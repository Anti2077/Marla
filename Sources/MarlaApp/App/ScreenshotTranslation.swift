import AppKit
import MarlaCore

extension MarlaApplicationModel {
    func translateScreenshot() {
        let pointer = NSEvent.mouseLocation
        guard screenRecordingAuthorized else {
            showPermissionError(
                "截图翻译需要屏幕录制权限。",
                surface: .screenshot,
                pointer: pointer,
                recovery: .openScreenRecordingSettings
            )
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
                startScreenshotOCR(capture: capture, pointer: pointer)
            case let .failure(error):
                handleScreenshotSelectionFailure(error, pointer: pointer)
            }
        }
    }

    private func startScreenshotOCR(capture: CapturedScreenshot, pointer: CGPoint) {
        let anchor = ScreenRect(
            x: capture.globalRect.origin.x,
            y: capture.globalRect.origin.y,
            width: capture.globalRect.width,
            height: capture.globalRect.height
        )
        let provider = settings.ocrProvider
        let requestID = sessionStore.beginRecognizing(
            anchor: anchor,
            pointer: pointer,
            provider: provider
        )
        panelCoordinator.showResult(store: sessionStore, at: anchor, pointer: pointer, activate: false)

        if provider == .glmOCR, settings.glmOCRAPIKey == nil {
            sessionStore.fail(
                "云端 GLM-OCR 没有已保存的 API Key。请先在 OCR 设置中保存 Key。",
                code: .invalidConfiguration,
                for: requestID,
                recovery: .openOCRSettings
            )
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            if provider == .glmOCR, let apiKey = settings.glmOCRAPIKey {
                do {
                    let result = try await glmOCR.recognize(capture.image, apiKey: apiKey, requestID: requestID)
                    try Task.checkCancellation()
                    sessionStore.submitOCRResult(result, for: requestID)
                    return
                } catch is CancellationError {
                    return
                } catch {
                    sessionStore.beginVisionFallback(for: requestID)
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
                    provider == .glmOCR
                        ? "云端结构识别和本机 Vision 都没有识别到文字，请重新框选。"
                        : "没有识别到文字，请重新框选。",
                    code: .invalidResponse,
                    for: requestID,
                    recovery: .reselectScreenshot
                )
            }
        }
        sessionStore.attachOCRTask(task, for: requestID)
    }

    private func handleScreenshotSelectionFailure(_ error: any Error, pointer: CGPoint) {
        if case ScreenshotError.cancelled = error {
            sessionStore.close()
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
