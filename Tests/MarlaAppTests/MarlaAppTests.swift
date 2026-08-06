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
