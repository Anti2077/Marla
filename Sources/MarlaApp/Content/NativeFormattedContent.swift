import AppKit
import ApplicationServices
import Foundation
import MarlaCore

@MainActor
enum NativeFormattedContentNormalizer {
    private struct Conversion {
        let markdown: String
        let visibleText: String
        let hasStructure: Bool
    }

    private struct BlockDescriptor {
        enum Kind {
            case heading(Int)
            case paragraph
            case unorderedItem(Int)
            case orderedItem(Int, Int)
            case blockQuote
            case codeBlock(String?)
            case thematicBreak
        }

        let identity: Int
        let kind: Kind
    }

    private static let markdownTypes = [
        NSPasteboard.PasteboardType("net.daringfireball.markdown"),
        NSPasteboard.PasteboardType("public.markdown"),
        NSPasteboard.PasteboardType("org.commonmark.markdown")
    ]

    private static let discardedHTMLTags: Set<String> = [
        "applet", "audio", "canvas", "embed", "head", "iframe", "link", "meta",
        "noscript", "object", "picture", "script", "source", "style", "svg",
        "template", "video"
    ]

    private static let axFontKey = NSAttributedString.Key("AXFont")
    private static let axLinkKey = NSAttributedString.Key("AXLink")
    private static let axStrikethroughKey = NSAttributedString.Key("AXStrikethrough")
    private static let axListPrefixKey = NSAttributedString.Key("AXListItemPrefix")
    private static let axListIndexKey = NSAttributedString.Key("AXListItemIndex")
    private static let axListLevelKey = NSAttributedString.Key("AXListItemLevel")

    static func content(from pasteboard: NSPasteboard) -> TranslationContent? {
        content(from: pasteboard.pasteboardItems ?? [])
    }

    static func content(from items: [NSPasteboardItem]) -> TranslationContent? {
        let contents = items.compactMap(content(from:))
        guard !contents.isEmpty else { return nil }

        if contents.allSatisfy({ $0.format == .plainText }) {
            return .plainText(contents.map(\.text).joined(separator: "\n\n"))
        }

        let markdown = contents.map { content in
            content.format == .semanticMarkdown ? content.text : escapedPlainTextBlock(content.text)
        }.joined(separator: "\n\n")
        return .semanticMarkdown(markdown)
    }

    static func content(from value: CFTypeRef?) -> TranslationContent? {
        if let attributed = value as? NSAttributedString {
            return content(from: attributed)
        }
        if let string = value as? String {
            return content(fromPlainText: string)
        }
        return nil
    }

