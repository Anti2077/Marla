# TASK-039：优化翻译窗口 Markdown 排版细节

Status: Active

Owner: Project owner + Agent

Created: 2026-09-02

Updated: 2026-09-02

Origin: direct request / visual defect

Conversation: 2026-09-02 创建新 Task 并优化翻译窗口 Markdown 渲染细节

## Initial request

项目所有者要求参考另外两颗工作树的最新 Task 建立新 Task，优化翻译窗口渲染 Markdown 时的细节，包括列表/表格的框线与圆角、代码块可读性等。

## Outcome

翻译窗口中的 Markdown 在保持原生、克制和连续可选择的前提下，获得更清楚的列表层级、具有圆角外框而不过度分割内容的 GFM 表格，以及在浅色和深色材质上都更易读的代码块与行内代码。

## Why now

TASK-028 已建立安全的原生 TextKit Markdown 投影，并完成标题、列表、引用、代码、链接和 GFM 表格的结构支持；当前真实固定 App 基线仍显示表格使用方正且层级偏弱的网格，列表 marker 偏小偏灰，代码块背景、语言标签和代码正文的对比不足。此时应在既有投影层内收敛视觉细节，不改变解析、canonical 内容或窗口行为。

## In Scope

- 优化无序与有序列表的 marker、缩进、换行对齐和嵌套层级，使 marker 清楚但不抢过正文。
- 优化 GFM 表格外观：使用清楚、克制的圆角外轮廓，避免四个直角和重复加粗的外层网格；保留内部行列关系、表头层级、自适应列宽、居中与自然换行。
- 提升 fenced code block 的浅色/深色可读性，包括背景、边框、圆角、内边距、语言标签、代码字体和行距；同步检查 inline code 的对比、圆角与跨行间隙。
- 译文和展开的可靠 `semanticMarkdown` 原文继续共用同一 attributed-document 构建与绘制路径。
- 增加定向属性、几何、选择/复制和测量回归；完善脱敏 Markdown UI fixture，覆盖嵌套列表、表格、行内代码和多行代码块。
- 运行完整检查、构建固定签名 Release App，并以浅色、深色和窄/宽结果卡真实截图完成五维 UI 复审。
- 同步本 Task、`STATUS.md` 及 Markdown 相关 UI/实现规格。

## Out of Scope

- 修改 Markdown 解析、Provider 输出、canonical Markdown、纯文本派生、复制格式、重试/语言/API 切换或最近记录恢复语义。
- 引入 WebView、HTML/RTF 渲染、语法高亮引擎、远程资源、脚本执行或新的 Markdown 依赖。
- 改变表格列宽算法、对齐合同、结果卡宽度预设、60% 高度上限、窗口位置、流式节流或 AppKit frame 动效。
- 重设计标题、引用、链接、语言栏、动作栏、Liquid Glass 或 Paper Lantern 身份层级。
- TASK-036 官网、TASK-038 API Profile 拖放，或其它工作树中的未提交内容。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-09-02 | Project owner | 参考另外两颗工作树创建新 Task，优化 Markdown 列表/表格框线、圆角、代码块可读性等细节 | 占用 TASK-039；新增三类呈现验收、定向回归、固定 App 截图与五维复审 | Active |
| 2026-09-02 | Project owner | 指出 fixture 中行内代码背景偏紧，希望背景更宽、更圆 | 行内代码首尾视觉 padding 与圆角调整为 6pt；补充几何回归并重新截图复核 | Active |

## Current evidence

