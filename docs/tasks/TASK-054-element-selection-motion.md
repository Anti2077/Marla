# TASK-054：截图元素层级选择与吸附动效

Status: Active

Owner: Project owner + Agent

Created: 2026-11-03

Updated: 2026-11-03

Origin: direct request

Conversation: 2026-11-03，研究 Snow Shot 后实现 Marla 普通截图的元素层级选择与吸附动画

## Execution context

- Worktree: `/private/tmp/marla-task-054-element-selection-motion`（本轮刻意选择的可丢弃工作树；永久范围和证据必须提交到 Git）
- Branch: `Anti2077/task-054-element-selection-motion`
- Base commit: `e59142ffdf77a184f57f2fa59e7f8d7a86db3f2c`
- Integration target: `main`
- Integration owner: primary worktree `/Users/anti/Documents/ChatGPT/Marla`
- Integration status: Unmerged
- Depends on: None for independent implementation; TASK-046's integrated selection behavior is the starting baseline.
- Expected merge order: Independent of TASK-053's license work and TASK-051's Markdown work; reconcile against current `main` before integration. No GPL code import depends on TASK-053 in this Task.
- Owned paths: this Task; `Sources/MarlaApp/Screenshot/ScreenshotSelection.swift`, `ScreenshotSelectionSupport.swift`, `ScreenshotCapture.swift`, new element-query/selection/transition files under `Sources/MarlaApp/Screenshot/`; `Sources/MarlaApp/App/ScreenshotTranslation.swift` only for capture-result wiring or synthetic acceptance fixtures; `Sources/MarlaApp/MarlaMotion.swift` only for selection motion tokens; related tests and new test files under `Tests/MarlaAppTests/`; `Marla.xcodeproj/project.pbxproj` and `Package.swift` only for source/test registration; `docs/features/screenshot-translation.md`; `docs/development/VERIFICATION.md` only for TASK-054 acceptance evidence, with final current-state reconciliation by the integration owner.
- Known overlaps: TASK-053 owns license files, README variants, Rust/website license metadata and licensing documentation; none are owned here. TASK-051 edits Markdown display, with possible shared Xcode registration and existing test-file conflicts; preserve both Tasks' entries, prefer new test files, and reconcile after current-main ancestry is restored. `STATUS.md`, global indexes, Backlog and Roadmap remain integration-owner-only. Other worktrees and their local changes are untouched.

## Initial request

项目所有者发现 Snow Shot 的元素吸附和滚轮切换层级效果很好，要求研究其实现，并在 Marla 直接实现元素识别、层级选择与相同风格的流畅选框动画。当前对话先明确完整目标，再创建独立 Task 和工作树。

## Outcome

普通截图翻译启动即进入元素吸附模式。用户悬停可选中应用暴露的元素，通过滚轮在元素、父容器和整窗口之间切换；选框立即响应并以短促、可中断的动画贴合目标。用户随时能切换或拖动为手动框选，确认后从同一次冻结截图裁切准确目标区域并继续现有 OCR/翻译流程。

## Why now

当前主线的 Space 模式只对 `SCShareableContent` 提供的整窗口矩形做命中，不包含 AX 元素层级、滚轮层级切换或独立的吸附框过渡。仅调整动画不能补足缺失的候选数据。本任务把识别、请求调度、选择状态、反馈和最终裁切作为一个完整行为实施。

## In Scope

