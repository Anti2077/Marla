import Foundation
import SwiftUI

struct MarkdownResultDocument {
    struct Block {
        let kind: Kind
        var content: AttributedString
    }

    enum Kind: Equatable {
        case heading(level: Int)
        case paragraph
        case unorderedItem(depth: Int)
        case orderedItem(ordinal: Int, depth: Int)
        case blockQuote
        case codeBlock(language: String?)
        case thematicBreak
        case table(Table)
    }

    struct Table: Equatable {
        enum Alignment: Equatable {
            case leading
            case center
            case trailing
        }

        let alignments: [Alignment]
        let rows: [[AttributedString]]
    }

    let blocks: [Block]

    static func parse(_ markdown: String) -> MarkdownResultDocument? {
        guard !markdown.isEmpty else { return nil }
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [Block] = []
        var ordinaryLines: [String] = []
        var lineIndex = 0

        func flushOrdinaryLines() -> Bool {
            defer { ordinaryLines.removeAll(keepingCapacity: true) }
            guard ordinaryLines.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
                return true
            }
            guard let parsedBlocks = foundationBlocks(from: ordinaryLines.joined(separator: "\n")) else {
                return false
            }
            blocks.append(contentsOf: parsedBlocks)
            return true
        }

        while lineIndex < lines.count {
            if let candidate = tableCandidate(in: lines, startingAt: lineIndex) {
                guard flushOrdinaryLines() else { return nil }
                blocks.append(Block(kind: .table(candidate.table), content: AttributedString()))
                lineIndex += candidate.lineCount
            } else {
                ordinaryLines.append(lines[lineIndex])
                lineIndex += 1
            }
        }

