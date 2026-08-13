import AppKit
import ApplicationServices
import MarlaCore

struct SelectionReadDiagnostics: Codable, Equatable {
    let rootCount: Int
    let hadFocusedCandidate: Bool
    let hadPointerCandidate: Bool
    let rawPointerHitCount: Int
    let hadSystemFocusedElement: Bool
    let hadApplicationFocusedElement: Bool
    let hadFocusedWindow: Bool
    let systemFocusedApplicationMatched: Bool
    let visitedElementCount: Int
    let termination: SelectionSearchTermination
    let matchedMechanism: SelectionMechanism?
    let elapsedMilliseconds: Int
    let copyFallbackAttempted: Bool
    let copyFallbackStatus: ClipboardRestoreStatus

    init(
        rootCount: Int,
        hadFocusedCandidate: Bool,
        hadPointerCandidate: Bool,
        rawPointerHitCount: Int,
        hadSystemFocusedElement: Bool,
        hadApplicationFocusedElement: Bool,
        hadFocusedWindow: Bool,
        systemFocusedApplicationMatched: Bool,
        visitedElementCount: Int,
        termination: SelectionSearchTermination,
        matchedMechanism: SelectionMechanism?,
        elapsedMilliseconds: Int,
        copyFallbackAttempted: Bool = false,
        copyFallbackStatus: ClipboardRestoreStatus = .notAttempted
    ) {
        self.rootCount = rootCount
        self.hadFocusedCandidate = hadFocusedCandidate
        self.hadPointerCandidate = hadPointerCandidate
        self.rawPointerHitCount = rawPointerHitCount
        self.hadSystemFocusedElement = hadSystemFocusedElement
        self.hadApplicationFocusedElement = hadApplicationFocusedElement
        self.hadFocusedWindow = hadFocusedWindow
        self.systemFocusedApplicationMatched = systemFocusedApplicationMatched
        self.visitedElementCount = visitedElementCount
        self.termination = termination
        self.matchedMechanism = matchedMechanism
        self.elapsedMilliseconds = elapsedMilliseconds
        self.copyFallbackAttempted = copyFallbackAttempted
        self.copyFallbackStatus = copyFallbackStatus
    }
}

@MainActor
final class AccessibilitySelectionReader: SelectionReader {
    private struct AXNode: Hashable {
        let element: AXUIElement

        static func == (lhs: AXNode, rhs: AXNode) -> Bool {
            CFEqual(lhs.element, rhs.element)
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(CFHash(element))
        }
    }

    private static let maximumElements = 4_000
    private static let searchTimeLimit: TimeInterval = 0.25
    private static let applicationMessageTimeout: Float = 0.1

    private let copyFallback: ClipboardSelectionFallback
    private(set) var lastDiagnostics: SelectionReadDiagnostics?

