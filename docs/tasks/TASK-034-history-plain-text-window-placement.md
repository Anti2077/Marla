# TASK-034：历史翻译纯文本摘要与翻译窗口出现位置

Status: Completed

Owner: Project owner + Agent

Created: 2026-08-22

Updated: 2026-08-22

Origin: direct request / defect

Conversation: 2026-08-22，历史翻译 Markdown 摘要、翻译窗口位置与宽度设置

## Initial request

项目所有者要求新建一个 Task 修复两个小问题：截图所示“最近翻译”中的 Markdown 不应以 Markdown 标记显示，直接使用纯文本；并在“通用”设置中增加翻译窗口出现位置选项，包括固定居中、跟随鼠标，以及固定横坐标且纵向居中。

## Outcome

最近翻译菜单中的来源和译文摘要均以纯文本显示，点击后仍恢复完整规范内容。用户可在通用设置中选择四种翻译窗口位置，设置会持久化并应用于结果卡和快速输入窗口；“记住上次位置”恢复面板左上角并在流式高度变化时保持顶部。结果卡底部动作栏提供“窄 / 中 / 宽”悬停宽度选择。

## Why now

TASK-028 已让语义 Markdown 成为会话的规范内容，但菜单摘要是紧凑的历史入口，不应暴露 Markdown 标记。现有面板定位逻辑集中且可测试，适合在不改变翻译合同的前提下提供用户可控的出现位置。

## In Scope

- 为最近翻译的来源和译文摘要提供纯文本投影，不修改 `RecentTranslation` 保存的规范内容或恢复后的结果卡渲染。
- 在通用设置中增加“翻译窗口位置”设置，选项为“固定居中”“跟随鼠标”“固定横坐标（垂直居中）”“记住上次位置”。
- 增加“记住上次位置”模式，保存用户实际移动后的面板左上角全局坐标，并在下次打开时按当前屏幕可见区域夹紧；流式高度变化固定顶部。
- 为固定横坐标提供可持久化的屏幕坐标输入，并对当前屏幕可见区域进行边界约束。
- 将位置设置应用到结果卡和快速输入面板，并保留面板尺寸、屏幕选择、动画、取消和固定窗口行为。
- 增加可持久化的“窄 / 中 / 宽”宽度预设，放置于结果卡底部动作栏的悬停弹出控件中，并复用现有拖拽宽度逻辑。
- 增加设置迁移/持久化、纯文本摘要和面板几何的自动化测试；同步 `STATUS.md`。

## Out of Scope

- 不改变会话规范 Markdown、复制 Markdown/纯文本行为或结果卡内的原生 Markdown 渲染。
- 不增加历史持久化、删除历史、跨设备同步或新的窗口锚点类型。
- 不改变产品版本、发布合同、Rust/C ABI 或翻译 Provider 合同。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-22 | Project owner | 历史翻译 Markdown 摘要改为纯文本 | 增加语义 Markdown 来源/译文摘要无标记回归，同时保留规范内容恢复 | Implemented; automated evidence passed |
| 2026-08-22 | Project owner | 通用设置增加四种翻译窗口出现位置与固定横坐标 | 增加偏好持久化、四种面板几何、屏幕边界和设置 UI 验收 | Implemented; automated evidence passed |
| 2026-08-22 | Project owner | 增加记住上次窗口位置 | 增加窗口移动持久化、跨屏回退和恢复位置验收 | Implemented; automated evidence passed |
| 2026-08-22 | Project owner | 记住窗口顶部而非左下角，并增加窄/中/宽宽度入口 | 增加顶部锚定的流式高度回归、宽度预设持久化与动作栏悬停布局验收 | Implemented; automated evidence passed |
| 2026-08-22 | Project owner | 宽度弹出选项点击后窗口消失 | 将 SwiftUI popover 的附属 AppKit 窗口视为翻译面板内部点击，增加外部点击隐藏回归 | Implemented; automated evidence passed |

## Current evidence

- `RecentTranslationsSection` 当前直接显示 `recent.translation` 和 `recent.sourceText`，因此语义 Markdown 的 `#`、列表标记和表格管线会暴露在菜单摘要中。
- `PanelPlacementCalculator` 当前按选区上/下方或指针中心定位，没有用户设置入口。
- `MarlaSettingsStore` 已集中管理 UserDefaults 偏好，`SettingsView` 已有通用设置页；结果卡允许原生拖动，`FloatingPanelCoordinator` 可通过 `windowDidMove` 观察最终坐标。

