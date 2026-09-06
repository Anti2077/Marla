import AppKit
import Foundation

enum InPlaceOverlayTextAlignment: Equatable {
    case leading
    case center
    case trailing

    var appKitValue: NSTextAlignment {
        switch self {
        case .leading: .left
        case .center: .center
        case .trailing: .right
        }
    }
}

struct InPlaceOverlayTableCell: Equatable {
    let row: Int
    let column: Int
    let rowCount: Int
    let columnCount: Int
    let alignment: InPlaceOverlayTextAlignment
    let preservesSourceGrid: Bool

    init(
        row: Int,
        column: Int,
        rowCount: Int,
        columnCount: Int,
        alignment: InPlaceOverlayTextAlignment,
        preservesSourceGrid: Bool = true
    ) {
        self.row = row
        self.column = column
        self.rowCount = rowCount
        self.columnCount = columnCount
        self.alignment = alignment
        self.preservesSourceGrid = preservesSourceGrid
    }
}

struct InPlaceMarkdownTable: Equatable {
    let alignments: [InPlaceOverlayTextAlignment]
    let rows: [[AttributedString]]
}

enum InPlaceMarkdownProjection {
    private static let maximumRows = 64
    private static let maximumColumns = 16

    static func visibleText(from markdown: String) -> String {
        MarkdownResultDocument.parse(markdown)?.plainText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func table(from markdown: String) -> InPlaceMarkdownTable? {
        guard let document = MarkdownResultDocument.parse(markdown),
              document.blocks.count == 1,
              case let .table(table) = document.blocks[0].kind,
              let columnCount = table.rows.first?.count,
              !table.rows.isEmpty,
              table.rows.count <= maximumRows,
              columnCount > 0,
              columnCount <= maximumColumns,
              table.alignments.count == columnCount,
              table.rows.allSatisfy({ $0.count == columnCount })
        else { return nil }

        return InPlaceMarkdownTable(
            alignments: table.alignments.map { alignment in
                switch alignment {
                case .leading: .leading
                case .center: .center
                case .trailing: .trailing
                }
            },
            rows: table.rows
        )
    }

    static func containsTableSyntax(_ markdown: String) -> Bool {
        markdown
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .contains(where: isTableRow)
    }

    private static func isTableRow(_ line: String) -> Bool {
        var separatorCount = 0
        var index = line.startIndex
        var codeDelimiterLength: Int?
        while index < line.endIndex {
            let character = line[index]
            if character == "\\" {
                index = line.index(after: index)
                if index < line.endIndex { index = line.index(after: index) }
                continue
            }
            if character == "`" {
                var runEnd = index
                var runLength = 0
                while runEnd < line.endIndex, line[runEnd] == "`" {
                    runLength += 1
                    runEnd = line.index(after: runEnd)
                }
                if let active = codeDelimiterLength {
                    if active == runLength { codeDelimiterLength = nil }
                } else {
                    codeDelimiterLength = runLength
                }
                index = runEnd
                continue
            }
            if character == "|", codeDelimiterLength == nil { separatorCount += 1 }
            index = line.index(after: index)
        }
        return separatorCount >= 2 || (separatorCount == 1 && (line.hasPrefix("|") || line.hasSuffix("|")))
    }
}
