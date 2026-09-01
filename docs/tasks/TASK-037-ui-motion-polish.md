# TASK-037：统一并优化原生 UI/UX 过渡动效

Status: Done

Owner: Project owner + Agent

Created: 2026-08-30

Updated: 2026-09-01

Origin: direct request

Conversation: 2026-08-30 创建新分支并优化 UI/UX 过渡动画

## Initial request

项目所有者要求创建新的分支，优化 Marla 的 UI/UX 与所有过渡动画等体验细节。

## Outcome

Marla 现有原生界面获得一套克制、一致、可中断且符合 macOS 语义的动效节奏；关键状态转换不再突兀或相互冲突，Reduce Motion、键盘焦点和辅助技术路径保持完整，并由自动化、固定 Release App 与真实截图/交互证据共同验证。

## Why now

Marla 已完成菜单、设置、结果卡、Quick Input、截图框选和快捷键编辑器等主要表面，但它们是在多个 Task 中逐步形成的。当前需要在不改变产品边界与已认可视觉基线的前提下，统一检查这些表面的过渡、反馈、焦点、流式布局和无障碍降级，而不是继续增加孤立动画。

## In Scope

- 在新分支上盘点菜单、Settings、API 编辑器、结果卡、Quick Input、截图框选与现有 AppKit 窗口承载中的全部用户可见状态过渡。
- 识别并修复突兀切换、重复或装饰性动效、互相竞争的动画、不可中断状态、布局抖动、焦点时序问题和 Reduce Motion 缺口。
- 在不改变既有产品行为的前提下建立共享动效语义与实现入口，按距离、复杂度和上下文区分进入、退出、状态反馈与布局协调节奏。
- 保留 TASK-020/021 的流式增长、锚点稳定与最终无动画 frame reconciliation，保留 TASK-035 已认可的 Liquid Glass matched-geometry 快捷键编辑动效。
- 为新增或修改的过渡增加定向自动化回归；同步当前 Task、相关 UI/实现规格和 `STATUS.md`。
- 构建固定 Release App，验证浅色、深色、Reduce Motion、键盘焦点和代表性加载/流式/完成/错误/展开/收起状态；使用真实截图完成五维复审，每维至少 7/10。

## Out of Scope

- `website/`、TASK-036 首页原型及任何 Web/GSAP 动效。
- 新产品入口、新设置项、新 Provider、新持久化数据或其它功能扩展。
- 把 Warm Minimal / Restrained Native 基线改成新的整体视觉方向，或增加渐变、发光、装饰性品牌动画和第二强调色。
- 重写 macOS 系统拥有的窗口、菜单、sheet 或 Liquid Glass 行为；只有发现可复现的承载缺陷时才做最小 AppKit 修正。
- 改变网络流式协议、Rust/FFI 合同、OCR/翻译业务逻辑或已认可的窗口尺寸与位置合同。
- 把静态截图当成完整动效证据；需要时补充短时序或逐状态证据，但不持久化用户内容。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-30 | Project owner | 创建新分支并优化 UI/UX 所有过渡动画等 | 新建 TASK-037；要求全表面动效审计、实现、自动化、固定 App、Reduce Motion 与五维复审 | Active |
| 2026-08-31 | Project owner | 修复结果卡宽度预设切换时窄到宽的瞬时内容裁切，以及两个方向的窗口上下跳动 | 宽度动画期间 SwiftUI 排版宽度必须跟随 AppKit 实际 frame；不得并发启动第二条高度动画；两个方向保持顶边稳定，并增加真实内容高度变化回归 | Active |
| 2026-08-31 | Project owner | 独立试用 `main@387d314` 基线确认原宽度预设路径没有裁切或上下跳，要求查明差异并修复后重建 | 撤回 TASK-037 新增的异步宽度动画协调；恢复 `main` 已验证的 AppKit 原生宽度切换和既有高度重排分工，新增宽度阶段不提前改变高度的回归并交付固定 App 复验 | Active |
| 2026-08-31 | Project owner | 复验确认窄到宽的内容裁切已解决，但宽度变动过程中窗口顶部仍短暂跳动，完成后回到原位 | 宽度预设动画期间统一延迟所有高度 reconciliation；系统宽度动画结束后只作一次顶部锚定高度校正，并以 generation 拒绝快速反向切换的旧完成任务 | Active |
| 2026-08-31 | Project owner | 复验认为延迟到动画结束的一次性高度调整使问题更严重，指出高度缩短时整窗上移且结束后仍有一帧回跳 | 撤回双阶段延迟方案；按目标宽度预先计算最终高度，将宽度、高度、水平位置与固定顶边合成唯一目标 frame，只执行一次原生窗口动画，不再在宽度结束后修正 frame | Active |
| 2026-09-01 | Project owner | 逐帧截图显示译文流式结束切换完成态时，正文区域短暂上移侵入语言栏，随后下降到正确位置 | 完成态不得触发正文容器或 raw 文本几何动画；动画值收窄到局部失败提示，保留投影节流与 Panel 高度合同，并增加 streaming→completed 不触发正文动画的回归 | Active |
| 2026-09-01 | Project owner | 六张逐帧截图显示宽度预设切换首帧中，面板仍是旧窄宽度，但内容已按目标宽度重排并越出右边界 | 目标宽度只用于计算唯一最终 frame；SwiftUI 布局宽度必须逐帧跟随 AppKit 实际 frame，宽度过渡期间的 resize 回调不得启动第二条高度动画，并覆盖快速反向与状态清理 | Active |
| 2026-09-01 | Project owner | 关闭完成 TASK-037，提交并合并进 `main` | 将剩余固定 App 交互项视为项目所有者最终验收通过；关闭 Task，提交任务分支，并在 `main` 上完成集成验证 | Done |

