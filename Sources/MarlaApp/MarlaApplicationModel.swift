import AppKit
import Carbon
import Combine
import Foundation
import MarlaCore
import QuartzCore
import Security
import ScreenCaptureKit
import SwiftUI
import Vision

@MainActor
final class KeychainCredentialStore: @unchecked Sendable {
    let service: String
    let account: String

    init(service: String = "com.marla.app", account: String = "translation-api-key") {
        self.service = service
        self.account = account
    }

    func scoped(to profileID: UUID) -> KeychainCredentialStore {
        KeychainCredentialStore(service: service, account: "translation-api-key.\(profileID.uuidString)")
    }

    var hasCredential: Bool { read() != nil }

    func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    func save(_ value: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            guard SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess else {
                throw KeychainError.saveFailed
            }
        } else if status != errSecSuccess {
            throw KeychainError.saveFailed
        }
    }

    func remove() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: LocalizedError {
    case saveFailed

    var errorDescription: String? { "无法保存 API Key。" }
}

struct TranslationAPIProfile: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var baseURL: String
    var modelName: String

    init(id: UUID = UUID(), name: String = "新配置", baseURL: String = "", modelName: String = "") {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.modelName = modelName
    }

    var isConfigured: Bool {
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        return ["http", "https"].contains(url.scheme?.lowercased() ?? "") &&
            url.host != nil &&
            !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

@MainActor
final class MarlaSettingsStore: ObservableObject {
    @Published var profiles: [TranslationAPIProfile] {
        didSet { saveProfiles() }
    }
    @Published var defaultProfileID: UUID? {
        didSet { defaults.set(defaultProfileID?.uuidString, forKey: Keys.defaultProfileID) }
    }
    var baseURL: String {
        get { defaultProfile?.baseURL ?? "" }
        set { updateProfile(id: defaultProfile?.id, baseURL: newValue) }
    }
    var modelName: String {
        get { defaultProfile?.modelName ?? "" }
        set { updateProfile(id: defaultProfile?.id, modelName: newValue) }
    }
    @Published var defaultTarget: TranslationTarget {
        didSet {
            defaults.set(defaultTarget.mode.rawValue, forKey: Keys.targetMode)
            defaults.set(defaultTarget.language, forKey: Keys.targetLanguage)
        }
    }
    @Published var forceTouchExperimental: Bool {
        didSet { defaults.set(forceTouchExperimental, forKey: Keys.forceTouch) }
    }
    @Published private(set) var credentialRevision = 0
    @Published private(set) var onboardingSkipped: Bool

    let keychain: KeychainCredentialStore
    private let defaults: UserDefaults

    private enum Keys {
        static let profiles = "translationAPIProfiles.v1"
        static let defaultProfileID = "translationDefaultProfileID"
        static let baseURL = "translationBaseURL"
        static let modelName = "translationModelName"
        static let targetMode = "translationTargetMode"
        static let targetLanguage = "translationTargetLanguage"
        static let forceTouch = "forceTouchExperimental"
        static let onboardingSkipped = "onboardingSkipped"
    }

    init(defaults: UserDefaults = .standard, keychain: KeychainCredentialStore = KeychainCredentialStore()) {
        self.defaults = defaults
        self.keychain = keychain
        if let data = defaults.data(forKey: Keys.profiles),
           let decoded = try? JSONDecoder().decode([TranslationAPIProfile].self, from: data),
           !decoded.isEmpty {
            profiles = decoded
            let storedID = defaults.string(forKey: Keys.defaultProfileID).flatMap(UUID.init(uuidString:))
            defaultProfileID = decoded.contains(where: { $0.id == storedID }) ? storedID : decoded.first?.id
        } else {
            let legacyURL = defaults.string(forKey: Keys.baseURL) ?? ""
            let legacyModel = defaults.string(forKey: Keys.modelName) ?? ""
            if !legacyURL.isEmpty || !legacyModel.isEmpty || keychain.hasCredential {
                let migrated = TranslationAPIProfile(name: "默认配置", baseURL: legacyURL, modelName: legacyModel)
                profiles = [migrated]
                defaultProfileID = migrated.id
                if let legacyKey = keychain.read() {
                    try? keychain.scoped(to: migrated.id).save(legacyKey)
                }
            } else {
                profiles = []
                defaultProfileID = nil
            }
        }
        let mode = TranslationTargetMode(rawValue: defaults.string(forKey: Keys.targetMode) ?? "automatic") ?? .automatic
        defaultTarget = TranslationTarget(mode: mode, language: defaults.string(forKey: Keys.targetLanguage))
        forceTouchExperimental = defaults.bool(forKey: Keys.forceTouch)
        onboardingSkipped = defaults.bool(forKey: Keys.onboardingSkipped)
        saveProfiles()
    }

    var defaultProfile: TranslationAPIProfile? {
        guard let defaultProfileID else { return profiles.first }
        return profiles.first(where: { $0.id == defaultProfileID }) ?? profiles.first
    }

    var apiKey: String? { defaultProfile.flatMap { apiKey(for: $0.id) } }
    var hasAPIConfiguration: Bool {
        defaultProfile?.isConfigured == true
    }

    func profile(id: UUID?) -> TranslationAPIProfile? {
        guard let id else { return defaultProfile }
        return profiles.first(where: { $0.id == id })
    }

    func apiKey(for profileID: UUID) -> String? {
        keychain.scoped(to: profileID).read()
    }

    func hasCredential(for profileID: UUID) -> Bool {
        apiKey(for: profileID) != nil
    }

    func endpoint(for profileID: UUID?) -> TranslationEndpointConfiguration? {
        guard let profile = profile(id: profileID), profile.isConfigured else { return nil }
        return TranslationEndpointConfiguration(
            baseURL: profile.baseURL,
            model: profile.modelName,
            apiKey: apiKey(for: profile.id)
        )
    }

    @discardableResult
    func addProfile() -> UUID {
        let profile = TranslationAPIProfile(name: "新配置")
        profiles.append(profile)
        if defaultProfileID == nil { defaultProfileID = profile.id }
        return profile.id
    }

    func updateProfile(id: UUID?, name: String? = nil, baseURL: String? = nil, modelName: String? = nil) {
        let targetID = id ?? defaultProfileID ?? profiles.first?.id ?? addProfile()
        guard let index = profiles.firstIndex(where: { $0.id == targetID }) else { return }
        if let name { profiles[index].name = name }
        if let baseURL { profiles[index].baseURL = baseURL }
        if let modelName { profiles[index].modelName = modelName }
        if defaultProfileID == nil { defaultProfileID = targetID }
        saveProfiles()
    }

    func setDefaultProfile(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        defaultProfileID = id
    }

    func moveProfile(id: UUID, by offset: Int) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + offset
        guard profiles.indices.contains(destination) else { return }
        profiles.swapAt(index, destination)
    }

    func removeProfile(id: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        keychain.scoped(to: id).remove()
        profiles.remove(at: index)
        if defaultProfileID == id { defaultProfileID = profiles.first?.id }
    }

    func updateAPIKey(_ value: String) throws {
        guard let profileID = defaultProfile?.id else { return }
        try updateAPIKey(value, for: profileID)
    }

    func updateAPIKey(_ value: String, for profileID: UUID) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            keychain.scoped(to: profileID).remove()
        } else {
            try keychain.scoped(to: profileID).save(value)
        }
        credentialRevision += 1
    }

    func removeAPIKey() {
        guard let profileID = defaultProfile?.id else { return }
        keychain.scoped(to: profileID).remove()
        credentialRevision += 1
    }

    private func saveProfiles() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: Keys.profiles)
    }

    func skipOnboarding() {
        onboardingSkipped = true
        defaults.set(true, forKey: Keys.onboardingSkipped)
    }

    func resetOnboarding() {
        onboardingSkipped = false
        defaults.set(false, forKey: Keys.onboardingSkipped)
    }

    func exposeOnboardingForUIAutomation() {
        onboardingSkipped = false
    }
}

