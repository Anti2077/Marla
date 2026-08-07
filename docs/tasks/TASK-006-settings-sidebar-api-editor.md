# TASK-006：设置侧栏与 API 配置编辑器重构

Status: Complete

Owner: Project owner + Agent

Created: 2026-08-06

Updated: 2026-08-07

Origin: direct request / UI defect

Conversation: `TASK-005` 多 API 配置与设置、截图交互持续迭代（历史详细切片）

## Initial request

项目所有者要求把设置改为原生侧栏结构，API 页面只显示摘要，选择或添加配置后才打开独立详情编辑器，并修复删除后的空白行和输入框拉伸。

## Outcome

设置窗口提供原生 macOS 侧栏，API 页面只展示配置摘要；详细配置在独立编辑窗口中打开，输入控件固定对齐，删除最后一个配置后显示真实空状态。

## Why now

TASK-005 的多 API 数据与行为已完成，但当前设置页仍将列表与编辑器堆在同一个 Form 中，造成删除后的空白区域、过长输入框和信息过载。

## In Scope

- 设置侧栏：通用、翻译 API、快捷键、OCR。
- API 摘要列表、添加/编辑弹出窗口、排序、默认和删除操作。
- 固定标签列与输入框宽度，修复最后配置删除后的空状态。
- OCR 只读 Vision/隐私说明页。
- 路由、删除、摘要同步自动化测试；真实 App 截图和五维 UI 评审。
- 同步 STATUS、BACKLOG、IDEAS 与本任务记录。

## Out of Scope

- 新增 OCR provider、OCR 参数、图片上传或翻译协议。
- 修改 TranslationAPIProfile、Keychain account、迁移、默认翻译和结果卡片切换行为。
- 隐私、关于、上下文增强和其它未确认子菜单。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-06 | Project owner | 将本切片要求追加到 `TASK-005` 对应的同一开发对话 | 侧栏、摘要列表、独立编辑器、空状态和真实 App 五维验收 | Verified |

## Current evidence

- TASK-005 已通过 `./scripts/check.sh`，现有 SettingsView 在一个 Form Section 中同时渲染列表和编辑器。
- 截图显示删除后空白区域、Base URL 输入过长以及详细字段常驻。

## Proposed approach

使用 `NavigationSplitView` 管理四个页面；API 页面只渲染摘要行并以 SwiftUI sheet 作为独立编辑窗口入口。编辑器使用固定标签列和 360pt 输入框，Key 仍仅写入 profile 派生的 Keychain account。

## Acceptance criteria

- [x] 设置默认打开通用页，侧栏包含四个首期页面。
- [x] API 列表仅显示名称、模型、默认/完整状态和操作；详细字段只在编辑窗口中显示。
- [x] 删除当前或最后配置后选择状态与空状态正确，无隐藏编辑区或占位 Divider。
- [x] 编辑名称/模型后摘要立即同步；Keychain 和多 API 行为回归测试继续通过。
- [x] `./scripts/check.sh` 通过。
- [x] 真实 App 生成侧栏、列表、编辑器、快捷键、OCR、浅色/深色证据，每项五维评审至少 7/10。
- [x] `./scripts/build-test-app.sh` 覆盖固定 `artifacts/Marla_dev.app`，保持现有签名和 Bundle ID。

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

使用真实 Debug/Release 测试 App 检查侧栏默认页、API 摘要、编辑弹窗、删除最后配置空状态、快捷键和 Vision OCR 状态页；在浅色、深色和 Reduce Motion 下截图留证。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `docs/versions/0.1.0/UI_SPEC.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `Sources/MarlaApp/SettingsView.swift`
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Sources/MarlaApp/MarlaApp.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Risks and rollback

- 侧栏增加最小窗口尺寸；可恢复为旧窗口宽度而不触碰数据模型。
- Sheet 的生命周期可能影响连接测试；关闭时取消 tester，Keychain 写入保持原路径。

## Decisions needed

None — 采用原生侧栏与弹出编辑窗口，OCR 页面只读 Vision 状态。

## Completion record

- Verified commit: Working tree (commit pending)
- Automated evidence: `./scripts/check.sh` — Rust 16 tests, Swift 26 tests, Xcode Debug build, formatting/whitespace and `git diff --check` passed.
- Manual evidence: `artifacts/ui-review/task-006/`; fixed Release App sidebar/API/editor/empty-state/shortcuts/OCR screenshots passed 8/8/8/8/7 review.
- Documentation updated: `STATUS.md`, `BACKLOG.md`, `IDEAS.md`, `UI_SPEC.md`, this Task.
- Remaining work promoted to: None
- Scope changes closed: Yes