## Current evidence

- `main` 当前与 `origin/main` 一致，最新集成基线为 TASK-035；本 Task 已创建分支 `Anti2077/task-037-ui-motion-polish`。
- 工作区在分支创建前已有未跟踪 `website/`，属于 TASK-036 范围，本 Task 保留且不写入。
- TASK-020/021 已验证结果卡 160ms 入场、流式高度增长、锚点稳定和动画结束后的无动画校正；错误修改可能重新引入窗口竞态。
- TASK-035 已验证 macOS 26 的 0.32 秒 Liquid Glass matched-geometry 快捷键融合转场；Reduce Motion 使用 identity transition 并关闭短状态动画。
- `MarlaMotion.swift` 现集中定义 100ms Reduce Motion 透明度、120ms 反馈、160ms 内容、180ms 布局、220ms 重排、320ms 快捷键融合与 900ms 等待呼吸语义；调用点仍按因果与距离选择，不把所有状态套进同一个动画。API 配置编辑器的 Keychain/错误、模型获取/列表、连接测试反馈，以及 OCR Provider/Key 保存反馈均使用局部 transition/content transition，并遵循 Reduce Motion。
- Settings 页面/条件字段、API 拖拽重排、Quick Input 编辑态/结果态、结果卡局部状态、截图确认和宽度预设均已接入明确且 value-scoped 的过渡；系统菜单与系统窗口承载保持系统拥有。
- 截图确认在有效框选后用 120ms 四角内收反馈再完成，确认期间冻结拖动和放大镜；Escape 仍可立即取消。Reduce Motion 下角点几何不变，只作短透明度反馈。
- 项目所有者已确认中间内容裁切解决；后续复验指出双阶段宽度/高度处理仍会让高度缩短时整窗上移，并在结束后回跳一帧。失败的延迟高度 reconciliation 方案已完整撤回。
- 当前宽度预设先用目标宽度计算最终内容高度，再把宽度、高度、水平位置与固定顶边合成唯一目标 frame，只调用一次 AppKit 原生窗口动画；没有 width completion 或结束后的 frame 修正。目标宽度不再提前写入 SwiftUI layout；`windowDidResize` 每帧把 AppKit 实际宽度同步给内容，并在预设过渡期间消费中间 resize，避免启动并发高度动画。Reduce Motion/live resize 对同一个最终 frame 立即应用。
- 项目所有者提供的六张逐帧截图中，`00.26.16` 明确显示旧窄面板内已经出现宽版单行排版，文字越出右边界，随后窗口才追上内容。根因是 `setWidthPreset` 在 `panel.setFrame` 开始前先执行 `layout.width = width`；当前实现删除该提前写入，并用可替换目标的 `ResultPanelWidthPresetTransition` 覆盖中间帧、目标帧、快速反向和关闭/重配清理。
- 项目所有者提供的五张逐帧截图显示窗口外框与标题区保持稳定，但完成事件后的正文曾短暂侵入语言栏。根因是正文容器把完整 `session.state` 作为动画值，而完成事件和最多延后 40ms 的 Markdown projection 更新不是同一时刻；当前实现把触发器收窄为“局部失败提示是否可见”，并移除 raw 文本的完成态动画，streaming→completed 不再创建正文几何动画 transaction。
- 截图和宽度预设定向测试、完整 `./scripts/check.sh` 与 `./scripts/build-test-app.sh` 均已通过；固定 App 脱敏截图已覆盖浅色、深色、Reduce Motion、Settings、快捷键、Quick Input、流式结果与原文展开。
- 玻璃表面轮廓按外观自适应：浅色模式使用低对比度中性黑色 0.8pt 描边，深色模式保留分隔色细描边；两种路径同时覆盖 macOS 26 `glassEffect` 与 macOS 14–25 `.regularMaterial` fallback。透明材质验证使用固定 App 前景的整屏截图，不能用单独窗口截图推断后景可读性。

