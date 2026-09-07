import AppKit
import MarlaCore

extension MarlaApplicationModel {
    func translateScreenshot() {
        beginScreenshotTranslation(intent: .nearby)
    }

    func translateInPlace() {
        guard settings.isInPlaceTranslationEnabled else { return }
        beginScreenshotTranslation(intent: .inPlace)
    }

    private func beginScreenshotTranslation(intent: ScreenshotTranslationIntent) {
        activeScreenshotVisionFallback = nil
        screenshotTranslationOverlay.close()
        inPlaceTranslation.cancelActiveRequest()
        let pointer = NSEvent.mouseLocation
        guard screenRecordingAuthorized else {
            if intent.presentsNearbyFailureCardBeforeCapture {
                showPermissionError(
                    "截图翻译需要屏幕录制权限。",
                    surface: .screenshot,
                    pointer: pointer,
                    recovery: .openScreenRecordingSettings
                )
            } else {
                requestScreenRecordingAccess()
            }
            return
        }
        let originatingApplication = NSWorkspace.shared.frontmostApplication
        let settingsWereVisible = settingsWindowCoordinator.suspendForScreenshotSelection()
        panelCoordinator.hide()
        screenshotCoordinator.present { [weak self] result in
            guard let self else { return }
            settingsWindowCoordinator.restoreAfterScreenshotSelection(wasVisible: settingsWereVisible)
            restoreFrontmostApplication(originatingApplication)
            switch result {
            case let .success(capture):
                startScreenshotOCR(capture: capture, pointer: pointer, intent: intent)
            case let .failure(error):
                handleScreenshotSelectionFailure(error, pointer: pointer, intent: intent)
            }
        }
    }

    private func startScreenshotOCR(
        capture: CapturedScreenshot,
        pointer: CGPoint,
        intent: ScreenshotTranslationIntent
    ) {
        let anchor = ScreenRect(
            x: capture.globalRect.origin.x,
            y: capture.globalRect.origin.y,
            width: capture.globalRect.width,
            height: capture.globalRect.height
        )
        let provider = intent.ocrProvider(configuredProvider: settings.ocrProvider)
        let requestID = sessionStore.beginRecognizing(
            anchor: anchor,
            pointer: pointer,
            provider: provider
        )
        if provider == .glmOCR, intent == .nearby {
            activeScreenshotVisionFallback = (capture: capture, requestID: requestID)
        }
        if intent.usesInPlaceOverlay {
            screenshotTranslationOverlay.presentWaiting(
                capture: capture,
                requestID: requestID,
                onCancel: { [weak self] in
                    guard let self, sessionStore.session?.id == requestID else { return }
                    glmOCR.cancelActiveRequest()
                    inPlaceTranslation.cancelActiveRequest()
                    sessionStore.close()
                },
                onTransfer: { [weak self] id in
                    self?.moveInPlaceTranslationToWindow(for: id) ?? false
                }
            )
        } else if intent.presentsNearbyResultCardAfterCapture {
            panelCoordinator.showResult(store: sessionStore, at: anchor, pointer: pointer, activate: false)
        }

        if provider == .glmOCR, settings.glmOCRAPIKey == nil {
            activeScreenshotVisionFallback = nil
            let message = intent.usesInPlaceOverlay
                ? "原位翻译需要 GLM-OCR API Key"
                : "云端 GLM-OCR 没有已保存的 API Key。请先在 OCR 设置中保存 Key。"
            sessionStore.fail(
                message,
                code: .invalidConfiguration,
                for: requestID,
                recovery: .openOCRSettings
            )
            if intent.usesInPlaceOverlay {
                screenshotTranslationOverlay.showFailure(message, for: requestID)
            }
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            if provider == .glmOCR, let apiKey = settings.glmOCRAPIKey {
                do {
                    let result = try await glmOCR.recognize(capture.image, apiKey: apiKey, requestID: requestID)
                    try Task.checkCancellation()
                    guard intent.usesInPlaceOverlay else {
                        activeScreenshotVisionFallback = nil
                        sessionStore.submitOCRResult(result, for: requestID)
                        return
                    }
                    screenshotTranslationOverlay.updateStage(.translating, for: requestID)
                    guard let configuration = sessionStore.prepareInPlaceTranslation(result, for: requestID) else {
                        screenshotTranslationOverlay.showFailure(
                            inPlaceFailureMessage(fallback: "无法开始原位翻译"),
                            for: requestID
                        )
                        return
                    }
                    do {
                        let translated = try await inPlaceTranslation.translate(
                            document: result.document,
                            configuration: configuration,
                            requestID: requestID
                        )
                        try Task.checkCancellation()
                        let layout = try InPlaceOverlayLayoutBuilder.make(
                            document: result.document,
                            translation: translated,
                            canvasSize: capture.globalRect.size
                        )
                        if try screenshotTranslationOverlay.apply(layout: layout, for: requestID) {
                            let content = InPlaceWindowContent.make(document: result.document, translation: translated)
                            sessionStore.completeInPlaceTranslation(for: requestID, content: content)
                            if content != nil { screenshotTranslationOverlay.enableTransfer(for: requestID) }
                        }
                    } catch is CancellationError {
                        return
                    } catch {
                        let message = error.localizedDescription
                        sessionStore.fail(
                            message,
                            code: .invalidResponse,
                            for: requestID
                        )
                        screenshotTranslationOverlay.showFailure(message, for: requestID)
                    }
                    return
                } catch is CancellationError {
                    return
                } catch {
                    if !intent.allowsVisionFallback {
                        activeScreenshotVisionFallback = nil
                        let message = error.localizedDescription
                        sessionStore.fail(
                            message,
                            code: .invalidResponse,
                            for: requestID,
                            retryable: true
                        )
                        screenshotTranslationOverlay.showFailure(message, for: requestID)
                        return
                    }
                    sessionStore.beginVisionFallback(for: requestID)
                    await recognizeScreenshotWithVision(
                        capture: capture,
                        requestID: requestID,
                        glmFailureMessage: true
                    )
                    return
                }
            }

            await recognizeScreenshotWithVision(
                capture: capture,
                requestID: requestID,
                glmFailureMessage: provider == .glmOCR
            )
        }
        sessionStore.attachOCRTask(task, for: requestID)
    }