@MainActor
enum SettingsWindowStyle {
    static func apply(to window: NSWindow) {
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        apply(to: window.contentView)
    }

    static func apply(to contentView: NSView?) {
        guard let contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = DesignTokens.radiusL
        contentView.layer?.cornerCurve = .continuous
        contentView.layer?.masksToBounds = true
    }
}

@MainActor
final class MarlaSettingsWindowCoordinator: NSObject, NSWindowDelegate {
    private(set) var window: NSWindow?

    init(window: NSWindow? = nil) {
        self.window = window
        super.init()
    }

    func present(settings: MarlaSettingsStore, appModel: MarlaApplicationModel) {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Marla 设置"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 820, height: 560)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = NSHostingView(
            rootView: SettingsView(settings: settings, appModel: appModel)
        )
        SettingsWindowStyle.apply(to: window)
        window.center()
        window.delegate = self
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func suspendForScreenshotSelection() -> Bool {
        guard let window, window.isVisible else { return false }
        window.orderOut(nil)
        return true
    }

    func restoreAfterScreenshotSelection(wasVisible: Bool) {
        guard wasVisible, let window else { return }
        window.orderBack(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

enum CardRecoveryAction: Equatable {
    case openSettings
    case openAccessibilitySettings
    case openScreenRecordingSettings
    case quickInput
    case reselectScreenshot
    case retry

    var title: String {
        switch self {
        case .openSettings: "打开设置"
        case .openAccessibilitySettings, .openScreenRecordingSettings: "前往系统设置"
        case .quickInput: "打开快速输入"
        case .reselectScreenshot: "重新框选"
        case .retry: "重试"
        }
    }
}

extension TranslationSurface {
    var symbolName: String {
        switch self {
        case .selection: "text.viewfinder"
        case .screenshot: "viewfinder"
        case .quickInput: "keyboard"
        }
    }
}

struct CardSession: Identifiable, Equatable {
    var id: UUID
    let surface: TranslationSurface
    var profileID: UUID?
    var profileName: String
    var sourceText: String
    var translation: String
    var target: TranslationTarget
    var state: TranslationSessionState
    var errorCode: TranslationErrorCode?
    var errorRetryable = false
    var recoveryAction: CardRecoveryAction?
    var copyConfirmed = false
    var isComparisonExpanded = false
    var isPinned = false
    var anchor: ScreenRect?
    var pointer: CGPoint?
    var isActivating = false

    var statusLabel: String {
        switch state {
        case .idle: "准备就绪"
        case .acquiring: "正在读取"
        case .recognizing: "正在识别"
        case .awaitingFirstToken: "等待译文"
        case .streaming: "翻译中"
        case .completed: "已完成"
        case .failed: "需要处理"
        case .cancelled: "已取消"
        }
    }
}

struct RecentTranslation: Identifiable, Equatable {
    let id: UUID
    let surface: TranslationSurface
    let profileID: UUID?
    let profileName: String
    let sourceText: String
    let translation: String
    let target: TranslationTarget
}

@MainActor
final class TranslationSessionStore: ObservableObject {
    @Published private(set) var session: CardSession?
    @Published private(set) var recentTranslations: [RecentTranslation] = []

    static let recentTranslationLimit = 3

    private let settings: MarlaSettingsStore
    private let client = RustTranslationClient()
    private var handle: RustTranslationClient.Handle?
    private var lastSource = ""
    private var lastSurface: TranslationSurface = .selection
    private var lastAnchor: ScreenRect?
    private var lastPointer: CGPoint?

    init(settings: MarlaSettingsStore) {
        self.settings = settings
    }

    var availableProfiles: [TranslationAPIProfile] { settings.profiles }

    func beginRecognizing(anchor: ScreenRect?, pointer: CGPoint?) -> UUID {
        cancelCurrentRequest()
        let id = UUID()
        session = CardSession(
            id: id,
            surface: .screenshot,
            profileID: settings.defaultProfile?.id,
            profileName: settings.defaultProfile?.name ?? "未配置",
            sourceText: "",
            translation: "",
            target: settings.defaultTarget,
            state: .recognizing,
            anchor: anchor,
            pointer: pointer,
            isActivating: false
        )
        lastSurface = .screenshot
        lastAnchor = anchor
        lastPointer = pointer
        return id
    }

    func installUIAutomationFixture(
        surface: TranslationSurface,
        sourceText: String,
        translation: String,
        state: TranslationSessionState,
        comparisonExpanded: Bool = false,
        pinned: Bool = false,
        recovery: CardRecoveryAction? = nil
    ) {
        cancelCurrentRequest()
        let id = UUID()
        session = CardSession(
            id: id,
            surface: surface,
            profileID: settings.defaultProfile?.id,
            profileName: settings.defaultProfile?.name ?? "未配置",
            sourceText: sourceText,
            translation: translation,
            target: settings.defaultTarget,
            state: state,
            errorCode: state.isFailure ? .network : nil,
            errorRetryable: recovery == .retry,
            recoveryAction: recovery,
            isComparisonExpanded: comparisonExpanded,
            isPinned: pinned,
            anchor: nil,
            pointer: NSEvent.mouseLocation,
            isActivating: true
        )
        lastSource = sourceText
        lastSurface = surface
        lastPointer = NSEvent.mouseLocation
        recordRecentTranslationIfEligible(session)
    }

    func submitRecognizedText(_ text: String, for id: UUID) {
        guard session?.id == id else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            session?.state = .failed(message: "没有识别到文字，请重新框选更清晰的区域。")
            session?.errorCode = .invalidResponse
            session?.errorRetryable = false
            session?.recoveryAction = .reselectScreenshot
            return
        }
        session?.sourceText = text
        startRequest(for: id)
    }

    func startText(_ text: String, surface: TranslationSurface, anchor: ScreenRect?, pointer: CGPoint?, activate: Bool = false, target: TranslationTarget? = nil, profileID: UUID? = nil) {
        cancelCurrentRequest()
        let id = UUID()
        lastSource = text
        lastSurface = surface
        lastAnchor = anchor
        lastPointer = pointer
        session = CardSession(
            id: id,
            surface: surface,
            profileID: profileID ?? settings.defaultProfile?.id,
            profileName: settings.profile(id: profileID ?? settings.defaultProfile?.id)?.name ?? "未配置",
            sourceText: text,
            translation: "",
            target: target ?? settings.defaultTarget,
            state: .acquiring,
            anchor: anchor,
            pointer: pointer,
            isActivating: activate
        )
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            session?.state = .failed(message: "没有可翻译的文字。")
            session?.errorCode = .invalidConfiguration
            return
        }
        startRequest(for: id)
    }

    func startRequest(for id: UUID) {
        guard var current = session, current.id == id else { return }
        lastSource = current.sourceText
        lastSurface = current.surface
        lastAnchor = current.anchor
        lastPointer = current.pointer
        guard let profile = settings.profile(id: current.profileID),
              let endpoint = settings.endpoint(for: profile.id) else {
            current.state = .failed(message: "请先在设置中配置翻译 API。")
            current.errorCode = .invalidConfiguration
            current.errorRetryable = false
            current.recoveryAction = .openSettings
            session = current
            return
        }
        current.state = .awaitingFirstToken
        current.errorCode = nil
        current.errorRetryable = false
        current.recoveryAction = nil
        current.profileID = profile.id
        current.profileName = profile.name
        session = current
        let request = TranslationFFIRequest(
            requestID: current.id,
            sourceText: current.sourceText,
            target: current.target,
            endpoint: endpoint
        )
        do {
            handle = try client.start(request: request) { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.apply(event)
                }
            }
        } catch {
            current.state = .failed(message: error.localizedDescription)
            current.errorCode = .internalError
            current.errorRetryable = true
            session = current
        }
    }

