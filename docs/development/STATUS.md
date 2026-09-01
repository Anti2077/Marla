# Project Status

Last updated: 2026-09-01

Development stage: Incubation / Unreleased

Release target: None. A version is assigned only when the project owner explicitly starts release preparation.

Overall state: In Progress — unversioned product incubation; no active release contract

Active task: None

TASK-037 已完成：共享动效语义现区分 100ms Reduce Motion 透明度、120ms 反馈、160ms 内容、180ms 布局、220ms 重排、320ms 快捷键融合与 900ms 等待呼吸；Settings、API 编辑器与拖拽、OCR 设置、Quick Input、结果卡、截图确认和快捷键局部状态使用明确且可中断的局部过渡，系统菜单/窗口行为保持系统拥有。结果卡宽度预设使用固定顶边的唯一目标 frame，SwiftUI 内容宽度逐帧跟随 AppKit 实际宽度，过渡 resize 不再并发启动高度动画；streaming→completed 不再对正文容器或 raw 文本触发几何动画。浅色玻璃表面增加自适应中性轮廓，Reduce Motion、键盘焦点、Escape 和辅助技术路径保持完整。`WidthPreset` 7/7、完成态正文动画回归 1/1、完整 24 项 Rust/180 项 Swift、Xcode Debug、结构门禁与固定签名 Release App 均通过；五维复审为 8/8/9/9/8。项目所有者于 2026-09-01 明确要求关闭、提交并合并，完成现场验收。未跟踪 `website/` 与 TASK-036 首页原型未纳入本 Task。

TASK-035 已完成：快捷键设置使用 `fn / ⇧ / ⌃ / ⌥ / ⌘` 修饰键切换与 32pt 单主键单元，编辑器直接位于每行操作名称和启用开关之间的留白，不打开 popover、sheet 或额外窗口；同一时间只展开一行。默认键位为划词 `⌃⇧D`、截图 `⌃⇧S`、快速输入 `⌃⇧Space`；完整旧默认配置会迁移，自定义配置保持不变；Fn/Globe 继续复用 Carbon 全局热键路径，不新增持续全局监听或权限。macOS 26 使用折叠 `.regular.interactive()`、展开 `.regular` 和 0.32 秒 matched geometry 将快捷键 chip 融合为固定 332×32pt 编辑条；Reduce Motion 使用 identity transition 并关闭短状态动画。最终折叠、D 展开和 Space 展开均保持 820×592；主键与修饰键共用 20pt 内容高度，外层 capsule 以 4pt 上下内边距形成连续玻璃边框，主键捕获态为居中 `ellipsis`，应用键为 24pt 圆形。无效或注册失败时确认键显示感叹号，独立 hover 命中层以 0 秒延迟同步显示具体原因。浅色、深色和 Reduce Motion 五维复审均为 8/8/9/9/8；完整检查与固定签名 App 已通过。实体 Fn/Globe 触发仍取决于具体键盘和系统 Globe 设置，不声明为已现场验证。

TASK-034 已由项目所有者于 2026-08-22 要求结束并关闭：最近翻译菜单中的来源和译文摘要改为纯文本；通用设置提供四种翻译窗口位置；记住位置保存面板左上角并在流式高度变化时保持顶部；结果卡动作栏提供可持久化的窄/中/宽宽度预设，popover 子窗口点击不会误触发外部点击隐藏。真实浅色/深色桌面截图五维复审仍记录为未完成证据缺口，不影响本次实现 Task 关闭。

TASK-033 已由项目所有者于 2026-08-20 明确关闭：OCR 页面使用独立 Provider 选择卡，并同时保留独立本机 Vision 与云端 GLM-OCR 卡；GLM 只配置一个 Keychain API Key。截图翻译在 GLM 结构识别期间显示专用等待态，成功后直接进入现有语义 Markdown 翻译与原生渲染。Vision 保持默认；缺少 GLM Key 时明确阻止并引导 OCR 设置，已配置云端请求失败时可见地自动降级到 Vision。截图仍只在活动会话内存中存活，不分配产品版本，开发 App 继续使用 `0.0.0` 占位。真实 GLM Key 成功调用没有被伪写为已验证，现作为独立 `RV-005` 保留，不重新打开实现 Task。

TASK-032 已完成：Marla 现在处于 `Incubation / Unreleased`，没有活动产品版本或发布合同。日常功能继续通过项目所有者明确选择的 Task 演进，完成或合入功能不提升产品版本；只有未来明确启动发布准备时才选择实际 SemVer、创建新合同并更新发布元数据。旧 `0.1.0` 合同和 Release Record 已标为从未发布的撤回草案，其未勾选项不再阻塞孵化。Debug/Release 开发 App 使用不可公开发布的 `0.0.0` 技术占位，固定 `artifacts/Marla_dev.app` 已重建并验证 Bundle ID、macOS 14、arm64、Paper Lantern 资源、稳定签名与 designated requirement 不变。Rust crate、C ABI、请求 schema、存储和迁移版本继续作为独立兼容标识。

TASK-031 已完成：状态栏 `MenuBarExtra(.window)` 现在由原生窗口独占系统材质，不再与内容级 `marlaGlassSurface()` 叠加；透明设置窗口和自定义 Panel 继续各自只使用一层内容材质。独立 Preview / fixture 显式保留单层表面，菜单布局与 Paper Lantern 身份层级不变。沙箱外 `./scripts/check.sh`、固定签名 Release 打包和浅色/深色五维复核均通过，未恢复 TASK-026 已否定的整窗 opacity、强制 clear 或透明度档位。Computer Use 无法枚举无主窗口的 LSUIElement 状态项，因此未把 fixture 冒充原生截图；项目所有者在固定 App 交付后明确授权合并到 `main`，Task 随之验收关闭。