    private func recognizeScreenshotWithVision(
        capture: CapturedScreenshot,
        requestID: UUID,
        glmFailureMessage: Bool
    ) async {
        defer {
            if activeScreenshotVisionFallback?.requestID == requestID {
                activeScreenshotVisionFallback = nil
            }
        }
        do {
            let document = try await visionOCR.recognize(capture.image)
            try Task.checkCancellation()
            sessionStore.submitOCRResult(
                OCRResult(provider: .vision, document: document, content: .plainText(document.plainText)),
                for: requestID
            )
        } catch is CancellationError {
            return
        } catch {
            sessionStore.fail(
                glmFailureMessage
                    ? "云端结构识别和本机 Vision 都没有识别到文字，请重新框选。"
                    : "没有识别到文字，请重新框选。",
                code: .invalidResponse,
                for: requestID,
                recovery: .reselectScreenshot
            )
        }
    }

    func fallbackScreenshotOCRToVision(for requestID: UUID) {
        guard let fallback = activeScreenshotVisionFallback,
              fallback.requestID == requestID,
              let session = sessionStore.session,
              session.id == requestID,
              session.surface == .screenshot,
              session.state == .recognizing,
              session.ocrActivity == .glmOCR
        else { return }

        activeScreenshotVisionFallback = nil
        sessionStore.cancelCurrentRequest()
        glmOCR.cancelActiveRequest()
        sessionStore.beginVisionFallback(for: requestID, reason: .userRequested)

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.recognizeScreenshotWithVision(
                capture: fallback.capture,
                requestID: requestID,
                glmFailureMessage: false
            )
        }
        sessionStore.attachOCRTask(task, for: requestID)
    }

    private func inPlaceFailureMessage(fallback: String) -> String {
        guard let session = sessionStore.session,
              case let .failed(message) = session.state
        else { return fallback }
        return message
    }

    @discardableResult
    func moveInPlaceTranslationToWindow(for requestID: UUID) -> Bool {
        guard screenshotTranslationOverlay.activeRequestID == requestID,
              let session = sessionStore.prepareInPlaceWindowTransfer(for: requestID) else { return false }
        panelCoordinator.showResult(
            store: sessionStore, at: session.anchor, pointer: session.pointer, activate: true
        )
        return true
    }

    private func handleScreenshotSelectionFailure(
        _ error: any Error,
        pointer: CGPoint,
        intent: ScreenshotTranslationIntent
    ) {
        if case ScreenshotError.cancelled = error {
            sessionStore.close()
        } else if !intent.presentsNearbyFailureCardBeforeCapture {
            sessionStore.close()
            if case ScreenshotError.captureFailed = error {
                requestScreenRecordingAccess()
            }
        } else {
            sessionStore.startText("", surface: .screenshot, anchor: nil, pointer: pointer)
            sessionStore.fail(
                error.localizedDescription,
                code: .invalidConfiguration,
                recovery: .openScreenRecordingSettings
            )
            panelCoordinator.showResult(
                store: sessionStore,
                at: nil,
                pointer: pointer,
                activate: false
            )
        }
    }
}
