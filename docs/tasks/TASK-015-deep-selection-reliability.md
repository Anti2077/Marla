# TASK-015：深度提升跨应用划词识别可靠性

Status: Done

Owner: Project owner + Agent

Created: 2026-08-07

Updated: 2026-08-09

Origin: BL-001 / project owner direct request / observed cross-application defects

Conversation: 2026-08-07 深度优化划词翻译

## Initial request

项目所有者要求开启新的 Task，深度优化划词翻译；当前在许多真实场景中无法识别可见选区，现有实现方式可能存在系统性局限。

## Outcome

Marla 默认使用有界、可诊断且不触碰剪贴板的 Accessibility 选区获取链路；用户明确开启兼容模式后，在 AX 无法取得选区时使用受保护的 Copy fallback。项目所有者已在此前失败的 Codex 与微信场景中确认取词成功率显著提升，并明确接受本次兼容适配目标完成。完整发布矩阵、跨应用几何/焦点证据和截图 `Esc` 真实复验继续保留为 BL-001/BL-002，不被本 Task 的完成状态掩盖。

## Why now

跨应用划词是 Marla 的核心入口，也是 0.1.0 尚未通过的发布阻塞项。当前实现已经覆盖标准 AX Range 和 Web Text Marker，但旧版 VSCodium 真实运行仍出现“可见选区存在、Marla 报告无选区”，Terminal、Safari、TextEdit 和最终 VSCodium 构建也没有完成当前产物验收。项目所有者现已明确选择 `BL-001` 并要求从实现方式本身深挖，而不只做一次兼容矩阵勾选。

## In Scope

- 建立 TextEdit、Terminal/Ghostty、Safari/Zen、Codex、VSCodium 和微信的代表性选区矩阵，覆盖原生文本、Web/Electron、自定义文本树、短句、多行、Unicode、编辑区/非编辑文本、空选区和可用/不可用几何。
- 审查并改进前台应用、focused element、focused window、Accessibility 后代与 Web Text Marker 的候选根和读取顺序。
- 修复同一元素的标准 Range、直接选中文字和 Text Marker 之间过早终止或错误覆盖的问题。
- 对 Accessibility 图执行全局去重和明确的元素/耗时边界，避免复杂 Electron/Web 树中的重复遍历、环和主线程长时间停顿。
- 在不记录选区正文、不采集附近文字、不写入磁盘的前提下提供足以区分失败阶段的结构化诊断证据。
- 增加默认关闭、用户明确开启的 Bob 兼容模式：Accessibility 失败后可模拟 `⌘C`，只读取本次 Copy 产生的文本，并在所有成功、失败、取消和超时路径恢复原剪贴板。
- 为检索优先级、空选区合并、循环/重复节点、预算耗尽、文本提取和几何降级增加可重复自动化测试。
- 使用当前固定签名 App 验证快捷键、选区文本、锚点/指针降级、源应用焦点和剪贴板不变，并同步功能规格、验收清单、Backlog 与 `STATUS.md`。
- 修复截图框选会话中真实 `Esc` 无法终止覆盖层的问题；保留 View、本地/全局事件路径，并增加会话级系统事件兜底和幂等清理。

## Out of Scope

- 默认启用 Copy fallback、静默读取任意既有剪贴板内容、无法验证快照完整性时继续发送文本。
- 读取附近文字、窗口标题、DOM、应用语境或持续监控选区。
- 浏览器扩展、DOM 注入、私有 API、OCR fallback 或按应用写死脚本。
- 原位覆盖翻译、持续跟随滚动、Force Touch、截图识别/OCR/翻译流程和翻译 Provider 逻辑；本 Task 仅纳入截图框选的 `Esc` 取消入口。
- 保证密码框、安全输入区、受 DRM/系统保护内容或完全不暴露 Accessibility 选区的应用可读取。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-07 | Project owner | 从单次 `BL-001` 验证扩展为对划词实现方式的深度可靠性优化 | 必须先形成失败分类与检索链路证据，再完成自动化和真实四类应用矩阵 | Completed; remaining release matrix stays in BL-001 |
| 2026-08-07 | Project owner | 报告 Zen、Ghostty 正常，但 Codex、微信仍无法划词；截图框选 `Esc` 仍无法退出 | 增加指针命中/父链快速路径、复杂/自定义 AX 树回归，以及真实截图 Escape 退出验收 | Completed for selection implementation; real Escape remains BL-002 |
| 2026-08-09 | Project owner | 实测确认 Bob 使用模拟 `⌘C` 后还原剪贴板，并授权按该方案适配 | 增加默认关闭的 Copy 兼容开关、完整 pasteboard 快照/恢复、并发写入保护和 Codex/微信真实验证 | Completed |
| 2026-08-09 | Project owner | 确认新方案实测成功率很高，接受本目标完成；当前 API `unauthorized` 不属于划词适配目标 | 以 Codex 剪贴板恢复、微信成功进入请求、完整自动化和固定产物作为关闭证据；API 凭据与剩余发布矩阵不阻塞本 Task | Completed |

