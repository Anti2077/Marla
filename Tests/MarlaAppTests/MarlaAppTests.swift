import AppKit
import MarlaCore
@testable import MarlaApp
import XCTest

@MainActor
private final class FakeSelectionClipboard: SelectionClipboardAccess {
    var changeCount = 0
    var text: String?
    var snapshotValue = PasteboardSnapshot(items: [])
    var changeCountAfterSnapshot: Int?
    var restoreResponse = ClipboardRestoreStatus.restored
    var restoreCalls = 0
    var lastRestoredSnapshot: PasteboardSnapshot?

    func snapshot() throws -> PasteboardSnapshot {
        if let changeCountAfterSnapshot {
            changeCount = changeCountAfterSnapshot
        }
        return snapshotValue
    }

    func plainText() -> String? { text }

    func restore(
        _ snapshot: PasteboardSnapshot,
        ifUnchangedFrom expectedChangeCount: Int
    ) -> ClipboardRestoreStatus {
        restoreCalls += 1
        guard changeCount == expectedChangeCount else {
            return .skippedBecauseClipboardChanged
        }
        lastRestoredSnapshot = snapshot
        return restoreResponse
    }
}

@MainActor
private final class FakeKeychainItems {
    var items: [String: Data] = [:]
    var deniedAccounts: Set<String> = []
    var readAccounts: [String] = []
    var authenticationContextIDs: [ObjectIdentifier] = []
    var savedAccounts: [String] = []
    var removedAccounts: [String] = []
    var saveSucceeds = true
    var removeSucceeds = true

    var backend: KeychainItemBackend {
        KeychainItemBackend(
            read: { [weak self] _, account, authenticationContext in
                guard let self else { return .failed(-1) }
                readAccounts.append(account)
                if let authenticationContext {
                    authenticationContextIDs.append(ObjectIdentifier(authenticationContext))
                }
                if deniedAccounts.contains(account) { return .failed(-1) }
                guard let data = items[account] else { return .notFound }
                return .found(data)
            },
            save: { [weak self] _, account, data in
                guard let self else { return false }
                savedAccounts.append(account)
                guard saveSucceeds else { return false }
                items[account] = data
                return true
            },
            remove: { [weak self] _, account in
                guard let self else { return false }
                removedAccounts.append(account)
                guard removeSucceeds else { return false }
                items.removeValue(forKey: account)
                return true
            }
        )
    }
}

final class MarlaAppTests: XCTestCase {
    func testDefaultShortcutBindingsAndInternalConflictDetection() {
        let defaults = ShortcutBinding.defaults
        XCTAssertEqual(defaults[.selection]?.displayName, "⌃⌥D")
        XCTAssertEqual(defaults[.screenshot]?.displayName, "⌃⌥S")
        XCTAssertEqual(defaults[.quickInput]?.displayName, "⌃⌥Space")

        let conflict = ShortcutBinding.conflictingAction(
            in: defaults,
            candidate: defaults[.selection]!,
            excluding: .screenshot
        )
        XCTAssertEqual(conflict, .selection)
    }

    func testQuickInputRejectsWhitespaceWithoutNormalizingValidSource() {
        XCTAssertFalse(QuickInputValidation.isSubmittable(" \n\t "))
        let source = "  Hello\nworld  "
        XCTAssertTrue(QuickInputValidation.isSubmittable(source))
        XCTAssertEqual(source, "  Hello\nworld  ")
    }

    @MainActor
    func testAPIProfilesSupportDefaultOrderingAndIndependentAccounts() {
        let suite = "com.marla.tests.profiles.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let keychain = KeychainCredentialStore(service: "com.marla.tests", account: UUID().uuidString)
        let settings = MarlaSettingsStore(defaults: defaults, keychain: keychain)

        let firstID = settings.addProfile()
        settings.updateProfile(id: firstID, name: "Qwen 快速", baseURL: "https://qwen.example/v1", modelName: "qwen-mt-turbo")
        let secondID = settings.addProfile()
        settings.updateProfile(id: secondID, name: "本地代理", baseURL: "http://127.0.0.1:8080/v1", modelName: "local")
        settings.setDefaultProfile(secondID)
        settings.moveProfile(id: secondID, by: -1)

        XCTAssertEqual(settings.defaultProfile?.id, secondID)
        XCTAssertEqual(settings.profiles.map(\.name), ["本地代理", "Qwen 快速"])
        XCTAssertTrue(settings.profile(id: firstID)?.isConfigured == true)
        XCTAssertNotEqual(keychain.scoped(to: firstID).account, keychain.scoped(to: secondID).account)

        settings.removeProfile(id: secondID)
        XCTAssertNil(settings.profile(id: secondID))
        XCTAssertEqual(settings.defaultProfile?.id, firstID)
    }

    @MainActor
    func testKeychainVaultStoresAndReloadsMultipleProfilesFromOnePhysicalItem() throws {
        let items = FakeKeychainItems()
        let firstID = UUID()
        let secondID = UUID()
        let keychain = KeychainCredentialStore(
            service: "com.marla.tests.vault",
            backend: items.backend
        )

        XCTAssertTrue(keychain.loadVault())
        try keychain.scoped(to: firstID).save("first-key")
        try keychain.scoped(to: secondID).save("second-key")

        XCTAssertEqual(Set(items.items.keys), [KeychainCredentialStore.vaultAccount])
        XCTAssertEqual(items.savedAccounts, [
            KeychainCredentialStore.vaultAccount,
            KeychainCredentialStore.vaultAccount
        ])

        items.readAccounts.removeAll()
        let reloaded = KeychainCredentialStore(
            service: "com.marla.tests.vault",
            backend: items.backend
        )
        XCTAssertTrue(reloaded.loadVault())
        XCTAssertEqual(reloaded.scoped(to: firstID).read(), "first-key")
        XCTAssertEqual(reloaded.scoped(to: secondID).read(), "second-key")
        XCTAssertEqual(items.readAccounts, [KeychainCredentialStore.vaultAccount])
    }

    @MainActor
    func testLegacyProfileItemsMigrateOnlyAfterVaultWriteSucceeds() {
        let items = FakeKeychainItems()
        let firstID = UUID()
        let secondID = UUID()
        let firstAccount = KeychainCredentialStore.profileAccount(for: firstID)
        let secondAccount = KeychainCredentialStore.profileAccount(for: secondID)
        items.items[firstAccount] = Data("first-key".utf8)
        items.items[secondAccount] = Data("second-key".utf8)
        let keychain = KeychainCredentialStore(
            service: "com.marla.tests.migration",
            backend: items.backend
        )

        XCTAssertTrue(keychain.loadVault())
        items.saveSucceeds = false
        XCTAssertFalse(keychain.migrateLegacyCredentials(
            profileIDs: [firstID, secondID],
            defaultProfileID: firstID
        ))
        XCTAssertNotNil(items.items[firstAccount])
        XCTAssertNotNil(items.items[secondAccount])
        XCTAssertTrue(items.removedAccounts.isEmpty)

        items.saveSucceeds = true
        XCTAssertTrue(keychain.migrateLegacyCredentials(
            profileIDs: [firstID, secondID],
            defaultProfileID: firstID
        ))

        XCTAssertEqual(keychain.scoped(to: firstID).read(), "first-key")
        XCTAssertEqual(keychain.scoped(to: secondID).read(), "second-key")
        XCTAssertNotNil(items.items[KeychainCredentialStore.vaultAccount])
        XCTAssertNil(items.items[firstAccount])
        XCTAssertNil(items.items[secondAccount])
        XCTAssertEqual(Set(items.removedAccounts), [firstAccount, secondAccount])
    }

