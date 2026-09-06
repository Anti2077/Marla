import AppKit
import Foundation

extension NSAttributedString.Key {
    static let marlaInPlaceCodeBackground = NSAttributedString.Key("com.marla.in-place.code-background")
    static let marlaInPlaceInlineCode = NSAttributedString.Key("com.marla.in-place.inline-code")
    static let marlaInPlaceSecondaryText = NSAttributedString.Key("com.marla.in-place.secondary-text")
}

@MainActor
enum InPlaceMarkdownAttributedText {
    struct Configuration {
        let baseFontSize: CGFloat
        let baseWeight: NSFont.Weight
        let usesMonospacedFont: Bool
        let alignment: NSTextAlignment
    }

    static func build(
        markdown: String,
        configuration: Configuration
    ) -> NSAttributedString? {
        guard let document = MarkdownResultDocument.parse(markdown) else { return nil }
        return build(document: document, configuration: configuration)
    }

    static func buildCell(
        _ content: AttributedString,
        configuration: Configuration,
        forceBold: Bool
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(
            attributedString: inline(content, configuration: configuration, forceBold: forceBold)
        )
        let paragraph = paragraphStyle(
            alignment: configuration.alignment,
            lineSpacing: 0,
            paragraphSpacing: 0
        )
        if result.length == 0 {
            result.append(NSAttributedString(string: " ", attributes: [
                .font: font(
                    size: configuration.baseFontSize,
                    weight: configuration.baseWeight,
                    monospaced: configuration.usesMonospacedFont,
                    bold: forceBold,
                    italic: false
                )
            ]))
        }
        result.addAttribute(.paragraphStyle, value: paragraph, range: fullRange(of: result))
        return result
    }

