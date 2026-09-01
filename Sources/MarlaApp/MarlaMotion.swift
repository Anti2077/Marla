import SwiftUI

/// Shared motion semantics for Marla's native presentation layer.
///
/// Durations are grouped by purpose instead of being applied universally:
/// feedback is fastest, local content changes are slightly slower, and the
/// existing shortcut morph remains the longest transition in the product.
enum MarlaMotion {
    static let reducedOpacityDuration: TimeInterval = 0.10
    static let feedbackDuration: TimeInterval = 0.12
    static let contentDuration: TimeInterval = 0.16
    static let layoutDuration: TimeInterval = 0.18
    static let reorderDuration: TimeInterval = 0.22
    static let shortcutMorphDuration: TimeInterval = 0.32
    static let screenshotConfirmationDuration: TimeInterval = 0.12
    static let breathingDuration: TimeInterval = 0.90

    static let feedback = Animation.easeOut(duration: feedbackDuration)
    static let content = Animation.easeOut(duration: contentDuration)
    static let layout = Animation.smooth(duration: layoutDuration)
    static let reorder = Animation.snappy(duration: reorderDuration)
    static let shortcutMorph = Animation.smooth(duration: shortcutMorphDuration)
    static let reducedOpacity = Animation.easeOut(duration: reducedOpacityDuration)
    static let breathing = Animation.easeInOut(duration: breathingDuration)

    static func animation(
        _ animation: Animation,
        reducesMotion: Bool,
        reducedMotionAnimation: Animation? = nil
    ) -> Animation? {
        reducesMotion ? reducedMotionAnimation : animation
    }

    static func contentTransition(
        reducesMotion: Bool,
        offset: CGFloat = 4
    ) -> AnyTransition {
        if reducesMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: offset)),
            removal: .opacity
        )
    }
}