- 普通截图默认元素吸附；无活动框选时 Space 在元素吸附和手动区域模式之间切换。不添加持久化模式偏好。
- 悬停查询目标应用暴露的 AX 角色、层级和几何，构建由细元素到父容器再到整窗口的候选路径；候选去重、边界裁切、所属进程/窗口校验、隐藏节点过滤、环检测和有界遍历。
- 排除 Marla 截图覆盖层，正确选择可见目标窗口；无可用元素、缺权限、超时或应用不支持时保留窗口候选。没有窗口时保留手动框选能力，不伪造元素。
- 鼠标滚轮/触控板按层级向外扩大、向内缩小，到边界停止；处理细小增量、滚动阶段及惯性，避免一次轻滑无控制地跳过多个层级。
- 相同候选路径保留层级；后台补查不得覆盖用户明确选定的框。鼠标按下锁定待确认目标，点击和拖动通过阈值区分；超过阈值进入手动框选。
- 保留拖动期间 Space 平移、释放后继续调整、Escape/右键取消、会话内 `1/2/3` OCR 临时切换和原位翻译隔离。
- AX 查询不阻塞主线程；合并连续鼠标请求、取消失效工作、拒绝旧会话/旧位置结果；先返回可用候选，再在停稳后有界补查。后台工作线程只在本线程创建/使用平台引用，不跨并发域传递 AX 对象。
- 兼容浏览器、原生应用与 Electron 辅助功能树的延迟就绪。若确有必要临时启用提供者的辅助功能暴露标志，仅限会话拥有的可恢复状态，并记录实现依据、清理和失败回归；不静默更改系统权限。
- 首次命中立即显示；后续位置和尺寸一起短过渡，从当前显示位置转向最新目标，不排队、不跳回旧起点、不明显回弹。以约 70–100ms 为初始调参范围，实机调整并记录最终值。
- 实际选择矩形与动画显示矩形分离；动画中途确认也使用准确选定边界，从同一会话冻结画面裁切，不能重新捕获实时窗口或使用中间动画框。
- 手动框选直接跟手；Reduce Motion 禁用吸附几何过渡，Reduce Transparency/Increase Contrast 和浅深色保留清楚的边界与提示。提示同步默认模式及滚轮说明。
- 复用原生 Swift/AppKit/SwiftUI 和现有多屏/屏幕缩放合同，新子系统进入独立源文件。同步规格、必要测试、性能与真实 App 验收证据。

## Out of Scope

- 原位翻译选择模式扩展、OCR 或翻译协议/模型/凭据修改、读取 AX 正文或 AX 文本翻译回退。
- 全局常驻鼠标监听、持续扫描其它应用、浏览器 DOM 注入、私有 API、图像分割模型、捆绑本地 VLM、新服务进程。
- 保存用户截图、元素正文、窗口标题或持久化元素树；公开或提交真实用户屏幕内容。合成 fixture 可用于脱敏验收。
- 引入 Snow Shot 源码、Rust selector 依赖或 Qt；本任务独立实现机制，不改变 ADR-0004 的平台对象归属。TASK-053 的许可决定不能自动扩大这里的导入范围。
- 全 App 动效改版、设置页新增动画档位、产品版本提升、发布、远端推送或其它工作树清理。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-11-03 | Project owner | 在识别/层级选择之外明确加入 Snow Shot 风格的流畅吸附动画 | 连续切换、反向中断、首次显示、动画中途确认及 Reduce Motion 均需验收 | Pending |
| 2026-11-03 | Project owner | 普通截图直接以吸附模式开始，替代此前讨论的默认手动区域模式 | 启动态、Space 切换、提示和回归测试使用新默认值 | Pending |
| 2026-11-03 | Project owner | TASK-053 已被另一对话占用且正在实施，指定本任务为 TASK-054 | 核对分支/工作树及路径归属，以本初始 Task 提交预留 054 | Recorded |

## Current evidence

- 任务创建前 primary `main` 在 `e59142f` 干净；`scripts/main-worktree.sh check --clean` 通过。本任务工作树从该提交创建。
- 已核对 `Anti2077/task-053-gpl3-license` 的 tracked Task：许可落地，明确不做元素吸附。054 没有占用其路径，也不修改其 Task。
- 本对话已通过 Serena 符号查询检查 `ScreenshotSelectionSession` 与 `ScreenshotWindowTargeting`：当前默认 `.region`，Space 切换 `.window`，命中为窗口数组中首个包含指针的矩形；没有 AX 元素候选路径或滚轮层级处理。
- 当前 `docs/features/screenshot-translation.md` 与 TASK-046 描述的窗口选择、Space 平移和临时 OCR 与代码相符；TASK-054 的新默认值和新选择合同尚未实现，需同次同步规格。
- Snow Shot 研究固定到 `01753292547704fd0f11c45317d2dd08cdbf03df`。代码中的 168ms/1.5s 查询预算、80ms 稳定门槛和 67/101ms 动画是参考参数，不是 Marla 已实现行为或性能证据。
- 截至初始任务记录，仅创建分支/工作树及 Task；没有运行或宣称通过功能验收。

## Proposed approach

