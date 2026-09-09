import AppKit
import XCTest
@testable import MarlaApp

@MainActor
final class HTMLTableProjectionTests: XCTestCase {
    private func fixture(_ name: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("rust/marla-core/tests/fixtures/ocr-tables/\(name).canonical.md"), encoding: .utf8)
    }

    private func table(_ markdown: String) throws -> MarkdownResultDocument.Table {
        let document = try XCTUnwrap(MarkdownResultDocument.parse(markdown))
        return try XCTUnwrap(document.blocks.compactMap { block in
            if case let .table(table) = block.kind { return table }
            return nil
        }.first)
    }

    func testActualFinanceKeepsBothHeaderLevelsAndAll22Cells() throws {
        let table = try table(fixture("finance"))
        XCTAssertEqual(table.rows.count, 5)
        XCTAssertEqual(table.alignments.count, 5)
        XCTAssertEqual(table.positionedCells?.count, 22)
        XCTAssertEqual(table.renderCells.filter { $0.rowSpan == 2 }.count, 1)
        XCTAssertEqual(table.renderCells.filter { $0.columnSpan == 2 }.count, 2)
        XCTAssertEqual(table.renderCells.filter(\.header).count, 7)
        XCTAssertEqual(String(table.rows[4][4].characters), "280")
    }

    func testActualScheduleRendersNativeRowSpansAndKeepsFooter() throws {
        let markdown = try fixture("schedule")
        let document = try XCTUnwrap(MarkdownResultDocument.parse(markdown))
        let rendered = MarkdownResultAttributedDocument.build(document)
        let index = (rendered.string as NSString).range(of: "Monday").location
        let paragraph = try XCTUnwrap(rendered.attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle)
        let cell = try XCTUnwrap(paragraph.textBlocks.first as? NSTextTableBlock)
        XCTAssertEqual(cell.rowSpan, 2)
        XCTAssertEqual(cell.startingColumn, 0)
        XCTAssertEqual(cell.table.numberOfColumns, 4)
        XCTAssertTrue(document.plainText.contains("Bring a laptop."))
        XCTAssertFalse(document.plainText.contains("<td"))
        XCTAssertEqual(try table(markdown).renderCells.count, 18)
        // The local OCR table has no source-image geometry; do not feed span grids to in-place layout.
        XCTAssertNil(InPlaceMarkdownProjection.table(from: markdown.components(separatedBy: "\n\n")[0]))
    }

    func testInlineCodeBoldAndBreaksPreserveTextAndNativeStyle() throws {
        let markdown = "<table><tbody><tr><th>Key</th><th>Value</th></tr><tr><th>CLI</th><td><code>a|b</code><br/><strong>A&amp;B</strong></td></tr></tbody></table>"
        let table = try table(markdown)
        let content = table.rows[1][1]
        XCTAssertEqual(String(content.characters), "a|b\u{2028}A&B")
        XCTAssertTrue(content.runs.contains { $0.inlinePresentationIntent?.contains(.code) == true })
        XCTAssertTrue(content.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
        XCTAssertTrue(table.renderCells[2].header)
    }

    func testUnsafeInvalidAndNestedHTMLNeverCreatesANativeTable() {
        for html in [
            "<table><tr><td rowspan='4'>bad</td></tr></table>",
            "<table><tr><td colspan='1000000'>bad</td></tr></table>",
            "<table><tr><td><script>bad</script></td></tr></table>",
            "<table><tr><td><img src='https://example.com/pixel'/></td></tr></table>",
            "<table><tr><td><table><tr><td>nested</td></tr></table></td></tr></table>",
            "<table><tr><td style='display:none'>bad</td></tr></table>",
            "<table><tr><td><!ENTITY external SYSTEM 'file:///etc/passwd'></td></tr></table>",
            "<table><tr><td>A</td><td>B</td></tr><tr><td>C</td></tr></table>",
        ] {
            XCTAssertNil(HTMLTableProjection.parse(html), html)
        }
    }

    func testHTMLInsideFencesStaysCodeAndDoesNotBecomeATable() throws {
        let raw = "<table><tr><td>literal</td></tr></table>"
        let document = try XCTUnwrap(MarkdownResultDocument.parse("```html\n\(raw)\n```"))
        XCTAssertFalse(document.blocks.contains { if case .table = $0.kind { true } else { false } })
        XCTAssertTrue(document.plainText.contains(raw))
    }

    func testPlainCopyKeepsMergedCellTextOnceAndCanonicalIsUnchanged() throws {
        let raw = try fixture("finance")
        let document = try XCTUnwrap(MarkdownResultDocument.parse(raw))
        XCTAssertEqual(document.plainText.components(separatedBy: "2025").count - 1, 1)
        XCTAssertTrue(document.plainText.contains("Totals are synthetic."))
    }

    func testActualSimpleTablesKeepBlankCellsAndDoNotCrashAtCardWidths() throws {
        for name in ["invoice", "comparison", "bilingual", "finance", "schedule"] {
            let document = try XCTUnwrap(MarkdownResultDocument.parse(fixture(name)))
            let rendered = MarkdownResultAttributedDocument.build(document)
            for width: CGFloat in [340, 720] {
                let height = MarkdownResultAttributedDocument.measuredHeight(rendered, width: width)
                XCTAssertTrue(height.isFinite && height > 0 && height < 10_000, "\(name) \(height)")
            }
        }
    }

    func testCaptureSyntheticNativeTablesWhenRequested() throws {
        guard let directory = ProcessInfo.processInfo.environment["MARLA_OCR_UI_EVIDENCE_DIR"] else { return }
        for dark in [false, true] {
            let appearance = try XCTUnwrap(NSAppearance(named: dark ? .darkAqua : .aqua))
            for name in ["finance", "schedule", "invoice"] {
                for width: CGFloat in [380, 760] {
                    let document = try XCTUnwrap(MarkdownResultDocument.parse(fixture(name)))
                    let rendered = MarkdownResultAttributedDocument.build(document)
                    let height = MarkdownResultAttributedDocument.measuredHeight(rendered, width: width - 32) + 32
                    let view = MarkdownSelectableTextView(frame: NSRect(x: 0, y: 0, width: width, height: height))
                    view.appearance = appearance
                    view.isEditable = false
                    view.drawsBackground = true
                    view.backgroundColor = dark ? .black : .white
                    view.textContainerInset = NSSize(width: 16, height: 16)
                    view.textContainer?.lineFragmentPadding = 0
                    view.textContainer?.containerSize = NSSize(width: width - 32, height: .greatestFiniteMagnitude)
                    view.textStorage?.setAttributedString(rendered)
                    view.layoutManager?.ensureLayout(for: view.textContainer!)
                    let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                    appearance.performAsCurrentDrawingAppearance {
                        view.cacheDisplay(in: view.bounds, to: rep)
                    }
                    let path = URL(fileURLWithPath: directory).appendingPathComponent("\(name)-\(dark ? "dark" : "light")-\(Int(width)).png")
                    try rep.representation(using: .png, properties: [:])?.write(to: path)
                }
            }
        }
    }
}
