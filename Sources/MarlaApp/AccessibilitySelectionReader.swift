import AppKit
import ApplicationServices
import MarlaCore

@MainActor
final class AccessibilitySelectionReader: SelectionReader {
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
        guard isTrusted else {
            throw SelectionReadingError.accessibilityPermissionRequired
        }

        let application = NSWorkspace.shared.frontmostApplication
        let systemWideElement = AXUIElementCreateSystemWide()
        guard let focusedElement = copyFocusedElement(from: systemWideElement) else {
            throw SelectionReadingError.focusedElementUnavailable
        }

        let lookup = findSelection(startingAt: focusedElement)
        guard case let .found(selectedText, selectedElement) = lookup else {
            if case .empty = lookup {
                throw SelectionReadingError.emptySelection
            }
            throw SelectionReadingError.selectedTextUnavailable
        }

        let selection = TextSelection(
            text: selectedText,
            bounds: copySelectionBounds(from: selectedElement),
            applicationBundleID: application?.bundleIdentifier,
            applicationName: application?.localizedName
        )

        guard selection.hasVisibleText else {
            throw SelectionReadingError.emptySelection
        }

        return selection
    }

    private func copyFocusedElement(from systemWideElement: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )

        guard result == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }

        let element = value as! AXUIElement
        return element
    }

    private enum SelectionLookup {
        case found(String, AXUIElement)
        case empty
        case unavailable
    }

    /// Electron editors can leave the macOS focus on their WebArea while the actual text area is
    /// exposed further down the accessibility tree. Search a bounded set of visible descendants
    /// so selection acquisition stays responsive and never expands into unrelated window context.
    private func findSelection(startingAt focusedElement: AXUIElement) -> SelectionLookup {
        var queue = [focusedElement]
        var nextIndex = 0
        var observedEmptySelection = false
        let maximumElements = 2_000

        while nextIndex < queue.count, nextIndex < maximumElements {
            let element = queue[nextIndex]
            nextIndex += 1

            switch selectionText(from: element) {
            case let .found(text, _):
                return .found(text, element)
            case .empty:
                observedEmptySelection = true
            case .unavailable:
                break
            }

            let remainingCapacity = maximumElements - queue.count
            guard remainingCapacity > 0 else { continue }
            queue.append(contentsOf: childElements(from: element).prefix(remainingCapacity))
        }

        return observedEmptySelection ? .empty : .unavailable
    }

    private func selectionText(from element: AXUIElement) -> SelectionLookup {
        if let selectedText = copyStringAttribute(
            kAXSelectedTextAttribute as CFString,
            from: element
        ) {
            if !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .found(selectedText, element)
            }
        }

        if let (rangeValue, range) = copySelectionRange(from: element) {
            guard range.length > 0 else {
                return .empty
            }

            var value: CFTypeRef?
            let result = AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXStringForRangeParameterizedAttribute as CFString,
                rangeValue,
                &value
            )
            if result == .success,
               let selectedText = stringValue(from: value),
               !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .found(selectedText, element)
            }

            if let fullValue = copyStringAttribute(kAXValueAttribute as CFString, from: element),
               let selectedText = Self.substring(in: fullValue, range: range),
               !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .found(selectedText, element)
            }
        }

        if let markerRange = copyAttribute("AXSelectedTextMarkerRange" as CFString, from: element) {
            var lengthValue: CFTypeRef?
            let lengthResult = AXUIElementCopyParameterizedAttributeValue(
                element,
                "AXLengthForTextMarkerRange" as CFString,
                markerRange,
                &lengthValue
            )
            if lengthResult == .success,
               let length = lengthValue as? NSNumber,
               length.intValue == 0 {
                return .empty
            }

            var markerStringValue: CFTypeRef?
            let stringResult = AXUIElementCopyParameterizedAttributeValue(
                element,
                "AXStringForTextMarkerRange" as CFString,
                markerRange,
                &markerStringValue
            )
            if stringResult == .success,
               let selectedText = stringValue(from: markerStringValue),
               !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .found(selectedText, element)
            }

            var attributedValue: CFTypeRef?
            let attributedResult = AXUIElementCopyParameterizedAttributeValue(
                element,
                "AXAttributedStringForTextMarkerRange" as CFString,
                markerRange,
                &attributedValue
            )
            if attributedResult == .success,
               let selectedText = stringValue(from: attributedValue),
               !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .found(selectedText, element)
            }
        }
        return .unavailable
    }

    private func childElements(from element: AXUIElement) -> [AXUIElement] {
        let attributes: [CFString] = [
            kAXChildrenAttribute as CFString,
            kAXVisibleChildrenAttribute as CFString,
            "AXContents" as CFString,
            "AXRows" as CFString
        ]
        var seen = Set<UInt>()
        var children: [AXUIElement] = []
        for attribute in attributes {
            for child in copyElementArrayAttribute(attribute, from: element) ?? [] {
                let identifier = UInt(bitPattern: Unmanaged.passUnretained(child).toOpaque())
                guard seen.insert(identifier).inserted else { continue }
                children.append(child)
            }
        }
        return children.sorted { selectionPriority(for: $0) > selectionPriority(for: $1) }
    }

    private func selectionPriority(for element: AXUIElement) -> Int {
        switch copyStringAttribute(kAXRoleAttribute as CFString, from: element) {
        case "AXTextArea", "AXTextField":
            3
        case "AXWebArea":
            2
        case "AXStaticText":
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
        return value as? [AXUIElement]
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

    private func copySelectionBounds(from element: AXUIElement) -> ScreenRect? {
        if let (rangeValue, _) = copySelectionRange(from: element),
           let rectangle = copyBounds(
               parameterizedAttribute: kAXBoundsForRangeParameterizedAttribute as CFString,
               parameter: rangeValue,
               from: element
           ) {
            return ScreenRect(
                x: rectangle.origin.x,
                y: rectangle.origin.y,
                width: rectangle.width,
                height: rectangle.height
            )
        }

        guard let markerRange = copyAttribute("AXSelectedTextMarkerRange" as CFString, from: element),
              let rectangle = copyBounds(
                  parameterizedAttribute: "AXBoundsForTextMarkerRange" as CFString,
                  parameter: markerRange,
                  from: element
              )
        else { return nil }
        return ScreenRect(
            x: rectangle.origin.x,
            y: rectangle.origin.y,
            width: rectangle.width,
            height: rectangle.height
        )
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
