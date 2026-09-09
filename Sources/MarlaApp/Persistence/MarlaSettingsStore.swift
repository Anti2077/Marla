import Combine
import CoreGraphics
import Foundation
import LocalAuthentication
import MarlaCore

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
    @Published private(set) var credentialRevision = 0
    @Published private(set) var onboardingSkipped: Bool
    @Published var ocrProvider: OCRProviderKind {
        didSet { defaults.set(ocrProvider.rawValue, forKey: Keys.ocrProvider) }
    }
    @Published var isInPlaceTranslationEnabled: Bool {
        didSet { defaults.set(isInPlaceTranslationEnabled, forKey: Keys.inPlaceTranslationEnabled) }
    }
    @Published var translationWindowPlacement: TranslationWindowPlacement {
        didSet { defaults.set(translationWindowPlacement.rawValue, forKey: Keys.translationWindowPlacement) }
    }
    @Published var translationWindowFixedX: CGFloat {
        didSet { defaults.set(Double(translationWindowFixedX), forKey: Keys.translationWindowFixedX) }
    }
    @Published var translationWindowWidthPreset: TranslationWindowWidthPreset {
        didSet { defaults.set(translationWindowWidthPreset.rawValue, forKey: Keys.translationWindowWidthPreset) }
    }
    private(set) var translationWindowLastTopLeft: CGPoint?
    @Published var settingsNavigationDestination: SettingsNavigationDestination?

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
        static let onboardingSkipped = "onboardingSkipped"
        static let ocrProvider = "ocrProvider.v1"
        static let inPlaceTranslationEnabled = "inPlaceTranslationEnabled.v1"
        static let translationWindowPlacement = "translationWindowPlacement.v1"
        static let translationWindowFixedX = "translationWindowFixedX.v1"
        static let translationWindowWidthPreset = "translationWindowWidthPreset.v1"
        static let translationWindowLastTopX = "translationWindowLastTopX.v1"
        static let translationWindowLastTopY = "translationWindowLastTopY.v1"
        // Kept for one-time migration from the previous bottom-left position format.
        static let translationWindowLastOriginX = "translationWindowLastOriginX.v1"
        static let translationWindowLastOriginY = "translationWindowLastOriginY.v1"
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
        onboardingSkipped = defaults.bool(forKey: Keys.onboardingSkipped)
        ocrProvider = OCRProviderKind(rawValue: defaults.string(forKey: Keys.ocrProvider) ?? "") ?? .vision
        isInPlaceTranslationEnabled = defaults.object(forKey: Keys.inPlaceTranslationEnabled) as? Bool ?? false
        translationWindowPlacement = TranslationWindowPlacement(
            rawValue: defaults.string(forKey: Keys.translationWindowPlacement) ?? ""
        ) ?? .automatic
        let fixedX = defaults.object(forKey: Keys.translationWindowFixedX) as? Double
        translationWindowFixedX = CGFloat(
            fixedX.flatMap { $0.isFinite ? $0 : nil }
                ?? Double(TranslationWindowPlacement.defaultFixedX)
        )
        translationWindowWidthPreset = TranslationWindowWidthPreset(
            rawValue: defaults.string(forKey: Keys.translationWindowWidthPreset) ?? ""
        ) ?? .narrow
        let lastX = (defaults.object(forKey: Keys.translationWindowLastTopX) as? Double)
            ?? (defaults.object(forKey: Keys.translationWindowLastOriginX) as? Double)
        let lastY = (defaults.object(forKey: Keys.translationWindowLastTopY) as? Double)
            ?? (defaults.object(forKey: Keys.translationWindowLastOriginY) as? Double)
        if let lastX, let lastY, lastX.isFinite, lastY.isFinite {
            translationWindowLastTopLeft = CGPoint(x: lastX, y: lastY)
        } else {
            translationWindowLastTopLeft = nil
        }
        settingsNavigationDestination = nil
        saveProfiles()
        saveDefaultProfileID()
        saveLanguagePreferences()
    }

    var defaultTarget: TranslationTarget { .automatic }

    func rememberTranslationWindowTopLeft(_ topLeft: CGPoint) {
        guard topLeft.x.isFinite, topLeft.y.isFinite else { return }
        translationWindowLastTopLeft = topLeft
        defaults.set(Double(topLeft.x), forKey: Keys.translationWindowLastTopX)
        defaults.set(Double(topLeft.y), forKey: Keys.translationWindowLastTopY)
    }

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
            providerProtocol: profile.providerProtocol,
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
        providerProtocol: TranslationProviderProtocol? = nil,
        baseURL: String? = nil,
        urlMode: TranslationEndpointURLMode? = nil,
        modelName: String? = nil
    ) {
        let targetID = id ?? defaultProfileID ?? profiles.first?.id ?? addProfile()
        guard let index = profiles.firstIndex(where: { $0.id == targetID }) else { return }
        if let name { profiles[index].name = name }
        if let providerProtocol { profiles[index].providerProtocol = providerProtocol }
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

    @discardableResult
    func setProfileOrder(_ orderedIDs: [UUID]) -> Bool {
        guard orderedIDs.count == profiles.count,
              Set(orderedIDs) == Set(profiles.map(\.id)) else { return false }
        guard orderedIDs != profiles.map(\.id) else { return true }
        let profilesByID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        profiles = orderedIDs.compactMap { profilesByID[$0] }
        return profiles.count == orderedIDs.count
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

    func noteCredentialChanged() {
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
