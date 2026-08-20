import Foundation
import MarlaCore

enum SettingsNavigationDestination: Equatable {
    case ocr
}

extension MarlaSettingsStore {
    var glmOCRAPIKey: String? {
        keychain.scoped(toAccount: KeychainCredentialStore.glmOCRAccount).read()
    }

    var hasGLMOCRAPIKey: Bool { glmOCRAPIKey != nil }

    func setOCRProvider(_ provider: OCRProviderKind) {
        ocrProvider = provider
    }

    func saveGLMOCRAPIKey(_ draft: String) throws {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        try keychain.scoped(toAccount: KeychainCredentialStore.glmOCRAccount).save(value)
        noteCredentialChanged()
    }

    func removeGLMOCRAPIKey() {
        keychain.scoped(toAccount: KeychainCredentialStore.glmOCRAccount).remove()
        noteCredentialChanged()
    }

    func requestSettingsNavigation(to destination: SettingsNavigationDestination) {
        settingsNavigationDestination = destination
    }

    func consumeSettingsNavigation(_ destination: SettingsNavigationDestination) {
        guard settingsNavigationDestination == destination else { return }
        settingsNavigationDestination = nil
    }
}
