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

enum KeychainItemReadResult {
    case found(Data)
    case notFound
    case failed(OSStatus)
}

@MainActor
struct KeychainItemBackend {
    let read: (_ service: String, _ account: String, _ authenticationContext: LAContext?) -> KeychainItemReadResult
    let save: (_ service: String, _ account: String, _ data: Data) -> Bool
    let remove: (_ service: String, _ account: String) -> Bool

    static let security = KeychainItemBackend(
        read: { service, account, authenticationContext in
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            if let authenticationContext {
                query[kSecUseAuthenticationContext as String] = authenticationContext
            }
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecItemNotFound { return .notFound }
            guard status == errSecSuccess, let data = result as? Data else {
                return .failed(status)
            }
            return .found(data)
        },
        save: { service, account, data in
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
                return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
            }
            return status == errSecSuccess
        },
        remove: { service, account in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            let status = SecItemDelete(query as CFDictionary)
            return status == errSecSuccess || status == errSecItemNotFound
        }
    )
}

@MainActor
final class KeychainCredentialStore: @unchecked Sendable {
    private struct VaultPayload: Codable {
        let schemaVersion: Int
        var credentials: [String: String]
    }

    private final class VaultState {
        var credentials: [String: String]?
        var loadAttempted = false
        var loadSucceeded = false
    }

    static let vaultAccount = "translation-api-key-vault.v1"

    let service: String
    let account: String
    private let backend: KeychainItemBackend
    private let state: VaultState

    init(
        service: String = "com.marla.app",
        account: String = "translation-api-key",
        backend: KeychainItemBackend = .security
    ) {
        self.service = service
        self.account = account
        self.backend = backend
        state = VaultState()
    }

    private init(
        service: String,
        account: String,
        backend: KeychainItemBackend,
        state: VaultState
    ) {
        self.service = service
        self.account = account
        self.backend = backend
        self.state = state
    }

    static func profileAccount(for profileID: UUID) -> String {
        "translation-api-key.\(profileID.uuidString)"
    }

    func scoped(to profileID: UUID) -> KeychainCredentialStore {
        KeychainCredentialStore(
            service: service,
            account: Self.profileAccount(for: profileID),
            backend: backend,
            state: state
        )
    }

    var hasCredential: Bool { read() != nil }

    /// Must be called after NSApplication finishes launching so Keychain may
    /// present the vault's single authorization UI before any translation.
    @discardableResult
    func loadVault(authenticationContext: LAContext? = nil) -> Bool {
        guard !state.loadAttempted else { return state.loadSucceeded }
        state.loadAttempted = true

        switch backend.read(service, Self.vaultAccount, authenticationContext) {
        case let .found(data):
            guard let payload = try? JSONDecoder().decode(VaultPayload.self, from: data),
                  payload.schemaVersion == 1 else {
                return false
            }
            state.credentials = payload.credentials.filter { !$0.value.isEmpty }
            state.loadSucceeded = true
            return true
        case .notFound:
            state.credentials = [:]
            state.loadSucceeded = true
            return true
        case .failed:
            return false
        }
    }

    /// Reads only the process-local vault. It intentionally never falls back to
    /// a physical profile item during translation, preventing a late prompt.
    func read() -> String? {
        state.credentials?[account]
    }

    func save(_ value: String) throws {
        guard loadVault(), var credentials = state.credentials else {
            throw KeychainError.saveFailed
        }
        credentials[account] = value
        guard writeVault(credentials) else { throw KeychainError.saveFailed }
    }

    @discardableResult
    func remove() -> Bool {
        guard var credentials = state.credentials else { return false }
        credentials.removeValue(forKey: account)

        if credentials.isEmpty {
            let removed = backend.remove(service, Self.vaultAccount)
            state.credentials = [:]
            return removed
        }

        let saved = writeVault(credentials)
        if !saved { state.credentials = credentials }
        return saved
    }

    /// Imports old per-profile items into one physical vault. Old items are
    /// deleted only after the complete merged vault has been written.
    @discardableResult
    func migrateLegacyCredentials(
        profileIDs: [UUID],
        defaultProfileID: UUID?,
        authenticationContext: LAContext? = nil
    ) -> Bool {
        guard loadVault(authenticationContext: authenticationContext), var credentials = state.credentials else { return false }
        let originalCredentials = credentials
        var importedAccounts: [String] = []
        var allReadsSucceeded = true

        for profileID in profileIDs {
            let profileAccount = Self.profileAccount(for: profileID)
            guard credentials[profileAccount] == nil else { continue }
            switch readLegacyCredential(account: profileAccount, authenticationContext: authenticationContext) {
            case let .found(value):
                credentials[profileAccount] = value
                importedAccounts.append(profileAccount)
            case .notFound:
                break
            case .failed:
                allReadsSucceeded = false
            }
        }

        if let defaultProfileID {
            let defaultAccount = Self.profileAccount(for: defaultProfileID)
            if credentials[defaultAccount] == nil {
                switch readLegacyCredential(account: account, authenticationContext: authenticationContext) {
                case let .found(value):
                    credentials[defaultAccount] = value
                    importedAccounts.append(account)
                case .notFound:
                    break
                case .failed:
                    allReadsSucceeded = false
                }
            }
        }

        guard credentials != originalCredentials else { return allReadsSucceeded }
        guard writeVault(credentials) else { return false }
        for importedAccount in importedAccounts {
            _ = backend.remove(service, importedAccount)
        }
        return allReadsSucceeded
    }

