import Foundation
@testable import MarlaCore
import XCTest

final class MarlaCoreTests: XCTestCase {
    func testTranslationCallbackMetricsQueuesOnlyDeltaReceipts() {
        let requestID = UUID()
        TranslationCallbackMetrics.record(
            TranslationFFIEvent(schemaVersion: 1, requestID: requestID, type: "delta", text: "disabled"),
            at: 5,
            enabled: false
        )
        XCTAssertNil(TranslationCallbackMetrics.takeDeltaReceipt(for: requestID))

        TranslationCallbackMetrics.record(
            TranslationFFIEvent(schemaVersion: 1, requestID: requestID, type: "started"),
            at: 10,
            enabled: true
        )
        XCTAssertNil(TranslationCallbackMetrics.takeDeltaReceipt(for: requestID))

        TranslationCallbackMetrics.record(
            TranslationFFIEvent(schemaVersion: 1, requestID: requestID, type: "delta", text: "a"),
            at: 20,
            enabled: true
        )
        TranslationCallbackMetrics.record(
            TranslationFFIEvent(schemaVersion: 1, requestID: requestID, type: "delta", text: "b"),
            at: 30,
            enabled: true
        )
        XCTAssertEqual(TranslationCallbackMetrics.takeDeltaReceipt(for: requestID), 20)
        XCTAssertEqual(TranslationCallbackMetrics.takeDeltaReceipt(for: requestID), 30)
        XCTAssertNil(TranslationCallbackMetrics.takeDeltaReceipt(for: requestID))
    }

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
        XCTAssertEqual(document.plainText, "Earlier\nLater")
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
        XCTAssertEqual(selection.content, .plainText("  port is already in use\n"))
        XCTAssertTrue(selection.hasVisibleText)
        XCTAssertEqual(selection.bounds?.width, 100)
    }

    func testWhitespaceOnlySelectionIsNotVisible() {
        let selection = TextSelection(text: " \n\t ")

        XCTAssertFalse(selection.hasVisibleText)
    }

    func testTextSelectionCanCarrySemanticMarkdown() {
        let selection = TextSelection(content: .semanticMarkdown("# Heading"))

        XCTAssertEqual(selection.text, "# Heading")
        XCTAssertEqual(selection.content.format, .semanticMarkdown)
        XCTAssertTrue(selection.hasVisibleText)
    }

    func testRustCoreBridgeVersionAndSurfaceClassification() {
        XCTAssertEqual(RustCoreBridge.apiVersion, 4)
        XCTAssertEqual(
            RustCoreBridge.classifySurface(applicationBundleID: "com.apple.Terminal"),
            .terminal
        )
        XCTAssertEqual(
            RustCoreBridge.classifySurface(applicationBundleID: "com.example.Unknown"),
            .unknown
        )
    }

    func testOCRFFIRequestAndCompletedEventKeepVersionedStructuredContract() throws {
        let requestID = UUID(uuidString: "00000000-0000-0000-0000-000000000033")!
        let request = OCRFFIRequest(
            requestID: requestID,
            imageData: Data([0x89, 0x50, 0x4E, 0x47]),
            mimeType: "image/png",
            apiKey: "secret"
        )
        let encoded = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
        XCTAssertEqual(object["requestID"] as? String, requestID.uuidString)
        XCTAssertEqual(object["mimeType"] as? String, "image/png")
        XCTAssertEqual(object["imageBase64"] as? String, "iVBORw==")

        let result = OCRResult(
            provider: .glmOCR,
            document: OCRDocument(blocks: [
                ContentBlock(id: "block-0", kind: .heading, sourceText: "Title", readingOrder: 0)
            ]),
            content: .semanticMarkdown("# Title")
        )
        let event = OCRFFIEvent(schemaVersion: 1, requestID: requestID, type: "completed", result: result)
        XCTAssertEqual(try JSONDecoder().decode(OCRFFIEvent.self, from: JSONEncoder().encode(event)), event)
    }

    func testTranslationRequestEncodesNestedCredentialAndTarget() throws {
        let request = TranslationFFIRequest(
            requestID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            sourceContent: .semanticMarkdown("# Hello\n\nworld"),
            sourceLanguage: .english,
            target: .japanese,
            endpoint: TranslationEndpointConfiguration(
                baseURL: "https://example.com/v1",
                urlMode: .completeURL,
                model: "demo",
                apiKey: "secret"
            )
        )
        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, 3)
        XCTAssertEqual(
            object["requestID"] as? String,
            "00000000-0000-0000-0000-000000000001"
        )
        XCTAssertNil(object["requestId"])
        let sourceContent = try XCTUnwrap(object["sourceContent"] as? [String: Any])
        XCTAssertEqual(sourceContent["format"] as? String, "semanticMarkdown")
        XCTAssertEqual(sourceContent["text"] as? String, "# Hello\n\nworld")
        XCTAssertNil(object["sourceText"])
        XCTAssertEqual(object["sourceLanguage"] as? String, "en")
        let endpoint = try XCTUnwrap(object["endpoint"] as? [String: Any])
        XCTAssertEqual(endpoint["baseURL"] as? String, "https://example.com/v1")
        XCTAssertEqual(endpoint["urlMode"] as? String, "completeURL")
        XCTAssertNil(endpoint["baseUrl"])
        XCTAssertEqual(endpoint["apiKey"] as? String, "secret")
        let target = try XCTUnwrap(object["target"] as? [String: Any])
        XCTAssertEqual(target["mode"] as? String, "explicit")
        XCTAssertEqual(target["language"] as? String, "ja")
    }

    func testTranslationSurfacesDeclareHonestDefaultContentFormats() {
        XCTAssertEqual(TranslationSurface.selection.defaultContentFormat, .plainText)
        XCTAssertEqual(TranslationSurface.screenshot.defaultContentFormat, .plainText)
        XCTAssertEqual(TranslationSurface.quickInput.defaultContentFormat, .semanticMarkdown)
    }

    func testTranslationLanguageNormalizationAndAutomaticRouting() {
        XCTAssertEqual(TranslationLanguage(normalizing: "zh-Hant"), .simplifiedChinese)
        XCTAssertEqual(TranslationLanguage(normalizing: "en-US"), .english)
        XCTAssertEqual(TranslationLanguage(normalizing: "ja-JP"), .japanese)
        XCTAssertEqual(TranslationLanguage(normalizing: "fr-FR"), .french)
        XCTAssertEqual(TranslationLanguage(normalizing: "es-MX"), .spanish)
        XCTAssertEqual(TranslationLanguage(normalizing: "de-DE"), .german)
        XCTAssertEqual(TranslationLanguage(normalizing: "ko-KR"), .korean)
        XCTAssertNil(TranslationLanguage(normalizing: "it"))

        for nativeLanguage in TranslationLanguage.allCases {
            for secondaryLanguage in TranslationLanguage.allCases where secondaryLanguage != nativeLanguage {
                XCTAssertEqual(
                    TranslationLanguageRouter.targetLanguage(
                        sourceLanguage: nativeLanguage,
                        target: .automatic,
                        nativeLanguage: nativeLanguage,
                        secondaryLanguage: secondaryLanguage
                    ),
                    secondaryLanguage
                )
                XCTAssertEqual(
                    TranslationLanguageRouter.targetLanguage(
                        sourceLanguage: nil,
                        target: .automatic,
                        nativeLanguage: nativeLanguage,
                        secondaryLanguage: secondaryLanguage
                    ),
                    nativeLanguage
                )
                XCTAssertEqual(
                    TranslationLanguageRouter.targetLanguage(
                        sourceLanguage: secondaryLanguage,
                        target: .japanese,
                        nativeLanguage: nativeLanguage,
                        secondaryLanguage: secondaryLanguage
                    ),
                    .japanese
                )
            }
        }
    }

    func testModelListRequestEncodesCurrentURLModeAndCredential() throws {
        let request = ModelListFFIRequest(
            requestID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            endpoint: TranslationEndpointConfiguration(
                baseURL: "https://example.com/v1/chat/completions",
                urlMode: .completeURL,
                model: "",
                apiKey: "secret"
            )
        )
        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
        let endpoint = try XCTUnwrap(object["endpoint"] as? [String: Any])
        XCTAssertEqual(endpoint["baseURL"] as? String, "https://example.com/v1/chat/completions")
        XCTAssertEqual(endpoint["urlMode"] as? String, "completeURL")
        XCTAssertEqual(endpoint["apiKey"] as? String, "secret")
    }

    func testTranslationEventsDecodeStableFailureAndDelta() throws {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let delta = try JSONDecoder().decode(
            TranslationFFIEvent.self,
            from: Data("{\"schemaVersion\":1,\"requestID\":\"\(id.uuidString)\",\"type\":\"delta\",\"text\":\"你\"}".utf8)
        )
        XCTAssertEqual(delta.requestID, id)
        XCTAssertEqual(delta.text, "你")
        let failure = try JSONDecoder().decode(
            TranslationFFIEvent.self,
            from: Data("{\"schemaVersion\":1,\"requestID\":\"\(id.uuidString)\",\"type\":\"failed\",\"code\":\"rate_limited\",\"message\":\"slow\",\"retryable\":true}".utf8)
        )
        XCTAssertEqual(failure.code, .rateLimited)
        XCTAssertTrue(failure.retryable == true)
    }

    func testTranslationSessionReducerTransitionsAndRejectsLateEvents() {
        let currentID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let staleID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
        var state = TranslationSessionState.awaitingFirstToken
        var translation = ""

        XCTAssertFalse(
            TranslationSessionReducer.apply(
                TranslationFFIEvent(
                    schemaVersion: 1,
                    requestID: staleID,
                    type: "delta",
                    text: "旧"
                ),
                requestID: currentID,
                state: &state,
                translation: &translation
            )
        )
        XCTAssertEqual(state, .awaitingFirstToken)
        XCTAssertEqual(translation, "")

        XCTAssertTrue(
            TranslationSessionReducer.apply(
                TranslationFFIEvent(
                    schemaVersion: 1,
                    requestID: currentID,
                    type: "delta",
                    text: "新"
                ),
                requestID: currentID,
                state: &state,
                translation: &translation
            )
        )
        XCTAssertEqual(state, .streaming)
        XCTAssertEqual(translation, "新")

        XCTAssertTrue(
            TranslationSessionReducer.apply(
                TranslationFFIEvent(
                    schemaVersion: 1,
                    requestID: currentID,
                    type: "completed",
                    text: "新译文"
                ),
                requestID: currentID,
                state: &state,
                translation: &translation
            )
        )
        XCTAssertEqual(state, .completed)
        XCTAssertEqual(translation, "新译文")

        XCTAssertFalse(
            TranslationSessionReducer.apply(
                TranslationFFIEvent(
                    schemaVersion: 1,
                    requestID: currentID,
                    type: "delta",
                    text: "迟到"
                ),
                requestID: currentID,
                state: &state,
                translation: &translation
            )
        )
        XCTAssertEqual(translation, "新译文")
    }

    func testCardPresentationUsesAcceptedSizingAndTransientDefaults() {
        let presentation = CardPresentation()
        XCTAssertEqual(presentation.preferredWidth, 380)
        XCTAssertEqual(presentation.minimumWidth, 320)
        XCTAssertEqual(presentation.maximumWidth, 520)
        XCTAssertEqual(presentation.maximumVisibleHeightRatio, 0.6)
        XCTAssertTrue(presentation.isTransient)
        XCTAssertFalse(presentation.isPinned)
        XCTAssertFalse(presentation.activatesOnPresentation)
    }
}
