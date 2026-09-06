import AppKit
import MarlaCore
import XCTest
@testable import MarlaApp

@MainActor
final class InPlaceChromeTests: XCTestCase {
    func testChromeAddsOnlyExteriorSpaceAtNegativeScreenCoordinates() throws {
        let capture = try capture()
        let coordinator = ScreenshotTranslationOverlayCoordinator()
        let id = UUID()
        coordinator.presentWaiting(capture: capture, requestID: id, onCancel: {})
        defer { coordinator.close() }
        XCTAssertEqual(coordinator.presentedFrame, capture.globalRect)
        XCTAssertEqual(coordinator.chromeFrame, InPlaceChromeGeometry.windowFrame(for: capture.globalRect))
        let identity = coordinator.panelIdentity
        coordinator.setChromeProximityForUIAutomation(true)
        XCTAssertEqual(coordinator.presentedFrame, capture.globalRect)
        XCTAssertEqual(coordinator.panelIdentity, identity)
        coordinator.setChromeProximityForUIAutomation(false)
        XCTAssertEqual(coordinator.presentedFrame, capture.globalRect)
    }

    func testProximityHasHysteresisAndIncludesTheActionTravelArea() {
        let size = CGSize(width: 600, height: 400)
        XCTAssertTrue(InPlaceChromeGeometry.isNearEdge(CGPoint(x: 10, y: 200), size: size, wasNear: false))
        XCTAssertFalse(InPlaceChromeGeometry.isNearEdge(CGPoint(x: 42, y: 200), size: size, wasNear: false))
        XCTAssertTrue(InPlaceChromeGeometry.isNearEdge(CGPoint(x: 42, y: 200), size: size, wasNear: true))
        XCTAssertFalse(InPlaceChromeGeometry.isNearEdge(CGPoint(x: 300, y: 200), size: size, wasNear: true))
        XCTAssertTrue(InPlaceChromeGeometry.isNearEdge(CGPoint(x: 500, y: 45), size: size, wasNear: false))
        XCTAssertFalse(InPlaceChromeGeometry.isNearEdge(CGPoint(x: -1, y: 45), size: size, wasNear: true))
    }

    func testTransferIsCompletedOnlySingleUseAndDoesNotCancelTextSession() throws {
        let coordinator = ScreenshotTranslationOverlayCoordinator()
        let id = UUID()
        var transfers = 0
        var cancellations = 0
        coordinator.presentWaiting(capture: try capture(), requestID: id, onCancel: {
            cancellations += 1
        }, onTransfer: { received in
            XCTAssertEqual(received, id)
            transfers += 1
            return true
        })
        coordinator.enableTransfer(for: id)
        XCTAssertFalse(coordinator.canTransfer)
        XCTAssertFalse(coordinator.transferToWindow(for: id))
        XCTAssertTrue(coordinator.updateStage(.translating, for: id))
        XCTAssertFalse(coordinator.transferToWindow(for: id))
        XCTAssertTrue(try coordinator.apply(layout: layout(), for: id))
        coordinator.enableTransfer(for: id)
        XCTAssertTrue(coordinator.canTransfer)
        XCTAssertFalse(coordinator.transferToWindow(for: UUID()))
        XCTAssertTrue(coordinator.transferToWindow(for: id))
        XCTAssertNil(coordinator.activeRequestID)
        XCTAssertNil(coordinator.chromeFrame)
        XCTAssertFalse(coordinator.isPresented)
        XCTAssertFalse(coordinator.transferToWindow(for: id))
        coordinator.close()
        XCTAssertEqual(transfers, 1)
        XCTAssertEqual(cancellations, 0)
    }

    func testFailedHandoffKeepsOverlayAndFailureDisablesTransfer() throws {
        let coordinator = ScreenshotTranslationOverlayCoordinator()
        let id = UUID()
        coordinator.presentWaiting(capture: try capture(), requestID: id, onCancel: {}, onTransfer: { _ in false })
        defer { coordinator.close() }
        XCTAssertTrue(try coordinator.apply(layout: layout(), for: id))
        coordinator.enableTransfer(for: id)
        XCTAssertFalse(coordinator.transferToWindow(for: id))
        XCTAssertTrue(coordinator.isPresented)
        XCTAssertTrue(coordinator.showFailure("Failed", for: id))
        XCTAssertFalse(coordinator.canTransfer)
        XCTAssertFalse(coordinator.transferToWindow(for: id))
    }

