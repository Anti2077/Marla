# TASK-031：状态栏菜单与设置玻璃一致性

Status: Done

Owner: Project owner + Agent

Created: 2026-08-18

Updated: 2026-08-18

Origin: direct request / visual defect

Conversation: 2026-08-18，项目所有者反馈状态栏菜单背景不如设置窗口通透

## Initial request

项目所有者希望状态栏菜单面板的背景透明观感与设置窗口一致。

## Outcome

状态栏 `MenuBarExtra(.window)` 只使用其原生系统玻璃，不再在内容内部叠加第二层 Marla 玻璃；设置窗口仍由透明原生窗口承载单层 Marla 系统玻璃。两者在浅色、深色以及聚焦/失焦状态下保持同一套系统自适应透明逻辑。

## Why now

当前 `MenuBarExtra(.window)` 已提供原生窗口材质，但 `MenuBarView` 末端又调用 `marlaGlassSurface()`；设置窗口则先把 `NSWindow` 背景设为透明，再只铺一层同一 modifier。双层与单层的所有权差异会让菜单视觉上更实、更不透明，也与 `UI_SPEC.md` 已明确的“不叠加多层模糊”约束不一致。

## In Scope

- 移除生产状态栏菜单内容内部的第二层玻璃，让 `MenuBarExtra(.window)` 独占菜单背景材质。
- 保持设置窗口、结果卡、快速输入和截图标签的既有单层玻璃实现不变。
- 保持菜单布局、Paper Lantern、尺寸、交互和可访问身份不变。
- 为独立 Preview / UI fixture 保留可显式启用的单层预览表面，但不让该表面进入生产 `MenuBarExtra`。
- 增加回归覆盖并同步 0.1.0 实现说明、UI 规格、Task 与 `STATUS.md`。

## Out of Scope

- 调整 `.glassEffect(.regular)`、`regularMaterial` 或整张 View 的 opacity。
- 新增透明度档位、设置项、持久化偏好或第二层材质。
- 改变菜单、设置、结果卡、快速输入或截图标签的布局、颜色、圆角、边框和阴影。
- 修改 Paper Lantern 资源、状态栏图标、AppIcon 或功能图标。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-18 | Project owner | 让状态栏菜单背景与设置窗口一样通透 | 增加材质所有权回归，并要求固定 Release 的菜单/设置浅色、深色、聚焦/失焦截图比较 | Verified; owner authorized main integration |

## Current evidence

- `MarlaApplication.body` 使用 `MenuBarExtra(...).menuBarExtraStyle(.window)`，该 scene 自带原生窗口背景。
- `MenuBarView.body` 当前在最外层再次调用 `.marlaGlassSurface(cornerRadius: 20)`，形成第二层材质。
- `SettingsWindowStyle` 把设置窗口设为非不透明、透明背景；`SettingsView.body` 只调用一次 `.marlaGlassSurface(...)`。
- `docs/versions/0.1.0/UI_SPEC.md` 已要求每个表面只使用一层 macOS HUD/Popover 类材质，避免叠加多层模糊。
- TASK-026 的整窗 opacity、强制 clear 与离散玻璃档位实验均因聚焦/失焦观感过透而回滚；本 Task 不恢复这些方案。
- 生产 `MenuBarView` 现在默认 `usesStandaloneGlassSurface == false`；Preview 与 `showMenuAutomationSurface` 显式传入 `true`，新增回归锁定两种所有权。
- 沙箱外 `./scripts/check.sh` 已通过 20 项 Rust 与 157 项 Swift 测试（3 项 Vision 因既有 `OSStatus -6662` 环境限制跳过）、Swift/Xcode Debug、结构、格式、空白和 diff 检查。沙箱内两次运行的 3 个既有 Pasteboard 断言返回 `nil`；同一源码在沙箱外全部通过，证明是系统 Pasteboard 沙箱边界而非产品回归。
- `./scripts/build-test-app.sh` 已重建并验证固定签名 Release App 的 Bundle ID、0.1.0、macOS 14+、arm64、Paper Lantern 资源、稳定签名和 designated requirement。

## Proposed approach

让背景材质的所有权跟随实际窗口：生产 `MenuBarExtra(.window)` 由系统窗口独占；透明的自定义设置窗口继续由 `SettingsView` 的 `marlaGlassSurface()` 独占。`MenuBarView` 增加一个仅用于独立 Preview / 自动化容器的显式表面参数，生产 scene 保持默认无内部材质。该改变不需要新的耐久 ADR。

