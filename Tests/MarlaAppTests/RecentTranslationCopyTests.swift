import AppKit
import MarlaCore
import XCTest
@testable import MarlaApp

final class RecentTranslationCopyTests: XCTestCase {
    @MainActor
    func testCopyUsesRequestedHistoryWithoutReplacingActiveSession() throws {
        let store = makeStore()
        let source = "# 原文\n\n" + String(repeating: "保留 `TOKEN` 和内部换行。\n", count: 40)
        let translation = "# Translation\n\n**Keep** `TOKEN`.\n\n| A | B |\n| --- | --- |\n| 一 | two |\r\n"
        store.installUIAutomationFixture(surface: .quickInput, sourceText: source,
                                         translation: translation, state: .completed,
                                         contentFormat: .semanticMarkdown)
        let id = try XCTUnwrap(store.recentTranslations.first?.id)
        store.installUIAutomationFixture(surface: .selection, sourceText: "Other source",
                                         translation: "Other result", state: .completed)
        store.installUIAutomationFixture(surface: .selection, sourceText: "Active source",
                                         translation: "Still streaming", state: .streaming)
        let active = try XCTUnwrap(store.session)
        let history = store.recentTranslations
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }

        XCTAssertTrue(store.copyRecentTranslation(id: id, to: pasteboard))
        XCTAssertEqual(pasteboard.string(forType: .string), translation.removingTrailingLineBreaks())
        XCTAssertTrue(store.copyRecentTranslation(id: id, content: .source, to: pasteboard))
        XCTAssertEqual(pasteboard.string(forType: .string), source.removingTrailingLineBreaks())
        XCTAssertEqual(store.session?.id, active.id)
        XCTAssertEqual(store.session?.state, active.state)
        XCTAssertEqual(store.session?.sourceContent, active.sourceContent)
        XCTAssertEqual(store.session?.translation, active.translation)
        XCTAssertNil(store.session?.copyConfirmation)
        XCTAssertEqual(store.recentTranslations, history)
    }

    @MainActor
    func testInvalidOrEvictedHistoryDoesNotOverwritePasteboard() throws {
        let store = makeStore()
        store.installUIAutomationFixture(surface: .selection, sourceText: "old", translation: "旧", state: .completed)
        let id = try XCTUnwrap(store.recentTranslations.first?.id)
        for index in 0..<3 {
            store.installUIAutomationFixture(surface: .selection, sourceText: "source-\(index)",
                                             translation: "译文-\(index)", state: .completed)
        }
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("untouched", forType: .string)
        let changeCount = pasteboard.changeCount
        XCTAssertFalse(store.copyRecentTranslation(id: id, to: pasteboard))
        XCTAssertFalse(store.copyRecentTranslation(id: UUID(), content: .source, to: pasteboard))
        XCTAssertEqual(pasteboard.changeCount, changeCount)
        XCTAssertEqual(pasteboard.string(forType: .string), "untouched")
    }

    @MainActor
    func testEmptySourceIsNotRecordedAndCopyWorksWithoutActiveSession() throws {
        let store = makeStore()
        store.installUIAutomationFixture(surface: .selection, sourceText: "\r\n", translation: "译文\n", state: .completed)
        XCTAssertTrue(store.recentTranslations.isEmpty)
        store.installUIAutomationFixture(surface: .selection, sourceText: "原文\n", translation: "译文\n", state: .completed)
        let id = try XCTUnwrap(store.recentTranslations.first?.id)
        store.close()
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("untouched", forType: .string)
        let changeCount = pasteboard.changeCount
        XCTAssertFalse(store.copyRecentTranslation(id: UUID(), content: .source, to: pasteboard))
        XCTAssertEqual(pasteboard.changeCount, changeCount)
        XCTAssertTrue(store.copyRecentTranslation(id: id, to: pasteboard))
        XCTAssertEqual(pasteboard.string(forType: .string), "译文")
        XCTAssertNil(store.session)
    }

    @MainActor
    private func makeStore() -> TranslationSessionStore {
        let suite = "com.marla.recent-copy-tests.\(UUID().uuidString)"
        return TranslationSessionStore(settings: MarlaSettingsStore(
            defaults: UserDefaults(suiteName: suite)!,
            keychain: KeychainCredentialStore(service: suite, account: "test")
        ))
    }
}
