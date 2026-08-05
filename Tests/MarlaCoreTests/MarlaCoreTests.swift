import Foundation
@testable import MarlaCore
import XCTest

final class MarlaCoreTests: XCTestCase {
    func testNormalizedRectClampsToUnitSpace() {
        let rect = NormalizedRect(x: -0.2, y: 0.8, width: 2, height: 0.5)

        XCTAssertEqual(rect.x, 0)
        XCTAssertEqual(rect.y, 0.8)
        XCTAssertEqual(rect.width, 1)
        XCTAssertEqual(rect.height, 0.2, accuracy: 0.000_001)
    }

    func testOCRDocumentSortsBlocksByReadingOrder() {
        let later = ContentBlock(
            id: "later",
            kind: .paragraph,
            sourceText: "Later",
            readingOrder: 2
        )
        let earlier = ContentBlock(
            id: "earlier",
            kind: .heading,
            sourceText: "Earlier",
            readingOrder: 1
        )

        let document = OCRDocument(blocks: [later, earlier])

        XCTAssertEqual(document.blocks.map(\.id), ["earlier", "later"])
    }

    func testOnlyScreenshotIntentRequiresOCR() {
        let context = ContextSnapshot(surface: .terminal, domain: .softwareDevelopment)
        let textIntent = TranslationIntent(
            input: .selectedText("port is already in use"),
            targetLanguage: "zh-Hans",
            context: context
        )
        let screenshotIntent = TranslationIntent(
            input: .screenshot(Data([0x01])),
            targetLanguage: "zh-Hans"
        )

        XCTAssertFalse(textIntent.input.requiresOCR)
        XCTAssertTrue(screenshotIntent.input.requiresOCR)
        XCTAssertEqual(textIntent.context.domain, .softwareDevelopment)
    }

    func testContextCacheExpiresEntries() async {
        let cache = ContextCache(timeToLive: 60)
        let key = ContextCacheKey(
            applicationBundleID: "com.apple.Terminal",
            windowIdentifier: "server"
        )
        let snapshot = ContextSnapshot(
            applicationBundleID: "com.apple.Terminal",
            surface: .terminal,
            domain: .softwareDevelopment
        )
        let start = Date(timeIntervalSince1970: 1_000)

        await cache.store(snapshot, for: key, now: start)

        let active = await cache.value(for: key, now: start.addingTimeInterval(59))
        let expired = await cache.value(for: key, now: start.addingTimeInterval(61))

        XCTAssertEqual(active, snapshot)
        XCTAssertNil(expired)
    }

    func testTextSelectionKeepsSourceTextAndDetectsVisibleContent() {
        let selection = TextSelection(
            text: "  port is already in use\n",
            bounds: ScreenRect(x: 20, y: 30, width: 100, height: 18),
            applicationBundleID: "com.apple.Terminal",
            applicationName: "Terminal"
        )

        XCTAssertEqual(selection.text, "  port is already in use\n")
        XCTAssertTrue(selection.hasVisibleText)
        XCTAssertEqual(selection.bounds?.width, 100)
    }

    func testWhitespaceOnlySelectionIsNotVisible() {
        let selection = TextSelection(text: " \n\t ")

        XCTAssertFalse(selection.hasVisibleText)
    }

    func testRustCoreBridgeVersionAndSurfaceClassification() {
        XCTAssertEqual(RustCoreBridge.apiVersion, 1)
        XCTAssertEqual(
            RustCoreBridge.classifySurface(applicationBundleID: "com.apple.Terminal"),
            .terminal
        )
        XCTAssertEqual(
            RustCoreBridge.classifySurface(applicationBundleID: "com.example.Unknown"),
            .unknown
        )
    }
}