## Acceptance criteria

- [x] 生产状态栏菜单不再叠加内容级 `marlaGlassSurface()`，设置窗口仍为单层系统玻璃。
- [x] 菜单与设置使用一致的单层系统自适应材质所有权，没有整窗 opacity、强制 clear 或新增第二层材质；项目所有者在固定 App 交付后授权合并。
- [x] 菜单宽度、内边距、Paper Lantern 位置、标题光学校正、按钮与最近翻译布局不变。
- [x] 独立 Preview / fixture 仍能用显式单层表面渲染，但生产默认值不能启用它。
- [x] 自动化回归、`./scripts/check.sh`、固定签名 Release 打包和 `git diff --check` 通过。
- [x] 新增代码未使任何源文件超过结构门禁。
- [x] 固定 Release App 的菜单/设置浅色与深色证据完成五维复审，每项至少 8/10；原生状态项的最终观感由项目所有者授权合并验收。
- [x] 0.1.0 实现说明、UI 规格、Task 与 `STATUS.md` 同步。

## Verification

### Automated

```sh
./scripts/check.sh
./scripts/build-test-app.sh
```

### Manual

重建并重新启动固定 `/Users/anti/Documents/ChatGPT/Marla/artifacts/Marla_dev.app`；分别捕获状态栏菜单和设置窗口的浅色、深色以及聚焦/失焦真实窗口截图，核对背景通透程度、边缘、文字对比度和既有布局。截图写入 `/private/tmp`，不提交仓库。

固定 Release App 的浅色/深色菜单独立 fixture 与设置窗口证据位于 `/private/tmp/marla-task031-menu-light.png`、`/private/tmp/marla-task031-menu-dark.png`、`/private/tmp/marla-task031-settings-focused.png`、`/private/tmp/marla-task031-settings-dark.png`。布局与对比度五维复审为 Philosophy 8、Visual Hierarchy 9、Craft 8、Functionality 9、Originality 8。菜单 fixture 通过显式独立单层表面验证布局；Computer Use 无法枚举无主窗口的 LSUIElement 状态项，因此没有把 fixture 冒充原生窗口截图。固定 App 交付后，项目所有者于 2026-08-18 明确要求合并到 `main`，作为本 Task 的最终原生观感验收与集成授权。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `docs/versions/0.1.0/UI_SPEC.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0007-app-layer-modularity.md`
- `docs/architecture/decisions/ADR-0008-paper-lantern-brand-identity.md`
- `docs/tasks/TASK-026-credential-consistency.md`
- `Sources/MarlaApp/MarlaApp.swift`
- `Sources/MarlaApp/SettingsView.swift`
- `Sources/MarlaApp/Settings/SettingsWindow.swift`
- `Sources/MarlaApp/Panel/FloatingPanel.swift`
- `Sources/MarlaApp/MarlaPreviews.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors (optional)

None. Task、单个 SwiftUI 表面和验证口径高度耦合，由主 Agent 单一写入。

## Risks and rollback

- 如果误删 Preview / fixture 的唯一背景，离屏视觉证据会变成透明内容；显式独立表面参数隔离这一风险。
- 原生 `MenuBarExtra` 的材质会随系统、焦点、桌面背景和无障碍设置自适应；必须用真实窗口而不是离屏 fixture 判断最终透明度。
- 回滚只需恢复生产菜单内部的 modifier 和移除独立表面参数；没有设置或数据迁移。

## Decisions needed

None

## Completion record

- Verified commit: `0ef3a6d`（实现）；收束提交见 Git 历史。
- Automated evidence: 沙箱外 `./scripts/check.sh` 通过 20 项 Rust、157 项 Swift（3 项既有 Vision host skip）、Swift/Xcode Debug、结构、格式、空白和 diff 检查；`./scripts/build-test-app.sh` 通过固定 Release 包、资源、稳定签名和 designated requirement 验证。
- Manual evidence: `/private/tmp/marla-task031-menu-light.png`、`/private/tmp/marla-task031-menu-dark.png`、`/private/tmp/marla-task031-settings-focused.png`、`/private/tmp/marla-task031-settings-dark.png` 五维复审为 8/9/8/9/8；项目所有者在固定 App 启动交付后授权合并到 `main`。
- Documentation updated: 本 Task、`STATUS.md`、0.1.0 `IMPLEMENTATION.md` 与双语 `UI_SPEC.md`。
- Remaining work promoted to: None
- Scope changes closed: Yes
- Parallel contributions integrated: None
