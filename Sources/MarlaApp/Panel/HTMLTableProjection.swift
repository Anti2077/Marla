import Foundation

/// Inert table markup only. No web view, HTML resource loading, or document execution.
/// Rust canonicalizes OCR tables; this validates again after translation/streaming.
enum HTMLTableProjection {
    static func parse(_ source: String) -> MarkdownResultDocument.Table? {
        guard source.utf8.count <= 262_144,
              !source.contains("<!"), !source.contains("<?"),
              source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("<table"),
              source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasSuffix("</table>"),
              let document = try? XMLDocument(xmlString: source, options: [.nodeLoadExternalEntitiesNever]),
              let root = document.rootElement()
        else { return nil }
        let all = [root] + descendants(root)
        let allowed: Set<String> = [
            "html", "head", "body", "table", "thead", "tbody", "tfoot", "tr", "th", "td",
            "br", "b", "strong", "i", "em", "code", "span", "s"
        ]
        guard all.allSatisfy({ element in
            allowed.contains(element.name?.lowercased() ?? "")
                && (element.attributes ?? []).allSatisfy {
                    ["rowspan", "colspan", "class", "border", "scope", "id", "headers"].contains($0.name?.lowercased() ?? "")
                }
        }) else { return nil }
        let tables = all.filter { $0.name?.lowercased() == "table" }
        guard tables.count == 1, let table = tables.first,
              validTableChildren(table)
        else { return nil }
        guard (root.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                == (table.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        let rowNodes = descendants(table).filter { $0.name?.lowercased() == "tr" }
        guard !rowNodes.isEmpty, rowNodes.count <= 128 else { return nil }
        var occupied = Array(repeating: Array(repeating: false, count: 32), count: rowNodes.count)
        var cells: [MarkdownResultDocument.Table.PositionedCell] = []
        var width = 0
        for (r, row) in rowNodes.enumerated() {
            var column = 0
            let children = (row.children ?? []).compactMap { $0 as? XMLElement }
            guard !children.isEmpty,
                  (row.children ?? []).allSatisfy({
                      $0 is XMLElement || ($0.kind == .text && ($0.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                  }) else { return nil }
            for cell in children {
                guard ["th", "td"].contains(cell.name?.lowercased() ?? ""),
                      let rowSpan = span(cell, "rowspan"), let columnSpan = span(cell, "colspan"),
                      descendants(cell).allSatisfy({
                          ["br", "b", "strong", "i", "em", "code", "span", "s"].contains($0.name?.lowercased() ?? "")
                      })
                else { return nil }
                while column < 32 && occupied[r][column] { column += 1 }
                guard column + columnSpan <= 32, r + rowSpan <= rowNodes.count else { return nil }
                for rr in r..<(r + rowSpan) {
                    for cc in column..<(column + columnSpan) {
                        guard !occupied[rr][cc] else { return nil }
                        occupied[rr][cc] = true
                    }
                }
                cells.append(.init(row: r, column: column, rowSpan: rowSpan, columnSpan: columnSpan,
                                   header: cell.name?.lowercased() == "th", content: inline(cell)))
                column += columnSpan
                width = max(width, column)
            }
        }
        guard width > 0, occupied.allSatisfy({ $0.prefix(width).allSatisfy { $0 } }) else { return nil }
        var rows = Array(repeating: Array(repeating: AttributedString(), count: width), count: rowNodes.count)
        for cell in cells { rows[cell.row][cell.column] = cell.content }
        return .init(alignments: Array(repeating: .center, count: width), rows: rows, positionedCells: cells)
    }

    private static func span(_ cell: XMLElement, _ name: String) -> Int? {
        guard let raw = cell.attribute(forName: name)?.stringValue else { return 1 }
        guard let value = Int(raw), (1...32).contains(value) else { return nil }
        return value
    }

    private static func descendants(_ element: XMLElement) -> [XMLElement] {
        (element.children ?? []).flatMap { child -> [XMLElement] in
            guard let child = child as? XMLElement else { return [] }
            return [child] + descendants(child)
        }
    }

    private static func validTableChildren(_ table: XMLElement) -> Bool {
        (table.children ?? []).allSatisfy { node in
            if node.kind == .text { return node.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true }
            guard let element = node as? XMLElement else { return false }
            if element.name?.lowercased() == "tr" { return true }
            guard ["thead", "tbody", "tfoot"].contains(element.name?.lowercased() ?? "") else { return false }
            return validTableChildren(element)
        }
    }

    private static func inline(_ node: XMLNode) -> AttributedString {
        if node.kind == .text { return AttributedString(node.stringValue ?? "") }
        if node.name?.lowercased() == "br" { return AttributedString("\u{2028}") }
        var content = AttributedString()
        for child in node.children ?? [] { content.append(inline(child)) }
        let intent: InlinePresentationIntent? = switch node.name?.lowercased() {
        case "b", "strong": .stronglyEmphasized
        case "i", "em": .emphasized
        case "code": .code
        case "s": .strikethrough
        default: nil
        }
        if let intent {
            for run in content.runs {
                content[run.range].inlinePresentationIntent = (run.inlinePresentationIntent ?? []).union(intent)
            }
        }
        return content
    }
}
