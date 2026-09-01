# TASK-038：优化 API Profile 拖放重排连续性

Status: Active

Owner: Project owner + Agent

Created: 2026-09-02

Updated: 2026-09-02

Origin: direct request / defect

Conversation: 2026-09-02 从主工作树 main 创建新分支并修复 API Profile 拖放动效

## Initial request

项目所有者要求从主工作树的 `main` 分支创建新分支和新 Task，解决几个 UI 问题；当前明确问题是翻译 API 配置重排在拿起、挤压让位和放置三个阶段都很生硬，需要基于所附 7.75 秒真实录屏与逐帧截图改进。

## Outcome

API Profile 重排在不恢复系统缩放预览的前提下形成一条连续、可中断的交互：原行自然抬起为固定尺寸预览，列表用稳定空槽平滑让位，释放或取消时预览与目标行完成无闪断交接；Reduce Motion 保留清楚的最终状态而不产生位移弹簧。

## Why now

TASK-013 已解决系统 `NSDraggingSession` 把整行预览缩成缩略图的问题，TASK-037 又统一了 120/160/220ms 动效语义；但本次真实录屏显示 SwiftUI 源行与独立 AppKit Panel 之间仍没有连续交接，数组重排和空槽移动的视觉反馈也过于突兀。当前需要修复承载边界和重排状态，而不是只替换一条 easing 曲线。

## In Scope

- 保持 TASK-013 已认可的固定 580×76pt 完整行预览、真实手柄抓取锚点、透明 1×1pt 原生拖动项和不缩放合同。
- 改进拿起阶段：源行与独立预览 Panel 在同一位置连续交接，不出现源行先消失、预览后跳出的断帧。
- 改进让位阶段：以明确、等高、稳定的插入空槽驱动周围行移动，跨行边界时不瞬间挤压、跳位或产生重复重排抖动。
- 改进放置与取消阶段：预览在目标槽位完成交接后再退出，目标行不经过“预览消失—原行重现”的空白闪断；快速反向和拖出有效区域仍恢复确定状态。
- 保留配置顺序的持久化、默认/启用状态、点击编辑、菜单、键盘与 NSAccessibility 上移/下移动作。
- 为纯状态/几何/提交语义增加定向回归；运行完整检查、构建固定签名 Release App，并用真实连续操作和浅色/深色/Reduce Motion 证据完成五维 UI 复核。
- 同步本 Task、`STATUS.md` 及拖放相关 UI/实现规格。

## Out of Scope

- TASK-036 首页、`website/` 或任何 Web/GSAP 动效。
- 修改 API Profile 的字段、编辑器、Provider、凭据、默认选择或持久化格式。
- 恢复会被 macOS 系统缩放的完整原生 drag image，或改变 580×76pt 预览尺寸与手柄锚点。
- 重设计 Settings 页面视觉层级、列表内容、颜色、字体、窗口尺寸或 Liquid Glass 基线。
- 新增装饰性缩放、旋转、发光、品牌动画或声音反馈。
- 尚未由项目所有者明确描述的其它 UI 问题；若在本对话追加，进入 Scope changes 后再实施。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-09-02 | Project owner | 从主工作树 `main` 创建新分支和 Task，优化拖放拿起、挤压让位和放置动效 | 以真实录屏时序为缺陷证据；新增三阶段连续性、Reduce Motion、回归测试与固定 App 现场验收 | Implemented; owner acceptance pending |
| 2026-09-02 | Project owner | “挤压敏感一点，放置的时候快一点” | 插入阈值改为方向敏感的 40%/60%，向下与向上均比中点更早让位；Panel 落点移动收为 140ms，最终交接收为 120ms，并增加常量回归 | Implemented; owner acceptance pending |
| 2026-09-02 | Project owner | 指针拖出列表卡片后仍应继续触发挤压让位 | 将纵向重排追踪提升到 AppKit dragging session，按屏幕纵坐标持续驱动临时顺序；API 页面作为扩展 drop 区，补充越界追踪回归与真实拖放验收 | Implemented; owner acceptance pending |

## Current evidence

