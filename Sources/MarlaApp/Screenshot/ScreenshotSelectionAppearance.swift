import SwiftUI

private struct ScreenshotSelectionChrome: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let opaque = reduceTransparency
            || ProcessInfo.processInfo.environment["MARLA_UI_TEST_REDUCE_TRANSPARENCY"] == "1"
        let strong = contrast == .increased
            || ProcessInfo.processInfo.environment["MARLA_UI_TEST_INCREASE_CONTRAST"] == "1"
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        content
            .background {
                if opaque { shape.fill(Color(white: 0.12)) }
                else { shape.fill(.black.opacity(0.78)).background(.ultraThinMaterial, in: shape) }
            }
            .clipShape(shape)
            .overlay { shape.stroke(.white.opacity(strong ? 0.9 : 0.28), lineWidth: strong ? 1.5 : 0.5) }
    }
}

extension View {
    func screenshotSelectionChrome(cornerRadius: CGFloat) -> some View {
        modifier(ScreenshotSelectionChrome(cornerRadius: cornerRadius))
    }
}
