import AppKit

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
        preservesLeadingEdge: Bool,
        visibleFrame: NSRect
    ) -> NSRect {
        var frame = current
        let stableTop = frame.maxY
        let stableCenter = frame.midX
        frame.size.width = width
        frame.size.height = height
        frame.origin.x = preservesLeadingEdge ? frame.minX : stableCenter - width / 2
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