    func readLegacyRootCredential(authenticationContext: LAContext? = nil) -> String? {
        guard case let .found(value) = readLegacyCredential(account: account, authenticationContext: authenticationContext) else { return nil }
        return value
    }

    func removeLegacyRootCredential() {
        _ = backend.remove(service, account)
    }

    private enum LegacyCredentialReadResult {
        case found(String)
        case notFound
        case failed
    }

    private func readLegacyCredential(account: String, authenticationContext: LAContext?) -> LegacyCredentialReadResult {
        switch backend.read(service, account, authenticationContext) {
        case let .found(data):
            guard let value = String(data: data, encoding: .utf8), !value.isEmpty else {
                return .notFound
            }
            return .found(value)
        case .notFound:
            return .notFound
        case .failed:
            return .failed
        }
    }

    private func writeVault(_ credentials: [String: String]) -> Bool {
        let payload = VaultPayload(schemaVersion: 1, credentials: credentials)
        guard let data = try? JSONEncoder().encode(payload),
              backend.save(service, Self.vaultAccount, data) else {
            return false
        }
        state.credentials = credentials
        return true
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
    var urlMode: TranslationEndpointURLMode
    var modelName: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String = "新配置",
        baseURL: String = "",
        urlMode: TranslationEndpointURLMode = .baseURL,
        modelName: String = "",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.urlMode = urlMode
        self.modelName = modelName
        self.isEnabled = isEnabled
    }

