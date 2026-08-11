#if DEBUG
import MarlaCore
import SwiftUI

@MainActor
private enum MarlaPreviewFixtures {
    static let source = """
    Marla keeps the translation close to the text you are reading.
    It preserves line breaks, code identifiers, and terminal arguments.
    """

    static let translation = """
    Marla 会让译文始终靠近你正在阅读的文字。
    它会保留换行、代码标识符和终端参数。
    """

    static func settings(apiConfigured: Bool = true, onboardingSkipped: Bool = true) -> MarlaSettingsStore {
        let suiteName = "com.marla.preview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        let keychain = KeychainCredentialStore(
            service: "com.marla.preview",
            account: UUID().uuidString
        )
        let settings = MarlaSettingsStore(defaults: defaults, keychain: keychain)
        settings.baseURL = apiConfigured ? "https://api.example.com/v1" : ""
        settings.modelName = apiConfigured ? "qwen-mt-turbo" : ""
        if onboardingSkipped {
            settings.skipOnboarding()
        } else {
            settings.resetOnboarding()
        }
        return settings
    }

    static func model(
        apiConfigured: Bool = true,
        onboardingSkipped: Bool = true,
        accessibilityTrusted: Bool = true,
        screenRecordingAuthorized: Bool = true
    ) -> MarlaApplicationModel {
        MarlaApplicationModel(
            settings: settings(apiConfigured: apiConfigured, onboardingSkipped: onboardingSkipped),
            enableSystemIntegrations: false,
            accessibilityTrusted: accessibilityTrusted,
            screenRecordingAuthorized: screenRecordingAuthorized
        )
    }

    static func sessionStore(
        surface: TranslationSurface,
        translation: String,
        state: TranslationSessionState,
        comparisonExpanded: Bool = false,
        pinned: Bool = false,
        recovery: CardRecoveryAction? = nil
    ) -> TranslationSessionStore {
        let store = TranslationSessionStore(settings: settings(apiConfigured: false))
        store.installUIAutomationFixture(
            surface: surface,
            sourceText: source,
            translation: translation,
            state: state,
            comparisonExpanded: comparisonExpanded,
            pinned: pinned,
            recovery: recovery
        )
        return store
    }

    static func modelWithRecents() -> MarlaApplicationModel {
        let model = model()
        let fixtures: [(TranslationSurface, String, String)] = [
            (.selection, "Hello", "你好"),
            (.screenshot, "Build succeeded with no warnings.", "构建成功，没有警告。"),
            (.quickInput, "保持专注，不要离开当前窗口。", "Stay focused without leaving the current window.")
        ]
        fixtures.forEach { surface, source, translation in
            model.sessionStore.installUIAutomationFixture(
                surface: surface,
                sourceText: source,
                translation: translation,
                state: .completed
            )
        }
        return model
    }
}

private struct PreviewPanel<Content: View>: View {
    let width: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(40)
            .frame(width: width)
            .background(DesignTokens.background)
    }
}

#Preview("Menu Bar - Ready") {
    MenuBarView(model: MarlaPreviewFixtures.model())
}

#Preview("Menu Bar - Recents") {
    MenuBarView(model: MarlaPreviewFixtures.modelWithRecents())
}

#Preview("Menu Bar - Setup") {
    MenuBarView(
        model: MarlaPreviewFixtures.model(
            apiConfigured: false,
            onboardingSkipped: false,
            accessibilityTrusted: false,
            screenRecordingAuthorized: false
        )
    )
}

#Preview("Settings") {
    let model = MarlaPreviewFixtures.model(apiConfigured: true)
    SettingsView(settings: model.settings, appModel: model)
}

#Preview("Card - Awaiting") {
    PreviewPanel(width: 560) {
        TranslationCardView(
            store: MarlaPreviewFixtures.sessionStore(
                surface: .selection,
                translation: "",
                state: .awaitingFirstToken
            ),
            onClose: {},
            onRecovery: { _ in }
        )
        .environment(\.marlaReduceMotionOverride, true)
    }
}

#Preview("Card - Streaming") {
    PreviewPanel(width: 560) {
        TranslationCardView(
            store: MarlaPreviewFixtures.sessionStore(
                surface: .selection,
                translation: "Marla 会让译文始终靠近你正在阅读的文字。",
                state: .streaming
            ),
            onClose: {},
            onRecovery: { _ in }
        )
        .environment(\.marlaReduceMotionOverride, true)
    }
}

#Preview("Card - Long Streaming") {
    PreviewPanel(width: 560) {
        TranslationCardView(
            store: MarlaPreviewFixtures.sessionStore(
                surface: .selection,
                translation: Array(repeating: "达到高度上限后，译文会在卡片内部继续滚动。", count: 40).joined(),
                state: .streaming
            ),
            onClose: {},
            onRecovery: { _ in },
            maximumPanelHeight: 540
        )
        .environment(\.marlaReduceMotionOverride, true)
    }
}

#Preview("Card - Comparison Pinned") {
    PreviewPanel(width: 560) {
        TranslationCardView(
            store: MarlaPreviewFixtures.sessionStore(
                surface: .screenshot,
                translation: MarlaPreviewFixtures.translation,
                state: .completed,
                comparisonExpanded: true,
                pinned: true
            ),
            onClose: {},
            onRecovery: { _ in }
        )
        .environment(\.marlaReduceMotionOverride, true)
    }
}

#Preview("Card - Error") {
    PreviewPanel(width: 560) {
        TranslationCardView(
            store: MarlaPreviewFixtures.sessionStore(
                surface: .quickInput,
                translation: "Marla 会让译文靠近原文。",
                state: .failed(message: "网络连接中断，已保留部分译文。"),
                recovery: .retry
            ),
            onClose: {},
            onRecovery: { _ in }
        )
        .environment(\.marlaReduceMotionOverride, true)
    }
}

#Preview("Quick Input") {
    PreviewPanel(width: 520) {
        QuickInputView(
            store: TranslationSessionStore(settings: MarlaPreviewFixtures.settings(apiConfigured: false)),
            onClose: {}
        )
    }
}
#endif