    func apply(_ event: TranslationFFIEvent) {
        guard var current = session else { return }
        guard TranslationSessionReducer.apply(
            event,
            requestID: current.id,
            state: &current.state,
            translation: &current.translation
        ) else { return }
        if event.type == "failed" {
            current.errorCode = event.code
            current.errorRetryable = event.retryable ?? false
            current.recoveryAction = recoveryAction(for: event.code, retryable: current.errorRetryable)
        }
        if current.state.isTerminal {
            handle?.release()
            handle = nil
        }
        session = current
        recordRecentTranslationIfEligible(current)
    }

    func retry() {
        guard let current = session, !lastSource.isEmpty else { return }
        startText(
            lastSource,
            surface: lastSurface,
            anchor: current.anchor ?? lastAnchor,
            pointer: current.pointer ?? lastPointer,
            activate: current.isActivating,
            target: current.target,
            profileID: current.profileID
        )
    }

    func changeAPIProfile(_ profileID: UUID) {
        guard var current = session,
              !current.sourceText.isEmpty,
              let profile = settings.profile(id: profileID),
              profile.isConfigured else { return }
        cancelCurrentRequest()
        current.profileID = profile.id
        current.profileName = profile.name
        current.translation = ""
        current.state = .acquiring
        current.errorCode = nil
        current.errorRetryable = false
        current.recoveryAction = nil
        current.id = UUID()
        session = current
        startRequest(for: current.id)
    }

    func changeTarget(_ target: TranslationTarget) {
        guard var current = session, !current.sourceText.isEmpty else { return }
        cancelCurrentRequest()
        current.target = target
        current.translation = ""
        current.state = .acquiring
        current.id = UUID()
        session = current
        startRequest(for: current.id)
    }

    func toggleComparison() {
        session?.isComparisonExpanded.toggle()
    }

    func togglePinned() {
        session?.isPinned.toggle()
    }

    func copyTranslation() {
        guard let id = session?.id, let translation = session?.translation, !translation.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translation, forType: .string)
        session?.copyConfirmed = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard self?.session?.id == id else { return }
            self?.session?.copyConfirmed = false
        }
    }

    func cancel() {
        guard session != nil else { return }
        cancelCurrentRequest()
        session?.state = .cancelled
    }

    func cancelCurrentRequest() {
        handle?.cancel()
        handle?.release()
        handle = nil
    }

    func close() {
        cancelCurrentRequest()
        session = nil
    }

    @discardableResult
    func restoreRecentTranslation(id: UUID) -> CardSession? {
        guard let index = recentTranslations.firstIndex(where: { $0.id == id }) else { return nil }
        let recent = recentTranslations.remove(at: index)
        recentTranslations.insert(recent, at: 0)
        cancelCurrentRequest()
        let restored = CardSession(
            id: UUID(),
            surface: recent.surface,
            profileID: recent.profileID,
            profileName: recent.profileName,
            sourceText: recent.sourceText,
            translation: recent.translation,
            target: recent.target,
            state: .completed,
            anchor: nil,
            pointer: NSEvent.mouseLocation,
            isActivating: true
        )
        session = restored
        lastSource = restored.sourceText
        lastSurface = restored.surface
        lastAnchor = nil
        lastPointer = restored.pointer
        return restored
    }

    func fail(
        _ message: String,
        code: TranslationErrorCode,
        for id: UUID? = nil,
        retryable: Bool = false,
        recovery: CardRecoveryAction? = nil
    ) {
        guard id == nil || session?.id == id else { return }
        session?.state = .failed(message: message)
        session?.errorCode = code
        session?.errorRetryable = retryable
        session?.recoveryAction = recovery ?? (retryable ? .retry : nil)
    }

    private func recoveryAction(for code: TranslationErrorCode?, retryable: Bool) -> CardRecoveryAction? {
        switch code {
        case .invalidConfiguration, .unauthorized:
            .openSettings
        case .rateLimited, .network, .timeout, .provider, .invalidResponse, .internalError:
            retryable ? .retry : nil
        case nil:
            retryable ? .retry : nil
        }
    }

    private func recordRecentTranslationIfEligible(_ candidate: CardSession?) {
        guard let candidate,
              case .completed = candidate.state,
              !candidate.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !candidate.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        recentTranslations.removeAll {
            $0.sourceText == candidate.sourceText &&
                $0.translation == candidate.translation &&
                $0.target == candidate.target
        }
        recentTranslations.insert(
            RecentTranslation(
                id: UUID(),
                surface: candidate.surface,
                profileID: candidate.profileID,
                profileName: candidate.profileName,
                sourceText: candidate.sourceText,
                translation: candidate.translation,
                target: candidate.target
            ),
            at: 0
        )
        if recentTranslations.count > Self.recentTranslationLimit {
            recentTranslations.removeLast(recentTranslations.count - Self.recentTranslationLimit)
        }
    }
}

@MainActor
final class MarlaPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
enum FloatingPanelStyle {
    static let cornerRadius = DesignTokens.radiusL

    static func apply(to panel: NSPanel) {
        panel.isMovable = true
        panel.isMovableByWindowBackground = true
        panel.hasShadow = true
    }

    static func apply(to contentView: NSView) {
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = cornerRadius
        contentView.layer?.cornerCurve = .continuous
        contentView.layer?.masksToBounds = true
    }
}

struct PanelPlacementCalculator {
    static func frame(
        visibleFrame visible: NSRect,
        requestedWidth: CGFloat,
        requestedHeight: CGFloat,
        anchor: ScreenRect?,
        pointer: CGPoint?
    ) -> NSRect {
        let width = min(max(requestedWidth, 320), min(520, visible.width - 16))
        let height = min(requestedHeight, visible.height * 0.6)
        let source = anchor.map {
            NSRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height)
        }
        var x = source?.midX ?? pointer?.x ?? visible.midX
        var y: CGFloat
        if let source {
            let roomAbove = visible.maxY - source.maxY
            let roomBelow = source.minY - visible.minY
            y = roomAbove >= roomBelow ? source.maxY + 8 : source.minY - height - 8
        } else {
            y = (pointer?.y ?? visible.midY) - height / 2
        }
        x -= width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - width - 8)
        y = min(max(y, visible.minY + 8), visible.maxY - height - 8)
        return NSRect(x: x, y: y, width: width, height: height)
    }
}

