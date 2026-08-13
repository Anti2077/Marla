import Foundation
import LocalAuthentication
import Security

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

