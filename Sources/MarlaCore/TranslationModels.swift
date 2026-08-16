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

public enum TranslationContentFormat: String, Codable, CaseIterable, Sendable {
    case plainText
    case semanticMarkdown
}

public struct TranslationContent: Codable, Equatable, Sendable {
    public let format: TranslationContentFormat
    public let text: String

    public init(format: TranslationContentFormat, text: String) {
        self.format = format
        self.text = text
    }

    public static func plainText(_ text: String) -> TranslationContent {
        TranslationContent(format: .plainText, text: text)
    }

    public static func semanticMarkdown(_ text: String) -> TranslationContent {
        TranslationContent(format: .semanticMarkdown, text: text)
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

    public var defaultContentFormat: TranslationContentFormat {
        switch self {
        case .selection, .screenshot: .plainText
        case .quickInput: .semanticMarkdown
        }
    }
}

public enum TranslationTargetMode: String, Codable, Sendable {
    case automatic
    case explicit
}

public enum TranslationLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"
    case japanese = "ja"
    case french = "fr"
    case spanish = "es"
    case german = "de"
    case korean = "ko"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .english: "English"
        case .japanese: "日本語"
        case .french: "Français"
        case .spanish: "Español"
        case .german: "Deutsch"
        case .korean: "한국어"
        }
    }

    public init?(normalizing identifier: String?) {
        guard let identifier else { return nil }
        let normalized = identifier.lowercased()
        if normalized == "zh" || normalized.hasPrefix("zh-") {
            self = .simplifiedChinese
        } else if normalized == "en" || normalized.hasPrefix("en-") {
            self = .english
        } else if normalized == "ja" || normalized.hasPrefix("ja-") {
            self = .japanese
        } else if normalized == "fr" || normalized.hasPrefix("fr-") {
            self = .french
        } else if normalized == "es" || normalized.hasPrefix("es-") {
            self = .spanish
        } else if normalized == "de" || normalized.hasPrefix("de-") {
            self = .german
        } else if normalized == "ko" || normalized.hasPrefix("ko-") {
            self = .korean
        } else {
            return nil
        }
    }
}

public enum TranslationSourceMode: String, Codable, Sendable {
    case automatic
    case explicit
}

public struct TranslationSource: Codable, Equatable, Sendable {
    public let mode: TranslationSourceMode
    public let language: TranslationLanguage?

    public init(mode: TranslationSourceMode = .automatic, language: TranslationLanguage? = nil) {
        self.mode = mode
        self.language = mode == .explicit ? language : nil
    }

    public static let automatic = TranslationSource()

    public static func explicit(_ language: TranslationLanguage) -> TranslationSource {
        TranslationSource(mode: .explicit, language: language)
    }

    public func resolved(using detectedLanguage: TranslationLanguage?) -> TranslationLanguage? {
        mode == .explicit ? language : detectedLanguage
    }
}

public struct TranslationTarget: Codable, Equatable, Sendable {
    public let mode: TranslationTargetMode
    public let language: TranslationLanguage?

    public init(mode: TranslationTargetMode = .automatic, language: TranslationLanguage? = nil) {
        self.mode = mode
        self.language = mode == .explicit ? language : nil
    }

    public static let automatic = TranslationTarget()
    public static let simplifiedChinese = TranslationTarget.explicit(.simplifiedChinese)
    public static let english = TranslationTarget.explicit(.english)
    public static let japanese = TranslationTarget.explicit(.japanese)
    public static let french = TranslationTarget.explicit(.french)
    public static let spanish = TranslationTarget.explicit(.spanish)
    public static let german = TranslationTarget.explicit(.german)
    public static let korean = TranslationTarget.explicit(.korean)

    public static func explicit(_ language: TranslationLanguage) -> TranslationTarget {
        TranslationTarget(mode: .explicit, language: language)
    }

    public var label: String {
        switch mode {
        case .automatic: "自动"
        case .explicit: language?.label ?? "自动"
        }
    }
}

public enum TranslationLanguageRouter {
    public static func targetLanguage(
        sourceLanguage: TranslationLanguage?,
        target: TranslationTarget,
        nativeLanguage: TranslationLanguage,
        secondaryLanguage: TranslationLanguage
    ) -> TranslationLanguage {
        if target.mode == .explicit, let language = target.language {
            return language
        }
        return sourceLanguage == nativeLanguage ? secondaryLanguage : nativeLanguage
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

public enum TranslationEndpointURLMode: String, Codable, CaseIterable, Sendable {
    case baseURL
    case completeURL
}

public struct TranslationEndpointConfiguration: Codable, Equatable, Sendable {
    public var baseURL: String
    public var urlMode: TranslationEndpointURLMode
    public var model: String
    public var apiKey: String?

    public init(
        baseURL: String = "",
        urlMode: TranslationEndpointURLMode = .baseURL,
        model: String = "",
        apiKey: String? = nil
    ) {
        self.baseURL = baseURL
        self.urlMode = urlMode
        self.model = model
        self.apiKey = apiKey
    }
}

public struct TranslationFFIRequest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let requestID: UUID
    public let sourceContent: TranslationContent
    public let sourceLanguage: TranslationLanguage?
    public let target: TranslationTarget
    public let endpoint: TranslationEndpointConfiguration
    public let timeouts: TranslationTimeouts

    public init(
        requestID: UUID,
        sourceContent: TranslationContent,
        sourceLanguage: TranslationLanguage?,
        target: TranslationTarget,
        endpoint: TranslationEndpointConfiguration,
        timeouts: TranslationTimeouts = .default
    ) {
        self.schemaVersion = 3
        self.requestID = requestID
        self.sourceContent = sourceContent
        self.sourceLanguage = sourceLanguage
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

public struct ModelListFFIRequest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let requestID: UUID
    public let endpoint: TranslationEndpointConfiguration

    public init(requestID: UUID, endpoint: TranslationEndpointConfiguration) {
        self.schemaVersion = 1
        self.requestID = requestID
        self.endpoint = endpoint
    }
}

public struct ModelListFFIEvent: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let requestID: UUID
    public let type: String
    public let models: [String]?
    public let code: TranslationErrorCode?
    public let message: String?

    public init(
        schemaVersion: Int,
        requestID: UUID,
        type: String,
        models: [String]? = nil,
        code: TranslationErrorCode? = nil,
        message: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.requestID = requestID
        self.type = type
        self.models = models
        self.code = code
        self.message = message
    }
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