## Motion audit

| Surface | Owner / trigger | Decision | Reduce Motion / interruption evidence |
| --- | --- | --- | --- |
| MenuBarExtra 与系统窗口 | macOS 系统窗口、菜单开合 | 保留系统行为，不叠加自定义入退场 | 不覆盖系统偏好；本 Task 无额外动画 |
| Settings 页面与侧栏 | `selectedPage` | 160ms 淡入与 4pt 内容位移，侧栏只作 120ms 选择反馈 | 100ms 透明度；新选择直接替换旧 transaction |
| Settings 条件字段 | 窗口位置设置 | 条件说明/固定 X 字段使用局部内容过渡 | 100ms 透明度；最终状态由设置值决定 |
| API Profile 拖拽 | drag begin/end/reorder | 开始 120ms、结束 160ms、重排 220ms；保留既有原生拖拽预览 | 重排无动画，开始/结束仅短透明度 |
| 快捷键编辑器 | 行展开、修饰键/主键/提交状态 | 保留 TASK-035 320ms Liquid Glass matched geometry；短反馈改用共享 token | identity 展开/收起，短状态不发生几何移动 |
| Quick Input | 编辑态与结果态替换 | 160ms 内容淡入/4pt 位移；明确 transaction 与 ZStack 所有权 | 100ms 透明度；session surface 是唯一终态来源 |
| 结果卡内容 | 状态、原文、部分失败、取消、pin/copy | 局部 transition/content transition；完成态不动画正文容器或 raw 文本几何；原文展开只在内容节点设动画，外层 transaction 禁止隐式布局动画；等待点使用 900ms 呼吸 | 100ms 透明度；流式 delta 和 streaming→completed 不移动正文；Reduce Motion 动态切换会停止呼吸 |
| 结果卡高度/宽度 | AppKit frame 协调 | 入场 160ms、高度 120ms；宽度预设预先计算目标高度，以固定顶边的唯一完整 frame 执行一次系统原生动画；内容宽度逐帧跟随 AppKit 实际 frame | Reduce Motion/live resize 立即设置同一个最终 frame；过渡 resize 不启动第二条高度动画，也没有结束后的修正 |
| 截图框选 | 有效 mouse-up 确认 | 120ms 四角内收；确认期间冻结拖动与放大镜，完成幂等 | 角点不移动，只降低透明度；Escape 可立即取消 |

## Proposed approach

1. 以实时源码和测试为准建立“触发 → 初态 → 过渡 → 终态 → 焦点/取消/Reduce Motion”清单，先区分系统拥有、AppKit frame 协调和 SwiftUI 状态动效。
2. 将可复用的时长、曲线和 Reduce Motion 策略放入匹配现有分层的新文件或现有设计 Token 所有者，避免业务 View 继续散落魔法数字。
3. 优先修复高影响问题：状态正确性依赖动画完成、快速切换无法取消、窗口/内容布局相互竞争、焦点被旧过渡抢回、等待/完成状态突变。
4. 每次只修改能由测试或真实 App 证据验证的动效，不为静态元素增加装饰性移动；保留系统原生菜单、窗口和 Liquid Glass 行为。
5. 定向测试通过后运行完整检查与固定 Release 打包，采集正常动效和 Reduce Motion 的代表性状态证据并完成五维复审。

## Acceptance criteria

