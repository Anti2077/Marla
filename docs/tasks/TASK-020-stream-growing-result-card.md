# TASK-020：随流式译文生长的结果卡

Status: Done

Implementation: Complete

Owner: Project owner + Agent

Created: 2026-08-10

Updated: 2026-08-10

Origin: direct project-owner request

Conversation: 2026-08-10 改进翻译窗口默认高度与流式增长

## Initial request

项目所有者要求改进翻译窗口：降低不必要留白带来的默认高度，并让窗口随着流式译文输出逐步向下生长；达到一个明确限制值后停止增高。

## Outcome

短译文和等待状态使用更紧凑的结果卡；流式译文增加时，卡片保持原锚点并按内容平滑增高，达到当前屏幕可见工作区的 60% 后固定外框高度，超出内容在译文区内部滚动。

## Why now

当前 `FloatingPanelCoordinator.showResult` 无论内容多少都用 300pt 高度打开结果卡，而 SwiftUI 译文区又独立限制在 150pt。真实截图显示短译文下方存在大块无意义留白；长译文也无法利用 UI 规范已经允许的屏幕高度上限。

## In Scope

- 将结果卡从固定 300pt 改为紧凑、内容驱动的默认高度。
- 流式译文每次增长时重新计算结果卡所需高度，并平滑扩大窗口。
- 保持首次计算的水平位置和靠近选区的一侧不跳动；增长只移动远离锚点的窗口边缘。
- 最大高度继续遵循当前屏幕可见工作区的 60%，达到上限后仅译文正文内部滚动。
- 展开/折叠原文对照、错误状态、固定状态和 Reduce Motion 与新布局兼容。
- 增加纯布局策略和面板增长回归测试，补充长流式 UI 自动化场景。
- 同步双语产品规格、UI 规格、实现说明、验收合同、Task 与 `STATUS.md`。
- 构建固定签名 Release App，采集真实浅色、深色和 Reduce Motion 的紧凑/增长/封顶截图，并执行五维 SwiftUI 设计审查。

## Out of Scope

- 改变结果卡宽度、语言菜单、字体、配色或操作按钮。
- 改变翻译请求、流式协议、重试、取消或 Provider 行为。
- 允许窗口超过当前屏幕可见工作区的 60%，或新增用户可配置高度。
- 改变快速输入编辑态的独立初始高度策略；提交后结果态复用本 Task 的结果卡行为。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-10 | Project owner | 降低默认高度，并让结果卡随流式译文增长到上限 | 新增内容测量、窗口增长、封顶滚动、真实截图与回归测试 | Pending |
| 2026-08-10 | Necessary support | 将“稳定几何”解释为锚点稳定而非外框固定，并以 UI 规范既有的工作区 60% 作为上限 | 同步 UX/双语规格；测试增长时锚定边保持不变 | Pending |

## Current evidence

- 当前工作树干净，位于 `main`，本地比 `origin/main` 领先 3 个既有提交；本 Task 不改写这些提交。
- `STATUS.md` 在本次请求前没有 Active Task，项目所有者的直接请求授权创建并激活 TASK-020。
- `showResult` 固定请求 `380×300pt`；`PanelPlacementCalculator` 只在首次显示时把请求高度限制到可见工作区 60%。
- `TranslationCardView` 整体允许无限最大高度，但译文 `ScrollView` 在折叠原文时固定最多 150pt、展开原文时最多 92pt；短译文不会反向缩小 AppKit 面板。
- 现有 UI 规范已经声明结果卡最大高度为当前屏幕可见工作区 60%、超出后正文内部滚动，并要求译文支持流式增长；UX 原则中“流式内容不反复改变周围几何”需要明确为保持锚点稳定。
- SwiftUI 设计方向已经锁定为 Restrained Native · Warm Minimal。本 Task 比较了固定紧凑高度、内容连续增长、分档增长三种呈现；内容连续增长最符合本次明确请求，也能保留现有流式游标作为唯一标志性细节。
- Serena 本会话未暴露可调用工具，因此按项目规则使用 `rg` 与定向文件读取检查 Swift 调用路径。
- `./scripts/check.sh` 通过 17 项 Rust、71 项 MarlaApp 与 13 项 MarlaCore Swift 测试，以及 Swift/Xcode Debug、格式、空白和 diff 检查；固定 Release App 通过 Bundle ID、版本、最低系统、arm64、稳定签名和 designated requirement 验证。
- 真实 Release 截图保留在临时目录：`/private/tmp/marla-task-020-streaming.png`（760×448px，224pt）、`/private/tmp/marla-task-020-growth-medium.png`（760×618px，中间增长）、`/private/tmp/marla-task-020-growth.png`（760×1288px，约 644pt 封顶）、`/private/tmp/marla-task-020-streaming-dark.png`（深色）和 `/private/tmp/marla-task-020-growth-reduce.png`（Reduce Motion）。按项目截图默认临时规则，没有把截图写入仓库。

