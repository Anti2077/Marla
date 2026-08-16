import AppKit
import Carbon
import Combine
import Foundation
import LocalAuthentication
import MarlaCore
import NaturalLanguage
import QuartzCore
import Security
import ScreenCaptureKit
import SwiftUI
import Vision

@MainActor
final class MarlaApplicationModel: ObservableObject {
    enum SelectionProbeResult: Equatable {
        case idle
        case success(text: String, hasBounds: Bool, applicationName: String?, surface: SurfaceType)
        case failure(message: String)
    }

    struct SelectionUIAutomationReport: Codable, Equatable {
        let result: String
        let errorCode: String?
        let textUTF16Length: Int?
        let contentFormat: TranslationContentFormat?
        let hasBounds: Bool?
        let sourceApplicationBundleID: String?
        let frontmostApplicationBundleIDAfterPresentation: String?
        let focusPreserved: Bool?
        let clipboardChangeCountDelta: Int
        let clipboardPreserved: Bool?
        let diagnostics: SelectionReadDiagnostics?
    }

    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var screenRecordingAuthorized = false
    @Published private(set) var selectionProbeResult: SelectionProbeResult = .idle
    @Published var bannerMessage: String?

    let services: MarlaApplicationServices
    var settings: MarlaSettingsStore { services.settings }
    var sessionStore: TranslationSessionStore { services.sessionStore }
    var panelCoordinator: FloatingPanelCoordinator { services.panelCoordinator }
    var screenshotCoordinator: ScreenshotCaptureCoordinator { services.screenshotCoordinator }
    var visionOCR: VisionOCRService { services.visionOCR }
    var shortcutManager: GlobalShortcutManager { services.shortcutManager }
    var settingsWindowCoordinator: MarlaSettingsWindowCoordinator { services.settingsWindowCoordinator }

    private let selectionReader: AccessibilitySelectionReader
    private var activeSelectionReadCancellation: SelectionReadCancellation?
    private var applicationDidFinishLaunchingObserver: NSObjectProtocol?
    private var didLoadCredentialsAfterLaunch = false

    init(
        selectionReader: AccessibilitySelectionReader = AccessibilitySelectionReader(),
        settings: MarlaSettingsStore = MarlaSettingsStore(),
        enableSystemIntegrations: Bool = !MarlaRuntime.isXcodePreview,
        accessibilityTrusted: Bool? = nil,
        screenRecordingAuthorized: Bool? = nil
    ) {
        self.selectionReader = selectionReader
        services = MarlaApplicationServices(
            settings: settings,
            enableSystemIntegrations: enableSystemIntegrations
        )
        panelCoordinator.attach(model: self)
        if enableSystemIntegrations {
            if !MarlaRuntime.isUIAutomationSnapshot {
                installCredentialVaultLaunchLoad()
            }
            refreshPermissions()
        }
        if let accessibilityTrusted {
            self.accessibilityTrusted = accessibilityTrusted
        }
        if let screenRecordingAuthorized {
            self.screenRecordingAuthorized = screenRecordingAuthorized
        }
        shortcutManager.onAction = { [weak self] action in
            switch action {
            case .selection: self?.translateSelection()
            case .screenshot: self?.translateScreenshot()
            case .quickInput: self?.showQuickInput()
            }
        }
        if let scenario = ProcessInfo.processInfo.environment["MARLA_UI_TEST_SCENARIO"] {
            DispatchQueue.main.async { [weak self] in
                self?.runUIAutomationScenario(scenario)
            }
        }
    }

