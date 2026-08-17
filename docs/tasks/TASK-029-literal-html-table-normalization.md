# TASK-029：纯文本 HTML 表格归一为 Markdown

Status: Complete

Owner: Project owner + Agent

Created: 2026-08-17

Updated: 2026-08-18

Origin: direct request / defect

Conversation: 2026-08-17，复制得到 literal `<table>` 时无法作为 Markdown 表格翻译

## Initial request

项目所有者发现部分应用复制表格时得到一整段 literal HTML，例如 `<table border="1"><tr><td>…</td></tr></table>`。当前这类字符串不能稳定进入已有 GFM pipe-table 合同，要求在请求 Provider 前转换为简单 Markdown 表格。

## Outcome

当受保护 Copy 或 Quick Input Paste 只提供一段可信的 literal HTML table 文本时，Marla 会在本地、安全地把表格归一为 GFM pipe table，并以 `semanticMarkdown` 交给翻译引擎；普通包含尖括号的文本、畸形 HTML 和不受支持的复杂表格继续诚实降级，不执行内容或加载资源。

## Why now

TASK-028 已支持真正的 HTML Pasteboard representation 到 Markdown 的转换，但 plain-text representation 中出现 literal `<table>` 时仍被当作普通文本。真实样本证明同一结构可能通过不同应用以不同 Pasteboard 类型到达，需要在既有原生归一化边界补齐这一窄缺口。

## In Scope

- 在 `NativeFormattedContentNormalizer` 的 plain-text 输入边界识别完整或混合文本中的 literal HTML `<table>` fragment。
- 复用本地 Foundation XML/HTML 解析和现有安全清洗边界，把 `tr`、`th`、`td` 转成简单 GFM pipe table。
- 保留单元格可见文本、HTML entity、Markdown 特殊字符和 `${BUILD_ID}$`、`${MIN_OS}$`、`${STATUS}$` 等占位符；单元格内 `|` 必须正确转义。
- 转换成功后声明 `semanticMarkdown`；无表格、解析失败、空表格或不支持的复杂结构不得伪造表格。
- 同时覆盖 Quick Input Paste 与生产 protected-Copy 的共享 normalizer，不改变 AX/Vision 内容边界。
- 让 rich Markdown 与 plain-text 的可见文本一致性校验理解 GFM pipe table，复用 Marla 已有表格解析和 plain projection，避免 Foundation `AttributedString(markdown:)` 抹掉单元格边界后误降级。
- protected Copy 在同一新 Pasteboard `changeCount` 下连续观察到相同非空 `TranslationContent` 后才接受，给 Flux Markdown 等延迟/渐进填充 representation 的来源一个有界稳定窗口。
- 对没有 charset 声明但实际为 UTF-8 的 `public.html` Pasteboard data，先按 UTF-8 解码成原生字符串再交给本地 HTML parser；非 UTF-8 数据保留原有 data parser fallback，避免 raw NBSP 被误解码成额外 `Â` 并造成 rich/plain 假冲突。
- 增加 Swift 回归并同步 Task、STATUS、Quick Input/划词相关功能规格。

## Out of Scope

