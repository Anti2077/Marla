import Foundation

public enum TranslationInput: Equatable, Sendable {
    case selectedText(String)
    case screenshot(Data)
    case quickInput(String)

    public var requiresOCR: Bool {
        if case .screenshot = self {
            return true
        }
        return false
    }

    public var plainText: String? {
        switch self {
        case let .selectedText(text), let .quickInput(text):
            return text
        case .screenshot:
            return nil
        }
    }
}

public enum TranslationPresentation: String, Codable, CaseIterable, Sendable {
    case translationOnly
    case comparison
}

public struct TranslationIntent: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let input: TranslationInput
    public let sourceLanguage: String?
    public let targetLanguage: String
    public let presentation: TranslationPresentation
    public let context: ContextSnapshot

    public init(
        id: UUID = UUID(),
        input: TranslationInput,
        sourceLanguage: String? = nil,
        targetLanguage: String,
        presentation: TranslationPresentation = .translationOnly,
        context: ContextSnapshot = .empty
    ) {
        self.id = id
        self.input = input
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.presentation = presentation
        self.context = context
    }
}

public struct TranslationRequest: Equatable, Sendable {
    public let intentID: UUID
    public let blocks: [ContentBlock]
    public let sourceLanguage: String?
    public let targetLanguage: String
    public let context: ContextSnapshot

    public init(
        intentID: UUID,
        blocks: [ContentBlock],
        sourceLanguage: String?,
        targetLanguage: String,
        context: ContextSnapshot
    ) {
        self.intentID = intentID
        self.blocks = blocks
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.context = context
    }
}

public enum TranslationEvent: Equatable, Sendable {
    case started(intentID: UUID)
    case blockDelta(blockID: String, text: String)
    case blockCompleted(blockID: String, text: String)
    case completed(intentID: UUID)
}

public enum TranslationSessionState: Equatable, Sendable {
    case idle
    case acquiring
    case recognizing
    case translating
    case presenting
    case completed
    case failed(message: String)
    case cancelled
}