## Proposed approach

新增 `TranslationWindowPlacement` 与 `TranslationWindowWidthPreset` 小型值类型保存位置/宽度偏好；设置存储只写版本化 UserDefaults 键。面板计算器接收模式，居中使用可见工作区中心，跟随鼠标使用触发点，固定横坐标使用屏幕全局 X 并在可见工作区内夹紧，记住上次位置使用保存的面板左上角坐标并在显示器变化后回退到当前屏幕中心。流式重算在记忆模式使用顶部锚点。历史摘要优先使用现有 `MarkdownResultDocument.plainText`，解析失败时使用 Foundation 纯文本回退；宽度预设复用现有横向布局和夹紧逻辑。

## Acceptance criteria

- [x] 最近翻译来源和译文摘要不显示 Markdown 标记；完整规范 Markdown 仍可在结果卡中恢复和复制。
- [x] 通用设置显示四种位置选项；固定横坐标模式显示可编辑 X 坐标。
- [x] 位置设置重启后保持，旧安装无值时使用跟随鼠标默认值。
- [x] 四种位置在多屏可见工作区和面板尺寸变化时不越界。
- [x] 记住上次位置会保存窗口移动后的左上角坐标，流式高度变化保持顶部，跨屏或坐标失效时夹紧到当前可见工作区。
- [x] 结果卡动作栏可悬停打开“窄 / 中 / 宽”宽度选项；选择后持久化并保持窗口当前顶部/中心边缘，手动拖拽宽度仍可用。
- [x] 点击宽度 popover 的选项不会触发外部点击自动隐藏；置顶与非置顶状态行为一致。
- [x] 结果卡和快速输入均使用设置后的位置，现有取消/激活/尺寸行为不回归（几何和聚焦回归已通过）。
- [x] 新增聚焦自动化测试、Xcode Debug/Release 构建、结构门禁和 `git diff --check` 通过；授权环境统一 `check.sh` 全绿，受限沙箱的 3 个既有 Markdown 粘贴板断言因宿主 XPC 不可用而失败。
- [x] `STATUS.md` 已记录当前验证状态。
- [ ] 固定 App 的真实设置/菜单截图五维复审仍待桌面 UI 会话可见后完成；项目所有者明确要求在此处关闭 Task，作为独立证据缺口保留。

## Verification

### Automated

```sh
./scripts/check.sh
git diff --check
```

### Manual

在固定 Release 开发 App 的通用设置中分别选择四种位置，使用结果卡和快速输入触发翻译，检查浅色/深色下窗口位置、屏幕边界和历史摘要；记录真实截图路径，不记录用户内容或凭据。

## Required Reading

- `AGENTS.md`
- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/development/VERSIONING.md`
- `docs/development/STATUS.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/features/inline-translation.md`
- `Sources/MarlaApp/Sessions/TranslationSessionStore.swift`
- `Sources/MarlaApp/Panel/FloatingPanel.swift`
- `Sources/MarlaApp/Persistence/MarlaSettingsStore.swift`
- `Sources/MarlaApp/SettingsView.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors (optional)

None. 本次改动涉及共享设置、窗口几何和菜单摘要，主 Agent 保持单一写入所有权。

## Risks and rollback

- 固定坐标可能在不同显示器排列下落在屏幕外；计算器必须按当前可见工作区夹紧。
- 位置偏好若错误影响可见性，可删除偏好键恢复默认跟随鼠标；不影响会话内容。

## Decisions needed

None. “固定横坐标（垂直居中）”作为该模式的用户可见名称，固定坐标按 macOS 全局屏幕 X 坐标处理。

## Completion record

- Verified commit: Working tree not committed; project owner requested Task closure
- Automated evidence: 授权环境 Rust 24 项、Swift 166 项（3 项 Vision 按既有宿主限制跳过）、Xcode Debug、固定 Release 构建、App 验证、结构/脚本/空白/diff 门禁通过；新增 popover 内部点击回归通过；受限沙箱的 3 个既有 hiservices XPC 粘贴板断言失败不属于本 Task 回归
- Manual evidence: Real light/dark desktop screenshots and five-dimension visual review remain unavailable in the current desktop session and are recorded as a separate evidence gap
- Documentation updated: Task、STATUS、inline-translation、quick-input 已更新
- Remaining work promoted to: None
- Scope changes closed: Implementation and automated verification complete; manual UI evidence gap explicitly retained at Task closure
- Parallel contributions integrated: None