    @MainActor
    func testStartupMigrationReusesOneAuthenticationContextForAllLegacyItems() throws {
        let suite = "com.marla.tests.authentication-context.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let firstID = UUID()
        let secondID = UUID()
        let profiles = [
            TranslationAPIProfile(id: firstID, name: "第一配置"),
            TranslationAPIProfile(id: secondID, name: "第二配置")
        ]
        defaults.set(try JSONEncoder().encode(profiles), forKey: "translationAPIProfiles.v1")
        defaults.set(firstID.uuidString, forKey: "translationDefaultProfileID")

        let items = FakeKeychainItems()
        items.items[KeychainCredentialStore.profileAccount(for: firstID)] = Data("first-key".utf8)
        items.items[KeychainCredentialStore.profileAccount(for: secondID)] = Data("second-key".utf8)
        let settings = MarlaSettingsStore(
            defaults: defaults,
            keychain: KeychainCredentialStore(service: "com.marla.tests.authentication-context", backend: items.backend)
        )

        settings.loadCredentialsAfterApplicationLaunch()

        XCTAssertEqual(settings.apiKey(for: firstID), "first-key")
        XCTAssertEqual(settings.apiKey(for: secondID), "second-key")
        XCTAssertEqual(Set(items.authenticationContextIDs).count, 1)
        XCTAssertEqual(items.authenticationContextIDs.count, 3) // vault probe + two legacy items
    }

    @MainActor
    func testDeniedVaultLoadNeverFallsBackToProfileItemDuringTranslation() {
        let items = FakeKeychainItems()
        let profileID = UUID()
        let profileAccount = KeychainCredentialStore.profileAccount(for: profileID)
        items.items[profileAccount] = Data("legacy-key".utf8)
        items.deniedAccounts.insert(KeychainCredentialStore.vaultAccount)
        let keychain = KeychainCredentialStore(
            service: "com.marla.tests.denied-vault",
            backend: items.backend
        )

        XCTAssertFalse(keychain.loadVault())
        XCTAssertNil(keychain.scoped(to: profileID).read())
        XCTAssertNil(keychain.scoped(to: profileID).read())
        XCTAssertEqual(items.readAccounts, [KeychainCredentialStore.vaultAccount])
    }

    @MainActor
    func testDeniedVaultLoadIsNotRetriedBySave() {
        let items = FakeKeychainItems()
        items.deniedAccounts.insert(KeychainCredentialStore.vaultAccount)
        let profileID = UUID()
        let keychain = KeychainCredentialStore(
            service: "com.marla.tests.denied-save",
            backend: items.backend
        )

        XCTAssertFalse(keychain.loadVault())
        XCTAssertThrowsError(try keychain.scoped(to: profileID).save("new-key"))
        XCTAssertEqual(items.readAccounts, [KeychainCredentialStore.vaultAccount])
    }

    @MainActor
    func testSettingsStartupMigratesRootOnlyLegacyCredentialIntoVault() {
        let suite = "com.marla.tests.root-only-migration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let items = FakeKeychainItems()
        items.items["translation-api-key"] = Data("legacy-key".utf8)
        let keychain = KeychainCredentialStore(
            service: "com.marla.tests.root-only-migration",
            backend: items.backend
        )
        let settings = MarlaSettingsStore(defaults: defaults, keychain: keychain)

        XCTAssertTrue(settings.profiles.isEmpty)
        XCTAssertTrue(items.readAccounts.isEmpty)

        settings.loadCredentialsAfterApplicationLaunch()

        let profileID = try! XCTUnwrap(settings.defaultProfileID)
        XCTAssertEqual(settings.apiKey(for: profileID), "legacy-key")
        XCTAssertNotNil(items.items[KeychainCredentialStore.vaultAccount])
        XCTAssertNil(items.items["translation-api-key"])
    }

    @MainActor
    func testLegacySingleAPIFieldsMigrateToNamedDefaultProfile() {
        let suite = "com.marla.tests.migration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set("https://legacy.example/v1", forKey: "translationBaseURL")
        defaults.set("legacy-model", forKey: "translationModelName")
        let settings = MarlaSettingsStore(
            defaults: defaults,
            keychain: KeychainCredentialStore(service: "com.marla.tests", account: UUID().uuidString)
        )

        XCTAssertEqual(settings.profiles.count, 1)
        XCTAssertEqual(settings.defaultProfile?.name, "默认配置")
        XCTAssertEqual(settings.baseURL, "https://legacy.example/v1")
        XCTAssertEqual(settings.defaultProfile?.urlMode, .baseURL)
        XCTAssertEqual(settings.modelName, "legacy-model")
        XCTAssertNotNil(defaults.data(forKey: "translationAPIProfiles.v1"))
    }

    @MainActor
    func testStoredProfileWithoutURLModeMigratesToBaseURL() throws {
        let suite = "com.marla.tests.url-mode-migration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let profileID = UUID()
        let legacyJSON = """
        [{"id":"\(profileID.uuidString)","name":"旧配置","baseURL":"https://legacy.example/v1","modelName":"legacy-model"}]
        """
        defaults.set(try XCTUnwrap(legacyJSON.data(using: .utf8)), forKey: "translationAPIProfiles.v1")

        let settings = MarlaSettingsStore(
            defaults: defaults,
            keychain: KeychainCredentialStore(service: "com.marla.tests", account: UUID().uuidString)
        )

        XCTAssertEqual(settings.defaultProfile?.id, profileID)
        XCTAssertEqual(settings.defaultProfile?.urlMode, .baseURL)
        XCTAssertEqual(settings.defaultProfile?.baseURL, "https://legacy.example/v1")
        XCTAssertEqual(settings.defaultProfile?.isEnabled, true)
    }

    func testAPIKeyDraftResolverPrefersNonEmptyDraftAndFallsBackOnlyWhenNeeded() {
        var fallbackCount = 0
        let draft = APIKeyDraftResolver.resolve("  draft-key  ") {
            fallbackCount += 1
            return "stored-key"
        }

        XCTAssertEqual(draft, "draft-key")
        XCTAssertEqual(fallbackCount, 0)

        let stored = APIKeyDraftResolver.resolve(" \n ") {
            fallbackCount += 1
            return "stored-key"
        }

        XCTAssertEqual(stored, "stored-key")
        XCTAssertEqual(fallbackCount, 1)
    }

    @MainActor
    func testConnectionTesterResetClearsStaleValidationResult() {
        let tester = TranslationConnectionTester()
        tester.test(endpoint: TranslationEndpointConfiguration(baseURL: "invalid", model: ""))

        XCTAssertNotNil(tester.message)
        XCTAssertFalse(tester.didSucceed)

        tester.reset()

        XCTAssertNil(tester.message)
        XCTAssertFalse(tester.isTesting)
        XCTAssertFalse(tester.didSucceed)
    }

    @MainActor
    func testProfileActivationMaintainsEnabledDefaultAndPersists() {
        let suite = "com.marla.tests.profile-activation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let keychain = KeychainCredentialStore(service: "com.marla.tests", account: UUID().uuidString)
        let settings = MarlaSettingsStore(defaults: defaults, keychain: keychain)

        let firstID = settings.addProfile()
        let secondID = settings.addProfile()
        let thirdID = settings.addProfile()
        settings.setDefaultProfile(secondID)

        settings.setProfileEnabled(false, for: secondID)
        XCTAssertEqual(settings.defaultProfileID, thirdID)

        settings.setProfileEnabled(false, for: thirdID)
        XCTAssertEqual(settings.defaultProfileID, firstID)

        settings.setProfileEnabled(false, for: firstID)
        XCTAssertNil(settings.defaultProfileID)
        XCTAssertTrue(settings.enabledProfiles.isEmpty)

        settings.setProfileEnabled(true, for: secondID)
        XCTAssertEqual(settings.defaultProfileID, secondID)

        settings.setProfileEnabled(false, for: secondID)
        settings.setDefaultProfile(thirdID)
        XCTAssertEqual(settings.defaultProfileID, thirdID)
        XCTAssertEqual(settings.profile(id: thirdID)?.isEnabled, true)

        let restored = MarlaSettingsStore(defaults: defaults, keychain: keychain)
        XCTAssertEqual(restored.defaultProfileID, thirdID)
        XCTAssertEqual(restored.enabledProfiles.map(\.id), [thirdID])
        XCTAssertEqual(restored.profile(id: firstID)?.isEnabled, false)
        XCTAssertEqual(restored.profile(id: secondID)?.isEnabled, false)
    }

