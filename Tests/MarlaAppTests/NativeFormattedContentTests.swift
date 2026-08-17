import AppKit
import ApplicationServices
import MarlaCore
@testable import MarlaApp
import XCTest

@MainActor
final class NativeFormattedContentTests: XCTestCase {
    func testHTMLPasteboardContentBecomesSanitizedSemanticMarkdown() throws {
        let item = NSPasteboardItem()
        let html = """
        <article>
          <h1>Release notes</h1>
          <p>Read <strong>important</strong> <a href="https://example.com/docs">docs</a>.</p>
          <ul><li>First</li><li>Use <code>MARLA_API_KEY</code></li></ul>
          <blockquote>Keep context.</blockquote>
          <script>window.location = 'https://tracker.example'</script>
          <img src="https://tracker.example/pixel.png" alt="diagram">
        </article>
        """
        item.setData(Data(html.utf8), forType: .html)
        item.setString(
            "Release notes\nRead important docs.\nFirst\nUse MARLA_API_KEY\nKeep context.",
            forType: .string
        )

        let content = try XCTUnwrap(NativeFormattedContentNormalizer.content(from: [item]))

        XCTAssertEqual(content.format, .semanticMarkdown)
        XCTAssertTrue(content.text.contains("# Release notes"), content.text)
        XCTAssertTrue(content.text.contains("**important**"), content.text)
        XCTAssertTrue(content.text.contains("[docs](https://example.com/docs)"), content.text)
        XCTAssertTrue(content.text.contains("- First"), content.text)
        XCTAssertTrue(content.text.contains("`MARLA_API_KEY`"), content.text)
        XCTAssertTrue(content.text.contains("> Keep context."), content.text)
        XCTAssertFalse(content.text.contains("diagram"), content.text)
        XCTAssertFalse(content.text.contains("tracker.example"), content.text)
        XCTAssertFalse(content.text.contains("script"), content.text)
    }

    func testHTMLMixedParagraphsAndTableBecomeOneSemanticMarkdownDocument() throws {
        let item = NSPasteboardItem()
        let html = """
        <article>
          <p>Complete the following checks before Friday.</p>
          <table>
            <thead><tr><th>Item</th><th>Expected</th><th>Actual</th></tr></thead>
            <tbody>
              <tr><td>Build number</td><td>${BUILD_ID}</td><td>{{BUILD_ID}}</td></tr>
              <tr><td>Status</td><td>ready</td><td>{{STATUS}}</td></tr>
            </tbody>
          </table>
          <p>Finish with one conclusion.</p>
        </article>
        """
        item.setData(Data(html.utf8), forType: .html)
        item.setString(
            "Complete the following checks before Friday.\nItem\nExpected\nActual\nBuild number\n${BUILD_ID}\n{{BUILD_ID}}\nStatus\nready\n{{STATUS}}\nFinish with one conclusion.",
            forType: .string
        )

        let content = try XCTUnwrap(NativeFormattedContentNormalizer.content(from: [item]))

        XCTAssertEqual(content.format, .semanticMarkdown)
        XCTAssertTrue(content.text.contains("Complete the following checks before Friday."), content.text)
        XCTAssertTrue(content.text.contains("| Item | Expected | Actual |"), content.text)
        XCTAssertTrue(content.text.contains("| Build number | $\\{BUILD\\_ID\\} | \\{\\{BUILD\\_ID\\}\\} |"), content.text)
        XCTAssertTrue(content.text.contains("Finish with one conclusion."), content.text)
    }

