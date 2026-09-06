import AppKit
import MarlaCore
import XCTest
@testable import MarlaApp

@MainActor
final class InPlaceMarkdownProjectionTests: XCTestCase {
    func testHeadingLevelsProduceSixDistinctNativeFontSizes() throws {
        let markdown = (1...6).map { level in
            "\(String(repeating: "#", count: level)) Heading \(level)"
        }.joined(separator: "\n\n")
        let attributed = try XCTUnwrap(makeAttributed(markdown))

        let sizes = try (1...6).map { level in
            try font(in: attributed, matching: "Heading \(level)").pointSize
        }
        XCTAssertEqual(Set(sizes).count, 6)
        for index in 1..<sizes.count {
            XCTAssertGreaterThan(sizes[index - 1], sizes[index])
        }
        XCTAssertFalse(attributed.string.contains("#"))
    }

    func testInlineEmphasisPreservesBoldItalicCombinedAndStrikeTraits() throws {
        let attributed = try XCTUnwrap(makeAttributed(
            "**bold** *italic* ***both*** ~~removed~~"
        ))

        XCTAssertTrue(traits(of: try font(in: attributed, matching: "bold")).contains(.bold))
        XCTAssertTrue(traits(of: try font(in: attributed, matching: "italic")).contains(.italic))
        let combined = traits(of: try font(in: attributed, matching: "both"))
        XCTAssertTrue(combined.contains(.bold))
        XCTAssertTrue(combined.contains(.italic))

        let removedRange = range(of: "removed", in: attributed)
        XCTAssertNotEqual(
            attributed.attribute(.strikethroughStyle, at: removedRange.location, effectiveRange: nil) as? Int,
            nil
        )
        XCTAssertFalse(attributed.string.contains("**"))
        XCTAssertFalse(attributed.string.contains("~~"))
    }

    func testInlineCodeAndLinkKeepSemanticAttributesAndDrawingPaint() throws {
        let attributed = try XCTUnwrap(makeAttributed(
            "Use `swift test` and read [the guide](https://example.com/guide)."
        ))
        let codeRange = range(of: "swift test", in: attributed)
        let codeFont = try XCTUnwrap(
            attributed.attribute(.font, at: codeRange.location, effectiveRange: nil) as? NSFont
        )
        XCTAssertTrue(codeFont.isFixedPitch)
        XCTAssertNotNil(attributed.attribute(.marlaInPlaceInlineCode, at: codeRange.location, effectiveRange: nil))

        let linkRange = range(of: "the guide", in: attributed)
        XCTAssertEqual(
            attributed.attribute(.link, at: linkRange.location, effectiveRange: nil) as? URL,
            URL(string: "https://example.com/guide")
        )
        XCTAssertNotNil(attributed.attribute(.underlineStyle, at: linkRange.location, effectiveRange: nil))

        let drawable = InPlaceMarkdownAttributedText.preparedForDrawing(attributed, textColor: .black)
        XCTAssertNotNil(drawable.attribute(.backgroundColor, at: codeRange.location, effectiveRange: nil))
        XCTAssertEqual(drawable.attribute(.foregroundColor, at: linkRange.location, effectiveRange: nil) as? NSColor, .black)
    }

    func testFencedCodeKeepsLanguageMonospacedTextAndBackgroundRole() throws {
        let attributed = try XCTUnwrap(makeAttributed(
            """
            ```swift
            let answer = 42
            ```
            """
        ))
        XCTAssertTrue(attributed.string.contains("swift"))
        XCTAssertTrue(attributed.string.contains("let answer = 42"))
        XCTAssertFalse(attributed.string.contains("```"))

        let codeRange = range(of: "let answer", in: attributed)
        XCTAssertTrue(try font(in: attributed, matching: "let answer").isFixedPitch)
        XCTAssertNotNil(
            attributed.attribute(.marlaInPlaceCodeBackground, at: codeRange.location, effectiveRange: nil)
        )
        let rects = InPlaceMarkdownAttributedText.codeBlockRects(in: attributed, width: 320)
        XCTAssertEqual(rects.count, 1)
        XCTAssertGreaterThan(rects[0].height, codeFontHeight(in: attributed, matching: "let answer"))
    }

    func testNestedListsAndTaskItemsProjectMarkersAndIndentation() throws {
        let attributed = try XCTUnwrap(makeAttributed(
            """
            - Parent
              - Child
            1. First
               1. Nested
            - [ ] Pending
            - [x] Complete
            """
        ))
        XCTAssertTrue(attributed.string.contains("•"))
        XCTAssertTrue(attributed.string.contains("1."))
        XCTAssertTrue(attributed.string.contains("☐"))
        XCTAssertTrue(attributed.string.contains("☑"))
        XCTAssertFalse(attributed.string.contains("[ ]"))
        XCTAssertFalse(attributed.string.contains("[x]"))

        let parentIndent = try paragraph(in: attributed, matching: "Parent").headIndent
        let childIndent = try paragraph(in: attributed, matching: "Child").headIndent
        XCTAssertGreaterThan(childIndent, parentIndent)
        let firstIndent = try paragraph(in: attributed, matching: "First").headIndent
        let nestedIndent = try paragraph(in: attributed, matching: "Nested").headIndent
        XCTAssertGreaterThan(nestedIndent, firstIndent)
    }