    init(copyFallback: ClipboardSelectionFallback = ClipboardSelectionFallback()) {
        self.copyFallback = copyFallback
    }

    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    func requestAccess() -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }

    func readSelection() throws -> TextSelection {
        try readSelection(from: nil)
    }

    /// Reads against the application captured at the shortcut trigger. A
    /// Carbon hot-key callback is delivered to Marla asynchronously; relying
    /// on a later `frontmostApplication` lookup can otherwise bind the AX
    /// search to Marla itself after AppKit has processed the event.
    func readSelection(
        from triggerApplication: NSRunningApplication?,
        allowCopyFallback: Bool = false,
        isCancelled: () -> Bool = { false }
    ) throws -> TextSelection {
        guard isTrusted else {
            lastDiagnostics = nil
            throw SelectionReadingError.accessibilityPermissionRequired
        }

        guard let application = triggerApplication ?? NSWorkspace.shared.frontmostApplication else {
            lastDiagnostics = nil
            throw SelectionReadingError.focusedElementUnavailable
        }

        let startedAt = ProcessInfo.processInfo.systemUptime
        let systemWideElement = AXUIElementCreateSystemWide()
        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(applicationElement, Self.applicationMessageTimeout)

        // `AXUIElementCopyElementAtPosition` is implemented inconsistently by
        // Electron and custom AppKit clients.  Some return a hit only when the
        // application element is used; others expose the renderer through the
        // system-wide element.  Probe both handles and merge the ancestor paths
        // before traversing the graph.  The trigger has already captured the
        // frontmost application, so this remains bounded to the pointer location
        // and never becomes a nearby-text scan.
        let pointerHitGroups: [[AXNode]] = [
            copyElementAtPointer(from: applicationElement).map { [AXNode(element: $0)] } ?? [],
            copyElementAtPointer(from: systemWideElement).map { [AXNode(element: $0)] } ?? []
        ]
        let pointerHits = SelectionCandidateRoots.merge(pointerHitGroups).map(\.element)
        let pointerCandidates = pointerHits.flatMap {
            elementAndAncestors(
                startingAt: $0,
                maximumCount: 16
            )
        }

        let systemFocusedApplication = copyElementAttribute(
            kAXFocusedApplicationAttribute as CFString,
            from: systemWideElement
        )
        let systemFocusedApplicationMatches = systemFocusedApplication.map {
            elementBelongsToApplication($0, application: application)
        } ?? false
        let rawSystemFocusedElement = copyElementAttribute(
            kAXFocusedUIElementAttribute as CFString,
            from: systemWideElement
        )
        let systemFocusedElement = rawSystemFocusedElement.flatMap {
            // Renderer/helper processes can own the focused AX node while the
            // focused application element still belongs to the frontmost app.
            // The old exact-PID check rejected that valid path (notably Codex).
            elementBelongsToApplication($0, application: application) || systemFocusedApplicationMatches
                ? $0
                : nil
        }
        let applicationFocusedElement = copyElementAttribute(
            kAXFocusedUIElementAttribute as CFString,
            from: applicationElement
        )
        let focusedWindow = copyElementAttribute(
            kAXFocusedWindowAttribute as CFString,
            from: applicationElement
        )
        let windowFocusedElement = focusedWindow.flatMap {
            copyElementAttribute(kAXFocusedUIElementAttribute as CFString, from: $0)
        }
        let focusedCandidates = [systemFocusedElement, applicationFocusedElement, windowFocusedElement]
            .compactMap { $0 }
        let focusedApplicationRoots: [AXNode] = systemFocusedApplicationMatches
            ? systemFocusedApplication.map { AXNode(element: $0) }.map { [$0] } ?? []
            : []
        let roots = SelectionCandidateRoots.merge([
            pointerCandidates.map(AXNode.init),
            focusedCandidates.map(AXNode.init),
            // Some renderer/helper processes expose the focused application as
            // a separate AX root. Keep it when LaunchServices ties that root
            // to the trigger-time frontmost application; otherwise a valid
            // selection can sit outside the main application's AX subtree.
            focusedApplicationRoots,
            [focusedWindow, applicationElement].compactMap { $0 }.map(AXNode.init)
        ])

        let outcome = SelectionGraphSearch.find(
            roots: roots,
            maximumElements: Self.maximumElements,
            hasTimeRemaining: {
                ProcessInfo.processInfo.systemUptime - startedAt < Self.searchTimeLimit
            },
            selection: { [self] node in selectionText(from: node.element) },
            children: { [self] node in childElements(from: node.element).map(AXNode.init) }
        )
        lastDiagnostics = SelectionReadDiagnostics(
            rootCount: Set(roots).count,
            hadFocusedCandidate: !focusedCandidates.isEmpty,
            hadPointerCandidate: !pointerCandidates.isEmpty,
            rawPointerHitCount: pointerHits.count,
            hadSystemFocusedElement: rawSystemFocusedElement != nil,
            hadApplicationFocusedElement: applicationFocusedElement != nil,
            hadFocusedWindow: focusedWindow != nil,
            systemFocusedApplicationMatched: systemFocusedApplicationMatches,
            visitedElementCount: outcome.visitedElementCount,
            termination: outcome.termination,
            matchedMechanism: {
                guard case let .found(_, mechanism, _) = outcome.lookup else { return nil }
                return mechanism
            }(),
            elapsedMilliseconds: Int((ProcessInfo.processInfo.systemUptime - startedAt) * 1_000)
        )

        if allowCopyFallback {
            if case .found = outcome.lookup {
                // Accessibility already found a selection; do not touch the clipboard.
            } else {
                do {
                    let fallback = try copyFallback.readSelection(
                        from: application,
                        isCancelled: isCancelled
                    )
                    updateCopyFallbackDiagnostics(
                        status: fallback.restoreStatus,
                        matched: true,
                        startedAt: startedAt
                    )
                    return fallback.selection
                } catch let error as ClipboardSelectionFallbackError {
                    updateCopyFallbackDiagnostics(
                        status: copyFallback.lastRestoreStatus,
                        matched: false,
                        startedAt: startedAt
                    )
                    switch error {
                    case .timedOut:
                        throw SelectionReadingError.copyFallbackTimedOut
                    case .restoreFailed:
                        throw SelectionReadingError.clipboardRestoreFailed
                    case .cancelled:
                        throw SelectionReadingError.selectionCancelled
                    case .sourceApplicationChanged,
                         .snapshotUnavailable,
                         .copyEventUnavailable,
                         .clipboardChangedDuringCopy,
                         .selectedTextUnavailable:
                        throw SelectionReadingError.copyFallbackUnavailable
                    }
                }
            }
        }

        guard case let .found(selectedText, mechanism, selectedNode) = outcome.lookup else {
            switch outcome.termination {
            case .elementLimit:
                throw SelectionReadingError.selectionSearchLimitReached
            case .timeLimit:
                throw SelectionReadingError.selectionSearchTimedOut
            case .found:
                assertionFailure("A found search must contain a selected node")
                throw SelectionReadingError.selectedTextUnavailable
            case .exhausted:
                break
            }
            if case .empty = outcome.lookup {
                // A pointer-only path is useful for custom-rendered surfaces,
                // but an empty value there does not prove that the application
                // exposed a real focused selection. Keep that failure distinct
                // from an explicitly empty range on a focused AX element.
                if focusedCandidates.isEmpty {
                    throw SelectionReadingError.selectedTextUnavailable
                }
                throw SelectionReadingError.emptySelection
            }
            if focusedCandidates.isEmpty {
                if pointerCandidates.isEmpty {
                    throw SelectionReadingError.focusedElementUnavailable
                }
                throw SelectionReadingError.selectedTextUnavailable
            }
            throw SelectionReadingError.selectedTextUnavailable
        }

        let selection = TextSelection(
            text: selectedText,
            bounds: copySelectionBounds(from: selectedNode.element, preferred: mechanism),
            applicationBundleID: application.bundleIdentifier,
            applicationName: application.localizedName
        )

        guard selection.hasVisibleText else {
            throw SelectionReadingError.emptySelection
        }

        return selection
    }

    private func updateCopyFallbackDiagnostics(
        status: ClipboardRestoreStatus,
        matched: Bool,
        startedAt: TimeInterval
    ) {
        guard let diagnostics = lastDiagnostics else { return }
        lastDiagnostics = SelectionReadDiagnostics(
            rootCount: diagnostics.rootCount,
            hadFocusedCandidate: diagnostics.hadFocusedCandidate,
            hadPointerCandidate: diagnostics.hadPointerCandidate,
            rawPointerHitCount: diagnostics.rawPointerHitCount,
            hadSystemFocusedElement: diagnostics.hadSystemFocusedElement,
            hadApplicationFocusedElement: diagnostics.hadApplicationFocusedElement,
            hadFocusedWindow: diagnostics.hadFocusedWindow,
            systemFocusedApplicationMatched: diagnostics.systemFocusedApplicationMatched,
            visitedElementCount: diagnostics.visitedElementCount,
            termination: diagnostics.termination,
            matchedMechanism: matched ? .simulatedCopy : diagnostics.matchedMechanism,
            elapsedMilliseconds: Int((ProcessInfo.processInfo.systemUptime - startedAt) * 1_000),
            copyFallbackAttempted: true,
            copyFallbackStatus: status
        )
    }

    private func elementBelongsToApplication(_ element: AXUIElement, application: NSRunningApplication) -> Bool {
        var elementProcessIdentifier = pid_t()
        guard AXUIElementGetPid(element, &elementProcessIdentifier) == .success else { return false }
        if elementProcessIdentifier == application.processIdentifier { return true }
        // A renderer/helper may expose AX nodes under the same bundle.  Accept
        // that identity only when LaunchServices can confirm it, rather than
        // trusting an arbitrary process returned by the system-wide element.
        return NSRunningApplication(processIdentifier: elementProcessIdentifier)?.bundleIdentifier
            == application.bundleIdentifier
    }

    private func copyElementAtPointer(
        from applicationElement: AXUIElement
    ) -> AXUIElement? {
        guard let location = CGEvent(source: nil)?.location else { return nil }
        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(
            applicationElement,
            Float(location.x),
            Float(location.y),
            &element
        )
        guard result == .success, let element else { return nil }
        return element
    }

    private func elementAndAncestors(
        startingAt element: AXUIElement,
        maximumCount: Int
    ) -> [AXUIElement] {
        var candidates: [AXUIElement] = []
        var seen = Set<AXNode>()
        var current: AXUIElement? = element

        while let candidate = current,
              candidates.count < maximumCount,
              seen.insert(AXNode(element: candidate)).inserted {
            candidates.append(candidate)
            current = copyElementAttribute(kAXParentAttribute as CFString, from: candidate)
        }
        return candidates
    }

    private func selectionText(from element: AXUIElement) -> SelectionTextLookup {
        var lookups: [SelectionTextLookup] = []
        // Do not gate selection probes on AXAttributeNames.  WebKit/Electron
        // frequently omits selection attributes from that list while still
        // serving the values (especially Text Marker ranges).  The AX call is
        // itself the capability check and returns `.attributeUnsupported` when
        // unavailable; skipping it creates a false negative.
        if let directValue = copyAttribute(kAXSelectedTextAttribute as CFString, from: element) {
            lookups.append(Self.textLookup(from: stringValue(from: directValue), mechanism: .directText))
        }

        if let (rangeValue, range) = copySelectionRange(from: element) {
            if range.length == 0 {
                lookups.append(.empty)
            } else {
                var rangeLookups: [SelectionTextLookup] = []
                rangeLookups.append(
                    parameterizedTextLookup(
                        attribute: kAXStringForRangeParameterizedAttribute as CFString,
                        parameter: rangeValue,
                        from: element,
                        mechanism: .standardRange
                    )
                )
                rangeLookups.append(
                    parameterizedTextLookup(
                        attribute: "AXAttributedStringForRange" as CFString,
                        parameter: rangeValue,
                        from: element,
                        mechanism: .standardRange
                    )
                )
                if let fullValue = copyStringAttribute(kAXValueAttribute as CFString, from: element) {
                    rangeLookups.append(
                        Self.textLookup(
                            from: Self.substring(in: fullValue, range: range),
                            mechanism: .standardRange
                        )
                    )
                }
                lookups.append(Self.resolveTextLookups(rangeLookups))
            }
        }

        if let markerRange = copyAttribute("AXSelectedTextMarkerRange" as CFString, from: element) {
            var markerLookups: [SelectionTextLookup] = []
            if let markerLength = textMarkerRangeLength(markerRange, from: element), markerLength == 0 {
                markerLookups.append(.empty)
            }
            markerLookups.append(
                parameterizedTextLookup(
                    attribute: "AXStringForTextMarkerRange" as CFString,
                    parameter: markerRange,
                    from: element,
                    mechanism: .textMarker
                )
            )
            markerLookups.append(
                parameterizedTextLookup(
                    attribute: "AXAttributedStringForTextMarkerRange" as CFString,
                    parameter: markerRange,
                    from: element,
                    mechanism: .textMarker
                )
            )
            lookups.append(Self.resolveTextLookups(markerLookups))
        }

        return Self.resolveTextLookups(lookups)
    }

    nonisolated static func resolveTextLookups(_ lookups: [SelectionTextLookup]) -> SelectionTextLookup {
        var observedEmptySelection = false
        for lookup in lookups {
            switch lookup {
            case let .found(text, mechanism):
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    observedEmptySelection = true
                    continue
                }
                return .found(text, mechanism)
            case .empty:
                observedEmptySelection = true
            case .unavailable:
                break
            }
        }
        return observedEmptySelection ? .empty : .unavailable
    }

    private static func textLookup(
        from text: String?,
        mechanism: SelectionMechanism
    ) -> SelectionTextLookup {
        guard let text else { return .unavailable }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .empty
            : .found(text, mechanism)
    }

    private func parameterizedTextLookup(
        attribute: CFString,
        parameter: CFTypeRef,
        from element: AXUIElement,
        mechanism: SelectionMechanism
    ) -> SelectionTextLookup {
        var value: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            attribute,
            parameter,
            &value
        )
        guard result == .success else { return .unavailable }
        return Self.textLookup(from: stringValue(from: value), mechanism: mechanism)
    }

    private func textMarkerRangeLength(_ markerRange: CFTypeRef, from element: AXUIElement) -> Int? {
        var lengthValue: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            "AXLengthForTextMarkerRange" as CFString,
            markerRange,
            &lengthValue
        )
        guard result == .success, let length = lengthValue as? NSNumber else { return nil }
        return length.intValue
    }

    private func childElements(from element: AXUIElement) -> [AXUIElement] {
        let attributes: [CFString] = [
            kAXChildrenAttribute as CFString,
            kAXVisibleChildrenAttribute as CFString,
            "AXChildrenInNavigationOrder" as CFString,
            "AXContents" as CFString,
            "AXRows" as CFString,
            "AXVisibleRows" as CFString,
            "AXDisclosedRows" as CFString
        ]
        var children: [AXUIElement] = []
        var seen = Set<AXNode>()
        // Do not gate child probes on AXAttributeNames. WebKit/Electron and
        // custom accessibility clients often omit children from that list
        // while still returning them from AXChildren/AXContents. The AX call
        // itself is the capability check; the graph search remains bounded.
        for attribute in attributes {
            for child in copyElementArrayAttribute(attribute, from: element) ?? [] {
                guard seen.insert(AXNode(element: child)).inserted else { continue }
                children.append(child)
            }
        }
        return children.enumerated()
            .map { (index: $0.offset, element: $0.element, priority: selectionPriority(for: $0.element)) }
            .sorted {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.index < $1.index
            }
            .map(\.element)
    }

    private func selectionPriority(for element: AXUIElement) -> Int {
        switch copyStringAttribute(kAXRoleAttribute as CFString, from: element) {
        case "AXTextArea", "AXTextField", "AXSearchField":
            4
        case "AXWebArea":
            3
        case "AXStaticText":
            2
        case "AXGroup", "AXScrollArea":
            1
        default:
            0
        }
    }

    private func copyElementArrayAttribute(
        _ attribute: CFString,
        from element: AXUIElement
    ) -> [AXUIElement]? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else { return nil }
        if let elements = value as? [AXUIElement] {
            return elements
        }
        if let value,
           CFGetTypeID(value) == CFArrayGetTypeID() {
            return (value as! NSArray).compactMap { item in
                let itemReference = item as CFTypeRef
                guard CFGetTypeID(itemReference) == AXUIElementGetTypeID() else { return nil }
                return (itemReference as! AXUIElement)
            }
        }
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return [value as! AXUIElement]
    }

    private func copyStringAttribute(
        _ attribute: CFString,
        from element: AXUIElement
    ) -> String? {
        stringValue(from: copyAttribute(attribute, from: element))
    }

    private func stringValue(from value: CFTypeRef?) -> String? {
        if let string = value as? String {
            return string
        }
        return (value as? NSAttributedString)?.string
    }

    private func copyAttribute(_ attribute: CFString, from element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        return result == .success ? value : nil
    }

    private func copyElementAttribute(_ attribute: CFString, from element: AXUIElement) -> AXUIElement? {
        guard let value = copyAttribute(attribute, from: element),
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        return (value as! AXUIElement)
    }

    private func copySelectionBounds(
        from element: AXUIElement,
        preferred mechanism: SelectionMechanism
    ) -> ScreenRect? {
        let standardBounds = copyStandardSelectionBounds(from: element)
        let markerBounds = copyTextMarkerSelectionBounds(from: element)
        let rectangle: CGRect?
        switch mechanism {
        case .textMarker:
            rectangle = markerBounds ?? standardBounds
        case .directText, .standardRange:
            rectangle = standardBounds ?? markerBounds
        case .simulatedCopy:
            rectangle = nil
        }
        guard let rectangle,
              let appKitRectangle = AccessibilityCoordinateConverter.appKitRect(
                  from: rectangle,
                  displays: currentDisplayGeometries()
              )
        else { return nil }
        return ScreenRect(
            x: appKitRectangle.origin.x,
            y: appKitRectangle.origin.y,
            width: appKitRectangle.width,
            height: appKitRectangle.height
        )
    }

    private func currentDisplayGeometries() -> [AccessibilityDisplayGeometry] {
        NSScreen.screens.compactMap { screen in
            let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
            guard let screenNumber = screen.deviceDescription[screenNumberKey] as? NSNumber else { return nil }
            return AccessibilityDisplayGeometry(
                accessibilityFrame: CGDisplayBounds(CGDirectDisplayID(screenNumber.uint32Value)),
                appKitFrame: screen.frame
            )
        }
    }

    private func copyStandardSelectionBounds(from element: AXUIElement) -> CGRect? {
        if let (rangeValue, range) = copySelectionRange(from: element),
           range.length > 0,
           let rectangle = copyBounds(
               parameterizedAttribute: kAXBoundsForRangeParameterizedAttribute as CFString,
               parameter: rangeValue,
               from: element
           ) {
            return rectangle
        }
        return nil
    }

    private func copyTextMarkerSelectionBounds(from element: AXUIElement) -> CGRect? {
        guard let markerRange = copyAttribute("AXSelectedTextMarkerRange" as CFString, from: element),
              let rectangle = copyBounds(
                  parameterizedAttribute: "AXBoundsForTextMarkerRange" as CFString,
                  parameter: markerRange,
                  from: element
              )
        else { return nil }
        return rectangle
    }

    nonisolated static func isUsableSelectionBounds(_ rectangle: CGRect) -> Bool {
        rectangle.origin.x.isFinite
            && rectangle.origin.y.isFinite
            && rectangle.width.isFinite
            && rectangle.height.isFinite
            && rectangle.width >= 0
            && rectangle.height >= 0
            && (rectangle.width > 0 || rectangle.height > 0)
    }

    private func copyBounds(
        parameterizedAttribute: CFString,
        parameter: CFTypeRef,
        from element: AXUIElement
    ) -> CGRect? {
        var boundsValue: CFTypeRef?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            parameterizedAttribute,
            parameter,
            &boundsValue
        )

        guard boundsResult == .success, let boundsValue else { return nil }
        if let value = boundsValue as? NSValue {
            return value.rectValue
        }
        guard CFGetTypeID(boundsValue) == AXValueGetTypeID() else { return nil }

        let axValue = boundsValue as! AXValue
        guard AXValueGetType(axValue) == .cgRect else { return nil }

        var rectangle = CGRect.zero
        return AXValueGetValue(axValue, .cgRect, &rectangle) ? rectangle : nil
    }

    private func copySelectionRange(from element: AXUIElement) -> (CFTypeRef, CFRange)? {
        var rangeValue: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        )

        guard rangeResult == .success,
              let rangeValue,
              CFGetTypeID(rangeValue) == AXValueGetTypeID()
        else {
            return nil
        }

        let axValue = rangeValue as! AXValue
        guard AXValueGetType(axValue) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range), range.location >= 0, range.length >= 0 else {
            return nil
        }
        return (rangeValue, range)
    }

    nonisolated static func substring(in value: String, range: CFRange) -> String? {
        guard range.location >= 0,
              range.length >= 0,
              range.location + range.length <= value.utf16.count
        else {
            return nil
        }
        let lowerBound = String.Index(utf16Offset: range.location, in: value)
        let upperBound = String.Index(utf16Offset: range.location + range.length, in: value)
        return String(value[lowerBound..<upperBound])
    }
}
