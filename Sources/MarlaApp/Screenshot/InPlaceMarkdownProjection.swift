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
}

struct InPlaceMarkdownTable: Equatable {
    let alignments: [InPlaceOverlayTextAlignment]
    let rows: [[String]]
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
            rows: table.rows.map { row in
                row.map {
                    String($0.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        )
    }
}
