import Foundation

public struct InPlaceTranslationSourceBlock: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let kind: ContentBlockKind
    public let sourceText: String

    public init(id: String, kind: ContentBlockKind, sourceText: String) {
        self.id = id
        self.kind = kind
        self.sourceText = sourceText
    }

    public init(contentBlock: ContentBlock) {
        self.init(id: contentBlock.id, kind: contentBlock.kind, sourceText: contentBlock.sourceText)
    }
}

public struct InPlaceTranslatedBlock: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }
}

public struct InPlaceTranslationResult: Codable, Equatable, Sendable {
    public let blocks: [InPlaceTranslatedBlock]

    public init(blocks: [InPlaceTranslatedBlock]) {
        self.blocks = blocks
    }

    public var textByID: [String: String] {
        Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, $0.text) })
    }
}