@MainActor
final class FloatingPanelCoordinator: NSObject, NSWindowDelegate {
    private weak var model: MarlaApplicationModel?
    private var panel: MarlaPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(model: MarlaApplicationModel? = nil, installEventMonitors: Bool = true) {
        self.model = model
        super.init()
        guard installEventMonitors else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if event.type == .keyDown, event.keyCode != 53 { return }
                guard self.model?.sessionStore.session?.isPinned != true else { return }
                self.hide()
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, event.keyCode == 53 {
                guard self.model?.sessionStore.session?.isPinned != true else { return event }
                self.hide()
                return nil
            }
            if event.type != .keyDown, event.window !== self.panel,
               self.model?.sessionStore.session?.isPinned != true {
                self.hide()
            }
            return event
        }
    }

    func attach(model: MarlaApplicationModel) {
        self.model = model
    }

    func showResult(store: TranslationSessionStore, at anchor: ScreenRect?, pointer: CGPoint?, activate: Bool) {
        let content = AnyView(
            TranslationCardView(
                store: store,
                onClose: { [weak self] in self?.hide() },
                onRecovery: { [weak self] action in self?.model?.performRecovery(action) }
            )
        )
        show(content: content, width: 380, height: 300, anchor: anchor, pointer: pointer, activate: activate)
    }

    func showQuickInput(store: TranslationSessionStore, pointer: CGPoint?) {
        store.close()
        let content = AnyView(
            QuickInputContainerView(
                store: store,
                onClose: { [weak self] in self?.hide() },
                onRecovery: { [weak self] action in self?.model?.performRecovery(action) }
            )
        )
        show(content: content, width: 420, height: 300, anchor: nil, pointer: pointer, activate: true)
    }

    func showMenuAutomationSurface(model: MarlaApplicationModel) {
        let content = AnyView(MenuBarView(model: model))
        show(
            content: content,
            width: 330,
            height: 620,
            anchor: nil,
            pointer: CGPoint(x: NSScreen.main?.visibleFrame.maxX ?? 1200, y: NSScreen.main?.visibleFrame.maxY ?? 800),
            activate: true
        )
    }

    func hide() {
        panel?.orderOut(nil)
        model?.sessionStore.close()
        SpeechCoordinator.shared.stop()
    }

    private func show(content: AnyView, width: CGFloat, height: CGFloat, anchor: ScreenRect?, pointer: CGPoint?, activate: Bool) {
        let panel = panel ?? makePanel()
        let forcedReduceMotion = ProcessInfo.processInfo.environment["MARLA_UI_TEST_REDUCE_MOTION"] == "1"
        let hostingView = NSHostingView(
            rootView: content.environment(\.marlaReduceMotionOverride, forcedReduceMotion)
        )
        FloatingPanelStyle.apply(to: hostingView)
        panel.contentView = hostingView
        let targetFrame = frame(width: width, height: height, anchor: anchor, pointer: pointer)
        let reduceMotion = forcedReduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        var entryFrame = targetFrame
        if !reduceMotion { entryFrame.origin.y -= 4 }
        panel.alphaValue = 0
        panel.setFrame(entryFrame, display: true, animate: false)
        panel.orderFrontRegardless()
        if activate {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKey()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.12 : 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            if !reduceMotion { panel.animator().setFrame(targetFrame, display: true) }
        }
    }

    private func makePanel() -> MarlaPanel {
        let panel = MarlaPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 260),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        FloatingPanelStyle.apply(to: panel)
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        self.panel = panel
        return panel
    }

    private func frame(width requestedWidth: CGFloat, height requestedHeight: CGFloat, anchor: ScreenRect?, pointer: CGPoint?) -> NSRect {
        let targetScreen = anchor.flatMap { rect in
            NSScreen.screens.first { $0.frame.intersects(NSRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)) }
        } ?? pointer.flatMap { point in
            NSScreen.screens.first { $0.frame.contains(point) }
        } ?? NSScreen.main ?? NSScreen.screens.first!
        return PanelPlacementCalculator.frame(
            visibleFrame: targetScreen.visibleFrame,
            requestedWidth: requestedWidth,
            requestedHeight: requestedHeight,
            anchor: anchor,
            pointer: pointer
        )
    }

    func windowWillClose(_ notification: Notification) {
        model?.sessionStore.close()
    }
}

enum GlobalShortcutAction: String, CaseIterable, Codable, Sendable {
    case selection
    case screenshot
    case quickInput

    var title: String {
        switch self {
        case .selection: "划词翻译"
        case .screenshot: "截图翻译"
        case .quickInput: "快速输入"
        }
    }

    var symbolName: String {
        switch self {
        case .selection: "text.viewfinder"
        case .screenshot: "viewfinder"
        case .quickInput: "keyboard"
        }
    }

    var hotKeyID: UInt32 {
        switch self {
        case .selection: 1
        case .screenshot: 2
        case .quickInput: 3
        }
    }

    init?(hotKeyID: UInt32) {
        switch hotKeyID {
        case 1: self = .selection
        case 2: self = .screenshot
        case 3: self = .quickInput
        default: return nil
        }
    }
}

struct ShortcutBinding: Codable, Equatable, Sendable {
    var keyCode: UInt16
    var modifiers: UInt

    var displayName: String {
        var result = ""
        if modifiers & NSEvent.ModifierFlags.control.rawValue != 0 { result += "⌃" }
        if modifiers & NSEvent.ModifierFlags.option.rawValue != 0 { result += "⌥" }
        if modifiers & NSEvent.ModifierFlags.shift.rawValue != 0 { result += "⇧" }
        if modifiers & NSEvent.ModifierFlags.command.rawValue != 0 { result += "⌘" }
        switch keyCode {
        case 49: result += "Space"
        case 36: result += "Return"
        case 48: result += "Tab"
        case 51: result += "Delete"
        case 2: result += "D"
        case 1: result += "S"
        case 0: result += "A"
        case 3: result += "F"
        case 4: result += "H"
        case 5: result += "G"
        case 6: result += "Z"
        case 7: result += "X"
        case 8: result += "C"
        case 9: result += "V"
        case 11: result += "B"
        case 12: result += "Q"
        case 13: result += "W"
        case 14: result += "E"
        case 15: result += "R"
        case 16: result += "Y"
        case 17: result += "T"
        case 31: result += "O"
        case 32: result += "U"
        case 34: result += "I"
        case 35: result += "P"
        case 37: result += "L"
        case 38: result += "J"
        case 40: result += "K"
        case 45: result += "N"
        case 46: result += "M"
        default: result += "Key \(keyCode)"
        }
        return result
    }

    var hasCommandModifier: Bool {
        let supported = NSEvent.ModifierFlags.command.rawValue
            | NSEvent.ModifierFlags.control.rawValue
            | NSEvent.ModifierFlags.option.rawValue
            | NSEvent.ModifierFlags.shift.rawValue
        return modifiers & supported != 0
    }

    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if modifiers & NSEvent.ModifierFlags.command.rawValue != 0 { value |= UInt32(cmdKey) }
        if modifiers & NSEvent.ModifierFlags.control.rawValue != 0 { value |= UInt32(controlKey) }
        if modifiers & NSEvent.ModifierFlags.option.rawValue != 0 { value |= UInt32(optionKey) }
        if modifiers & NSEvent.ModifierFlags.shift.rawValue != 0 { value |= UInt32(shiftKey) }
        return value
    }

    static let defaults: [GlobalShortcutAction: ShortcutBinding] = [
        .selection: ShortcutBinding(keyCode: 2, modifiers: NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue),
        .screenshot: ShortcutBinding(keyCode: 1, modifiers: NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue),
        .quickInput: ShortcutBinding(keyCode: 49, modifiers: NSEvent.ModifierFlags.control.rawValue | NSEvent.ModifierFlags.option.rawValue)
    ]

    static func conflictingAction(
        in bindings: [GlobalShortcutAction: ShortcutBinding],
        candidate: ShortcutBinding,
        excluding action: GlobalShortcutAction
    ) -> GlobalShortcutAction? {
        bindings.first(where: { $0.key != action && $0.value == candidate })?.key
    }
}

