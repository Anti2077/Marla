import AppKit
import MarlaCore

extension MarlaApplicationModel {
    func presentInPlaceOverlayUIAutomationFixture(named scenario: String) -> Bool {
        let supported = ["in-place-overlay", "in-place-overlay-waiting", "in-place-overlay-failure",
                         "in-place-overlay-hover", "in-place-overlay-transfer", "in-place-overlay-small",
                         "in-place-overlay-interactive"]
        guard supported.contains(scenario),
              let screen = NSScreen.main
        else { return false }

        let isSmall = scenario == "in-place-overlay-small"
        let size = isSmall ? CGSize(width: 240, height: 140) : CGSize(width: 860, height: 620)
        let frame = CGRect(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        let document = isSmall ? OCRDocument(blocks: [
            Self.fixtureBlock("short", .paragraph, "A short passage.", 0.08, 0.45, 0.8, 0.4, 0)
        ]) : Self.makeInPlaceTableFixtureDocument()
        let translation = isSmall ? InPlaceTranslationResult(blocks: [
            InPlaceTranslatedBlock(id: "short", text: "一段简短的译文。")
        ]) : Self.makeInPlaceTableFixtureTranslation()
        guard let layout = try? InPlaceOverlayLayoutBuilder.make(
            document: document,
            translation: translation,
            canvasSize: size
        ), let image = Self.makeInPlaceTableFixtureImage(size: size, document: document, layout: layout)
        else { return false }

        sessionStore.installUIAutomationFixture(
            surface: .screenshot, sourceText: document.plainText, translation: "", state: .recognizing,
            contentFormat: .semanticMarkdown, ocrActivity: .glmOCR
        )
        guard let requestID = sessionStore.session?.id else { return false }
        screenshotTranslationOverlay.presentWaiting(
            capture: CapturedScreenshot(image: image, globalRect: frame),
            requestID: requestID,
            onCancel: { [weak self] in self?.sessionStore.close() },
            onTransfer: { [weak self] id in self?.moveInPlaceTranslationToWindow(for: id) ?? false }
        )
        if scenario == "in-place-overlay-waiting" {
            return true
        }
        if scenario == "in-place-overlay-failure" {
            screenshotTranslationOverlay.showFailure("无法识别可翻译文字", for: requestID)
            return true
        }

        do {
            screenshotTranslationOverlay.updateStage(.translating, for: requestID)
            guard try screenshotTranslationOverlay.apply(layout: layout, for: requestID) else { return false }
            sessionStore.completeInPlaceTranslation(
                for: requestID, content: InPlaceWindowContent.make(document: document, translation: translation)
            )
            screenshotTranslationOverlay.enableTransfer(for: requestID)
            if ProcessInfo.processInfo.environment["MARLA_UI_TEST_EXIT_AFTER_CAPTURE"] == "1" {
                screenshotTranslationOverlay.setChromeProximityForUIAutomation(scenario != "in-place-overlay")
            }
            if scenario == "in-place-overlay-transfer" {
                return screenshotTranslationOverlay.transferToWindow(for: requestID)
            }
            return true
        } catch {
            FileHandle.standardError.write(Data("In-place fixture failed: \(error.localizedDescription)\n".utf8))
            return false
        }
    }

    private static func makeInPlaceTableFixtureDocument() -> OCRDocument {
        OCRDocument(blocks: [
            fixtureBlock("title", .title, "# Native Markdown in place", 0.035, 0.035, 0.72, 0.09, 0),
            fixtureBlock(
                "headings",
                .heading,
                "# Level one\n\n### Level three\n\n###### Level six",
                0.04, 0.16, 0.50, 0.20, 1
            ),
            fixtureBlock(
                "inline",
                .paragraph,
                "**Bold**, *italic*, ***both***, ~~removed~~, `inline code`, and [a link](https://example.com).",
                0.04, 0.40, 0.50, 0.11, 2
            ),
            fixtureBlock(
                "list",
                .listItem,
                "- Parent item\n  - Nested item\n- [ ] Pending\n- [x] Complete",
                0.04, 0.55, 0.50, 0.17, 3
            ),
            fixtureBlock(
                "code",
                .code,
                "```swift\nlet result = translate(capture)\n```",
                0.59, 0.16, 0.36, 0.20, 4
            ),
            fixtureBlock(
                "quote",
                .paragraph,
                "> Structure remains visible while words change.",
                0.59, 0.41, 0.36, 0.12, 5
            ),
            fixtureBlock(
                "ordered",
                .listItem,
                "1. Capture\n2. Recognize\n3. Translate in place",
                0.59, 0.57, 0.36, 0.15, 6
            ),
            fixtureBlock(
                "table",
                .table,
                "<table><tr><th>Semantic</th><th>Inline</th><th>Destination</th></tr><tr><td>Strong and emphasis</td><td>code and removed</td><td>Guide</td></tr></table>",
                0.035, 0.77, 0.93, 0.18, 7
            )
        ])
    }

    private static func makeInPlaceTableFixtureTranslation() -> InPlaceTranslationResult {
        InPlaceTranslationResult(blocks: [
            InPlaceTranslatedBlock(id: "title", text: "# 原位保留 Markdown 结构"),
            InPlaceTranslatedBlock(id: "headings", text: "# 一级标题\n\n### 三级标题\n\n###### 六级标题"),
            InPlaceTranslatedBlock(
                id: "inline",
                text: "**粗体**、*斜体*、***粗斜体***、~~删除线~~、`行内代码`与[链接](https://example.com)。"
            ),
            InPlaceTranslatedBlock(
                id: "list",
                text: "- 父级条目\n  - 嵌套条目\n- [ ] 待完成\n- [x] 已完成"
            ),
            InPlaceTranslatedBlock(
                id: "code",
                text: "```swift\nlet result = translate(capture)\n```"
            ),
            InPlaceTranslatedBlock(id: "quote", text: "> 文字变化时，结构仍留在原处。"),
            InPlaceTranslatedBlock(id: "ordered", text: "1. 截图\n2. 识别\n3. 原位翻译"),
            InPlaceTranslatedBlock(
                id: "table",
                text: "| 语义 | 行内样式 | 目标 |\n| :--- | :--- | :--- |\n| **粗体**与*斜体* | `代码`与~~删除线~~ | [文档](https://example.com) |"
            )
        ])
    }

    private static func fixtureBlock(
        _ id: String,
        _ kind: ContentBlockKind,
        _ text: String,
        _ x: Double,
        _ y: Double,
        _ width: Double,
        _ height: Double,
        _ order: Int
    ) -> ContentBlock {
        ContentBlock(
            id: id,
            kind: kind,
            sourceText: text,
            bounds: NormalizedRect(x: x, y: y, width: width, height: height),
            readingOrder: order
        )
    }

    private static func makeInPlaceTableFixtureImage(
        size: CGSize,
        document: OCRDocument,
        layout: InPlaceOverlayLayout
    ) -> CGImage? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        bitmap.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        let isDark = ProcessInfo.processInfo.environment["MARLA_UI_TEST_APPEARANCE"] == "dark"
        let background = isDark ? NSColor(calibratedWhite: 0.09, alpha: 1) : NSColor(calibratedWhite: 0.98, alpha: 1)
        let alternate = isDark ? NSColor(calibratedWhite: 0.14, alpha: 1) : NSColor(calibratedWhite: 0.94, alpha: 1)
        let line = isDark ? NSColor(calibratedWhite: 0.32, alpha: 1) : NSColor(calibratedWhite: 0.78, alpha: 1)
        let text = isDark ? NSColor.white : NSColor(calibratedWhite: 0.12, alpha: 1)
        background.setFill()
        NSBezierPath.fill(CGRect(origin: .zero, size: size))

        for block in document.blocks where block.kind != .table {
            guard let bounds = block.bounds else { continue }
            let frame = InPlaceOverlayLayoutBuilder.frame(for: bounds, canvasSize: size).insetBy(dx: 2, dy: 1)
            let fontSize: CGFloat = block.kind == .title ? 26 : (block.kind == .heading ? 17 : 14)
            let font = NSFont.systemFont(
                ofSize: fontSize,
                weight: block.kind == .title ? .bold : (block.kind == .heading ? .semibold : .regular)
            )
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            (InPlaceMarkdownProjection.visibleText(from: block.sourceText) as NSString).draw(
                with: frame,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font, .foregroundColor: text, .paragraphStyle: paragraph]
            )
        }