- 在译文渲染器中执行或直接渲染任意 HTML。
- 把 Provider 返回的 canonical HTML 自动改写为 Markdown。
- 支持 `rowspan`、`colspan`、嵌套表格、CSS 布局、附件或任意 DOM 到 Markdown 转换。
- 改变 Provider/FFI schema、Markdown copy 的 canonical 语义或新增 HTML/RTF 多 representation 输出。
- 放宽 ADR-0009 的 rich/plain 可见文本一致性要求，或仅凭“内容更长”信任冲突的富 representation。
- 截图结构 OCR。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-17 | Project owner | 把复制得到的 literal HTML table 转成简单 Markdown 表格后再交给翻译引擎 | 新增 plain-text HTML table 检测、占位符/转义/降级回归，并复验 protected Copy 与 Quick Input 的共享输入合同 | Complete |
| 2026-08-18 | Project owner | Flux Markdown 混合选择可完整粘贴到 Obsidian，但 Marla 查看原文缺少/扁平化表格，要求纳入 TASK-029 修复 | 新增 GFM-aware rich/plain 校验、同一 Copy 结果稳定观察，以及完整 Markdown/HTML 与 plain projection 的 Flux 形态回归 | Complete |
| 2026-08-18 | Project owner | 固定 App 复验仍失败：混合选择降级为纯文本，单独选择表格可保留 Markdown | 用真实 Flux Markdown 复现后确认 checkbox 的 plain projection 使用行首 U+FFFC；新增精确回归并仅规范该控件占位符 | Complete |
| 2026-08-18 | Project owner | 最新固定 App 复验仍把混合选区的表格逐行显示，要求确认是否真正重建并继续修复 | 脱敏真实审计确认 Flux 提供的 HTML 含 1 个 table，但无 charset 的 UTF-8 raw NBSP 被 data parser 误解码为 `Â + NBSP`，导致一致性假冲突并降级到无表格 RTF；改为 UTF-8 string-first HTML 解析并保留非 UTF-8 fallback | Complete |

## Current evidence

- `LiteralHTMLTableNormalizer` 已接入 `NativeFormattedContentNormalizer` 的共享 plain-text 边界；Quick Input Paste 与 protected Copy 得到 literal table 时都会在 Provider 请求前输出 `semanticMarkdown`。
- 用户样本、混合段落、entity、pipe、空 cell、占位符、复杂/畸形结构、围栏与多反引号 inline-code 示例均有回归覆盖。为防止 HTML tidy 静默搬移并丢弃内容，解析后还会校验文档与 table 的可见文本一致，并限制 table/section/row/cell 的简单结构。
- Flux follow-up 已把 semantic Markdown 可见投影切到 `MarkdownResultDocument.parse(...).plainText`，并规范 task-list 视觉 marker；完整“标题 + task list + 三列表格”与等价 plain projection 保留 `semanticMarkdown`，不完整 plain projection 仍回落为 `plainText`。
- protected Copy 现在只在同一新 `changeCount` 下连续两次得到完全相同的非空 `TranslationContent` 后接受；候选变化会重新稳定，原有取消、失焦、超时、并发写入和 snapshot 恢复保护不变。
- 真实 Flux Markdown 复现显示，混合选择的每个 HTML checkbox 在 plain Pasteboard projection 中以行首 U+FFFC（object replacement character）表示；上一轮合成回归漏掉了这个来源特征，因此仍发生 rich/plain mismatch。当前规范化只移除行首该控件占位符，不移除正文内部 U+FFFC，也不改变内容长度信任规则。
- 项目所有者再次复验后，最新固定 App 的脱敏审计确认来源为 `com.xykong.Markdown`、最终内容为 `semanticMarkdown`，但解析出的 GFM table 数量为 0，内容也不含 literal `<table>`；剪贴板恢复和焦点保持均成功。进一步的非内容候选审计确认 Flux 实际提供 `public.html`、`public.rtf` 与 plain representations：HTML 可解析出 1 个 table，但 visible match 失败；RTF visible match 成功但 table 数为 0。
- 首差异码点审计把 HTML/plain 归一化长度定位为 302/292，首个差异为 HTML 的 U+00C2 (`Â`) 对 plain 的 `H`。Flux HTML 的原始 UTF-8 NBSP 字节在没有 charset 声明时被 `XMLDocument(data:)` 按 Latin-1 路径解释成 `Â + NBSP`，每个 raw NBSP 多出一个可见 `Â`。HTML 现在优先经 `String(data:encoding:.utf8)` 后用 `XMLDocument(xmlString:)` 清洗；无法 UTF-8 解码时仍保留原有 data parser fallback。回归覆盖 raw NBSP、U+FFFC checkbox plain projection 与完整 table，且不放宽任意其它可见文本差异。
- 最终 `./scripts/check.sh` 通过 20 项 Rust 与 144 项 Swift（3 项 Vision host 限制 skip）、Swift Package、Xcode Debug、结构、格式、shell、空白与 diff 门禁。新增 GFM/task-list 一致性、不完整 plain 拒绝、渐进 Copy 候选、Flux U+FFFC checkbox projection，以及无 charset UTF-8 raw NBSP HTML 回归均通过。`./scripts/build-test-app.sh` 随后重建并验证固定 Release App 的 Bundle ID、版本、最低系统、arm64、Paper Lantern 资源、稳定签名和 designated requirement。
- 最终固定 App 对同一真实 Flux“标题 + 四个 checkbox + 三列表格”选区的脱敏审计得到 `contentFormat=semanticMarkdown`、`semanticMarkdownTableCount=1`、`sourceApplicationBundleID=com.xykong.Markdown`、`focusPreserved=true`、`clipboardPreserved=true`，且最终 Markdown 不含 literal `<table>`。修复前同一选区的 table count 为 0。项目所有者的查看原文/真实 Provider 界面确认仍待完成。

