import AppKit
import MarlaCore

extension MarlaApplicationModel {
    func presentMarkdownUIAutomationFixture(named scenario: String) -> Bool {
        let isWide: Bool
        switch scenario {
        case "markdown-streaming":
            isWide = false
            presentStreamingMarkdownUIAutomationFixture()
        case "markdown-streaming-wide":
            isWide = true
            presentStreamingMarkdownUIAutomationFixture()
        case "markdown-streaming-growth":
            isWide = false
            presentGrowingMarkdownUIAutomationFixture()
        case "markdown-completed":
            isWide = false
            presentCompletedMarkdownUIAutomationFixture()
        case "markdown-completed-wide":
            isWide = true
            presentCompletedMarkdownUIAutomationFixture()
        case "markdown-code-styling":
            isWide = false
            presentMarkdownCodeStylingUIAutomationFixture()
        case "markdown-code-styling-wide":
            isWide = true
            presentMarkdownCodeStylingUIAutomationFixture()
        case "markdown-comparison":
            isWide = false
            presentMarkdownComparisonUIAutomationFixture()
        case "markdown-comparison-wide":
            isWide = true
            presentMarkdownComparisonUIAutomationFixture()
        default:
            return false
        }

        if isWide {
            DispatchQueue.main.async { [weak self] in
                self?.panelCoordinator.setResultWidthForUIAutomation(ResultCardLayout.maximumWidth)
            }
        }
        return true
    }

    func presentGrowingMarkdownUIAutomationFixture() {
        let source = "# Streaming Markdown\n\nThe result grows from incomplete syntax into a complete table."
        let stages = [
            "# 实时 Markdown",
            """
            # 实时 Markdown

            当前译文正在形成 **原生富文本
            """,
            """
            # 实时 Markdown

            当前译文正在形成 **原生富文本投影**，窗口跟随实际排版增长。

            | 阶段 | 状态 |
            """,
            """
            # 实时 Markdown

            当前译文正在形成 **原生富文本投影**，窗口跟随实际排版增长。

            | 阶段 | 状态 | 说明 |
            | :--- | :---: | ---: |
            | 解析 | 进行中 | 未闭合片段会保留当前字符 |
            | 布局 | 已同步 | TextKit 测量正文与窗口高度 |
            """,
        ]

        sessionStore.installUIAutomationFixture(
            surface: .quickInput,
            sourceText: source,
            translation: stages[0],
            state: .streaming,
            contentFormat: .semanticMarkdown
        )
        panelCoordinator.showResult(
            store: sessionStore,
            at: nil,
            pointer: NSEvent.mouseLocation,
            activate: true
        )

        for (index, stage) in stages.dropFirst().enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index + 1) * 0.18) { [weak self] in
                self?.sessionStore.updateUIAutomationFixture(
                    translation: stage,
                    state: .streaming
                )
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.sessionStore.updateUIAutomationFixture(
                translation: stages[stages.count - 1],
                state: .completed
            )
        }
    }

    func presentStreamingMarkdownUIAutomationFixture() {
        sessionStore.installUIAutomationFixture(
            surface: .quickInput,
            sourceText: "# Field Notes\n\n- Preserve structure\n- Keep `TOKEN` unchanged",
            translation: """
            # 夜间维护记录

            部署已经开始，当前批次正在逐步完成**配置检查**与连接验证。

            ## 当前进度

            - 配置文件已载入
            - `TOKEN` 保持原样

            | 阶段 | 当前状态 | 备注 |
            | :--- | :---: | ---: |
            | 构建 | **进行中** | 正在整理输出并自然换行 |
            | 验证 | 等待下一批结果 | 尚未完成
            """,
            state: .streaming,
            contentFormat: .semanticMarkdown
        )
        panelCoordinator.showResult(
            store: sessionStore,
            at: nil,
            pointer: NSEvent.mouseLocation,
            activate: true
        )
    }

    func presentCompletedMarkdownUIAutomationFixture() {
        sessionStore.installUIAutomationFixture(
            surface: .quickInput,
            sourceText: "# Release Notes\n\n- Preserve structure\n- Keep `TOKEN` unchanged",
            translation: """
            # 发布说明

            Marla 会在翻译完成后显示**清晰排版**，同时保留原始 Markdown；[**粗体链接**](https://example.com/strong)也保持清晰字重。

            ## 本次改进

            - 标题、列表与引用可直接阅读
            - 行内代码 `TOKEN` 保持原样

            > 阅读时保持标题、段落、列表与表格的连续顺序。

            | 能力 | 输出 | 状态 |
            | :--- | :---: | ---: |
            | 强调 | **粗体字重保持清晰** | 完成 |
            | 表格 | 按该列最长内容分配宽度，超出后自然换行 | 完成 |

            [查看验证说明](https://example.com/check)

            ```zsh
            ./scripts/check.sh
            ```
            """,
            state: .completed,
            contentFormat: .semanticMarkdown
        )
        panelCoordinator.showResult(
            store: sessionStore,
            at: nil,
            pointer: NSEvent.mouseLocation,
            activate: true
        )
    }

    func presentMarkdownCodeStylingUIAutomationFixture() {
        sessionStore.installUIAutomationFixture(
            surface: .selection,
            sourceText: "# Code Styling\n\nKeep code readable without overpowering the translation.",
            translation: """
            # 开发

            安装依赖后运行以下命令：

            ```zsh
            npm install

            npm run tauri:dev
            ```

            第一行保留 `npm run sidecar:linux` 命令。
            第二行保留 `npm run sidecar:windows` 命令。

            输出目录为 `src-tauri/binaries/`，目标包括 `aarch64-apple-darwin` 与 `x86_64-apple-darwin`。
            """,
            state: .completed,
            contentFormat: .semanticMarkdown
        )
        panelCoordinator.showResult(
            store: sessionStore,
            at: nil,
            pointer: NSEvent.mouseLocation,
            activate: true
        )
    }

    func presentMarkdownComparisonUIAutomationFixture() {
        sessionStore.installUIAutomationFixture(
            surface: .selection,
            sourceText: """
            # Source Notes

            The protected selection keeps **source emphasis** and `TOKEN` intact.

            - Preserve headings and lists
            - Render the source only when expanded

            | Input | Format |
            | :--- | :---: |
            | Selection | Markdown |
            """,
            translation: """
            # 原文对照

            译文与保留结构的原文可以在同一结果卡中阅读。
            """,
            state: .completed,
            comparisonExpanded: true,
            contentFormat: .semanticMarkdown
        )
        panelCoordinator.showResult(
            store: sessionStore,
            at: nil,
            pointer: NSEvent.mouseLocation,
            activate: true
        )
    }

}
