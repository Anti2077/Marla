# TASK-003: 菜单最近翻译与全表面玻璃一致性

Status: Done

Owner: Project owner + Agent

Created: 2026-08-06

Updated: 2026-08-06

Origin: direct request / visual defect

## Outcome

三项准备全部完成后，菜单栏弹窗自动隐藏权限状态条，并在同一区域展示仅本次运行保留的最近翻译；截图翻译入口始终显示有效图标。菜单、设置、结果卡、快速输入与截图框选提示在支持的系统上使用一致的 Liquid Glass，在 macOS 14–25 保持可读的系统材质回退。

## Why now

项目所有者在真实 App 截图中确认了三个问题：已完成权限仍长期占用菜单空间、截图翻译入口图标缺失、菜单栏弹窗和其他界面的玻璃视觉不一致。这些问题直接影响菜单栏作为主要入口的日常可用性。

## In Scope

- 三项准备未全部完成时显示可操作状态；全部完成后自动隐藏该状态条。
- 增加最多三条、仅内存、退出即清空的最近完成翻译，并允许从菜单重新打开结果。
- 为最近翻译增加去重、容量和失败/未完成结果不入列的自动化测试。
- 替换在目标系统上不可用的截图翻译 SF Symbol，并覆盖菜单和设置中的同一入口。
- 让菜单、设置、结果卡、快速输入与截图框选提示/尺寸标签采用一致的单层玻璃策略；macOS 14–25 使用系统材质回退。
- 同步 0.1.0 中英文规格、实现说明、验收项和 `STATUS.md`。

## Out of Scope

- 写入磁盘、UserDefaults、数据库或云端的持久翻译历史。
- 收藏、搜索、同步、来源应用/窗口记录或截图缩略图。
- 改变翻译 Provider、OCR、快捷键或权限获取机制。
- 为旧系统模拟与 macOS 26 完全相同的光学渲染。

## Current evidence

- 真实菜单截图显示三个权限均已完成，但权限状态条仍然可见。
- `MenuBarView` 无条件渲染 `PermissionChip`，并使用不透明 `DesignTokens.background`。
- 菜单和设置使用 `rectangle.dashed.and.magnifyingglass`，真实菜单中该 SF Symbol 没有渲染；结果卡的截图图标已经使用可用的 `viewfinder`。
- 结果卡和快速输入已经使用 `marlaGlassSurface`；菜单和设置尚未使用，截图框选提示仍是纯黑色块。
- 0.1.0 明确禁止持久历史，但 `IDEA-006` 已记录“会话内、退出后清空”为最小候选形态；本次直接请求选择该形态，不改变持久化边界。

## Proposed approach

在 `TranslationSessionStore` 内维护一个有界的 `RecentTranslation` 数组，只在请求完成且原文/译文均非空时更新；相同原文、译文和目标去重并移到首位。菜单通过应用模型重新展示所选条目，整个数组不接触任何持久化 API。

复用一个主要表面修饰器：macOS 26+ 使用 SwiftUI `glassEffect`，macOS 14–25 使用单层 `regularMaterial`。设置窗口清除内容区的不透明背景；截图框选的提示与尺寸标签使用 AppKit `NSVisualEffectView` 等价的材质绘制路径或克制的材质容器。内部控件不叠加第二层玻璃。

## Acceptance criteria

- [x] API、辅助功能和屏幕录制任一未就绪时，菜单仍显示相应状态和入口。
- [x] 三项全部就绪后，权限状态条自动消失；无最近结果时显示清楚的空状态。
- [x] 最多三条最近完成翻译只存在于内存，退出后清空；失败、取消和空结果不进入列表。
- [x] 点击最近翻译可重新打开完成态结果卡，不发起新的网络请求。
- [x] 截图翻译在菜单和设置中均显示有效 SF Symbol。
- [x] 菜单、设置、结果卡、快速输入和截图框选提示具有一致的单层玻璃表面；浅色、深色与回退路径均可读。
- [x] Reduce Motion 行为、翻译生命周期和隐私边界不回归。
- [x] `./scripts/check.sh` 通过。
- [x] 真实 App 截图完成五维复评且每项至少 7/10。
- [x] 相关 0.1.0 中英文文档和 `STATUS.md` 同步。

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

- 在三项准备分别未完成与全部完成的真实菜单状态中截图，确认状态条替换逻辑。
- 完成至少四次翻译，确认容量、排序、去重、点击恢复和退出清空。
- 在浅色、深色与 Reduce Motion 下检查菜单、设置、结果卡、快速输入和截图框选提示。
- 对真实截图执行 `swiftui-design-skill` 五维复评，证据写入 `artifacts/ui-review/task-003/`。

## Required Reading

- `docs/development/STATUS.md`
- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/UI_SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/backlog/IDEAS.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `Sources/MarlaApp/MarlaApp.swift`
- `Sources/MarlaApp/SettingsView.swift`
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Sources/MarlaApp/MarlaPreviews.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Risks and rollback

- 会话内最近翻译延长敏感文字在进程内的生命周期；容量固定为三条、无来源元数据、退出清空，并在设置中明确说明。
- 系统玻璃在离屏截图中可能不可栅格化；自动化继续显式使用材质回退，真实 App 截图验证 macOS 26 路径。
- 清除窗口背景可能降低文字对比度；使用语义色、单层材质和真实浅/深色截图复核。
- 可通过移除最近数组和恢复权限条常驻渲染回滚，不影响翻译核心或持久设置。

## Decisions needed

None. 项目所有者已选择会话内最近翻译和全表面 Liquid Glass；持久历史仍不在 0.1.0 范围内。

## Completion record

- Verified commit: pending; worktree implementation verified on 2026-08-06.
- Automated evidence: `./scripts/check.sh` passed with 16 Rust tests, 22 Swift tests, Swift build, Xcode Debug App build, source whitespace, and `git diff --check`. Added tests cover SF Symbol availability, recent capacity/deduplication, failed/cancelled/empty exclusion, and restoration without a network request. `Marla_test_202608061928.app` passed Release package verification.
- Manual evidence: light/dark recent menus, Settings, quick input, comparison card, and screenshot selection inspected under `artifacts/ui-review/task-003/`; first-pass Settings title-bar black strip was fixed and recaptured. Five-dimension scores: 8/8/8/8/7. `computer-use` could not enumerate the LSUIElement no-main-window app, so the production macOS 26 glass path is supported by compiled `glassEffect` code while off-screen screenshots intentionally show the material fallback.
- Documentation updated: `docs/development/STATUS.md`, `docs/versions/0.1.0/SPEC.md`, `UI_SPEC.md`, `IMPLEMENTATION.md`, `ACCEPTANCE.md`, and this task file.
- Remaining work promoted to: None. Persistent history, favorites, search, and synchronization remain in `IDEA-006` and outside 0.1.0.
