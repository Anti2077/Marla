import AppKit
import MarlaCore
@testable import MarlaApp
import XCTest

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

        XCTAssertEqual(cancellationCount, 2)
    }

    @MainActor
    func testScreenshotEscapeMonitorInstallsAndRemovesSessionMonitors() {
        let monitor = ScreenshotEscapeMonitor {}

        XCTAssertFalse(monitor.isInstalled)
        monitor.install()
        XCTAssertTrue(monitor.isInstalled)
        monitor.remove()
        XCTAssertFalse(monitor.isInstalled)
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
}