TASK-030 已完成并关闭 RV-003。固定签名 Release App 的 30 组独立本地样本中，入口到 UI 壳层可见 P50/P95/max 为 131.869/145.947/149.332ms，Rust callback 到 Swift 可见 delta 为 35.068/43.957/44.074ms；delta 使用 `127.0.0.1` SSE，不混入 Provider 网络时间。空闲、常规完成态、真实 ScreenCaptureKit 全显示器冻结/框选、沙盒外 2400×1600 Vision accurate OCR 的最大 RSS 分别约 126.1/128.9/325.3/147.3 MiB，均在预算内。报告只含 metric 和纳秒时长。项目所有者随后于 2026-08-18 明确确认 RV-002、RV-004、TASK-013 与 TASK-016 全部通过；RV-001 至 RV-004 现均为 Complete，过去的两个 Blocked Task 均为 Done。闭环记录不包含显示器型号、凭据、认证方式或用户内容。

TASK-029 已完成：literal HTML table 由严格 table-only parser 转成 GFM；source-owned rich Markdown 使用 Marla 自己的 GFM projection 做 rich/plain 校验；protected Copy 只在同一 Pasteboard `changeCount` 下连续两次候选一致后接受。Flux `public.html` 中无 charset 的 UTF-8 raw NBSP 现按原生字符串优先解析，非 UTF-8 保留原有 fallback，严格可见文本校验未放宽。最终真实 Flux 审计已从 0 个表格变为 1 个并保持焦点和剪贴板恢复，项目所有者确认修复有效；实现提交为 `895a1de`。

TASK-028 已完成。此前合并的结构化翻译合同、受保护 Copy-only 划词、Quick Input 富 Paste、完成态原生 Markdown、GFM 表格/粗体、Markdown/纯文本复制、Paper Lantern 菜单身份位，以及混合表格布局崩溃和滚动抽搐修复保持有效；2026-08-17 重开范围进一步完成了实时原生 Markdown 投影、基于真实 TextKit 文档的流式与最终窗口高度校正、展开原文 Markdown、代码块与行内代码样式，以及菜单/结果卡身份层级微调。最终菜单标题组采用 14pt 向上光学校正，使标题字形约 24pt 的上边距为 16pt 左边距的 1.5 倍。自动化、固定 Release App、稳定签名、真实截图五维复审和项目所有者验收均已通过；截图结构 OCR 与同次 HTML/RTF 多 representation 输出复制仍不在本 Task 范围内。

TASK-027 已完成：Paper Lantern 是 Marla 的正式品牌标志和产品意象；品牌 SVG、参考 PNG、产品/UX 约束与 ADR 已落地。macOS 标准 10 槽位 AppIcon asset catalog 已接入 Xcode Debug/Release，所有后续 App 构建默认使用该图标；固定签名 `artifacts/Marla_dev.app` 已重建，并通过图标声明、`AppIcon.icns`、`Assets.car` 和 10 个 Paper Lantern rendition 验证。

TASK-026 已完成设置连接测试与真实翻译凭据语义一致性修复：编辑器现在以“保存并测试”保存当前 profile 与非空 Key 草稿后，从同一份已保存 endpoint 发起测试；真实请求在 profile 缺少已保存凭据时显示不泄露 Key 的 profile-specific 引导。项目所有者随后追加的标准 `⌘,` 设置命令已通过真实固定 App 验证，重复触发复用同一设置窗口。手动降低玻璃层 opacity 的实验因焦点/失焦时过透已回退，当前恢复原有系统默认玻璃，不保留自定义玻璃档位。用户自行输入现有 Key 的真实网络复验已由 `RV-004` 于 2026-08-18 完成，不重新打开实现 Task。

TASK-025 已立项：按职责把 `MarlaApplicationModel.swift` 拆分到分层目录，新增 `scripts/check-structure.sh` 结构门禁并接入 `check.sh`，新建 ADR-0007 并更新 `AGENTS.md` 与 `TASK_TEMPLATE.md`，防止单文件巨型化复发。

TASK-025 已完成源码职责拆分、Xcode 工程引用同步、结构门禁与固定 Release App 验证：`MarlaApplicationModel.swift` 已降至约 771 行，所有 Swift 源文件均低于 800 行，Models 目录无 UI framework import。`./scripts/check.sh` 全绿，固定 `artifacts/Marla_dev.app` 通过 Bundle ID、版本、arm64、稳定签名和 designated requirement 验证。

TASK-024 已完成第一阶段结构改造并合并到 `main`：新增 `MarlaApplicationServices` 集中构造应用级 Settings、Session、Floating Panel、Screenshot、Vision、Shortcut 与 Settings Window 服务；`MarlaApplicationModel` 保留兼容访问器和入口行为，不改变产品流程或 Swift/Rust 合同。授权环境下 `./scripts/check.sh` 已通过 20 项 Rust、97 项 Swift（3 项 Vision 图形服务限制 skip）、Swift Package、Xcode Debug、脚本语法、空白与 diff 检查；`artifacts/Marla_dev.app` 已通过固定 Release 打包、稳定签名和 designated requirement 验证。后续仍可按职责继续拆分同一大文件。

Blocked tasks: None.

## Current objective

当前没有 Active implementation Task。下一项产品实现、修复或验证工作仍必须由项目所有者从直接请求、Ideas、Backlog 或证据缺口中明确选择，Agent 不自动从旧 `0.1.0` 草案或 Roadmap 提升工作。