    var isConfigured: Bool {
        Self.isValidEndpointURL(baseURL) &&
            !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func isValidEndpointURL(_ value: String) -> Bool {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return ["http", "https"].contains(url.scheme?.lowercased() ?? "") &&
            url.host != nil &&
            url.query == nil &&
            url.fragment == nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case baseURL
        case urlMode
        case modelName
        case isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        baseURL = try container.decode(String.self, forKey: .baseURL)
        urlMode = try container.decodeIfPresent(TranslationEndpointURLMode.self, forKey: .urlMode) ?? .baseURL
        modelName = try container.decode(String.self, forKey: .modelName)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}

enum APIKeyDraftResolver {
    static func resolve(_ draft: String, fallback: () -> String?) -> String? {
        let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedDraft.isEmpty ? fallback() : trimmedDraft
    }
}

@MainActor
final class MarlaSettingsStore: ObservableObject {
    @Published var profiles: [TranslationAPIProfile] {
        didSet { saveProfiles() }
    }
    @Published var defaultProfileID: UUID? {
        didSet { saveDefaultProfileID() }
    }
    var baseURL: String {
        get { defaultProfile?.baseURL ?? "" }
        set { updateProfile(id: defaultProfile?.id, baseURL: newValue) }
    }
    var modelName: String {
        get { defaultProfile?.modelName ?? "" }
        set { updateProfile(id: defaultProfile?.id, modelName: newValue) }
    }
    @Published private(set) var nativeLanguage: TranslationLanguage
    @Published private(set) var secondaryLanguage: TranslationLanguage
    @Published var selectionCopyFallbackEnabled: Bool {
        didSet { defaults.set(selectionCopyFallbackEnabled, forKey: Keys.selectionCopyFallback) }
    }
    @Published private(set) var credentialRevision = 0
    @Published private(set) var onboardingSkipped: Bool

    let keychain: KeychainCredentialStore
    private let defaults: UserDefaults
    private let shouldMigrateRootCredentialWithoutProfiles: Bool

    private enum Keys {
        static let profiles = "translationAPIProfiles.v1"
        static let defaultProfileID = "translationDefaultProfileID"
        static let baseURL = "translationBaseURL"
        static let modelName = "translationModelName"
        static let nativeLanguage = "translationNativeLanguage.v1"
        static let secondaryLanguage = "translationSecondaryLanguage.v1"
        static let selectionCopyFallback = "selectionCopyFallbackEnabled"
        static let onboardingSkipped = "onboardingSkipped"
    }

    init(defaults: UserDefaults = .standard, keychain: KeychainCredentialStore = KeychainCredentialStore()) {
        self.defaults = defaults
        self.keychain = keychain
        let persistedProfilesData = defaults.data(forKey: Keys.profiles)
        shouldMigrateRootCredentialWithoutProfiles = persistedProfilesData == nil
        if let data = persistedProfilesData,
           let decoded = try? JSONDecoder().decode([TranslationAPIProfile].self, from: data) {
            profiles = decoded
            let storedID = defaults.string(forKey: Keys.defaultProfileID).flatMap(UUID.init(uuidString:))
            defaultProfileID = decoded.contains(where: { $0.id == storedID && $0.isEnabled })
                ? storedID
                : decoded.first(where: \.isEnabled)?.id
        } else {
            let legacyURL = defaults.string(forKey: Keys.baseURL) ?? ""
            let legacyModel = defaults.string(forKey: Keys.modelName) ?? ""
            if !legacyURL.isEmpty || !legacyModel.isEmpty {
                let migrated = TranslationAPIProfile(name: "默认配置", baseURL: legacyURL, modelName: legacyModel)
                profiles = [migrated]
                defaultProfileID = migrated.id
            } else {
                profiles = []
                defaultProfileID = nil
            }
        }
        let storedNativeLanguage = TranslationLanguage(rawValue: defaults.string(forKey: Keys.nativeLanguage) ?? "") ?? .simplifiedChinese
        nativeLanguage = storedNativeLanguage
        let storedSecondaryLanguage = TranslationLanguage(rawValue: defaults.string(forKey: Keys.secondaryLanguage) ?? "") ?? .english
        secondaryLanguage = storedSecondaryLanguage == storedNativeLanguage
            ? Self.fallbackLanguage(excluding: storedNativeLanguage)
            : storedSecondaryLanguage
        selectionCopyFallbackEnabled = defaults.bool(forKey: Keys.selectionCopyFallback)
        onboardingSkipped = defaults.bool(forKey: Keys.onboardingSkipped)
        saveProfiles()
        saveDefaultProfileID()
        saveLanguagePreferences()
    }

    var defaultTarget: TranslationTarget { .automatic }

    func setNativeLanguage(_ language: TranslationLanguage) {
        guard language != secondaryLanguage else { return }
        nativeLanguage = language
        saveLanguagePreferences()
    }

    func setSecondaryLanguage(_ language: TranslationLanguage) {
        guard language != nativeLanguage else { return }
        secondaryLanguage = language
        saveLanguagePreferences()
    }

    private static func fallbackLanguage(excluding language: TranslationLanguage) -> TranslationLanguage {
        TranslationLanguage.allCases.first(where: { $0 != language }) ?? .english
    }

    private func saveLanguagePreferences() {
        defaults.set(nativeLanguage.rawValue, forKey: Keys.nativeLanguage)
        defaults.set(secondaryLanguage.rawValue, forKey: Keys.secondaryLanguage)
    }

    /// Called only after NSApplication finishes launching. This is the sole
    /// production entry point that may show Keychain authorization for reads.
    func loadCredentialsAfterApplicationLaunch() {
        let authenticationContext = LAContext()
        authenticationContext.localizedReason = "Marla 需要在启动时读取翻译 API Key"

        guard keychain.loadVault(authenticationContext: authenticationContext) else {
            credentialRevision += 1
            return
        }

        if profiles.isEmpty,
           shouldMigrateRootCredentialWithoutProfiles,
           let legacyKey = keychain.readLegacyRootCredential(authenticationContext: authenticationContext) {
            let migrated = TranslationAPIProfile(name: "默认配置")
            profiles = [migrated]
            defaultProfileID = migrated.id
            if (try? keychain.scoped(to: migrated.id).save(legacyKey)) != nil {
                keychain.removeLegacyRootCredential()
            }
        }

        keychain.migrateLegacyCredentials(
            profileIDs: profiles.map(\.id),
            defaultProfileID: defaultProfileID,
            authenticationContext: authenticationContext
        )
        credentialRevision += 1
    }

    var defaultProfile: TranslationAPIProfile? {
        guard let defaultProfileID else { return nil }
        return profiles.first(where: { $0.id == defaultProfileID && $0.isEnabled })
    }

    var enabledProfiles: [TranslationAPIProfile] {
        profiles.filter(\.isEnabled)
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
        guard let profile = profile(id: profileID), profile.isEnabled, profile.isConfigured else { return nil }
        return TranslationEndpointConfiguration(
            baseURL: profile.baseURL,
            urlMode: profile.urlMode,
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

    func updateProfile(
        id: UUID?,
        name: String? = nil,
        baseURL: String? = nil,
        urlMode: TranslationEndpointURLMode? = nil,
        modelName: String? = nil
    ) {
        let targetID = id ?? defaultProfileID ?? profiles.first?.id ?? addProfile()
        guard let index = profiles.firstIndex(where: { $0.id == targetID }) else { return }
        if let name { profiles[index].name = name }
        if let baseURL { profiles[index].baseURL = baseURL }
        if let urlMode { profiles[index].urlMode = urlMode }
        if let modelName { profiles[index].modelName = modelName }
        if defaultProfileID == nil, profiles[index].isEnabled { defaultProfileID = targetID }
        saveProfiles()
    }

    func setDefaultProfile(_ id: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        if !profiles[index].isEnabled {
            profiles[index].isEnabled = true
        }
        defaultProfileID = id
    }

    func setProfileEnabled(_ isEnabled: Bool, for id: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        guard profiles[index].isEnabled != isEnabled else {
            if isEnabled, defaultProfileID == nil { defaultProfileID = id }
            if !isEnabled, defaultProfileID == id {
                defaultProfileID = nextEnabledProfileID(after: index, excluding: id)
            }
            return
        }

        profiles[index].isEnabled = isEnabled
        if isEnabled {
            if defaultProfileID == nil { defaultProfileID = id }
        } else if defaultProfileID == id {
            defaultProfileID = nextEnabledProfileID(after: index, excluding: id)
        }
    }

    func moveProfile(id: UUID, by offset: Int) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + offset
        guard profiles.indices.contains(destination) else { return }
        profiles.swapAt(index, destination)
    }

    @discardableResult
    func moveProfile(id: UUID, onto targetID: UUID) -> Bool {
        guard id != targetID,
              let sourceIndex = profiles.firstIndex(where: { $0.id == id }),
              let targetIndex = profiles.firstIndex(where: { $0.id == targetID }) else { return false }
        let profile = profiles.remove(at: sourceIndex)
        profiles.insert(profile, at: min(targetIndex, profiles.count))
        return true
    }

    func removeProfile(id: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let replacementDefaultID = nextEnabledProfileID(after: index, excluding: id)
        keychain.scoped(to: id).remove()
        profiles.remove(at: index)
        if defaultProfileID == id { defaultProfileID = replacementDefaultID }
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

    private func saveDefaultProfileID() {
        if let defaultProfileID {
            defaults.set(defaultProfileID.uuidString, forKey: Keys.defaultProfileID)
        } else {
            defaults.removeObject(forKey: Keys.defaultProfileID)
        }
    }

    private func nextEnabledProfileID(after index: Int, excluding excludedID: UUID) -> UUID? {
        if index + 1 < profiles.count,
           let next = profiles[(index + 1)...].first(where: { $0.id != excludedID && $0.isEnabled }) {
            return next.id
        }
        return profiles[..<index].first(where: { $0.id != excludedID && $0.isEnabled })?.id
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
        // Keep dragging scoped to the native title bar. Treating the entire
        // content surface as a window-drag region steals pointer drags from
        // controls such as the API profile reorder handle.
        window.isMovableByWindowBackground = false
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
    var nativeLanguage: TranslationLanguage = .simplifiedChinese
    var secondaryLanguage: TranslationLanguage = .english
    var source: TranslationSource = .automatic
    var detectedSourceLanguage: TranslationLanguage?
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

    var resolvedSourceLanguage: TranslationLanguage? {
        source.resolved(using: detectedSourceLanguage)
    }

    var resolvedTargetLanguage: TranslationLanguage {
        TranslationLanguageRouter.targetLanguage(
            sourceLanguage: resolvedSourceLanguage,
            target: target,
            nativeLanguage: nativeLanguage,
            secondaryLanguage: secondaryLanguage
        )
    }

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
    let nativeLanguage: TranslationLanguage
    let secondaryLanguage: TranslationLanguage
    let source: TranslationSource
    let detectedSourceLanguage: TranslationLanguage?
    let target: TranslationTarget
}

enum SystemSourceLanguageDetector {
    static func detect(_ text: String) -> TranslationLanguage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        return TranslationLanguage(normalizing: recognizer.dominantLanguage?.rawValue)
    }
}

@MainActor
final class TranslationSessionStore: ObservableObject {
    @Published private(set) var session: CardSession?
    @Published private(set) var recentTranslations: [RecentTranslation] = []

    static let recentTranslationLimit = 3

    private let settings: MarlaSettingsStore
    private let client = RustTranslationClient()
    private let sourceLanguageDetector: (String) -> TranslationLanguage?
    private var handle: RustTranslationClient.Handle?

    init(
        settings: MarlaSettingsStore,
        sourceLanguageDetector: @escaping (String) -> TranslationLanguage? = SystemSourceLanguageDetector.detect
    ) {
        self.settings = settings
        self.sourceLanguageDetector = sourceLanguageDetector
    }

    var availableProfiles: [TranslationAPIProfile] { settings.enabledProfiles }
    var nativeLanguage: TranslationLanguage { settings.nativeLanguage }
    var secondaryLanguage: TranslationLanguage { settings.secondaryLanguage }

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
            nativeLanguage: settings.nativeLanguage,
            secondaryLanguage: settings.secondaryLanguage,
            target: settings.defaultTarget,
            state: .recognizing,
            anchor: anchor,
            pointer: pointer,
            isActivating: false
        )
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
            nativeLanguage: settings.nativeLanguage,
            secondaryLanguage: settings.secondaryLanguage,
            source: .automatic,
            detectedSourceLanguage: sourceLanguageDetector(sourceText),
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
        session?.detectedSourceLanguage = sourceLanguageDetector(text)
        startRequest(for: id)
    }

    func startText(
        _ text: String,
        surface: TranslationSurface,
        anchor: ScreenRect?,
        pointer: CGPoint?,
        activate: Bool = false,
        source: TranslationSource = .automatic,
        target: TranslationTarget? = nil,
        profileID: UUID? = nil
    ) {
        cancelCurrentRequest()
        let id = UUID()
        session = CardSession(
            id: id,
            surface: surface,
            profileID: profileID ?? settings.defaultProfile?.id,
            profileName: settings.profile(id: profileID ?? settings.defaultProfile?.id)?.name ?? "未配置",
            sourceText: text,
            translation: "",
            nativeLanguage: settings.nativeLanguage,
            secondaryLanguage: settings.secondaryLanguage,
            source: source,
            detectedSourceLanguage: sourceLanguageDetector(text),
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
            sourceLanguage: current.resolvedSourceLanguage,
            target: .explicit(current.resolvedTargetLanguage),
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
        guard var current = session, !current.sourceText.isEmpty else { return }
        cancelCurrentRequest()
        current.translation = ""
        current.state = .acquiring
        current.errorCode = nil
        current.errorRetryable = false
        current.recoveryAction = nil
        current.id = UUID()
        session = current
        startRequest(for: current.id)
    }

    func changeAPIProfile(_ profileID: UUID) {
        guard var current = session,
              !current.sourceText.isEmpty,
              let profile = settings.profile(id: profileID),
              profile.isEnabled,
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

    func changeSource(_ source: TranslationSource) {
        guard var current = session, !current.sourceText.isEmpty else { return }
        cancelCurrentRequest()
        current.source = source
        current.translation = ""
        current.state = .acquiring
        current.errorCode = nil
        current.errorRetryable = false
        current.recoveryAction = nil
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
            nativeLanguage: recent.nativeLanguage,
            secondaryLanguage: recent.secondaryLanguage,
            source: recent.source,
            detectedSourceLanguage: recent.detectedSourceLanguage,
            target: recent.target,
            state: .completed,
            anchor: nil,
            pointer: NSEvent.mouseLocation,
            isActivating: true
        )
        session = restored
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
                $0.nativeLanguage == candidate.nativeLanguage &&
                $0.secondaryLanguage == candidate.secondaryLanguage &&
                $0.source == candidate.source &&
                $0.detectedSourceLanguage == candidate.detectedSourceLanguage &&
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
                nativeLanguage: candidate.nativeLanguage,
                secondaryLanguage: candidate.secondaryLanguage,
                source: candidate.source,
                detectedSourceLanguage: candidate.detectedSourceLanguage,
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
        show(
            content: content,
            width: 380,
            height: 300,
            anchor: anchor,
            pointer: pointer,
            activate: activate
        )
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
        show(
            content: content,
            width: 420,
            height: 300,
            anchor: nil,
            pointer: pointer,
            activate: true
        )
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

    private func show(
        content: AnyView,
        width: CGFloat,
        height: CGFloat,
        anchor: ScreenRect?,
        pointer: CGPoint?,
        activate: Bool
    ) {
        let panel = panel ?? makePanel()
        let forcedReduceMotion = ProcessInfo.processInfo.environment["MARLA_UI_TEST_REDUCE_MOTION"] == "1"
        let hostingView = NSHostingView(
            rootView: content.environment(\.marlaReduceMotionOverride, forcedReduceMotion)
        )
        FloatingPanelStyle.apply(to: panel)
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
        let targetScreen = screen(anchor: anchor, pointer: pointer) ?? NSScreen.main ?? NSScreen.screens.first!
        return PanelPlacementCalculator.frame(
            visibleFrame: targetScreen.visibleFrame,
            requestedWidth: requestedWidth,
            requestedHeight: requestedHeight,
            anchor: anchor,
            pointer: pointer
        )
    }

    private func screen(anchor: ScreenRect?, pointer: CGPoint?) -> NSScreen? {
        anchor.flatMap { rect in
            NSScreen.screens.first { $0.frame.intersects(NSRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)) }
        } ?? pointer.flatMap { point in
            NSScreen.screens.first { $0.frame.contains(point) }
        }
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

    static var isUIAutomationSnapshot: Bool {
        ProcessInfo.processInfo.environment["MARLA_UI_TEST_CAPTURE_PATH"] != nil
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
    private var capturePreparationTask: Task<Void, Never>?
    private var capturePreparationID: UUID?

    func present(completion: @escaping (Result<CapturedScreenshot, Error>) -> Void) {
        if self.completion != nil {
            finish(.failure(ScreenshotError.cancelled))
        }
        self.completion = completion
        let preparationID = UUID()
        capturePreparationID = preparationID
        let escapeMonitor = ScreenshotEscapeMonitor { [weak self] in
            guard let self, self.capturePreparationID == preparationID else { return }
            if let selectionSession {
                selectionSession.cancel()
            } else {
                finish(.failure(ScreenshotError.cancelled))
            }
        }
        self.escapeMonitor = escapeMonitor
        escapeMonitor.install()

        capturePreparationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let frozenDisplays = try await captureFrozenDisplays()
                try Task.checkCancellation()
                guard capturePreparationID == preparationID else { return }
                capturePreparationTask = nil
                showSelection(using: frozenDisplays)
            } catch is CancellationError {
                return
            } catch {
                guard capturePreparationID == preparationID else { return }
                finish(.failure(error))
            }
        }
    }

    private func showSelection(using frozenDisplays: [ScreenshotMagnifierSource]) {
        let session = ScreenshotSelectionSession(magnifierSources: frozenDisplays) { [weak self] rect, cancelled in
            guard let self else { return }
            if cancelled {
                finish(.failure(ScreenshotError.cancelled))
            } else {
                capture(global: rect, from: frozenDisplays)
            }
        }
        selectionSession = session
        windows = frozenDisplays.map { source in
            let window = ScreenshotSelectionWindow(
                contentRect: source.screenFrame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                onCancel: { [weak session] in session?.cancel() }
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.acceptsMouseMovedEvents = true
            window.contentView = ScreenshotSelectionView(session: session, frozenSource: source)
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
        Task { @MainActor [weak self] in
            guard let self else { return }
            for _ in 0..<100 where selectionSession == nil {
                try? await Task.sleep(for: .milliseconds(10))
            }
            guard let screen = NSScreen.main else { return }
            let frame = screen.frame
            selectionSession?.begin(
                at: NSPoint(x: frame.minX + frame.width * 0.24, y: frame.minY + frame.height * 0.3)
            )
            selectionSession?.move(
                to: NSPoint(x: frame.minX + frame.width * 0.76, y: frame.minY + frame.height * 0.68)
            )
        }
    }

    private func capture(global: NSRect, from frozenDisplays: [ScreenshotMagnifierSource]) {
        guard global.width > 4, global.height > 4 else {
            finish(.failure(ScreenshotError.invalidRegion))
            return
        }
        guard let image = ScreenshotFrozenCapture.image(
            global: global,
            frozenDisplays: frozenDisplays
        ) else {
            finish(.failure(ScreenshotError.captureFailed))
            return
        }
        finish(.success(CapturedScreenshot(image: image, globalRect: global)))
    }

    private func captureFrozenDisplays() async throws -> [ScreenshotMagnifierSource] {
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        let ownApplication = shareableContent.applications.first {
            $0.processID == ProcessInfo.processInfo.processIdentifier
        }
        var frozenDisplays: [ScreenshotMagnifierSource] = []
        for screen in NSScreen.screens {
            try Task.checkCancellation()
            guard let screenNumber = screen.deviceDescription[
                    NSDeviceDescriptionKey("NSScreenNumber")
                  ] as? NSNumber,
                  let display = shareableContent.displays.first(where: {
                      $0.displayID == CGDirectDisplayID(screenNumber.uint32Value)
                  }) else {
                continue
            }

            let configuration = SCStreamConfiguration()
            configuration.sourceRect = CGRect(origin: .zero, size: screen.frame.size)
            configuration.width = max(1, Int(screen.frame.width * screen.backingScaleFactor))
            configuration.height = max(1, Int(screen.frame.height * screen.backingScaleFactor))
            configuration.showsCursor = false
            let filter: SCContentFilter
            if let ownApplication {
                filter = SCContentFilter(
                    display: display,
                    excludingApplications: [ownApplication],
                    exceptingWindows: []
                )
            } else {
                filter = SCContentFilter(display: display, excludingWindows: [])
            }
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            frozenDisplays.append(
                ScreenshotMagnifierSource(screenFrame: screen.frame, cgImage: image)
            )
        }
        guard !frozenDisplays.isEmpty, frozenDisplays.count == NSScreen.screens.count else {
            throw ScreenshotError.captureFailed
        }
        return frozenDisplays
    }

    private func finish(_ result: Result<CapturedScreenshot, Error>) {
        capturePreparationTask?.cancel()
        capturePreparationTask = nil
        capturePreparationID = nil
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
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private let onEscape: () -> Void

    init(onEscape: @escaping () -> Void) {
        self.onEscape = onEscape
    }

    var isInstalled: Bool {
        localMonitor != nil || globalMonitor != nil || eventTap != nil
    }

    var hasEventTap: Bool {
        eventTap != nil
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
        installEventTap()
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
        if let eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
            self.eventTapSource = nil
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
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

    func handleEventTapEscape() {
        onEscape()
    }

    nonisolated static func isCancelKeyCode(_ keyCode: UInt16) -> Bool {
        keyCode == 53
    }

    func reenableEventTap() {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func installEventTap() {
        let keyDownMask = CGEventMask(1) << CGEventType.keyDown.rawValue
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        // A default tap can be denied when Marla is allowed to listen but not
        // suppress system keyboard events.  A listen-only tap still gives us a
        // process-independent Escape notification; local/global monitors remain
        // responsible for consuming it when AppKit owns the event.
        let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: keyDownMask,
            callback: handleScreenshotEscapeEventTap,
            userInfo: userInfo
        ) ?? CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: keyDownMask,
            callback: handleScreenshotEscapeEventTap,
            userInfo: userInfo
        )
        guard let eventTap else { return }
        guard let source = CFMachPortCreateRunLoopSource(nil, eventTap, 0) else {
            CFMachPortInvalidate(eventTap)
            return
        }
        self.eventTap = eventTap
        eventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
}

private func handleScreenshotEscapeEventTap(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userData: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userData else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<ScreenshotEscapeMonitor>.fromOpaque(userData).takeUnretainedValue()
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        Task { @MainActor in monitor.reenableEventTap() }
        return Unmanaged.passUnretained(event)
    }
    guard type == .keyDown,
          ScreenshotEscapeMonitor.isCancelKeyCode(
              UInt16(event.getIntegerValueField(.keyboardEventKeycode))
          )
    else { return Unmanaged.passUnretained(event) }
    Task { @MainActor in monitor.handleEventTapEscape() }
    return nil
}

final class ScreenshotSelectionWindow: NSWindow {
    private let onCancel: () -> Void

    init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool,
        onCancel: @escaping () -> Void = {}
    ) {
        self.onCancel = onCancel
        super.init(
            contentRect: contentRect,
            styleMask: style,
            backing: backingStoreType,
            defer: flag
        )
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // AppKit can route Escape as a key equivalent or cancelOperation rather
    // than delivering keyDown to the content view. Keep a window-owned path
    // so cancellation does not depend on first-responder identity.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard ScreenshotEscapeMonitor.isCancelKeyCode(event.keyCode) else {
            return super.performKeyEquivalent(with: event)
        }
        onCancel()
        return true
    }

    // A borderless overlay can receive the key event through NSWindow's
    // dispatch path without ever asking the first responder to handle it.
    // Catch Escape here as well so cancellation remains independent of the
    // hosted SwiftUI view and of AppKit key-equivalent routing details.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown,
           ScreenshotEscapeMonitor.isCancelKeyCode(event.keyCode) {
            onCancel()
            return
        }
        super.sendEvent(event)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }
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

@MainActor
enum ScreenshotFrozenCapture {
    struct Fragment {
        let displayIndex: Int
        let clipRect: CGRect
        let fullDisplayRect: CGRect
    }

    struct Layout {
        let pixelSize: CGSize
        let scale: CGFloat
        let fragments: [Fragment]
    }

    static func layout(
        global: CGRect,
        frozenDisplays: [ScreenshotMagnifierSource]
    ) -> Layout? {
        guard global.width > 0, global.height > 0 else { return nil }
        let intersectingDisplays = frozenDisplays.enumerated().filter {
            !$0.element.screenFrame.intersection(global).isNull
                && $0.element.screenFrame.intersection(global).width > 0
                && $0.element.screenFrame.intersection(global).height > 0
        }
        guard !intersectingDisplays.isEmpty else { return nil }
        let scale = intersectingDisplays.map(\.element.pixelScale).max() ?? 1
        let pixelSize = CGSize(
            width: max(1, (global.width * scale).rounded(.up)),
            height: max(1, (global.height * scale).rounded(.up))
        )
        let fragments = intersectingDisplays.map { index, source in
            let intersection = source.screenFrame.intersection(global)
            return Fragment(
                displayIndex: index,
                clipRect: ScreenCaptureGeometry.destinationRect(
                    intersection: intersection,
                    selection: global,
                    scale: scale
                ),
                fullDisplayRect: CGRect(
                    x: (source.screenFrame.minX - global.minX) * scale,
                    y: (source.screenFrame.minY - global.minY) * scale,
                    width: source.screenFrame.width * scale,
                    height: source.screenFrame.height * scale
                )
            )
        }
        return Layout(pixelSize: pixelSize, scale: scale, fragments: fragments)
    }

    static func image(
        global: CGRect,
        frozenDisplays: [ScreenshotMagnifierSource]
    ) -> CGImage? {
        guard let layout = layout(global: global, frozenDisplays: frozenDisplays),
              let context = CGContext(
                  data: nil,
                  width: Int(layout.pixelSize.width),
                  height: Int(layout.pixelSize.height),
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }
        for fragment in layout.fragments {
            context.saveGState()
            context.clip(to: fragment.clipRect)
            context.draw(
                frozenDisplays[fragment.displayIndex].cgImage,
                in: fragment.fullDisplayRect
            )
            context.restoreGState()
        }
        return context.makeImage()
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
    let cgImage: CGImage
    let image: NSImage

    init(screenFrame: NSRect, cgImage: CGImage) {
        self.screenFrame = screenFrame
        self.cgImage = cgImage
        image = NSImage(cgImage: cgImage, size: screenFrame.size)
    }

    init?(screen: NSScreen) {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let cgImage = CGDisplayCreateImage(CGDirectDisplayID(screenNumber.uint32Value)) else {
            return nil
        }
        self.init(screenFrame: screen.frame, cgImage: cgImage)
    }

    var pixelScale: CGFloat {
        guard screenFrame.width > 0, screenFrame.height > 0 else { return 1 }
        return max(
            CGFloat(cgImage.width) / screenFrame.width,
            CGFloat(cgImage.height) / screenFrame.height
        )
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
    private let frozenSource: ScreenshotMagnifierSource?
    private let hintView: NSHostingView<ScreenshotGlassLabel>
    private let sizeView: NSHostingView<ScreenshotGlassLabel>

    init(
        session: ScreenshotSelectionSession,
        frozenSource: ScreenshotMagnifierSource? = nil
    ) {
        self.session = session
        self.frozenSource = frozenSource
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
        frozenSource?.image.draw(
            in: bounds,
            from: NSRect(origin: .zero, size: frozenSource?.image.size ?? .zero),
            operation: .copy,
            fraction: 1
        )
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
            if let frozenSource {
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(rect: rect).addClip()
                frozenSource.image.draw(
                    in: bounds,
                    from: NSRect(origin: .zero, size: frozenSource.image.size),
                    operation: .copy,
                    fraction: 1
                )
                NSGraphicsContext.restoreGraphicsState()
            } else {
                NSGraphicsContext.current?.compositingOperation = .clear
                rect.fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
            }
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
private final class SelectionReadCancellation {
    private(set) var isCancelled = false

    func cancel() {
        isCancelled = true
    }
}

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

    let settings: MarlaSettingsStore
    let sessionStore: TranslationSessionStore
    let panelCoordinator: FloatingPanelCoordinator
    let screenshotCoordinator = ScreenshotCaptureCoordinator()
    let visionOCR = VisionOCRService()
    let shortcutManager: GlobalShortcutManager
    let settingsWindowCoordinator = MarlaSettingsWindowCoordinator()

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
        let installsInteractiveMonitors = enableSystemIntegrations && !MarlaRuntime.isUIAutomationSnapshot
        self.selectionReader = selectionReader
        self.settings = settings
        sessionStore = TranslationSessionStore(settings: settings)
        panelCoordinator = FloatingPanelCoordinator(installEventMonitors: installsInteractiveMonitors)
        shortcutManager = GlobalShortcutManager(registerHotKeys: installsInteractiveMonitors)
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
            let selection = try selectionReader.readSelection(
                from: triggerApplication,
                allowCopyFallback: settings.selectionCopyFallbackEnabled,
                isCancelled: { readCancellation.isCancelled }
            )
            sessionStore.startText(selection.text, surface: .selection, anchor: selection.bounds, pointer: pointer)
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
            let selection = try selectionReader.readSelection(
                from: triggerApplication ?? audit.sourceApplication,
                allowCopyFallback: settings.selectionCopyFallbackEnabled,
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
            let selection = try selectionReader.readSelection(
                from: NSWorkspace.shared.frontmostApplication,
                allowCopyFallback: settings.selectionCopyFallbackEnabled
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
        case .selectionCancelled: "已取消本次兼容取词。"
        case .copyFallbackUnavailable: "兼容取词没有取得新的选区文本，请重试或使用快速输入。"
        case .copyFallbackTimedOut: "兼容取词等待应用响应超时，请重试或使用快速输入。"
        case .clipboardRestoreFailed: "兼容取词未能安全恢复剪贴板，已停止翻译请求。"
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
