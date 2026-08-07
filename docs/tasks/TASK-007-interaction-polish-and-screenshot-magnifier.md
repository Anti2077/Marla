# TASK-007：设置与浮层交互细节修正

Status: Complete

Owner: Project owner + Agent

Created: 2026-08-06

Updated: 2026-08-07

Origin: direct request / UI defects

Conversation: `TASK-005` 多 API 配置与设置、截图交互持续迭代（历史详细切片）

## Initial request

项目所有者要求修复 API 编辑器边界与取消、设置圆角、快捷键独立开关、结果卡拖动/底角，并为截图框选增加十字指针和便于精细操作的放大镜。

## Outcome

设置窗口补齐可撤销的新增配置流程、快捷键独立开关和完整圆角；翻译结果卡可拖动且边缘干净；截图框选提供系统十字光标与贴近指针的像素放大镜，便于精确落点。

## Why now

TASK-006 已完成设置结构重构，但真实 App 截图暴露了编辑器边界、缺少取消、侧栏圆角、快捷键按需启用、结果卡拖动和底角裁剪问题。项目所有者同时确认需要改善截图框选的细微操作。

## In Scope

- API 编辑器边界留白与明确取消操作；取消新增时删除临时 profile 及其独立 Keychain 项。
- 设置侧栏圆角与每个全局快捷键的持久化开关。
- 结果卡片可拖动，并移除造成底角突出的重复阴影/边缘。
- 截图框选保持系统十字光标，并增加内存像素放大镜、中心准星、坐标与边缘自动换位。
- 自动化测试、双语 UI/行为规格、真实 App 截图和五维设计评审。

## Out of Scope

- OCR provider、OCR 参数、图片上传或翻译请求协议。
- 修改 `TranslationAPIProfile` 的持久化 schema 或 Keychain account 规则。
- 自动 API fallback、截图历史、云端 OCR、快捷键菜单入口的显隐。
- 自定义鼠标光标资源、屏幕像素持久化或诊断截图存储。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-06 | Project owner | 将本切片交互修复追加到 `TASK-005` 对应的同一开发对话 | 取消清理、快捷键持久化、面板几何、放大镜边界/隐私和真实 App 五维验收 | Verified |

## Current evidence

- TASK-006 真实 App 截图显示 API 编辑 sheet 缺少取消，编辑区域边界留白不足，侧栏背景顶部为直角。
- 快捷键管理器当前总是注册三个 action，没有独立 enabled 状态。
- `MarlaPanel` 没有启用窗口背景拖动；SwiftUI 卡片和 NSPanel 同时绘制阴影，底角出现边缘突出。
- 框选视图已经声明系统 `.crosshair`，但没有指针位置的像素放大反馈。

## Proposed approach

新增轻量编辑会话状态区分新建与已有配置；快捷键 enabled 集合独立持久化并参与 Carbon 注册。结果面板由 AppKit 窗口负责拖动和外层阴影，SwiftUI 内容只负责圆角材质。截图入口在显示框选层前取得每块显示器的短生命周期内存快照，放大镜只采样指针周围小区域并在会话结束时释放。

## Acceptance criteria

- [x] 新增配置可以取消；取消后列表、默认选择和 Keychain 中都不残留临时配置。
- [x] API 字段/焦点边界不被 sheet 裁切，设置侧栏四角完整。
- [x] 三个全局快捷键各有 switch；关闭后立即取消注册，重开后恢复注册，状态跨启动保留。
- [x] 翻译结果卡可从非控件区域拖动，底部两角没有突出的矩形边缘。
- [x] 截图框选使用十字光标，指针旁显示清晰放大镜、中心准星和坐标，并在屏幕边缘自动换位。
- [x] 放大镜来源只在内存中存在，会话取消/完成后释放，不改变 Vision 与网络隐私边界。
- [x] `./scripts/check.sh` 通过，真实 App 截图五维评审每项至少 7/10。
- [x] `./scripts/build-test-app.sh` 覆盖固定 `artifacts/Marla_dev.app`，保持 Bundle ID、稳定签名和 designated requirement。

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

在真实固定路径 App 中检查浅色/深色设置页、API 新增取消、快捷键开关、可拖动结果卡和截图放大镜；验证放大镜在显示器四边换位且不遮住中心落点。证据保存到 `artifacts/ui-review/task-007/`，不保存用户截图源像素。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `docs/versions/0.1.0/UI_SPEC.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/features/screenshot-translation.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `docs/architecture/decisions/ADR-0005-vision-only-ocr-for-0.1.0.md`
- `Sources/MarlaApp/SettingsView.swift`
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Sources/MarlaApp/MarlaApp.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Risks and rollback

- 全局快捷键重注册可能遇到系统占用；失败时恢复上一组注册和 enabled 状态并显示冲突。
- 全屏内存快照会增加框选期间峰值内存；会话结束立即释放，失败时放大镜降级为准星而不阻塞框选。
- 背景拖动不得吞掉按钮、菜单、滚动和文字选择；可回退为仅标题栏拖动区域。

## Decisions needed

None — 项目所有者已确认全部交互修正与截图放大镜。

## Completion record

- Verified commit: Working tree (commit pending)
- Automated evidence: `./scripts/check.sh` — Rust 16 tests, Swift 30 tests, Xcode Debug build, formatting/whitespace and `git diff --check` passed.
- Manual evidence: `artifacts/ui-review/task-007/`; fixed Release App API editor, shortcut light/dark, result-card and screenshot-magnifier captures passed 8/8/8/8/7 review. AppKit panel properties and regression coverage verify background dragging; direct pointer-drag automation was not available for the LSUIElement app.
- Documentation updated: `STATUS.md`, `BACKLOG.md`, `SPEC.md`, `UI_SPEC.md`, this Task.
- Remaining work promoted to: None
- Scope changes closed: Yes
