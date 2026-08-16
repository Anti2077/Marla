import AppKit
import SwiftUI

struct MarkdownResultSelectableText: NSViewRepresentable {
    let document: MarkdownResultDocument

    func makeNSView(context _: Context) -> NSScrollView {
        Self.makeScrollView()
    }

    static func makeScrollView() -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.horizontalScrollElasticity = .none

        let textView = MarkdownSelectableTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: .greatestFiniteMagnitude
        )
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.controlAccentColor,
            .underlineStyle: 0,
        ]
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context _: Context) {
        guard let textView = scrollView.documentView as? MarkdownSelectableTextView else { return }
        let attributed = MarkdownResultAttributedDocument.build(document)
        textView.replaceContentsIfNeeded(with: attributed)
        textView.setAccessibilityLabel(document.plainText)
    }
}

final class MarkdownSelectableTextView: NSTextView {
    private var installedContents: NSAttributedString?

    @discardableResult
    func replaceContentsIfNeeded(with attributed: NSAttributedString) -> Bool {
        guard installedContents?.isEqual(to: attributed) != true, let textStorage else { return false }
        let selection = selectedRange()
        textStorage.setAttributedString(attributed)
        installedContents = NSAttributedString(attributedString: attributed)
        setSelectedRange(NSIntersectionRange(selection, NSRange(location: 0, length: attributed.length)))
        return true
    }

    override func copy(_ sender: Any?) {
        let selection = selectedRange()
        guard selection.location != NSNotFound, selection.length > 0 else {
            super.copy(sender)
            return
        }
        let selectedText = (string as NSString)
            .substring(with: selection)
            .removingTrailingLineBreaks()
        guard !selectedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(selectedText, forType: .string)
    }
}

@MainActor
enum MarkdownResultAttributedDocument {
    private static let bodyFont = NSFont.systemFont(ofSize: 15)
    private static let bodyColor = NSColor.labelColor
    private static let secondaryColor = NSColor.secondaryLabelColor
    private static let tertiaryColor = NSColor.tertiaryLabelColor
    private static let dividerColor = NSColor.separatorColor
    private static let subtleBackground = NSColor.labelColor.withAlphaComponent(0.065)
    private static let alternatingRowBackground = NSColor.labelColor.withAlphaComponent(0.025)

