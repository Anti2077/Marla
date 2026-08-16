import AppKit
import MarlaCore
import XCTest
@testable import MarlaApp

final class MarkdownResultTextTests: XCTestCase {
    func testStructuredParserBuildsReadableNativeBlocks() throws {
        let markdown = """
        # Release Notes

        A paragraph with **emphasis**, `TOKEN`, and a [link](https://example.com/docs).

        - First item
        - Second item

        > Keep the reading context.

        ```swift
        let value = 1
        ```
        """

        let document = try XCTUnwrap(MarkdownResultDocument.parse(markdown))

        XCTAssertEqual(
            document.blocks.map(\.kind),
            [
                .heading(level: 1),
                .paragraph,
                .unorderedItem(depth: 1),
                .unorderedItem(depth: 1),
                .blockQuote,
                .codeBlock(language: "swift")
            ]
        )
        XCTAssertEqual(String(document.blocks[0].content.characters), "Release Notes")
        XCTAssertTrue(
            document.blocks[1].content.runs.contains { $0.link == URL(string: "https://example.com/docs") }
        )
        XCTAssertTrue(
            document.blocks[1].content.runs.contains {
                $0.inlinePresentationIntent?.contains(.code) == true
            }
        )
    }

    func testGFMTableParsesAlignmentEmptyCellsEscapedPipesAndCodePipes() throws {
        let markdown = """
        | Name | Command | Note |
        | :--- | :-----: | ---: |
        | Flux \\| Markdown | `a|b` | |
        """

        let document = try XCTUnwrap(MarkdownResultDocument.parse(markdown))
        guard case let .table(table) = try XCTUnwrap(document.blocks.first).kind else {
            return XCTFail("Expected a native GFM table block")
        }

        XCTAssertEqual(table.alignments, [.leading, .center, .trailing])
        XCTAssertEqual(table.rows.count, 2)
        XCTAssertEqual(table.rows.map(\.count), [3, 3])
        XCTAssertEqual(String(table.rows[1][0].characters), "Flux | Markdown")
        XCTAssertEqual(String(table.rows[1][1].characters), "a|b")
        XCTAssertEqual(String(table.rows[1][2].characters), "")
        XCTAssertTrue(
            table.rows[1][1].runs.contains {
                $0.inlinePresentationIntent?.contains(.code) == true
            }
        )
    }

    func testMalformedGFMTableSafelyFallsBackToOrdinaryMarkdown() throws {
        let document = try XCTUnwrap(
            MarkdownResultDocument.parse("| One | Two |\n| -- | invalid |\n| A | B |")
        )

        XCTAssertFalse(document.blocks.contains { block in
            if case .table = block.kind { return true }
            return false
        })
        XCTAssertTrue(document.plainText.contains("invalid"))
    }

    @MainActor
    func testTableColumnWidthsFollowLongestVisibleCellWithinBounds() throws {
        let markdown = """
        | Detailed explanation | S | M |
        | --- | --- | --- |
        | This column contains much longer visible content than the others | A | B |
        """
        let document = try XCTUnwrap(MarkdownResultDocument.parse(markdown))
        guard case let .table(table) = try XCTUnwrap(document.blocks.first).kind else {
            return XCTFail("Expected a native GFM table block")
        }

        let percentages = MarkdownResultAttributedDocument.tableColumnPercentages(table)
        XCTAssertEqual(percentages.count, 3)
        XCTAssertEqual(percentages.reduce(0, +), 100, accuracy: 0.001)
        XCTAssertGreaterThan(percentages[0], percentages[1])
        XCTAssertGreaterThan(percentages[0], percentages[2])
        XCTAssertGreaterThan(percentages[1], 0)
        XCTAssertGreaterThan(percentages[2], 0)
    }

    @MainActor
    func testRenderedTableCentersEveryColumnWithoutChangingParsedAlignment() throws {
        let markdown = """
        | Leading | Center | Trailing |
        | :--- | :---: | ---: |
        | Left | Middle | Right |
        """
        let document = try XCTUnwrap(MarkdownResultDocument.parse(markdown))
        guard case let .table(table) = try XCTUnwrap(document.blocks.first).kind else {
            return XCTFail("Expected a native GFM table block")
        }
        XCTAssertEqual(table.alignments, [.leading, .center, .trailing])

        let rendered = MarkdownResultAttributedDocument.build(document)
        for token in ["Leading", "Center", "Trailing", "Left", "Middle", "Right"] {
            let range = (rendered.string as NSString).range(of: token)
            let style = try XCTUnwrap(
                rendered.attribute(.paragraphStyle, at: range.location, effectiveRange: nil)
                    as? NSParagraphStyle
            )
            XCTAssertEqual(style.alignment, .center, token)
        }
    }

