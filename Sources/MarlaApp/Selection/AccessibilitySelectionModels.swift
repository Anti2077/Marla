import AppKit
import MarlaCore

@MainActor
final class SelectionReadCancellation {
    private(set) var isCancelled = false

    func cancel() {
        isCancelled = true
    }
}

struct AccessibilityDisplayGeometry: Equatable {
    let accessibilityFrame: CGRect
    let appKitFrame: CGRect
}

enum AccessibilityCoordinateConverter {
    static func appKitRect(
        from accessibilityRect: CGRect,
        displays: [AccessibilityDisplayGeometry]
    ) -> CGRect? {
        guard AccessibilitySelectionReader.isUsableSelectionBounds(accessibilityRect) else { return nil }

        let candidates: [(display: AccessibilityDisplayGeometry, area: CGFloat)] = displays.compactMap { display in
            let intersection = accessibilityRect.intersection(display.accessibilityFrame)
            let area = intersection.isNull ? 0 : intersection.width * intersection.height
            return area > 0 ? (display, area) : nil
        }
        let display = candidates.max { lhs, rhs in lhs.area < rhs.area }?.display
        guard let display else { return nil }

        let localX = accessibilityRect.minX - display.accessibilityFrame.minX
        let localTop = accessibilityRect.minY - display.accessibilityFrame.minY
        return CGRect(
            x: display.appKitFrame.minX + localX,
            y: display.appKitFrame.maxY - localTop - accessibilityRect.height,
            width: accessibilityRect.width,
            height: accessibilityRect.height
        )
    }
}

enum SelectionMechanism: String, Codable, Equatable {
    case directText
    case standardRange
    case textMarker
    case simulatedCopy
}

enum SelectionTextLookup: Equatable {
    case found(TranslationContent, SelectionMechanism)
    case empty
    case unavailable
}

enum SelectionSearchTermination: String, Codable, Equatable {
    case found
    case exhausted
    case elementLimit
    case timeLimit
}

enum SelectionGraphLookup<Node> {
    case found(TranslationContent, SelectionMechanism, Node)
    case empty
    case unavailable
}

struct SelectionSearchOutcome<Node> {
    let lookup: SelectionGraphLookup<Node>
    let visitedElementCount: Int
    let termination: SelectionSearchTermination
}

struct SelectionGraphSearch {
    static func find<Node: Hashable>(
        roots: [Node],
        maximumElements: Int,
        hasTimeRemaining: () -> Bool,
        selection: (Node) -> SelectionTextLookup,
        children: (Node) -> [Node]
    ) -> SelectionSearchOutcome<Node> {
        var queue: [Node] = []
        var enqueued = Set<Node>()
        var nextIndex = 0
        var visitedElementCount = 0
        var observedEmptySelection = false
        var deferredRoots: [Node] = []

        func enqueue(_ nodes: [Node]) {
            for node in nodes where enqueued.insert(node).inserted {
                queue.append(node)
            }
        }

        enqueue(roots)
        let initialRootCount = queue.count

        while nextIndex < queue.count {
            guard visitedElementCount < maximumElements else {
                return SelectionSearchOutcome(
                    lookup: .unavailable,
                    visitedElementCount: visitedElementCount,
                    termination: .elementLimit
                )
            }
            guard hasTimeRemaining() else {
                return SelectionSearchOutcome(
                    lookup: .unavailable,
                    visitedElementCount: visitedElementCount,
                    termination: .timeLimit
                )
            }

            let node = queue[nextIndex]
            nextIndex += 1
            visitedElementCount += 1

            switch selection(node) {
            case let .found(content, mechanism):
                return SelectionSearchOutcome(
                    lookup: .found(content, mechanism, node),
                    visitedElementCount: visitedElementCount,
                    termination: .found
                )
            case .empty:
                observedEmptySelection = true
            case .unavailable:
                break
            }

            // Probe every focused/pointer/window root before expanding any one large AX subtree.
            // Electron and custom browser trees often expose the selection on an ancestor while
            // the first hit node owns thousands of unrelated descendants.
            if nextIndex < initialRootCount {
                deferredRoots.append(node)
                continue
            }
            if !deferredRoots.isEmpty {
                deferredRoots.forEach { enqueue(children($0)) }
                deferredRoots.removeAll(keepingCapacity: true)
            }
            enqueue(children(node))
        }

        return SelectionSearchOutcome(
            lookup: observedEmptySelection ? .empty : .unavailable,
            visitedElementCount: visitedElementCount,
            termination: .exhausted
        )
    }
}

struct SelectionCandidateRoots {
    static func merge<Node: Hashable>(_ groups: [[Node]]) -> [Node] {
        var seen = Set<Node>()
        return groups.flatMap { group in
            group.filter { seen.insert($0).inserted }
        }
    }
}