    @MainActor
    func testDisabledProfilesAreUnavailableToTranslationSessions() {
        let suite = "com.marla.tests.disabled-profiles.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = MarlaSettingsStore(
            defaults: defaults,
            keychain: KeychainCredentialStore(service: "com.marla.tests", account: UUID().uuidString)
        )
        let enabledID = settings.addProfile()
        settings.updateProfile(id: enabledID, name: "启用", baseURL: "https://enabled.example/v1", modelName: "enabled-model")
        let disabledID = settings.addProfile()
        settings.updateProfile(id: disabledID, name: "停用", baseURL: "https://disabled.example/v1", modelName: "disabled-model")
        settings.setProfileEnabled(false, for: disabledID)
        let store = TranslationSessionStore(settings: settings)

        store.installUIAutomationFixture(
            surface: .selection,
            sourceText: "Hello",
            translation: "你好",
            state: .completed
        )
        let originalSessionID = store.session?.id
        store.changeAPIProfile(disabledID)

        XCTAssertEqual(store.availableProfiles.map(\.id), [enabledID])
        XCTAssertNil(settings.endpoint(for: disabledID))
        XCTAssertEqual(store.session?.id, originalSessionID)
        XCTAssertEqual(store.session?.profileID, enabledID)
    }

    @MainActor
    func testProfileDropReorderingPersistsExactOrder() {
        let suite = "com.marla.tests.profile-drag-order.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let keychain = KeychainCredentialStore(service: "com.marla.tests", account: UUID().uuidString)
        let settings = MarlaSettingsStore(defaults: defaults, keychain: keychain)
        let firstID = settings.addProfile()
        let secondID = settings.addProfile()
        let thirdID = settings.addProfile()

        XCTAssertTrue(settings.moveProfile(id: firstID, onto: thirdID))
        XCTAssertEqual(settings.profiles.map(\.id), [secondID, thirdID, firstID])
        XCTAssertTrue(settings.moveProfile(id: firstID, onto: secondID))
        XCTAssertEqual(settings.profiles.map(\.id), [firstID, secondID, thirdID])
        XCTAssertFalse(settings.moveProfile(id: firstID, onto: firstID))

        let restored = MarlaSettingsStore(defaults: defaults, keychain: keychain)
        XCTAssertEqual(restored.profiles.map(\.id), [firstID, secondID, thirdID])
    }

    func testProfileDragPreviewKeepsTheGrabbedHandlePointUnderThePointer() {
        let handleLocation = CGPoint(x: 9, y: 31)
        let pointerLocation = CGPoint(x: 440, y: 280)

        let previewFrame = APIProfileDragGeometry.previewFrame(
            pointerLocation: pointerLocation,
            handleLocation: handleLocation
        )
        let handleOrigin = APIProfileDragGeometry.handleOriginInPreview

        XCTAssertEqual(previewFrame.width, APIProfileDragGeometry.previewSize.width)
        XCTAssertEqual(previewFrame.height, APIProfileDragGeometry.previewSize.height)
        XCTAssertEqual(
            previewFrame.minX + handleOrigin.x + handleLocation.x,
            pointerLocation.x
        )
        XCTAssertEqual(
            previewFrame.minY + handleOrigin.y + handleLocation.y,
            pointerLocation.y
        )
        XCTAssertEqual(APIProfileDragGeometry.previewSize, APIProfileDragGeometry.rowSize)
        XCTAssertEqual(APIProfileDragGeometry.systemDraggingImageSize, CGSize(width: 1, height: 1))
    }

    @MainActor
    func testPersistedEmptyProfileListDoesNotRemigrateLegacyConfiguration() {
        let suite = "com.marla.tests.persisted-empty-profiles.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set("https://legacy.example/v1", forKey: "translationBaseURL")
        defaults.set("legacy-model", forKey: "translationModelName")
        let keychain = KeychainCredentialStore(service: "com.marla.tests", account: UUID().uuidString)
        let settings = MarlaSettingsStore(defaults: defaults, keychain: keychain)
        let profileID = try! XCTUnwrap(settings.defaultProfileID)

        settings.removeProfile(id: profileID)
        let restored = MarlaSettingsStore(defaults: defaults, keychain: keychain)

        XCTAssertTrue(restored.profiles.isEmpty)
        XCTAssertNil(restored.defaultProfileID)
    }

    @MainActor
    func testCompleteURLModePersistsAndReachesEndpointConfiguration() {
        let suite = "com.marla.tests.complete-url-mode.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = MarlaSettingsStore(
            defaults: defaults,
            keychain: KeychainCredentialStore(service: "com.marla.tests", account: UUID().uuidString)
        )
        let profileID = settings.addProfile()
        settings.updateProfile(
            id: profileID,
            baseURL: "https://example.com/custom/chat/completions",
            urlMode: .completeURL,
            modelName: "demo"
        )

        XCTAssertEqual(settings.profile(id: profileID)?.urlMode, .completeURL)
        XCTAssertEqual(settings.endpoint(for: profileID)?.urlMode, .completeURL)
        XCTAssertEqual(settings.endpoint(for: profileID)?.baseURL, "https://example.com/custom/chat/completions")

        let restored = MarlaSettingsStore(
            defaults: defaults,
            keychain: KeychainCredentialStore(service: "com.marla.tests", account: UUID().uuidString)
        )
        XCTAssertEqual(restored.profile(id: profileID)?.urlMode, .completeURL)
    }

    func testAPIProfileRejectsQueryAndFragmentURLs() {
        XCTAssertTrue(TranslationAPIProfile.isValidEndpointURL("https://example.com/v1"))
        XCTAssertFalse(TranslationAPIProfile.isValidEndpointURL("https://example.com/v1?key=value"))
        XCTAssertFalse(TranslationAPIProfile.isValidEndpointURL("https://example.com/v1#fragment"))
        XCTAssertFalse(TranslationAPIProfile.isValidEndpointURL("example.com/v1"))
    }

    @MainActor
    func testDeletingLastAPIProfileLeavesAnEmptyStoreWithoutImplicitDefault() {
        let suite = "com.marla.tests.empty-profiles.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = MarlaSettingsStore(
            defaults: defaults,
            keychain: KeychainCredentialStore(service: "com.marla.tests", account: UUID().uuidString)
        )

        let profileID = settings.addProfile()
        settings.removeProfile(id: profileID)

        XCTAssertTrue(settings.profiles.isEmpty)
        XCTAssertNil(settings.defaultProfileID)
        XCTAssertNil(settings.defaultProfile)
    }

    @MainActor
    func testProfileSummaryFieldsReflectEditsImmediately() {
        let suite = "com.marla.tests.profile-summary.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = MarlaSettingsStore(
            defaults: defaults,
            keychain: KeychainCredentialStore(service: "com.marla.tests", account: UUID().uuidString)
        )

        let profileID = settings.addProfile()
        settings.updateProfile(id: profileID, name: "新名称", modelName: "new-model")

        let summary = try! XCTUnwrap(settings.profile(id: profileID))
        XCTAssertEqual(summary.name, "新名称")
        XCTAssertEqual(summary.modelName, "new-model")
    }

    @MainActor
    func testCancellingNewAPIProfileRemovesPlaceholderAndScopedCredential() {
        let suite = "com.marla.tests.cancel-profile.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let keychain = KeychainCredentialStore(service: "com.marla.tests", account: UUID().uuidString)
        let settings = MarlaSettingsStore(defaults: defaults, keychain: keychain)

        let profileID = settings.addProfile()
        let scopedAccount = keychain.scoped(to: profileID).account

        settings.removeProfile(id: profileID)

        XCTAssertNil(settings.profile(id: profileID))
        XCTAssertNil(settings.defaultProfileID)
        XCTAssertEqual(scopedAccount, "translation-api-key.\(profileID.uuidString)")
        XCTAssertNil(keychain.scoped(to: profileID).read())
    }

    @MainActor
    func testShortcutEnabledStatePersistsAndFiltersDispatch() {
        let suite = "com.marla.tests.shortcuts.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let manager = GlobalShortcutManager(registerHotKeys: false, defaults: defaults)
        XCTAssertEqual(manager.enabledActions, Set(GlobalShortcutAction.allCases))

        manager.setEnabled(false, for: .screenshot)
        var dispatched: GlobalShortcutAction?
        manager.onAction = { dispatched = $0 }
        manager.handleHotKey(id: GlobalShortcutAction.screenshot.hotKeyID)

        XCTAssertFalse(manager.isEnabled(.screenshot))
        XCTAssertNil(dispatched)

        let restored = GlobalShortcutManager(registerHotKeys: false, defaults: defaults)
        XCTAssertFalse(restored.isEnabled(.screenshot))
        XCTAssertTrue(restored.isEnabled(.selection))

        restored.restoreDefaults()
        XCTAssertEqual(restored.enabledActions, Set(GlobalShortcutAction.allCases))
    }

    func testScreenshotShortcutUsesAnAvailableSystemSymbol() {
        XCTAssertEqual(GlobalShortcutAction.screenshot.symbolName, "viewfinder")
        XCTAssertNotNil(
            NSImage(systemSymbolName: GlobalShortcutAction.screenshot.symbolName, accessibilityDescription: nil)
        )
    }

    @MainActor
    func testRecentTranslationsKeepOnlyThreeCompletedUniqueResults() {
        let store = makeSessionStore()
        for index in 1 ... 4 {
            store.installUIAutomationFixture(
                surface: .selection,
                sourceText: "source-\(index)",
                translation: "translation-\(index)",
                state: .completed
            )
        }

        XCTAssertEqual(store.recentTranslations.count, TranslationSessionStore.recentTranslationLimit)
        XCTAssertEqual(store.recentTranslations.map(\.translation), ["translation-4", "translation-3", "translation-2"])

        store.installUIAutomationFixture(
            surface: .selection,
            sourceText: "source-3",
            translation: "translation-3",
            state: .completed
        )
        XCTAssertEqual(store.recentTranslations.map(\.translation), ["translation-3", "translation-4", "translation-2"])
    }

    @MainActor
    func testRecentTranslationsExcludeFailedCancelledAndEmptyResults() {
        let store = makeSessionStore()
        store.installUIAutomationFixture(
            surface: .selection,
            sourceText: "source",
            translation: "partial",
            state: .failed(message: "network")
        )
        store.installUIAutomationFixture(
            surface: .quickInput,
            sourceText: "source",
            translation: "",
            state: .completed
        )
        store.installUIAutomationFixture(
            surface: .screenshot,
            sourceText: "source",
            translation: "cancelled",
            state: .cancelled
        )

        XCTAssertTrue(store.recentTranslations.isEmpty)
    }

    @MainActor
    func testRestoringRecentTranslationDoesNotStartANewRequest() {
        let store = makeSessionStore()
        store.installUIAutomationFixture(
            surface: .screenshot,
            sourceText: "Hello",
            translation: "你好",
            state: .completed
        )
        let recentID = try! XCTUnwrap(store.recentTranslations.first?.id)

        let restored = store.restoreRecentTranslation(id: recentID)

        XCTAssertEqual(restored?.state, .completed)
        XCTAssertEqual(restored?.sourceText, "Hello")
        XCTAssertEqual(restored?.translation, "你好")
        XCTAssertEqual(store.recentTranslations.count, 1)
    }

    func testPanelPlacementClampsToNegativeCoordinateDisplay() {
        let visible = NSRect(x: -1920, y: -120, width: 1920, height: 1080)
        let anchor = ScreenRect(x: -80, y: 700, width: 60, height: 22)
        let frame = PanelPlacementCalculator.frame(
            visibleFrame: visible,
            requestedWidth: 380,
            requestedHeight: 300,
            anchor: anchor,
            pointer: nil
        )

        XCTAssertGreaterThanOrEqual(frame.minX, visible.minX + 8)
        XCTAssertLessThanOrEqual(frame.maxX, visible.maxX - 8)
        XCTAssertGreaterThanOrEqual(frame.minY, visible.minY + 8)
        XCTAssertLessThanOrEqual(frame.maxY, visible.maxY - 8)
        XCTAssertEqual(frame.width, 380)
        XCTAssertEqual(frame.height, 300)
    }

    func testPanelPlacementChoosesSideWithMoreVisibleSpace() {
        let visible = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let nearTop = ScreenRect(x: 700, y: 820, width: 80, height: 20)
        let frame = PanelPlacementCalculator.frame(
            visibleFrame: visible,
            requestedWidth: 380,
            requestedHeight: 300,
            anchor: nearTop,
            pointer: nil
        )
        XCTAssertLessThanOrEqual(frame.maxY, nearTop.y - 8)
    }

    func testInlineOverlayPlacementCoversEligibleSingleLineAndStaysVisible() throws {
        let visible = NSRect(x: -1920, y: -120, width: 1920, height: 1080)
        let anchor = ScreenRect(x: -1800, y: 700, width: 320, height: 22)

        let placement = try XCTUnwrap(
            InlineOverlayPlacementCalculator.placement(
                visibleFrame: visible,
                anchor: anchor,
                pointer: nil,
                sourceText: "A single line selection"
            )
        )
        let frame = placement.frame

        XCTAssertEqual(placement.mode, .selectionBounds)
        XCTAssertTrue(visible.contains(frame))
        XCTAssertLessThanOrEqual(frame.minX, anchor.x)
        XCTAssertGreaterThanOrEqual(frame.maxX, anchor.x + anchor.width)
        XCTAssertEqual(frame.midY, anchor.y + anchor.height / 2, accuracy: 0.001)
    }

    func testInlineOverlayPlacementUsesPointerForShortSingleLineWithoutBounds() throws {
        let visible = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let pointer = CGPoint(x: 1395, y: 860)

        let placement = try XCTUnwrap(
            InlineOverlayPlacementCalculator.placement(
                visibleFrame: visible,
                anchor: nil,
                pointer: pointer,
                sourceText: "No exact geometry"
            )
        )

        XCTAssertEqual(placement.mode, .pointerEstimate)
        XCTAssertTrue(visible.contains(placement.frame))
        XCTAssertEqual(placement.frame.height, 40)
    }

    func testInlineOverlayPlacementRejectsMultilineLongAndUnsafeGeometry() {
        let visible = NSRect(x: 0, y: 0, width: 1440, height: 900)

        XCTAssertNil(
            InlineOverlayPlacementCalculator.placement(
                visibleFrame: visible,
                anchor: nil,
                pointer: CGPoint(x: 200, y: 300),
                sourceText: String(repeating: "x", count: 161)
            )
        )
        XCTAssertNil(
            InlineOverlayPlacementCalculator.placement(
                visibleFrame: visible,
                anchor: ScreenRect(x: 200, y: 300, width: 240, height: 22),
                pointer: nil,
                sourceText: "First line\nSecond line"
            )
        )
        XCTAssertNil(
            InlineOverlayPlacementCalculator.placement(
                visibleFrame: visible,
                anchor: ScreenRect(x: 200, y: 300, width: 240, height: 52),
                pointer: nil,
                sourceText: "Wrapped geometry"
            )
        )
        XCTAssertNil(
            InlineOverlayPlacementCalculator.placement(
                visibleFrame: visible,
                anchor: ScreenRect(x: 1380, y: 300, width: 120, height: 22),
                pointer: nil,
                sourceText: "Crosses the display edge"
            )
        )
    }

    func testAccessibilityCoordinateConverterMapsTopLeftDisplayCoordinatesToAppKit() throws {
        let displays = [
            AccessibilityDisplayGeometry(
                accessibilityFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                appKitFrame: CGRect(x: 0, y: 0, width: 1512, height: 982)
            ),
            AccessibilityDisplayGeometry(
                accessibilityFrame: CGRect(x: -1920, y: 120, width: 1920, height: 1080),
                appKitFrame: CGRect(x: -1920, y: -218, width: 1920, height: 1080)
            )
        ]

        XCTAssertEqual(
            AccessibilityCoordinateConverter.appKitRect(
                from: CGRect(x: -1800, y: 220, width: 320, height: 24),
                displays: displays
            ),
            CGRect(x: -1800, y: 738, width: 320, height: 24)
        )
        XCTAssertNil(
            AccessibilityCoordinateConverter.appKitRect(
                from: CGRect(x: 5000, y: 5000, width: 40, height: 20),
                displays: displays
            )
        )
    }

    func testInlineOverlayTerminalStatesExpandFailureAndCloseCancellation() {
        XCTAssertEqual(
            InlineOverlayTransition.terminalAction(for: .failed(message: "network")),
            .expand
        )
        XCTAssertEqual(InlineOverlayTransition.terminalAction(for: .cancelled), .close)
        XCTAssertEqual(InlineOverlayTransition.terminalAction(for: nil), .close)
        XCTAssertNil(InlineOverlayTransition.terminalAction(for: .streaming))
        XCTAssertNil(InlineOverlayTransition.terminalAction(for: .completed))
    }

    func testScreenCaptureGeometryConvertsAppKitSelectionToDisplayLocalTopLeftCoordinates() {
        let screen = CGRect(x: -1920, y: -120, width: 1920, height: 1080)
        let intersection = CGRect(x: -1800, y: 700, width: 320, height: 120)

        XCTAssertEqual(
            ScreenCaptureGeometry.sourceRect(intersection: intersection, screenFrame: screen),
            CGRect(x: 120, y: 140, width: 320, height: 120)
        )
    }

    func testScreenCaptureGeometryPlacesDisplayFragmentInsideScaledSelection() {
        let selection = CGRect(x: -100, y: 200, width: 500, height: 200)
        let intersection = CGRect(x: 0, y: 240, width: 300, height: 120)

        XCTAssertEqual(
            ScreenCaptureGeometry.destinationRect(
                intersection: intersection,
                selection: selection,
                scale: 2
            ),
            CGRect(x: 200, y: 80, width: 600, height: 240)
        )
    }

    @MainActor
    func testFrozenScreenshotLayoutComposesCrossDisplaySelectionAtHighestScale() throws {
        let leftImage = try makeSolidImage(width: 200, height: 200, color: .systemRed)
        let rightImage = try makeSolidImage(width: 100, height: 100, color: .systemGreen)
        let displays = [
            ScreenshotMagnifierSource(
                screenFrame: CGRect(x: -100, y: 0, width: 100, height: 100),
                cgImage: leftImage
            ),
            ScreenshotMagnifierSource(
                screenFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
                cgImage: rightImage
            )
        ]
        let selection = CGRect(x: -50, y: 20, width: 100, height: 40)

        let layout = try XCTUnwrap(
            ScreenshotFrozenCapture.layout(global: selection, frozenDisplays: displays)
        )

        XCTAssertEqual(layout.scale, 2)
        XCTAssertEqual(layout.pixelSize, CGSize(width: 200, height: 80))
        XCTAssertEqual(layout.fragments.count, 2)
        XCTAssertEqual(layout.fragments[0].clipRect, CGRect(x: 0, y: 0, width: 100, height: 80))
        XCTAssertEqual(layout.fragments[0].fullDisplayRect, CGRect(x: -100, y: -40, width: 200, height: 200))
        XCTAssertEqual(layout.fragments[1].clipRect, CGRect(x: 100, y: 0, width: 100, height: 80))
        XCTAssertEqual(layout.fragments[1].fullDisplayRect, CGRect(x: 100, y: -40, width: 200, height: 200))

        let image = try XCTUnwrap(
            ScreenshotFrozenCapture.image(global: selection, frozenDisplays: displays)
        )
        XCTAssertEqual(image.width, 200)
        XCTAssertEqual(image.height, 80)
    }

    @MainActor
    func testFrozenScreenshotLayoutRejectsRegionsOutsideCapturedDisplays() throws {
        let image = try makeSolidImage(width: 100, height: 100, color: .black)
        let display = ScreenshotMagnifierSource(
            screenFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            cgImage: image
        )

        XCTAssertNil(
            ScreenshotFrozenCapture.layout(
                global: CGRect(x: 200, y: 200, width: 20, height: 20),
                frozenDisplays: [display]
            )
        )
    }

    @MainActor
    func testFloatingPanelStyleEnablesDraggingAndClipsHostedContent() {
        let panel = MarlaPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 300),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        let contentView = NSView(frame: panel.contentView?.bounds ?? .zero)

        FloatingPanelStyle.apply(to: panel)
        FloatingPanelStyle.apply(to: contentView)

        XCTAssertTrue(panel.isMovable)
        XCTAssertTrue(panel.isMovableByWindowBackground)
        XCTAssertTrue(panel.hasShadow)
        XCTAssertEqual(contentView.layer?.cornerRadius, DesignTokens.radiusL)
        XCTAssertTrue(contentView.layer?.masksToBounds == true)
    }

    @MainActor
    func testInlineOverlayPanelStyleDisablesDraggingAndUsesCompactClipping() {
        let panel = MarlaPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 40),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        let contentView = NSView(frame: panel.contentView?.bounds ?? .zero)

        InlineOverlayPanelStyle.apply(to: panel)
        InlineOverlayPanelStyle.apply(to: contentView)

        XCTAssertFalse(panel.isMovable)
        XCTAssertFalse(panel.isMovableByWindowBackground)
        XCTAssertTrue(panel.hasShadow)
        XCTAssertEqual(contentView.layer?.cornerRadius, DesignTokens.radiusS)
        XCTAssertTrue(contentView.layer?.masksToBounds == true)
    }

    @MainActor
    func testSettingsWindowUsesOneFullSizeTransparentRoundedSurface() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        let contentView = NSView(frame: window.contentView?.bounds ?? .zero)
        window.contentView = contentView

        SettingsWindowStyle.apply(to: window)

        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertEqual(window.titlebarSeparatorStyle, .none)
        XCTAssertFalse(window.isOpaque)
        XCTAssertFalse(window.isMovableByWindowBackground)
        XCTAssertEqual(contentView.layer?.cornerRadius, DesignTokens.radiusL)
        XCTAssertEqual(contentView.layer?.cornerCurve, .continuous)
        XCTAssertTrue(contentView.layer?.masksToBounds == true)
    }

    @MainActor
    func testSettingsWindowCanSuspendForScreenshotWithoutRestoringAsKey() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let coordinator = MarlaSettingsWindowCoordinator(window: window)
        window.orderFront(nil)

        XCTAssertTrue(coordinator.suspendForScreenshotSelection())
        XCTAssertFalse(window.isVisible)

        coordinator.restoreAfterScreenshotSelection(wasVisible: true)

        XCTAssertTrue(window.isVisible)
        XCTAssertFalse(window.isKeyWindow)
        window.orderOut(nil)
    }

    @MainActor
    func testScreenshotSelectionWindowCanBecomeKeyButNotMain() {
        let window = ScreenshotSelectionWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        XCTAssertTrue(window.canBecomeKey)
        XCTAssertFalse(window.canBecomeMain)
    }

    @MainActor
    func testScreenshotSelectionWindowRoutesEscapeBeforeFirstResponder() throws {
        var cancellationCount = 0
        let window = ScreenshotSelectionWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            onCancel: { cancellationCount += 1 }
        )
        let event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                characters: "\u{1B}",
                charactersIgnoringModifiers: "\u{1B}",
                isARepeat: false,
                keyCode: 53
            )
        )

        window.sendEvent(event)
        XCTAssertTrue(window.performKeyEquivalent(with: event))
        window.cancelOperation(nil)
        XCTAssertEqual(cancellationCount, 3)
    }

    @MainActor
    func testEscapeCancelsScreenshotSelection() {
        XCTAssertTrue(ScreenshotSelectionView.isCancelKeyCode(53))
        XCTAssertFalse(ScreenshotSelectionView.isCancelKeyCode(36))

        var didCancel = false
        let session = ScreenshotSelectionSession { _, cancelled in
            didCancel = cancelled
        }
        let view = ScreenshotSelectionView(session: session)
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{1B}",
            charactersIgnoringModifiers: "\u{1B}",
            isARepeat: false,
            keyCode: 53
        )

        view.keyDown(with: try! XCTUnwrap(event))
        XCTAssertTrue(didCancel)
    }

    @MainActor
    func testScreenshotEscapeMonitorRoutesOnlyEscapeAndConsumesLocalEvent() throws {
        var cancellationCount = 0
        let monitor = ScreenshotEscapeMonitor {
            cancellationCount += 1
        }
        let escape = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "\u{1B}",
                charactersIgnoringModifiers: "\u{1B}",
                isARepeat: false,
                keyCode: 53
            )
        )
        let returnKey = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "\r",
                charactersIgnoringModifiers: "\r",
                isARepeat: false,
                keyCode: 36
            )
        )

        XCTAssertNil(monitor.handleLocal(escape))
        XCTAssertTrue(monitor.handleLocal(returnKey) === returnKey)
        monitor.handleGlobal(returnKey)
        monitor.handleGlobal(escape)
        monitor.handleEventTapEscape()

        XCTAssertEqual(cancellationCount, 3)
    }

    @MainActor
    func testScreenshotEscapeMonitorInstallsAndRemovesSessionMonitors() {
        let monitor = ScreenshotEscapeMonitor {}

        XCTAssertFalse(monitor.isInstalled)
        monitor.install()
        XCTAssertTrue(monitor.isInstalled)
        monitor.remove()
        XCTAssertFalse(monitor.isInstalled)
        XCTAssertFalse(monitor.hasEventTap)
        monitor.remove()
        XCTAssertFalse(monitor.isInstalled)
    }

    @MainActor
    func testScreenshotSelectionCancellationIsIdempotent() {
        var finishCount = 0
        var wasCancelled = false
        let session = ScreenshotSelectionSession { _, cancelled in
            finishCount += 1
            wasCancelled = cancelled
        }

        session.cancel()
        session.cancel()

        XCTAssertEqual(finishCount, 1)
        XCTAssertTrue(wasCancelled)
    }

    func testScreenshotMagnifierFlipsAtEdgesAndClampsSampleRect() {
        let bounds = NSRect(x: 0, y: 0, width: 500, height: 400)
        let topRight = ScreenshotMagnifierGeometry.frame(pointer: NSPoint(x: 490, y: 390), in: bounds)
        XCTAssertLessThan(topRight.maxX, 490)
        XCTAssertLessThan(topRight.maxY, 390)
        XCTAssertGreaterThanOrEqual(topRight.minX, bounds.minX + ScreenshotMagnifierGeometry.margin)
        XCTAssertGreaterThanOrEqual(topRight.minY, bounds.minY + ScreenshotMagnifierGeometry.margin)

        let lowerLeft = ScreenshotMagnifierGeometry.frame(pointer: NSPoint(x: 2, y: 2), in: bounds)
        XCTAssertGreaterThan(lowerLeft.minX, 2)
        XCTAssertGreaterThan(lowerLeft.minY, 2)

        let sourceBounds = NSRect(x: 0, y: 0, width: 100, height: 80)
        let lowSample = ScreenshotMagnifierGeometry.sourceRect(
            pointer: NSPoint(x: 1, y: 1),
            in: sourceBounds,
            destinationSize: NSSize(width: 96, height: 96),
            zoom: 6
        )
        let highSample = ScreenshotMagnifierGeometry.sourceRect(
            pointer: NSPoint(x: 99, y: 79),
            in: sourceBounds,
            destinationSize: NSSize(width: 96, height: 96),
            zoom: 6
        )
        XCTAssertEqual(lowSample.minX, sourceBounds.minX)
        XCTAssertEqual(lowSample.minY, sourceBounds.minY)
        XCTAssertEqual(highSample.maxX, sourceBounds.maxX)
        XCTAssertEqual(highSample.maxY, sourceBounds.maxY)
    }

    func testAccessibilityRangeFallbackUsesUTF16Offsets() {
        let value = "A😀中文B"
        XCTAssertEqual(
            AccessibilitySelectionReader.substring(in: value, range: CFRange(location: 1, length: 4)),
            "😀中文"
        )
        XCTAssertNil(
            AccessibilitySelectionReader.substring(in: value, range: CFRange(location: 20, length: 1))
        )
    }

    func testSelectionTextResolutionContinuesAfterEmptyStandardRange() {
        XCTAssertEqual(
            AccessibilitySelectionReader.resolveTextLookups([
                .empty,
                .found("Electron marker selection", .textMarker)
            ]),
            .found("Electron marker selection", .textMarker)
        )
        XCTAssertEqual(
            AccessibilitySelectionReader.resolveTextLookups([
                .found("   \n", .directText),
                .unavailable,
                .found("Range selection", .standardRange)
            ]),
            .found("Range selection", .standardRange)
        )
        XCTAssertEqual(
            AccessibilitySelectionReader.resolveTextLookups([.unavailable, .empty, .unavailable]),
            .empty
        )
    }

    func testSelectionGraphSearchDeduplicatesRootsAndCyclesGlobally() {
        let children = [
            0: [1, 1],
            1: [0, 2],
            2: [2]
        ]
        let outcome = SelectionGraphSearch.find(
            roots: [0, 0],
            maximumElements: 20,
            hasTimeRemaining: { true },
            selection: { node in
                node == 2 ? .found("selected", .directText) : .unavailable
            },
            children: { children[$0] ?? [] }
        )

        XCTAssertEqual(outcome.visitedElementCount, 3)
        XCTAssertEqual(outcome.termination, .found)
        guard case let .found(text, mechanism, node) = outcome.lookup else {
            return XCTFail("Expected a selection match")
        }
        XCTAssertEqual(text, "selected")
        XCTAssertEqual(mechanism, .directText)
        XCTAssertEqual(node, 2)
    }

    func testSelectionCandidateRootsPrioritizePointerPathAndDedupeFallbacks() {
        let roots = SelectionCandidateRoots.merge([
            [7, 6, 5],
            [5, 4],
            [4, 3]
        ])

        XCTAssertEqual(roots, [7, 6, 5, 4, 3])
        let outcome = SelectionGraphSearch.find(
            roots: roots,
            maximumElements: 20,
            hasTimeRemaining: { true },
            selection: { node in
                node == 7 ? .found("pointer selection", .directText) : .unavailable
            },
            children: { _ in [] }
        )
        XCTAssertEqual(outcome.visitedElementCount, 1)
        XCTAssertEqual(outcome.termination, .found)
    }

    func testSelectionGraphSearchDoesNotLetEarlierEmptyNodeHideLaterSelection() {
        let outcome = SelectionGraphSearch.find(
            roots: [0, 1],
            maximumElements: 20,
            hasTimeRemaining: { true },
            selection: { node in
                node == 0 ? .empty : .found("marker", .textMarker)
            },
            children: { _ in [] }
        )

        XCTAssertEqual(outcome.visitedElementCount, 2)
        guard case let .found(text, mechanism, node) = outcome.lookup else {
            return XCTFail("Expected the later non-empty selection")
        }
        XCTAssertEqual(text, "marker")
        XCTAssertEqual(mechanism, .textMarker)
        XCTAssertEqual(node, 1)
    }

    func testSelectionGraphSearchReportsElementAndTimeBudgets() {
        let elementLimited = SelectionGraphSearch.find(
            roots: [0],
            maximumElements: 2,
            hasTimeRemaining: { true },
            selection: { _ in .unavailable },
            children: { [$0 + 1] }
        )
        XCTAssertEqual(elementLimited.visitedElementCount, 2)
        XCTAssertEqual(elementLimited.termination, .elementLimit)

        var timeChecks = 0
        let timeLimited = SelectionGraphSearch.find(
            roots: [0],
            maximumElements: 20,
            hasTimeRemaining: {
                timeChecks += 1
                return timeChecks == 1
            },
            selection: { _ in .unavailable },
            children: { [$0 + 1] }
        )
        XCTAssertEqual(timeLimited.visitedElementCount, 1)
        XCTAssertEqual(timeLimited.termination, .timeLimit)
    }

    func testSelectionGraphSearchProbesAllRootsBeforeExpandingTheirChildren() {
        var events: [String] = []
        let outcome = SelectionGraphSearch.find(
            roots: [0, 1],
            maximumElements: 20,
            hasTimeRemaining: { true },
            selection: { node in
                events.append("selection\(node)")
                return .unavailable
            },
            children: { node in
                events.append("children\(node)")
                return node < 2 ? [node + 2] : []
            }
        )

        XCTAssertEqual(outcome.termination, .exhausted)
        XCTAssertEqual(
            Array(events.prefix(4)),
            ["selection0", "selection1", "children0", "children1"]
        )
    }

    func testSelectionBoundsRejectInvalidGeometryButAllowsCaretWidth() {
        XCTAssertTrue(
            AccessibilitySelectionReader.isUsableSelectionBounds(
                CGRect(x: 10, y: 20, width: 0, height: 18)
            )
        )
        XCTAssertFalse(
            AccessibilitySelectionReader.isUsableSelectionBounds(
                CGRect(x: CGFloat.infinity, y: 20, width: 30, height: 18)
            )
        )
        XCTAssertFalse(AccessibilitySelectionReader.isUsableSelectionBounds(.zero))
    }

    @MainActor
    func testCopyFallbackReadsOnlyTextAfterPasteboardChangeAndRestoresSnapshot() throws {
        let clipboard = FakeSelectionClipboard()
        clipboard.text = "old clipboard"
        clipboard.snapshotValue = PasteboardSnapshot(items: [
            PasteboardItemSnapshot(representations: [
                PasteboardRepresentation(type: "public.utf8-plain-text", data: Data("old clipboard".utf8)),
                PasteboardRepresentation(type: "com.example.custom", data: Data([1, 2, 3]))
            ])
        ])
        var now = 0.0
        var pumpCount = 0
        let fallback = ClipboardSelectionFallback(
            clipboard: clipboard,
            timeout: 0.2,
            now: { now },
            pump: { _ in
                pumpCount += 1
                now += 0.01
                clipboard.changeCount = 1
                clipboard.text = "copied selection"
            },
            sendCopy: { true },
            isFrontmost: { _ in true }
        )

        let result = try fallback.readSelection(from: NSRunningApplication.current)

        XCTAssertEqual(result.selection.text, "copied selection")
        XCTAssertEqual(result.restoreStatus, .restored)
        XCTAssertEqual(fallback.lastRestoreStatus, .restored)
        XCTAssertEqual(clipboard.restoreCalls, 1)
        XCTAssertEqual(clipboard.lastRestoredSnapshot, clipboard.snapshotValue)
        XCTAssertGreaterThan(pumpCount, 0)
    }

    @MainActor
    func testCopyFallbackDoesNotConsumeUnchangedClipboardText() {
        let clipboard = FakeSelectionClipboard()
        clipboard.text = "stale clipboard"
        var now = 0.0
        let fallback = ClipboardSelectionFallback(
            clipboard: clipboard,
            timeout: 0.03,
            now: { now },
            pump: { _ in now += 0.01 },
            sendCopy: { true },
            isFrontmost: { _ in true }
        )

        XCTAssertThrowsError(try fallback.readSelection(from: NSRunningApplication.current)) { error in
            XCTAssertEqual(error as? ClipboardSelectionFallbackError, .timedOut)
        }
        XCTAssertEqual(fallback.lastRestoreStatus, .notAttempted)
        XCTAssertEqual(clipboard.restoreCalls, 0)
    }

    @MainActor
    func testCopyFallbackRestoresAfterChangedClipboardContainsNoText() {
        let clipboard = FakeSelectionClipboard()
        var now = 0.0
        let fallback = ClipboardSelectionFallback(
            clipboard: clipboard,
            timeout: 0.03,
            now: { now },
            pump: { _ in
                now += 0.01
                clipboard.changeCount = 1
                clipboard.text = nil
            },
            sendCopy: { true },
            isFrontmost: { _ in true }
        )

        XCTAssertThrowsError(try fallback.readSelection(from: NSRunningApplication.current)) { error in
            XCTAssertEqual(error as? ClipboardSelectionFallbackError, .selectedTextUnavailable)
        }
        XCTAssertEqual(fallback.lastRestoreStatus, .restored)
        XCTAssertEqual(clipboard.restoreCalls, 1)
    }

    @MainActor
    func testCopyFallbackDoesNotRestoreWhenCopyEventWasNeverSent() {
        let clipboard = FakeSelectionClipboard()
        let fallback = ClipboardSelectionFallback(
            clipboard: clipboard,
            sendCopy: { false },
            isFrontmost: { _ in true }
        )

        XCTAssertThrowsError(try fallback.readSelection(from: NSRunningApplication.current)) { error in
            XCTAssertEqual(error as? ClipboardSelectionFallbackError, .copyEventUnavailable)
        }
        XCTAssertEqual(fallback.lastRestoreStatus, .notAttempted)
        XCTAssertEqual(clipboard.restoreCalls, 0)
    }

    @MainActor
    func testCopyFallbackAbortsWhenClipboardChangesDuringSnapshot() {
        let clipboard = FakeSelectionClipboard()
        clipboard.changeCountAfterSnapshot = 1
        var copyEventCount = 0
        let fallback = ClipboardSelectionFallback(
            clipboard: clipboard,
            sendCopy: {
                copyEventCount += 1
                return true
            },
            isFrontmost: { _ in true }
        )

        XCTAssertThrowsError(try fallback.readSelection(from: NSRunningApplication.current)) { error in
            XCTAssertEqual(error as? ClipboardSelectionFallbackError, .snapshotUnavailable)
        }
        XCTAssertEqual(copyEventCount, 0)
        XCTAssertEqual(clipboard.restoreCalls, 0)
    }

    @MainActor
    func testCopyFallbackNeverRestoresOverConcurrentClipboardWrite() {
        let clipboard = FakeSelectionClipboard()
        var now = 0.0
        var pumpCount = 0
        let fallback = ClipboardSelectionFallback(
            clipboard: clipboard,
            timeout: 0.2,
            now: { now },
            pump: { _ in
                pumpCount += 1
                now += 0.01
                clipboard.changeCount = pumpCount == 1 ? 1 : 2
                clipboard.text = pumpCount == 1 ? nil : "copied selection"
            },
            sendCopy: { true },
            isFrontmost: { _ in true }
        )

        XCTAssertThrowsError(try fallback.readSelection(from: NSRunningApplication.current)) { error in
            XCTAssertEqual(error as? ClipboardSelectionFallbackError, .clipboardChangedDuringCopy)
        }
        XCTAssertEqual(fallback.lastRestoreStatus, .skippedBecauseClipboardChanged)
        XCTAssertNil(clipboard.lastRestoredSnapshot)
        XCTAssertGreaterThanOrEqual(pumpCount, 2)
    }

    @MainActor
    func testCopyFallbackStopsWhenSnapshotCannotBeRestored() {
        let clipboard = FakeSelectionClipboard()
        clipboard.restoreResponse = .failed
        var now = 0.0
        let fallback = ClipboardSelectionFallback(
            clipboard: clipboard,
            timeout: 0.1,
            now: { now },
            pump: { _ in
                now += 0.01
                clipboard.changeCount = 1
                clipboard.text = "copied selection"
            },
            sendCopy: { true },
            isFrontmost: { _ in true }
        )

        XCTAssertThrowsError(try fallback.readSelection(from: NSRunningApplication.current)) { error in
            XCTAssertEqual(error as? ClipboardSelectionFallbackError, .restoreFailed)
        }
        XCTAssertEqual(fallback.lastRestoreStatus, .failed)
    }

    @MainActor
    func testCopyFallbackRestoresSnapshotWhenCancelledAfterCopy() {
        let clipboard = FakeSelectionClipboard()
        var now = 0.0
        var cancelled = false
        let fallback = ClipboardSelectionFallback(
            clipboard: clipboard,
            timeout: 0.1,
            now: { now },
            pump: { _ in
                now += 0.01
                clipboard.changeCount = 1
                clipboard.text = "copied selection"
                cancelled = true
            },
            sendCopy: { true },
            isFrontmost: { _ in true }
        )

        XCTAssertThrowsError(
            try fallback.readSelection(
                from: NSRunningApplication.current,
                isCancelled: { cancelled }
            )
        ) { error in
            XCTAssertEqual(error as? ClipboardSelectionFallbackError, .cancelled)
        }
        XCTAssertEqual(fallback.lastRestoreStatus, .restored)
        XCTAssertEqual(clipboard.restoreCalls, 1)
        XCTAssertEqual(clipboard.lastRestoredSnapshot, clipboard.snapshotValue)
    }

    @MainActor
    func testCopyFallbackRestoresSnapshotWhenSourceApplicationLosesFocus() {
        let clipboard = FakeSelectionClipboard()
        var now = 0.0
        var sourceIsFrontmost = true
        let fallback = ClipboardSelectionFallback(
            clipboard: clipboard,
            timeout: 0.1,
            now: { now },
            pump: { _ in
                now += 0.01
                clipboard.changeCount = 1
                clipboard.text = "copied selection"
                sourceIsFrontmost = false
            },
            sendCopy: { true },
            isFrontmost: { _ in sourceIsFrontmost }
        )

        XCTAssertThrowsError(try fallback.readSelection(from: NSRunningApplication.current)) { error in
            XCTAssertEqual(error as? ClipboardSelectionFallbackError, .sourceApplicationChanged)
        }
        XCTAssertEqual(fallback.lastRestoreStatus, .restored)
        XCTAssertEqual(clipboard.restoreCalls, 1)
    }

    @MainActor
    func testClipboardSnapshotRebuildsEveryItemAndRepresentation() throws {
        let firstItem = NSPasteboardItem()
        firstItem.setString("original", forType: .string)
        firstItem.setData(
            Data([1, 2, 3, 4]),
            forType: NSPasteboard.PasteboardType("com.marla.tests.binary")
        )
        let secondItem = NSPasteboardItem()
        secondItem.setData(
            Data("second".utf8),
            forType: NSPasteboard.PasteboardType("public.utf8-plain-text")
        )
        let snapshot = try PasteboardSnapshot.capture(items: [firstItem, secondItem])

        XCTAssertEqual(
            try PasteboardSnapshot.capture(items: snapshot.makePasteboardItems()),
            snapshot
        )
    }

    @MainActor
    func testSelectionCopyFallbackSettingDefaultsOffAndPersists() {
        let suite = "com.marla.tests.copy-fallback.(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let keychain = KeychainCredentialStore(service: "com.marla.tests", account: UUID().uuidString)

        let settings = MarlaSettingsStore(defaults: defaults, keychain: keychain)
        XCTAssertFalse(settings.selectionCopyFallbackEnabled)

        settings.selectionCopyFallbackEnabled = true
        let reloaded = MarlaSettingsStore(defaults: defaults, keychain: keychain)
        XCTAssertTrue(reloaded.selectionCopyFallbackEnabled)
    }

    @MainActor
    func testInlineTranslationExperimentDefaultsOffAndPersists() {
        let suite = "com.marla.tests.inline-overlay.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let keychain = KeychainCredentialStore(service: "com.marla.tests", account: UUID().uuidString)

        let settings = MarlaSettingsStore(defaults: defaults, keychain: keychain)
        XCTAssertFalse(settings.inlineTranslationExperimental)

        settings.inlineTranslationExperimental = true
        let reloaded = MarlaSettingsStore(defaults: defaults, keychain: keychain)
        XCTAssertTrue(reloaded.inlineTranslationExperimental)
    }

    @MainActor
    func testSelectionUIAutomationReportContainsNoSelectedTextOrClipboardContent() throws {
        let report = MarlaApplicationModel.SelectionUIAutomationReport(
            result: "success",
            errorCode: nil,
            textUTF16Length: 27,
            hasBounds: true,
            sourceApplicationBundleID: "com.apple.TextEdit",
            frontmostApplicationBundleIDAfterPresentation: "com.apple.TextEdit",
            focusPreserved: true,
            clipboardChangeCountDelta: 0,
            clipboardPreserved: true,
            diagnostics: SelectionReadDiagnostics(
                rootCount: 3,
                hadFocusedCandidate: true,
                hadPointerCandidate: true,
                rawPointerHitCount: 1,
                hadSystemFocusedElement: true,
                hadApplicationFocusedElement: true,
                hadFocusedWindow: true,
                systemFocusedApplicationMatched: true,
                visitedElementCount: 1,
                termination: .found,
                matchedMechanism: .standardRange,
                elapsedMilliseconds: 2
            )
        )
        let encoded = try JSONEncoder().encode(report)
        let json = try XCTUnwrap(String(data: encoded, encoding: .utf8))

        XCTAssertFalse(json.contains("Marla selection reliability"))
        XCTAssertFalse(json.contains("clipboardContent"))
        XCTAssertTrue(json.contains("textUTF16Length"))
        XCTAssertTrue(json.contains("clipboardChangeCountDelta"))
        XCTAssertTrue(json.contains("clipboardPreserved"))
    }

    @MainActor
    private func makeSessionStore() -> TranslationSessionStore {
        let suite = "com.marla.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return TranslationSessionStore(
            settings: MarlaSettingsStore(
                defaults: defaults,
                keychain: KeychainCredentialStore(
                    service: "com.marla.tests",
                    account: UUID().uuidString
                )
            )
        )
    }

    private func makeSolidImage(width: Int, height: Int, color: NSColor) throws -> CGImage {
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try XCTUnwrap(context.makeImage())
    }
}