    static func build(_ document: MarkdownResultDocument) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for (index, block) in document.blocks.enumerated() {
            switch block.kind {
            case let .heading(level):
                appendParagraph(
                    inline(block.content, baseFont: headingFont(level: level)),
                    to: result,
                    paragraphSpacing: 8
                )
            case .paragraph:
                appendParagraph(inline(block.content), to: result, paragraphSpacing: 8)
            case let .unorderedItem(depth):
                appendListItem(marker: "•", depth: depth, content: block.content, to: result)
            case let .orderedItem(ordinal, depth):
                appendListItem(marker: "\(ordinal).", depth: depth, content: block.content, to: result)
            case .blockQuote:
                appendQuote(block.content, to: result)
            case let .codeBlock(language):
                appendCodeBlock(language: language, content: block.content, to: result)
            case .thematicBreak:
                let rule = NSAttributedString(
                    string: "────────────────────────\n",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 9),
                        .foregroundColor: dividerColor,
                    ]
                )
                result.append(rule)
            case let .table(table):
                appendTable(table, to: result)
            }

            if index < document.blocks.count - 1,
               result.string.last != "\n" {
                result.append(NSAttributedString(string: "\n"))
            }
        }

        return result
    }

    private static func inline(
        _ content: AttributedString,
        baseFont: NSFont = bodyFont,
        baseColor: NSColor = bodyColor,
        forceBold: Bool = false,
        forceItalic: Bool = false
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for run in content.runs {
            let text = String(content[run.range].characters)
            let intent = run.inlinePresentationIntent
            let isCode = intent?.contains(.code) == true
            let isBold = forceBold || intent?.contains(.stronglyEmphasized) == true
            let isItalic = forceItalic || intent?.contains(.emphasized) == true
            var font = isCode ? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular) : baseFont
            var traits: NSFontTraitMask = []
            if isBold { traits.insert(.boldFontMask) }
            if isItalic { traits.insert(.italicFontMask) }
            if !traits.isEmpty { font = NSFontManager.shared.convert(font, toHaveTrait: traits) }

            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: baseColor,
            ]
            if isCode { attributes[.backgroundColor] = subtleBackground }
            if intent?.contains(.strikethrough) == true { attributes[.strikethroughStyle] = 1 }
            if let link = run.link { attributes[.link] = link }
            result.append(NSAttributedString(string: text, attributes: attributes))
        }
        return result
    }

    private static func appendParagraph(
        _ content: NSAttributedString,
        to result: NSMutableAttributedString,
        paragraphSpacing: CGFloat
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = paragraphSpacing
        let mutable = NSMutableAttributedString(attributedString: content)
        mutable.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: mutable.length))
        result.append(mutable)
        result.append(NSAttributedString(string: "\n"))
    }

    private static func appendListItem(
        marker: String,
        depth: Int,
        content: AttributedString,
        to result: NSMutableAttributedString
    ) {
        let paragraph = NSMutableParagraphStyle()
        let baseIndent = CGFloat(max(0, depth - 1)) * 14
        paragraph.firstLineHeadIndent = baseIndent
        paragraph.headIndent = baseIndent + 28
        paragraph.tabStops = [
            NSTextTab(textAlignment: .right, location: baseIndent + 20),
            NSTextTab(textAlignment: .left, location: baseIndent + 28),
        ]
        paragraph.paragraphSpacing = 4

        let item = NSMutableAttributedString(
            string: "\t\(marker)\t",
            attributes: [
                .font: bodyFont,
                .foregroundColor: secondaryColor,
            ]
        )
        item.append(inline(content))
        item.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: item.length))
        item.append(NSAttributedString(string: "\n"))
        result.append(item)
    }

    private static func appendQuote(_ content: AttributedString, to result: NSMutableAttributedString) {
        let block = NSTextBlock()
        block.setWidth(2, type: .absoluteValueType, for: .border, edge: .minX)
        block.setBorderColor(dividerColor, for: .minX)
        block.setWidth(8, type: .absoluteValueType, for: .padding, edge: .minX)

        let paragraph = NSMutableParagraphStyle()
        paragraph.textBlocks = [block]
        paragraph.paragraphSpacing = 8
        let quote = NSMutableAttributedString(attributedString: inline(
            content,
            baseColor: secondaryColor,
            forceItalic: true
        ))
        quote.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: quote.length))
        quote.append(NSAttributedString(string: "\n"))
        result.append(quote)
    }

    private static func appendCodeBlock(
        language: String?,
        content: AttributedString,
        to result: NSMutableAttributedString
    ) {
        let block = NSTextBlock()
        block.backgroundColor = subtleBackground
        block.setWidth(8, type: .absoluteValueType, for: .padding)
        block.setWidth(0.5, type: .absoluteValueType, for: .border)
        block.setBorderColor(dividerColor)
        block.setContentWidth(100, type: .percentageValueType)

        let paragraph = NSMutableParagraphStyle()
        paragraph.textBlocks = [block]
        paragraph.paragraphSpacing = 8

        let code = NSMutableAttributedString()
        if let language, !language.isEmpty {
            code.append(NSAttributedString(
                string: "\(language)\n",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: tertiaryColor,
                ]
            ))
        }
        code.append(NSAttributedString(
            string: String(content.characters).removingTrailingLineBreaks(),
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: bodyColor,
            ]
        ))
        code.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: code.length))
        code.append(NSAttributedString(string: "\n"))
        result.append(code)
    }

    private static func appendTable(
        _ markdownTable: MarkdownResultDocument.Table,
        to result: NSMutableAttributedString
    ) {
        guard let columnCount = markdownTable.rows.first?.count, columnCount > 0 else { return }
        let textTable = NSTextTable()
        textTable.numberOfColumns = columnCount
        textTable.layoutAlgorithm = .fixedLayoutAlgorithm
        textTable.collapsesBorders = true
        textTable.hidesEmptyCells = false
        textTable.setContentWidth(100, type: .percentageValueType)
        let columnPercentages = tableColumnPercentages(markdownTable)

        for (rowIndex, row) in markdownTable.rows.enumerated() {
            for (columnIndex, content) in row.enumerated() {
                let cell = NSTextTableBlock(
                    table: textTable,
                    startingRow: rowIndex,
                    rowSpan: 1,
                    startingColumn: columnIndex,
                    columnSpan: 1
                )
                cell.setWidth(0.5, type: .absoluteValueType, for: .border)
                cell.setBorderColor(dividerColor)
                cell.setWidth(8, type: .absoluteValueType, for: .padding)
                cell.setContentWidth(columnPercentages[columnIndex], type: .percentageValueType)
                cell.verticalAlignment = .middleAlignment
                if rowIndex == 0 {
                    cell.backgroundColor = subtleBackground
                } else if rowIndex.isMultiple(of: 2) {
                    cell.backgroundColor = alternatingRowBackground
                }

                let paragraph = NSMutableParagraphStyle()
                paragraph.textBlocks = [cell]
                paragraph.alignment = .center
                paragraph.lineBreakMode = .byWordWrapping
                paragraph.lineSpacing = 1
                let rendered = NSMutableAttributedString(attributedString: inline(
                    content,
                    baseFont: rowIndex == 0
                        ? NSFont.systemFont(ofSize: 14, weight: .semibold)
                        : NSFont.systemFont(ofSize: 14),
                    forceBold: rowIndex == 0
                ))
                if rendered.length == 0 { rendered.append(NSAttributedString(string: " ")) }
                rendered.addAttribute(
                    .paragraphStyle,
                    value: paragraph,
                    range: NSRange(location: 0, length: rendered.length)
                )
                rendered.append(NSAttributedString(string: "\n"))
                result.append(rendered)
            }
        }
        result.append(NSAttributedString(string: "\n"))
    }

    static func tableColumnPercentages(_ table: MarkdownResultDocument.Table) -> [CGFloat] {
        guard let columnCount = table.rows.first?.count, columnCount > 0 else { return [] }
        let minimumWeight: CGFloat = 72
        let maximumWeight: CGFloat = 240
        let horizontalCellPadding: CGFloat = 16
        let weights = (0..<columnCount).map { columnIndex in
            let measuredWidth = table.rows.enumerated().map { rowIndex, row in
                let font = rowIndex == 0
                    ? NSFont.systemFont(ofSize: 14, weight: .semibold)
                    : NSFont.systemFont(ofSize: 14)
                let visibleText = String(row[columnIndex].characters)
                return ceil((visibleText as NSString).size(withAttributes: [.font: font]).width)
                    + horizontalCellPadding
            }.max() ?? minimumWeight
            return min(maximumWeight, max(minimumWeight, measuredWidth))
        }
        let total = weights.reduce(0, +)
        guard total > 0 else { return Array(repeating: 100 / CGFloat(columnCount), count: columnCount) }
        return weights.map { ($0 / total) * 100 }
    }

    private static func headingFont(level: Int) -> NSFont {
        switch level {
        case 1: .systemFont(ofSize: 20, weight: .bold)
        case 2: .systemFont(ofSize: 18, weight: .bold)
        case 3: .systemFont(ofSize: 16, weight: .semibold)
        default: .systemFont(ofSize: 15, weight: .semibold)
        }
    }
}
