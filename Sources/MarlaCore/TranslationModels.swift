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

public enum TranslationSurface: String, Codable, CaseIterable, Sendable {
    case selection
    case screenshot
    case quickInput

    public var displayName: String {
        switch self {
        case .selection: "划词翻译"
        case .screenshot: "截图翻译"
        case .quickInput: "快速输入"
        }
    }
}

public enum TranslationTargetMode: String, Codable, Sendable {
    case automatic
    case explicit
}

public struct TranslationTarget: Codable, Equatable, Sendable {
    public let mode: TranslationTargetMode
    public let language: String?

    public init(mode: TranslationTargetMode = .automatic, language: String? = nil) {
        self.mode = mode
        self.language = mode == .explicit ? language : nil
    }

    public static let automatic = TranslationTarget()
    public static let simplifiedChinese = TranslationTarget(mode: .explicit, language: "zh-Hans")
    public static let english = TranslationTarget(mode: .explicit, language: "en")

    public var label: String {
        switch (mode, language) {
        case (.automatic, _): "自动"
        case (.explicit, "zh-Hans"): "简体中文"
        case (.explicit, "en"): "English"
        default: language ?? "自动"
        }
    }
}

public enum TranslationErrorCode: String, Codable, Sendable {
    case invalidConfiguration = "invalid_configuration"
    case unauthorized
    case rateLimited = "rate_limited"
    case network
    case timeout
    case provider
    case invalidResponse = "invalid_response"
    case internalError = "internal"
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
    case started(requestID: UUID)
    case delta(requestID: UUID, text: String)
    case completed(requestID: UUID, text: String)
    case failed(requestID: UUID, code: TranslationErrorCode, message: String, retryable: Bool)
    case cancelled(requestID: UUID)
}

public enum TranslationSessionState: Equatable, Sendable {
    case idle
    case acquiring
    case recognizing
    case awaitingFirstToken
    case streaming
    case completed
    case failed(message: String)
    case cancelled
}

public struct CardPresentation: Equatable, Sendable {
    public var anchor: ScreenRect?
    public var preferredWidth: Double
    public var minimumWidth: Double
    public var maximumWidth: Double
    public var maximumVisibleHeightRatio: Double
    public var isTransient: Bool
    public var isPinned: Bool
    public var activatesOnPresentation: Bool

    public init(
        anchor: ScreenRect? = nil,
        preferredWidth: Double = 380,
        minimumWidth: Double = 320,
        maximumWidth: Double = 520,
        maximumVisibleHeightRatio: Double = 0.6,
        isTransient: Bool = true,
        isPinned: Bool = false,
        activatesOnPresentation: Bool = false
    ) {
        self.anchor = anchor
        self.preferredWidth = preferredWidth
        self.minimumWidth = minimumWidth
        self.maximumWidth = maximumWidth
        self.maximumVisibleHeightRatio = maximumVisibleHeightRatio
        self.isTransient = isTransient
        self.isPinned = isPinned
        self.activatesOnPresentation = activatesOnPresentation
    }
}

public struct TranslationEndpointConfiguration: Codable, Equatable, Sendable {
    public var baseURL: String
    public var model: String
    public var apiKey: String?

    public init(baseURL: String = "", model: String = "", apiKey: String? = nil) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
    }
}

public struct TranslationFFIRequest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let requestID: UUID
    public let sourceText: String
    public let target: TranslationTarget
    public let endpoint: TranslationEndpointConfiguration
    public let timeouts: TranslationTimeouts

    public init(
        requestID: UUID,
        sourceText: String,
        target: TranslationTarget,
        endpoint: TranslationEndpointConfiguration,
        timeouts: TranslationTimeouts = .default
    ) {
        self.schemaVersion = 1
        self.requestID = requestID
        self.sourceText = sourceText
        self.target = target
        self.endpoint = endpoint
        self.timeouts = timeouts
    }
}

public struct TranslationTimeouts: Codable, Equatable, Sendable {
    public var connectSeconds: Int
    public var firstTokenSeconds: Int
    public var overallSeconds: Int

    public init(connectSeconds: Int = 10, firstTokenSeconds: Int = 30, overallSeconds: Int = 120) {
        self.connectSeconds = connectSeconds
        self.firstTokenSeconds = firstTokenSeconds
        self.overallSeconds = overallSeconds
    }

    public static let `default` = TranslationTimeouts()
}

public struct TranslationFFIEvent: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let requestID: UUID
    public let type: String
    public let text: String?
    public let code: TranslationErrorCode?
    public let message: String?
    public let retryable: Bool?

    public init(
        schemaVersion: Int,
        requestID: UUID,
        type: String,
        text: String? = nil,
        code: TranslationErrorCode? = nil,
        message: String? = nil,
        retryable: Bool? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.requestID = requestID
        self.type = type
        self.text = text
        self.code = code
        self.message = message
        self.retryable = retryable
    }
}

public enum TranslationSessionReducer {
    @discardableResult
    public static func apply(
        _ event: TranslationFFIEvent,
        requestID: UUID,
        state: inout TranslationSessionState,
        translation: inout String
    ) -> Bool {
        guard event.schemaVersion == 1, event.requestID == requestID else { return false }

        switch event.type {
        case "started":
            state = .awaitingFirstToken
        case "delta":
            guard !state.isTerminal else { return false }
            state = .streaming
            translation += event.text ?? ""
        case "completed":
            guard !state.isTerminal else { return false }
            state = .completed
            if let text = event.text, !text.isEmpty {
                translation = text
            }
        case "failed":
            guard !state.isTerminal else { return false }
            state = .failed(message: event.message ?? "翻译失败，请重试。")
        case "cancelled":
            guard !state.isTerminal else { return false }
            state = .cancelled
        default:
            return false
        }
        return true
    }
}

public extension TranslationSessionState {
    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            true
        case .idle, .acquiring, .recognizing, .awaitingFirstToken, .streaming:
            false
        }
    }
}
