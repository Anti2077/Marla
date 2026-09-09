import AppKit
import MarlaCore

enum ResultPanelHorizontalAnchor: Equatable {
    case leading
    case center
    case trailing
}

@MainActor
enum ResultPanelWindowSizing {
    static func apply(to panel: NSPanel, enabled: Bool, visibleFrame: NSRect) {
        guard enabled else {
            panel.styleMask.remove(.resizable)
            panel.minSize = .zero
            panel.maxSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
            return
        }
        panel.styleMask.insert(.resizable)
        panel.minSize = NSSize(
            width: ResultCardLayout.minimumWidth,
            height: ResultCardLayout.defaultPanelHeight
        )
        panel.maxSize = NSSize(
            width: ResultCardLayout.maximumPanelWidth(visibleWidth: visibleFrame.width),
            height: ResultCardLayout.maximumPanelHeight(visibleHeight: visibleFrame.height)
        )
    }
}

enum ResultPanelWidthPresetFrameCalculator {
    static func targetFrame(
        current: NSRect,
        width: CGFloat,
        height: CGFloat,
        horizontalAnchor: ResultPanelHorizontalAnchor,
        visibleFrame: NSRect
    ) -> NSRect {
        var frame = current
        let stableTop = frame.maxY
        let stableLeading = frame.minX
        let stableCenter = frame.midX
        let stableTrailing = frame.maxX
        frame.size.width = width
        frame.size.height = height
        switch horizontalAnchor {
        case .leading:
            frame.origin.x = stableLeading
        case .center:
            frame.origin.x = stableCenter - width / 2
        case .trailing:
            frame.origin.x = stableTrailing - width
        }
        frame.origin.x = min(
            max(frame.origin.x, visibleFrame.minX + 8),
            visibleFrame.maxX - width - 8
        )
        frame.origin.y = min(
            max(stableTop - height, visibleFrame.minY + 8),
            visibleFrame.maxY - height - 8
        )
        return frame
    }
}

struct ResultPanelWidthChangeResult {
    let frame: NSRect
    let maximumHeight: CGFloat
    let automaticSide: AutomaticPanelPlacementSide?
}

struct AutomaticPanelPlacementContext {
    let source: NSRect
    let surface: TranslationSurface
    var side: AutomaticPanelPlacementSide
}

@MainActor
enum ResultPanelWidthChangeCalculator {
    static func target(
        currentFrame: NSRect,
        width: CGFloat,
        visibleFrame: NSRect,
        placement: TranslationWindowPlacement,
        horizontalAnchor: ResultPanelHorizontalAnchor,
        currentMaximumHeight: CGFloat,
        automaticContext: AutomaticPanelPlacementContext?,
        session: CardSession?,
        layout: ResultPanelLayoutModel
    ) -> ResultPanelWidthChangeResult {
        let preferredHeight: (CGFloat) -> CGFloat = { maximumHeight in
            guard let session else { return currentFrame.height }
            return ResultCardLayout.preferredPanelHeight(
                session: session,
                cardWidth: width,
                maximumPanelHeight: maximumHeight,
                markdownProjection: layout.markdownProjection,
                sourceMarkdownProjection: layout.sourceMarkdownProjection
            )
        }
        guard placement == .automatic,
              let automaticContext else {
            return ResultPanelWidthChangeResult(
                frame: ResultPanelWidthPresetFrameCalculator.targetFrame(
                    current: currentFrame,
                    width: width,
                    height: preferredHeight(currentMaximumHeight),
                    horizontalAnchor: placement == .rememberLastPosition ? .leading : horizontalAnchor,
                    visibleFrame: visibleFrame
                ),
                maximumHeight: currentMaximumHeight,
                automaticSide: nil
            )
        }

        let sidePlacement = AutomaticPanelPlacementCalculator.placementAfterWidthChange(
            visibleFrame: visibleFrame,
            panelSize: NSSize(width: width, height: ResultCardLayout.defaultPanelHeight),
            source: automaticContext.source,
            surface: automaticContext.surface,
            currentSide: automaticContext.side
        )
        let maximumHeight = AutomaticPanelPlacementCalculator.maximumPanelHeight(
            baseMaximum: ResultCardLayout.maximumPanelHeight(visibleHeight: visibleFrame.height),
            side: sidePlacement.automaticSide,
            visibleFrame: visibleFrame,
            source: automaticContext.source
        )
        let placement = AutomaticPanelPlacementCalculator.placement(
            visibleFrame: visibleFrame,
            panelSize: NSSize(width: width, height: preferredHeight(maximumHeight)),
            source: automaticContext.source,
            surface: automaticContext.surface,
            preferredSide: sidePlacement.automaticSide
        )
        return ResultPanelWidthChangeResult(
            frame: placement.frame,
            maximumHeight: maximumHeight,
            automaticSide: placement.automaticSide
        )
    }
}

struct ResultPanelWidthPresetTransition {
    private(set) var targetWidth: CGFloat?

    mutating func begin(targetWidth: CGFloat, currentWidth: CGFloat) {
        self.targetWidth = abs(targetWidth - currentWidth) > 0.5 ? targetWidth : nil
    }

    mutating func consumesResize(at width: CGFloat) -> Bool {
        guard let targetWidth else { return false }
        if abs(width - targetWidth) <= 0.5 {
            self.targetWidth = nil
        }
        return true
    }

    mutating func reset() {
        targetWidth = nil
    }
}
