import Foundation
import MarlaCore

struct InPlaceOverlaySourceUnit {
    enum Content {
        case single(ContentBlock, translatedText: String)
        case table(
            sourceIDs: [String],
            sourceMarkdown: String,
            translatedMarkdown: String,
            bounds: NormalizedRect,
            preservesSourceGrid: Bool
        )
        case omitted(sourceIDs: [String])
    }

    let content: Content
}

enum InPlaceTableGrouping {
    static func units(
        document: OCRDocument,
        translation: InPlaceTranslationResult
    ) -> [InPlaceOverlaySourceUnit] {
        let textByID = translation.textByID
        var units: [InPlaceOverlaySourceUnit] = []
        var index = document.blocks.startIndex

        while index < document.blocks.endIndex {
            let source = document.blocks[index]
            guard let translatedText = textByID[source.id] else {
                units.append(.init(content: .omitted(sourceIDs: [source.id])))
                index = document.blocks.index(after: index)
                continue
            }

            guard isTableFragment(source: source, translatedText: translatedText) else {
                units.append(.init(content: .single(source, translatedText: translatedText)))
                index = document.blocks.index(after: index)
                continue
            }

            var runEnd = document.blocks.index(after: index)
            while runEnd < document.blocks.endIndex {
                let candidate = document.blocks[runEnd]
                guard let candidateTranslation = textByID[candidate.id],
                      isTableFragment(source: candidate, translatedText: candidateTranslation)
                else { break }
                runEnd = document.blocks.index(after: runEnd)
            }

            let run = Array(document.blocks[index..<runEnd])
            units.append(contentsOf: partition(run, textByID: textByID))
            index = runEnd
        }
        return units
    }

    private static func partition(
        _ run: [ContentBlock],
        textByID: [String: String]
    ) -> [InPlaceOverlaySourceUnit] {
        var units: [InPlaceOverlaySourceUnit] = []
        var start = run.startIndex

        while start < run.endIndex {
            var acceptedEnd: Int?
            var end = run.endIndex
            while end > start {
                let candidates = Array(run[start..<end])
                if let unit = tableUnit(from: candidates, textByID: textByID) {
                    units.append(unit)
                    acceptedEnd = end
                    break
                }
                end -= 1
            }

            if let acceptedEnd {
                start = acceptedEnd
            } else {
                units.append(.init(content: .omitted(sourceIDs: [run[start].id])))
                start += 1
            }
        }
        return units
    }

    private static func tableUnit(
        from blocks: [ContentBlock],
        textByID: [String: String]
    ) -> InPlaceOverlaySourceUnit? {
        guard !blocks.isEmpty,
              geometryIsCoherent(blocks),
              let bounds = unionBounds(blocks)
        else { return nil }

        let translatedLines = blocks.compactMap { textByID[$0.id] }
        guard translatedLines.count == blocks.count,
              translatedLines.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        else { return nil }

        let sourceMarkdown = blocks.map { block in
            if block.kind == .table {
                return LiteralHTMLTableNormalizer.markdown(from: block.sourceText) ?? block.sourceText
            }
            return block.sourceText
        }.joined(separator: "\n")
        let translatedMarkdown = translatedLines.joined(separator: "\n")
        guard let sourceTable = InPlaceMarkdownProjection.table(from: sourceMarkdown),
              let translatedTable = InPlaceMarkdownProjection.table(from: translatedMarkdown),
              sourceTable.rows.count == translatedTable.rows.count,
              sourceTable.rows.first?.count == translatedTable.rows.first?.count
        else { return nil }

        return InPlaceOverlaySourceUnit(
            content: .table(
                sourceIDs: blocks.map(\.id),
                sourceMarkdown: sourceMarkdown,
                translatedMarkdown: translatedMarkdown,
                bounds: bounds,
                preservesSourceGrid: blocks.count == 1 && blocks[0].kind == .table
            )
        )
    }

    private static func isTableFragment(source: ContentBlock, translatedText: String) -> Bool {
        source.kind == .table
            || InPlaceMarkdownProjection.containsTableSyntax(source.sourceText)
            || InPlaceMarkdownProjection.containsTableSyntax(translatedText)
    }

    private static func geometryIsCoherent(_ blocks: [ContentBlock]) -> Bool {
        guard let first = blocks.first else { return false }
        guard blocks.count > 1 else { return first.bounds != nil }

        for pair in zip(blocks, blocks.dropFirst()) {
            guard pair.1.readingOrder == pair.0.readingOrder + 1,
                  let upper = pair.0.bounds,
                  let lower = pair.1.bounds
            else { return false }

            let horizontalIntersection = max(
                0,
                min(upper.x + upper.width, lower.x + lower.width) - max(upper.x, lower.x)
            )
            let horizontalOverlap = horizontalIntersection / max(0.000_001, min(upper.width, lower.width))
            let verticalGap = lower.y - (upper.y + upper.height)
            let maximumGap = max(0.04, max(upper.height, lower.height) * 2.5)
            guard lower.y >= upper.y - 0.01,
                  horizontalOverlap >= 0.45,
                  verticalGap <= maximumGap
            else { return false }
        }
        return true
    }

    private static func unionBounds(_ blocks: [ContentBlock]) -> NormalizedRect? {
        let bounds = blocks.compactMap(\.bounds)
        guard bounds.count == blocks.count,
              bounds.allSatisfy(isValid),
              let first = bounds.first
        else { return nil }
        let minX = bounds.dropFirst().reduce(first.x) { min($0, $1.x) }
        let minY = bounds.dropFirst().reduce(first.y) { min($0, $1.y) }
        let maxX = bounds.dropFirst().reduce(first.x + first.width) { max($0, $1.x + $1.width) }
        let maxY = bounds.dropFirst().reduce(first.y + first.height) { max($0, $1.y + $1.height) }
        return NormalizedRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func isValid(_ bounds: NormalizedRect) -> Bool {
        bounds.x.isFinite
            && bounds.y.isFinite
            && bounds.width.isFinite
            && bounds.height.isFinite
            && bounds.x >= 0
            && bounds.y >= 0
            && bounds.width > 0
            && bounds.height > 0
            && bounds.x + bounds.width <= 1
            && bounds.y + bounds.height <= 1
    }
}
