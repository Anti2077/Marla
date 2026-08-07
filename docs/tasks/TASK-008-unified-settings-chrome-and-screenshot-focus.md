# TASK-008：设置窗口一体化与截图焦点修正

Status: Complete

Owner: Project owner + Agent

Created: 2026-08-06

Updated: 2026-08-07

Origin: direct request / UI defect

Conversation: `TASK-005` 多 API 配置与设置、截图交互持续迭代（历史详细切片）

## Initial request

项目所有者要求把窗口顶部按钮融入设置主界面、移除右缘突兀白条、在设置中说明 `Esc` 取消截图，并保证设置已打开时截图层仍位于最前方。

## Outcome

设置窗口只保留一个连续主表面，系统红黄绿按钮融入主界面且不显示突兀滚动条；截图框选明确提示 `Esc` 取消，并且从已打开的设置窗口触发截图时，设置不会重新抢到最前方。

## Why now

TASK-007 的真实 App 使用中暴露了设置标题栏与圆角内容双层叠放、右侧滚动指示器过亮，以及设置窗口打开时截图入口的窗口层级错误。这些问题直接破坏原生一致性和截图操作可用性。

## In Scope

- 将设置窗口标题栏与 SwiftUI 内容合并为单一连续视觉表面，保留原生红黄绿窗口按钮。
- 隐藏设置内容区不必要的滚动指示器，不影响实际滚动。
- 截图框选层显示 `Esc 取消`，并验证键盘 Escape 能结束当前选择会话。
- 截图开始时降低/隐藏已打开设置窗口，结束或取消后恢复其原有可见状态但不抢占用户前台应用。
- 自动化测试、真实固定路径 App 截图、五维设计评审和文档同步。

## Out of Scope

- 改变截图捕获、Vision OCR、翻译请求或隐私协议。
- 新增自定义标题栏按钮、OCR provider 或截图历史。
- 改变设置导航、API profile、Keychain 或快捷键数据模型。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-06 | Project owner | 将本切片窗口与截图层级要求追加到 `TASK-005` 对应的同一开发对话 | 单一四角表面、隐藏滚动条、设置暂停/恢复和截图取消场景验收 | Verified |

## Current evidence

- 用户截图显示系统标题栏与下方圆角 SwiftUI 内容形成两个分离矩形，红黄绿按钮没有融入主表面。
- `SettingsPageShell` 的 `ScrollView` 使用自动滚动指示器，窗口右缘出现突兀白条。
- 框选层已有 Escape 事件处理和顶部提示，但需要把该行为在设置页与真实截图入口中明确呈现并覆盖焦点回归。
- 设置窗口由独立 coordinator 管理；截图开始没有协调其可见性与恢复顺序。

## Proposed approach

由 `MarlaSettingsWindowCoordinator` 配置透明、全尺寸内容标题栏和统一圆角承载层，让原生交通灯保持可操作同时覆盖在同一表面。设置内容的滚动条改为隐藏但保留滚轮滚动。截图 coordinator 在会话前记录设置窗口状态并临时 `orderOut`，会话结束只恢复原可见窗口层级，不主动激活 App。

## Acceptance criteria

- [x] 设置窗口只显示一个连续圆角表面，红黄绿按钮位于主界面内，不再出现双层标题栏。
- [x] 设置窗口右缘没有白色滚动指示条，鼠标滚轮/触控板滚动仍可用。
- [x] 截图界面明确显示 `Esc 取消`，按 Escape 会取消且不执行 OCR 或翻译。
- [x] 设置窗口已打开时触发截图，设置不会重新到最前方遮挡框选层；取消/完成后状态恢复合理且不抢源应用焦点。
- [x] `./scripts/check.sh` 通过，真实 App 浅色/深色截图五维评审每项至少 7/10。
- [x] `./scripts/build-test-app.sh` 覆盖固定 `artifacts/Marla_dev.app`，Bundle ID、稳定签名和 designated requirement 不变。

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

用固定 Release App 检查浅色/深色设置窗口的一体化标题栏与右缘；保持设置窗口打开后触发截图，确认框选层、Escape 取消和设置窗口恢复。证据保存到 `artifacts/ui-review/task-008/`。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/UI_SPEC.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/features/screenshot-translation.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0005-vision-only-ocr-for-0.1.0.md`
- `Sources/MarlaApp/SettingsView.swift`
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Risks and rollback

- 全尺寸内容标题栏可能影响交通灯点击区域或窗口拖动；保留原生 titlebar style mask，并通过真实窗口截图和交互检查。
- 临时隐藏设置窗口必须只作用于本次截图会话；可回退为降低窗口层级，不触碰截图与 OCR 数据流。

## Decisions needed

None — 项目所有者已明确要求单一主表面、隐藏白条、Escape 取消和截图焦点修正。

## Completion record

- Verified commit: Uncommitted worktree; no commit requested
- Automated evidence: `./scripts/check.sh` passed on 2026-08-06 with 16 Rust and 34 Swift tests, including full-size Settings chrome, screenshot-window focus, settings suspension/restoration, and an Escape `NSEvent` cancellation path.
- Manual evidence: Release screenshots under `artifacts/ui-review/task-008/` cover unified Settings light, Shortcuts dark, and screenshot selection entered while Settings was open. Five-dimension score: 8/8/8/8/7. A physical Computer Use press could not be isolated because two same-path Marla processes were running; the Agent stopped only its own test process and did not terminate the owner's existing instance.
- Documentation updated: `SPEC.md`, `UI_SPEC.md`, `ACCEPTANCE.md`, screenshot feature status, `STATUS.md`, and Backlog.
- Remaining work promoted to: None; broader 0.1.0 live acceptance gaps remain listed in `STATUS.md`.
- Scope changes closed: Yes