- 专用分支 `Anti2077/task-038-api-profile-reorder-motion` 已从本地 `main@506c4cf` 创建；主工作树当前另有 TASK-036 分支和未提交网页改动，本 Task 不触碰。
- 所附 H.264 录屏为 1864×1408、约 7.747 秒；两次相反方向重排都能复现同一时序断点，静态截图进一步覆盖预览出现、列表让位和释放后的帧。
- `APIProfileReorderState` 已分离初始顺序、临时视觉顺序和 dragging/settling phase；hover 只移动等高空槽，成功 drop 才通过 `setProfileOrder` 一次提交完整顺序，取消先恢复初始顺序。
- 方向阈值依据当前视觉索引选择向下 40% 或向上 60%，快速反向不会沿用旧方向；让位使用可替换的 220ms `smooth` transaction。
- `draggingSession(_:movedTo:)` 同时移动固定 Panel，并按屏幕 Y 映射到首末 slot，指针横向离开列表或纵向越过边界后仍持续驱动让位；API 页面级 delegate 扩展有效 drop 区。
- 拖拽源在原生 session 期间自保活；成功释放使用 140ms Panel 落点和 120ms Panel/真实行交接，显式可取消 Task 负责视觉清理，业务顺序不依赖动画 completion。
- 7 项定向测试覆盖显式 before/after、40%/60% 阈值、快速反向、列表越界纵向追踪、取消恢复、一次提交和落点几何；最终 `./scripts/check.sh` 通过 Rust 24 项、全量 Swift、SwiftPM、Xcode Debug、结构与 diff 门禁。
- 固定 `artifacts/Marla_dev.app` 已在最终拖拽源保活改动后重建，验证 `com.marla.app`、`0.0.0`、macOS 14、arm64、Paper Lantern 资源、稳定 `API Usage Monitor Dev` 签名和 designated requirement。
- 临时独立 bundle 的深色现场操作确认指针横向离开列表右侧后仍会挤压，`Esc` 取消恢复原顺序且移除 Panel。Computer Use 不能可靠产生 AppKit mouse-up，因此成功释放、最终 140ms/120ms 手感和 Reduce Motion 仍保留给项目所有者实鼠标验收。
- 深色真实静态与拖动序列的五维复核为理念一致性 8、视觉层级 8、工艺 8、功能性 8、原创性 7；完整预览、等高空槽和列表外框无可见变形。浅色与成功 mouse-up 证据仍缺，不据此关闭 Task。

## Implemented approach

1. 将 API Profile row/拖放实现从已包含多个设置组件的 `SettingsShared.swift` 拆到独立 Settings 层源文件，并同步 Xcode target，保持 ADR-0007 结构门禁。
2. 建立单一拖放会话状态：被拖 ID、当前插入位置、阶段（拿起/拖动/落下）和初始/预览顺序分离；hover 只更新临时视觉顺序，成功 drop 才把最终顺序提交到 `MarlaSettingsStore`，取消则恢复初始顺序。
3. 让源行、等高空槽和 Panel 共享明确的 phase：拿起交叉淡入/淡出；让位使用 value-scoped、可替换的布局动画；落下把 Panel 移到目标 slot 的屏幕 frame 并与源行交叉交接，完成回调只负责清理临时承载，不决定业务顺序。
4. Reduce Motion 关闭 spring/位移，让顺序和最终状态即时更新，仅保留短透明度交接；快速反向使用最新插入位置覆盖旧动画，不排队等待旧 completion。

## Acceptance criteria

