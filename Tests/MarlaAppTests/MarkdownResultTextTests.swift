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

    @MainActor
    func testCodeStylingUsesCustomRoundedBackgroundAttributes() throws {
        let markdown = """
        First `TOKEN`.
        Second `VALUE`.

        ```zsh
        npm install
        npm run dev
        ```
        """
        let document = try XCTUnwrap(MarkdownResultDocument.parse(markdown))
        let rendered = MarkdownResultAttributedDocument.build(document)

        let inlineRange = (rendered.string as NSString).range(of: "TOKEN")
        XCTAssertNotEqual(inlineRange.location, NSNotFound)
        XCTAssertNil(rendered.attribute(.backgroundColor, at: inlineRange.location, effectiveRange: nil))
        XCTAssertNotNil(rendered.attribute(.marlaInlineCodeBackground, at: inlineRange.location, effectiveRange: nil))

        let blockRange = (rendered.string as NSString).range(of: "npm install")
        XCTAssertNotEqual(blockRange.location, NSNotFound)
        XCTAssertNotNil(rendered.attribute(.marlaCodeBlockBackground, at: blockRange.location, effectiveRange: nil))
        XCTAssertNotNil(rendered.attribute(.marlaCodeBlockBorder, at: blockRange.location, effectiveRange: nil))
        let paragraph = try XCTUnwrap(
            rendered.attribute(.paragraphStyle, at: blockRange.location, effectiveRange: nil)
                as? NSParagraphStyle
        )
        let textBlock = try XCTUnwrap(paragraph.textBlocks.first)
        XCTAssertNil(textBlock.backgroundColor)
        XCTAssertNil(textBlock.borderColor(for: .minX))

        let textView = MarkdownSelectableTextView(frame: .zero)
        textView.textStorage?.setAttributedString(rendered)
        textView.setSelectedRange(NSRange(location: 0, length: rendered.length))
        XCTAssertEqual(
            textView.selectedTextForCopy(),
            rendered.string.removingTrailingLineBreaks()
        )
    }

    @MainActor
    func testInlineCodeBackgroundAddsHorizontalPaddingAndLeavesVerticalSeparation() {
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        let firstGlyphRect = NSRect(x: 10, y: 0, width: 40, height: 24)
        let secondGlyphRect = NSRect(x: 10, y: 24, width: 40, height: 24)

        let first = MarkdownSelectableTextView.inlineCodeBackgroundRect(
            for: firstGlyphRect,
            font: font
        )
        let second = MarkdownSelectableTextView.inlineCodeBackgroundRect(
            for: secondGlyphRect,
            font: font
        )

        XCTAssertEqual(first.minX, firstGlyphRect.minX - 3, accuracy: 0.001)
        XCTAssertEqual(first.maxX, firstGlyphRect.maxX + 3, accuracy: 0.001)
        XCTAssertLessThan(first.height, firstGlyphRect.height)
        XCTAssertLessThan(first.maxY, second.minY)
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

    func testStreamingAndCompletedSemanticMarkdownUseRichProjection() {
        var session = makeSession(format: .semanticMarkdown, state: .streaming)
        XCTAssertTrue(session.shouldRenderMarkdownProjection)
        XCTAssertFalse(session.shouldRenderCompletedMarkdown)

        session.state = .completed
        XCTAssertTrue(session.shouldRenderMarkdownProjection)
        XCTAssertTrue(session.shouldRenderCompletedMarkdown)

        session.state = .failed(message: "Interrupted")
        XCTAssertFalse(session.shouldRenderMarkdownProjection)
        XCTAssertFalse(session.shouldRenderCompletedMarkdown)

        session = makeSession(format: .plainText, state: .completed)
        XCTAssertFalse(session.shouldRenderMarkdownProjection)
        XCTAssertFalse(session.shouldRenderCompletedMarkdown)
    }

    @MainActor
    func testStreamingProjectionKeepsCanonicalMarkdownAndMarksOnlyItsVisualCursor() throws {
        let markdown = "# Heading\n\nA paragraph with **strong"
        var session = makeSession(format: .semanticMarkdown, state: .streaming)
        session.translation = markdown

        let input = try XCTUnwrap(MarkdownProjectionInput(session: session))
        let projection = try XCTUnwrap(MarkdownProjectionSnapshot(input: input))
        var cursorRange = NSRange(location: NSNotFound, length: 0)
        projection.attributedDocument.enumerateAttribute(
            .marlaStreamingCursor,
            in: NSRange(location: 0, length: projection.attributedDocument.length)
        ) { value, range, stop in
            guard value != nil else { return }
            cursorRange = range
            stop.pointee = true
        }

        XCTAssertEqual(input.markdown, markdown)
        XCTAssertEqual(projection.input.phase, .streaming)
        XCTAssertNotEqual(cursorRange.location, NSNotFound)
        XCTAssertFalse(projection.document.plainText.contains("│"))
    }

    @MainActor
    func testThrottledProjectionRemainsValidForNewerDeltaInTheSameSession() throws {
        var session = makeSession(format: .semanticMarkdown, state: .streaming)
        session.translation = "# First snapshot"
        let firstInput = try XCTUnwrap(MarkdownProjectionInput(session: session))
        let firstProjection = try XCTUnwrap(MarkdownProjectionSnapshot(input: firstInput))
        let firstHeight = ResultCardLayout.translationContentHeight(
            session: session,
            cardWidth: 380,
            markdownProjection: firstProjection
        )

        session.translation += "\n\nA newer delta arrives before the throttled projection updates."

        XCTAssertTrue(firstProjection.matches(session))
        XCTAssertEqual(
            ResultCardLayout.translationContentHeight(
                session: session,
                cardWidth: 380,
                markdownProjection: firstProjection
            ),
            firstHeight
        )

        session.state = .completed
        XCTAssertTrue(firstProjection.matches(session))

        let replacement = makeSession(format: .semanticMarkdown, state: .streaming)
        XCTAssertFalse(firstProjection.matches(replacement))

        session.state = .failed(message: "Interrupted")
        XCTAssertFalse(firstProjection.matches(session))
    }

    @MainActor
    func testIncompleteStreamingMarkdownNeverChangesItsCanonicalInput() throws {
        let partials = [
            "# 标题\n\n**尚未闭合",
            "[正在生成的链接](https://example.com",
            "```swift\nlet value = 1",
            "| 阶段 | 状态 |\n| --- | :---: |\n| 构建 | 进行中",
        ]

        for markdown in partials {
            var session = makeSession(format: .semanticMarkdown, state: .streaming)
            session.translation = markdown
            let input = try XCTUnwrap(MarkdownProjectionInput(session: session))

            XCTAssertEqual(input.markdown, markdown)
            if let projection = MarkdownProjectionSnapshot(input: input) {
                XCTAssertEqual(projection.input.markdown, markdown)
                XCTAssertFalse(projection.document.plainText.contains("│"))
            }
        }
    }

    @MainActor
    func testSelectionCopyOmitsTheStreamingCursor() throws {
        var session = makeSession(format: .semanticMarkdown, state: .streaming)
        session.translation = "# Streaming\n\nVisible text"
        let input = try XCTUnwrap(MarkdownProjectionInput(session: session))
        let projection = try XCTUnwrap(MarkdownProjectionSnapshot(input: input))
        let textView = MarkdownSelectableTextView(frame: .zero)
        textView.replaceContentsIfNeeded(with: projection.attributedDocument)
        textView.setSelectedRange(NSRange(location: 0, length: projection.attributedDocument.length))

        let copied = try XCTUnwrap(textView.selectedTextForCopy())
        XCTAssertFalse(copied.contains("│"))
        XCTAssertTrue(copied.contains("Streaming"))
        XCTAssertTrue(copied.contains("Visible text"))
    }

    @MainActor
    func testSourceMarkdownProjectionUsesSemanticSourceWithoutStreamingCursor() throws {
        let markdown = """
        # Source

        Keep **emphasis** and `TOKEN`.

        | Field | Value |
        | --- | :---: |
        | Format | Markdown |
        """
        var session = makeSession(format: .semanticMarkdown, state: .completed)
        session.sourceText = markdown

        let input = try XCTUnwrap(SourceMarkdownProjectionInput(session: session))
        let projection = try XCTUnwrap(SourceMarkdownProjectionSnapshot(input: input))

        XCTAssertEqual(input.markdown, markdown)
        XCTAssertTrue(projection.document.blocks.contains { block in
            if case .table = block.kind { return true }
            return false
        })
        XCTAssertFalse(projection.attributedDocument.string.contains("│"))
        XCTAssertTrue(projection.matches(session))

        session.sourceText += "\nChanged"
        XCTAssertFalse(projection.matches(session))
    }

    @MainActor
    func testSourceMarkdownProjectionRejectsPlainTextSource() {
        let session = makeSession(format: .plainText, state: .completed)
        XCTAssertNil(SourceMarkdownProjectionInput(session: session))
    }

    @MainActor
    func testSourceMarkdownViewportUsesAttributedDocumentAndKeepsTheCap() throws {
        let rows = (1 ... 20).map { "| \($0) | A source value that wraps naturally |" }
        let markdown = ([
            "# Source table",
            "",
            "| Step | Value |",
            "| ---: | :--- |",
        ] + rows).joined(separator: "\n")
        var session = makeSession(format: .semanticMarkdown, state: .completed)
        session.sourceText = markdown
        session.isComparisonExpanded = true
        let input = try XCTUnwrap(SourceMarkdownProjectionInput(session: session))
        let projection = try XCTUnwrap(SourceMarkdownProjectionSnapshot(input: input))
        let measured = MarkdownResultAttributedDocument.measuredHeight(
            projection.attributedDocument,
            width: 380 - ResultCardLayout.outerHorizontalPadding
        )
        let viewport = ResultCardLayout.sourceViewportHeight(
            session: session,
            cardWidth: 380,
            sourceMarkdownProjection: projection
        )

        XCTAssertGreaterThan(measured, ResultCardLayout.maximumSourceViewportHeight)
        XCTAssertEqual(viewport, ResultCardLayout.maximumSourceViewportHeight)
    }

    @MainActor
    func testProjectedMarkdownHeightUsesTheSameAttributedDocumentAtBothWidths() throws {
        let markdown = """
        # Release Notes

        A paragraph whose rendered spacing and heading font differ from raw Markdown text measurement.

        | Capability | Current behavior |
        | :--- | :---: |
        | Streaming | The native projection grows with the visible document and wraps long cells naturally. |
        | Completion | The final document is measured again after the streaming cursor disappears. |
        """
        var session = makeSession(format: .semanticMarkdown, state: .streaming)
        session.translation = markdown
        let streamingInput = try XCTUnwrap(MarkdownProjectionInput(session: session))
        let streamingProjection = try XCTUnwrap(MarkdownProjectionSnapshot(input: streamingInput))
        let maximumHeight: CGFloat = 700

        let narrowContentHeight = ResultCardLayout.translationContentHeight(
            session: session,
            cardWidth: 380,
            markdownProjection: streamingProjection
        )
        let wideContentHeight = ResultCardLayout.translationContentHeight(
            session: session,
            cardWidth: 760,
            markdownProjection: streamingProjection
        )
        let measuredNarrow = MarkdownResultAttributedDocument.measuredHeight(
            streamingProjection.attributedDocument,
            width: 380 - ResultCardLayout.outerHorizontalPadding
        )

        XCTAssertEqual(narrowContentHeight, measuredNarrow, accuracy: 0.5)
        XCTAssertGreaterThan(narrowContentHeight, wideContentHeight)

        let streamingPanelHeight = ResultCardLayout.preferredPanelHeight(
            session: session,
            cardWidth: 380,
            maximumPanelHeight: maximumHeight,
            markdownProjection: streamingProjection
        )

        session.state = .completed
        let completedInput = try XCTUnwrap(MarkdownProjectionInput(session: session))
        let completedProjection = try XCTUnwrap(MarkdownProjectionSnapshot(input: completedInput))
        let completedPanelHeight = ResultCardLayout.preferredPanelHeight(
            session: session,
            cardWidth: 380,
            maximumPanelHeight: maximumHeight,
            markdownProjection: completedProjection
        )
        let completedViewportHeight = ResultCardLayout.translationViewportHeight(
            session: session,
            cardWidth: 380,
            maximumPanelHeight: maximumHeight,
            markdownProjection: completedProjection
        )

        XCTAssertEqual(
            completedPanelHeight,
            ResultCardLayout.fixedChromeHeight() + completedViewportHeight,
            accuracy: 0.5
        )
        XCTAssertLessThanOrEqual(completedPanelHeight, maximumHeight)
        XCTAssertLessThanOrEqual(abs(streamingPanelHeight - completedPanelHeight), 24)
        XCTAssertEqual(completedProjection.input.markdown, markdown)
    }

    @MainActor
    func testLongStreamingMarkdownStillCapsAtTheVisibleWorkspaceLimit() throws {
        let rows = (1 ... 80).map { "| \($0) | A long streaming value that must wrap inside the result card |" }
        let markdown = ([
            "# Streaming table",
            "",
            "| Step | Result |",
            "| ---: | :--- |",
        ] + rows).joined(separator: "\n")
        var session = makeSession(format: .semanticMarkdown, state: .streaming)
        session.translation = markdown
        let input = try XCTUnwrap(MarkdownProjectionInput(session: session))
        let projection = try XCTUnwrap(MarkdownProjectionSnapshot(input: input))
        let maximumHeight: CGFloat = 540
        let contentHeight = ResultCardLayout.translationContentHeight(
            session: session,
            cardWidth: 380,
            markdownProjection: projection
        )
        let viewportHeight = ResultCardLayout.translationViewportHeight(
            session: session,
            cardWidth: 380,
            maximumPanelHeight: maximumHeight,
            markdownProjection: projection
        )
        let panelHeight = ResultCardLayout.preferredPanelHeight(
            session: session,
            cardWidth: 380,
            maximumPanelHeight: maximumHeight,
            markdownProjection: projection
        )

        XCTAssertGreaterThan(contentHeight, viewportHeight)
        XCTAssertEqual(panelHeight, maximumHeight)
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
