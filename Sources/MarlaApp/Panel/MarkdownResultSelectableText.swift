import AppKit
import SwiftUI

extension NSAttributedString.Key {
    static let marlaStreamingCursor = NSAttributedString.Key("com.marla.streaming-cursor")
    static let marlaInlineCodeBackground = NSAttributedString.Key("com.marla.inline-code-background")
    static let marlaCodeBlockBackground = NSAttributedString.Key("com.marla.code-block-background")
    static let marlaCodeBlockBorder = NSAttributedString.Key("com.marla.code-block-border")
}

struct MarkdownResultSelectableText: NSViewRepresentable {
    let attributedDocument: NSAttributedString
    let accessibilityText: String

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
        textView.replaceContentsIfNeeded(with: attributedDocument)
        textView.setAccessibilityLabel(accessibilityText)
    }
}

final class MarkdownSelectableTextView: NSTextView {
    static let codeBlockCornerRadius: CGFloat = 5
    static let inlineCodeCornerRadius: CGFloat = 3
    static let inlineCodeHorizontalPadding: CGFloat = 3

    private var installedContents: NSAttributedString?

    override func draw(_ dirtyRect: NSRect) {
        drawCodeBackgrounds(in: dirtyRect)
        super.draw(dirtyRect)
    }

    @discardableResult
    func replaceContentsIfNeeded(with attributed: NSAttributedString) -> Bool {
        guard installedContents?.isEqual(to: attributed) != true, let textStorage else { return false }
        let selection = selectedRange()
        textStorage.setAttributedString(attributed)
        installedContents = NSAttributedString(attributedString: attributed)
        setSelectedRange(NSIntersectionRange(selection, NSRange(location: 0, length: attributed.length)))
        return true
    }

    func selectedTextForCopy() -> String? {
        let selection = selectedRange()
        guard selection.location != NSNotFound, selection.length > 0, let textStorage else { return nil }
        let selected = NSMutableAttributedString(
            attributedString: textStorage.attributedSubstring(from: selection)
        )
        var cursorRanges: [NSRange] = []
        selected.enumerateAttribute(
            .marlaStreamingCursor,
            in: NSRange(location: 0, length: selected.length)
        ) { value, range, _ in
            if value != nil { cursorRanges.append(range) }
        }
        for range in cursorRanges.reversed() {
            selected.deleteCharacters(in: range)
        }
        let selectedText = selected.string
            .removingTrailingLineBreaks()
        return selectedText.isEmpty ? nil : selectedText
    }

    override func copy(_ sender: Any?) {
        guard let selectedText = selectedTextForCopy() else {
            super.copy(sender)
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(selectedText, forType: .string)
    }

    static func inlineCodeBackgroundRect(for glyphRect: NSRect, font: NSFont) -> NSRect {
        let fontHeight = ceil(font.ascender - font.descender + 2)
        let height = min(max(1, glyphRect.height - 2), fontHeight)
        return NSRect(
            x: glyphRect.minX - inlineCodeHorizontalPadding,
            y: glyphRect.midY - (height / 2),
            width: glyphRect.width + (inlineCodeHorizontalPadding * 2),
            height: height
        )
    }

    private func drawCodeBackgrounds(in dirtyRect: NSRect) {
        guard let layoutManager,
              let textContainer,
              let textStorage,
              textStorage.length > 0 else {
            return
        }
        layoutManager.ensureLayout(for: textContainer)
        let origin = textContainerOrigin
        let localDirtyRect = dirtyRect.offsetBy(dx: -origin.x, dy: -origin.y)
        let visibleGlyphRange = layoutManager.glyphRange(
            forBoundingRect: localDirtyRect,
            in: textContainer
        )
        let visibleCharacterRange = layoutManager.characterRange(
            forGlyphRange: visibleGlyphRange,
            actualGlyphRange: nil
        )
        guard visibleCharacterRange.length > 0 else { return }

        drawCodeBlockBackgrounds(
            visibleCharacterRange: visibleCharacterRange,
            layoutManager: layoutManager,
            textContainer: textContainer,
            textStorage: textStorage,
            origin: origin,
            dirtyRect: dirtyRect
        )
        drawInlineCodeBackgrounds(
            visibleCharacterRange: visibleCharacterRange,
            layoutManager: layoutManager,
            textContainer: textContainer,
            textStorage: textStorage,
            origin: origin,
            dirtyRect: dirtyRect
        )
    }

    private func drawCodeBlockBackgrounds(
        visibleCharacterRange: NSRange,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer,
        textStorage: NSTextStorage,
        origin: NSPoint,
        dirtyRect: NSRect
    ) {
        var visitedRanges = Set<Int>()
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.enumerateAttribute(
            .marlaCodeBlockBackground,
            in: visibleCharacterRange
        ) { value, range, _ in
            guard value != nil else { return }
            var effectiveRange = NSRange()
            guard let fillColor = textStorage.attribute(
                .marlaCodeBlockBackground,
                at: range.location,
                longestEffectiveRange: &effectiveRange,
                in: fullRange
            ) as? NSColor,
                visitedRanges.insert(effectiveRange.location).inserted else {
                return
            }

            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: effectiveRange,
                actualCharacterRange: nil
            )
            var glyphRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            guard !glyphRect.isEmpty else { return }
            glyphRect.origin.x = 0
            glyphRect.size.width = textContainer.size.width
            let blockRect = glyphRect
                .insetBy(dx: 0, dy: -8)
                .offsetBy(dx: origin.x, dy: origin.y)
            guard blockRect.intersects(dirtyRect) else { return }

            let pathRect = blockRect.insetBy(dx: 0.25, dy: 0.25)
            let path = NSBezierPath(
                roundedRect: pathRect,
                xRadius: Self.codeBlockCornerRadius,
                yRadius: Self.codeBlockCornerRadius
            )
            fillColor.setFill()
            path.fill()
            if let borderColor = textStorage.attribute(
                .marlaCodeBlockBorder,
                at: effectiveRange.location,
                effectiveRange: nil
            ) as? NSColor {
                borderColor.setStroke()
                path.lineWidth = 0.5
                path.stroke()
            }
        }
    }