- [x] 菜单、Settings/API 编辑器、结果卡、Quick Input、截图框选与快捷键编辑器的用户可见过渡均已形成源码级审计记录，并明确系统拥有、保留、修改或无动画的理由。
- [x] 同类状态使用统一但非“一刀切”的动效语义；进入、退出、短反馈和布局协调按因果、距离与复杂度选择节奏。
- [x] 所有修改后的状态转换可被新输入打断或替换，状态正确性不依赖动画结束回调；快速重复操作不会留下旧焦点、旧 frame 或错误可见状态。
- [x] TASK-020/021 的流式增长、60% 高度上限、锚点稳定和最终无动画校正保持通过；TASK-035 的认可动效与窗口 820×592 合同不回归。
- [x] Reduce Motion 下不存在位置弹簧、缩放、呼吸或 matched-geometry 位移动效；最终状态、错误、焦点和操作反馈仍清楚可用。
- [x] 键盘焦点、Escape、VoiceOver/NSAccessibility 名称与状态不因过渡丢失，Hover 不成为唯一信息路径。
- [x] 结果卡窄到宽和宽到窄切换时，不出现首帧内容越界、瞬时异常裁切、并发高度动画或结束后的单帧回跳；唯一目标 frame 在整个动画中保持顶边稳定，SwiftUI 内容宽度逐帧等于 AppKit 实际宽度。项目所有者于 2026-09-01 明确关闭 Task，作为最终固定 App 现场验收。
- [x] 译文从 streaming 切换为 completed 时，正文顶部保持在语言栏下方，不向上侵入标题/语言区，也不在 projection 更新后再次下落；自动化证明两态使用相同正文动画触发值，项目所有者于 2026-09-01 明确关闭 Task，作为最终固定 App 现场验收。
- [x] 项目所有者从固定 App 连续操作 Settings、Quick Input、结果卡和截图框选，确认浅色、深色、Reduce Motion 与加载/流式/完成/错误/展开/收起时无体感布局抖动或双重布局；2026-09-01 关闭指令完成该现场验收。
- [x] 相关定向测试与 `./scripts/check.sh` 通过，新增代码不触发 800 行/8 类型结构门禁。
- [x] `./scripts/build-test-app.sh` 通过，固定 `artifacts/Marla_dev.app` 的 Bundle、版本占位、架构、稳定签名和 designated requirement 保持有效。
- [x] 真实固定 App 截图/状态证据完成五维复审，Philosophy、Visual Hierarchy、Craft、Functionality、Originality 每维至少 7/10。
- [x] 相关规格、当前 Task 和 `STATUS.md` 与最终验证事实同步；本轮未改变产品或架构合同，因此无需修改其它规范或 ADR。

## Verification