    func testLiteralPlainHTMLTableBecomesSemanticMarkdownBeforeTranslation() throws {
        let item = NSPasteboardItem()
        let literalHTML = #"<table border="1"><tr><td>Item</td><td>Expected</td><td>Actual</td></tr><tr><td>Build number</td><td>${BUILD_ID}$</td><td>${BUILD_ID}$</td></tr><tr><td>Minimum system</td><td>macOS 14</td><td>${MIN_OS}$</td></tr><tr><td>Status</td><td>ready</td><td>${STATUS}$</td></tr></table>"#
        item.setString(literalHTML, forType: .string)

        let content = try XCTUnwrap(NativeFormattedContentNormalizer.content(from: [item]))

        XCTAssertEqual(content.format, .semanticMarkdown)
        XCTAssertEqual(
            content.text,
            """
            | Item | Expected | Actual |
            | --- | --- | --- |
            | Build number | ${BUILD_ID}$ | ${BUILD_ID}$ |
            | Minimum system | macOS 14 | ${MIN_OS}$ |
            | Status | ready | ${STATUS}$ |
            """
        )
    }

    func testLiteralHTMLTablePreservesMixedTextEntitiesPipesAndEmptyCells() throws {
        let item = NSPasteboardItem()
        let literalHTML = """
        Before the table.
        <table>
          <tr><th>Name</th><th>Value</th><th>Empty</th></tr>
          <tr><td>A &amp; B</td><td>left | right</td><td></td></tr>
        </table>
        After the table.
        """
        item.setString(literalHTML, forType: .string)

        let content = try XCTUnwrap(NativeFormattedContentNormalizer.content(from: [item]))

        XCTAssertEqual(content.format, .semanticMarkdown)
        XCTAssertEqual(
            content.text,
            """
            Before the table.

            | Name | Value | Empty |
            | --- | --- | --- |
            | A & B | left \\| right |  |

            After the table.
            """
        )
    }

    func testLiteralHTMLTableUsesTheSharedPlainTextBoundary() throws {
        let literalHTML = "<table><tr><td>Key</td><td>Value</td></tr><tr><td>ID</td><td>${ID}$</td></tr></table>"

        let content = try XCTUnwrap(
            NativeFormattedContentNormalizer.content(from: literalHTML as CFString)
        )

        XCTAssertEqual(content.format, .semanticMarkdown)
        XCTAssertTrue(content.text.contains("| ID | ${ID}$ |"), content.text)
    }

    func testLiteralHTMLTableRejectsComplexMalformedEmptyAndCodeExamples() throws {
        let unsupportedSamples = [
            "<table><tr><td rowspan=\"2\">A</td><td>B</td></tr><tr><td>C</td></tr></table>",
            "<table><tr><td>A</td></tr><tr><td>B</td><td>C</td></tr></table>",
            "<table><tr><td>Outer<table><tr><td>Inner</td></tr></table></td></tr></table>",
            "<table><tr><td>Missing close</tr></table>",
            "<table><tr><td></td></tr></table>",
            "<table><tr><td>Visible</td></tr><span>Dropped text</span></table>",
            "```html\n<table><tr><td>Code example</td></tr></table>\n```",
            "```html\n~~~\n<table><tr><td>Still fenced</td></tr></table>\n```",
            "Use ``<table><tr><td>inline code</td></tr></table>`` as an example.",
            "Use <T> for a generic type, not a table.",
        ]

        for sample in unsupportedSamples {
            let item = NSPasteboardItem()
            item.setString(sample, forType: .string)

            XCTAssertEqual(
                NativeFormattedContentNormalizer.content(from: [item]),
                .plainText(sample),
                sample
            )
        }
    }

    func testHTMLVisibleTextMismatchFallsBackToPlainText() throws {
        let item = NSPasteboardItem()
        item.setData(Data("<p>Visible</p><p>Unexpected hidden payload</p>".utf8), forType: .html)
        item.setString("Visible", forType: .string)

        let content = try XCTUnwrap(NativeFormattedContentNormalizer.content(from: [item]))

        XCTAssertEqual(content, .plainText("Visible"))
    }

