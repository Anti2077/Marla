import Foundation
import MarlaCore

struct InPlaceTranslationServiceError: LocalizedError, Equatable {
    let code: TranslationErrorCode
    let message: String
    let retryable: Bool

    var errorDescription: String? { message }
}

struct InPlaceTranslationConfiguration: Equatable, Sendable {
    let sourceContent: TranslationContent
    let sourceLanguage: TranslationLanguage?
    let target: TranslationTarget
    let endpoint: TranslationEndpointConfiguration
}

@MainActor
final class InPlaceTranslationService {
    private let client = RustTranslationClient()
    private var activeRequestID: UUID?
    private var handle: RustTranslationClient.Handle?
    private var continuation: CheckedContinuation<InPlaceTranslationResult, any Error>?

    func translate(
        document: OCRDocument,
        configuration: InPlaceTranslationConfiguration,
        requestID: UUID
    ) async throws -> InPlaceTranslationResult {
        cancelActiveRequest()
        try Task.checkCancellation()
        let blocks = document.blocks.map { block in
            let sourceText: String
            if block.kind == .table {
                sourceText = LiteralHTMLTableNormalizer.markdown(from: block.sourceText) ?? block.sourceText
            } else {
                sourceText = block.sourceText
            }
            return InPlaceTranslationSourceBlock(id: block.id, kind: block.kind, sourceText: sourceText)
        }
        guard !blocks.isEmpty else {
            throw InPlaceTranslationServiceError(
                code: .invalidConfiguration,
                message: "GLM-OCR 没有返回可定位的文字块。",
                retryable: false
            )
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                activeRequestID = requestID
                self.continuation = continuation
                do {
                    handle = try client.start(
                        request: TranslationFFIRequest(
                            requestID: requestID,
                            sourceContent: configuration.sourceContent,
                            sourceLanguage: configuration.sourceLanguage,
                            target: configuration.target,
                            endpoint: configuration.endpoint,
                            inPlaceBlocks: blocks
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

    private func apply(_ event: TranslationFFIEvent) {
        guard event.schemaVersion == 1,
              event.requestID == activeRequestID
        else { return }

        switch event.type {
        case "completed":
            guard let text = event.text,
                  let data = text.data(using: .utf8),
                  let result = try? JSONDecoder().decode(InPlaceTranslationResult.self, from: data),
                  Set(result.blocks.map(\.id)).count == result.blocks.count
            else {
                finish(
                    throwing: InPlaceTranslationServiceError(
                        code: .invalidResponse,
                        message: "翻译服务没有返回可安全定位的块级译文。",
                        retryable: true
                    )
                )
                return
            }
            finish(returning: result)
        case "failed":
            finish(
                throwing: InPlaceTranslationServiceError(
                    code: event.code ?? .internalError,
                    message: event.message ?? "原位翻译失败。",
                    retryable: event.retryable ?? false
                )
            )
        case "cancelled":
            finish(throwing: CancellationError())
        default:
            break
        }
    }

    private func finish(returning result: InPlaceTranslationResult) {
        let pending = continuation
        clearActiveRequest()
        pending?.resume(returning: result)
    }

    private func finish(throwing error: any Error) {
        let pending = continuation
        clearActiveRequest()
        pending?.resume(throwing: error)
    }

    private func clearActiveRequest() {
        continuation = nil
        activeRequestID = nil
        handle?.release()
        handle = nil
    }
}