        let tableBlocks = layout.blocks.filter { $0.tableCell != nil }
        let sourceMarkdown = tableBlocks.first.flatMap { first -> String? in
            let sourceBlocks = document.blocks.filter { first.sourceIDs.contains($0.id) }
            guard let sourceTableBlock = sourceBlocks.first else { return nil }
            if sourceBlocks.count == 1, sourceTableBlock.kind == .table {
                return LiteralHTMLTableNormalizer.markdown(from: sourceTableBlock.sourceText)
                    ?? sourceTableBlock.sourceText
            }
            return sourceBlocks.map(\.sourceText).joined(separator: "\n")
        }
        if let first = tableBlocks.first, first.tableCell?.preservesSourceGrid == true,
           let sourceMarkdown,
           let sourceTable = InPlaceMarkdownProjection.table(from: sourceMarkdown) {
            for item in tableBlocks {
                guard let cell = item.tableCell else { continue }
                if cell.row.isMultiple(of: 2) == false {
                    alternate.setFill()
                    NSBezierPath.fill(item.frame)
                }
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byWordWrapping
                paragraph.alignment = cell.alignment.appKitValue
                let font = NSFont.systemFont(
                    ofSize: item.fontSize,
                    weight: cell.row == 0 ? .semibold : .regular
                )
                let value = String(sourceTable.rows[cell.row][cell.column].characters)
                (value as NSString).draw(
                    with: item.frame.insetBy(dx: 6, dy: 3),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: [.font: font, .foregroundColor: text, .paragraphStyle: paragraph]
                )
            }
            let tableFrame = tableBlocks.dropFirst().reduce(first.frame) { $0.union($1.frame) }
            line.setStroke()
            let grid = NSBezierPath(rect: tableFrame)
            grid.lineWidth = 1
            for column in 1..<(first.tableCell?.columnCount ?? 1) {
                guard let cell = tableBlocks.first(where: { $0.tableCell?.row == 0 && $0.tableCell?.column == column }) else { continue }
                grid.move(to: CGPoint(x: cell.frame.minX, y: tableFrame.minY))
                grid.line(to: CGPoint(x: cell.frame.minX, y: tableFrame.maxY))
            }
            for row in 1..<(first.tableCell?.rowCount ?? 1) {
                guard let cell = tableBlocks.first(where: { $0.tableCell?.row == row && $0.tableCell?.column == 0 }) else { continue }
                grid.move(to: CGPoint(x: tableFrame.minX, y: cell.frame.maxY))
                grid.line(to: CGPoint(x: tableFrame.maxX, y: cell.frame.maxY))
            }
            grid.stroke()
        }
        graphics.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.cgImage
    }
}