    @MainActor
    func testStrongMarkupUsesAnExplicitBoldFontTraitAcrossParagraphListAndLink() throws {
        let markdown = """
        **Paragraph** and [**Link**](https://example.com).

        - **List** item
        """
        let document = try XCTUnwrap(MarkdownResultDocument.parse(markdown))
        let rendered = MarkdownResultAttributedDocument.build(document)

        for token in ["Paragraph", "Link", "List"] {
            let range = (rendered.string as NSString).range(of: token)
            XCTAssertNotEqual(range.location, NSNotFound)
            let font = try XCTUnwrap(rendered.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont)
            XCTAssertTrue(NSFontManager.shared.traits(of: font).contains(.boldFontMask), token)
        }
        let linkRange = (rendered.string as NSString).range(of: "Link")
        XCTAssertEqual(
            rendered.attribute(.link, at: linkRange.location, effectiveRange: nil) as? URL,
            URL(string: "https://example.com")
        )
    }

    func testPlainTextProjectionRemovesMarkupAndUsesTSVForTables() throws {
        let markdown = """
        # Title

        **Bold** [label](https://example.com) and `code`.

        - First
        - Second

        1. Ordered

        ```swift
        let value = 1
        ```

        | Left | Right |
        | :--- | ---: |
        | A | B |
        """
        let document = try XCTUnwrap(MarkdownResultDocument.parse(markdown))

        XCTAssertEqual(
            document.plainText,
            """
            Title

            Bold label and code.

            • First
            • Second

            1. Ordered

            let value = 1

            Left\tRight
            A\tB
            """
        )
    }

    @MainActor
    func testSingleNativeDocumentSupportsCrossBlockSelectionAndCopyWithoutTrailingLineBreak() throws {
        let markdown = """
        # Heading

        Paragraph

        - Item

        | A | B |
        | --- | --- |
        | 1 | 2 |
        """
        let document = try XCTUnwrap(MarkdownResultDocument.parse(markdown))
        let rendered = MarkdownResultAttributedDocument.build(document)
        let textView = MarkdownSelectableTextView(frame: .zero)
        textView.textStorage?.setAttributedString(rendered)
        textView.setSelectedRange(NSRange(location: 0, length: rendered.length))

        textView.copy(nil)

        let copied = try XCTUnwrap(NSPasteboard.general.string(forType: .string))
        XCTAssertTrue(copied.contains("Heading"))
        XCTAssertTrue(copied.contains("Paragraph"))
        XCTAssertTrue(copied.contains("Item"))
        XCTAssertTrue(copied.contains("1"))
        XCTAssertFalse(copied.hasSuffix("\n"))
        XCTAssertEqual(copied, rendered.string.removingTrailingLineBreaks())
    }

    @MainActor
    func testCompletedMarkdownUsesOneVerticalAppKitScrollOwnerWithoutHorizontalElasticity() throws {
        let scrollView = MarkdownResultSelectableText.makeScrollView()
        let textView = try XCTUnwrap(scrollView.documentView as? MarkdownSelectableTextView)

        XCTAssertTrue(scrollView.hasVerticalScroller)
        XCTAssertTrue(scrollView.autohidesScrollers)
        XCTAssertEqual(scrollView.scrollerStyle, .overlay)
        XCTAssertFalse(scrollView.hasHorizontalScroller)
        XCTAssertEqual(scrollView.horizontalScrollElasticity, .none)
        XCTAssertTrue(textView.textContainer?.widthTracksTextView == true)
        XCTAssertTrue(textView.isVerticallyResizable)
        XCTAssertFalse(textView.isHorizontallyResizable)
    }