    func testHTMLDropsHiddenNodesAndUnsafeLinkTargets() throws {
        let item = NSPasteboardItem()
        let html = """
        <div>
          <p><a href="javascript:alert('x')">Open</a> safely</p>
          <p hidden>Secret</p>
          <p style="display : none !important">Also secret</p>
          <p style="content-visibility: hidden">Deferred secret</p>
          <p style="opacity: 0">Transparent secret</p>
        </div>
        """
        item.setData(Data(html.utf8), forType: .html)
        item.setString("Open safely", forType: .string)

        let content = try XCTUnwrap(NativeFormattedContentNormalizer.content(from: [item]))

        XCTAssertEqual(content.text, "Open safely")
        XCTAssertFalse(content.text.contains("javascript"))
        XCTAssertFalse(content.text.contains("Secret"))
        XCTAssertFalse(content.text.contains("Deferred"))
        XCTAssertFalse(content.text.contains("Transparent"))
    }

    func testRTFAttributesBecomeSemanticMarkdown() throws {
        let source = NSMutableAttributedString(string: "Important docs")
        source.addAttribute(
            .font,
            value: NSFont.boldSystemFont(ofSize: 14),
            range: NSRange(location: 0, length: 9)
        )
        source.addAttribute(
            .link,
            value: URL(string: "https://example.com/docs")!,
            range: NSRange(location: 10, length: 4)
        )
        let data = try source.data(
            from: NSRange(location: 0, length: source.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        let item = NSPasteboardItem()
        item.setData(data, forType: .rtf)
        item.setString(source.string, forType: .string)

        let content = try XCTUnwrap(NativeFormattedContentNormalizer.content(from: [item]))

        XCTAssertEqual(content.format, .semanticMarkdown)
        XCTAssertTrue(content.text.contains("**Important**"), content.text)
        XCTAssertTrue(content.text.contains("[docs](https://example.com/docs)"), content.text)
    }

    func testRTFDRepresentationBecomesSemanticMarkdownWithoutPlainProjection() throws {
        let source = NSAttributedString(
            string: "Important",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 14)]
        )
        let data = try source.data(
            from: NSRange(location: 0, length: source.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
        )
        let item = NSPasteboardItem()
        item.setData(data, forType: .rtfd)

        let content = try XCTUnwrap(NativeFormattedContentNormalizer.content(from: [item]))

        XCTAssertEqual(content, .semanticMarkdown("**Important**"))
    }

    func testAttributedMarkdownPresentationIntentsPreserveBlocks() throws {
        let markdown = "# Heading\n\n- **Bold** [link](https://example.com)"
        let attributed = NSAttributedString(try AttributedString(markdown: markdown))

        let content = try XCTUnwrap(NativeFormattedContentNormalizer.content(from: attributed))

        XCTAssertEqual(content.format, .semanticMarkdown)
        XCTAssertTrue(content.text.contains("# Heading"), content.text)
        XCTAssertTrue(content.text.contains("- **Bold** [link](https://example.com)"), content.text)
    }

    func testPlainAttributedTextHonestlyDegradesToPlainText() throws {
        let attributed = NSAttributedString(
            string: "Plain text",
            attributes: [.font: NSFont.systemFont(ofSize: 14)]
        )

        let content = try XCTUnwrap(NativeFormattedContentNormalizer.content(from: attributed))

        XCTAssertEqual(content, .plainText("Plain text"))
    }

    func testAccessibilityAttributedKeysPreserveFontAndListSemantics() throws {
        let source = NSMutableAttributedString(string: "Important\nFirst item")
        source.addAttribute(
            NSAttributedString.Key("AXFont"),
            value: [
                "AXFontName": "Helvetica-Bold",
                "AXFontSize": 14
            ],
            range: NSRange(location: 0, length: 9)
        )
        let itemRange = NSRange(location: 10, length: 10)
        source.addAttribute(
            NSAttributedString.Key("AXListItemPrefix"),
            value: NSAttributedString(string: "•"),
            range: itemRange
        )
        source.addAttribute(
            NSAttributedString.Key("AXListItemIndex"),
            value: 0,
            range: itemRange
        )
        source.addAttribute(
            NSAttributedString.Key("AXListItemLevel"),
            value: 0,
            range: itemRange
        )

        let content = try XCTUnwrap(NativeFormattedContentNormalizer.content(from: source))

        XCTAssertEqual(content.format, .semanticMarkdown)
        XCTAssertTrue(content.text.contains("**Important**"), content.text)
        XCTAssertTrue(content.text.contains("- First item"), content.text)
    }

    func testExplicitMarkdownRepresentationTakesPriorityOverPlainProjection() throws {
        let item = NSPasteboardItem()
        item.setString("# Heading\n\n**Bold**", forType: .init("net.daringfireball.markdown"))
        item.setString("Heading\nBold", forType: .string)

        let content = try XCTUnwrap(NativeFormattedContentNormalizer.content(from: [item]))

        XCTAssertEqual(content, .semanticMarkdown("# Heading\n\n**Bold**"))
    }

    func testExplicitGFMTableMatchesRenderedPlainProjection() throws {
        let item = NSPasteboardItem()
        let markdown = """
        #### Acceptance Items

        - [ ] Heading and list hierarchy is correct
        - [ ] Inline code `MARLA_API_KEY` is not translated

        | Item | Expected | Actual |
        | --- | --- | --- |
        | Build number | `${BUILD_ID}` | `{{BUILD_ID}}` |
        | Minimum system | macOS 14 | `{{MIN_OS}}` |
        | Status | ready | `{{STATUS}}` |
        """
        let visiblePlainText = """
        Acceptance Items
        Heading and list hierarchy is correct
        Inline code MARLA_API_KEY is not translated
        Item\tExpected\tActual
        Build number\t${BUILD_ID}\t{{BUILD_ID}}
        Minimum system\tmacOS 14\t{{MIN_OS}}
        Status\tready\t{{STATUS}}
        """
        item.setString(markdown, forType: .init("net.daringfireball.markdown"))
        item.setString(visiblePlainText, forType: .string)

        let content = try XCTUnwrap(NativeFormattedContentNormalizer.content(from: [item]))

        XCTAssertEqual(content, .semanticMarkdown(markdown))
    }

    func testExplicitGFMTableMatchesFluxCheckboxObjectProjection() throws {
        let item = NSPasteboardItem()
        let markdown = """
        ### Acceptance Items

        - [ ] Heading and list hierarchy is correct
        - [ ] Link destinations are unchanged
        - [ ] Inline code `MARLA_API_KEY` is not translated
        - [ ] The copied result remains complete Markdown

        | Item | Expected | Actual |
        | --- | --- | --- |
        | Build number | `${BUILD_ID}` | `{{BUILD_ID}}` |
        | Minimum system | macOS 14 | `{{MIN_OS}}` |
        | Status | ready | `{{STATUS}}` |
        """
        let fluxPlainText = """
        Acceptance Items

        \u{FFFC} Heading and list hierarchy is correct
        \u{FFFC} Link destinations are unchanged
        \u{FFFC} Inline code MARLA_API_KEY is not translated
        \u{FFFC} The copied result remains complete Markdown
        Item\tExpected\tActual
        Build number\t${BUILD_ID}\t{{BUILD_ID}}
        Minimum system\tmacOS 14\t{{MIN_OS}}
        Status\tready\t{{STATUS}}
        """
        item.setString(markdown, forType: .init("net.daringfireball.markdown"))
        item.setString(fluxPlainText, forType: .string)

        let content = try XCTUnwrap(NativeFormattedContentNormalizer.content(from: [item]))

        XCTAssertEqual(content, .semanticMarkdown(markdown))
    }

    func testFluxUTF8HTMLWithRawNonbreakingSpacesPreservesTableStructure() throws {
        let item = NSPasteboardItem()
        let html = """
        <article>
          <h3>Acceptance Items</h3>
          <ul>
            <li><input type="checkbox"> Heading and list hierarchy is correct</li>
            <li><input type="checkbox"> Link destinations are unchanged</li>
            <li><input type="checkbox"> Inline code <code>MARLA_API_KEY</code> is not translated</li>
            <li><input type="checkbox"> The copied result remains complete Markdown</li>
          </ul>
          <table>
            <thead><tr><th>Item</th><th>Expected</th><th>Actual</th></tr></thead>
            <tbody>
              <tr><td>Build number</td><td><code>${BUILD_ID}</code></td><td><code>{{BUILD_ID}}</code></td></tr>
              <tr><td>Minimum system</td><td>macOS 14</td><td><code>{{MIN_OS}}</code></td></tr>
              <tr><td>Status</td><td>ready</td><td><code>{{STATUS}}</code></td></tr>
            </tbody>
          </table>
        </article>
        """
        let fluxPlainText = """
        Acceptance Items

        \u{FFFC} Heading and list hierarchy is correct
        \u{FFFC} Link destinations are unchanged
        \u{FFFC} Inline code MARLA_API_KEY is not translated
        \u{FFFC} The copied result remains complete Markdown
        Item\tExpected\tActual
        Build number\t${BUILD_ID}\t{{BUILD_ID}}
        Minimum system\tmacOS 14\t{{MIN_OS}}
        Status\tready\t{{STATUS}}
        """
        item.setData(Data(html.utf8), forType: .html)
        item.setString(fluxPlainText, forType: .string)

        let content = try XCTUnwrap(NativeFormattedContentNormalizer.content(from: [item]))
        let document = try XCTUnwrap(MarkdownResultDocument.parse(content.text))

        XCTAssertEqual(content.format, .semanticMarkdown)
        XCTAssertEqual(document.blocks.filter { if case .table = $0.kind { true } else { false } }.count, 1)
        XCTAssertTrue(content.text.contains("| Item | Expected | Actual |"), content.text)
        XCTAssertTrue(content.text.contains("| Status | ready | `{{STATUS}}` |"), content.text)
    }

    func testExplicitGFMTableStillRejectsIncompletePlainProjection() throws {
        let item = NSPasteboardItem()
        let markdown = """
        | Item | Expected | Actual |
        | --- | --- | --- |
        | Build number | `${BUILD_ID}` | `{{BUILD_ID}}` |
        """
        let incompletePlainText = "Item\tExpected\tActual"
        item.setString(markdown, forType: .init("net.daringfireball.markdown"))
        item.setString(incompletePlainText, forType: .string)

        let content = try XCTUnwrap(NativeFormattedContentNormalizer.content(from: [item]))

        XCTAssertEqual(content, .plainText(incompletePlainText))
    }

    func testExplicitMarkdownMismatchFallsBackToVisiblePlainText() throws {
        let item = NSPasteboardItem()
        item.setString("# Visible\n\nInjected", forType: .init("net.daringfireball.markdown"))
        item.setString("Visible", forType: .string)

        let content = try XCTUnwrap(NativeFormattedContentNormalizer.content(from: [item]))

        XCTAssertEqual(content, .plainText("Visible"))
    }

    func testQuickInputEditorInsertsRichPasteAsMarkdownAtSelection() {
        let editor = MarkdownPasteTextView(frame: .zero)
        editor.string = "Before after"
        editor.setSelectedRange(NSRange(location: 7, length: 0))
        editor.richPasteContent = { .semanticMarkdown("**bold** ") }

        editor.paste(nil)

        XCTAssertEqual(editor.string, "Before **bold** after")
        XCTAssertEqual(editor.selectedRange().location, 16)
    }

    func testQuickInputEditorInsertsNormalizedPlainFallbackOverSelection() {
        let editor = MarkdownPasteTextView(frame: .zero)
        editor.string = "Before unsafe after"
        editor.setSelectedRange(NSRange(location: 7, length: 6))
        editor.richPasteContent = { .plainText("safe") }

        editor.paste(nil)

        XCTAssertEqual(editor.string, "Before safe after")
        XCTAssertEqual(editor.selectedRange().location, 11)
    }
}
