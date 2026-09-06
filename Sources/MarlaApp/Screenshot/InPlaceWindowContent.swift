import Foundation
import MarlaCore

enum InPlaceWindowContent {
    static func make(document: OCRDocument, translation: InPlaceTranslationResult) -> TranslationContent? {
        let sourceIDs = document.blocks.map(\.id)
        let translatedIDs = translation.blocks.map(\.id)
        guard !sourceIDs.isEmpty,
              Set(sourceIDs).count == sourceIDs.count,
              Set(translatedIDs).count == translatedIDs.count,
              Set(sourceIDs) == Set(translatedIDs),
              translation.blocks.allSatisfy({ !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        else { return nil }
        let byID = translation.textByID
        let sources = Dictionary(uniqueKeysWithValues: document.blocks.map { ($0.id, $0) })
        let sections = InPlaceTableGrouping.units(document: document, translation: translation).flatMap { unit -> [String] in
            switch unit.content {
            case let .table(_, _, markdown, _, _):
                return [markdown]
            case let .single(source, text):
                return [section(text, kind: source.kind)]
            case let .omitted(ids):
                // Geometry/fit rejection does not discard a validated translation in the result window.
                return ids.compactMap { id in
                    guard let text = byID[id], let source = sources[id] else { return nil }
                    return section(text, kind: source.kind)
                }
            }
        }
        return .semanticMarkdown(sections.joined(separator: "\n\n"))
    }

    private static func section(_ text: String, kind: ContentBlockKind) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .title, .heading:
            return trimmed.hasPrefix("#") ? text : (kind == .title ? "# " : "## ") + text
        case .table:
            return LiteralHTMLTableNormalizer.markdown(from: text) ?? text
        default:
            return text
        }
    }
}