@MainActor
protocol GlobalShortcutManaging: AnyObject {
    var bindings: [GlobalShortcutAction: ShortcutBinding] { get }
    var enabledActions: Set<GlobalShortcutAction> { get }
    var conflictMessage: String? { get }
    func isEnabled(_ action: GlobalShortcutAction) -> Bool
    func setEnabled(_ enabled: Bool, for action: GlobalShortcutAction)
    func set(_ binding: ShortcutBinding, for action: GlobalShortcutAction)
    func restoreDefaults()
    func conflict(for binding: ShortcutBinding, excluding action: GlobalShortcutAction) -> GlobalShortcutAction?
}

private let marlaHotKeySignature: OSType = 0x4D52_4C41 // MRLA

enum MarlaRuntime {
    static var isXcodePreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

private func handleMarlaHotKeyEvent(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }
    let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in manager.handleHotKey(id: hotKeyID.id) }
    return noErr
}

@MainActor
final class GlobalShortcutManager: ObservableObject, GlobalShortcutManaging {
    @Published private(set) var bindings = ShortcutBinding.defaults
    @Published private(set) var enabledActions = Set(GlobalShortcutAction.allCases)
    @Published private(set) var conflictMessage: String?
    var onAction: ((GlobalShortcutAction) -> Void)?
    private var eventHandler: EventHandlerRef?
    private var registeredHotKeys: [GlobalShortcutAction: EventHotKeyRef] = [:]
    private let defaults: UserDefaults
    private let shouldRegisterHotKeys: Bool

    init(
        registerHotKeys: Bool = !MarlaRuntime.isXcodePreview,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        shouldRegisterHotKeys = registerHotKeys
        load()
        guard registerHotKeys else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            handleMarlaHotKeyEvent,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        if status != noErr {
            conflictMessage = "无法初始化全局快捷键服务（错误 \(status)）。"
        } else if let action = register(bindings, enabledActions: enabledActions) {
            conflictMessage = "\(action.title)的快捷键已被系统或其他应用占用，请重新录制。"
        }
    }

    func isEnabled(_ action: GlobalShortcutAction) -> Bool {
        enabledActions.contains(action)
    }

    func setEnabled(_ enabled: Bool, for action: GlobalShortcutAction) {
        let previous = enabledActions
        var candidate = enabledActions
        if enabled {
            candidate.insert(action)
        } else {
            candidate.remove(action)
        }
        if let unavailable = register(bindings, enabledActions: candidate) {
            _ = register(bindings, enabledActions: previous)
            conflictMessage = "\(unavailable.title)的快捷键已被系统或其他应用占用，请重新录制。"
            return
        }
        enabledActions = candidate
        conflictMessage = nil
        save()
    }

    func set(_ binding: ShortcutBinding, for action: GlobalShortcutAction) {
        guard binding.hasCommandModifier else {
            conflictMessage = "快捷键至少需要包含 ⌘、⌃、⌥ 或 ⇧ 中的一个修饰键。"
            return
        }
        if let conflict = conflict(for: binding, excluding: action) {
            conflictMessage = "\(binding.displayName) 已用于\(conflict.title)，请使用其他组合键。"
            return
        }
        let previous = bindings
        var candidate = bindings
        candidate[action] = binding
        if let unavailable = register(candidate, enabledActions: enabledActions) {
            _ = register(previous, enabledActions: enabledActions)
            conflictMessage = "\(unavailable.title)的 \(binding.displayName) 已被占用，请使用其他组合键。"
            return
        }
        bindings = candidate
        conflictMessage = nil
        save()
    }

    func restoreDefaults() {
        let previous = bindings
        let previousEnabled = enabledActions
        let allEnabled = Set(GlobalShortcutAction.allCases)
        if let unavailable = register(ShortcutBinding.defaults, enabledActions: allEnabled) {
            _ = register(previous, enabledActions: previousEnabled)
            conflictMessage = "默认快捷键 \(unavailable.title) 已被占用，请保留当前设置或重新录制。"
            return
        }
        bindings = ShortcutBinding.defaults
        enabledActions = allEnabled
        conflictMessage = nil
        save()
    }

    func conflict(for binding: ShortcutBinding, excluding action: GlobalShortcutAction) -> GlobalShortcutAction? {
        ShortcutBinding.conflictingAction(in: bindings, candidate: binding, excluding: action)
    }

    func handleHotKey(id: UInt32) {
        guard let action = GlobalShortcutAction(hotKeyID: id), isEnabled(action) else { return }
        onAction?(action)
    }

    private func register(
        _ candidate: [GlobalShortcutAction: ShortcutBinding],
        enabledActions: Set<GlobalShortcutAction>
    ) -> GlobalShortcutAction? {
        unregisterAll()
        guard shouldRegisterHotKeys else { return nil }
        for action in GlobalShortcutAction.allCases {
            guard enabledActions.contains(action) else { continue }
            guard let binding = candidate[action] else { continue }
            var reference: EventHotKeyRef?
            let identifier = EventHotKeyID(signature: marlaHotKeySignature, id: action.hotKeyID)
            let status = RegisterEventHotKey(
                UInt32(binding.keyCode),
                binding.carbonModifiers,
                identifier,
                GetApplicationEventTarget(),
                0,
                &reference
            )
            guard status == noErr, let reference else {
                unregisterAll()
                return action
            }
            registeredHotKeys[action] = reference
        }
        return nil
    }

    private func unregisterAll() {
        registeredHotKeys.values.forEach { UnregisterEventHotKey($0) }
        registeredHotKeys.removeAll()
    }

    private func load() {
        if let data = defaults.data(forKey: "shortcutBindings"),
           let decoded = try? JSONDecoder().decode([GlobalShortcutAction: ShortcutBinding].self, from: data) {
            bindings = decoded
        }
        if let data = defaults.data(forKey: "shortcutEnabledActions.v1"),
           let decoded = try? JSONDecoder().decode(Set<GlobalShortcutAction>.self, from: data) {
            enabledActions = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(bindings) {
            defaults.set(data, forKey: "shortcutBindings")
        }
        if let data = try? JSONEncoder().encode(enabledActions) {
            defaults.set(data, forKey: "shortcutEnabledActions.v1")
        }
    }

}

struct CapturedScreenshot {
    let image: CGImage
    let globalRect: CGRect
}

@MainActor
protocol ScreenshotCapturing: AnyObject {
    func present(completion: @escaping (Result<CapturedScreenshot, Error>) -> Void)
}

@MainActor
final class ScreenshotCaptureCoordinator: ScreenshotCapturing {
    private var windows: [NSWindow] = []
    private var completion: ((Result<CapturedScreenshot, Error>) -> Void)?
    private var selectionSession: ScreenshotSelectionSession?
    private var escapeMonitor: ScreenshotEscapeMonitor?