TASK-023 已完成整体代码审查、自动化验证与固定 Release 测试 App 交付：Rust 翻译与模型列表取消从 10ms 轮询改为事件驱动唤醒，SSE 单个未完成帧增加 1 MiB 内存上限，严格 Clippy 与 shell 语法检查纳入统一验证，5 个公开 unsafe FFI 函数补齐安全合同；`artifacts/Marla_dev.app` 已重建并通过稳定签名验证。

TASK-022 已完成实现并收束：Français、Español、Deutsch、한국어 已接入既有语言路由、UI 菜单和 Swift/Rust 请求合同；Vision 已改为自动语言检测并按运行时能力过滤七门产品 OCR 候选。真实固定开发 App 的日语/韩语截图路由仍是独立证据缺口；其余 Qwen-MT 语言暂不视为已适配。未来发布准备可按届时范围决定是否要求复验。

TASK-021 已完成：结果卡支持 380–760pt 横向调整，流式译文在未达到 60% 高度上限前完整推动窗口增长，动画竞态会在完成后按最新会话和宽度校正，且非激活划词路径的光标与拖动已完成实机复验。TASK-013 与 TASK-016 也已在 2026-08-18 获得项目所有者最终确认并关闭。

## Current implemented baseline

- Native SwiftUI/AppKit menu-bar application with selection translation, screenshot translation, and quick input.
- Nearby result card with streaming, comparison, copy, retry, system speech, pinning, cancellation, target switching, and actionable error states.
- Result cards start at a compact 380pt width and content-driven height, resize horizontally up to 760pt or the visible-workspace limit, reflow height with streamed wrapping while keeping their anchored edge stable, and cap at 60% of the visible workspace before scrolling translation content internally. TASK-034 adds persistent narrow/medium/wide presets (380/520/680pt) through a compact hover control in the result-card action row.
- Production selection content comes only from one protected simulated-Copy transaction bound to the trigger-time frontmost application. It snapshots every readable Pasteboard representation, accepts only the new Copy result, restores and verifies the original snapshot on every controlled exit, refuses to overwrite a newer external write, rejects focus changes, and reports only redacted lifecycle evidence.
- Accessibility remains the permission and optional non-content positioning substrate. Its standard range, Web Text Marker, bounded graph, identity, and geometry helpers are not allowed to provide or fall back to translation content.
- Selection translation always uses the complete nearby result card; the rejected single-line source-covering and pointer-estimate prototype has been removed together with its setting and runtime path.
- Pre-selection full-display ScreenCaptureKit freezing with Marla-window exclusion and same-frame cross-display selection/loupe/crop composition. Vision remains default, local and plain-text; selected GLM-OCR uses one Keychain Key, memory-only bounded encoding, a fixed cloud contract, visible waiting/fallback state and canonical semantic Markdown.
- Embedded Rust static library with C ABI v4, translation request schema v3, OCR request schema v1, shared async runtime, generic OpenAI-compatible SSE, Qwen-MT and GLM-OCR adapters, timeouts, cancellation, structure normalization and stale-event isolation.
- Grouped Settings, Carbon shortcuts, Keychain credential storage, permission guidance, light/dark appearance, Reduce Motion, and verified test-app packaging.
- Xcode SwiftUI previews for the main menu, Settings, translation-card states, and quick input, with preview-safe fixtures that avoid system integrations.
- Menu setup status that automatically yields to three bounded in-memory recent translations once API, Accessibility, and Screen Recording are ready; selecting a recent result performs no network request and quitting clears the list.
- Single-layer macOS 26 Liquid Glass with a macOS 14–25 system-material fallback across the menu, Settings, result card, quick input, and screenshot-selection labels; screenshot entry icons use the available `viewfinder` symbol.
- Fixed-path Release development packaging that stages, stable-signs, and verifies a new `artifacts/Marla_dev.app` before replacing the previous App; missing stable identities fail instead of falling back to ad-hoc signing.
- Multiple named OpenAI-compatible API profiles with one versioned Keychain vault, legacy single-endpoint/per-profile migration, shared in-memory credentials, default selection, settings CRUD/reordering, and explicit result-card switching are implemented under TASK-005/TASK-016.
- Every API profile supports explicit Base URL or Complete URL semantics. The editor uses an inline Base/Complete switch and can fetch a Rust-owned `/models` list with the current profile credential, then expand and select a model at the bottom of the form.
- The API editor gives its first scroll-content row an 8pt focus-ring safety inset, keeping the native macOS Focus Ring complete in light and dark appearance.
- Settings use a five-page native sidebar including Translation Languages, plus a summary-only API list and independently clipped editor sheet; global shortcuts have persistent switches, result cards support background dragging, and screenshot selection includes an in-memory 6× pointer magnifier.
- Global native/secondary preferences support Simplified Chinese, English, Japanese, French, Spanish, German, and Korean under TASK-022. New sessions locally detect source language, route native to secondary and other/unknown source to native, expose source/target overrides in the result card and quick input, and send consistent explicit target semantics through generic and Qwen-MT providers; expanded-language fixed development-App UI evidence remains incomplete.
- Settings use a transparent full-size title bar with traffic lights inside one continuous four-corner surface, hidden scroll indicators, and a fixed `Esc` screenshot-cancellation row. Screenshot selection temporarily suspends an open Settings window and restores it without activating it; `Esc` cancellation is owned by the active selection session rather than a single view's first-responder state, with window key-equivalent/cancel-operation routing and a listen-only event-tap fallback.
- Translation API profiles have persistent enabled states and only enabled profiles can be selected or invoked. The summary list uses native switches, a Set Default/Delete menu, accessibility move actions, and a trailing reorder handle. Settings content no longer moves the window; the newest fixed App uses a complete-row drag preview and 220ms animated hover reordering, which the project owner accepted on 2026-08-18.
- Project-scoped Serena 1.6.1 provides read-only Swift/Rust semantic navigation through Codex. A custom Context and fixed tool allowlist expose only nine retrieval/diagnostic tools; source edits, shell, project switching, onboarding, memories, Dashboard, and Headroom remain disabled.
- Paper Lantern is the selected Marla brand mark and product metaphor: “a little light beside the reader.” The canonical SVG and reference PNG exports live under `Resources/Brand/PaperLantern/`; the 10-slot macOS AppIcon catalog is compiled into Debug and Release builds. The menu-bar identity item uses a separate 18pt monochrome Paper Lantern template; the MenuBarExtra panel header uses a 33.6pt full-color rendition while its text group has a 14pt upward optical correction that makes the approximately 24pt top inset 1.5 times the 16pt leading inset; selection/screenshot result-card headers use a 24pt full-color identity mark and 17pt title. Quick Input and all functional controls continue to use SF Symbols.
- Quick Input preserves complete semantic Markdown through the Provider and session. Awaiting remains raw; from the first non-empty streaming delta, Markdown uses the same native heading/list/quote/code/link/table projection and TextKit height semantics as completion. Copy and request-changing actions retain the canonical string, while plain-text sessions and failed partial output remain unrendered. The reopened TASK-028 slice and its latest UI refinement are fixed-App verified and project-owner accepted.

