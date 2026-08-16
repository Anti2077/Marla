import AppKit
import MarlaCore

extension MarlaApplicationModel {
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

            > 流式阶段仍显示原始字符，完成后才切换视图。

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

}