    private func installCredentialVaultLaunchLoad() {
        applicationDidFinishLaunchingObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.loadCredentialsAfterLaunchIfNeeded()
            }
        }
    }

    func loadCredentialsAfterLaunchIfNeeded() {
        guard !didLoadCredentialsAfterLaunch else { return }
        didLoadCredentialsAfterLaunch = true
        settings.loadCredentialsAfterApplicationLaunch()
        if let applicationDidFinishLaunchingObserver {
            NotificationCenter.default.removeObserver(applicationDidFinishLaunchingObserver)
            self.applicationDidFinishLaunchingObserver = nil
        }
    }

    func refreshPermissions() {
        accessibilityTrusted = selectionReader.isTrusted
        screenRecordingAuthorized = CGPreflightScreenCaptureAccess()
    }

    func requestAccessibilityAccess() {
        accessibilityTrusted = selectionReader.requestAccess()
    }

    func requestScreenRecordingAccess() {
        screenRecordingAuthorized = CGRequestScreenCaptureAccess()
    }

    func translateSelection() {
        if let activeSelectionReadCancellation {
            activeSelectionReadCancellation.cancel()
            return
        }
        let readCancellation = SelectionReadCancellation()
        activeSelectionReadCancellation = readCancellation
        defer {
            if activeSelectionReadCancellation === readCancellation {
                activeSelectionReadCancellation = nil
            }
        }

        let pointer = NSEvent.mouseLocation
        let triggerApplication = NSWorkspace.shared.frontmostApplication
        if ProcessInfo.processInfo.environment["MARLA_UI_TEST_SCENARIO"] == "selection-live" {
            // Live acceptance arms this mode at launch and samples only when
            // the owner deliberately presses the real selection shortcut after
            // making a visible selection. It never presents a card or starts a
            // translation request.
            runSelectionUIAutomationAudit(
                triggerApplication: triggerApplication,
                isCancelled: { readCancellation.isCancelled }
            )
            return
        }
        let selectionAudit = selectionUIAutomationAuditIfRequested()
        guard accessibilityTrusted else {
            showPermissionError(
                "划词翻译需要辅助功能权限。",
                surface: .selection,
                pointer: pointer,
                recovery: .openAccessibilitySettings
            )
            scheduleSelectionUIAutomationReport(
                selection: nil,
                error: .accessibilityPermissionRequired,
                audit: selectionAudit
            )
            return
        }
        do {
            let selection = try selectionReader.readSelectionUsingProtectedCopy(
                from: triggerApplication,
                isCancelled: { readCancellation.isCancelled }
            )
            sessionStore.startContent(
                selection.content,
                surface: .selection,
                anchor: selection.bounds,
                pointer: pointer
            )
            panelCoordinator.showResult(store: sessionStore, at: selection.bounds, pointer: pointer, activate: false)
            scheduleSelectionUIAutomationReport(selection: selection, error: nil, audit: selectionAudit)
        } catch let error as SelectionReadingError {
            if error == .selectionCancelled {
                scheduleSelectionUIAutomationReport(selection: nil, error: error, audit: selectionAudit)
                return
            }
            sessionStore.startText("", surface: .selection, anchor: nil, pointer: pointer)
            sessionStore.fail(
                message(for: error),
                code: .invalidConfiguration,
                recovery: recovery(for: error)
            )
            panelCoordinator.showResult(store: sessionStore, at: nil, pointer: pointer, activate: false)
            scheduleSelectionUIAutomationReport(selection: nil, error: error, audit: selectionAudit)
        } catch {
            showPermissionError(
                "暂时无法读取当前选区。",
                surface: .selection,
                pointer: pointer,
                recovery: .quickInput
            )
            scheduleSelectionUIAutomationReport(selection: nil, error: nil, audit: selectionAudit)
        }
    }

    private struct SelectionUIAutomationAudit {
        let reportURL: URL
        let sourceApplication: NSRunningApplication?
        let sourceApplicationBundleID: String?
        let clipboardChangeCount: Int
        let clipboardSnapshot: PasteboardSnapshot?
    }

    private func selectionUIAutomationAuditIfRequested() -> SelectionUIAutomationAudit? {
        guard let path = ProcessInfo.processInfo.environment["MARLA_UI_TEST_SELECTION_REPORT_PATH"],
              !path.isEmpty
        else { return nil }
        let sourceApplication = NSWorkspace.shared.frontmostApplication
        return SelectionUIAutomationAudit(
            reportURL: URL(fileURLWithPath: path),
            sourceApplication: sourceApplication,
            sourceApplicationBundleID: sourceApplication?.bundleIdentifier,
            clipboardChangeCount: NSPasteboard.general.changeCount,
            clipboardSnapshot: try? PasteboardSnapshot.capture(from: .general)
        )
    }

    private func runSelectionUIAutomationAudit(
        triggerApplication: NSRunningApplication? = nil,
        isCancelled: () -> Bool = { false }
    ) {
        guard let audit = selectionUIAutomationAuditIfRequested() else { return }
        guard accessibilityTrusted else {
            scheduleSelectionUIAutomationReport(
                selection: nil,
                error: .accessibilityPermissionRequired,
                audit: audit
            )
            return
        }

        do {
            let selection = try selectionReader.readSelectionUsingProtectedCopy(
                from: triggerApplication ?? audit.sourceApplication,
                isCancelled: isCancelled
            )
            scheduleSelectionUIAutomationReport(selection: selection, error: nil, audit: audit)
        } catch let error as SelectionReadingError {
            scheduleSelectionUIAutomationReport(selection: nil, error: error, audit: audit)
        } catch {
            scheduleSelectionUIAutomationReport(selection: nil, error: nil, audit: audit)
        }
    }

    private func scheduleSelectionUIAutomationReport(
        selection: MarlaCore.TextSelection?,
        error: SelectionReadingError?,
        audit: SelectionUIAutomationAudit?
    ) {
        guard let audit else { return }
        let diagnostics = selectionReader.lastDiagnostics
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            let finalClipboardSnapshot = try? PasteboardSnapshot.capture(from: .general)
            let clipboardPreserved: Bool?
            if let initialClipboardSnapshot = audit.clipboardSnapshot,
               let finalClipboardSnapshot {
                clipboardPreserved = initialClipboardSnapshot == finalClipboardSnapshot
            } else {
                clipboardPreserved = nil
            }
            let report = SelectionUIAutomationReport(
                result: selection == nil ? "failure" : "success",
                errorCode: error.map(Self.selectionErrorCode),
                textUTF16Length: selection?.text.utf16.count,
                contentFormat: selection?.content.format,
                hasBounds: selection.map { $0.bounds != nil },
                sourceApplicationBundleID: selection?.applicationBundleID ?? audit.sourceApplicationBundleID,
                frontmostApplicationBundleIDAfterPresentation: frontmostBundleID,
                focusPreserved: audit.sourceApplicationBundleID.map { $0 == frontmostBundleID },
                clipboardChangeCountDelta: NSPasteboard.general.changeCount - audit.clipboardChangeCount,
                clipboardPreserved: clipboardPreserved,
                diagnostics: diagnostics
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            guard let data = try? encoder.encode(report) else { return }
            try? data.write(to: audit.reportURL, options: .atomic)
        }
    }

    private static func selectionErrorCode(_ error: SelectionReadingError) -> String {
        switch error {
        case .accessibilityPermissionRequired: "accessibilityPermissionRequired"
        case .focusedElementUnavailable: "focusedElementUnavailable"
        case .selectedTextUnavailable: "selectedTextUnavailable"
        case .emptySelection: "emptySelection"
        case .selectionSearchLimitReached: "selectionSearchLimitReached"
        case .selectionSearchTimedOut: "selectionSearchTimedOut"
        case .selectionCancelled: "selectionCancelled"
        case .copyFallbackUnavailable: "copyFallbackUnavailable"
        case .copyFallbackTimedOut: "copyFallbackTimedOut"
        case .clipboardRestoreFailed: "clipboardRestoreFailed"
        }
    }

    func translateScreenshot() {
        let pointer = NSEvent.mouseLocation
        guard screenRecordingAuthorized else {
            showPermissionError(
                "截图翻译需要屏幕录制权限。",
                surface: .screenshot,
                pointer: pointer,
                recovery: .openScreenRecordingSettings
            )
            return
        }
        let originatingApplication = NSWorkspace.shared.frontmostApplication
        let settingsWereVisible = settingsWindowCoordinator.suspendForScreenshotSelection()
        panelCoordinator.hide()
        screenshotCoordinator.present { [weak self] result in
            guard let self else { return }
            settingsWindowCoordinator.restoreAfterScreenshotSelection(wasVisible: settingsWereVisible)
            restoreFrontmostApplication(originatingApplication)
            switch result {
            case let .success(capture):
                let anchor = ScreenRect(
                    x: capture.globalRect.origin.x,
                    y: capture.globalRect.origin.y,
                    width: capture.globalRect.width,
                    height: capture.globalRect.height
                )
                let requestID = sessionStore.beginRecognizing(anchor: anchor, pointer: pointer)
                panelCoordinator.showResult(store: sessionStore, at: anchor, pointer: pointer, activate: false)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    do {
                        let document = try await visionOCR.recognize(capture.image)
                        sessionStore.submitRecognizedText(document.plainText, for: requestID)
                    } catch {
                        sessionStore.fail(
                            "没有识别到文字，请重新框选。",
                            code: .invalidResponse,
                            for: requestID,
                            recovery: .reselectScreenshot
                        )
                    }
                }
            case let .failure(error):
                if case ScreenshotError.cancelled = error {
                    sessionStore.close()
                } else {
                    sessionStore.startText("", surface: .screenshot, anchor: nil, pointer: pointer)
                    sessionStore.fail(
                        error.localizedDescription,
                        code: .invalidConfiguration,
                        recovery: .openScreenRecordingSettings
                    )
                    panelCoordinator.showResult(
                        store: sessionStore,
                        at: nil,
                        pointer: pointer,
                        activate: false
                    )
                }
            }
        }
    }

    private func restoreFrontmostApplication(_ application: NSRunningApplication?) {
        guard let application,
              application.processIdentifier != NSRunningApplication.current.processIdentifier else {
            return
        }
        application.activate(options: [])
    }

    func showQuickInput() {
        panelCoordinator.showQuickInput(store: sessionStore, pointer: NSEvent.mouseLocation)
    }

    private func runUIAutomationScenario(_ scenario: String) {
        if ProcessInfo.processInfo.environment["MARLA_UI_TEST_APPEARANCE"] == "dark" {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        } else if ProcessInfo.processInfo.environment["MARLA_UI_TEST_APPEARANCE"] == "light" {
            NSApp.appearance = NSAppearance(named: .aqua)
        }
        let source = """
        Marla keeps the translation close to the text you are reading.
        It preserves line breaks, code identifiers, and terminal arguments.
        """
        let translation = """
        Marla 会让译文始终靠近你正在阅读的文字。
        它会保留换行、代码标识符和终端参数。
        """

        if presentMarkdownUIAutomationFixture(named: scenario) {
            scheduleUIAutomationSnapshotIfRequested()
            return
        }

        switch scenario {
        case "menu":
            settings.exposeOnboardingForUIAutomation()
            panelCoordinator.showMenuAutomationSurface(model: self)
        case "menu-recents":
            [
                (TranslationSurface.selection, "Hello", "你好"),
                (.screenshot, "Build succeeded with no warnings.", "构建成功，没有警告。"),
                (.quickInput, "保持专注，不要离开当前窗口。", "Stay focused without leaving the current window.")
            ].forEach { surface, source, translation in
                sessionStore.installUIAutomationFixture(
                    surface: surface,
                    sourceText: source,
                    translation: translation,
                    state: .completed
                )
            }
            panelCoordinator.showMenuAutomationSurface(model: self)
        case "quick-input":
            showQuickInput()
        case "awaiting":
            sessionStore.installUIAutomationFixture(
                surface: .selection,
                sourceText: source,
                translation: "",
                state: .awaitingFirstToken
            )
            panelCoordinator.showResult(store: sessionStore, at: nil, pointer: NSEvent.mouseLocation, activate: true)
        case "streaming":
            sessionStore.installUIAutomationFixture(
                surface: .selection,
                sourceText: source,
                translation: "Marla 会让译文始终靠近你正在阅读的文字。",
                state: .streaming
            )
            panelCoordinator.showResult(store: sessionStore, at: nil, pointer: NSEvent.mouseLocation, activate: true)
        case "streaming-nonactivating":
            sessionStore.installUIAutomationFixture(
                surface: .selection,
                sourceText: source,
                translation: "Marla 会让译文始终靠近你正在阅读的文字。",
                state: .streaming
            )
            panelCoordinator.showResult(
                store: sessionStore,
                at: nil,
                pointer: NSEvent.mouseLocation,
                activate: false
            )
        case "streaming-growth":
            let stages = [
                "Marla 会让译文靠近正在阅读的文字。",
                Array(repeating: "译文会随着流式内容逐步增长。", count: 10).joined(),
                Array(repeating: "达到屏幕高度上限后，外框停止增长，后续译文在正文内部滚动。", count: 45).joined()
            ]
            sessionStore.installUIAutomationFixture(
                surface: .selection,
                sourceText: source,
                translation: stages[0],
                state: .streaming
            )
            panelCoordinator.showResult(store: sessionStore, at: nil, pointer: NSEvent.mouseLocation, activate: true)
            for (index, stage) in stages.dropFirst().enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + (Double(index + 1) * 0.25)) { [weak self] in
                    self?.sessionStore.installUIAutomationFixture(
                        surface: .selection,
                        sourceText: source,
                        translation: stage,
                        state: .streaming
                    )
                }
            }
        case "streaming-height-regression":
            sessionStore.installUIAutomationFixture(
                surface: .selection,
                sourceText: source,
                translation: "The inspection is complete.",
                state: .streaming
            )
            panelCoordinator.showResult(
                store: sessionStore,
                at: nil,
                pointer: NSEvent.mouseLocation,
                activate: false
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
                self?.sessionStore.installUIAutomationFixture(
                    surface: .selection,
                    sourceText: source,
                    translation: """
                    The inspection is complete, and currently no junk code remains that needs to be deleted. \
                    The Carbon cursor experiment, 16/50ms polling, panel mouse monitor, manual cursor stack, \
                    cursor-rect disabling, test-specific counters, and deprecated geometry APIs have been removed. \
                    The remaining event handling belongs to shortcuts and screenshot selection rather than resize.
                    """,
                    state: .streaming
                )
            }
        case "streaming-wide":
            sessionStore.installUIAutomationFixture(
                surface: .selection,
                sourceText: source,
                translation: Array(
                    repeating: "加宽结果卡后，长译文会减少换行，并按新的内容高度重新排版。",
                    count: 18
                ).joined(),
                state: .streaming
            )
            panelCoordinator.showResult(store: sessionStore, at: nil, pointer: NSEvent.mouseLocation, activate: true)
            DispatchQueue.main.async { [weak self] in
                self?.panelCoordinator.setResultWidthForUIAutomation(ResultCardLayout.maximumWidth)
            }
        case "comparison":
            sessionStore.installUIAutomationFixture(
                surface: .screenshot,
                sourceText: source,
                translation: translation,
                state: .completed,
                comparisonExpanded: true,
                pinned: true
            )
            panelCoordinator.showResult(store: sessionStore, at: nil, pointer: NSEvent.mouseLocation, activate: true)
        case "error":
            sessionStore.installUIAutomationFixture(
                surface: .quickInput,
                sourceText: source,
                translation: "Marla 会让译文靠近原文。",
                state: .failed(message: "网络连接中断，已保留部分译文。"),
                recovery: .retry
            )
            panelCoordinator.showResult(store: sessionStore, at: nil, pointer: NSEvent.mouseLocation, activate: true)
        case "long":
            sessionStore.installUIAutomationFixture(
                surface: .selection,
                sourceText: Array(repeating: source, count: 4).joined(separator: "\n"),
                translation: Array(repeating: translation, count: 4).joined(separator: "\n"),
                state: .completed
            )
            panelCoordinator.showResult(store: sessionStore, at: nil, pointer: NSEvent.mouseLocation, activate: true)
        case "settings":
            openSettings()
        case "settings-api", "settings-editor":
            if settings.profiles.isEmpty {
                let firstID = settings.addProfile()
                settings.updateProfile(
                    id: firstID,
                    name: "Qwen 快速",
                    baseURL: "https://api.example.com/v1",
                    modelName: "qwen-mt-turbo"
                )
                let secondID = settings.addProfile()
                settings.updateProfile(
                    id: secondID,
                    name: "本地代理",
                    baseURL: "http://127.0.0.1:8080/v1",
                    modelName: "local-model"
                )
            }
            openSettings()
        case "screenshot":
            screenshotCoordinator.presentUIAutomationFixture()
        case "screenshot-from-settings":
            openSettings()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.translateScreenshot()
            }
        case "selection-audit":
            let selectionDelay = ProcessInfo.processInfo.environment["MARLA_UI_TEST_SELECTION_DELAY"]
                .flatMap(Double.init) ?? 0
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, selectionDelay)) { [weak self] in
                // Acceptance sampling must never present UI or send selected text to a provider.
                self?.runSelectionUIAutomationAudit()
            }
        case "selection-live":
            // Unlike the one-shot audit, live mode waits for the real
            // ⌃⌥D shortcut so the owner can select text after launch.
            break
        case "translation-live":
            sessionStore.startText(
                "Hello",
                surface: .quickInput,
                anchor: nil,
                pointer: NSEvent.mouseLocation,
                activate: true
            )
            panelCoordinator.showResult(
                store: sessionStore,
                at: nil,
                pointer: NSEvent.mouseLocation,
                activate: true
            )
        default:
            break
        }

        scheduleUIAutomationSnapshotIfRequested()
    }

    private func scheduleUIAutomationSnapshotIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard let capturePath = environment["MARLA_UI_TEST_CAPTURE_PATH"], !capturePath.isEmpty else { return }
        let shouldExit = environment["MARLA_UI_TEST_EXIT_AFTER_CAPTURE"] == "1"
        let captureDelay = environment["MARLA_UI_TEST_CAPTURE_DELAY"].flatMap(Double.init) ?? 0.8
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, captureDelay)) {
            do {
                try Self.captureFrontmostApplicationWindow(to: capturePath)
            } catch {
                FileHandle.standardError.write(Data("UI snapshot failed: \(error.localizedDescription)\n".utf8))
            }
            if shouldExit {
                NSApp.terminate(nil)
            }
        }
    }

    private static func captureFrontmostApplicationWindow(to path: String) throws {
        let visibleWindows = NSApp.windows.filter(\.isVisible)
        let scenario = ProcessInfo.processInfo.environment["MARLA_UI_TEST_SCENARIO"]
        let capturesFullDisplaySurface = scenario == "screenshot" || scenario == "screenshot-from-settings"
        let visibleSheet = visibleWindows
            .lazy
            .compactMap(\.attachedSheet)
            .first(where: \.isVisible) ?? visibleWindows.first { $0.sheetParent != nil }
        let largestWindow = visibleWindows.max { lhs, rhs in
                lhs.frame.width * lhs.frame.height < rhs.frame.width * rhs.frame.height
            }
        let window = capturesFullDisplaySurface
            ? largestWindow
            : visibleSheet
                ?? (NSApp.keyWindow?.isVisible == true ? NSApp.keyWindow : nil)
                ?? largestWindow
        guard let window,
              let view = window.contentView?.superview ?? window.contentView else {
            throw UIAutomationSnapshotError.windowUnavailable
        }
        window.displayIfNeeded()
        view.layoutSubtreeIfNeeded()
        let bounds = view.bounds
        let scale = window.backingScaleFactor
        guard bounds.width > 0,
              bounds.height > 0,
              let representation = NSBitmapImageRep(
                  bitmapDataPlanes: nil,
                  pixelsWide: Int((bounds.width * scale).rounded(.up)),
                  pixelsHigh: Int((bounds.height * scale).rounded(.up)),
                  bitsPerSample: 8,
                  samplesPerPixel: 4,
                  hasAlpha: true,
                  isPlanar: false,
                  colorSpaceName: .deviceRGB,
                  bytesPerRow: 0,
                  bitsPerPixel: 0
              ) else {
            throw UIAutomationSnapshotError.bitmapUnavailable
        }
        representation.size = bounds.size
        view.cacheDisplay(in: bounds, to: representation)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw UIAutomationSnapshotError.encodingFailed
        }
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    func openSettings() {
        settingsWindowCoordinator.present(settings: settings, appModel: self)
    }

    func showRecentTranslation(id: UUID) {
        guard let session = sessionStore.restoreRecentTranslation(id: id) else { return }
        panelCoordinator.showResult(
            store: sessionStore,
            at: nil,
            pointer: session.pointer,
            activate: true
        )
    }

    func performRecovery(_ action: CardRecoveryAction) {
        switch action {
        case .openSettings:
            openSettings()
        case .openAccessibilitySettings:
            openPrivacySettings(pane: "Privacy_Accessibility")
        case .openScreenRecordingSettings:
            openPrivacySettings(pane: "Privacy_ScreenCapture")
        case .quickInput:
            showQuickInput()
        case .reselectScreenshot:
            panelCoordinator.hide()
            translateScreenshot()
        case .retry:
            sessionStore.retry()
        }
    }

    func probeCurrentSelection() {
        do {
            let selection = try selectionReader.readSelectionUsingProtectedCopy(
                from: NSWorkspace.shared.frontmostApplication
            )
            selectionProbeResult = .success(
                text: selection.text,
                hasBounds: selection.bounds != nil,
                applicationName: selection.applicationName,
                surface: selection.applicationBundleID.map { RustCoreBridge.classifySurface(applicationBundleID: $0) } ?? .unknown
            )
        } catch let error as SelectionReadingError {
            selectionProbeResult = .failure(message: message(for: error))
        } catch {
            selectionProbeResult = .failure(message: "读取选区时发生未知错误。")
        }
        refreshPermissions()
    }

    private func showPermissionError(
        _ message: String,
        surface: TranslationSurface,
        pointer: CGPoint,
        recovery: CardRecoveryAction
    ) {
        sessionStore.startText("", surface: surface, anchor: nil, pointer: pointer)
        sessionStore.fail(message, code: .invalidConfiguration, recovery: recovery)
        panelCoordinator.showResult(store: sessionStore, at: nil, pointer: pointer, activate: true)
    }

    private func openPrivacySettings(pane: String) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(pane)"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func recovery(for error: SelectionReadingError) -> CardRecoveryAction {
        switch error {
        case .accessibilityPermissionRequired:
            .openAccessibilitySettings
        case .focusedElementUnavailable,
             .selectedTextUnavailable,
             .emptySelection,
             .selectionSearchLimitReached,
             .selectionSearchTimedOut,
             .selectionCancelled,
             .copyFallbackUnavailable,
             .copyFallbackTimedOut,
             .clipboardRestoreFailed:
            .quickInput
        }
    }

    private func message(for error: SelectionReadingError) -> String {
        switch error {
        case .accessibilityPermissionRequired: "请先授予辅助功能权限。"
        case .focusedElementUnavailable: "无法读取当前聚焦的界面元素。"
        case .selectedTextUnavailable: "当前应用没有提供可读取的选中文本。"
        case .emptySelection: "当前没有选中文字。试试 ⌃⌥Space 快速输入。"
        case .selectionSearchLimitReached: "当前应用的选区结构过于复杂，读取已安全停止。"
        case .selectionSearchTimedOut: "当前应用响应选区读取超时，请重试或使用快速输入。"
        case .selectionCancelled: "已取消本次受保护取词。"
        case .copyFallbackUnavailable: "受保护 Copy 没有取得新的选区内容，请重试或使用快速输入。"
        case .copyFallbackTimedOut: "受保护 Copy 等待应用响应超时，请重试或使用快速输入。"
        case .clipboardRestoreFailed: "受保护取词未能安全恢复剪贴板，已停止翻译请求。"
        }
    }
}

private enum UIAutomationSnapshotError: LocalizedError {
    case windowUnavailable
    case bitmapUnavailable
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .windowUnavailable: "没有可截图的 Marla 窗口。"
        case .bitmapUnavailable: "无法创建 UI 截图缓冲区。"
        case .encodingFailed: "无法编码 UI 截图。"
        }
    }
}
