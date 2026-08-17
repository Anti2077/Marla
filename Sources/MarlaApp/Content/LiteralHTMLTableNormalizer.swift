import Foundation

enum LiteralHTMLTableNormalizer {
    private static let tableExpression = try! NSRegularExpression(
        pattern: #"(?is)<table(?:\s[^>]*)?>.*?</table\s*>"#
    )
    private static let placeholderExpression = try! NSRegularExpression(
        pattern: #"\$\{[A-Za-z_][A-Za-z0-9_.:-]*\}\$?|\{\{[A-Za-z_][A-Za-z0-9_.:-]*\}\}"#
    )
    private static let allowedTableTags: Set<String> = [
        "a", "b", "br", "code", "em", "i", "span", "strong",
        "table", "tbody", "td", "tfoot", "th", "thead", "tr"
    ]
    private static let tableSectionTags: Set<String> = ["thead", "tbody", "tfoot"]
    private static let tableCellTags: Set<String> = ["th", "td"]
    private static let inlineCellTags: Set<String> = [
        "a", "b", "br", "code", "em", "i", "span", "strong",
    ]

    static func markdown(from text: String) -> String? {
        let source = text as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        let matches = tableExpression.matches(in: text, range: fullRange)
        guard !matches.isEmpty,
              tagCount("table", closing: false, in: text) == matches.count,
              tagCount("table", closing: true, in: text) == matches.count
        else { return nil }

        var renderedTables: [(range: NSRange, markdown: String)] = []
        for match in matches {
            guard !isInsideMarkdownCode(match.range, in: source),
                  let markdown = tableMarkdown(from: source.substring(with: match.range))
            else { return nil }
            renderedTables.append((match.range, markdown))
        }

        var output = ""
        var cursor = 0
        for table in renderedTables {
            let prefixRange = NSRange(location: cursor, length: table.range.location - cursor)
            output += escapePlainText(source.substring(with: prefixRange))
            output += "\n\n\(table.markdown)\n\n"
            cursor = NSMaxRange(table.range)
        }
        output += escapePlainText(
            source.substring(with: NSRange(location: cursor, length: source.length - cursor))
        )
        let normalized = output
            .replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func tableMarkdown(from fragment: String) -> String? {
        guard tagsAreBalanced(in: fragment),
              let document = try? XMLDocument(data: Data(fragment.utf8), options: [.documentTidyHTML]),
              let root = document.rootElement()
        else { return nil }

        let tables = ((try? root.nodes(forXPath: ".//table")) ?? []).compactMap { $0 as? XMLElement }
        guard tables.count == 1, let table = tables.first else { return nil }
        let documentElements = [root] + descendantElements(of: root)
        let permittedDocumentTags = allowedTableTags.union(["html", "head", "title", "body"])
        guard documentElements.allSatisfy({ element in
            permittedDocumentTags.contains(element.name?.lowercased() ?? "")
        }) else { return nil }

        let elements = [table] + descendantElements(of: table)
        guard elements.allSatisfy(isAllowedTableElement),
              hasOnlySimpleTableStructure(table),
              collapsedWhitespace(root.stringValue ?? "") == collapsedWhitespace(table.stringValue ?? "")
        else { return nil }

        let rows = elements.filter { $0.name?.lowercased() == "tr" }
        guard !rows.isEmpty else { return nil }
        var parsedRows: [[String]] = []
        var columnCount: Int?
        var hasVisibleCell = false

        for row in rows {
            let cells = (row.children ?? []).compactMap { child -> XMLElement? in
                guard let element = child as? XMLElement,
                      ["th", "td"].contains(element.name?.lowercased() ?? "")
                else { return nil }
                return element
            }
            guard !cells.isEmpty,
                  columnCount.map({ $0 == cells.count }) ?? true
            else { return nil }
            columnCount = cells.count

            parsedRows.append(cells.map { cell in
                let visible = collapsedWhitespace(cell.stringValue ?? "")
                hasVisibleCell = hasVisibleCell || !visible.isEmpty
                return escapeTableCell(visible)
            })
        }

        guard hasVisibleCell, let columnCount, columnCount > 0 else { return nil }
        let header = "| \(parsedRows[0].joined(separator: " | ")) |"
        let delimiter = "| \(Array(repeating: "---", count: columnCount).joined(separator: " | ")) |"
        let body = parsedRows.dropFirst().map { "| \($0.joined(separator: " | ")) |" }
        return ([header, delimiter] + body).joined(separator: "\n")
    }

    private static func tagsAreBalanced(in fragment: String) -> Bool {
        for tag in ["table", "tr", "th", "td"] {
            let openings = tagCount(tag, closing: false, in: fragment)
            let closings = tagCount(tag, closing: true, in: fragment)
            if openings != closings { return false }
        }
        return tagCount("table", closing: false, in: fragment) == 1
            && tagCount("tr", closing: false, in: fragment) > 0
            && tagCount("th", closing: false, in: fragment)
                + tagCount("td", closing: false, in: fragment) > 0
    }

    private static func tagCount(_ tag: String, closing: Bool, in text: String) -> Int {
        let prefix = closing ? #"</"# : #"<"#
        let pattern = #"(?i)"# + prefix + NSRegularExpression.escapedPattern(for: tag)
            + (closing ? #"\s*>"# : #"(?:\s[^>]*)?>"#)
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return 0 }
        return expression.numberOfMatches(
            in: text,
            range: NSRange(location: 0, length: (text as NSString).length)
        )
    }

    private static func descendantElements(of element: XMLElement) -> [XMLElement] {
        (element.children ?? []).flatMap { child -> [XMLElement] in
            guard let child = child as? XMLElement else { return [] }
            return [child] + descendantElements(of: child)
        }
    }

    private static func isAllowedTableElement(_ element: XMLElement) -> Bool {
        let name = element.name?.lowercased() ?? ""
        guard allowedTableTags.contains(name),
              element.attribute(forName: "hidden") == nil,
              element.attribute(forName: "style") == nil,
              element.attribute(forName: "aria-hidden") == nil,
              element.attribute(forName: "rowspan") == nil,
              element.attribute(forName: "colspan") == nil
        else { return false }
        return true
    }

    private static func hasOnlySimpleTableStructure(_ table: XMLElement) -> Bool {
        children(of: table, allowElementsNamed: tableSectionTags.union(["tr"])) { child in
            let name = child.name?.lowercased() ?? ""
            if tableSectionTags.contains(name) {
                return children(of: child, allowElementsNamed: ["tr"]) { row in
                    hasOnlySimpleRowStructure(row)
                }
            }
            return hasOnlySimpleRowStructure(child)
        }
    }

    private static func hasOnlySimpleRowStructure(_ row: XMLElement) -> Bool {
        children(of: row, allowElementsNamed: tableCellTags) { cell in
            hasOnlyInlineCellContent(cell)
        }
    }

    private static func hasOnlyInlineCellContent(_ element: XMLElement) -> Bool {
        children(of: element, allowElementsNamed: inlineCellTags) { child in
            hasOnlyInlineCellContent(child)
        }
    }

    private static func children(
        of element: XMLElement,
        allowElementsNamed allowedNames: Set<String>,
        validateElement: (XMLElement) -> Bool
    ) -> Bool {
        (element.children ?? []).allSatisfy { child in
            if child.kind == .text {
                return child.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
                    || element.name?.lowercased() == "td"
                    || element.name?.lowercased() == "th"
                    || inlineCellTags.contains(element.name?.lowercased() ?? "")
            }
            if child.kind == .comment { return true }
            guard let child = child as? XMLElement,
                  allowedNames.contains(child.name?.lowercased() ?? "")
            else { return false }
            return validateElement(child)
        }
    }

    private static func isInsideMarkdownCode(_ range: NSRange, in source: NSString) -> Bool {
        let prefix = source.substring(to: range.location)
        if hasOpenMarkdownFence(in: prefix) { return true }

        let lineRange = source.lineRange(for: NSRange(location: range.location, length: 0))
        let linePrefix = source.substring(
            with: NSRange(location: lineRange.location, length: range.location - lineRange.location)
        )
        return hasOpenInlineCodeSpan(in: linePrefix as NSString)
    }

    private static func hasOpenMarkdownFence(in prefix: String) -> Bool {
        var openFence: (marker: Character, length: Int)?
        for line in prefix.split(separator: "\n", omittingEmptySubsequences: false) {
            let characters = Array(line)
            var markerIndex = 0
            while markerIndex < min(3, characters.count), characters[markerIndex] == " " {
                markerIndex += 1
            }
            guard markerIndex < characters.count,
                  characters[markerIndex] == "`" || characters[markerIndex] == "~"
            else { continue }

            let marker = characters[markerIndex]
            var runEnd = markerIndex
            while runEnd < characters.count, characters[runEnd] == marker { runEnd += 1 }
            let runLength = runEnd - markerIndex
            guard runLength >= 3 else { continue }

            if let current = openFence {
                let remainderIsWhitespace = characters[runEnd...].allSatisfy(\.isWhitespace)
                if marker == current.marker,
                   runLength >= current.length,
                   remainderIsWhitespace {
                    openFence = nil
                }
            } else {
                openFence = (marker, runLength)
            }
        }
        return openFence != nil
    }

    private static func hasOpenInlineCodeSpan(in prefix: NSString) -> Bool {
        var openRunLength: Int?
        var index = 0
        while index < prefix.length {
            guard prefix.character(at: index) == 0x60, !isEscapedBacktick(at: index, in: prefix) else {
                index += 1
                continue
            }
            var end = index + 1
            while end < prefix.length, prefix.character(at: end) == 0x60 {
                end += 1
            }
            let runLength = end - index
            if let currentRunLength = openRunLength {
                if runLength == currentRunLength { openRunLength = nil }
            } else {
                openRunLength = runLength
            }
            index = end
        }
        return openRunLength != nil
    }

    private static func isEscapedBacktick(at index: Int, in text: NSString) -> Bool {
        var slashCount = 0
        var cursor = index
        while cursor > 0, text.character(at: cursor - 1) == 0x5C {
            slashCount += 1
            cursor -= 1
        }
        return !slashCount.isMultiple(of: 2)
    }

    private static func escapeTableCell(_ text: String) -> String {
        let source = text as NSString
        let matches = placeholderExpression.matches(
            in: text,
            range: NSRange(location: 0, length: source.length)
        )
        var output = ""
        var cursor = 0
        for match in matches {
            output += escapeMarkdown(source.substring(
                with: NSRange(location: cursor, length: match.range.location - cursor)
            ))
            output += source.substring(with: match.range)
            cursor = NSMaxRange(match.range)
        }
        output += escapeMarkdown(source.substring(from: cursor))
        return output
    }

    private static func escapePlainText(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { escapeMarkdown(String($0)) }
            .joined(separator: "\n")
    }

    private static func escapeMarkdown(_ text: String) -> String {
        let escapable: Set<Character> = ["\\", "`", "*", "_", "{", "}", "[", "]", "<", ">", "|"]
        return text.reduce(into: "") { result, character in
            if escapable.contains(character) { result.append("\\") }
            result.append(character)
        }
    }

    private static func collapsedWhitespace(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
