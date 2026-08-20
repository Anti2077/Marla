import Foundation

public enum OCRProviderKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case vision
    case glmOCR

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .vision: "本机 Vision"
        case .glmOCR: "云端 GLM-OCR"
        }
    }
}

public struct OCRResult: Codable, Equatable, Sendable {
    public let provider: OCRProviderKind
    public let document: OCRDocument
    public let content: TranslationContent

    public init(provider: OCRProviderKind, document: OCRDocument, content: TranslationContent) {
        self.provider = provider
        self.document = document
        self.content = content
    }
}

public struct OCRTimeouts: Codable, Equatable, Sendable {
    public var connectSeconds: Int
    public var overallSeconds: Int

    public init(connectSeconds: Int = 10, overallSeconds: Int = 60) {
        self.connectSeconds = connectSeconds
        self.overallSeconds = overallSeconds
    }

    public static let `default` = OCRTimeouts()
}

public struct OCRFFIRequest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let requestID: UUID
    public let imageBase64: String
    public let mimeType: String
    public let apiKey: String
    public let timeouts: OCRTimeouts

    public init(
        requestID: UUID,
        imageData: Data,
        mimeType: String,
        apiKey: String,
        timeouts: OCRTimeouts = .default
    ) {
        schemaVersion = 1
        self.requestID = requestID
        imageBase64 = imageData.base64EncodedString()
        self.mimeType = mimeType
        self.apiKey = apiKey
        self.timeouts = timeouts
    }
}

public struct OCRFFIEvent: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let requestID: UUID
    public let type: String
    public let result: OCRResult?
    public let code: TranslationErrorCode?
    public let message: String?
    public let retryable: Bool?

    public init(
        schemaVersion: Int,
        requestID: UUID,
        type: String,
        result: OCRResult? = nil,
        code: TranslationErrorCode? = nil,
        message: String? = nil,
        retryable: Bool? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.requestID = requestID
        self.type = type
        self.result = result
        self.code = code
        self.message = message
        self.retryable = retryable
    }
}
