import Foundation

public enum ContentBlockKind: String, Codable, CaseIterable, Sendable {
    case title
    case heading
    case paragraph
    case listItem
    case table
    case code
    case formula
    case caption
    case other
}

public struct ContentBlock: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let kind: ContentBlockKind
    public let sourceText: String
    public let bounds: NormalizedRect?
    public let readingOrder: Int
    public let confidence: Double?

    public init(
        id: String,
        kind: ContentBlockKind,
        sourceText: String,
        bounds: NormalizedRect? = nil,
        readingOrder: Int,
        confidence: Double? = nil
    ) {
        self.id = id
        self.kind = kind
        self.sourceText = sourceText
        self.bounds = bounds
        self.readingOrder = readingOrder
        self.confidence = confidence.map { min(max($0, 0), 1) }
    }
}

public struct OCRDocument: Codable, Equatable, Sendable {
    public let blocks: [ContentBlock]
    public let detectedLanguage: String?

    public init(blocks: [ContentBlock], detectedLanguage: String? = nil) {
        self.blocks = blocks.sorted { lhs, rhs in
            if lhs.readingOrder == rhs.readingOrder {
                return lhs.id < rhs.id
            }
            return lhs.readingOrder < rhs.readingOrder
        }
        self.detectedLanguage = detectedLanguage
    }

    public var plainText: String {
        blocks.map(\.sourceText).joined(separator: "\n")
    }
}
