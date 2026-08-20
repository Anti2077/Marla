import Foundation

public struct OCRRequest: Equatable, Sendable {
    public let imageData: Data
    public let preferredLanguages: [String]

    public init(imageData: Data, preferredLanguages: [String] = []) {
        self.imageData = imageData
        self.preferredLanguages = preferredLanguages
    }
}

public protocol OCRProvider: Sendable {
    func recognize(_ request: OCRRequest) async throws -> OCRResult
}

public protocol TranslationProvider: Sendable {
    func translate(
        _ request: TranslationRequest
    ) -> AsyncThrowingStream<TranslationEvent, any Error>
}

public protocol ContextProvider: Sendable {
    func context(for intent: TranslationIntent) async -> ContextSnapshot
}