## Proposed approach

在 Swift/AppKit 表现层新增可单元测试的结果卡布局策略：按 380pt 卡宽、系统 15pt 译文字体和实际换行测量译文高度，计算紧凑视口、对照区预留与屏幕上限。`TranslationCardView` 使用该视口高度，使短内容不制造空白、长内容在封顶后由现有 `ScrollView` 滚动。`FloatingPanelCoordinator` 订阅当前 `CardSession`，在 SwiftUI 完成本轮布局后读取 hosting view 的 fitting size，按同一上限调整 `NSPanel`；增长保持靠近锚点的边不动，Reduce Motion 下立即调整，其余情况使用克制的 ease-out。该修改不穿过 Rust/FFI 边界，不需要新 ADR。

## Acceptance criteria

- [x] 等待首字和单行短译文的结果卡明显低于原固定 300pt，且无大块底部空白。
- [x] 流式译文从短到长时，结果卡高度随可见内容单调增长，不重播首次出现动画。
- [x] 有可靠选区锚点时，卡片靠近选区的边在增长过程中保持稳定；指针降级时保持窗口中心稳定并限制在可见工作区。
- [x] 结果卡不超过当前屏幕可见工作区 60%，达到上限后译文区内部可滚动，标题、语言、错误和操作区保持可见。
- [x] 展开/折叠原文对照会重算可用译文高度但不重新翻译；固定状态不改变高度策略。
- [x] Reduce Motion 下不执行位置/尺寸动画，只立即采用新高度。
- [x] 布局策略、上下锚定、屏幕封顶和短/长文本有自动化回归测试。
- [x] `./scripts/check.sh`、固定签名 Release 打包和 `git diff --check` 通过。
- [x] 固定 Release App 的浅色、深色、Reduce Motion 紧凑/增长/封顶场景完成真实截图审查，五个维度均至少 7/10；五维评分为哲学一致性 8/10、视觉层级 8/10、工艺质量 8/10、功能性 9/10、原创性 7/10。
- [x] 双语规格、实现、验收、Task 与 `STATUS.md` 同步。

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

用固定签名 `artifacts/Marla_dev.app` 分别展示等待首字、单行流式译文、中等长度流式译文和超过上限的长译文；在选区上方与下方各确认一次靠近选区的边保持不动。检查长译文内部滚动、展开原文、浅色、深色和 Reduce Motion。截图按项目规则仅保存在 `/private/tmp` 的本次会话临时证据中，不写入仓库。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/UI_SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `Sources/MarlaApp/MarlaApp.swift`
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Sources/MarlaApp/MarlaPreviews.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors (optional)

None. 面板尺寸、SwiftUI 内容高度与同一组布局常量紧密耦合；Task、STATUS 和双语规格由主 Agent 统一维护，拆分写入会增加行为与文档不一致风险。

## Risks and rollback

- SwiftUI fitting size 与 AppKit 窗口约束如果形成反馈循环，可能产生抖动；布局策略必须量化到像素并忽略微小重复变化。
- 向上/向下放置的卡片需要固定不同窗口边；错误处理会让卡片覆盖选区或漂移。
- 辅助功能字体或较小屏幕会压缩正文视口；始终优先保留标题、语言和操作区，正文滚动降级。
- 可通过恢复 `showResult` 的固定 300pt 和译文区固定 maxHeight 回滚；不触碰翻译、凭据或输入获取数据。

## Decisions needed

None. 高度上限沿用已接受 UI 规范的当前屏幕可见工作区 60%；若后续真实试用需要不同上限或可配置项，再作为新的范围变更记录。

## Completion record

- Verified commit: 当前工作区未提交；项目所有者未要求 commit/push
- Automated evidence: `./scripts/check.sh` 通过 17 Rust、71 MarlaApp Swift、13 MarlaCore Swift；固定 Release App 通过包验证；`git diff --check` 通过
- Manual evidence: `/private/tmp/marla-task-020-streaming.png`、`growth-medium.png`、`growth.png`、`streaming-dark.png` 和 `growth-reduce.png`；短卡 224pt、中间增长约 309pt、长卡封顶约 644pt；五维评分 8/8/8/9/7
- Documentation updated: `UX_PRINCIPLES.md`、0.1.0 `SPEC.md`/`UI_SPEC.md`/`IMPLEMENTATION.md`/`ACCEPTANCE.md`、Task-020 与 `STATUS.md`
- Remaining work promoted to: None
- Scope changes closed: Yes
- Parallel contributions integrated: None