## Proposed approach

在共享内容归一化边界为可信 plain-text 值增加窄检测；真正 `.html` representation 继续使用通用安全转换器，literal table 使用独立的严格 table-only parser。只有存在配对 table 标签、本地解析得到简单矩形行列且完整可见文本未被 tidy 搬移或丢弃时才转换。若输入包含 table 之外的文本，则转义为 Markdown 字面文本、保留顺序并把表格 fragment 替换为 GFM table；任何安全/一致性条件失败都让完整输入原样返回 `plainText`。

Flux follow-up 保持 ADR-0009 的一致性合同，但把语义 Markdown 的可见投影切到 `MarkdownResultDocument.parse(...).plainText`，使 GFM header/body/cell 与 ordinary block 共用已验证解析语义。protected Copy 不记录或比较原始敏感字节，只在既有 0.8 秒期限内要求连续两次归一化候选完全相等；候选变化会重新开始稳定观察，新的 `changeCount` 仍按并发外部写入中止并保护原 Pasteboard。

## Acceptance criteria

- [x] 用户提供的 `<table border="1">…</table>` 样本在请求前变为三列表头 + 三行 body 的 GFM pipe table。
- [x] `${BUILD_ID}$`、`${MIN_OS}$` 和 `${STATUS}$` 逐字保留，不被解释或翻译前改写。
- [x] `<th>`/`<td>`、HTML entity、单元格 pipe、空单元格和 table 前后普通段落有回归覆盖。
- [x] 没有 `<table>` 的普通文本、尖括号表达式、畸形/空表格、`rowspan`/`colspan` 或嵌套表格安全降级为原始 `plainText`。
- [x] 转换不执行 script/style、加载图片或远程资源，也不改变 protected Copy 的快照恢复与 AX/Vision 边界。
- [x] Quick Input Paste 与受保护 Copy 共用同一转换结果；转换成功发送 `semanticMarkdown`。
- [x] 现有 `.html`、Markdown、RTF/RTFD、attributed text、GFM table 和普通纯文本回归无退化。
- [x] 新增代码不突破结构门禁；`./scripts/check.sh` 通过。
- [x] 固定 Release App 重建并验证；项目所有者可用该样本确认请求前 Markdown。
- [x] Task、STATUS 和相关功能文档与实际行为一致。
- [x] 完整 GFM Markdown 与等价 plain projection 可通过一致性校验；完整表格不会因 Foundation 投影丢列边界而降级。
- [x] Markdown/HTML rich representation 与不完整 plain projection 仍诚实降级，不因 rich 内容更长而绕过 ADR-0009。
- [x] protected Copy 对同一 changeCount 的渐进候选等待至连续两次相等，且取消、失焦、超时、并发写入和恢复语义不变。
- [x] 无 charset 的 UTF-8 HTML 中 raw NBSP 不得被误解码成 `Â + NBSP`；修复后 HTML/table 仍必须通过原有完整 plain projection 一致性校验，非 UTF-8 representation 保留安全 fallback。
- [x] Flux Markdown“段落 + 列表 + 表格”真实选择在查看原文与 Provider 输入中包含完整 GFM 表格，并仍完整恢复原剪贴板。