## Current evidence

- 任务开始时的基线只从 system-wide `AXFocusedUIElement` 开始，最多广度遍历 2,000 个元素；没有以前台应用元素或 focused window 为候选根的降级路径。
- 子节点只在单个父元素内部按对象地址去重；整次遍历没有全局 visited 集合，复杂 AX 图中的重复引用或环会消耗预算。
- 同一元素只要标准 `AXSelectedTextRange` 长度为 0 就立即返回 `.empty`，不会继续尝试该元素可能提供的非空 `AXSelectedTextMarkerRange`，存在可确认的假阴性路径。
- 任务开始时的子元素只读取 `AXChildren`、`AXVisibleChildren`、`AXContents` 和 `AXRows`，并在每个父元素内按文本角色排序；尚未证明这能稳定到达所有 WebKit/Electron 编辑器的实际选择节点。
- 当前测试只直接覆盖 UTF-16 `CFRange` 截取；没有隔离测试候选根、遍历、机制合并、预算或 AX 错误分类。
- 旧的真实 VSCodium 运行曾在可见选区存在时返回“没有选中文字”；后续 Text Marker 扩展通过编译和自动化，但没有完成最终真实复测。Terminal、Safari、TextEdit、焦点保持和锚点放置仍未验收。
- 2026-08-07 最新固定 App 的无选区 Codex 脱敏审计确认：`sourceApplicationBundleID=com.openai.codex`、`rawPointerHitCount=1`、`hadFocusedWindow=true`，但当时没有系统/应用 focused 元素，251 个节点在 89ms 内有界遍历后返回 `emptySelection`；该报告不包含正文或剪贴板内容。
- 代码已修复两条可复现的假阴性风险：选区属性不再受不完整 `AXAttributeNames` 列表阻断；指针命中同时探测应用和 system-wide AX 根，并在前台应用拥有 renderer/helper AX 节点时保留候选。截图窗口另增加 `performKeyEquivalent`/`cancelOperation` 路由，以及事件 tap 的 listen-only 回退；真实 `Esc` 仍待解锁桌面后的最终验收。
- 最新改动继续移除子节点探测对 `AXAttributeNames` 的依赖，兼容以 CFArray 返回子节点的客户端，并把通过身份校验的 system-wide focused-application 根加入图检索；快捷键触发时捕获的前台应用会贯穿本次读取，避免异步 Carbon 回调把 AX 查询绑定到 Marla。
- 现有产品、架构和 ADR 一致要求：Swift/AppKit 负责 Accessibility 与剪贴板兼容模式；0.1.0 默认不模拟 Copy、不采集附近文字，用户开启兼容模式后才允许受保护的 Copy fallback，缺少几何时诚实降级到指针附近。
- 项目所有者已授权把 Bob 式“模拟 `⌘C` + 恢复剪贴板”作为默认关闭的可选兼容模式；默认关闭仍保持原有隐私边界。

### 社区实现证据（2026-08-09）

- Bob 官方文档没有公开内部取词实现；它只明确说明普通划词适用于“可以选中文本，并且可以复制”的场景，无法选中或复制时建议截图翻译，获取不准时建议输入翻译。这个描述不能证明 Bob 只依赖 AX。
- Bob 的公开 AppleScript 接口区分 `selectionTranslate`（由 Bob 自己读取当前选区）、`pasteboardTranslate`（从剪贴板读取）和 `translateText`（外部直接传入文本）；PopClip 集成则把 `{popclip full text}` 直接传给 Bob。由此可确认 Bob/PopClip 至少存在外部文本直传入口，但不能据此推断 Bob 的内部 fallback 细节。
- 开源 SelectedTextKit 明确实现了有序策略：Accessibility → 菜单栏 Copy action → 模拟 `⌘C`；浏览器另有 AppleScript 路径。其 Copy 路径会备份全部 pasteboard items、轮询 changeCount、读取新文本并恢复原内容；Safari 使用更长的等待窗口。该项目把多路径 fallback 而非 AX 深遍历作为可靠性的主要来源。
- Easydict 直接使用 SelectedTextKit，并在 AX 失败时对 WeChat、`com.openai.chat`、VS Code 等应用允许强制 fallback；源码还在菜单 Copy 与模拟快捷键之间按场景切换。这与当前 Codex/微信现象高度吻合，但它包含按应用 allowlist 和剪贴板操作，均超出本 Task 现有边界。
- 另一个开源 portable-translator 也验证了相同顺序：鼠标拖选结束后先读 `AXSelectedText`，失败后模拟 `⌘C`，轮询并恢复剪贴板。它的实现规模和维护度不足以单独证明成熟度，但可作为社区趋同证据。
- PopClip 官方开发文档确认它可以取得当前选区全文并通过脚本、macOS Service 或插件传出；这是一条“外挂层获取文本、Marla 接收显式文本”的候选路径，仍需在 Codex 和微信做真实验证。
- 项目所有者随后通过实测确认：Bob 会模拟 `⌘C` 读取选区，然后还原原剪贴板内容。剪贴板历史工具未留下明显记录，符合“短暂写入后立即恢复”或历史工具只保留最终状态的表现。该证据将“模拟 Copy + 完整恢复”从社区推测升级为 Bob 的已确认行为，并直接促成项目所有者授权 Marla 的默认关闭兼容模式。