Swift 平台层按窗口/显示器快照确定查询目标，在有界后台执行 AX 几何查询。查询协调器维护会话与目标代次，选择模型保存候选路径、用户选定层级、按下锁定和拖动转换。AppKit 保留截图窗口、鼠标/键盘输入、多屏坐标及冻结像素绘制；选框过渡独立保存目标与显示矩形，并按需调度绘制，空闲停止。SwiftUI 用于适合的提示和控件，不为动效重写整个截图层。

窗口查询与 AX 几何无法保证与冻结帧原子同步，因此必须校验缓存窗口身份/边界；发现明显移动、失效或所属窗口不符时丢弃子元素，降级到可验证的窗口/手动路径。不可将晚到的实时几何假称为冻结画面中的准确元素。

## Acceptance criteria

- [ ] 普通截图启动即有元素吸附，无需先按空格；无活动框选时 Space 可切回手动模式并再切回吸附。
- [ ] 原生 App、浏览器和 Codex/Electron 的代表性控件/容器可识别，路径由细到粗、去重且符合窗口与显示器边界；无法暴露的内容诚实降级。
- [ ] 滚轮/触控板逐层切换、方向正确、边界停止；重复路径和后台补查保留用户显式选择，按下后不被新结果改写。
- [ ] 单击确认与拖动转手动框选可靠；Space 平移/释放后调整、取消、OCR 临时选择及原位隔离通过回归。
- [ ] 快速移动、旧查询晚到、会话替换、超时、缺/撤销权限和关闭期间没有主线程等待、过期更新或资源泄漏。
- [ ] 首次命中立即显示，连续/反向切换可中断且不排队、不跳回；实际裁切始终使用准确目标而非动画框，冻结像素来自同一截图会话。
- [ ] Retina、混合缩放多屏、负坐标和屏幕边缘命中/裁切正确，目标窗口变化和覆盖层排除有测试。
- [ ] 缺 AX 权限时仍可窗口选择/手动框选，不在悬停中重复弹权限提示；任何临时提供者标志有受控释放和失败清理。
- [ ] 代表性查询记录耗时分布、取消/超时和节点预算；真实操作时序覆盖连续滚轮、快速反向和动画中途确认，不以静态截图代替动效证据。
- [ ] 浅色、深色、Reduce Motion、Reduce Transparency 和 Increase Contrast 真实 App 检查；真实 App 脱敏截图五维复审每维至少 7/10。
- [ ] `./scripts/check.sh`、稳定签名 Release 构建、源结构门禁和 `git diff --check` 通过；新增测试验证行为/失败边界而非复写实现。
- [ ] 功能规格与实现一致，Task 记录真实证据与未完成项；工作树提交干净并达到 `Ready for integration`。`Done` 仅在主线整合、主线验证和全局文档同步后记录。

## Verification

### Automated

创建阶段：检查 Task 结构、相对路径、编号/分支匹配、白空格及 primary 干净状态。只新增任务记录，不运行与该文档修改无关的完整构建。

实施阶段：新增候选层级、坐标转换、请求代次/取消、显式层级保留、点击/拖动转换、滚轮归一化、过渡中断和最终裁切几何测试；回归截图现有测试。

```sh
MARLA_BUILD_CACHE_ROOT=/private/tmp/marla-task-054-cache ./scripts/check.sh
./scripts/build-test-app.sh
git diff --check
```

### Manual

使用真实固定 Release App 覆盖 Finder/系统原生控件、Safari/Chrome 页面、Codex/Electron 内容与工具栏。连续滚轮、触控板、快速移入/移出、反向切换、按下后晚到结果、立即确认和拖动转手动均有现场验证。覆盖多屏/缩放可用配置；设备不具备的条件明确保留缺口，不用单屏结果代替。

动画和视觉证据优先使用合成窗口、脱敏 fixture 和内存查看；不持久化真实用户截图。记录首个可用结果、细化结果、时延分布和预算耗尽场景，未实测不承诺帧率或全应用识别率。

## Required Reading

