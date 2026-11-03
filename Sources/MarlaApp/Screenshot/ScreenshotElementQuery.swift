import ApplicationServices
import Foundation

struct ScreenshotElementQueryRequest: Equatable, Sendable {
    let generation: UInt64
    let windowID: UInt32
    let processID: Int32
    let windowFrame: CGRect
    let visibleBounds: CGRect
    let point: CGPoint
    let primaryScreenMaxY: CGFloat
    let refined: Bool
}

struct ScreenshotElementQueryResult: Sendable {
    let request: ScreenshotElementQueryRequest
    let path: ScreenshotElementPath
    let elapsedMilliseconds: Double
    let visitedNodes: Int
    let termination: String
}

/// This lock protects only a cancellation bit, never a platform reference.
final class ScreenshotQueryCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.withLock { cancelled = true } }
    var isCancelled: Bool { lock.withLock { cancelled } }
}

/// All AX references are created, traversed and destroyed synchronously on this worker invocation.
/// No AXValue attribute, titles, descriptions or text content is read.
/// Public text ranges are used only to request line geometry.
enum ScreenshotElementQuery {
    static func run(
        _ request: ScreenshotElementQueryRequest, cancellation: ScreenshotQueryCancellation,
        prepareProvider: ((AXUIElement) -> Void)? = nil
    ) -> ScreenshotElementQueryResult {
        let search = Search(request: request, cancellation: cancellation, prepareProvider: prepareProvider)
        return search.run()
    }

    static func query(_ request: ScreenshotElementQueryRequest,
                      cancellation: ScreenshotQueryCancellation) -> ScreenshotElementQueryResult {
        run(request, cancellation: cancellation)
    }

    private final class Search {
        let request: ScreenshotElementQueryRequest
        let cancellation: ScreenshotQueryCancellation
        let started = ProcessInfo.processInfo.systemUptime
        let budget: TimeInterval
        let prepareProvider: ((AXUIElement) -> Void)?
        var visited = 0
        var termination = "complete"

        init(request: ScreenshotElementQueryRequest, cancellation: ScreenshotQueryCancellation,
             prepareProvider: ((AXUIElement) -> Void)?) {
            self.prepareProvider = prepareProvider
            self.request = request
            self.cancellation = cancellation
            budget = request.refined ? 0.45 : 0.16
        }

        var active: Bool {
            if cancellation.isCancelled { termination = "cancelled"; return false }
            if ProcessInfo.processInfo.systemUptime - started >= budget { termination = "timeout"; return false }
            if visited >= 512 { termination = "nodeBudget"; return false }
            return true
        }

        func run() -> ScreenshotElementQueryResult {
            var candidates: [ScreenshotElementCandidate] = []
            if AXIsProcessTrusted(), active, windowUnchanged() {
                candidates = query()
                if !AXIsProcessTrusted() || !windowUnchanged() {
                    candidates = []
                    termination = "windowChangedOrPermissionRevoked"
                }
            } else if !AXIsProcessTrusted() {
                termination = "permissionUnavailable"
            } else if termination == "complete" {
                termination = "windowChanged"
            }
            return ScreenshotElementQueryResult(
                request: request,
                path: .make(
                    windowID: request.windowID, windowFrame: request.windowFrame,
                    visibleBounds: request.visibleBounds, point: request.point, leafToRoot: candidates
                ),
                elapsedMilliseconds: (ProcessInfo.processInfo.systemUptime - started) * 1_000,
                visitedNodes: visited, termination: termination
            )
        }

        func query() -> [ScreenshotElementCandidate] {
            guard request.processID > 0, request.processID != getpid() else { return [] }
            let application = AXUIElementCreateApplication(request.processID)
            AXUIElementSetMessagingTimeout(application, 0.025)
            if active { prepareProvider?(application) }
            // Public geometry matching is deliberately conservative when windows share identical bounds.
            let windows = elements(attribute(kAXWindowsAttribute, application))
            let matching = windows.filter { window in
                guard let rect = frame(window) else { return false }
                return ScreenshotElementPath.approximatelyEqual(rect, request.windowFrame, tolerance: 2)
            }
            guard matching.count == 1, let window = matching.first, active else { return [] }
            let axPoint = CGPoint(x: request.point.x, y: request.primaryScreenMaxY - request.point.y)
            var hit: AXUIElement?
            AXUIElementCopyElementAtPosition(application, Float(axPoint.x), Float(axPoint.y), &hit)
            guard active else { return [] }
            let leaf = hit ?? window
            var node: AXUIElement? = leaf
            var seen: [AXUIElement] = []
            var path: [ScreenshotElementCandidate] = []
            var reachedWindow = false
            while let element = node, active, seen.count < 32 {
                guard !seen.contains(where: { CFEqual($0, element) }) else {
                    termination = "cycle"; break
                }
                seen.append(element)
                visited += 1
                guard owned(element), !hidden(element) else { break }
                if let rect = frame(element), let role = attribute(kAXRoleAttribute, element) as? String {
                    path.append(ScreenshotElementCandidate(frame: rect, role: role))
                }
                if CFEqual(element, window) { reachedWindow = true; break }
                node = elementAttribute(kAXParentAttribute, element)
            }
            guard reachedWindow else { termination = "unverifiedWindow"; return [] }
            if request.refined, active {
                let descendants = finerPath(at: request.point, from: leaf, depth: 0, seen: [])
                path = descendants + path
            }
            if active, let textFrame = textLineFrame(at: axPoint, element: leaf), textFrame.contains(request.point) {
                path.insert(ScreenshotElementCandidate(frame: textFrame, role: "AXTextLine"), at: 0)
            }
            return path
        }