**结论**：Codex/微信无法识别而 Zen/Ghostty 可识别，最可能是前两者没有稳定暴露标准 AX 选区，而 Bob 用模拟 Copy 绕过了这一限制。本 Task 现已获授权实现默认关闭的“AX → `⌘C` 备份/恢复”兼容模式；PopClip/Service 和按应用脚本仍只作为后续候选，不进入本次实现。

## Proposed approach

将平台 AX 调用与检索决策分层：平台层在触发时固定前台应用身份，提供 system focused element、应用 focused element、focused window、通过身份校验的 focused-application 根和有界子关系；检索层按确定顺序评估直接文本、标准 Range 与 Web Text Marker，只有所有可用机制都为空后才进入可选 Copy fallback。AX 子节点探测不以不完整的 `AXAttributeNames` 作为前置许可，而由实际 AX 调用判定能力；整次检索使用全局对象去重、元素与耗时双预算，并保留不含选区正文的机制、角色、AX 错误和预算结果。兼容模式以稳定 `changeCount` 包围完整 `NSPasteboard.general` item/type/data 快照，再发送带 Command 修饰键的 `⌘C`，只接受本次变化后的非空文本；接受前再次确认源应用仍在前台，恢复后重新读取并逐表示比较。恢复前若发现其他进程已再次写入，则不覆盖更新后的剪贴板，并将该状态写入脱敏诊断；重复划词快捷键取消当前等待并先完成清理。恢复失败时不发送翻译请求。文本取得后仍从实际命中元素解析 Range/Marker bounds，Copy fallback 没有几何时卡片降级到触发时指针附近。该调整属于已授权的 Swift/AppKit 平台集成，不改变 Rust 边界；默认关闭的设置字段和剪贴板生命周期验收同步更新。

## Acceptance criteria

- [ ] Release follow-up (BL-001): TextEdit 原生文本、Terminal 文本、Safari 普通网页文本与输入区、VSCodium Monaco 编辑器均在当前固定签名 App 中完成短句、多行或 Unicode 真实矩阵。
- [x] Codex 可见正文和微信可选消息文本能通过 `⌃⌥D` 读取；项目所有者确认新方案在原失败场景中的成功率很高。
- [ ] Release follow-up (BL-001): Zen 与 Ghostty 的既有成功路径完成当前固定 App 回归。
- [x] 默认关闭 Copy 兼容模式时读取行为不触碰剪贴板；开启后，AX 失败的 Codex/微信场景可通过模拟 `⌘C` 读取文本。
- [x] Copy fallback 只接受本次 `changeCount` 变化后的非空文本；完整快照包含所有 item、类型、顺序和可读数据。
- [x] Copy fallback 在成功、空结果、异常、取消、超时和恢复失败路径均有清理结果；其他进程已写入剪贴板时不覆盖其更新内容。
- [x] 同一元素的某一种选择机制为空或失败时，仍会继续评估其它可用机制；非空 Text Marker 不再被零长度标准 Range 覆盖。
- [x] 候选根与后代图全局去重，存在重复节点或环时不会无限遍历；元素/耗时预算耗尽有明确、可测试的诊断结果。
- [x] 无选区、focused element 缺失、应用未暴露选择和权限缺失能够区分；所有失败均不发送翻译请求。
- [x] 诊断不包含选区正文、附近文字、窗口标题、API Key 或截图，不写入持久存储。
- [ ] Release follow-up (BL-001): 在完整真实矩阵中复核有/无 bounds 的卡片位置、源文本、剪贴板类型、焦点保持和卡片交互。
- [x] 检索策略、错误合并、循环/重复节点、预算、Unicode 文本与几何降级均有自动化回归覆盖。
- [x] `./scripts/check.sh` 和 `./scripts/build-test-app.sh` 通过，固定 `artifacts/Marla_dev.app` 保持既有 Bundle ID、arm64、稳定签名和 designated requirement。
- [ ] Release follow-up (BL-002): 截图框选覆盖层出现后，真实 `Esc` 能立即退出；不执行截图、OCR、网络请求或文件写入，重复/迟到取消不会影响下一次会话。
- [x] `docs/features/inline-translation.md`、中英双语 `SPEC.md`/`ACCEPTANCE.md`、`BACKLOG.md` 和 `STATUS.md` 与最终验证事实同步。