    func testReplacementCannotTransferThePreviousResult() throws {
        let coordinator = ScreenshotTranslationOverlayCoordinator()
        let firstID = UUID()
        let secondID = UUID()
        var transfers = 0
        coordinator.presentWaiting(capture: try capture(), requestID: firstID, onCancel: {}, onTransfer: { _ in
            transfers += 1
            return true
        })
        XCTAssertTrue(try coordinator.apply(layout: layout(), for: firstID))
        coordinator.enableTransfer(for: firstID)
        coordinator.presentWaiting(capture: try capture(), requestID: secondID, onCancel: {})
        defer { coordinator.close() }
        XCTAssertFalse(coordinator.transferToWindow(for: firstID))
        XCTAssertFalse(coordinator.canTransfer)
        XCTAssertEqual(transfers, 0)
    }

    func testWindowContentRetainsReadingOrderAndGeometryOmittedTranslations() throws {
        let document = OCRDocument(blocks: [
            block("title", .title, "Title", order: 0),
            block("table", .table, "<table><tr><th>A</th><th>B</th></tr><tr><td>C</td><td>D</td></tr></table>", order: 1),
            block("missing-bounds", .paragraph, "Source", order: 2, bounds: nil)
        ])
        let markdown = "| 甲 | 乙 |\n| --- | --- |\n| **丙** | `丁` |"
        let translation = InPlaceTranslationResult(blocks: [
            .init(id: "missing-bounds", text: "完整的**段落**"),
            .init(id: "table", text: markdown),
            .init(id: "title", text: "标题")
        ])
        let content = try XCTUnwrap(InPlaceWindowContent.make(document: document, translation: translation))
        XCTAssertEqual(content.format, .semanticMarkdown)
        XCTAssertEqual(content.text, "# 标题\n\n\(markdown)\n\n完整的**段落**")
        XCTAssertEqual(MarkdownResultDocument.parse(content.text)?.blocks.count, 3)
    }

    func testWindowContentRejectsDuplicateMissingUnknownOrEmptyResults() {
        let document = OCRDocument(blocks: [block("a", .paragraph, "A", order: 0)])
        for blocks: [InPlaceTranslatedBlock] in [[], [.init(id: "b", text: "B")],
              [.init(id: "a", text: "A"), .init(id: "a", text: "B")], [.init(id: "a", text: " \n")]] {
            XCTAssertNil(InPlaceWindowContent.make(document: document, translation: .init(blocks: blocks)))
        }
    }

    func testSessionHandoffPreservesContentMetadataAndDoesNotReadCredentialsOrRecordHistory() throws {
        let suite = "com.marla.tests.inplace-transfer.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var credentialReads = 0
        let keychain = KeychainCredentialStore(service: suite, backend: KeychainItemBackend(
            read: { _, _, _ in credentialReads += 1; return .notFound },
            save: { _, _, _ in false }, remove: { _, _ in false }
        ))
        let store = TranslationSessionStore(settings: MarlaSettingsStore(defaults: defaults, keychain: keychain))
        store.installUIAutomationFixture(surface: .screenshot, sourceText: "# Source", translation: "",
                                         state: .awaitingFirstToken, contentFormat: .semanticMarkdown)
        let initial = try XCTUnwrap(store.session)
        let readsBeforeTransfer = credentialReads
        XCTAssertNil(store.prepareInPlaceWindowTransfer(for: initial.id))
        store.completeInPlaceTranslation(for: initial.id, content: .semanticMarkdown("# 译文\n\n**正文**"))
        let moved = try XCTUnwrap(store.prepareInPlaceWindowTransfer(for: initial.id))
        XCTAssertEqual(moved.id, initial.id)
        XCTAssertEqual(moved.profileID, initial.profileID)
        XCTAssertEqual(moved.sourceContent, initial.sourceContent)
        XCTAssertEqual(moved.target, initial.target)
        XCTAssertEqual(moved.resolvedTargetLanguage, initial.resolvedTargetLanguage)
        XCTAssertEqual(moved.translation, "# 译文\n\n**正文**")
        XCTAssertEqual(moved.state, .completed)
        XCTAssertTrue(store.recentTranslations.isEmpty)
        XCTAssertEqual(credentialReads, readsBeforeTransfer)
        let nextID = store.beginRecognizing(anchor: nil, pointer: nil)
        XCTAssertNil(store.prepareInPlaceWindowTransfer(for: initial.id))
        store.completeInPlaceTranslation(for: initial.id, content: .semanticMarkdown("stale"))
        XCTAssertEqual(store.session?.id, nextID)
        XCTAssertEqual(store.session?.translation, "")
        store.close()
    }

