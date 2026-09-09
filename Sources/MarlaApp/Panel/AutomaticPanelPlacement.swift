import AppKit
import MarlaCore

enum AutomaticPanelPlacementSide: Equatable {
    case below
    case above
    case right
    case left
    case pointer

    var growthAnchor: ResultPanelGrowthAnchor {
        switch self {
        case .below: .top
        case .above: .bottom
        case .right, .left, .pointer: .center
        }
    }

    var horizontalAnchor: ResultPanelHorizontalAnchor {
        switch self {
        case .right: .leading
        case .left: .trailing
        case .below, .above, .pointer: .center
        }
    }
}

struct PanelPlacementResult: Equatable {
    let frame: NSRect
    let automaticSide: AutomaticPanelPlacementSide?
}

enum PanelTargetScreenCalculator {
    static func index(
        screenFrames: [NSRect],
        source: NSRect?,
        pointer: CGPoint?
    ) -> Int? {
        guard !screenFrames.isEmpty else { return nil }
        if let source {
            let intersections = screenFrames.enumerated().map { index, frame in
                let intersection = frame.intersection(source)
                let area = intersection.isNull ? 0 : intersection.width * intersection.height
                return (index: index, area: area, containsPointer: pointer.map(frame.contains) ?? false)
            }
            if let best = intersections.max(by: { lhs, rhs in
                if lhs.area != rhs.area { return lhs.area < rhs.area }
                if lhs.containsPointer != rhs.containsPointer { return !lhs.containsPointer }
                return lhs.index > rhs.index
            }), best.area > 0 {
                return best.index
            }
        }
        if let pointer, let pointerIndex = screenFrames.firstIndex(where: { $0.contains(pointer) }) {
            return pointerIndex
        }
        return nil
    }
}

enum AutomaticPanelPlacementCalculator {
    static let sourceGap: CGFloat = 12
    static let workspaceInset: CGFloat = 8

    static func placement(
        visibleFrame: NSRect,
        panelSize: NSSize,
        source: NSRect,
        surface: TranslationSurface,
        preferredSide: AutomaticPanelPlacementSide? = nil
    ) -> PanelPlacementResult {
        let workspace = visibleFrame.insetBy(dx: workspaceInset, dy: workspaceInset)
        let priorities = preferredSide.map { [$0] } ?? priority(for: surface)
        let candidates = priorities.map {
            ($0, candidate(side: $0, panelSize: panelSize, source: source, workspace: workspace))
        }

        if preferredSide == nil,
           let firstAvailable = candidates.first(where: { workspace.contains($0.1) && !$0.1.intersects(source) }) {
            return PanelPlacementResult(frame: firstAvailable.1, automaticSide: firstAvailable.0)
        }

        let clamped = candidates.map { side, frame in
            (side, clamp(frame, to: workspace), overlapArea(frame: clamp(frame, to: workspace), source: source))
        }
        let best = clamped.enumerated().min { lhs, rhs in
            if lhs.element.2 != rhs.element.2 {
                return lhs.element.2 < rhs.element.2
            }
            return lhs.offset < rhs.offset
        }?.element
        let resolved = best ?? (.pointer, pointerFrame(panelSize: panelSize, pointer: nil, workspace: workspace), 0)
        return PanelPlacementResult(frame: resolved.1, automaticSide: resolved.0)
    }

    static func pointerPlacement(
        visibleFrame: NSRect,
        panelSize: NSSize,
        pointer: CGPoint?
    ) -> PanelPlacementResult {
        let workspace = visibleFrame.insetBy(dx: workspaceInset, dy: workspaceInset)
        return PanelPlacementResult(
            frame: pointerFrame(panelSize: panelSize, pointer: pointer, workspace: workspace),
            automaticSide: .pointer
        )
    }

    static func placementAfterWidthChange(
        visibleFrame: NSRect,
        panelSize: NSSize,
        source: NSRect,
        surface: TranslationSurface,
        currentSide: AutomaticPanelPlacementSide?
    ) -> PanelPlacementResult {
        if let currentSide {
            let preserved = placement(
                visibleFrame: visibleFrame,
                panelSize: panelSize,
                source: source,
                surface: surface,
                preferredSide: currentSide
            )
            if preservesGap(frame: preserved.frame, source: source, side: currentSide) {
                return preserved
            }
        }
        return placement(
            visibleFrame: visibleFrame,
            panelSize: panelSize,
            source: source,
            surface: surface
        )
    }

