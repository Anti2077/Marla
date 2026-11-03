import Foundation

/// A replaceable trajectory. The capture rectangle never reads this presentation state.
struct ScreenshotSelectionTransition {
    private(set) var displayed = CGRect.zero
    private(set) var target = CGRect.zero
    private(set) var isRunning = false
    private var origin = CGRect.zero
    private var startedAt: TimeInterval = 0
    let duration: TimeInterval

    init(duration: TimeInterval = MarlaMotion.screenshotSnapDuration) {
        self.duration = duration
    }

    mutating func update(_ rect: CGRect, at time: TimeInterval, animated: Bool) {
        guard rect != target || (!animated && isRunning) else { return }
        advance(at: time)
        let canAnimate = animated && duration > 0 && !displayed.isEmpty && !rect.isEmpty
        origin = displayed
        target = rect
        startedAt = time
        isRunning = canAnimate
        if !canAnimate { displayed = rect }
    }

    mutating func advance(at time: TimeInterval) {
        guard isRunning else { return }
        let progress = min(max((time - startedAt) / duration, 0), 1)
        let eased = CGFloat(1 - pow(1 - progress, 3))
        displayed = CGRect(
            x: origin.minX + (target.minX - origin.minX) * eased,
            y: origin.minY + (target.minY - origin.minY) * eased,
            width: origin.width + (target.width - origin.width) * eased,
            height: origin.height + (target.height - origin.height) * eased
        )
        if progress >= 1 { displayed = target; isRunning = false }
    }
}