        guard flushOrdinaryLines() else { return nil }
        return blocks.isEmpty ? nil : MarkdownResultDocument(blocks: blocks)
    }

    var plainText: String {
        var result = ""
        var previousKind: Kind?
        for block in blocks {
            let separator = if let previousKind {
                Self.areAdjacentListItems(previousKind, block.kind) ? "\n" : "\n\n"
            } else {
                ""
            }
            result += separator + Self.plainText(for: block)
            previousKind = block.kind
        }
        return result.removingTrailingLineBreaks()
    }

    private static func plainText(for block: Block) -> String {
        switch block.kind {
        case .heading, .paragraph, .blockQuote:
            String(block.content.characters).removingTrailingLineBreaks()
        case let .unorderedItem(depth):
            String(repeating: "  ", count: max(0, depth - 1))
                + "• "
                + String(block.content.characters).removingTrailingLineBreaks()
        case let .orderedItem(ordinal, depth):
            String(repeating: "  ", count: max(0, depth - 1))
                + "\(ordinal). "
                + String(block.content.characters).removingTrailingLineBreaks()
        case .codeBlock:
            String(block.content.characters).removingTrailingLineBreaks()
        case .thematicBreak:
            "────────"
        case let .table(table):
            table.rows.map { row in
                row.map { String($0.characters).removingTrailingLineBreaks() }.joined(separator: "\t")
            }.joined(separator: "\n")
        }
    }

    private static func areAdjacentListItems(_ lhs: Kind, _ rhs: Kind) -> Bool {
        switch (lhs, rhs) {
        case (.unorderedItem, .unorderedItem), (.orderedItem, .orderedItem): true
        default: false
        }
    }

    private struct TableCandidate {
        let table: Table
        let lineCount: Int
    }

    private static func foundationBlocks(from markdown: String) -> [Block]? {
        do {
            let parsed = try fullAttributedMarkdown(markdown)
            var blocks: [Block] = []
            var currentIdentity: Int?

            for run in parsed.runs {
                guard let descriptor = descriptor(for: run.presentationIntent) else { return nil }
                var fragment = AttributedString(parsed[run.range])
                fragment.presentationIntent = nil
                fragment.imageURL = nil

                if currentIdentity == descriptor.identity, !blocks.isEmpty {
                    blocks[blocks.count - 1].content.append(fragment)
                } else {
                    currentIdentity = descriptor.identity
                    blocks.append(Block(kind: descriptor.kind, content: fragment))
                }
            }
            return blocks
        } catch {
            return nil
        }
    }

    private static func tableCandidate(in lines: [String], startingAt index: Int) -> TableCandidate? {
        guard index + 1 < lines.count,
              let header = tableCells(in: lines[index]),
              let delimiter = tableCells(in: lines[index + 1]),
              !header.isEmpty,
              header.count == delimiter.count
        else { return nil }

        let alignments = delimiter.compactMap(tableAlignment)
        guard alignments.count == delimiter.count else { return nil }

        var rawRows = [header]
        var nextIndex = index + 2
        while nextIndex < lines.count,
              !lines[nextIndex].trimmingCharacters(in: .whitespaces).isEmpty,
              let row = tableCells(in: lines[nextIndex]),
              row.count == header.count {
            rawRows.append(row)
            nextIndex += 1
        }

        var rows: [[AttributedString]] = []
        for row in rawRows {
            var parsedRow: [AttributedString] = []
            for cell in row {
                guard var content = try? inlineAttributedMarkdown(cell) else { return nil }
                content.imageURL = nil
                parsedRow.append(content)
            }
            rows.append(parsedRow)
        }

        return TableCandidate(
            table: Table(alignments: alignments, rows: rows),
            lineCount: nextIndex - index
        )
    }

    private static func tableAlignment(_ delimiter: String) -> Table.Alignment? {
        let value = delimiter.trimmingCharacters(in: .whitespaces)
        let leading = value.hasPrefix(":")
        let trailing = value.hasSuffix(":")
        let hyphens = value.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        guard hyphens.count >= 3, hyphens.allSatisfy({ $0 == "-" }) else { return nil }
        if leading && trailing { return .center }
        if trailing { return .trailing }
        return .leading
    }

    private static func tableCells(in line: String) -> [String]? {
        var cells: [String] = []
        var current = ""
        var index = line.startIndex
        var codeDelimiterLength: Int?
        var foundSeparator = false

        while index < line.endIndex {
            let character = line[index]
            if character == "\\" {
                current.append(character)
                index = line.index(after: index)
                if index < line.endIndex {
                    current.append(line[index])
                    index = line.index(after: index)
                }
                continue
            }
            if character == "`" {
                var runEnd = index
                var runLength = 0
                while runEnd < line.endIndex, line[runEnd] == "`" {
                    runLength += 1
                    runEnd = line.index(after: runEnd)
                }
                current.append(contentsOf: line[index..<runEnd])
                if let activeDelimiterLength = codeDelimiterLength {
                    if activeDelimiterLength == runLength { codeDelimiterLength = nil }
                } else {
                    codeDelimiterLength = runLength
                }
                index = runEnd
                continue
            }
            if character == "|", codeDelimiterLength == nil {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
                foundSeparator = true
            } else {
                current.append(character)
            }
            index = line.index(after: index)
        }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        guard foundSeparator else { return nil }

        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        if trimmedLine.hasPrefix("|"), cells.first?.isEmpty == true { cells.removeFirst() }
        if trimmedLine.hasSuffix("|"), cells.last?.isEmpty == true { cells.removeLast() }
        return cells
    }

    private static func fullAttributedMarkdown(_ markdown: String) throws -> AttributedString {
        let normalized = normalizingStrongLinkLabels(in: markdown)
        let parsed = try AttributedString(
            markdown: normalized,
            options: .init(
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        )
        guard normalized != markdown else { return parsed }

        let original = try AttributedString(
            markdown: markdown,
            options: .init(
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        )
        return parsed.characters.elementsEqual(original.characters) ? parsed : original
    }

    private static func inlineAttributedMarkdown(_ markdown: String) throws -> AttributedString {
        let normalized = normalizingStrongLinkLabels(in: markdown)
        let parsed = try AttributedString(
            markdown: normalized,
            options: .init(
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        )
        guard normalized != markdown else { return parsed }

        let original = try AttributedString(
            markdown: markdown,
            options: .init(
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        )
        return parsed.characters.elementsEqual(original.characters) ? parsed : original
    }

    private static func normalizingStrongLinkLabels(in markdown: String) -> String {
        let pattern = #"\[(\*\*\*|___|\*\*|__)([^\]\n]+)\1\]\(([^)\n]+)\)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return markdown }
        let range = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
        return expression.stringByReplacingMatches(
            in: markdown,
            range: range,
            withTemplate: "$1[$2]($3)$1"
        )
    }

    private struct BlockDescriptor {
        let identity: Int
        let kind: Kind
    }

    private static func descriptor(for intent: PresentationIntent?) -> BlockDescriptor? {
        guard let components = intent?.components, !components.isEmpty else { return nil }

        for component in components {
            switch component.kind {
            case let .header(level):
                return BlockDescriptor(identity: component.identity, kind: .heading(level: level))
            case let .codeBlock(languageHint):
                return BlockDescriptor(identity: component.identity, kind: .codeBlock(language: languageHint))
            case .thematicBreak:
                return BlockDescriptor(identity: component.identity, kind: .thematicBreak)
            default:
                continue
            }
        }

        if let item = components.first(where: {
            if case .listItem = $0.kind { return true }
            return false
        }) {
            let depth = max(
                1,
                components.filter {
                    if case .orderedList = $0.kind { return true }
                    if case .unorderedList = $0.kind { return true }
                    return false
                }.count
            )
            let usesOrderedMarker = components.first(where: {
                if case .orderedList = $0.kind { return true }
                if case .unorderedList = $0.kind { return true }
                return false
            }).map {
                if case .orderedList = $0.kind { return true }
                return false
            } ?? false

            if case let .listItem(ordinal) = item.kind {
                let kind: Kind = usesOrderedMarker
                    ? .orderedItem(ordinal: ordinal, depth: depth)
                    : .unorderedItem(depth: depth)
                return BlockDescriptor(identity: item.identity, kind: kind)
            }
        }

        let paragraph = components.first(where: {
            if case .paragraph = $0.kind { return true }
            return false
        })
        guard let paragraph else { return nil }
        let isQuote = components.contains {
            if case .blockQuote = $0.kind { return true }
            return false
        }
        return BlockDescriptor(
            identity: paragraph.identity,
            kind: isQuote ? .blockQuote : .paragraph
        )
    }

}

extension CardSession {
    var shouldRenderMarkdownProjection: Bool {
        MarkdownProjectionInput(session: self) != nil
    }

    var shouldRenderCompletedMarkdown: Bool {
        guard sourceContent.format == .semanticMarkdown else { return false }
        if case .completed = state { return true }
        return false
    }
}

struct MarkdownResultText: View {
    let projection: MarkdownProjectionSnapshot

    var body: some View {
        MarkdownResultSelectableText(
            attributedDocument: projection.attributedDocument,
            accessibilityText: projection.document.plainText
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension String {
    func removingTrailingLineBreaks() -> String {
        var result = self
        while result.last == "\n" || result.last == "\r" { result.removeLast() }
        return result
    }
}