    func testBlockQuoteUsesVisibleTreatmentWithoutMarkdownMarker() throws {
        let attributed = try XCTUnwrap(makeAttributed("> A quoted **idea**"))
        XCTAssertTrue(attributed.string.hasPrefix("│ "))
        XCTAssertFalse(attributed.string.contains(">"))
        XCTAssertTrue(traits(of: try font(in: attributed, matching: "quoted")).contains(.italic))
        XCTAssertNotNil(
            attributed.attribute(
                .marlaInPlaceSecondaryText,
                at: range(of: "quoted", in: attributed).location,
                effectiveRange: nil
            )
        )
    }

    func testTableCellsPreserveInlineRichRuns() throws {
        let table = try XCTUnwrap(InPlaceMarkdownProjection.table(from: """
        | Style | Value |
        | --- | --- |
        | **bold** and *italic* | `code` and [link](https://example.com) |
        """))
        let left = InPlaceMarkdownAttributedText.buildCell(
            table.rows[1][0],
            configuration: configuration,
            forceBold: false
        )
        let right = InPlaceMarkdownAttributedText.buildCell(
            table.rows[1][1],
            configuration: configuration,
            forceBold: false
        )

        XCTAssertTrue(traits(of: try font(in: left, matching: "bold")).contains(.bold))
        XCTAssertTrue(traits(of: try font(in: left, matching: "italic")).contains(.italic))
        XCTAssertTrue(try font(in: right, matching: "code").isFixedPitch)
        XCTAssertEqual(
            right.attribute(.link, at: range(of: "link", in: right).location, effectiveRange: nil) as? URL,
            URL(string: "https://example.com")
        )
    }

    func testLayoutStoresTheExactFittedAttributedDocument() throws {
        let layout = try InPlaceOverlayLayoutBuilder.make(
            document: OCRDocument(blocks: [
                ContentBlock(
                    id: "rich",
                    kind: .paragraph,
                    sourceText: "Source",
                    bounds: NormalizedRect(x: 0.05, y: 0.1, width: 0.9, height: 0.8),
                    readingOrder: 0
                )
            ]),
            translation: InPlaceTranslationResult(blocks: [
                InPlaceTranslatedBlock(
                    id: "rich",
                    text: "## Heading\n\nA **bold** line with `code`.\n\n> Quote"
                )
            ]),
            canvasSize: CGSize(width: 520, height: 240)
        )
        let block = try XCTUnwrap(layout.blocks.first)
        let attributed = try XCTUnwrap(block.attributedText)
        XCTAssertEqual(block.text, attributed.string)
        let drawingFrame = block.frame.insetBy(dx: 2, dy: 1)
        let measured = InPlaceMarkdownAttributedText.measuredSize(attributed, width: drawingFrame.width)
        XCTAssertLessThanOrEqual(measured.width, ceil(drawingFrame.width))
        XCTAssertLessThanOrEqual(measured.height, ceil(drawingFrame.height))
        XCTAssertTrue(traits(of: try font(in: attributed, matching: "bold")).contains(.bold))
        XCTAssertTrue(try font(in: attributed, matching: "code").isFixedPitch)
    }

    private var configuration: InPlaceMarkdownAttributedText.Configuration {
        .init(
            baseFontSize: 16,
            baseWeight: .regular,
            usesMonospacedFont: false,
            alignment: .left
        )
    }

    private func makeAttributed(_ markdown: String) -> NSAttributedString? {
        InPlaceMarkdownAttributedText.build(markdown: markdown, configuration: configuration)
    }

    private func range(of needle: String, in attributed: NSAttributedString) -> NSRange {
        (attributed.string as NSString).range(of: needle)
    }

    private func font(in attributed: NSAttributedString, matching needle: String) throws -> NSFont {
        let location = range(of: needle, in: attributed).location
        return try XCTUnwrap(attributed.attribute(.font, at: location, effectiveRange: nil) as? NSFont)
    }

    private func paragraph(
        in attributed: NSAttributedString,
        matching needle: String
    ) throws -> NSParagraphStyle {
        let location = range(of: needle, in: attributed).location
        return try XCTUnwrap(
            attributed.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
        )
    }

    private func traits(of font: NSFont) -> NSFontDescriptor.SymbolicTraits {
        font.fontDescriptor.symbolicTraits
    }

    private func codeFontHeight(in attributed: NSAttributedString, matching needle: String) -> CGFloat {
        guard let value = try? font(in: attributed, matching: needle) else { return 0 }
        return ceil(value.ascender - value.descender)
    }
}