    func present(completion: @escaping (Result<CapturedScreenshot, Error>) -> Void) {
        self.completion = completion
        let magnifierSources = NSScreen.screens.compactMap(ScreenshotMagnifierSource.init(screen:))
        let session = ScreenshotSelectionSession(magnifierSources: magnifierSources) { [weak self] rect, cancelled in
            guard let self else { return }
            if cancelled {
                self.finish(.failure(ScreenshotError.cancelled))
            } else {
                self.capture(global: rect)
            }
        }
        selectionSession = session
        let escapeMonitor = ScreenshotEscapeMonitor { [weak self, weak session] in
            guard let self, let session, self.selectionSession === session else { return }
            session.cancel()
        }
        self.escapeMonitor = escapeMonitor
        escapeMonitor.install()
        windows = NSScreen.screens.map { screen in
            let window = ScreenshotSelectionWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.acceptsMouseMovedEvents = true
            window.contentView = ScreenshotSelectionView(session: session)
            window.makeFirstResponder(window.contentView)
            window.orderFrontRegardless()
            return window
        }
        NSApp.activate(ignoringOtherApps: true)
        let pointer = NSEvent.mouseLocation
        let keyWindow = windows.first(where: { $0.frame.contains(pointer) }) ?? windows.first
        keyWindow?.makeKey()
        keyWindow?.makeFirstResponder(keyWindow?.contentView)
    }

    func presentUIAutomationFixture() {
        present { _ in }
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        selectionSession?.begin(at: NSPoint(x: frame.minX + frame.width * 0.24, y: frame.minY + frame.height * 0.3))
        selectionSession?.move(to: NSPoint(x: frame.minX + frame.width * 0.76, y: frame.minY + frame.height * 0.68))
    }

    private func capture(global: NSRect) {
        guard global.width > 4, global.height > 4 else {
            finish(.failure(ScreenshotError.invalidRegion))
            return
        }
        Task { @MainActor [weak self] in
            do {
                let image = try await self?.captureWithScreenCaptureKit(global)
                guard let image else { throw ScreenshotError.captureFailed }
                self?.finish(.success(CapturedScreenshot(image: image, globalRect: global)))
            } catch {
                self?.finish(.failure(error))
            }
        }
    }

    private func captureWithScreenCaptureKit(_ global: CGRect) async throws -> CGImage {
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        let targetScale = NSScreen.screens
            .filter { $0.frame.intersects(global) }
            .map(\.backingScaleFactor)
            .max() ?? 1
        let pixelWidth = max(1, Int(global.width * targetScale))
        let pixelHeight = max(1, Int(global.height * targetScale))
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ScreenshotError.captureFailed
        }

        var capturedAnyDisplay = false
        for screen in NSScreen.screens {
            let intersection = screen.frame.intersection(global)
            guard !intersection.isNull, intersection.width > 0, intersection.height > 0,
                  let screenNumber = screen.deviceDescription[
                    NSDeviceDescriptionKey("NSScreenNumber")
                  ] as? NSNumber,
                  let display = shareableContent.displays.first(where: {
                      $0.displayID == CGDirectDisplayID(screenNumber.uint32Value)
                  }) else {
                continue
            }

            let configuration = SCStreamConfiguration()
            configuration.sourceRect = ScreenCaptureGeometry.sourceRect(
                intersection: intersection,
                screenFrame: screen.frame
            )
            configuration.width = max(1, Int(intersection.width * screen.backingScaleFactor))
            configuration.height = max(1, Int(intersection.height * screen.backingScaleFactor))
            configuration.showsCursor = false
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let fragment = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            let destination = ScreenCaptureGeometry.destinationRect(
                intersection: intersection,
                selection: global,
                scale: targetScale
            )
            context.draw(fragment, in: destination)
            capturedAnyDisplay = true
        }
        guard capturedAnyDisplay, let result = context.makeImage() else {
            throw ScreenshotError.captureFailed
        }
        return result
    }

    private func finish(_ result: Result<CapturedScreenshot, Error>) {
        escapeMonitor?.remove()
        escapeMonitor = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        selectionSession = nil
        let completion = self.completion
        self.completion = nil
        completion?(result)
    }
}

@MainActor
final class ScreenshotEscapeMonitor {
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private let onEscape: () -> Void

    init(onEscape: @escaping () -> Void) {
        self.onEscape = onEscape
    }

    var isInstalled: Bool {
        localMonitor != nil || globalMonitor != nil
    }

    func install() {
        remove()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleLocal(event) ?? event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard Self.isCancelKeyCode(event.keyCode) else { return }
            Task { @MainActor [weak self] in
                self?.onEscape()
            }
        }
    }

    func remove() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    func handleLocal(_ event: NSEvent) -> NSEvent? {
        guard Self.isCancelKeyCode(event.keyCode) else { return event }
        onEscape()
        return nil
    }

    func handleGlobal(_ event: NSEvent) {
        guard Self.isCancelKeyCode(event.keyCode) else { return }
        onEscape()
    }

    static func isCancelKeyCode(_ keyCode: UInt16) -> Bool {
        keyCode == 53
    }
}

final class ScreenshotSelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

enum ScreenCaptureGeometry {
    /// ScreenCaptureKit source rectangles use a display-local, top-left origin, while AppKit
    /// selection windows report global points with a bottom-left origin.
    static func sourceRect(intersection: CGRect, screenFrame: CGRect) -> CGRect {
        CGRect(
            x: intersection.minX - screenFrame.minX,
            y: screenFrame.maxY - intersection.maxY,
            width: intersection.width,
            height: intersection.height
        )
    }

    static func destinationRect(intersection: CGRect, selection: CGRect, scale: CGFloat) -> CGRect {
        CGRect(
            x: (intersection.minX - selection.minX) * scale,
            y: (intersection.minY - selection.minY) * scale,
            width: intersection.width * scale,
            height: intersection.height * scale
        )
    }
}

enum ScreenshotError: LocalizedError {
    case cancelled
    case invalidRegion
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .cancelled: "已取消截图。"
        case .invalidRegion: "选取的区域太小。"
        case .captureFailed: "无法捕获选取区域，请检查屏幕录制权限。"
        }
    }
}

struct ScreenshotMagnifierGeometry {
    static let size = NSSize(width: 104, height: 128)
    static let margin: CGFloat = 8
    static let offset = NSSize(width: 18, height: 18)

    static func frame(pointer: NSPoint, in bounds: NSRect) -> NSRect {
        var origin = NSPoint(
            x: pointer.x + offset.width,
            y: pointer.y + offset.height
        )
        if origin.x + size.width > bounds.maxX - margin {
            origin.x = pointer.x - offset.width - size.width
        }
        if origin.y + size.height > bounds.maxY - margin {
            origin.y = pointer.y - offset.height - size.height
        }
        origin.x = min(max(origin.x, bounds.minX + margin), bounds.maxX - size.width - margin)
        origin.y = min(max(origin.y, bounds.minY + margin), bounds.maxY - size.height - margin)
        return NSRect(origin: origin, size: size)
    }

    static func sourceRect(
        pointer: NSPoint,
        in sourceBounds: NSRect,
        destinationSize: NSSize,
        zoom: CGFloat
    ) -> NSRect {
        let width = min(sourceBounds.width, destinationSize.width / zoom)
        let height = min(sourceBounds.height, destinationSize.height / zoom)
        let x = min(max(pointer.x - width / 2, sourceBounds.minX), sourceBounds.maxX - width)
        let y = min(max(pointer.y - height / 2, sourceBounds.minY), sourceBounds.maxY - height)
        return NSRect(x: x, y: y, width: width, height: height)
    }
}

@MainActor
struct ScreenshotMagnifierSource {
    let screenFrame: NSRect
    let image: NSImage

    init?(screen: NSScreen) {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let cgImage = CGDisplayCreateImage(CGDirectDisplayID(screenNumber.uint32Value)) else {
            return nil
        }
        screenFrame = screen.frame
        image = NSImage(cgImage: cgImage, size: screen.frame.size)
    }

    func contains(_ point: NSPoint) -> Bool {
        screenFrame.contains(point)
    }