## Verification

### Automated

```sh
./scripts/check.sh
```

定向测试必须覆盖用户样本、混合段落、实体/pipe/空 cell、占位符逐字保留，以及复杂/畸形 HTML 的诚实降级。

### Manual

在固定 `artifacts/Marla_dev.app` 中把用户样本以纯文本粘贴到 Quick Input，并从提供 literal HTML plain representation 的来源触发一次 protected Copy；确认发给 Provider 的内容为 GFM pipe table，原 Pasteboard 完整恢复，结果卡仍走现有 Markdown 表格路径。凭据由项目所有者使用既有 profile，不读取或记录 Key。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/DATA_CONTRACTS.md`
- `docs/architecture/decisions/ADR-0006-selection-copy-compatibility.md`
- `docs/architecture/decisions/ADR-0009-semantic-markdown-translation-contract.md`
- `docs/features/quick-input.md`
- `docs/features/inline-translation.md`
- `Sources/MarlaApp/Content/NativeFormattedContent.swift`
- `Sources/MarlaApp/Selection/ClipboardSelectionFallback.swift`
- `Sources/MarlaApp/Sessions/QuickInputMarkdownEditor.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors (optional)

| Contributor | Objective | Required Reading | Write ownership | Permission | Output / status |
| --- | --- | --- | --- | --- | --- |
| `task029_docs` | 同步 literal HTML table 输入归一化的用户可见合同 | AGENTS.md、STATUS、TASK-029、ADR-0006/0009、Quick Input、Inline Translation | `docs/features/quick-input.md`、`docs/features/inline-translation.md` | Edit | Complete; main Agent reconciled wording against the final implementation |

## Risks and rollback

- 普通文本可能讨论 HTML 代码；检测必须足够窄，不能把代码示例或尖括号表达式误当作富结构。
- HTML table 可包含跨行/跨列、嵌套块和不安全节点；不支持的结构必须整体降级，不能静默错列。
- 转换后输入格式从 `plainText` 升级为 `semanticMarkdown`，会启用 Markdown Provider 提示；只允许有可靠 table 证据时升级。
- 回滚时移除 literal plain-text 检测和新增测试，保留 TASK-028 已验证的真正 HTML representation 路径。

## Decisions needed

None. 本 Task 采用简单矩形表格边界；复杂 HTML 表格诚实降级，不自动扩大范围。

## Completion record

- Verified commit: `895a1de`。
- Automated evidence: `NativeFormattedContentTests` 21/21 通过；最终 `./scripts/check.sh` 全绿，包含 20 项 Rust、144 项 Swift（3 项 Vision host 限制 skip）、Swift Package、Xcode Debug、结构门禁、格式、shell、空白与 diff 检查。
- Manual evidence: `./scripts/build-test-app.sh` 重建并验证固定 `artifacts/Marla_dev.app` 的 Bundle ID `com.marla.app`、版本 0.1.0、macOS 14.0+、arm64、Paper Lantern 资源、稳定签名 `API Usage Monitor Dev` 与 designated requirement。最终真实 Flux 混合选区脱敏审计得到 `semanticMarkdownTableCount=1`、`clipboardPreserved=true`、`focusPreserved=true`；项目所有者随后确认“的确修好了”。
- Documentation updated: TASK-029、STATUS、Quick Input 与划词翻译规格均已同步 literal HTML、GFM-aware 校验、protected Copy 稳定观察、U+FFFC checkbox 与 UTF-8 raw NBSP 修复边界。
- Remaining work promoted to: None；额外应用覆盖仍属于既有发布验证广度，不新增产品能力。
- Scope changes closed: 本 Task 的 literal HTML、Flux 混合表格、真实固定 App 和剪贴板恢复验收均已关闭。
- Parallel contributions integrated: `task029_docs` 的 Quick Input 与划词规格贡献已由主 Agent 按最终代码、测试和真实审计统一校正。