        func finerPath(at point: CGPoint, from element: AXUIElement, depth: Int,
                       seen: [AXUIElement]) -> [ScreenshotElementCandidate] {
            guard active, depth < 24, !seen.contains(where: { CFEqual($0, element) }) else { return [] }
            let nextSeen = seen + [element]
            var best: [ScreenshotElementCandidate] = []
            var seenChildren: [AXUIElement] = []
            // Walk every containing branch, including overlapping browser groups. A first-child-only
            // descent can stop at a large decorative container while a sibling exposes paragraph text.
            for name in [kAXVisibleChildrenAttribute, kAXChildrenAttribute, "AXContents"] {
                var count: CFIndex = 0
                guard active, AXUIElementGetAttributeValueCount(element, name as CFString, &count) == .success,
                      count > 0 else { continue }
                var offset: CFIndex = 0
                while offset < min(count, 512), active {
                    var value: CFArray?
                    guard AXUIElementCopyAttributeValues(element, name as CFString, offset,
                              min(32, count - offset), &value) == .success else { break }
                    offset += 32
                    for child in elements(value) {
                        guard active else { break }
                        guard !seenChildren.contains(where: { CFEqual($0, child) }) else { continue }
                        seenChildren.append(child)
                        visited += 1
                        guard owned(child), !hidden(child),
                              let parent = elementAttribute(kAXParentAttribute, child), CFEqual(parent, element)
                        else { continue }
                        let rect = frame(child)
                        if let rect, !rect.contains(point) { continue }
                        let role = attribute(kAXRoleAttribute, child) as? String
                        var childPath = finerPath(at: point, from: child, depth: depth + 1, seen: nextSeen)
                        if let rect, let role {
                            childPath.append(ScreenshotElementCandidate(frame: rect, role: role))
                        }
                        // Keep only an actual ancestry chain; do not combine overlapping siblings.
                        if let candidate = childPath.first,
                           best.first.map({ candidate.frame.width * candidate.frame.height < $0.frame.width * $0.frame.height }) ?? true {
                            best = childPath
                        }
                    }
                }
            }
            return best
        }

        func parameter(_ name: String, _ value: CFTypeRef, element: AXUIElement) -> CFTypeRef? {
            guard active else { return nil }
            var result: CFTypeRef?
            return AXUIElementCopyParameterizedAttributeValue(element, name as CFString, value, &result) == .success
                ? result : nil
        }

        /// Public text geometry only: position → index → line range → bounds. No string is requested.
        func textLineFrame(at point: CGPoint, element: AXUIElement) -> CGRect? {
            var point = point
            guard let position = AXValueCreate(.cgPoint, &point),
                  let value = parameter(kAXRangeForPositionParameterizedAttribute, position, element: element),
                  CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
            var range = CFRange()
            guard AXValueGetValue(value as! AXValue, .cfRange, &range), range.location >= 0,
                  let line = parameter(kAXLineForIndexParameterizedAttribute, NSNumber(value: range.location), element: element),
                  let lineRange = parameter(kAXRangeForLineParameterizedAttribute, line, element: element),
                  let bounds = parameter(kAXBoundsForRangeParameterizedAttribute, lineRange, element: element),
                  CFGetTypeID(bounds) == AXValueGetTypeID() else { return nil }
            var rect = CGRect.zero
            guard AXValueGetValue(bounds as! AXValue, .cgRect, &rect) else { return nil }
            return CGRect(x: rect.minX, y: request.primaryScreenMaxY - rect.maxY, width: rect.width, height: rect.height)
        }

        func attribute(_ name: String, _ element: AXUIElement) -> CFTypeRef? {
            guard active else { return nil }
            AXUIElementSetMessagingTimeout(element, 0.025)
            var value: CFTypeRef?
            return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
        }

        func elementAttribute(_ name: String, _ element: AXUIElement) -> AXUIElement? {
            guard let value = attribute(name, element), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
            return (value as! AXUIElement)
        }

        func elements(_ value: CFTypeRef?) -> [AXUIElement] {
            guard let value, CFGetTypeID(value) == CFArrayGetTypeID() else { return [] }
            return (value as! [AnyObject]).prefix(128).compactMap {
                CFGetTypeID($0) == AXUIElementGetTypeID() ? ($0 as! AXUIElement) : nil
            }
        }

        func owned(_ element: AXUIElement) -> Bool {
            var pid: pid_t = 0
            return active && AXUIElementGetPid(element, &pid) == .success && pid == request.processID
        }

        func hidden(_ element: AXUIElement) -> Bool {
            (attribute("AXHidden", element) as? Bool == true)
                || (attribute(kAXMinimizedAttribute, element) as? Bool == true)
        }

        func frame(_ element: AXUIElement) -> CGRect? {
            guard let position = attribute(kAXPositionAttribute, element),
                  CFGetTypeID(position) == AXValueGetTypeID(),
                  let size = attribute(kAXSizeAttribute, element), CFGetTypeID(size) == AXValueGetTypeID()
            else { return nil }
            var point = CGPoint.zero
            var dimensions = CGSize.zero
            guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
                  AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
            return CGRect(x: point.x, y: request.primaryScreenMaxY - point.y - dimensions.height,
                          width: dimensions.width, height: dimensions.height)
        }

        func windowUnchanged() -> Bool {
            guard let info = CGWindowListCopyWindowInfo(.optionIncludingWindow, request.windowID) as? [[String: Any]],
                  let window = info.first,
                  (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == request.processID,
                  (window[kCGWindowIsOnscreen as String] as? Bool) == true,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds)
            else { return false }
            let converted = CGRect(x: rect.minX, y: request.primaryScreenMaxY - rect.maxY,
                                   width: rect.width, height: rect.height)
            return ScreenshotElementPath.approximatelyEqual(converted, request.windowFrame, tolerance: 2)
        }
    }
}