- `TASK-039` 专用分支 `Anti2077/task-039-markdown-rendering-polish` 从本地 `main@506c4cf` 创建；TASK-036 与 TASK-038 位于独立工作树，本 Task 不继承或修改其内容。
- 现有脱敏 `markdown-completed-wide` 固定 App 浅色截图位于 `/private/tmp/marla-task039-before-light.png`：GFM 表格四角为直角，外框和内部网格同级；无序列表 marker 偏小且使用 secondary label；代码块 `zsh` 标签、背景和 0.5pt 边框在浅色材质上辨识度较低。
- `MarkdownResultAttributedDocument` 负责 list paragraph、`NSTextTable` cell 和 code attributed attributes；`MarkdownSelectableTextView` 在文字前绘制 fenced/inline code 背景。视觉优化可以留在 Panel presentation layer 内，不触碰 parser、session 或 Rust core。
- 当前代码块为 5pt 圆角、8pt TextBlock padding、13pt regular monospace、11pt tertiary language label，并使用 `labelColor` 6.5% 背景与 separator border；表格每个 cell 都绘制 0.5pt 全边框且没有圆角外层；列表 marker 与正文共享 15pt 字号但 marker 使用 secondary color。
- `MarkdownResultTextTests` 已覆盖解析、strong/link/list 字重、代码自定义背景属性、inline code 几何、跨 block 选择/复制、表格列宽与完成/流式测量，但尚未验证表格圆角装饰属性、列表 marker 层级和增强后的 code metrics。
- 实现后 `MarkdownResultTextTests` 29/29 通过；列表增加 marker/悬挂几何回归，表格增加整表装饰属性与仅内部 cell border 回归，行内代码几何回归已按项目所有者截图反馈锁定为首尾各 6pt 视觉扩展。
- `./scripts/check.sh` 通过 24 项 Rust、完整 Swift suite、Swift Package、Xcode Debug、结构、脚本、空白与 diff 门禁；`MarkdownResultSelectableText.swift` 未超过 800 行结构上限。
- `./scripts/build-test-app.sh` 通过；固定 `artifacts/Marla_dev.app` 为 `com.marla.app`、`0.0.0`、macOS 14.0、arm64，Paper Lantern 资源、稳定签名 `API Usage Monitor Dev` 与 designated requirement 有效。
- 最终 Markdown 几何证据为 `/private/tmp/marla-task039-final-light-narrow.png`（760px，对应 380pt）与 `/private/tmp/marla-task039-final-dark-wide.png`（1520px，对应 760pt）。窗口级截图只用于列表、表格与代码排版；真实玻璃使用不设置 `MARLA_UI_TEST_CAPTURE_PATH` 的固定 App 整屏证据 `/private/tmp/marla-task039-final-dark-wide-fullscreen.png`，确认仍为单层系统 `.glassEffect(.regular)`，后方桌面内容可见且被柔化。机器上其它工作树存在同 Bundle ID 实例，因此没有把其抢前台后的窗口截图纳入证据。
- 五维复审为 Philosophy 8、Visual Hierarchy 8、Craft 8、Functionality 9、Originality 7；每维均不低于 7。当前未见文字重叠、边框压字、横向滚动或窄/宽裁切。

## Proposed approach

1. 在现有 attributed-document 层定义语义化且动态适配外观的 Markdown presentation tokens，避免散落新的颜色、间距和圆角魔法数字。
2. 列表继续使用 TextKit paragraph/tab stop，不创建独立卡片；调整 marker 字重/颜色、层级缩进、正文 gap 与 line spacing，确保换行与嵌套稳定。
3. 表格继续使用 `NSTextTable` 负责布局，但只保留必要的内部分隔线；为整张表添加自定义 decoration attributes，由 `MarkdownSelectableTextView` 在文字前绘制一个完整的圆角背景与外轮廓，避免 cell 外边重复形成方角。
4. 代码继续使用一个连续可选 `NSTextView`；增强动态背景/边框和代码排版，绘制圆角不得改变字符、选择、复制或 canonical Markdown。
5. 先运行定向测试，再执行完整检查、固定 App 构建和真实浅/深、窄/宽截图复审；任何 TextKit 测量差异必须与实际 viewport 使用同一 attributed document。

## Acceptance criteria

- [x] 无序/有序列表 marker 在浅色与深色中清楚可辨；换行正文与首行正文对齐，至少两级嵌套保持稳定层级且不挤压可读宽度。
- [x] GFM 表格具有一个连续的圆角外背景/轮廓；四角不再由 cell 外边框显示为直角，内部行列仍清楚但不过度加重，表头、斑马层级或等效行层级保持克制。
- [x] 表格继续遵守当前自适应列宽、统一居中、自然换行、空单元格和 malformed fallback 合同；窄/宽结果卡都没有横向溢出或裁切。
- [x] fenced code block 在浅色与深色材质上明显区别于正文，语言标签、13pt 左右等宽代码、行距与内边距清楚；圆角和边框不压字，不让长行产生水平滚动。
- [x] inline code 与正文有足够区分，连续行背景不相碰，首尾 padding 和圆角稳定；链接、strong、italic 与 code 组合不回归。
- [x] 译文、流式完成态和展开的可靠 Markdown 原文继续共用同一原生投影；连续选择、`⌘C`、canonical Markdown copy、纯文本派生和视觉流式游标排除规则保持通过。
- [x] Markdown TextKit 实测高度、结果卡内容驱动增长、60% 高度封顶、单一纵向滚动 owner 与宽度预设行为不回归。
- [x] 定向测试、`./scripts/check.sh` 和 `git diff --check` 通过；新增代码不触发 800 行/8 顶层类型结构门禁。
- [x] `./scripts/build-test-app.sh` 通过，固定 `artifacts/Marla_dev.app` 的 Bundle、`0.0.0`、arm64、Paper Lantern 资源、稳定签名和 designated requirement 保持有效。
- [x] 固定 App 的浅色、深色、窄/宽 Markdown fixture 截图完成五维复审，Philosophy、Visual Hierarchy、Craft、Functionality、Originality 每维至少 7/10，且无重叠、裁切或不可读文本。
- [x] Markdown UI/实现规格、当前 Task 与 `STATUS.md` 同步到最终验证事实。

