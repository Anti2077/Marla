import CoreGraphics
import Foundation
import MarlaCore

struct GLMOCRServiceError: LocalizedError, Equatable {
    let code: TranslationErrorCode
    let message: String
    let retryable: Bool

    var errorDescription: String? { message }
}

@MainActor
final class GLMOCRService {
    private let client = RustOCRClient()
    private var activeRequestID: UUID?
    private var handle: RustOCRClient.Handle?
    private var continuation: CheckedContinuation<OCRResult, any Error>?

    func recognize(_ image: CGImage, apiKey: String, requestID: UUID) async throws -> OCRResult {
        cancelActiveRequest()
        try Task.checkCancellation()
        let encoded = try CloudOCRImageEncoder.encode(image)
        try Task.checkCancellation()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                activeRequestID = requestID
                self.continuation = continuation
                do {
                    handle = try client.start(
                        request: OCRFFIRequest(
                            requestID: requestID,
                            imageData: encoded.data,
                            mimeType: encoded.mimeType,
                            apiKey: apiKey
                        )
                    ) { [weak self] event in
                        Task { @MainActor [weak self] in
                            self?.apply(event)
                        }
                    }
                } catch {
                    finish(throwing: error)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelActiveRequest()
            }
        }
    }

    func cancelActiveRequest() {
        handle?.cancel()
        handle?.release()
        handle = nil
        activeRequestID = nil
        let pending = continuation
        continuation = nil
        pending?.resume(throwing: CancellationError())
    }

    private func apply(_ event: OCRFFIEvent) {
        guard event.schemaVersion == 1, event.requestID == activeRequestID else { return }
        switch event.type {
        case "completed":
            guard let result = event.result else {
                finish(throwing: GLMOCRServiceError(
                    code: .invalidResponse,
                    message: "GLM-OCR 没有返回可用的结构化内容。",
                    retryable: true
                ))
                return
            }
            finish(returning: result)
        case "failed":
            finish(throwing: GLMOCRServiceError(
                code: event.code ?? .provider,
                message: event.message ?? "GLM-OCR 结构识别失败。",
                retryable: event.retryable ?? true
            ))
        case "cancelled":
            finish(throwing: CancellationError())
        default:
            break
        }
    }

    private func finish(returning result: OCRResult) {
        let pending = takeContinuation()
        pending?.resume(returning: result)
    }

    private func finish(throwing error: any Error) {
        let pending = takeContinuation()
        pending?.resume(throwing: error)
    }

    private func takeContinuation() -> CheckedContinuation<OCRResult, any Error>? {
        handle?.release()
        handle = nil
        activeRequestID = nil
        let pending = continuation
        continuation = nil
        return pending
    }
}