    func localPoint(for globalPoint: NSPoint) -> NSPoint {
        NSPoint(x: globalPoint.x - screenFrame.minX, y: globalPoint.y - screenFrame.minY)
    }
}

@MainActor
final class ScreenshotSelectionSession {
    private(set) var startPoint: NSPoint?
    private(set) var currentPoint: NSPoint?
    private(set) var pointerPoint: NSPoint?
    let magnifierSources: [ScreenshotMagnifierSource]
    private var redrawCallbacks: [() -> Void] = []
    private var hasFinished = false
    private let onFinish: (NSRect, Bool) -> Void

    init(
        magnifierSources: [ScreenshotMagnifierSource] = [],
        onFinish: @escaping (NSRect, Bool) -> Void
    ) {
        self.magnifierSources = magnifierSources
        self.onFinish = onFinish
    }

    var selectionRect: NSRect {
        guard let startPoint, let currentPoint else { return .zero }
        return NSRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(startPoint.x - currentPoint.x),
            height: abs(startPoint.y - currentPoint.y)
        )
    }

    func attach(_ view: ScreenshotSelectionView) {
        redrawCallbacks.append { [weak view] in view?.needsDisplay = true }
    }

    func begin(at point: NSPoint) {
        guard !hasFinished else { return }
        pointerPoint = point
        startPoint = point
        currentPoint = point
        redraw()
    }

    func move(to point: NSPoint) {
        guard startPoint != nil, !hasFinished else { return }
        pointerPoint = point
        currentPoint = point
        redraw()
    }

    func hover(at point: NSPoint) {
        guard !hasFinished else { return }
        pointerPoint = point
        redraw()
    }

    func confirm(at point: NSPoint) {
        move(to: point)
        finish(cancelled: selectionRect.width <= 4 || selectionRect.height <= 4)
    }

    func cancel() {
        finish(cancelled: true)
    }

    private func redraw() {
        redrawCallbacks.forEach { $0() }
    }

    private func finish(cancelled: Bool) {
        guard !hasFinished else { return }
        hasFinished = true
        onFinish(selectionRect, cancelled)
    }
}

@MainActor
final class ScreenshotSelectionView: NSView {
    private let session: ScreenshotSelectionSession
    private let hintView: NSHostingView<ScreenshotGlassLabel>
    private let sizeView: NSHostingView<ScreenshotGlassLabel>

    init(session: ScreenshotSelectionSession) {
        self.session = session
        hintView = NSHostingView(
            rootView: ScreenshotGlassLabel(
                text: "拖动框选要翻译的区域 · Esc 取消",
                usesMonospacedDigits: false
            )
        )
        sizeView = NSHostingView(
            rootView: ScreenshotGlassLabel(text: "0 × 0", usesMonospacedDigits: true)
        )
        super.init(frame: .zero)
        wantsLayer = true
        addSubview(hintView)
        addSubview(sizeView)
        sizeView.isHidden = true
        session.attach(self)
    }

    required init?(coder: NSCoder) { nil }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseMoved(with event: NSEvent) {
        guard let window else { return }
        session.hover(at: window.convertPoint(toScreen: event.locationInWindow))
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        session.begin(at: window.convertPoint(toScreen: event.locationInWindow))
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        session.move(to: window.convertPoint(toScreen: event.locationInWindow))
    }

    override func mouseUp(with event: NSEvent) {
        guard let window else { return }
        session.confirm(at: window.convertPoint(toScreen: event.locationInWindow))
    }

    override func rightMouseDown(with event: NSEvent) {
        session.cancel()
    }

    override func keyDown(with event: NSEvent) {
        if Self.isCancelKeyCode(event.keyCode) { session.cancel() }
    }

    static func isCancelKeyCode(_ keyCode: UInt16) -> Bool {
        keyCode == 53
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.42).setFill()
        bounds.fill()
        guard let window else { return }
        let rect = window.convertFromScreen(session.selectionRect)
        if rect.width <= 0 || rect.height <= 0 {
            hintView.isHidden = false
            sizeView.isHidden = true
            let size = hintView.fittingSize
            hintView.frame = NSRect(
                x: bounds.midX - size.width / 2,
                y: bounds.maxY - size.height - 16,
                width: size.width,
                height: size.height
            )
        }
        if rect.width > 0, rect.height > 0 {
            hintView.isHidden = true
            NSGraphicsContext.current?.compositingOperation = .clear
            rect.fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            NSColor.white.setStroke()
            let border = NSBezierPath(rect: rect)
            border.lineWidth = 1
            border.stroke()
            let length: CGFloat = 10
            let corners = [
                (NSPoint(x: rect.minX, y: rect.minY), NSPoint(x: rect.minX + length, y: rect.minY), NSPoint(x: rect.minX, y: rect.minY + length)),
                (NSPoint(x: rect.maxX, y: rect.minY), NSPoint(x: rect.maxX - length, y: rect.minY), NSPoint(x: rect.maxX, y: rect.minY + length)),
                (NSPoint(x: rect.minX, y: rect.maxY), NSPoint(x: rect.minX + length, y: rect.maxY), NSPoint(x: rect.minX, y: rect.maxY - length)),
                (NSPoint(x: rect.maxX, y: rect.maxY), NSPoint(x: rect.maxX - length, y: rect.maxY), NSPoint(x: rect.maxX, y: rect.maxY - length))
            ]
            corners.forEach { first, second, third in
                let path = NSBezierPath()
                path.move(to: first); path.line(to: second); path.move(to: first); path.line(to: third)
                path.lineWidth = 2
                path.stroke()
            }
            sizeView.rootView = ScreenshotGlassLabel(
                text: "\(Int(rect.width)) × \(Int(rect.height))",
                usesMonospacedDigits: true
            )
            let labelSize = sizeView.fittingSize
            sizeView.frame = NSRect(
                x: rect.minX,
                y: max(bounds.minY + 8, rect.minY - labelSize.height - 6),
                width: labelSize.width,
                height: labelSize.height
            )
            sizeView.isHidden = false
        }
        drawMagnifier(in: window)
    }

    private func drawMagnifier(in window: NSWindow) {
        guard let globalPoint = session.pointerPoint,
              let source = session.magnifierSources.first(where: { $0.contains(globalPoint) }) else { return }
        let localPoint = window.convertFromScreen(NSRect(origin: globalPoint, size: .zero)).origin
        guard bounds.contains(localPoint) else { return }

        let frame = ScreenshotMagnifierGeometry.frame(pointer: localPoint, in: bounds)
        let outerPath = NSBezierPath(roundedRect: frame, xRadius: 14, yRadius: 14)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        shadow.shadowBlurRadius = 12
        shadow.shadowOffset = NSSize(width: 0, height: -3)
        shadow.set()
        NSColor.windowBackgroundColor.withAlphaComponent(0.96).setFill()
        outerPath.fill()
        NSGraphicsContext.restoreGraphicsState()

        let imageRect = NSRect(x: frame.minX + 4, y: frame.minY + 28, width: 96, height: 96)
        let imagePath = NSBezierPath(roundedRect: imageRect, xRadius: 11, yRadius: 11)
        NSGraphicsContext.saveGraphicsState()
        imagePath.addClip()
        let sourceBounds = NSRect(origin: .zero, size: source.image.size)
        let sourceRect = ScreenshotMagnifierGeometry.sourceRect(
            pointer: source.localPoint(for: globalPoint),
            in: sourceBounds,
            destinationSize: imageRect.size,
            zoom: 6
        )
        source.image.draw(
            in: imageRect,
            from: sourceRect,
            operation: .copy,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.none]
        )
        NSGraphicsContext.restoreGraphicsState()

        NSColor.white.withAlphaComponent(0.92).setStroke()
        outerPath.lineWidth = 1.5
        outerPath.stroke()
        imagePath.lineWidth = 0.5
        imagePath.stroke()

        let center = NSPoint(x: imageRect.midX, y: imageRect.midY)
        let crosshair = NSBezierPath()
        crosshair.move(to: NSPoint(x: center.x - 10, y: center.y))
        crosshair.line(to: NSPoint(x: center.x + 10, y: center.y))
        crosshair.move(to: NSPoint(x: center.x, y: center.y - 10))
        crosshair.line(to: NSPoint(x: center.x, y: center.y + 10))
        NSColor.systemBlue.setStroke()
        crosshair.lineWidth = 1
        crosshair.stroke()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 1.5, y: center.y - 1.5, width: 3, height: 3)).fill()

        let coordinateText = "x \(Int(globalPoint.x))   y \(Int(globalPoint.y))" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let textSize = coordinateText.size(withAttributes: attributes)
        coordinateText.draw(
            at: NSPoint(x: frame.midX - textSize.width / 2, y: frame.minY + 7),
            withAttributes: attributes
        )
    }
}