### Automated

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter Screenshot
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter WidthPreset
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox --filter TranslationCompletionDoesNotTriggerBodyLayoutAnimation
./scripts/check.sh
./scripts/build-test-app.sh
```

- `Screenshot`：19 项通过，覆盖确认延迟、Reduce Motion 几何不变与确认期间 Escape 取消。
- `WidthPreset`：7 项通过，覆盖水平锚点/顶部稳定、重排后的目标宽高原子合成、完整目标尺寸的可见工作区钳制，以及中间/目标 resize 消费、快速反向覆盖旧目标、关闭/重配清理和重复选择当前宽度不残留过渡。
- `TranslationCompletionDoesNotTriggerBodyLayoutAnimation`：1 项通过，证明 streaming 与 completed 的正文动画触发值同为 false，只有部分失败提示为 true。
- `./scripts/check.sh`：通过；24 项 Rust、180 项 Swift 测试、Swift Package、Xcode Debug、结构、脚本、空白与 diff 门禁均通过。
- `FloatingPanel.swift` 为 795 行，未超过门禁；窗口尺寸与完整目标 frame 计算位于独立辅助文件。
- `./scripts/build-test-app.sh`：通过；固定 App 为 `com.marla.app`、`0.0.0`、macOS 14.0、arm64，Paper Lantern 资源、稳定签名 `API Usage Monitor Dev` 与 designated requirement 有效。

### Manual

- 已从固定 `artifacts/Marla_dev.app` 的项目内脱敏 scenario 采集 `/private/tmp/marla-task037-shortcuts-light.png`、`settings-dark.png`、`shortcuts-reduce.png`、`comparison-dark.png`、`quick-input-light.png` 与 `streaming-reduce.png`；临时证据未加入仓库。最近新增的 `settings-editor` fixture 直接启动时以 `SIGABRT` 退出且未生成截图，因此不把旧截图扩展解释为 API 编辑器/OCR 新状态的视觉证据。
- 透明材质的浅色/深色对比改用 `/usr/sbin/screencapture` 在 Marla 位于前景时采集整屏证据：`/private/tmp/marla-task037-settings-light-fullscreen-front.png` 与 `/private/tmp/marla-task037-settings-dark-fullscreen-front.png`。浅色背景下卡片、侧栏和外框轮廓均可辨认；单独窗口截图不包含后景，不能作为这项判断依据。
- 截图保持 Settings 820×592 合同，未见裁切、重叠、焦点遮挡或 Reduce Motion 几何异常。五维复审为 Philosophy 8、Visual Hierarchy 8、Craft 9、Functionality 9、Originality 8。
- Computer Use 曾因同 Bundle ID 历史副本、fixture `SIGABRT` 和锁屏而无法独立读取完整连续 UI，因此没有把静态截图冒充时序证据。项目所有者随后使用最终固定 App 完成实际体验，并于 2026-09-01 明确要求关闭、提交并合并 TASK-037，作为宽度快速反向、完成态正文稳定和其余连续动效的最终现场验收。用户逐帧截图只作为外部临时证据引用，未加入仓库。

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
- `docs/versions/0.1.0/UI_SPEC.md`（仅作为已撤回版本的历史视觉与动效证据，不作为当前发布合同）
- `docs/tasks/TASK-020-stream-growing-result-card.md`
- `docs/tasks/TASK-021-resizable-result-card-width.md`
- `docs/tasks/TASK-031-menu-glass-parity.md`
- `docs/tasks/TASK-034-history-plain-text-window-placement.md`
- `docs/tasks/TASK-035-composable-shortcut-editor.md`
- 实际审计命中的 `Sources/MarlaApp/` 与 `Tests/MarlaAppTests/` 文件；在 Current evidence 中补充精确列表。

## Parallel contributors (optional)

None. 当前范围需要先由主 Agent 统一建立跨表面的动效语义、源码清单与验收基线；本轮没有项目所有者要求并行 Agent 工作。

## Risks and rollback

- SwiftUI 隐式动画可能把无关属性一起纳入 transaction，造成窗口尺寸、文字选择或焦点抖动；修改必须限定到明确的 state value。
- AppKit frame 动画与 SwiftUI 布局动画可能竞争，尤其在流式 delta、宽度变化和入场重叠时；宽度预设预先计算完整目标 frame 并只提交一次，开始前提升既有高度 generation 以拒绝旧 completion。
- macOS 26 Liquid Glass 与 macOS 14–25 fallback 行为不同；不能用旧系统淡入缩放替代已认可的系统 matched geometry，也不能把 fixture 视为真实 MenuBarExtra 证据。
- Reduce Motion 测试实例可能让正常动画看似消失；所有视觉判断先确认启动环境与系统设置。
- 若某项优化引入可见回归，按表面回退对应改动，不回退用户已有 `website/` 内容或其它无关工作。

## Decisions needed

None. 初始实现沿用已认可的 Restrained Native · Warm Minimal 与 Paper Lantern 行为基线；若审计发现需要整体视觉重设计或改变产品行为，将暂停该部分并向项目所有者单独确认。

## Completion record

- Verified commit: 待本次实现提交后记录；当前分支 `Anti2077/task-037-ui-motion-polish`。
- Automated evidence: `Screenshot` 19/19、`WidthPreset` 7/7、完成态正文动画回归 1/1、`./scripts/check.sh` 与最终 `./scripts/build-test-app.sh` 通过；完整检查含 24 项 Rust 与 180 项 Swift 测试。
- Manual evidence: 固定 App 脱敏临时截图覆盖浅色、深色与 Reduce Motion；五维复审 8/8/9/9/8。项目所有者于 2026-09-01 明确要求关闭、提交并合并，完成连续动效现场验收。
- Documentation updated: 本 Task 与 `docs/development/STATUS.md`；产品/架构合同未改变，无需新增 ADR 或修改其它规范。
- Remaining work promoted to: None。
- Scope changes closed: Yes；所有实现、自动化、固定 App、视觉与项目所有者现场验收均已闭合。
- Parallel contributions integrated: None
