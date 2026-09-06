import AppKit

/// Application-scoped dependencies owned by the native host.
///
/// Keeping construction here makes `MarlaApplicationModel` responsible for
/// lifecycle and intent routing instead of also being the dependency
/// container for every platform coordinator.
@MainActor
final class MarlaApplicationServices {
    let settings: MarlaSettingsStore
    let sessionStore: TranslationSessionStore
    let panelCoordinator: FloatingPanelCoordinator
    let screenshotCoordinator: ScreenshotCaptureCoordinator
    let visionOCR: VisionOCRService
    let glmOCR: GLMOCRService
    let inPlaceTranslation: InPlaceTranslationService
    let screenshotTranslationOverlay: ScreenshotTranslationOverlayCoordinator
    let shortcutManager: GlobalShortcutManager
    let settingsWindowCoordinator: MarlaSettingsWindowCoordinator

    init(
        settings: MarlaSettingsStore,
        enableSystemIntegrations: Bool
    ) {
        let installsInteractiveMonitors = enableSystemIntegrations && !MarlaRuntime.isUIAutomationSnapshot
        self.settings = settings
        sessionStore = TranslationSessionStore(settings: settings)
        let testsInPlaceClicks = enableSystemIntegrations
            && ProcessInfo.processInfo.environment["MARLA_UI_TEST_SCENARIO"] == "in-place-overlay-interactive"
        panelCoordinator = FloatingPanelCoordinator(installEventMonitors: installsInteractiveMonitors || testsInPlaceClicks)
        screenshotCoordinator = ScreenshotCaptureCoordinator()
        visionOCR = VisionOCRService()
        glmOCR = GLMOCRService()
        inPlaceTranslation = InPlaceTranslationService()
        screenshotTranslationOverlay = ScreenshotTranslationOverlayCoordinator()
        shortcutManager = GlobalShortcutManager(registerHotKeys: installsInteractiveMonitors)
        settingsWindowCoordinator = MarlaSettingsWindowCoordinator()
    }
}