- `AGENTS.md`；`docs/development/STATUS.md` 的 universal Required Reading。
- `docs/development/WORKFLOW.md`、`docs/tasks/TASK_TEMPLATE.md`、`docs/development/UI_UX_SKILLS.md`。
- `docs/features/screenshot-translation.md`；`docs/tasks/TASK-018-frozen-screenshot-selection.md`、`TASK-037-ui-motion-polish.md`、`TASK-046-screenshot-selection-efficiency.md`。
- `docs/architecture/decisions/ADR-0001-native-macos.md`、`ADR-0002-ocr-strategy.md`、`ADR-0004-swiftui-rust-core.md`、`ADR-0006-selection-copy-compatibility.md`、`ADR-0011-frozen-screenshot-in-place-translation.md`。
- `Sources/MarlaApp/Screenshot/ScreenshotSelection.swift`、`ScreenshotSelectionSupport.swift`、`ScreenshotCapture.swift`、`ScreenshotTranslationIntent.swift`。
- `Sources/MarlaApp/App/ScreenshotTranslation.swift`、`Sources/MarlaApp/Selection/AccessibilitySelectionReader.swift`、`Sources/MarlaApp/MarlaMotion.swift`。
- `Tests/MarlaAppTests/MarlaAppTests.swift` 中现有截图选择/冻结帧回归；`scripts/check-structure.sh`、`scripts/build-test-app.sh`。
- Installed `swiftui-design-skill`（含 `references/design-review.md`）、`axiom-macos` 的 AppKit interoperability 和 ScreenCaptureKit 参考；Serena 只用于语义导航。
- External reference, not vendored: [Snow Shot selector](https://github.com/mg-chao/snow-apps/tree/01753292547704fd0f11c45317d2dd08cdbf03df/snow-crates/crates/snow-ui-selector)、[coordinator](https://github.com/mg-chao/snow-apps/blob/01753292547704fd0f11c45317d2dd08cdbf03df/snow_shot/src/presentation/selector/screenshotselectorcoordinator.cpp)、[selection model](https://github.com/mg-chao/snow-apps/blob/01753292547704fd0f11c45317d2dd08cdbf03df/snow_shot/src/presentation/core/screenshotintelligentselectionmodel.cpp)、[transition](https://github.com/mg-chao/snow-apps/blob/01753292547704fd0f11c45317d2dd08cdbf03df/snow_shot/src/presentation/core/screenshotsmartselectiontransition.cpp)。

## Parallel contributors

None at creation. 任务创建是一份紧密耦合的文档，由本 Agent 单独维护；未委派实施或修改其它工作树。

## Integration notes

- 初始 Task 提交完成编号预留，不在 `main` 新增未集成功能声明。主工作树整合时更新 `STATUS.md`、必要索引和当前验收状态，不关闭其它 Task 的现场缺口。
- TASK-053 的许可落地独立推进；若其先合并，在本功能分支吸收 current `main`，保留许可结果，不借机导入外部代码。
- TASK-051 可能涉及 Xcode 工程、共享测试文件。合并前逐项保留其注册和测试，不能整文件选择一边。
- 实施工作树达到 `Ready for integration` 后，primary 使用 `./scripts/main-worktree.sh merge Anti2077/task-054-element-selection-motion`；合并后先运行 `check`，再同步目标分支文档和最终验证。
- 推送远端、发布和工作树清理未授权。创建记录不能被报告为功能完成或主线整合。

## Risks and rollback

AX 提供者可能超时、缺少层级或异步初始化；默认吸附增加启动即触发查询的频率，必须用预算、合并、取消与窗口降级控制成本。冻结画面与实时 AX 不原子，必须优先拒绝无法校验的子元素。动画与逻辑矩形分离可避免中间帧误截。回滚可恢复手动模式默认及旧窗口选择，冻结截图和后续 OCR/翻译保持现有路径。

## Decisions needed

None for the agreed scope. 普通截图默认吸附由项目所有者明确决定。若发现必须使用私有 API、改变平台对象归属或扩大内容访问，先报告具体事实并另行决定，不自行扩展本 Task。

## Completion record

- Worktree verified commit: Initial reservation only; implementation pending
- Integration commit: Not integrated
- Integration verification: Pending implementation
- Automated evidence: Task required sections, local referenced paths, unique ID/branch match, default-mode scope and whitespace checks passed; initial tracked diff whitespace verified before commit
- Manual evidence: Pending; source research is not real-App acceptance
- Documentation updated: This Task only at creation
- Mainline documentation updated by: Pending primary integration
- Remaining work promoted to: None
- Scope changes closed: Default-mode and Task-ID decisions recorded; implementation acceptance pending
- Parallel contributions integrated: None
- Remote push state: Not authorized; not performed
- Worktree cleanup state: Not authorized; retained