## Verification

### Automated

```sh
./scripts/check.sh
./scripts/build-test-app.sh
```

2026-08-09 自动化证据：Swift Package 68 项测试通过；Copy fallback 覆盖新 `changeCount`、多 item/type/data 重建、快照期并发变化、成功/空结果/无 Copy 事件/取消/失焦/超时/并发新写入/恢复失败，脱敏报告新增完整快照前后是否一致的 `clipboardPreserved`。`./scripts/check.sh` 通过（Rust 17、Swift 68、Swift/Xcode Debug 构建、格式/空白/diff 检查）；`./scripts/build-test-app.sh` 重新覆盖并验证固定 `artifacts/Marla_dev.app` 的 Bundle ID `com.marla.app`、arm64、稳定签名 Authority `API Usage Monitor Dev` 和既有 designated requirement。

2026-08-09 真实证据：项目所有者在当前固定 App 中确认一个此前失败的 Codex 可见选区已成功取得，且剪贴板最终内容已还原；随后微信选区进入真实翻译请求并显示 Provider `unauthorized`，证明微信文本已由兼容取词链路取得。项目所有者继续试用后确认新方案成功率很高，并明确接受本目标完成。当前默认 DashScope profile 的独立 Keychain 凭据缺失属于本机 API 配置，不纳入划词适配完成判定。兼容性设置页浅色/深色真实 Release 截图位于 `artifacts/ui-review/task-015/`，五维评分为 8/8/8/8/7。完整发布矩阵与本轮真实截图 `Esc` 继续留在 BL-001/BL-002。

### Manual

后续 BL-001 在同一份固定签名 `artifacts/Marla_dev.app` 上完成 TextEdit、Terminal、Safari、VSCodium、Zen 和 Ghostty 发布矩阵；BL-002 复验截图 `Esc`。逐项只记录不含正文的命中机制、bounds、焦点和剪贴板摘要，不重新打开本 Task。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/features/inline-translation.md`
- `docs/features/screenshot-translation.md`
- `docs/tasks/TASK-009-reliable-screenshot-escape-cancellation.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0003-context-engine.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `docs/architecture/decisions/ADR-0006-selection-copy-compatibility.md`
- `Sources/MarlaApp/AccessibilitySelectionReader.swift`
- `Sources/MarlaApp/ClipboardSelectionFallback.swift`
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Sources/MarlaCore/SelectionModels.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`
- `Tests/MarlaCoreTests/MarlaCoreTests.swift`

## Risks and rollback

- 扩大候选根可能误读非前台或无关元素；必须绑定触发时前台 PID，并以真实焦点候选优先。
- 更深的 AX 查询可能阻塞主线程；双预算、全局去重和测试中的预算耗尽覆盖是硬边界。
- 不同应用可能同时暴露多种且不一致的选区表示；以可见非空选择为成功，但不得拼接多个节点或采集附近文本。
- 可通过关闭兼容模式或回退到当前 AX 有界读取器恢复；若 Copy fallback 的快照或恢复失败，必须停止翻译请求并报告失败，不得静默使用未确认的剪贴板内容。

## Decisions needed

None. 项目所有者已接受本目标完成，并明确把当前 API `unauthorized` 排除在划词适配之外。

## Completion record

- Verified commit: 未提交；在 `6503d13` 基础工作树完成并验证。
- Automated evidence: `./scripts/check.sh` 通过（Rust 17、Swift 68、Swift/Xcode Debug 构建、格式/空白/diff）；`./scripts/build-test-app.sh` 通过；`./scripts/verify-app.sh artifacts/Marla_dev.app` 在授权环境再次通过 Bundle ID、版本、最低系统、arm64 与稳定签名检查。
- Manual evidence: Codex 原失败选区成功且剪贴板还原；微信选区成功进入真实请求；项目所有者继续试用后确认整体成功率很高并接受目标完成。
- Documentation updated: TASK-015、`STATUS.md`、inline/screenshot feature specs、双语 0.1.0 SPEC/ACCEPTANCE、architecture/ADR、Backlog/Ideas。
- Remaining work promoted to: BL-001 完整跨应用发布矩阵；BL-002 截图真实 `Esc`、裁剪和权限复验。当前 API `unauthorized` 是缺失 Keychain 凭据的本机配置问题，按项目所有者要求不纳入本 Task。
- Scope changes closed: Yes。