    static func maximumPanelHeight(
        baseMaximum: CGFloat,
        side: AutomaticPanelPlacementSide?,
        visibleFrame: NSRect,
        source: NSRect?
    ) -> CGFloat {
        guard let source else { return baseMaximum }
        let workspace = visibleFrame.insetBy(dx: workspaceInset, dy: workspaceInset)
        let directionalMaximum: CGFloat
        switch side {
        case .below:
            directionalMaximum = source.minY - sourceGap - workspace.minY
        case .above:
            directionalMaximum = workspace.maxY - source.maxY - sourceGap
        case .right, .left, .pointer, nil:
            return baseMaximum
        }
        return min(baseMaximum, max(ResultCardLayout.defaultPanelHeight, directionalMaximum))
    }

    private static func priority(for surface: TranslationSurface) -> [AutomaticPanelPlacementSide] {
        switch surface {
        case .selection: [.below, .above, .right, .left]
        case .screenshot: [.right, .left, .below, .above]
        case .quickInput: [.pointer]
        }
    }

    private static func candidate(
        side: AutomaticPanelPlacementSide,
        panelSize: NSSize,
        source: NSRect,
        workspace: NSRect
    ) -> NSRect {
        let centeredX = source.midX - panelSize.width / 2
        let centeredY = source.midY - panelSize.height / 2
        switch side {
        case .below:
            return NSRect(
                x: centeredX,
                y: source.minY - sourceGap - panelSize.height,
                width: panelSize.width,
                height: panelSize.height
            )
        case .above:
            return NSRect(
                x: centeredX,
                y: source.maxY + sourceGap,
                width: panelSize.width,
                height: panelSize.height
            )
        case .right:
            return NSRect(
                x: source.maxX + sourceGap,
                y: centeredY,
                width: panelSize.width,
                height: panelSize.height
            )
        case .left:
            return NSRect(
                x: source.minX - sourceGap - panelSize.width,
                y: centeredY,
                width: panelSize.width,
                height: panelSize.height
            )
        case .pointer:
            return pointerFrame(panelSize: panelSize, pointer: nil, workspace: workspace)
        }
    }

    private static func pointerFrame(
        panelSize: NSSize,
        pointer: CGPoint?,
        workspace: NSRect
    ) -> NSRect {
        let point = pointer ?? CGPoint(x: workspace.midX, y: workspace.midY)
        return clamp(
            NSRect(
                x: point.x - panelSize.width / 2,
                y: point.y - panelSize.height / 2,
                width: panelSize.width,
                height: panelSize.height
            ),
            to: workspace
        )
    }

    private static func preservesGap(
        frame: NSRect,
        source: NSRect,
        side: AutomaticPanelPlacementSide
    ) -> Bool {
        switch side {
        case .below:
            frame.maxY <= source.minY - sourceGap
        case .above:
            frame.minY >= source.maxY + sourceGap
        case .right:
            frame.minX >= source.maxX + sourceGap
        case .left:
            frame.maxX <= source.minX - sourceGap
        case .pointer:
            false
        }
    }

    private static func clamp(_ frame: NSRect, to workspace: NSRect) -> NSRect {
        var frame = frame
        frame.origin.x = min(max(frame.minX, workspace.minX), workspace.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, workspace.minY), workspace.maxY - frame.height)
        return frame
    }

    private static func overlapArea(frame: NSRect, source: NSRect) -> CGFloat {
        let intersection = frame.intersection(source)
        guard !intersection.isNull else { return 0 }
        return intersection.width * intersection.height
    }
}