## Verification

### Automated

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter MarkdownResultTextTests
./scripts/check.sh
./scripts/build-test-app.sh
```

### Manual

- 固定 `artifacts/Marla_dev.app`，使用脱敏 Markdown fixture 分别采集 light/dark、380pt/760pt 结果卡。
- 样本同时包含两级无序/有序列表、长项换行、三列表格、空单元格、行内 code、带 language 的多行 fenced code block 和长命令。
- 对照变更前 `/private/tmp/marla-task039-before-light.png`，检查表格外角/内部线、列表 marker/缩进、code 背景/标签/正文，以及结果卡底部动作栏和滚动边界。
- 截图只保存脱敏 fixture；用户内容和截图不写入仓库。

## Required Reading

- `AGENTS.md`
- `docs/development/STATUS.md`
- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/product/BRAND.md`
- `docs/development/VERSIONING.md`
- `docs/development/UI_UX_SKILLS.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `docs/architecture/decisions/ADR-0007-app-layer-modularity.md`
- `docs/architecture/decisions/ADR-0008-paper-lantern-brand-identity.md`
- `docs/tasks/TASK-028-structured-translation-foundation.md`
- `docs/tasks/TASK-037-ui-motion-polish.md`
- `docs/versions/0.1.0/UI_SPEC.md`（仅作为已撤回版本的历史 Markdown 视觉合同，不作为当前发布合同）
- `docs/versions/0.1.0/IMPLEMENTATION.md`（仅作为已撤回版本的历史实现合同，不作为当前发布合同）
- `Sources/MarlaApp/Panel/MarkdownResultText.swift`
- `Sources/MarlaApp/Panel/MarkdownResultSelectableText.swift`
- `Sources/MarlaApp/Panel/StreamingMarkdownProjection.swift`
- `Sources/MarlaApp/Panel/TranslationCardView.swift`
- `Sources/MarlaApp/App/MarkdownResultUIAutomation.swift`
- `Tests/MarlaAppTests/MarkdownResultTextTests.swift`

## Parallel contributors (optional)

None. 本 Task 的 attributed-document attributes、TextKit 自定义绘制、测量回归和 UI fixture 紧密耦合，且 Task/`STATUS.md` 需要由主 Agent 统一解释与写入；不制造并行写入冲突。

## Risks and rollback

- `NSTextTable` 的 cell layout 与自定义 rounded decoration 属于不同绘制层；外框必须从真实 glyph/layout range 求得，不能从固定行高猜测，也不能盖住选择或文字。
- 自定义背景属性可能扩大 effective range 或改变 attributed-string equality，造成流式替换与测量抖动；属性只用于视觉，构建必须保持确定性。
- 提高对比时不能把代码块变成第二张卡片或让表格网格压过正文；浅色和深色均以系统动态色和克制层级复核。
- 若自定义表格绘制在窄宽、空单元格或滚动 dirty rect 下不稳定，回滚为现有 `NSTextTable` 外框，并保留可独立验证的列表/code 改进，不牺牲内容和复制正确性。

## Decisions needed

None. 本 Task 沿用已认可的 Restrained Native · Warm Minimal、单一连续 TextKit 表面和系统动态外观；不进行新的整体视觉方向选择。

## Completion record

- Verified commit:
- Automated evidence: `MarkdownResultTextTests` 29/29；`./scripts/check.sh`；`./scripts/build-test-app.sh`
- Manual evidence: `/private/tmp/marla-task039-final-light-narrow.png`、`/private/tmp/marla-task039-final-dark-wide.png`、`/private/tmp/marla-task039-final-dark-wide-fullscreen.png`；五维 8/8/8/9/7
- Documentation updated: `docs/versions/0.1.0/UI_SPEC.md`、`docs/versions/0.1.0/IMPLEMENTATION.md`、本 Task、`docs/development/STATUS.md`
- Remaining work promoted to:
- Scope changes closed: 实现与 Agent 视觉复审已完成；Task 保持 Active，等待项目所有者在固定 App 中体验后决定关闭
- Parallel contributions integrated: None