private struct ScreenshotGlassLabel: View {
    let text: String
    let usesMonospacedDigits: Bool

    var body: some View {
        Group {
            if usesMonospacedDigits {
                Text(text)
                    .font(AppFont.micro.monospacedDigit().weight(.medium))
            } else {
                Text(text)
                    .font(AppFont.caption.weight(.medium))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, usesMonospacedDigits ? 8 : 12)
        .padding(.vertical, usesMonospacedDigits ? 5 : 7)
        .marlaGlassSurface(cornerRadius: usesMonospacedDigits ? 6 : 8)
        .fixedSize()
    }
}

@MainActor
protocol VisionOCRProviding: AnyObject {
    func recognize(_ image: CGImage) async throws -> OCRDocument
}

@MainActor
final class VisionOCRService: VisionOCRProviding {
    func recognize(_ image: CGImage) async throws -> OCRDocument {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.usesLanguageCorrection = true
                    request.recognitionLanguages = ["zh-Hans", "en-US"]
                    let handler = VNImageRequestHandler(cgImage: image, options: [:])
                    try handler.perform([request])
                    let observations = request.results ?? []
                    let lines = observations.compactMap { observation -> (text: String, bounds: CGRect, confidence: Double)? in
                        guard let candidate = observation.topCandidates(1).first else { return nil }
                        return (candidate.string, observation.boundingBox, Double(candidate.confidence))
                    }.sorted { lhs, rhs in
                        let yDistance = abs(lhs.1.midY - rhs.1.midY)
                        if yDistance < 0.025 { return lhs.1.minX < rhs.1.minX }
                        return lhs.1.midY > rhs.1.midY
                    }
                    let blocks = lines.enumerated().map { index, line in
                        ContentBlock(
                            id: String(format: "line-%04d", index),
                            kind: .paragraph,
                            sourceText: line.text,
                            bounds: NormalizedRect(
                                x: line.bounds.minX,
                                y: line.bounds.minY,
                                width: line.bounds.width,
                                height: line.bounds.height
                            ),
                            readingOrder: index,
                            confidence: line.confidence
                        )
                    }
                    let document = OCRDocument(blocks: blocks)
                    guard !document.plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw ScreenshotError.captureFailed
                    }
                    continuation.resume(returning: document)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

@MainActor
final class MarlaApplicationModel: ObservableObject {
    enum SelectionProbeResult: Equatable {
        case idle
        case success(text: String, hasBounds: Bool, applicationName: String?, surface: SurfaceType)
        case failure(message: String)
    }

    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var screenRecordingAuthorized = false
    @Published private(set) var selectionProbeResult: SelectionProbeResult = .idle
    @Published var bannerMessage: String?

    let settings: MarlaSettingsStore
    let sessionStore: TranslationSessionStore
    let panelCoordinator: FloatingPanelCoordinator
    let screenshotCoordinator = ScreenshotCaptureCoordinator()
    let visionOCR = VisionOCRService()
    let shortcutManager: GlobalShortcutManager
    let settingsWindowCoordinator = MarlaSettingsWindowCoordinator()

    private let selectionReader: AccessibilitySelectionReader

    init(
        selectionReader: AccessibilitySelectionReader = AccessibilitySelectionReader(),
        settings: MarlaSettingsStore = MarlaSettingsStore(),
        enableSystemIntegrations: Bool = !MarlaRuntime.isXcodePreview,
        accessibilityTrusted: Bool? = nil,
        screenRecordingAuthorized: Bool? = nil
    ) {
        self.selectionReader = selectionReader
        self.settings = settings
        sessionStore = TranslationSessionStore(settings: settings)
        panelCoordinator = FloatingPanelCoordinator(installEventMonitors: enableSystemIntegrations)
        shortcutManager = GlobalShortcutManager(registerHotKeys: enableSystemIntegrations)
        panelCoordinator.attach(model: self)
        if enableSystemIntegrations {
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
        let pointer = NSEvent.mouseLocation
        guard accessibilityTrusted else {
            showPermissionError(
                "划词翻译需要辅助功能权限。",
                surface: .selection,
                pointer: pointer,
                recovery: .openAccessibilitySettings
            )
            return
        }
        do {
            let selection = try selectionReader.readSelection()
            sessionStore.startText(selection.text, surface: .selection, anchor: selection.bounds, pointer: pointer)
            panelCoordinator.showResult(store: sessionStore, at: selection.bounds, pointer: pointer, activate: false)
        } catch let error as SelectionReadingError {
            sessionStore.startText("", surface: .selection, anchor: nil, pointer: pointer)
            sessionStore.fail(
                message(for: error),
                code: .invalidConfiguration,
                recovery: recovery(for: error)
            )
            panelCoordinator.showResult(store: sessionStore, at: nil, pointer: pointer, activate: false)
        } catch {
            showPermissionError(
                "暂时无法读取当前选区。",
                surface: .selection,
                pointer: pointer,
                recovery: .quickInput
            )
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
        case "selection-live":
            let selectionDelay = ProcessInfo.processInfo.environment["MARLA_UI_TEST_SELECTION_DELAY"]
                .flatMap(Double.init) ?? 0
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, selectionDelay)) { [weak self] in
                self?.translateSelection()
            }
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
        let visibleSheet = visibleWindows
            .lazy
            .compactMap(\.attachedSheet)
            .first(where: \.isVisible) ?? visibleWindows.first { $0.sheetParent != nil }
        let window = visibleSheet
            ?? (NSApp.keyWindow?.isVisible == true ? NSApp.keyWindow : nil)
            ?? visibleWindows.max { lhs, rhs in
                lhs.frame.width * lhs.frame.height < rhs.frame.width * rhs.frame.height
            }
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
            let selection = try selectionReader.readSelection()
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
        case .focusedElementUnavailable, .selectedTextUnavailable, .emptySelection:
            .quickInput
        }
    }

    private func message(for error: SelectionReadingError) -> String {
        switch error {
        case .accessibilityPermissionRequired: "请先授予辅助功能权限。"
        case .focusedElementUnavailable: "无法读取当前聚焦的界面元素。"
        case .selectedTextUnavailable: "当前应用没有提供可读取的选中文本。"
        case .emptySelection: "当前没有选中文字。试试 ⌃⌥Space 快速输入。"
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