- [ ] 拖动开始时完整行在原位置连续抬起为 580×76pt Panel；源行与 Panel 不出现先后空白帧、重复实心行、缩放或抓取点偏移。
- [ ] 拖过相邻行时存在一个稳定、等高的目标空槽；周围行平滑让位，不瞬间挤压、跳位、改变列表外框高度或在同一目标上重复触发动效。
- [ ] 快速上下反向拖动可立即采用最新目标，不积压旧动画，也不产生顺序来回抖动。
- [ ] 向下拖在目标行 40% 后触发 `.after`，向上拖在目标行 60% 前触发 `.before`；两个方向都比固定 50% 中点更敏感。
- [ ] 指针横向拖出列表卡片、或纵向越过首尾行但仍在 API 页面时，等高空槽继续按指针纵向位置让位；离开页面取消时恢复初始顺序。
- [ ] 成功释放时 Panel 连续归位到目标槽并与真实行交接；Panel 不会先消失，真实行也不会在错误槽位闪现。
- [ ] 成功释放的 Panel 落点移动约 140ms、最终交叉交接约 120ms，明显快于让位阶段但不闪现。
- [ ] 取消、无效 drop、切换页面或窗口失活不会提交临时顺序，并清理 Panel/临时状态；成功 drop 只提交一次最终顺序且重启后顺序一致。
- [ ] 固定 580×76pt 完整预览、手柄精确锚点、透明 1×1pt 原生 drag item、点击编辑和无障碍上移/下移动作保持不回归。
- [ ] Reduce Motion 下无弹簧、位置追随或落下飞行动画；最终顺序、取消恢复和短透明度反馈仍清楚。
- [x] 定向测试、`./scripts/check.sh` 和 `git diff --check` 通过；新增/拆分源码满足 800 行与 8 个顶层类型门禁。
- [x] `./scripts/build-test-app.sh` 通过，固定 `artifacts/Marla_dev.app` 的 Bundle、`0.0.0`、arm64、Paper Lantern 资源、稳定签名和 designated requirement 保持有效。
- [ ] 在固定 App 中完成向下、向上、快速反向、取消及 Reduce Motion 连续操作；浅色与深色真实证据的五维复审每维至少 7/10。
- [x] 拖放相关 UI/实现规格、当前 Task 与 `STATUS.md` 同步到当前实现和验证事实；项目所有者现场验收后再写最终关闭记录。

## Verification

### Automated

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter APIProfileReorder
./scripts/check.sh
./scripts/build-test-app.sh
```

### Manual

- 固定 `artifacts/Marla_dev.app`，Settings → 翻译 API，至少两个具名 profile。
- 浅色与深色：从尾部手柄向下、向上、跨边界后快速反向并释放；逐帧检查拿起、等高空槽、周围行让位、落下交接和最终顺序。
- 取消/无效 drop：拖出有效列表或以系统取消路径结束，确认顺序与初始一致且无残留 Panel。
- Reduce Motion：重复同组操作，确认无位置弹簧/飞行动画，但状态变化和短透明度交接可理解。
- 原始用户截图/录屏只作为外部临时证据，不复制进仓库；新证据只使用脱敏 fixture/profile。

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
- `docs/tasks/TASK-013-api-profile-activation-and-editor-actions.md`
- `docs/tasks/TASK-037-ui-motion-polish.md`
- `docs/versions/0.1.0/UI_SPEC.md`（仅作为拖放历史交互证据，不作为当前发布合同）
- `docs/versions/0.1.0/IMPLEMENTATION.md`（仅作为拖放历史实现证据，不作为当前发布合同）
- `Sources/MarlaApp/SettingsView.swift`
- `Sources/MarlaApp/Settings/SettingsShared.swift`
- `Sources/MarlaApp/MarlaMotion.swift`
- `Sources/MarlaApp/Persistence/MarlaSettingsStore.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors (optional)

None. 当前实现和文档围绕同一个 AppKit/SwiftUI 拖放状态机紧密耦合，且 Task、`STATUS.md` 与相关规格必须由主 Agent 统一解释和写入；不制造并行写入冲突。

## Risks and rollback

- 独立 Panel 与 SwiftUI 行处于不同窗口坐标系；落下 frame 必须从真实目标 slot 转成屏幕坐标，不能从固定行高猜测。
- 用动画 completion 决定持久化会让取消和快速反向产生竞态；最终业务顺序必须由 drop 事件一次提交，completion 只清理视觉层。
- macOS 原生 drag session 的取消与成功结束时序不同；回滚路径是保留透明 1×1pt 原生 item 与固定 Panel，只关闭新增交接/临时顺序状态，恢复 TASK-037 已验证语义。
- 拆分源码需要同步手工维护的 Xcode project；SwiftPM 和 Xcode Debug 都必须通过。

## Decisions needed

None. 本 Task 保持已认可视觉、尺寸、产品和持久化合同，只修复真实录屏中可复现的交互动效连续性。

## Completion record

- Verified commit:
- Automated evidence:
- Manual evidence:
- Documentation updated:
- Remaining work promoted to:
- Scope changes closed:
- Parallel contributions integrated:
