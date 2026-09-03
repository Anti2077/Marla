import AppKit
import MarlaCore

extension MarlaApplicationModel {
    func presentInPlaceOverlayUIAutomationFixture(named scenario: String) -> Bool {
        let supported = ["in-place-overlay", "in-place-overlay-waiting", "in-place-overlay-failure"]
        guard supported.contains(scenario),
              let screen = NSScreen.main
        else { return false }

        let size = CGSize(width: 760, height: 480)
        let frame = CGRect(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        let document = Self.makeInPlaceTableFixtureDocument()
        let translation = Self.makeInPlaceTableFixtureTranslation()
        guard let layout = try? InPlaceOverlayLayoutBuilder.make(
            document: document,
            translation: translation,
            canvasSize: size
        ), let image = Self.makeInPlaceTableFixtureImage(size: size, document: document, layout: layout)
        else { return false }

        let requestID = UUID()
        screenshotTranslationOverlay.presentWaiting(
            capture: CapturedScreenshot(image: image, globalRect: frame),
            requestID: requestID,
            onCancel: {}
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
            return try screenshotTranslationOverlay.apply(layout: layout, for: requestID)
        } catch {
            FileHandle.standardError.write(Data("In-place fixture failed: \(error.localizedDescription)\n".utf8))
            return false
        }
    }

    private static func makeInPlaceTableFixtureDocument() -> OCRDocument {
        OCRDocument(blocks: [
            fixtureBlock("title", .title, "# Why Quantum Leap", 0.03, 0.035, 0.72, 0.09, 0),
            fixtureBlock(
                "table",
                .table,
                """
                | # | Capability | What it gives you |
                | :---: | :--- | :--- |
                | 1 | Flexible topologies | Local-to-remote tests, two remote SSH endpoints, or a direct connection |
                | 2 | Live measurements | Bandwidth curves, throughput, transfer totals, RTT, jitter, loss and retransmissions |
                | 3 | Controlled automation | Remote startup, reuse confirmation, cleanup and host-key verification |
                | 4 | Cross-platform workflow | Native credentials, bilingual UI, light and dark themes, responsive layouts |
                """,
                0.03, 0.18, 0.94, 0.65, 1
            ),
            fixtureBlock(
                "paragraph",
                .paragraph,
                "Everything stays visible in one frozen screenshot overlay.",
                0.04, 0.87, 0.86, 0.07, 2
            )
        ])
    }

    private static func makeInPlaceTableFixtureTranslation() -> InPlaceTranslationResult {
        InPlaceTranslationResult(blocks: [
            InPlaceTranslatedBlock(id: "title", text: "## 为什么选择量子跃迁"),
            InPlaceTranslatedBlock(
                id: "table",
                text: """
                | 编号 | 能力 | 它能为您带来什么 |
                | :---: | :--- | :--- |
                | 1 | 灵活的拓扑结构 | 本地到远程测试、两个远程 SSH 端点，或直接连接至现有的 iperf3 服务 |
                | 2 | 实时测量 | 带宽曲线、吞吐量、传输总量、RTT、抖动、丢包以及 TCP 重传 |
                | 3 | 受控自动化 | 远程服务启动、复用确认、会话清理以及 SSH 主机密钥验证 |
                | 4 | 跨平台工作流 | 原生凭据存储、双语界面、浅色和深色主题以及响应式布局 |
                """
            ),
            InPlaceTranslatedBlock(id: "paragraph", text: "所有内容都直接保留在同一个冻结截图覆盖层中。")
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

        guard let sourceTableBlock = document.blocks.first(where: { $0.kind == .table }),
              let sourceTable = InPlaceMarkdownProjection.table(from: sourceTableBlock.sourceText)
        else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        let tableBlocks = layout.blocks.filter { $0.id == sourceTableBlock.id && $0.tableCell != nil }
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
            let value = sourceTable.rows[cell.row][cell.column]
            (value as NSString).draw(
                with: item.frame.insetBy(dx: 6, dy: 3),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font, .foregroundColor: text, .paragraphStyle: paragraph]
            )
        }
        if let first = tableBlocks.first {
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