    static func content(from attributed: NSAttributedString) -> TranslationContent? {
        let visibleText = attributed.string
        guard !visibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let conversion = conversion(from: attributed)
        guard conversion.hasStructure,
              visibleTextMatches(conversion.visibleText, visibleText),
              !conversion.markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return content(fromPlainText: visibleText)
        }
        return .semanticMarkdown(conversion.markdown)
    }

    static func visibleTextMatches(_ lhs: String, _ rhs: String) -> Bool {
        normalizedVisibleText(lhs) == normalizedVisibleText(rhs)
    }

    static func content(_ content: TranslationContent, representsVisibleText text: String) -> Bool {
        let visibleText: String
        switch content.format {
        case .plainText:
            visibleText = content.text
        case .semanticMarkdown:
            guard let document = MarkdownResultDocument.parse(content.text) else { return false }
            visibleText = document.plainText
        }
        return visibleTextMatches(visibleText, text)
    }

    private static func content(from item: NSPasteboardItem) -> TranslationContent? {
        let plainText = item.string(forType: .string)

        for type in markdownTypes {
            if let markdown = item.string(forType: type),
               !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let content = TranslationContent.semanticMarkdown(markdown)
                if let plainText,
                   !self.content(content, representsVisibleText: plainText) {
                    return .plainText(plainText)
                }
                return content
            }
        }

        if let data = item.data(forType: .html),
           let conversion = htmlConversion(from: data),
           plainText.map({ visibleTextMatches(conversion.visibleText, $0) }) != false {
            return conversion.hasStructure
                ? .semanticMarkdown(conversion.markdown)
                : .plainText(plainText ?? conversion.visibleText)
        }

        for (type, documentType) in [
            (NSPasteboard.PasteboardType.rtfd, NSAttributedString.DocumentType.rtfd),
            (NSPasteboard.PasteboardType.rtf, NSAttributedString.DocumentType.rtf)
        ] {
            guard let data = item.data(forType: type),
                  let attributed = try? NSAttributedString(
                      data: data,
                      options: [.documentType: documentType],
                      documentAttributes: nil
                  )
            else { continue }
            let conversion = conversion(from: attributed)
            guard plainText.map({ visibleTextMatches(conversion.visibleText, $0) }) != false else { continue }
            if conversion.hasStructure {
                return .semanticMarkdown(conversion.markdown)
            }
        }

        guard let plainText,
              !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return content(fromPlainText: plainText)
    }

    private static func content(fromPlainText text: String) -> TranslationContent? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        if let markdown = LiteralHTMLTableNormalizer.markdown(from: text) {
            return .semanticMarkdown(markdown)
        }
        return .plainText(text)
    }

    private static func htmlConversion(from data: Data) -> Conversion? {
        let document = String(data: data, encoding: .utf8)
            .flatMap { try? XMLDocument(xmlString: $0, options: [.documentTidyHTML]) }
            ?? (try? XMLDocument(data: data, options: [.documentTidyHTML]))
        guard let document,
              let root = document.rootElement()
        else { return nil }

        let markdown = cleanMarkdown(renderHTML(root, listDepth: 0, inPreformattedBlock: false))
        let visibleText = cleanVisibleText(renderVisibleHTML(root, inPreformattedBlock: false))
        guard !visibleText.isEmpty else { return nil }
        return Conversion(
            markdown: markdown,
            visibleText: visibleText,
            hasStructure: htmlContainsSemanticStructure(root)
        )
    }

    private static func renderHTML(
        _ node: XMLNode,
        listDepth: Int,
        inPreformattedBlock: Bool
    ) -> String {
        if node.kind == .text {
            let text = node.stringValue ?? ""
            return inPreformattedBlock ? text : escapedHTMLText(text)
        }
        guard let element = node as? XMLElement else {
            return (node.children ?? []).map {
                renderHTML($0, listDepth: listDepth, inPreformattedBlock: inPreformattedBlock)
            }.joined()
        }

        let name = element.name?.lowercased() ?? ""
        guard !isDiscarded(element, name: name) else { return "" }
        let children = element.children ?? []
        let inner = children.map {
            renderHTML($0, listDepth: listDepth, inPreformattedBlock: inPreformattedBlock)
        }.joined()

        switch name {
        case "h1", "h2", "h3", "h4", "h5", "h6":
            let level = Int(name.dropFirst()) ?? 1
            return "\n\n\(String(repeating: "#", count: level)) \(trimInline(inner))\n\n"
        case "p", "article", "aside", "div", "footer", "header", "main", "section":
            return "\n\n\(trimInline(inner))\n\n"
        case "br":
            return "\n"
        case "strong", "b":
            return wrap(trimInline(inner), marker: "**")
        case "em", "i", "cite":
            return wrap(trimInline(inner), marker: "*")
        case "del", "s", "strike":
            return wrap(trimInline(inner), marker: "~~")
        case "code" where !inPreformattedBlock:
            return inlineCode(element.stringValue ?? "")
        case "pre":
            return "\n\n\(fencedCode(element.stringValue ?? ""))\n\n"
        case "blockquote":
            let quote = cleanMarkdown(inner)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { "> \($0)" }
                .joined(separator: "\n")
            return "\n\n\(quote)\n\n"
        case "a":
            let label = trimInline(inner)
            guard let href = safeLink(element.attribute(forName: "href")?.stringValue),
                  !label.isEmpty
            else { return label }
            return "[\(label)](\(href))"
        case "img":
            return ""
        case "ul":
            return renderList(element, ordered: false, depth: listDepth + 1)
        case "ol":
            return renderList(element, ordered: true, depth: listDepth + 1)
        case "table":
            return renderTable(element)
        case "hr":
            return "\n\n---\n\n"
        default:
            return inner
        }
    }

    private static func renderList(_ element: XMLElement, ordered: Bool, depth: Int) -> String {
        let items = (element.children ?? []).compactMap { child -> XMLElement? in
            guard let item = child as? XMLElement, item.name?.lowercased() == "li" else { return nil }
            return item
        }
        let rendered = items.enumerated().map { index, item -> String in
            let children = item.children ?? []
            let inline = children.filter { child in
                guard let element = child as? XMLElement else { return true }
                let name = element.name?.lowercased()
                return name != "ul" && name != "ol"
            }.map { renderHTML($0, listDepth: depth, inPreformattedBlock: false) }.joined()
            let nested = children.compactMap { child -> String? in
                guard let element = child as? XMLElement else { return nil }
                switch element.name?.lowercased() {
                case "ul": return renderList(element, ordered: false, depth: depth + 1)
                case "ol": return renderList(element, ordered: true, depth: depth + 1)
                default: return nil
                }
            }.joined()
            let marker = ordered ? "\(index + 1)." : "-"
            let indentation = String(repeating: "  ", count: max(0, depth - 1))
            return "\(indentation)\(marker) \(trimInline(inline))\(nested)"
        }.joined(separator: "\n")
        return rendered.isEmpty ? "" : "\n\n\(rendered)\n\n"
    }

    private static func renderTable(_ element: XMLElement) -> String {
        let rows = ((try? element.nodes(forXPath: ".//tr")) ?? []).compactMap { $0 as? XMLElement }
        let cells = rows.map { row in
            (row.children ?? []).compactMap { child -> String? in
                guard let cell = child as? XMLElement,
                      ["th", "td"].contains(cell.name?.lowercased() ?? "")
                else { return nil }
                let value = trimInline((cell.children ?? []).map {
                    renderHTML($0, listDepth: 0, inPreformattedBlock: false)
                }.joined())
                return value.replacingOccurrences(of: "|", with: "\\|")
            }
        }.filter { !$0.isEmpty }
        guard let first = cells.first else { return "" }
        let columnCount = cells.map(\.count).max() ?? first.count
        func padded(_ row: [String]) -> [String] {
            row + Array(repeating: "", count: max(0, columnCount - row.count))
        }
        let header = "| \(padded(first).joined(separator: " | ")) |"
        let separator = "| \(Array(repeating: "---", count: columnCount).joined(separator: " | ")) |"
        let body = cells.dropFirst().map { "| \(padded($0).joined(separator: " | ")) |" }
        return "\n\n\(([header, separator] + body).joined(separator: "\n"))\n\n"
    }

    private static func renderVisibleHTML(_ node: XMLNode, inPreformattedBlock: Bool) -> String {
        if node.kind == .text {
            let value = node.stringValue ?? ""
            return inPreformattedBlock ? value : collapsedHTMLTextPreservingBoundaries(value)
        }
        guard let element = node as? XMLElement else {
            return (node.children ?? []).map {
                renderVisibleHTML($0, inPreformattedBlock: inPreformattedBlock)
            }.joined()
        }
        let name = element.name?.lowercased() ?? ""
        guard !isDiscarded(element, name: name) else { return "" }
        if name == "img" {
            return ""
        }
        if name == "br" { return "\n" }
        let isPreformatted = inPreformattedBlock || name == "pre"
        let inner = (element.children ?? []).map {
            renderVisibleHTML($0, inPreformattedBlock: isPreformatted)
        }.joined()
        let blockTags: Set<String> = [
            "article", "aside", "blockquote", "div", "footer", "h1", "h2", "h3",
            "h4", "h5", "h6", "header", "hr", "li", "main", "ol", "p", "pre",
            "section", "table", "td", "th", "tr", "ul"
        ]
        return blockTags.contains(name) ? "\n\(inner)\n" : inner
    }

    private static func htmlContainsSemanticStructure(_ element: XMLElement) -> Bool {
        let semanticTags: Set<String> = [
            "a", "b", "blockquote", "code", "del", "em", "h1", "h2", "h3", "h4",
            "h5", "h6", "hr", "i", "ol", "pre", "s", "strike", "strong", "table", "ul"
        ]
        if semanticTags.contains(element.name?.lowercased() ?? ""),
           !isDiscarded(element, name: element.name?.lowercased() ?? "") {
            return true
        }
        return (element.children ?? []).contains { child in
            guard let child = child as? XMLElement else { return false }
            return htmlContainsSemanticStructure(child)
        }
    }

    private static func isDiscarded(_ element: XMLElement, name: String) -> Bool {
        if discardedHTMLTags.contains(name) { return true }
        if element.attribute(forName: "hidden") != nil { return true }
        if element.attribute(forName: "aria-hidden")?.stringValue?.lowercased() == "true" { return true }
        let declarations = inlineStyleDeclarations(element.attribute(forName: "style")?.stringValue)
        return declarations["display"] == "none"
            || ["hidden", "collapse"].contains(declarations["visibility"])
            || declarations["content-visibility"] == "hidden"
            || declarations["opacity"]?.trimmingCharacters(in: CharacterSet(charactersIn: "0.")) == ""
    }

    private static func inlineStyleDeclarations(_ style: String?) -> [String: String] {
        guard let style else { return [:] }
        return style.split(separator: ";").reduce(into: [:]) { declarations, component in
            let parts = component.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return }
            let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = parts[1]
                .replacingOccurrences(of: #"\s*!important\s*$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            declarations[name] = value
        }
    }

    private static func conversion(from attributed: NSAttributedString) -> Conversion {
        let foundationAttributed = AttributedString(attributed)
        if foundationAttributed.runs.contains(where: { $0.presentationIntent != nil }),
           let markdown = markdownFromPresentationIntents(foundationAttributed) {
            return Conversion(
                markdown: cleanMarkdown(markdown),
                visibleText: attributed.string,
                hasStructure: true
            )
        }
        return markdownFromAppKitAttributes(attributed)
    }

    private static func markdownFromPresentationIntents(_ attributed: AttributedString) -> String? {
        var blocks: [(descriptor: BlockDescriptor, content: String)] = []
        for run in attributed.runs {
            guard let descriptor = blockDescriptor(for: run.presentationIntent) else { continue }
            let text = String(attributed[run.range].characters)
            let fragment = styledInlineText(
                text,
                intent: run.inlinePresentationIntent,
                link: run.link
            )
            if blocks.last?.descriptor.identity == descriptor.identity {
                blocks[blocks.count - 1].content += fragment
            } else {
                blocks.append((descriptor, fragment))
            }
        }
        guard !blocks.isEmpty else { return nil }
        return blocks.map { block in
            let content = trimInline(block.content)
            switch block.descriptor.kind {
            case let .heading(level): return "\(String(repeating: "#", count: level)) \(content)"
            case .paragraph: return content
            case let .unorderedItem(depth):
                return "\(String(repeating: "  ", count: max(0, depth - 1)))- \(content)"
            case let .orderedItem(ordinal, depth):
                return "\(String(repeating: "  ", count: max(0, depth - 1)))\(ordinal). \(content)"
            case .blockQuote:
                return content.split(separator: "\n", omittingEmptySubsequences: false)
                    .map { "> \($0)" }.joined(separator: "\n")
            case let .codeBlock(language): return fencedCode(content, language: language)
            case .thematicBreak: return "---"
            }
        }.joined(separator: "\n\n")
    }

    private static func blockDescriptor(for intent: PresentationIntent?) -> BlockDescriptor? {
        guard let components = intent?.components, !components.isEmpty else { return nil }
        for component in components {
            switch component.kind {
            case let .header(level):
                return BlockDescriptor(identity: component.identity, kind: .heading(level))
            case let .codeBlock(languageHint):
                return BlockDescriptor(identity: component.identity, kind: .codeBlock(languageHint))
            case .thematicBreak:
                return BlockDescriptor(identity: component.identity, kind: .thematicBreak)
            default:
                break
            }
        }
        if let item = components.first(where: {
            if case .listItem = $0.kind { return true }
            return false
        }), case let .listItem(ordinal) = item.kind {
            let depth = max(1, components.filter {
                if case .orderedList = $0.kind { return true }
                if case .unorderedList = $0.kind { return true }
                return false
            }.count)
            let ordered = components.contains {
                if case .orderedList = $0.kind { return true }
                return false
            }
            return BlockDescriptor(
                identity: item.identity,
                kind: ordered ? .orderedItem(ordinal, depth) : .unorderedItem(depth)
            )
        }
        guard let paragraph = components.first(where: {
            if case .paragraph = $0.kind { return true }
            return false
        }) else { return nil }
        let quoted = components.contains {
            if case .blockQuote = $0.kind { return true }
            return false
        }
        return BlockDescriptor(identity: paragraph.identity, kind: quoted ? .blockQuote : .paragraph)
    }

    private static func markdownFromAppKitAttributes(_ attributed: NSAttributedString) -> Conversion {
        let string = attributed.string as NSString
        var location = 0
        var blocks: [String] = []
        var hasStructure = false

        while location < attributed.length {
            var start = 0
            var end = 0
            var contentsEnd = 0
            string.getParagraphStart(&start, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: location, length: 0))
            let range = NSRange(location: start, length: max(0, contentsEnd - start))
            var inline = ""
            attributed.enumerateAttributes(in: range) { attributes, runRange, _ in
                let raw = string.substring(with: runRange)
                var rendered = escapeMarkdown(raw)
                var usesCodeStyle = false
                var usesItalicStyle = false
                var usesBoldStyle = false
                if let font = attributes[.font] as? NSFont {
                    let traits = NSFontManager.shared.traits(of: font)
                    if font.isFixedPitch {
                        usesCodeStyle = true
                    } else {
                        usesItalicStyle = traits.contains(.italicFontMask)
                        usesBoldStyle = traits.contains(.boldFontMask)
                    }
                }
                if let font = attributes[axFontKey] as? [AnyHashable: Any] {
                    let names = [
                        font["AXFontName"] as? String,
                        font["AXFontFamily"] as? String,
                        font["AXVisibleName"] as? String
                    ].compactMap { $0 }.joined(separator: " ").lowercased()
                    usesCodeStyle = usesCodeStyle
                        || names.contains("mono")
                        || names.contains("menlo")
                        || names.contains("courier")
                    usesItalicStyle = usesItalicStyle
                        || names.contains("italic")
                        || names.contains("oblique")
                    usesBoldStyle = usesBoldStyle
                        || names.contains("bold")
                        || names.contains("semibold")
                }
                if usesCodeStyle {
                    rendered = inlineCode(raw)
                    hasStructure = true
                } else {
                    if usesItalicStyle {
                        rendered = wrap(rendered, marker: "*")
                        hasStructure = true
                    }
                    if usesBoldStyle {
                        rendered = wrap(rendered, marker: "**")
                        hasStructure = true
                    }
                }
                if (attributes[axStrikethroughKey] as? NSNumber)?.boolValue == true {
                    rendered = wrap(rendered, marker: "~~")
                    hasStructure = true
                }
                if let link = safeLink(attributes[.link]) ?? safeLink(attributes[axLinkKey]) {
                    rendered = "[\(rendered)](\(link))"
                    hasStructure = true
                }
                inline += rendered
            }

            if range.length > 0 {
                let style = attributed.attribute(.paragraphStyle, at: range.location, effectiveRange: nil)
                    as? NSParagraphStyle
                let axPrefixValue = attributed.attribute(axListPrefixKey, at: range.location, effectiveRange: nil)
                let axPrefix = (axPrefixValue as? NSAttributedString)?.string
                    ?? (axPrefixValue as? String)
                if let style, !style.textLists.isEmpty {
                    let depth = style.textLists.count
                    let marker = style.textLists.last?.marker(forItemNumber: blocks.count + 1) ?? "-"
                    let ordered = marker.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) }
                    let prefix = ordered ? "1." : "-"
                    inline = "\(String(repeating: "  ", count: max(0, depth - 1)))\(prefix) \(strippingListMarker(inline))"
                    hasStructure = true
                } else if let axPrefix, !axPrefix.isEmpty {
                    let level = (attributed.attribute(axListLevelKey, at: range.location, effectiveRange: nil)
                        as? NSNumber)?.intValue ?? 0
                    let index = (attributed.attribute(axListIndexKey, at: range.location, effectiveRange: nil)
                        as? NSNumber)?.intValue ?? 0
                    let ordered = axPrefix.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) }
                    let prefix = ordered ? "\(index + 1)." : "-"
                    inline = "\(String(repeating: "  ", count: max(0, level)))\(prefix) \(strippingListMarker(inline))"
                    hasStructure = true
                }
            }

            blocks.append(trimInline(inline))
            location = max(end, location + 1)
        }

        return Conversion(
            markdown: cleanMarkdown(blocks.joined(separator: "\n\n")),
            visibleText: attributed.string,
            hasStructure: hasStructure
        )
    }

    private static func styledInlineText(
        _ text: String,
        intent: InlinePresentationIntent?,
        link: URL?
    ) -> String {
        var rendered = escapeMarkdown(text)
        if intent?.contains(.code) == true {
            rendered = inlineCode(text)
        } else {
            if intent?.contains(.emphasized) == true {
                rendered = wrap(rendered, marker: "*")
            }
            if intent?.contains(.stronglyEmphasized) == true {
                rendered = wrap(rendered, marker: "**")
            }
            if intent?.contains(.strikethrough) == true {
                rendered = wrap(rendered, marker: "~~")
            }
        }
        if let link = safeLink(link) {
            rendered = "[\(rendered)](\(link))"
        }
        return rendered
    }

    private static func safeLink(_ value: Any?) -> String? {
        let string: String?
        switch value {
        case let url as URL: string = url.absoluteString
        case let stringValue as String: string = stringValue
        default:
            if let value {
                let reference = value as CFTypeRef
                if CFGetTypeID(reference) == AXUIElementGetTypeID() {
                    var urlValue: CFTypeRef?
                    let result = AXUIElementCopyAttributeValue(
                        reference as! AXUIElement,
                        "AXURL" as CFString,
                        &urlValue
                    )
                    string = result == .success
                        ? (urlValue as? URL)?.absoluteString ?? (urlValue as? String)
                        : nil
                } else {
                    string = nil
                }
            } else {
                string = nil
            }
        }
        guard let string,
              let components = URLComponents(string: string),
              let scheme = components.scheme?.lowercased(),
              ["http", "https", "mailto"].contains(scheme)
        else { return nil }
        return string.replacingOccurrences(of: " ", with: "%20")
            .replacingOccurrences(of: ")", with: "%29")
    }

    private static func escapedHTMLText(_ text: String) -> String {
        let collapsed = collapsedHTMLWhitespace(text)
        let leading = text.first?.isWhitespace == true ? " " : ""
        let trailing = text.last?.isWhitespace == true ? " " : ""
        return leading + escapeMarkdown(collapsed) + trailing
    }

    private static func collapsedHTMLWhitespace(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func collapsedHTMLTextPreservingBoundaries(_ text: String) -> String {
        let collapsed = collapsedHTMLWhitespace(text)
        guard !collapsed.isEmpty else { return text.isEmpty ? "" : " " }
        let leading = text.first?.isWhitespace == true ? " " : ""
        let trailing = text.last?.isWhitespace == true ? " " : ""
        return leading + collapsed + trailing
    }

    private static func escapedPlainTextBlock(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { escapeMarkdown(String($0)) }
            .joined(separator: "\n")
    }

    private static func escapeMarkdown(_ text: String) -> String {
        var result = ""
        let escapable: Set<Character> = ["\\", "`", "*", "_", "{", "}", "[", "]", "<", ">"]
        for character in text {
            if escapable.contains(character) { result.append("\\") }
            result.append(character)
        }
        return result
    }

    private static func wrap(_ content: String, marker: String) -> String {
        guard !content.isEmpty else { return "" }
        let leadingCount = content.prefix { $0.isWhitespace }.count
        let trailingCount = content.reversed().prefix { $0.isWhitespace }.count
        let start = content.index(content.startIndex, offsetBy: leadingCount)
        let end = content.index(content.endIndex, offsetBy: -trailingCount)
        guard start < end else { return content }
        return String(content[..<start]) + marker + String(content[start..<end]) + marker + String(content[end...])
    }

    private static func inlineCode(_ text: String) -> String {
        var delimiterLength = 1
        var runLength = 0
        for character in text {
            if character == "`" {
                runLength += 1
                delimiterLength = max(delimiterLength, runLength + 1)
            } else {
                runLength = 0
            }
        }
        let delimiter = String(repeating: "`", count: delimiterLength)
        let needsPadding = text.first == "`" || text.last == "`"
        return needsPadding ? "\(delimiter) \(text) \(delimiter)" : "\(delimiter)\(text)\(delimiter)"
    }

    private static func fencedCode(_ text: String, language: String? = nil) -> String {
        var fenceLength = 3
        var runLength = 0
        for character in text {
            if character == "`" {
                runLength += 1
                fenceLength = max(fenceLength, runLength + 1)
            } else {
                runLength = 0
            }
        }
        let fence = String(repeating: "`", count: fenceLength)
        let body = text.trimmingCharacters(in: .newlines)
        return "\(fence)\(language ?? "")\n\(body)\n\(fence)"
    }

    private static func trimInline(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func strippingListMarker(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"^\s*(?:[-*+•◦▪]|\d+[.)])\s+"#,
            with: "",
            options: .regularExpression
        )
    }

    private static func cleanMarkdown(_ markdown: String) -> String {
        markdown
            .replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanVisibleText(_ text: String) -> String {
        text.replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedVisibleText(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                String(line).replacingOccurrences(
                    of: #"^\s*(?:[-*+•◦▪]|\d+[.)])\s+"#,
                    with: "",
                    options: .regularExpression
                ).replacingOccurrences(
                    of: #"^\s*(?:\[[ xX]\]|[☐☑☒])\s*"#,
                    with: "",
                    options: .regularExpression
                ).replacingOccurrences(
                    // Web-backed Markdown previews may expose an HTML checkbox
                    // as U+FFFC in the plain Pasteboard projection.
                    of: #"^\s*\uFFFC\s*"#,
                    with: "",
                    options: .regularExpression
                )
            }
            .joined(separator: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