    static func measuredSize(_ attributed: NSAttributedString, width: CGFloat) -> CGSize {
        guard attributed.length > 0, width > 0 else { return .zero }
        let textStorage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            size: CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer)
        return CGSize(width: ceil(used.width), height: ceil(used.height))
    }

    static func preparedForDrawing(
        _ attributed: NSAttributedString,
        textColor: NSColor
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: attributed)
        let range = fullRange(of: result)
        guard range.length > 0 else { return result }
        result.addAttribute(.foregroundColor, value: textColor, range: range)
        result.enumerateAttribute(.marlaInPlaceSecondaryText, in: range) { value, runRange, _ in
            guard value != nil else { return }
            result.addAttribute(
                .foregroundColor,
                value: textColor.withAlphaComponent(0.76),
                range: runRange
            )
        }
        result.enumerateAttribute(.marlaInPlaceInlineCode, in: range) { value, runRange, _ in
            guard value != nil else { return }
            result.addAttribute(
                .backgroundColor,
                value: textColor.withAlphaComponent(0.11),
                range: runRange
            )
        }
        return result
    }

    static func codeBlockRects(
        in attributed: NSAttributedString,
        width: CGFloat
    ) -> [CGRect] {
        guard attributed.length > 0, width > 0 else { return [] }
        let textStorage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            size: CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)

        var rects: [CGRect] = []
        let range = fullRange(of: attributed)
        attributed.enumerateAttribute(.marlaInPlaceCodeBackground, in: range) { value, runRange, _ in
            guard value != nil else { return }
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: runRange,
                actualCharacterRange: nil
            )
            let glyphRect = layoutManager.boundingRect(
                forGlyphRange: glyphRange,
                in: textContainer
            )
            guard !glyphRect.isEmpty else { return }
            rects.append(glyphRect)
        }
        return rects
    }

    private static func build(
        document: MarkdownResultDocument,
        configuration: Configuration
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, block) in document.blocks.enumerated() {
            switch block.kind {
            case let .heading(level):
                appendHeading(level: level, content: block.content, configuration: configuration, to: result)
            case .paragraph:
                appendParagraph(block.content, configuration: configuration, to: result)
            case let .unorderedItem(depth):
                appendListItem(
                    marker: "•",
                    depth: depth,
                    content: block.content,
                    configuration: configuration,
                    to: result
                )
            case let .orderedItem(ordinal, depth):
                appendListItem(
                    marker: "\(ordinal).",
                    depth: depth,
                    content: block.content,
                    configuration: configuration,
                    to: result
                )
            case .blockQuote:
                appendQuote(block.content, configuration: configuration, to: result)
            case let .codeBlock(language):
                appendCodeBlock(
                    language: language,
                    content: block.content,
                    configuration: configuration,
                    to: result
                )
            case .thematicBreak:
                appendThematicBreak(configuration: configuration, to: result)
            case let .table(table):
                appendEmbeddedTable(table, configuration: configuration, to: result)
            }
            if index < document.blocks.count - 1, result.string.last != "\n" {
                result.append(NSAttributedString(string: "\n"))
            }
        }
        while result.string.last == "\n" {
            result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
        }
        return result
    }

    private static func appendHeading(
        level: Int,
        content: AttributedString,
        configuration: Configuration,
        to result: NSMutableAttributedString
    ) {
        let scale = headingScale(level: level)
        let weight: NSFont.Weight = level <= 2 ? .bold : (level <= 4 ? .semibold : .medium)
        let headingConfiguration = Configuration(
            baseFontSize: configuration.baseFontSize * scale,
            baseWeight: weight,
            usesMonospacedFont: false,
            alignment: configuration.alignment
        )
        appendStyledParagraph(
            inline(content, configuration: headingConfiguration, forceBold: false),
            configuration: headingConfiguration,
            paragraphSpacing: configuration.baseFontSize * 0.32,
            to: result
        )
    }

    private static func appendParagraph(
        _ content: AttributedString,
        configuration: Configuration,
        to result: NSMutableAttributedString
    ) {
        appendStyledParagraph(
            inline(content, configuration: configuration, forceBold: false),
            configuration: configuration,
            paragraphSpacing: configuration.baseFontSize * 0.28,
            to: result
        )
    }

    private static func appendStyledParagraph(
        _ content: NSAttributedString,
        configuration: Configuration,
        paragraphSpacing: CGFloat,
        to result: NSMutableAttributedString
    ) {
        let rendered = NSMutableAttributedString(attributedString: content)
        rendered.addAttribute(
            .paragraphStyle,
            value: paragraphStyle(
                alignment: configuration.alignment,
                lineSpacing: 0,
                paragraphSpacing: paragraphSpacing
            ),
            range: fullRange(of: rendered)
        )
        result.append(rendered)
        result.append(NSAttributedString(string: "\n"))
    }

    private static func appendListItem(
        marker: String,
        depth: Int,
        content: AttributedString,
        configuration: Configuration,
        to result: NSMutableAttributedString
    ) {
        let renderedContent = NSMutableAttributedString(
            attributedString: inline(content, configuration: configuration, forceBold: false)
        )
        let taskMarker = consumeTaskMarker(from: renderedContent)
        let visibleMarker = taskMarker ?? marker
        let step = max(12, configuration.baseFontSize * 1.15)
        let markerWidth = max(18, configuration.baseFontSize * 1.55)
        let baseIndent = CGFloat(max(0, depth - 1)) * step
        let paragraph = paragraphStyle(
            alignment: configuration.alignment,
            lineSpacing: 0,
            paragraphSpacing: configuration.baseFontSize * 0.2
        )
        paragraph.firstLineHeadIndent = baseIndent
        paragraph.headIndent = baseIndent + markerWidth
        paragraph.tabStops = [
            NSTextTab(textAlignment: .right, location: baseIndent + markerWidth - 6),
            NSTextTab(textAlignment: .left, location: baseIndent + markerWidth)
        ]

        let item = NSMutableAttributedString(
            string: "\t\(visibleMarker)\t",
            attributes: [
                .font: font(
                    size: taskMarker == nil ? configuration.baseFontSize * 0.92 : configuration.baseFontSize,
                    weight: .semibold,
                    monospaced: taskMarker == nil && marker != "•",
                    bold: false,
                    italic: false
                )
            ]
        )
        item.append(renderedContent)
        item.addAttribute(.paragraphStyle, value: paragraph, range: fullRange(of: item))
        item.append(NSAttributedString(string: "\n"))
        result.append(item)
    }

    private static func appendQuote(
        _ content: AttributedString,
        configuration: Configuration,
        to result: NSMutableAttributedString
    ) {
        let paragraph = paragraphStyle(
            alignment: configuration.alignment,
            lineSpacing: 0,
            paragraphSpacing: configuration.baseFontSize * 0.28
        )
        paragraph.firstLineHeadIndent = configuration.baseFontSize * 0.35
        paragraph.headIndent = configuration.baseFontSize * 1.15
        let quote = NSMutableAttributedString(
            string: "│ ",
            attributes: [
                .font: font(
                    size: configuration.baseFontSize,
                    weight: .semibold,
                    monospaced: true,
                    bold: false,
                    italic: false
                ),
                .marlaInPlaceSecondaryText: true
            ]
        )
        let body = NSMutableAttributedString(attributedString: inline(
            content,
            configuration: configuration,
            forceBold: false,
            forceItalic: true
        ))
        body.addAttribute(.marlaInPlaceSecondaryText, value: true, range: fullRange(of: body))
        quote.append(body)
        quote.addAttribute(.paragraphStyle, value: paragraph, range: fullRange(of: quote))
        quote.append(NSAttributedString(string: "\n"))
        result.append(quote)
    }

    private static func appendCodeBlock(
        language: String?,
        content: AttributedString,
        configuration: Configuration,
        to result: NSMutableAttributedString
    ) {
        let code = NSMutableAttributedString()
        if let language, !language.isEmpty {
            code.append(NSAttributedString(
                string: "\(language)\n",
                attributes: [
                    .font: font(
                        size: configuration.baseFontSize * 0.78,
                        weight: .semibold,
                        monospaced: true,
                        bold: false,
                        italic: false
                    ),
                    .marlaInPlaceSecondaryText: true
                ]
            ))
        }
        code.append(NSAttributedString(
            string: String(content.characters).removingTrailingLineBreaks(),
            attributes: [
                .font: font(
                    size: configuration.baseFontSize * 0.9,
                    weight: .medium,
                    monospaced: true,
                    bold: false,
                    italic: false
                )
            ]
        ))
        let paragraph = paragraphStyle(
            alignment: .left,
            lineSpacing: configuration.baseFontSize * 0.08,
            paragraphSpacing: configuration.baseFontSize * 0.35
        )
        paragraph.firstLineHeadIndent = configuration.baseFontSize * 0.45
        paragraph.headIndent = configuration.baseFontSize * 0.45
        paragraph.tailIndent = -configuration.baseFontSize * 0.45
        code.addAttributes(
            [
                .paragraphStyle: paragraph,
                .marlaInPlaceCodeBackground: true
            ],
            range: fullRange(of: code)
        )
        code.append(NSAttributedString(string: "\n"))
        result.append(code)
    }

    private static func appendThematicBreak(
        configuration: Configuration,
        to result: NSMutableAttributedString
    ) {
        result.append(NSAttributedString(
            string: "────────────────\n",
            attributes: [
                .font: font(
                    size: configuration.baseFontSize * 0.62,
                    weight: .regular,
                    monospaced: false,
                    bold: false,
                    italic: false
                ),
                .marlaInPlaceSecondaryText: true,
                .paragraphStyle: paragraphStyle(
                    alignment: configuration.alignment,
                    lineSpacing: 0,
                    paragraphSpacing: configuration.baseFontSize * 0.25
                )
            ]
        ))
    }

    private static func appendEmbeddedTable(
        _ table: MarkdownResultDocument.Table,
        configuration: Configuration,
        to result: NSMutableAttributedString
    ) {
        guard let columnCount = table.rows.first?.count, columnCount > 0 else { return }
        let textTable = NSTextTable()
        textTable.numberOfColumns = columnCount
        textTable.layoutAlgorithm = .fixedLayoutAlgorithm
        textTable.collapsesBorders = true
        textTable.setContentWidth(100, type: .percentageValueType)

        for (rowIndex, row) in table.rows.enumerated() {
            for (columnIndex, content) in row.enumerated() {
                let cell = NSTextTableBlock(
                    table: textTable,
                    startingRow: rowIndex,
                    rowSpan: 1,
                    startingColumn: columnIndex,
                    columnSpan: 1
                )
                cell.setWidth(0.5, type: .absoluteValueType, for: .border)
                cell.setWidth(max(2, configuration.baseFontSize * 0.28), type: .absoluteValueType, for: .padding)
                cell.setContentWidth(100 / CGFloat(columnCount), type: .percentageValueType)
                cell.verticalAlignment = .middleAlignment

                let rendered = NSMutableAttributedString(attributedString: buildCell(
                    content,
                    configuration: Configuration(
                        baseFontSize: configuration.baseFontSize * 0.9,
                        baseWeight: rowIndex == 0 ? .semibold : configuration.baseWeight,
                        usesMonospacedFont: false,
                        alignment: configuration.alignment
                    ),
                    forceBold: rowIndex == 0
                ))
                let paragraph = (rendered.attribute(
                    .paragraphStyle,
                    at: 0,
                    effectiveRange: nil
                ) as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
                    ?? NSMutableParagraphStyle()
                paragraph.textBlocks = [cell]
                rendered.addAttribute(.paragraphStyle, value: paragraph, range: fullRange(of: rendered))
                rendered.append(NSAttributedString(string: "\n"))
                result.append(rendered)
            }
        }
        result.append(NSAttributedString(string: "\n"))
    }

    private static func inline(
        _ content: AttributedString,
        configuration: Configuration,
        forceBold: Bool,
        forceItalic: Bool = false
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for run in content.runs {
            let visibleText = String(content[run.range].characters)
            let intent = run.inlinePresentationIntent
            let isCode = intent?.contains(.code) == true
            let isBold = forceBold || intent?.contains(.stronglyEmphasized) == true
            let isItalic = forceItalic || intent?.contains(.emphasized) == true
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font(
                    size: isCode ? configuration.baseFontSize * 0.9 : configuration.baseFontSize,
                    weight: isCode ? .medium : configuration.baseWeight,
                    monospaced: isCode || configuration.usesMonospacedFont,
                    bold: isBold,
                    italic: isItalic
                )
            ]
            if isCode { attributes[.marlaInPlaceInlineCode] = true }
            if intent?.contains(.strikethrough) == true {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }
            if let link = run.link {
                attributes[.link] = link
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            result.append(NSAttributedString(string: visibleText, attributes: attributes))
        }
        return result
    }

    private static func consumeTaskMarker(from content: NSMutableAttributedString) -> String? {
        let prefixes = [
            "[ ] ": "☐",
            "[x] ": "☑",
            "[X] ": "☑"
        ]
        for (prefix, marker) in prefixes where content.string.hasPrefix(prefix) {
            content.deleteCharacters(in: NSRange(location: 0, length: (prefix as NSString).length))
            return marker
        }
        return nil
    }

    private static func paragraphStyle(
        alignment: NSTextAlignment,
        lineSpacing: CGFloat,
        paragraphSpacing: CGFloat
    ) -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = lineSpacing
        paragraph.paragraphSpacing = paragraphSpacing
        return paragraph
    }

    private static func headingScale(level: Int) -> CGFloat {
        switch min(6, max(1, level)) {
        case 1: 1.5
        case 2: 1.34
        case 3: 1.2
        case 4: 1.1
        case 5: 1.02
        default: 0.96
        }
    }

    private static func font(
        size: CGFloat,
        weight: NSFont.Weight,
        monospaced: Bool,
        bold: Bool,
        italic: Bool
    ) -> NSFont {
        var value = monospaced
            ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
            : NSFont.systemFont(ofSize: size, weight: weight)
        var traits: NSFontTraitMask = []
        if bold { traits.insert(.boldFontMask) }
        if italic { traits.insert(.italicFontMask) }
        if !traits.isEmpty {
            value = NSFontManager.shared.convert(value, toHaveTrait: traits)
        }
        return value
    }

    private static func fullRange(of attributed: NSAttributedString) -> NSRange {
        NSRange(location: 0, length: attributed.length)
    }
}