Latest integrated implementation baseline: TASK-037 native UI/UX motion refinement on the unversioned incubation baseline; exact implementation and merge identifiers are recorded by Git history.

## Development evidence gaps

- TASK-035 已验证 Fn/Globe 的 AppKit flag、Carbon mask、显示、校验和回滚路径；实体 Fn + 主键能否从其它应用触发仍依赖具体键盘固件与 macOS Globe 键设置，因此不声明为通用现场通过。
- Real Japanese, Korean, Chinese, and English screenshot OCR plus source-language routing do not yet have final fixed development-App verification after the TASK-022 Vision repair.
- `docs/versions/0.1.0/ACCEPTANCE.md` 已随未发布草案撤回；其中未勾选项保留历史语境，但不是当前孵化期阻塞。
- TASK-033 的 mock Provider、固定 Release UI 与错误/回退路径已经验证；真实 GLM-OCR 成功调用作为 `RV-005` 保留，需项目所有者在 SecureField 中自行输入 Key 后完成，Agent 不读取、输入、输出或记录该凭据。

## Next selectable work

The next implementation or verification Task must be selected explicitly by the project owner from a direct request, Ideas, Backlog, or a current evidence gap. The Agent does not auto-promote any item, and the withdrawn `0.1.0` checklist does not determine the queue.

当前验证队列只有 `RV-005`。RV-001～004 已关闭并只作为 `VERIFICATION.md` 中的基线证据保留，不是可选工作。

## Current risks

- TASK-015's historical AX-first/optional-Copy route has been superseded by TASK-028's Copy-only production route. FluxMarkdown and protected Pasteboard behavior have owner/automated acceptance; additional Zen/GitHub breadth may be selected as future evidence rather than an Active implementation gap.
- Community evidence and project-owner testing identify simulated `⌘C` with Pasteboard backup/restore as the reliable cross-application content path. Copy menu、浏览器扩展和 PopClip/macOS Service bridge 当前均无计划；只有出现可复现的工作流缺口时，才回到 IDEA-008 评估其中一种入口。
- Screenshot coordinate conversion has unit coverage and RV-002 now supplies the project-owner real-region comparison; no display model or geometry parameters were recorded.
- The fixed-path development App is locally signed, not Developer ID signed or notarized; it is not a public distribution artifact.
- Real DashScope Qwen-MT translation succeeded, but representative TTFT, throughput, and live error mapping remain unmeasured.
- TASK-022 的 Swift/Rust 语言合同与 Vision 修复已实现：七门语言的归一/路由、设置持久化、通用提示词、Qwen-MT 映射、未适配代码拒绝和 Vision 配置均有回归测试。最新固定开发 App 已重建并签名通过；当前 xctest 图形服务无法创建 Vision CVPixelBuffer（OSStatus -6662），沙盒外探针已证明自动检测下日/韩/中/英样本有结果；现场固定 App 截图 OCR、长标签和完整窗口验收保留为独立证据缺口，不阻止其它孵化 Task。

## Latest verification

- TASK-037（已关闭，实现提交 `7aa921c`）：`Screenshot` 19/19、`WidthPreset` 7/7 与完成态正文动画回归 1/1 通过。最终 `./scripts/check.sh` 通过 24 项 Rust、180 项 Swift、Swift Package、Xcode Debug、结构、脚本、空白与 diff 门禁，`FloatingPanel.swift` 为 795 行。`./scripts/build-test-app.sh` 验证固定 App 为 `com.marla.app`、`0.0.0`、macOS 14.0、arm64，Paper Lantern 资源、稳定签名 `API Usage Monitor Dev` 与 designated requirement 有效。固定 App 的浅色、深色、Reduce Motion 和前景整屏透明材质证据五维复审为 8/8/9/9/8；用户逐帧截图未加入仓库。项目所有者于 2026-09-01 明确要求关闭、提交并合并，完成连续动效现场验收。

- TASK-035（已关闭）：最终 `./scripts/check.sh` 通过 24 项 Rust、全部 Swift、Swift Package、Xcode Debug、结构、格式、脚本、空白与 diff 门禁；`./scripts/build-test-app.sh` 重建并验证固定 Release `artifacts/Marla_dev.app` 为 `com.marla.app`、`0.0.0`、macOS 14.0、arm64 和稳定签名。真实固定 App 验证单窗口行内编辑、三行互斥、取消/提交/恢复默认、错误 AX 语义、0 秒原因提示和焦点恢复；折叠、D 展开与 Space 展开均为 820×592。浅色、深色和 Reduce Motion 五维复审均为 8/8/9/9/8；正常模式保留 0.32 秒 matched-geometry 融合，Reduce Motion 使用 identity transition 且无短状态动画。实现提交为 `02484d8`。