    private func drawInlineCodeBackgrounds(
        visibleCharacterRange: NSRange,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer,
        textStorage: NSTextStorage,
        origin: NSPoint,
        dirtyRect: NSRect
    ) {
        var visitedRanges = Set<Int>()
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.enumerateAttribute(
            .marlaInlineCodeBackground,
            in: visibleCharacterRange
        ) { value, range, _ in
            guard value != nil else { return }
            var effectiveRange = NSRange()
            guard let fillColor = textStorage.attribute(
                .marlaInlineCodeBackground,
                at: range.location,
                longestEffectiveRange: &effectiveRange,
                in: fullRange
            ) as? NSColor,
                visitedRanges.insert(effectiveRange.location).inserted else {
                return
            }
            let glyphRange = layoutManager.glyphRange(
                forCharacterRange: effectiveRange,
                actualCharacterRange: nil
            )
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) {
                _, _, container, lineGlyphRange, _ in
                let segmentRange = NSIntersectionRange(glyphRange, lineGlyphRange)
                guard segmentRange.length > 0 else { return }
                let characterIndex = layoutManager.characterIndexForGlyph(at: segmentRange.location)
                guard let font = textStorage.attribute(
                    .font,
                    at: min(characterIndex, max(0, textStorage.length - 1)),
                    effectiveRange: nil
                ) as? NSFont else {
                    return
                }
                let glyphRect = layoutManager.boundingRect(forGlyphRange: segmentRange, in: container)
                let backgroundRect = Self.inlineCodeBackgroundRect(for: glyphRect, font: font)
                    .offsetBy(dx: origin.x, dy: origin.y)
                guard backgroundRect.intersects(dirtyRect) else { return }
                fillColor.setFill()
                NSBezierPath(
                    roundedRect: backgroundRect,
                    xRadius: Self.inlineCodeCornerRadius,
                    yRadius: Self.inlineCodeCornerRadius
                ).fill()
            }
        }
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

    static func build(
        _ document: MarkdownResultDocument,
        showsStreamingCursor: Bool = false
    ) -> NSAttributedString {
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

        if showsStreamingCursor {
            let cursor = NSAttributedString(
                string: "│",
                attributes: [
                    .font: bodyFont,
                    .foregroundColor: NSColor.controlAccentColor,
                    .marlaStreamingCursor: true,
                ]
            )
            let insertionIndex = result.string.hasSuffix("\n")
                ? max(0, result.length - 1)
                : result.length
            result.insert(cursor, at: insertionIndex)
        }

        return result
    }

    static func measuredHeight(_ attributed: NSAttributedString, width: CGFloat) -> CGFloat {
        let textStorage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(
            size: NSSize(width: max(1, width), height: .greatestFiniteMagnitude)
        )
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = false
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: textContainer)
        return ceil(layoutManager.usedRect(for: textContainer).height)
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
            if isCode { attributes[.marlaInlineCodeBackground] = subtleBackground }
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
        block.setWidth(8, type: .absoluteValueType, for: .padding)
        block.setWidth(0.5, type: .absoluteValueType, for: .border)
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
        code.addAttributes(
            [
                .paragraphStyle: paragraph,
                .marlaCodeBlockBackground: subtleBackground,
                .marlaCodeBlockBorder: dividerColor,
            ],
            range: NSRange(location: 0, length: code.length)
        )
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
