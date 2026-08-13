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
    let shortcutManager: GlobalShortcutManager
    let settingsWindowCoordinator: MarlaSettingsWindowCoordinator

    init(
        settings: MarlaSettingsStore,
        enableSystemIntegrations: Bool
    ) {
        let installsInteractiveMonitors = enableSystemIntegrations && !MarlaRuntime.isUIAutomationSnapshot
        self.settings = settings
        sessionStore = TranslationSessionStore(settings: settings)
        panelCoordinator = FloatingPanelCoordinator(installEventMonitors: installsInteractiveMonitors)
        screenshotCoordinator = ScreenshotCaptureCoordinator()
        visionOCR = VisionOCRService()
        shortcutManager = GlobalShortcutManager(registerHotKeys: installsInteractiveMonitors)
        settingsWindowCoordinator = MarlaSettingsWindowCoordinator()
    }
}