- TASK-034（已关闭）：最近翻译菜单纯文本摘要、四种窗口位置、顶部坐标记忆、窄/中/宽宽度预设，以及 popover 子窗口点击不误隐藏均已实现。授权环境下 `./scripts/check.sh` 全绿：Rust 24 项、Swift 166 项（3 项 Vision 按既有宿主限制跳过）、Xcode Debug、结构/脚本/空白/diff 门禁通过；`./scripts/build-test-app.sh` 已重建并验证固定 Release `artifacts/Marla_dev.app`（`0.0.0`、arm64、稳定签名）。真实浅色/深色设置与四种位置截图五维复审仍是已记录的独立证据缺口。

- TASK-033：24 项 Rust 与 161 项 Swift 测试通过，其中 3 项 Vision 图片回归因宿主 OSStatus -6662 按既有规则 skip；新增 OCR/设置/Keychain/会话回归、C ABI v4、翻译 schema v3 与 OCR schema v1 均同步。受限沙箱首次运行因系统 Pasteboard/XPC 不可用使 3 个既有复制断言得到 nil；授权环境重跑全部通过，Swift Package、Xcode Debug、结构/格式/shell/空白/diff 门禁均通过。`./scripts/build-test-app.sh` 已重建并验证固定 `artifacts/Marla_dev.app`：`com.marla.app`、`0.0.0`、macOS 14.0、arm64、Paper Lantern 资源、稳定签名 `API Usage Monitor Dev` 和 designated requirement 均保持不变。真实 Release fixture 位于 `/private/tmp/marla-task033-settings-light.png`、`/private/tmp/marla-task033-settings-dark.png`、`/private/tmp/marla-task033-awaiting-light.png`、`/private/tmp/marla-task033-fallback-dark.png` 与 `/private/tmp/marla-task033-awaiting-reduce-motion.png`；三张独立设置卡在滚动容器中层级清楚，已显示区域与等待/可见降级/Reduce Motion 状态均无重叠或异常裁切，五维复审为 8/8/8/9/7。真实凭据成功路径仍待项目所有者现场验收。
- TASK-032：授权环境 `./scripts/check.sh` 全绿：20 项 Rust 与 157 项 Swift 通过，其中 3 项 Vision 图片回归因宿主 OSStatus -6662 按既有规则 skip；Swift Package、Xcode Debug、严格 Rust format/Clippy、结构、shell、空白和 diff 门禁均通过。受限沙箱的首次运行曾因 `com.apple.hiservices-xpcservice` 不可用导致 3 个 Pasteboard 复制断言失败，授权重跑全部通过。`./scripts/build-test-app.sh` 随后完成 Release 构建并安全替换固定 App；最终 `artifacts/Marla_dev.app` 为 `com.marla.app`、开发占位版本 `0.0.0`、macOS 14.0、arm64，Paper Lantern 资源完整，稳定签名 `API Usage Monitor Dev` 与 designated requirement 保持不变。
- 2026-08-18 项目所有者明确回报 `RV-002`、`RV-004`、`TASK-013` 与 `TASK-016` 全部通过。RV-002 关闭截图裁剪、冻结画面、取消路径、代表性显示器布局与 TCC 持久性；RV-004 关闭同一已保存 profile 的“保存并测试”与真实翻译一致性；TASK-013 关闭固定尺寸拖拽 Panel、精确手柄锚点、无缩放、移动空槽与松手恢复动态；TASK-016 关闭干净授权状态下启动 vault 授权和首次翻译不再逐 profile 打断。未记录显示器型号、Key、endpoint、密码、Touch ID、截图或翻译内容。
- TASK-030：`./scripts/measure-rv003.sh 30` 在固定签名 Release App 上完成 30 组入口与 30 组本地 delta 样本，两个 P95 分别为 145.947ms 与 43.957ms；60 行原始证据只含 schema、metric 和纳秒时长。空闲、常规、全显示器冻结/框选与沙盒外 Vision accurate OCR 最大 RSS 分别约 126.1/128.9/325.3/147.3 MiB。`./scripts/check.sh`、`./scripts/build-test-app.sh` 与 `git diff --check` 最终通过；固定 App 保持 Bundle ID、0.1.0、macOS 14+、arm64、Paper Lantern 资源、稳定签名与 designated requirement。
- TASK-029：literal HTML table 样本与安全降级矩阵、完整 GFM/task-list 与等价 plain projection、不完整 plain 拒绝、同一 `changeCount` 下渐进候选稳定观察、真实 Flux 行首 U+FFFC checkbox projection，以及无 charset UTF-8 raw NBSP HTML 均已进入回归。最终 `./scripts/check.sh` 全绿：20 项 Rust、144 项 Swift（3 项 Vision host 限制 skip）、Swift Package、Xcode Debug、结构门禁、格式、shell、空白与 diff 检查均通过。`./scripts/build-test-app.sh` 已重建并验证固定 `artifacts/Marla_dev.app` 的 Bundle ID `com.marla.app`、版本 0.1.0、macOS 14.0+、arm64、Paper Lantern 资源、稳定签名 `API Usage Monitor Dev` 与 designated requirement。最终真实 Flux 混合选区脱敏审计得到 `semanticMarkdownTableCount=1`（修复前为 0）、`clipboardPreserved=true`、`focusPreserved=true`，项目所有者确认“的确修好了”。
- TASK-028 于 2026-08-17 由项目所有者最终确认完成。重开范围此前完整 `./scripts/check.sh` 已通过 20 项 Rust 与 142 项 Swift，另有 3 项 Vision 宿主环境 skip；最终 14pt 菜单标题调整后的 `./scripts/build-test-app.sh` 再次通过 Release、arm64、Bundle、资源、稳定签名和 designated requirement 验证。本轮新增高频投影回归定向通过，证明 40ms 合并窗口内同 session 继续使用上一份原生投影而不闪回 raw。受限沙盒复跑时仅 3 项系统 Pasteboard 复制断言因 `com.apple.hiservices-xpcservice` 不可用失败，沙盒外重跑又在执行前被审批服务 `404`/`503` 阻断；这项当前环境限制不覆盖此前全绿与真实 App 证据。
- TASK-028 的代码样式 fixture 已在固定 Release App 覆盖 380pt 浅色、760pt 深色和 Reduce Motion：`/private/tmp/marla-task028-code-style-light-380.png`、`/private/tmp/marla-task028-code-style-dark-760.png`、`/private/tmp/marla-task028-code-style-dark-reduce.png`。多行 fenced code block 的 5pt 圆角连续且不裁切；inline code 背景低于正文行高、左右各扩 3pt，并在窄宽相邻两行中保留清楚间隔。五维复审为 8/8/9/9/7；`MarkdownResultTextTests` 26/26 通过，完整 `./scripts/check.sh` 通过 20 项 Rust、142 项 Swift（3 项 Vision 宿主环境跳过）、Swift Package、Xcode Debug、结构与差异检查，固定 Release 包和稳定签名验证通过。
- TASK-028 的最终菜单标题位置已在新构建的固定 Release App 中以 2x 浅色/深色截图复核：`/private/tmp/marla-task028-menu-top-one-half-light.png` 与 `/private/tmp/marla-task028-menu-top-one-half-dark.png` 中，“Marla” 字形顶部距面板约 46–48px、左侧约 32px，即约 23–24pt 上边距相对 16pt 左边距接近 1.5 倍；标题/副标题无裁切，右侧 33.6pt 灯笼和下方操作区没有移动。五维复审为 8/9/9/9/8。
- TASK-028 的展开原文已对可靠 `semanticMarkdown` 接入同一原生 Markdown/TextKit 投影，保留 110pt viewport 和单一原生纵向滚动所有者；`plainText`、Vision OCR 和解析失败保持纯文本。新增 3 项测试后 `MarkdownResultTextTests` 24/24 通过，完整 `./scripts/check.sh` 通过 20 项 Rust、140 项 Swift（3 项 Vision 宿主限制跳过）、Swift Package、Xcode Debug、结构和差异检查；380pt 浅色、760pt 深色与 Reduce Motion 固定 App 证据位于 `/private/tmp/marla-task028-source-md-light-380.png`、`/private/tmp/marla-task028-source-md-dark-760.png`、`/private/tmp/marla-task028-source-md-dark-reduce.png`，五维复审为 8/8/8/9/7。
- TASK-028 本轮菜单/结果卡 UI 微调的固定 Release 截图覆盖菜单浅色/深色、划词 380pt/760pt、截图结果、Quick Input 和 Reduce Motion。24pt 灯笼、17pt 划词/截图标题、下移 2pt 的 API profile 与不变的功能控件均无裁切或重叠；五维复审为 8/9/8/9/8。`./scripts/build-test-app.sh` 重新验证 `artifacts/Marla_dev.app` 的 Release Rust 路径、`com.marla.app`、0.1.0、macOS 14.0、arm64、稳定签名与 designated requirement。
- TASK-028 的 2026-08-16 基线完成于实现提交 `6b302e5`。最终合并前在沙盒外运行 `./scripts/check.sh` 全绿：严格 Rust formatting/Clippy、20 项 Rust、全部 Swift/Pasteboard 测试、Swift Package、Xcode Debug、结构门禁、shell 语法、空白与 diff 检查均通过；`./scripts/build-test-app.sh` 重建并验证固定稳定签名 Release App。
- TASK-028 的混合表格崩溃定位为 `MarkdownSelectableTextView.layout()` 中 intrinsic size 自失效造成的 AppKit/SwiftUI 布局递归；后续表格横跳和滚动条显隐抽搐由单一原生 `NSScrollView`、overlay 纵向 scroller、关闭水平弹性及等价文档输入快照修复。项目所有者确认真实混合选择不再崩溃、表格和纵向滚动“正常啦”，并在真实 Provider、FluxMarkdown、Quick Input、复制和完成态渲染复验后授权 Task 收束。浅色/深色固定 fixture 五维复审为 8/8/8/9/7。
- TASK-023：`./scripts/check.sh` 通过严格 Rust formatting/Clippy、20 项 Rust、84 项 MarlaApp（3 项 Vision 图形服务限制 skip）、13 项 MarlaCore、Swift Package、Xcode Debug、3 个 shell 脚本语法、空白与 diff 检查。新增回归证明事件驱动取消会即时唤醒并保持幂等，SSE 未完成帧在 1 MiB 边界后被拒绝。`./scripts/build-test-app.sh` 随后成功重建固定 Release；`artifacts/Marla_dev.app` 通过 Bundle ID `com.marla.app`、版本 0.1.0、macOS 14.0+、arm64、稳定签名 `API Usage Monitor Dev` 和 designated requirement 验证，已交付项目所有者现场查看。
- TASK-021 已完成：宽度、非激活光标/拖动、源应用焦点和多次结果替换均已验收；本轮针对未封顶高度少算，增加了按 SwiftUI 实际行高补足的 `ResultCardLayout` 测量、真实 `NSHostingView` 回归，以及每次高度动画结束后按最新会话/宽度执行一次无动画 frame reconciliation。40ms 非激活场景覆盖了首个 delta 与 160ms 入场动画重叠的竞态。`./scripts/check.sh` 通过 17 Rust、80 MarlaApp、13 MarlaCore、Swift Package、Xcode Debug、格式/空白/diff；固定 Release 与 `/private/tmp/marla-task-021-height-race-final.png` 均验证通过。
- TASK-022：`./scripts/check.sh` 通过 18 Rust、84 MarlaApp（3 项 Vision 图片回归因 OSStatus -6662 明确 skip）、13 MarlaCore、Swift Package、非沙盒 Xcode Debug、格式/空白/diff；`./scripts/build-test-app.sh` 重建并验证固定签名 `artifacts/Marla_dev.app`。沙盒外探针验证自动检测下日/韩/中/英样本；现场固定 App 截图 OCR 和窗口视觉验收仍待完成。实现已按项目所有者授权收束，实现提交为 `978294e`，收束记录为 `c212400`。
- TASK-020 is complete. `./scripts/check.sh` passes 17 Rust, 71 MarlaApp Swift, and 13 MarlaCore Swift tests plus Swift/Xcode Debug, formatting, whitespace, and diff checks; the fixed Release `artifacts/Marla_dev.app` passes Bundle ID/version/minimum-system/arm64/stable-signature/designated-requirement verification. Real Release captures in `/private/tmp` show 224pt compact, approximately 309pt intermediate growth, approximately 644pt capped growth, dark appearance, and Reduce Motion; five-dimension review scores 8/8/8/9/7. Screenshots remain ephemeral per project policy and were not added to the repository.
- TASK-019 is complete on `Anti2077/ideas-012-translation-languages` with uncommitted branch changes. After the project-owner removal decision, `./scripts/check.sh` passes 17 Rust and 81 Swift tests plus Swift/Xcode Debug, formatting, whitespace, and diff checks; six dedicated inline-experiment tests were removed with that feature. The stable-signed fixed Release passes Bundle ID/version/minimum-system/arm64/signature/designated-requirement verification. Language settings, result-card, and quick-input captures under `artifacts/ui-review/task-019/` retain scores 8/8/8/8/7; final General light/dark captures without the Experimental section are under `artifacts/ui-review/task-019-removal/` and score 8/8/8/9/7. A live Japanese request against the Keychain-backed profile was not run because a new acceptance process raised system authorization; mock-provider payload tests verify `ja` mapping without exposing credentials.
- TASK-018 is complete at implementation commit `27203b5`. It captures every active display before presenting selection windows, excludes Marla's own windows, redraws the background/undimmed selection/loupe from the same frozen frame set, and composites the final crop without a second live capture. Cross-display mixed-scale layout tests pass; `./scripts/check.sh` passes 17 Rust and 83 Swift tests plus Swift/Xcode Debug, and the stable-signed fixed Release passes packaging. Three 3420×2224 Release captures under `artifacts/ui-review/task-018/` cover light, dark, and Reduce Motion and score 8/8/8/7/7. The project owner accepted Task closure; downstream RV-002 and RV-003 were both completed on 2026-08-18.
- TASK-017's exact and pointer-estimate single-line surfaces were built and visually reviewed, but project-owner real use found both presentations unsatisfactory. TASK-019 now removes the prototype, its setting, runtime path, automation fixtures, and dedicated tests; the historical TASK-017 evidence remains available but no longer describes the current product baseline.
- TASK-016's first live authorization test invalidated the `kSecMatchLimitAll` behavior claim. The follow-up uses one vault and one `LAContext`, but its first two Release packages respectively crashed from nil `NSApp` during construction and remained alive without an openable menu surface after adding a custom App Delegate plus early `NSApplication.shared` access. The final lifecycle repair removes both construction-time AppKit paths and listens only for `NSApplication.didFinishLaunchingNotification`. `./scripts/check.sh` passes 17 Rust and 74 Swift tests plus the Xcode Debug build; the stable-signed fixed Release App is valid, idles in the normal AppKit event loop, creates no new crash report, and successfully captures its complete built-in menu acceptance surface. The project owner confirmed the clean live authorization path passed on 2026-08-18.
- Rust: 17 tests passed.
- Swift: 81 tests passed.
- Xcode Debug application build passed.
- TASK-014 installed `uv 0.12.2`, `serena-agent 1.6.1`, and rustup `rust-analyzer 1.96.0`; Serena health check passed and indexed 15 Swift files plus 1 Rust file while project/build caches remained ignored.
- TASK-014's real stdio MCP session exposed exactly nine read-only semantic tools, with no edit, shell, project-switching, memory, or onboarding tools. Swift symbol/reference queries covered `TranslationAPIProfile` and `RustTranslationClient/start`; Rust covered `marla_translation_start` and four semantic test references.
- A separate read-only `codex exec` process loaded the project `.codex/config.toml`, called Serena successfully, and returned `ACTIVE_PROJECT=Marla CONTEXT=codex-readonly-context ACTIVE_TOOLS=9`.
- A second independent read-only `codex exec` process actually called `serena.find_symbol` and located `TranslationAPIProfile` at `Sources/MarlaApp/MarlaApplicationModel.swift:81-138`; root `AGENTS.md` now preserves the semantic-first usage rule, navigation-only boundary, ignored paths, and `rg`/normal-read fallback.
- SwiftUI preview support compiled in the Swift Package and Xcode Debug build.
- Xcode Preview launched and loaded `__preview.dylib` while the fixed-path development app remained running; Debug allows the Preview host instance while Release remains single-instance.
- `Marla_test_202608060135.app` passed Bundle ID, version, deployment target, arm64, executable, and signature checks.
- Real-app visual scenarios passed the five-dimension SwiftUI review with every dimension at least 7/10.
- TASK-003 menu-recents, Settings, quick-input, comparison-card, and screenshot-selection captures passed the five-dimension rescore at 8/8/8/8/7; evidence is under `artifacts/ui-review/task-003/`.
- `Marla_test_202608061928.app` passed Bundle ID, version, deployment target, arm64, executable, and signature checks.
- TASK-005 settings and streaming-card screenshots passed the five-dimension SwiftUI review at 8/8/8/8/7; evidence is under `artifacts/ui-review/task-005/`.
- `artifacts/Marla_dev.app` was replaced by a no-argument Release build and passed Bundle ID, version, deployment target, arm64, executable, stable-signature, and designated-requirement checks; no timestamped App or staging residue was added.
- TASK-006 settings sidebar/API summary/editor/empty state, light/dark General, Shortcuts, and OCR screenshots passed the five-dimension SwiftUI review at 8/8/8/8/7; evidence is under `artifacts/ui-review/task-006/`.
- TASK-007 API editor, shortcut light/dark, result-card and screenshot-magnifier captures passed the five-dimension SwiftUI review at 8/8/8/8/7; evidence is under `artifacts/ui-review/task-007/`. Direct pointer-drag automation was unavailable for this LSUIElement app, so dragging is verified by AppKit panel configuration and automated regression coverage rather than a simulated mouse gesture.
- TASK-008 unified Settings light, Shortcuts dark, and screenshot-from-open-Settings captures passed the five-dimension SwiftUI review at 8/8/8/8/7; evidence is under `artifacts/ui-review/task-008/`.
- TASK-009 added session-scoped local/global Escape monitors plus idempotent cancellation coverage. After all old fixed-path instances were closed, Computer Use sent real `Escape` events to the sole Release `artifacts/Marla_dev.app`; both ordinary and open-Settings screenshot overlays disappeared without a result card. Evidence and the lock-interrupted final capture note are under `artifacts/ui-review/task-009/`.
- TASK-010 added per-profile Base/Complete URL routing, an inline URL-mode switch, Rust-owned `/models` discovery through C ABI v2, and bottom-of-form model selection. A real `gpt-5.6-luna` Complete URL stream returned “你好”, `finish_reason: stop`, and `[DONE]`; the related `/v1/models` endpoint returned 20 models including `gpt-5.6-luna`. Light/dark Release captures passed the five-dimension review at 8/8/8/8/7 under `artifacts/ui-review/task-010/`. The fixed App retained Bundle ID `com.marla.app`, arm64, Authority `API Usage Monitor Dev`, and its designated requirement.
- TASK-011 added an 8pt scroll-content safety inset above the first API editor field. Frontmost light/dark Release windows captured by verified Core Graphics Window ID show the native blue Focus Ring complete on all four sides; five-dimension scores are 8/8/9/8/7 under `artifacts/ui-review/task-011/`. The fixed App retained Bundle ID `com.marla.app`, arm64, Authority `API Usage Monitor Dev`, and its designated requirement.
- TASK-012 changed development tracking to one evolving Task per implementation conversation. Owner-added scope remains in the same Task with explicit scope-change, acceptance, and verification updates; `git diff --check` and stale-rule searches passed.
- The 2026-08-06 to 2026-08-07 multi-API/settings development conversation is retrospectively consolidated in canonical `TASK-005`; `TASK-006` through `TASK-011` remain linked detailed evidence slices rather than separate conversation boundaries.
- TASK-013's fixed `artifacts/Marla_dev.app` retains Bundle ID `com.marla.app`, arm64, Authority `API Usage Monitor Dev`, and the existing designated requirement. Static light/dark list and editor captures passed the five-dimension review under `artifacts/ui-review/task-013/`; the owner confirmed that dragging the handle no longer moves the Settings window. Computer Use completed and reversed a real cross-row handle drag, restoring the prior order. After the owner still observed system drag-image scaling, the visible preview moved to a fixed 580×76pt nonactivating Panel while the native drag item became transparent 1×1pt; the project owner accepted the Panel, exact handle anchor, moving empty slot, no-scaling behavior, and release restoration on 2026-08-18.
- A real DashScope `qwen-mt-turbo` request translated `Hello` to “你好”; the credential remained in Keychain.
- TASK-015 is complete. Standard/range/marker resolution, pointer/focused/window root ordering, trigger-time application binding, system focused-application roots, ungated AX child probes, CFArray child conversion, global AX graph deduplication, cyclic references, search budgets, Unicode offsets, window-level Escape routing, and the complete Copy transaction lifecycle all pass. The fixed `artifacts/Marla_dev.app` is stable-signature-verified. The project owner confirmed a formerly failing Codex selection plus clipboard restoration, confirmed WeChat reached the real translation request, then accepted the goal complete after observing a high success rate. The downstream Provider `unauthorized` is a missing local profile credential and is excluded from TASK-015. Cross-application verification is closed as RV-001; RV-002 and RV-003 were later completed on 2026-08-18.

## Pending product decisions

Default translation vendor, contextual translation controls, persistent history, public signing/notarization, and public distribution remain unselected future work. GLM-OCR controls are complete under TASK-033, with live-provider evidence retained as RV-005; Paper Lantern brand selection and AppIcon integration are complete under ADR-0008 and TASK-027.

## Required Reading

These files are universal for every task:

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/development/VERSIONING.md`
- `docs/architecture/ARCHITECTURE.md`

The active Task must list any additional UI, implementation, acceptance, feature, data-contract, source, test, and ADR files it actually requires.
