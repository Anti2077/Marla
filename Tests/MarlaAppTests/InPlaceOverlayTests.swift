import AppKit
import MarlaCore
import XCTest
@testable import MarlaApp

@MainActor
final class InPlaceOverlayTests: XCTestCase {
    func testLayoutFlipsTopOriginOCRBoundsIntoAppKitCoordinates() throws {
        let document = OCRDocument(blocks: [
            ContentBlock(
                id: "heading-0",
                kind: .heading,
                sourceText: "Heading",
                bounds: NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.25),
                readingOrder: 0
            )
        ])
        let layout = try InPlaceOverlayLayoutBuilder.make(
            document: document,
            translation: InPlaceTranslationResult(blocks: [
                InPlaceTranslatedBlock(id: "heading-0", text: "标题")
            ]),
            canvasSize: CGSize(width: 1_000, height: 800)
        )

        XCTAssertEqual(layout.blocks[0].sourceFrame.minX, 100, accuracy: 0.001)
        XCTAssertEqual(layout.blocks[0].sourceFrame.minY, 440, accuracy: 0.001)
        XCTAssertEqual(layout.blocks[0].sourceFrame.width, 300, accuracy: 0.001)
        XCTAssertEqual(layout.blocks[0].sourceFrame.height, 200, accuracy: 0.001)
        XCTAssertTrue(layout.blocks[0].frame.contains(layout.blocks[0].sourceFrame))
        XCTAssertGreaterThan(layout.blocks[0].fontSize, 8)
    }

    func testLayoutPreservesHeadingAndCodeTypographyRoles() throws {
        let document = OCRDocument(blocks: [
            ContentBlock(
                id: "heading",
                kind: .heading,
                sourceText: "Install",
                bounds: NormalizedRect(x: 0.05, y: 0.05, width: 0.9, height: 0.18),
                readingOrder: 0
            ),
            ContentBlock(
                id: "code",
                kind: .code,
                sourceText: "npm test",
                bounds: NormalizedRect(x: 0.05, y: 0.45, width: 0.9, height: 0.18),
                readingOrder: 1
            )
        ])
        let layout = try InPlaceOverlayLayoutBuilder.make(
            document: document,
            translation: InPlaceTranslationResult(blocks: [
                InPlaceTranslatedBlock(id: "heading", text: "安装"),
                InPlaceTranslatedBlock(id: "code", text: "npm test")
            ]),
            canvasSize: CGSize(width: 600, height: 400)
        )

        XCTAssertGreaterThan(layout.blocks[0].fontSize, layout.blocks[1].fontSize)
        XCTAssertFalse(layout.blocks[0].usesMonospacedFont)
        XCTAssertTrue(layout.blocks[1].usesMonospacedFont)
    }

    func testLayoutProjectsMarkdownHeadingToVisibleText() throws {
        let layout = try InPlaceOverlayLayoutBuilder.make(
            document: OCRDocument(blocks: [
                ContentBlock(
                    id: "heading",
                    kind: .heading,
                    sourceText: "## Why Quantum Leap",
                    bounds: NormalizedRect(x: 0.05, y: 0.05, width: 0.9, height: 0.2),
                    readingOrder: 0
                )
            ]),
            translation: InPlaceTranslationResult(blocks: [
                InPlaceTranslatedBlock(id: "heading", text: "## 为什么选择量子跃迁")
            ]),
            canvasSize: CGSize(width: 640, height: 240)
        )

        XCTAssertEqual(layout.blocks.count, 1)
        XCTAssertEqual(layout.blocks[0].text, "为什么选择量子跃迁")
        XCTAssertFalse(layout.blocks[0].text.contains("#"))
    }

    func testLayoutExpandsSingleGFMTableBlockIntoNativeCells() throws {
        let source = """
        | # | Capability | What it gives you |
        | :---: | :--- | ---: |
        | 1 | Flexible topology | Local or remote tests |
        """
        let translated = """
        | 编号 | 能力 | 它能为您带来什么 |
        | :---: | :--- | ---: |
        | 1 | 灵活拓扑 | 本地或远程测试 |
        """
        let layout = try InPlaceOverlayLayoutBuilder.make(
            document: OCRDocument(blocks: [
                ContentBlock(
                    id: "table",
                    kind: .table,
                    sourceText: source,
                    bounds: NormalizedRect(x: 0.05, y: 0.1, width: 0.9, height: 0.8),
                    readingOrder: 0
                )
            ]),
            translation: InPlaceTranslationResult(blocks: [
                InPlaceTranslatedBlock(id: "table", text: translated)
            ]),
            canvasSize: CGSize(width: 720, height: 240)
        )

        XCTAssertEqual(layout.blocks.count, 6)
        XCTAssertEqual(layout.renderedSourceBlockCount, 1)
        XCTAssertEqual(layout.omittedBlockCount, 0)
        XCTAssertTrue(layout.blocks.allSatisfy { $0.tableCell != nil })
        XCTAssertTrue(layout.blocks.allSatisfy { !$0.text.contains("|") && !$0.text.contains("---") })

        let header = try XCTUnwrap(layout.blocks.first { $0.tableCell?.row == 0 && $0.tableCell?.column == 0 })
        let body = try XCTUnwrap(layout.blocks.first { $0.tableCell?.row == 1 && $0.tableCell?.column == 0 })
        XCTAssertGreaterThan(header.frame.minY, body.frame.minY)
        XCTAssertEqual(header.tableCell?.alignment, .center)
        let firstColumn = layout.blocks.filter { $0.tableCell?.column == 0 }
        let secondColumn = layout.blocks.filter { $0.tableCell?.column == 1 }
        XCTAssertLessThanOrEqual(
            firstColumn.map(\.frame.maxX).max() ?? 0,
            secondColumn.map(\.frame.minX).min() ?? 0
        )
    }

    func testLayoutProjectsRealGLMHeadingWholeTableAndParagraphShapeTogether() throws {
        let tableSource = """
        | # | Capability | What it gives you |
        | :---: | :--- | :--- |
        | 01 | Flexible topologies | Local-to-remote tests or two remote SSH endpoints |
        | 02 | Live measurements | Bandwidth, transfer totals, RTT, jitter, loss and retransmissions |
        | 03 | Controlled automation | Remote startup, reuse confirmation and cleanup |
        | 04 | Cross-platform workflow | Native credentials, bilingual UI and responsive layouts |
        """
        let tableTranslation = """
        | 编号 | 功能 | 能为您带来什么 |
        | :---: | :--- | :--- |
        | 01 | 灵活的拓扑结构 | 本地到远程测试、两个远程 SSH 端点，或直接连接现有服务 |
        | 02 | 实时测量 | 带宽曲线、吞吐量、传输总量、RTT、抖动、丢包和重传 |
        | 03 | 受控自动化 | 远程服务启动、复用确认和会话清理 |
        | 04 | 跨平台工作流 | 原生凭据存储、双语界面和响应式布局 |
        """
        let document = OCRDocument(blocks: [
            ContentBlock(
                id: "title",
                kind: .title,
                sourceText: "# Why Quantum Leap",
                bounds: NormalizedRect(x: 0.03, y: 0.035, width: 0.72, height: 0.09),
                readingOrder: 0
            ),
            ContentBlock(
                id: "table",
                kind: .table,
                sourceText: tableSource,
                bounds: NormalizedRect(x: 0.03, y: 0.18, width: 0.94, height: 0.65),
                readingOrder: 1
            ),
            ContentBlock(
                id: "paragraph",
                kind: .paragraph,
                sourceText: "Everything stays visible in the frozen overlay.",
                bounds: NormalizedRect(x: 0.04, y: 0.87, width: 0.86, height: 0.07),
                readingOrder: 2
            )
        ])
        let layout = try InPlaceOverlayLayoutBuilder.make(
            document: document,
            translation: InPlaceTranslationResult(blocks: [
                InPlaceTranslatedBlock(id: "title", text: "## 为什么选择量子跃迁"),
                InPlaceTranslatedBlock(id: "table", text: tableTranslation),
                InPlaceTranslatedBlock(id: "paragraph", text: "所有内容都保留在冻结截图覆盖层中。")
            ]),
            canvasSize: CGSize(width: 760, height: 480)
        )

        XCTAssertEqual(layout.renderedSourceBlockCount, 3)
        XCTAssertEqual(layout.omittedBlockCount, 0)
        XCTAssertEqual(layout.blocks.filter { $0.id == "table" }.count, 15)
        XCTAssertEqual(layout.blocks.first { $0.id == "title" }?.text, "为什么选择量子跃迁")
        XCTAssertTrue(layout.blocks.allSatisfy { !$0.text.contains("##") })
        XCTAssertTrue(layout.blocks.allSatisfy { !$0.text.contains("|") })
        XCTAssertTrue(layout.blocks.allSatisfy { !$0.text.contains("---") })
    }

    func testLayoutReassemblesSplitGLMTableFragmentsIntoOneNativeTable() throws {
        let document = OCRDocument(blocks: [
            ContentBlock(
                id: "table-header",
                kind: .paragraph,
                sourceText: "| # | 功能 | 能为您带来什么 |",
                bounds: NormalizedRect(x: 0.04, y: 0.18, width: 0.92, height: 0.08),
                readingOrder: 0
            ),
            ContentBlock(
                id: "table-delimiter",
                kind: .paragraph,
                sourceText: "| --- | --- | --- |",
                bounds: NormalizedRect(x: 0.04, y: 0.27, width: 0.35, height: 0.05),
                readingOrder: 1
            ),
            ContentBlock(
                id: "table-body-a",
                kind: .paragraph,
                sourceText: "| 01 | 灵活的拓扑结构 | 本地或远程测试 |\n| 02 | 实时测量 | 带宽、RTT 和抖动 |",
                bounds: NormalizedRect(x: 0.04, y: 0.33, width: 0.92, height: 0.18),
                readingOrder: 2
            ),
            ContentBlock(
                id: "table-body-b",
                kind: .paragraph,
                sourceText: "| 03 | 受控自动化 | 远程启动与清理 |\n| 04 | 跨平台工作流 | 原生凭据与双语界面 |",
                bounds: NormalizedRect(x: 0.04, y: 0.52, width: 0.92, height: 0.18),
                readingOrder: 3
            )
        ])
        let translation = InPlaceTranslationResult(blocks: [
            InPlaceTranslatedBlock(id: "table-header", text: "| # | Capability | What it gives you |"),
            InPlaceTranslatedBlock(id: "table-delimiter", text: "| --- | --- | --- |"),
            InPlaceTranslatedBlock(
                id: "table-body-a",
                text: "| 01 | Flexible topology | Local or remote tests |\n| 02 | Live measurements | Bandwidth, RTT, and jitter |"
            ),
            InPlaceTranslatedBlock(
                id: "table-body-b",
                text: "| 03 | Controlled automation | Remote startup and cleanup |\n| 04 | Cross-platform workflow | Native credentials and bilingual UI |"
            )
        ])

        let layout = try InPlaceOverlayLayoutBuilder.make(
            document: document,
            translation: translation,
            canvasSize: CGSize(width: 860, height: 520)
        )

        XCTAssertEqual(layout.blocks.count, 15)
        XCTAssertEqual(layout.renderedSourceBlockCount, 4)
        XCTAssertEqual(layout.omittedBlockCount, 0)
        XCTAssertTrue(layout.blocks.allSatisfy { $0.tableCell != nil })
        XCTAssertTrue(layout.blocks.allSatisfy { $0.sourceIDs == document.blocks.map(\.id) })
        XCTAssertTrue(layout.blocks.allSatisfy { $0.tableCell?.preservesSourceGrid == false })
        XCTAssertTrue(layout.blocks.allSatisfy { !$0.text.contains("|") && !$0.text.contains("---") })
    }

    func testLayoutNormalizesGLMLiteralHTMLTableBeforeNativeProjection() throws {
        let source = """
        <table><tr><th></th><th>Capability</th><th>What it gives you</th></tr><tr><td>01</td><td>Flexible topologies</td><td>Local-to-remote tests</td></tr><tr><td>02</td><td>Live measurements</td><td>Bandwidth, RTT, and jitter</td></tr><tr><td>03</td><td>Controlled automation</td><td>Remote startup and cleanup</td></tr><tr><td>04</td><td>Cross-platform workflow</td><td>Native credentials and bilingual UI</td></tr></table>
        """
        let translated = """
        | | 能力 | 能为您带来什么 |
        | --- | --- | --- |
        | 01 | 灵活的拓扑结构 | 本地到远程测试 |
        | 02 | 实时测量 | 带宽、RTT 和抖动 |
        | 03 | 受控自动化 | 远程启动与清理 |
        | 04 | 跨平台工作流 | 原生凭据与双语界面 |
        """
        let document = OCRDocument(blocks: [
            ContentBlock(
                id: "glm-table",
                kind: .table,
                sourceText: source,
                bounds: NormalizedRect(x: 0.02, y: 0.08, width: 0.96, height: 0.84),
                readingOrder: 0
            )
        ])

        let layout = try InPlaceOverlayLayoutBuilder.make(
            document: document,
            translation: InPlaceTranslationResult(blocks: [
                InPlaceTranslatedBlock(id: "glm-table", text: translated)
            ]),
            canvasSize: CGSize(width: 900, height: 520)
        )

        XCTAssertEqual(layout.blocks.count, 15)
        XCTAssertEqual(layout.renderedSourceBlockCount, 1)
        XCTAssertEqual(layout.omittedBlockCount, 0)
        XCTAssertTrue(layout.blocks.allSatisfy { $0.sourceIDs == ["glm-table"] })
        XCTAssertTrue(layout.blocks.allSatisfy { $0.tableCell?.preservesSourceGrid == true })
        XCTAssertTrue(layout.blocks.allSatisfy { !$0.text.contains("<table") && !$0.text.contains("|") })
        XCTAssertEqual(
            layout.blocks.first { $0.tableCell?.row == 1 && $0.tableCell?.column == 1 }?.text,
            "灵活的拓扑结构"
        )
    }

    func testLayoutFreezesMalformedTableSyntaxInsteadOfDrawingItAsParagraphText() throws {
        let document = OCRDocument(blocks: [
            ContentBlock(
                id: "malformed-table",
                kind: .paragraph,
                sourceText: "| 功能 | 说明 |\n| --- | --- |\n| 快速 | 原位覆盖 |",
                bounds: NormalizedRect(x: 0.05, y: 0.1, width: 0.9, height: 0.3),
                readingOrder: 0
            ),
            ContentBlock(
                id: "paragraph",
                kind: .paragraph,
                sourceText: "保持可见",
                bounds: NormalizedRect(x: 0.05, y: 0.72, width: 0.9, height: 0.12),
                readingOrder: 1
            )
        ])
        let layout = try InPlaceOverlayLayoutBuilder.make(
            document: document,
            translation: InPlaceTranslationResult(blocks: [
                InPlaceTranslatedBlock(
                    id: "malformed-table",
                    text: "| Capability | Description |\n| not a delimiter | --- |\n| Fast | In-place overlay |"
                ),
                InPlaceTranslatedBlock(id: "paragraph", text: "Remains visible")
            ]),
            canvasSize: CGSize(width: 640, height: 360)
        )

        XCTAssertEqual(layout.blocks.map(\.id), ["paragraph"])
        XCTAssertEqual(layout.renderedSourceBlockCount, 1)
        XCTAssertEqual(layout.omittedBlockCount, 1)
        XCTAssertFalse(layout.blocks.contains { $0.text.contains("|") || $0.text.contains("---") })
    }

    func testLayoutFreezesDenseOrphanTableRowsAsOneUnsafeRun() throws {
        let rows = (0..<4).map { row in
            ContentBlock(
                id: "row-\(row)",
                kind: .paragraph,
                sourceText: "| \(row) | 紧密行 | 说明 |",
                bounds: NormalizedRect(x: 0.05, y: 0.2 + Double(row) * 0.055, width: 0.9, height: 0.05),
                readingOrder: row
            )
        }
        let paragraph = ContentBlock(
            id: "safe",
            kind: .paragraph,
            sourceText: "安全段落",
            bounds: NormalizedRect(x: 0.05, y: 0.72, width: 0.9, height: 0.12),
            readingOrder: 4
        )
        let translation = InPlaceTranslationResult(blocks: (0..<4).map { row in
            InPlaceTranslatedBlock(id: "row-\(row)", text: "| \(row) | Dense row | Description |")
        } + [InPlaceTranslatedBlock(id: "safe", text: "Safe paragraph")])

        let layout = try InPlaceOverlayLayoutBuilder.make(
            document: OCRDocument(blocks: rows + [paragraph]),
            translation: translation,
            canvasSize: CGSize(width: 640, height: 360)
        )

        XCTAssertEqual(layout.blocks.map(\.id), ["safe"])
        XCTAssertEqual(layout.renderedSourceBlockCount, 1)
        XCTAssertEqual(layout.omittedBlockCount, 4)
    }

    func testLayoutRejectsMalformedOrUnreadableTableAsOneSourceBlock() throws {
        let block = ContentBlock(
            id: "table",
            kind: .table,
            sourceText: "| A | B |\n| --- | --- |\n| 1 | 2 |",
            bounds: NormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.08),
            readingOrder: 0
        )
        for translation in [
            "| 甲 | 乙 |\n| 不是分隔线 | --- |\n| 1 | 2 |",
            "| 甲 | 乙 |\n| --- | --- |\n| 这是一段无法放入极矮表格区域的长译文 | 另一段同样无法完整显示的长译文 |"
        ] {
            XCTAssertThrowsError(
                try InPlaceOverlayLayoutBuilder.make(
                    document: OCRDocument(blocks: [block]),
                    translation: InPlaceTranslationResult(blocks: [
                        InPlaceTranslatedBlock(id: "table", text: translation)
                    ]),
                    canvasSize: CGSize(width: 320, height: 120)
                )
            ) { error in
                XCTAssertEqual(error as? InPlaceOverlayLayoutError, .noRenderableBlocks)
            }
        }
    }

    func testLayoutRejectsMismatchedIDsAndOmitsMissingBoundsWhenAnotherBlockIsReliable() throws {
        let bounded = ContentBlock(
            id: "source",
            kind: .paragraph,
            sourceText: "Source",
            bounds: NormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.2),
            readingOrder: 0
        )
        XCTAssertThrowsError(
            try InPlaceOverlayLayoutBuilder.make(
                document: OCRDocument(blocks: [bounded]),
                translation: InPlaceTranslationResult(blocks: [
                    InPlaceTranslatedBlock(id: "unknown", text: "译文")
                ]),
                canvasSize: CGSize(width: 500, height: 300)
            )
        ) { error in
            XCTAssertEqual(error as? InPlaceOverlayLayoutError, .mismatchedBlockIDs)
        }

        let unbounded = ContentBlock(
            id: "unbounded",
            kind: .paragraph,
            sourceText: "Source",
            readingOrder: 0
        )
        let layout = try InPlaceOverlayLayoutBuilder.make(
            document: OCRDocument(blocks: [bounded, unbounded]),
            translation: InPlaceTranslationResult(blocks: [
                InPlaceTranslatedBlock(id: "source", text: "译文"),
                InPlaceTranslatedBlock(id: "unbounded", text: "保留原图")
            ]),
            canvasSize: CGSize(width: 500, height: 300)
        )
        XCTAssertEqual(layout.blocks.map(\.id), ["source"])
        XCTAssertEqual(layout.sourceBlockCount, 2)
        XCTAssertEqual(layout.omittedBlockCount, 1)
    }

    func testLayoutRejectsDecodedOutOfRangeBounds() throws {
        let bounds = try JSONDecoder().decode(
            NormalizedRect.self,
            from: Data(#"{"x":0.9,"y":0.1,"width":0.2,"height":0.2}"#.utf8)
        )
        let document = OCRDocument(blocks: [
            ContentBlock(
                id: "outside",
                kind: .paragraph,
                sourceText: "Outside",
                bounds: bounds,
                readingOrder: 0
            )
        ])

        XCTAssertThrowsError(
            try InPlaceOverlayLayoutBuilder.make(
                document: document,
                translation: InPlaceTranslationResult(blocks: [
                    InPlaceTranslatedBlock(id: "outside", text: "越界")
                ]),
                canvasSize: CGSize(width: 500, height: 300)
            )
        ) { error in
            XCTAssertEqual(error as? InPlaceOverlayLayoutError, .noRenderableBlocks)
        }
    }

    func testLayoutOmitsSevereOverlapAndRejectsWhenNothingCanFit() throws {
        let overlapping = [
            ContentBlock(
                id: "a",
                kind: .paragraph,
                sourceText: "A",
                bounds: NormalizedRect(x: 0.1, y: 0.1, width: 0.6, height: 0.3),
                readingOrder: 0
            ),
            ContentBlock(
                id: "b",
                kind: .paragraph,
                sourceText: "B",
                bounds: NormalizedRect(x: 0.2, y: 0.15, width: 0.6, height: 0.3),
                readingOrder: 1
            )
        ]
        let overlapLayout = try InPlaceOverlayLayoutBuilder.make(
            document: OCRDocument(blocks: overlapping),
            translation: InPlaceTranslationResult(blocks: [
                InPlaceTranslatedBlock(id: "a", text: "甲"),
                InPlaceTranslatedBlock(id: "b", text: "乙")
            ]),
            canvasSize: CGSize(width: 500, height: 300)
        )
        XCTAssertEqual(overlapLayout.blocks.map(\.id), ["a"])
        XCTAssertEqual(overlapLayout.omittedBlockCount, 1)

        let tiny = ContentBlock(
            id: "tiny",
            kind: .paragraph,
            sourceText: "Short",
            bounds: NormalizedRect(x: 0.1, y: 0.1, width: 0.12, height: 0.04),
            readingOrder: 0
        )
        XCTAssertThrowsError(
            try InPlaceOverlayLayoutBuilder.make(
                document: OCRDocument(blocks: [tiny]),
                translation: InPlaceTranslationResult(blocks: [
                    InPlaceTranslatedBlock(
                        id: "tiny",
                        text: "这是一段明显无法放进原始狭小区域并保持可读字号的很长译文"
                    )
                ]),
                canvasSize: CGSize(width: 500, height: 300)
            )
        ) { error in
            XCTAssertEqual(error as? InPlaceOverlayLayoutError, .noRenderableBlocks)
        }
    }

    func testBackgroundSamplingIgnoresSparseTextColoredOutliers() {
        let colors = Array(repeating: NSColor.white, count: 24)
            + Array(repeating: NSColor.black, count: 8)
        let appearance = ScreenshotBackgroundSampler.robustAppearance(colors: colors)

        XCTAssertEqual(appearance.color.redComponent, 1, accuracy: 0.001)
        XCTAssertEqual(appearance.color.greenComponent, 1, accuracy: 0.001)
        XCTAssertEqual(appearance.color.blueComponent, 1, accuracy: 0.001)
        XCTAssertEqual(appearance.variation, 0, accuracy: 0.001)
        XCTAssertEqual(appearance.textColor, .black)
    }

    func testBackgroundRestorationErasesTextWhilePreservingRowColorAndGridLine() throws {
        let image = try makeTableImage()
        let block = InPlaceOverlayBlock(
            id: "cell",
            kind: .paragraph,
            text: "译文",
            normalizedBounds: NormalizedRect(x: 0.25, y: 0.1, width: 0.425, height: 0.3),
            sourceFrame: CGRect(x: 30, y: 36, width: 51, height: 18),
            frame: CGRect(x: 30, y: 36, width: 51, height: 18),
            fontSize: 14,
            fontWeight: .regular,
            usesMonospacedFont: false
        )
        let restored = try ScreenshotBackgroundRestorer.restore(
            image: image,
            layout: InPlaceOverlayLayout(
                canvasSize: CGSize(width: 120, height: 60),
                blocks: [block],
                sourceBlockCount: 1
            )
        )
        let sourceBitmap = NSBitmapImageRep(cgImage: image)
        let bitmap = NSBitmapImageRep(cgImage: restored.image)

        let erasedTextPixel = try XCTUnwrap(bitmap.colorAt(x: 60, y: 18)?.usingColorSpace(.deviceRGB))
        XCTAssertEqual(erasedTextPixel.redComponent, 0.92, accuracy: 0.03)
        XCTAssertEqual(erasedTextPixel.greenComponent, 0.92, accuracy: 0.03)
        XCTAssertEqual(erasedTextPixel.blueComponent, 0.92, accuracy: 0.03)

        let gridY = try XCTUnwrap((11...18).min { left, right in
            let leftValue = sourceBitmap.colorAt(x: 12, y: left)?.usingColorSpace(.deviceRGB)?.redComponent ?? 1
            let rightValue = sourceBitmap.colorAt(x: 12, y: right)?.usingColorSpace(.deviceRGB)?.redComponent ?? 1
            return leftValue < rightValue
        })
        let sourceGridPixel = try XCTUnwrap(sourceBitmap.colorAt(x: 12, y: gridY)?.usingColorSpace(.deviceRGB))
        XCTAssertLessThan(sourceGridPixel.redComponent, 0.35)
        let preservedGridPixel = try XCTUnwrap(bitmap.colorAt(x: 60, y: gridY)?.usingColorSpace(.deviceRGB))
        XCTAssertLessThan(preservedGridPixel.redComponent, 0.35)
        XCTAssertLessThan(preservedGridPixel.greenComponent, 0.35)
        XCTAssertLessThan(preservedGridPixel.blueComponent, 0.35)

        let sourceVerticalGrid = try XCTUnwrap(sourceBitmap.colorAt(x: 84, y: 20)?.usingColorSpace(.deviceRGB))
        XCTAssertLessThan(sourceVerticalGrid.redComponent, 0.35)
        let preservedVerticalGrid = try XCTUnwrap(bitmap.colorAt(x: 84, y: 20)?.usingColorSpace(.deviceRGB))
        XCTAssertLessThan(preservedVerticalGrid.redComponent, 0.35)
        XCTAssertLessThan(preservedVerticalGrid.greenComponent, 0.35)
        XCTAssertLessThan(preservedVerticalGrid.blueComponent, 0.35)
    }

    func testBackgroundRestorationRemovesInlineCodeDecorationOutsideGlyphBounds() throws {
        let image = try makeInlineCodeImage()
        let block = InPlaceOverlayBlock(
            id: "inline-code",
            kind: .paragraph,
            text: "命令",
            normalizedBounds: NormalizedRect(
                x: 44.0 / 120.0,
                y: 27.0 / 60.0,
                width: 32.0 / 120.0,
                height: 6.0 / 60.0
            ),
            sourceFrame: CGRect(x: 44, y: 27, width: 32, height: 6),
            frame: CGRect(x: 44, y: 27, width: 32, height: 6),
            fontSize: 8,
            fontWeight: .regular,
            usesMonospacedFont: false
        )
        let restored = try ScreenshotBackgroundRestorer.restore(
            image: image,
            layout: InPlaceOverlayLayout(
                canvasSize: CGSize(width: 120, height: 60),
                blocks: [block],
                sourceBlockCount: 1
            )
        )
        let sourceBitmap = NSBitmapImageRep(cgImage: image)
        let bitmap = NSBitmapImageRep(cgImage: restored.image)
        let decoratedPixel = try XCTUnwrap(sourceBitmap.colorAt(x: 41, y: 30)?.usingColorSpace(.deviceRGB))
        XCTAssertLessThan(decoratedPixel.redComponent, 0.9)
        let restoredPixel = try XCTUnwrap(bitmap.colorAt(x: 41, y: 30)?.usingColorSpace(.deviceRGB))
        XCTAssertEqual(restoredPixel.redComponent, 1, accuracy: 0.03)
        XCTAssertEqual(restoredPixel.greenComponent, 1, accuracy: 0.03)
        XCTAssertEqual(restoredPixel.blueComponent, 1, accuracy: 0.03)
    }

    func testBackgroundRestorationAcceptsOrRejectsTableCellsAtomically() throws {
        let image = try makeAtomicRestorationImage()
        let tableCells = (0..<2).map { column in
            return InPlaceOverlayBlock(
                id: "table",
                kind: .table,
                text: column == 0 ? "能力" : "说明",
                normalizedBounds: NormalizedRect(
                    x: 0.05 + Double(column) * 0.25,
                    y: 0.2,
                    width: 0.25,
                    height: 0.4
                ),
                sourceFrame: CGRect(x: 9 + column * 45, y: 32, width: 45, height: 32),
                frame: CGRect(x: 9 + column * 45, y: 32, width: 45, height: 32),
                fontSize: 10,
                fontWeight: .semibold,
                usesMonospacedFont: false,
                tableCell: InPlaceOverlayTableCell(
                    row: 0,
                    column: column,
                    rowCount: 1,
                    columnCount: 2,
                    alignment: .center
                )
            )
        }
        let paragraph = InPlaceOverlayBlock(
            id: "paragraph",
            kind: .paragraph,
            text: "译文",
            normalizedBounds: NormalizedRect(x: 0.7, y: 0.2, width: 0.2, height: 0.2),
            sourceFrame: CGRect(x: 126, y: 48, width: 36, height: 16),
            frame: CGRect(x: 126, y: 48, width: 36, height: 16),
            fontSize: 10,
            fontWeight: .regular,
            usesMonospacedFont: false
        )
        let result = try ScreenshotBackgroundRestorer.restore(
            image: image,
            layout: InPlaceOverlayLayout(
                canvasSize: CGSize(width: 180, height: 80),
                blocks: tableCells + [paragraph],
                sourceBlockCount: 2
            )
        )

        XCTAssertEqual(result.blocks.map(\.block.id), ["paragraph"])
        XCTAssertEqual(result.renderedSourceBlockCount, 1)
    }

    func testTableRestorationClearsCellInteriorsWithoutHorizontalTextSmear() throws {
        let image = try makeSmearingTableImage()
        let blocks: [InPlaceOverlayBlock] = (0..<2).map { column -> InPlaceOverlayBlock in
            let x = CGFloat(column) * 60
            let normalizedX = Double(column) * 0.5
            return InPlaceOverlayBlock(
                id: "table",
                kind: .table,
                text: column == 0 ? "能力" : "说明",
                normalizedBounds: NormalizedRect(
                    x: normalizedX,
                    y: 0.2,
                    width: 0.5,
                    height: 0.4
                ),
                sourceFrame: CGRect(x: x, y: 24, width: 60, height: 24),
                frame: CGRect(x: x, y: 24, width: 60, height: 24),
                fontSize: 10,
                fontWeight: .regular,
                usesMonospacedFont: false,
                tableCell: InPlaceOverlayTableCell(
                    row: 0,
                    column: column,
                    rowCount: 1,
                    columnCount: 2,
                    alignment: .center
                )
            )
        }
        let restored = try ScreenshotBackgroundRestorer.restore(
            image: image,
            layout: InPlaceOverlayLayout(
                canvasSize: CGSize(width: 120, height: 60),
                blocks: blocks,
                sourceBlockCount: 1
            )
        )
        let bitmap = NSBitmapImageRep(cgImage: restored.image)

        for x in Array(6...54) + Array(66...114) {
            let color = try XCTUnwrap(bitmap.colorAt(x: x, y: 24)?.usingColorSpace(NSColorSpace.deviceRGB))
            XCTAssertGreaterThan(color.redComponent, 0.95, "unexpected smear at x=\(x)")
            XCTAssertGreaterThan(color.greenComponent, 0.95, "unexpected smear at x=\(x)")
            XCTAssertGreaterThan(color.blueComponent, 0.95, "unexpected smear at x=\(x)")
        }
    }

    func testCoordinatorCountsExpandedTableAsOneRenderedSourceBlock() throws {
        _ = NSApplication.shared
        let coordinator = ScreenshotTranslationOverlayCoordinator()
        let requestID = UUID()
        let image = try makeSolidImage(width: 400, height: 160, color: .white)
        coordinator.presentWaiting(
            capture: CapturedScreenshot(
                image: image,
                globalRect: CGRect(x: 40, y: 40, width: 400, height: 160)
            ),
            requestID: requestID,
            onCancel: {}
        )
        let layout = try InPlaceOverlayLayoutBuilder.make(
            document: OCRDocument(blocks: [
                ContentBlock(
                    id: "table",
                    kind: .table,
                    sourceText: "| A | B |\n| --- | --- |\n| 1 | 2 |",
                    bounds: NormalizedRect(x: 0.05, y: 0.1, width: 0.9, height: 0.8),
                    readingOrder: 0
                )
            ]),
            translation: InPlaceTranslationResult(blocks: [
                InPlaceTranslatedBlock(
                    id: "table",
                    text: "| 甲 | 乙 |\n| --- | --- |\n| 一 | 二 |"
                )
            ]),
            canvasSize: CGSize(width: 400, height: 160)
        )

        XCTAssertTrue(try coordinator.apply(layout: layout, for: requestID))
        XCTAssertEqual(coordinator.stage, .translated(renderedBlockCount: 1, omittedBlockCount: 0))
        coordinator.close()
    }

    func testCoordinatorUpdatesSamePanelAndRejectsStaleCallbacks() throws {
        _ = NSApplication.shared
        let coordinator = ScreenshotTranslationOverlayCoordinator()
        let requestID = UUID()
        var cancellationCount = 0
        let image = try makeSolidImage(width: 200, height: 120, color: .white)
        coordinator.presentWaiting(
            capture: CapturedScreenshot(
                image: image,
                globalRect: CGRect(x: 40, y: 40, width: 200, height: 120)
            ),
            requestID: requestID,
            onCancel: { cancellationCount += 1 }
        )
        let panelIdentity = try XCTUnwrap(coordinator.panelIdentity)

        XCTAssertEqual(coordinator.stage, .recognizing)
        XCTAssertTrue(coordinator.updateStage(.translating, for: requestID))
        XCTAssertEqual(coordinator.panelIdentity, panelIdentity)

        let document = OCRDocument(blocks: [
            ContentBlock(
                id: "block",
                kind: .paragraph,
                sourceText: "Source text",
                bounds: NormalizedRect(x: 0.1, y: 0.2, width: 0.8, height: 0.4),
                readingOrder: 0
            )
        ])
        let layout = try InPlaceOverlayLayoutBuilder.make(
            document: document,
            translation: InPlaceTranslationResult(blocks: [
                InPlaceTranslatedBlock(id: "block", text: "原位译文")
            ]),
            canvasSize: CGSize(width: 200, height: 120)
        )
        XCTAssertTrue(try coordinator.apply(layout: layout, for: requestID))
        XCTAssertEqual(coordinator.panelIdentity, panelIdentity)
        XCTAssertEqual(coordinator.stage, .translated(renderedBlockCount: 1, omittedBlockCount: 0))

        XCTAssertFalse(coordinator.showFailure("过期失败", for: UUID()))
        XCTAssertEqual(coordinator.stage, .translated(renderedBlockCount: 1, omittedBlockCount: 0))
        coordinator.close()
        XCTAssertEqual(cancellationCount, 1)
        XCTAssertNil(coordinator.activeRequestID)
    }

    func testPresentingNewOverlayCancelsPreviousRequestAndInvalidatesItsID() throws {
        _ = NSApplication.shared
        let coordinator = ScreenshotTranslationOverlayCoordinator()
        let image = try makeSolidImage(width: 120, height: 80, color: .white)
        let capture = CapturedScreenshot(
            image: image,
            globalRect: CGRect(x: 30, y: 30, width: 120, height: 80)
        )
        let firstID = UUID()
        let secondID = UUID()
        var firstCancelled = false
        coordinator.presentWaiting(capture: capture, requestID: firstID) {
            firstCancelled = true
        }
        coordinator.presentWaiting(capture: capture, requestID: secondID, onCancel: {})

        XCTAssertTrue(firstCancelled)
        XCTAssertEqual(coordinator.activeRequestID, secondID)
        XCTAssertFalse(coordinator.updateStage(.translating, for: firstID))
        XCTAssertEqual(coordinator.stage, .recognizing)
        coordinator.close()
    }

    private func makeTableImage() throws -> CGImage {
        let image = try makeSolidImage(width: 120, height: 60, color: NSColor(calibratedWhite: 0.98, alpha: 1))
        guard let context = CGContext(
            data: nil,
            width: 120,
            height: 60,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw TestImageError.contextUnavailable }
        context.draw(image, in: CGRect(x: 0, y: 0, width: 120, height: 60))
        context.setFillColor(CGColor(gray: 0.92, alpha: 1))
        context.fill(CGRect(x: 0, y: 36, width: 120, height: 18))
        context.setFillColor(CGColor(gray: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 45, width: 120, height: 1))
        context.fill(CGRect(x: 84, y: 0, width: 1, height: 60))
        context.setFillColor(CGColor(gray: 0.05, alpha: 1))
        context.fill(CGRect(x: 42, y: 40, width: 36, height: 10))
        guard let output = context.makeImage() else { throw TestImageError.contextUnavailable }
        return output
    }

    private func makeInlineCodeImage() throws -> CGImage {
        let image = try makeSolidImage(width: 120, height: 60, color: .white)
        guard let context = CGContext(
            data: nil,
            width: 120,
            height: 60,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw TestImageError.contextUnavailable }
        context.draw(image, in: CGRect(x: 0, y: 0, width: 120, height: 60))
        context.setFillColor(CGColor(gray: 0.78, alpha: 1))
        context.fill(CGRect(x: 40, y: 23, width: 40, height: 14))
        context.setFillColor(CGColor(gray: 0.05, alpha: 1))
        context.fill(CGRect(x: 44, y: 27, width: 32, height: 6))
        guard let output = context.makeImage() else { throw TestImageError.contextUnavailable }
        return output
    }

    private func makeAtomicRestorationImage() throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: 180,
            height: 80,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw TestImageError.contextUnavailable }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 180, height: 80))
        for y in stride(from: 16, to: 64, by: 4) {
            for x in stride(from: 50, to: 108, by: 4) {
                context.setFillColor(((x + y) / 4).isMultiple(of: 2) ? NSColor.black.cgColor : NSColor.white.cgColor)
                context.fill(CGRect(x: x, y: y, width: 4, height: 4))
            }
        }
        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(x: 132, y: 52, width: 20, height: 6))
        guard let image = context.makeImage() else { throw TestImageError.contextUnavailable }
        return image
    }

    private func makeSmearingTableImage() throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: 120,
            height: 60,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw TestImageError.contextUnavailable }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 120, height: 60))
        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(x: 46, y: 20, width: 10, height: 8))
        context.fill(CGRect(x: 64, y: 20, width: 10, height: 8))
        context.fill(CGRect(x: 59, y: 12, width: 2, height: 24))
        guard let image = context.makeImage() else { throw TestImageError.contextUnavailable }
        return image
    }

    private func makeSolidImage(width: Int, height: Int, color: NSColor) throws -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let converted = color.usingColorSpace(.deviceRGB) else {
            throw TestImageError.contextUnavailable
        }
        context.setFillColor(converted.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { throw TestImageError.contextUnavailable }
        return image
    }

    private enum TestImageError: Error {
        case contextUnavailable
    }
}