    func testTransferButtonIsFullyInsideExpandedTopBorderAndNeverOverScreenshot() {
        for size in [CGSize(width: 884, height: 672), CGSize(width: 264, height: 192)] {
            let button = InPlaceChromeGeometry.transferRect(in: size)
            let capture = InPlaceChromeGeometry.captureRect(in: size)
            let expanded = InPlaceChromeGeometry.outerRect(in: size, expanded: true)
            XCTAssertTrue(expanded.contains(button))
            XCTAssertFalse(capture.intersects(button))
            XCTAssertTrue(InPlaceChromeGeometry.isNearEdge(CGPoint(x: button.midX, y: button.midY),
                                                            size: size, wasNear: true))
            let collapsed = InPlaceChromeGeometry.outerRect(in: size, expanded: false)
            XCTAssertEqual(capture.minY - collapsed.minY, 6)
            XCTAssertEqual(capture.minX - expanded.minX, 10)
            XCTAssertEqual(capture.minY - expanded.minY, 36)
        }
    }

    func testHiddenNearbyMonitorKeepsSessionThroughActualHandoffThenVisiblePanelDismisses() throws {
        _ = NSApplication.shared
        let suite = "com.marla.tests.inplace-monitor.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let keychain = KeychainCredentialStore(service: suite, backend: KeychainItemBackend(
            read: { _, _, _ in XCTFail("No credentials should be read"); return .notFound },
            save: { _, _, _ in false }, remove: { _, _ in false }
        ))
        let model = MarlaApplicationModel(
            settings: MarlaSettingsStore(defaults: defaults, keychain: keychain), enableSystemIntegrations: false
        )
        model.sessionStore.installUIAutomationFixture(surface: .screenshot, sourceText: "Source", translation: "",
                                                     state: .recognizing, contentFormat: .semanticMarkdown)
        let id = try XCTUnwrap(model.sessionStore.session?.id)
        let coordinator = model.screenshotTranslationOverlay
        defer { coordinator.close(); model.panelCoordinator.hide() }
        coordinator.presentWaiting(capture: try capture(), requestID: id, onCancel: { model.sessionStore.close() },
                                   onTransfer: { model.moveInPlaceTranslationToWindow(for: $0) })
        XCTAssertTrue(try coordinator.apply(layout: layout(), for: id))
        model.sessionStore.completeInPlaceTranslation(for: id, content: .semanticMarkdown("**译文**"))
        coordinator.enableTransfer(for: id)
        let mouseDown = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
        let escape = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53))
        // This is the monitor invoked before a real overlay button's action, absent from old snapshot fixtures.
        XCTAssertFalse(model.panelCoordinator.handleDismissalEvent(mouseDown, isLocal: true))
        XCTAssertFalse(model.panelCoordinator.handleDismissalEvent(mouseDown, isLocal: false))
        XCTAssertFalse(model.panelCoordinator.handleDismissalEvent(escape, isLocal: true))
        XCTAssertEqual(model.sessionStore.session?.id, id)
        XCTAssertTrue(coordinator.transferToWindow(for: id))
        XCTAssertEqual(model.sessionStore.session?.translation, "**译文**")
        XCTAssertEqual(model.sessionStore.session?.state, .completed)
        XCTAssertFalse(coordinator.isPresented)
        model.panelCoordinator.handleDismissalEvent(mouseDown, isLocal: true)
        XCTAssertNil(model.sessionStore.session, "Visible nearby panels must still dismiss on outside clicks")
        let newID = model.sessionStore.beginRecognizing(anchor: nil, pointer: nil)
        model.panelCoordinator.handleDismissalEvent(mouseDown, isLocal: true)
        XCTAssertEqual(model.sessionStore.session?.id, newID, "A previously shown but now hidden panel must stay inactive")
    }

    private func block(_ id: String, _ kind: ContentBlockKind, _ text: String, order: Int,
                       bounds: NormalizedRect? = NormalizedRect(x: 0.1, y: 0.2, width: 0.8, height: 0.6)) -> ContentBlock {
        ContentBlock(id: id, kind: kind, sourceText: text, bounds: bounds, readingOrder: order)
    }

    private func layout() throws -> InPlaceOverlayLayout {
        try InPlaceOverlayLayoutBuilder.make(
            document: OCRDocument(blocks: [block("a", .paragraph, "Source", order: 0)]),
            translation: .init(blocks: [.init(id: "a", text: "译文")]),
            canvasSize: CGSize(width: 240, height: 160)
        )
    }

    private func capture() throws -> CapturedScreenshot {
        _ = NSApplication.shared
        let context = try XCTUnwrap(CGContext(data: nil, width: 240, height: 160, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 240, height: 160))
        return CapturedScreenshot(image: try XCTUnwrap(context.makeImage()),
                                  globalRect: CGRect(x: -260, y: 60, width: 240, height: 160))
    }
}