    @MainActor
    func testCompletedMarkdownScrollsVerticallyWithoutHorizontalDrift() throws {
        let rows = (1...24).map { "| Row \($0) | A longer cell that wraps naturally at compact width | Done |" }
            .joined(separator: "\n")
        let markdown = """
        Paragraph before the table.

        | Item | Detail | Status |
        | --- | --- | --- |
        \(rows)

        Paragraph after the table.
        """
        let document = try XCTUnwrap(MarkdownResultDocument.parse(markdown))
        let scrollView = MarkdownResultSelectableText.makeScrollView()
        scrollView.frame = NSRect(x: 0, y: 0, width: 320, height: 120)
        let textView = try XCTUnwrap(scrollView.documentView as? MarkdownSelectableTextView)
        textView.replaceContentsIfNeeded(with: MarkdownResultAttributedDocument.build(document))
        scrollView.layoutSubtreeIfNeeded()
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        textView.layoutSubtreeIfNeeded()
        scrollView.layoutSubtreeIfNeeded()

        XCTAssertGreaterThan(textView.frame.height, scrollView.contentSize.height)
        let maximumOffset = max(0, textView.frame.height - scrollView.contentSize.height)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: maximumOffset))
        scrollView.reflectScrolledClipView(scrollView.contentView)

        XCTAssertGreaterThan(scrollView.contentView.bounds.minY, 0)
        XCTAssertEqual(scrollView.contentView.bounds.minX, 0, accuracy: 0.001)
    }

    @MainActor
    func testEquivalentCompletedDocumentDoesNotReplaceTextStorageAgain() throws {
        let document = try XCTUnwrap(MarkdownResultDocument.parse("# Heading\n\n| A | B |\n| --- | --- |\n| 1 | 2 |"))
        let rendered = MarkdownResultAttributedDocument.build(document)
        let textView = MarkdownSelectableTextView(frame: .zero)

        XCTAssertTrue(textView.replaceContentsIfNeeded(with: rendered))
        XCTAssertFalse(textView.replaceContentsIfNeeded(with: NSAttributedString(attributedString: rendered)))
    }

    @MainActor
    func testCompletedMarkdownCopiesCanonicalOrPlainProjectionWithoutMutatingSession() throws {
        let store = makeSessionStore()
        let canonical = "# Heading\n\n**Bold**\n"
        store.installUIAutomationFixture(
            surface: .quickInput,
            sourceText: "# Source",
            translation: canonical,
            state: .completed,
            contentFormat: .semanticMarkdown
        )

        store.copyTranslation(as: .markdown)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "# Heading\n\n**Bold**")
        XCTAssertEqual(store.session?.translation, canonical)
        XCTAssertEqual(store.session?.copyConfirmation, .markdown)

        store.copyTranslation(as: .plainText)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "Heading\n\nBold")
        XCTAssertEqual(store.session?.translation, canonical)
        XCTAssertEqual(store.session?.copyConfirmation, .plainText)
    }

    @MainActor
    func testCopyFeedbackRestartsItsTimerForRepeatedCopies() async throws {
        let store = makeSessionStore()
        store.installUIAutomationFixture(
            surface: .quickInput,
            sourceText: "# Source",
            translation: "# Translation",
            state: .completed,
            contentFormat: .semanticMarkdown
        )

        store.copyTranslation(as: .markdown)
        try await Task.sleep(for: .milliseconds(350))
        store.copyTranslation(as: .plainText)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(store.session?.copyConfirmation, .plainText)

        try await Task.sleep(for: .milliseconds(350))
        XCTAssertNil(store.session?.copyConfirmation)
    }

    func testImageReferencesRemainAltTextWithoutRemoteImageAttributes() throws {
        let document = try XCTUnwrap(
            MarkdownResultDocument.parse("Image: ![diagram](https://example.com/remote.png)")
        )

        XCTAssertEqual(String(document.blocks[0].content.characters), "Image: diagram")
        XCTAssertFalse(document.blocks[0].content.runs.contains { $0.imageURL != nil })
    }

    func testOnlyCompletedSemanticMarkdownUsesRichProjection() {
        var session = makeSession(format: .semanticMarkdown, state: .streaming)
        XCTAssertFalse(session.shouldRenderCompletedMarkdown)

        session.state = .completed
        XCTAssertTrue(session.shouldRenderCompletedMarkdown)

        session.state = .failed(message: "Interrupted")
        XCTAssertFalse(session.shouldRenderCompletedMarkdown)

        session = makeSession(format: .plainText, state: .completed)
        XCTAssertFalse(session.shouldRenderCompletedMarkdown)
    }

    func testEmptyMarkdownFallsBackToRawDisplay() {
        XCTAssertNil(MarkdownResultDocument.parse(""))
    }

    private func makeSession(
        format: TranslationContentFormat,
        state: TranslationSessionState
    ) -> CardSession {
        CardSession(
            id: UUID(),
            surface: .quickInput,
            profileID: nil,
            profileName: "Test",
            sourceContent: TranslationContent(format: format, text: "# Source"),
            translation: "# Translation",
            target: .automatic,
            state: state
        )
    }

    @MainActor
    private func makeSessionStore() -> TranslationSessionStore {
        let suite = "com.marla.markdown-result-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return TranslationSessionStore(
            settings: MarlaSettingsStore(
                defaults: defaults,
                keychain: KeychainCredentialStore(
                    service: "com.marla.markdown-result-tests",
                    account: UUID().uuidString
                )
            )
        )
    }
}
