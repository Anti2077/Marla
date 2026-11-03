import Foundation

/// Geometry and roles only. No AX objects, titles, values or source text cross the worker boundary.
struct ScreenshotElementCandidate: Equatable, Sendable {
    let frame: CGRect
    let role: String
}

struct ScreenshotElementPath: Equatable, Sendable {
    let windowID: UInt32
    let candidates: [ScreenshotElementCandidate]

    static func make(
        windowID: UInt32, windowFrame: CGRect, visibleBounds: CGRect,
        point: CGPoint, leafToRoot: [ScreenshotElementCandidate]
    ) -> Self {
        let window = visibleBounds.isNull ? windowFrame : windowFrame.intersection(visibleBounds)
        guard usable(window), window.contains(point) else { return Self(windowID: windowID, candidates: []) }
        var result: [ScreenshotElementCandidate] = []
        for candidate in leafToRoot.prefix(32) {
            guard usable(candidate.frame) else { continue }
            let frame = candidate.frame.intersection(window)
            guard usable(frame), frame.contains(point), !approximatelyEqual(frame, window) else { continue }
            if let last = result.last {
                guard !approximatelyEqual(last.frame, frame), frame.contains(last.frame) else { continue }
            }
            result.append(ScreenshotElementCandidate(frame: frame, role: candidate.role))
        }
        result.append(ScreenshotElementCandidate(frame: window, role: "AXWindow"))
        return Self(windowID: windowID, candidates: result)
    }

    static func usable(_ rect: CGRect) -> Bool {
        rect.minX.isFinite && rect.minY.isFinite && rect.width.isFinite && rect.height.isFinite
            && rect.width > 4 && rect.height > 4 && !rect.isNull
    }

    static func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 1) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.maxX - rhs.maxX) <= tolerance && abs(lhs.maxY - rhs.maxY) <= tolerance
    }
}

struct ScreenshotElementChoice {
    private(set) var path: ScreenshotElementPath?
    private(set) var index = 0
    private(set) var isExplicit = false
    private(set) var isLocked = false
    var selected: ScreenshotElementCandidate? {
        guard let path, path.candidates.indices.contains(index) else { return nil }
        return path.candidates[index]
    }

    mutating func replace(_ next: ScreenshotElementPath?) {
        guard !isLocked else { return }
        let previous = selected
        let sameWindow = path?.windowID == next?.windowID
        let samePath = path == next
        path = next
        if samePath { return }
        if sameWindow, isExplicit, let previous,
           let retained = next?.candidates.firstIndex(where: {
               ScreenshotElementPath.approximatelyEqual($0.frame, previous.frame) && $0.role == previous.role
           }) {
            index = retained
        } else if sameWindow, isExplicit, let previous {
            // A refinement may not move a frame explicitly chosen by the user.
            var candidates = next?.candidates ?? []
            candidates.removeAll { $0.frame != previous.frame && !($0.frame.contains(previous.frame) || previous.frame.contains($0.frame)) }
            candidates.append(previous)
            candidates.sort { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
            path = ScreenshotElementPath(windowID: next?.windowID ?? 0, candidates: candidates)
            index = candidates.firstIndex(of: previous) ?? 0
        } else {
            index = 0
            isExplicit = false
        }
    }

    mutating func step(_ delta: Int) {
        guard !isLocked, let path, !path.candidates.isEmpty else { return }
        index = min(max(index + delta, 0), path.candidates.count - 1)
        isExplicit = true
    }

    mutating func lock() { isLocked = true }
    mutating func reset() { self = Self() }
}

/// A precise finger gesture emits at most one level; momentum never changes the selection.
struct ScreenshotLevelScroll {
    private var accumulated: CGFloat = 0
    private var gestureActive = false
    private var gestureConsumed = false
    private var lastStep: TimeInterval = -.infinity
    private var lastEvent: TimeInterval = -.infinity

    mutating func step(
        delta: CGFloat, precise: Bool, began: Bool, momentum: Bool, ended: Bool,
        timestamp: TimeInterval
    ) -> Int {
        guard delta.isFinite, !momentum else { return 0 }
        if began {
            accumulated = 0
            gestureConsumed = false
            gestureActive = true
        } else if !gestureActive, timestamp - lastEvent > 0.25 {
            accumulated = 0
            gestureConsumed = false
        }
        lastEvent = timestamp
        if ended {
            accumulated = 0
            gestureActive = false
            return 0
        }
        if precise, gestureConsumed { return 0 }
        guard delta != 0 else { return 0 }
        if accumulated * delta < 0 { accumulated = 0 }
        accumulated += delta
        let threshold: CGFloat = precise ? 12 : 1
        guard abs(accumulated) >= threshold, timestamp - lastStep >= 0.1 else { return 0 }
        let direction = accumulated > 0 ? 1 : -1
        accumulated = 0
        lastStep = timestamp
        if precise { gestureConsumed = true }
        return direction
    }
}