struct PanelPlacementCalculator {
    static func placement(
        visibleFrame visible: NSRect,
        requestedWidth: CGFloat,
        requestedHeight: CGFloat,
        minimumWidth: CGFloat = 320,
        maximumWidth: CGFloat = 520,
        anchor: ScreenRect?,
        pointer: CGPoint?,
        surface: TranslationSurface? = nil,
        placement: TranslationWindowPlacement = .followMouse,
        fixedX: CGFloat = TranslationWindowPlacement.defaultFixedX,
        lastTopLeft: CGPoint? = nil,
        preferredAutomaticSide: AutomaticPanelPlacementSide? = nil
    ) -> PanelPlacementResult {
        let visibleMaximumWidth = max(minimumWidth, min(maximumWidth, visible.width - 16))
        let width = min(max(requestedWidth, minimumWidth), visibleMaximumWidth)
        let height = min(requestedHeight, visible.height * ResultCardLayout.maximumVisibleHeightRatio)
        let source = anchor.flatMap(validSourceRect)
        let panelSize = NSSize(width: width, height: height)

        if placement == .automatic {
            guard let source, let surface, surface != .quickInput else {
                return AutomaticPanelPlacementCalculator.pointerPlacement(
                    visibleFrame: visible,
                    panelSize: panelSize,
                    pointer: pointer
                )
            }
            return AutomaticPanelPlacementCalculator.placement(
                visibleFrame: visible,
                panelSize: panelSize,
                source: source,
                surface: surface,
                preferredSide: preferredAutomaticSide
            )
        }

        let followMouseSource = placement == .followMouse ? source : nil
        var x: CGFloat
        var y: CGFloat
        switch placement {
        case .automatic:
            preconditionFailure("Automatic placement is resolved above")
        case .centered:
            x = visible.midX
            y = visible.midY - height / 2
        case .fixedXCentered:
            x = fixedX.isFinite ? fixedX : visible.minX + TranslationWindowPlacement.defaultFixedX
            y = visible.midY - height / 2
        case .rememberLastPosition:
            x = lastTopLeft?.x ?? visible.midX - width / 2
            y = lastTopLeft.map { $0.y - height } ?? visible.midY - height / 2
        case .followMouse:
            x = followMouseSource?.midX ?? pointer?.x ?? visible.midX
            if let followMouseSource {
                let roomAbove = visible.maxY - followMouseSource.maxY
                let roomBelow = followMouseSource.minY - visible.minY
                y = roomAbove >= roomBelow
                    ? followMouseSource.maxY + 8
                    : followMouseSource.minY - height - 8
            } else {
                y = (pointer?.y ?? visible.midY) - height / 2
            }
        }
        if placement != .fixedXCentered && placement != .rememberLastPosition { x -= width / 2 }
        x = min(max(x, visible.minX + 8), visible.maxX - width - 8)
        y = min(max(y, visible.minY + 8), visible.maxY - height - 8)
        return PanelPlacementResult(
            frame: NSRect(x: x, y: y, width: width, height: height),
            automaticSide: nil
        )
    }

    static func frame(
        visibleFrame visible: NSRect,
        requestedWidth: CGFloat,
        requestedHeight: CGFloat,
        minimumWidth: CGFloat = 320,
        maximumWidth: CGFloat = 520,
        anchor: ScreenRect?,
        pointer: CGPoint?,
        surface: TranslationSurface? = nil,
        placement: TranslationWindowPlacement = .followMouse,
        fixedX: CGFloat = TranslationWindowPlacement.defaultFixedX,
        lastTopLeft: CGPoint? = nil
    ) -> NSRect {
        Self.placement(
            visibleFrame: visible,
            requestedWidth: requestedWidth,
            requestedHeight: requestedHeight,
            minimumWidth: minimumWidth,
            maximumWidth: maximumWidth,
            anchor: anchor,
            pointer: pointer,
            surface: surface,
            placement: placement,
            fixedX: fixedX,
            lastTopLeft: lastTopLeft
        ).frame
    }

    private static func validSourceRect(_ anchor: ScreenRect) -> NSRect? {
        let values = [anchor.x, anchor.y, anchor.width, anchor.height]
        guard values.allSatisfy(\.isFinite), anchor.width > 0, anchor.height > 0 else { return nil }
        return NSRect(x: anchor.x, y: anchor.y, width: anchor.width, height: anchor.height)
    }
}
