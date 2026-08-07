# TASK-005：多翻译 API 配置与结果卡片手动切换

Status: Complete

Owner: Project owner + Agent

Created: 2026-08-06

Updated: 2026-08-07

Origin: BL-007 / direct request / IDEA-010

Conversation: 2026-08-06 至 2026-08-07，多 API 配置与设置、截图交互持续迭代

## Initial request

项目所有者要求直接实现想法池中的多 API 配置，并在完成后继续覆盖固定 `artifacts/Marla_dev.app`，避免测试 App 因路径、Bundle ID 或签名漂移而反复申请权限。

## Outcome

用户可以在设置中保存多个具名 OpenAI-compatible 翻译端点、独立管理每个 API Key，并在当前翻译结果卡片中显式切换配置；切换会取消旧请求，用同一份源文本和目标语言重新翻译。本次开发对话随后持续完成设置侧栏与独立编辑器、快捷键开关、截图放大镜、设置/截图焦点处理、可靠 Escape 取消、Base/完整 URL、模型发现和编辑器 Focus Ring 修复，并始终交付同一固定签名测试 App。

## Why now

当前设置只支持一个端点，切换服务商需要离开结果卡片并修改全局字段。项目所有者已明确要求直接实现 IDEA-010 的首期核心交互。

## In Scope

- 多配置数据模型、稳定配置 ID、默认配置和旧单配置迁移。
- 配置的创建、命名、编辑、测试、排序、删除和设为默认。
- 每个配置使用独立 Keychain account；删除同步删除凭证。
- 选择、截图、快速输入结果卡片显示配置名并提供切换菜单。
- 切换时取消旧请求、隔离迟到事件、复用源文本/目标语言；截图不重新截图或 OCR。
- 将设置重构为通用、翻译 API、快捷键和 OCR 四页侧栏；API 列表只展示摘要，详情在独立编辑器中打开。
- 修复 API 编辑器取消、四角裁切与固定字段对齐；为三个全局快捷键增加独立开关。
- 允许结果卡从背景拖动，修复底角；截图框选增加十字光标、6× 放大镜、中心准星和边缘换位。
- 将设置窗口整合为单一连续四角表面，隐藏滚动白条；截图开始时暂时隐藏设置窗口并可靠响应 `Esc`。
- 为每个 profile 增加 Base URL/完整 URL 模式，并通过当前地址与 Key 获取、展开和选择 `/models` 模型列表。
- 为 API 编辑器首行增加 Focus Ring 安全边距，保证浅色和深色前台窗口中的系统聚焦环四边完整。
- 自动化测试、0.1.0 中英文实现文档和 STATUS 同步。

## Out of Scope

- 自动 fallback、静默路由和按失败类型自动改发。
- Provider 专属参数、图片直传、上下文控制、持久化历史和多模型对比。
- 为每个入口单独记忆默认配置。

## Scope changes during the conversation

本表按新 conversation-scoped Task 规则追溯整理。`TASK-006` 至 `TASK-011` 是旧规则下创建的详细施工与验收切片，继续保留以维护原有证据链接；它们现在统一归入本 Task 的同一开发对话范围。

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-06 | Project owner | 初始范围：多 API profile、独立 Keychain、默认配置、结果卡手动切换与固定 App 覆盖 | profile 迁移、请求隔离、截图 OCR 复用、真实设置/卡片截图和固定签名 App | Verified |
| 2026-08-06 | Project owner | 增加设置侧栏、摘要 API 列表、独立详情编辑器、通用/快捷键/OCR 页面 | 删除空状态、固定字段宽度、浅色/深色真实 App 验收；详见 `TASK-006` | Verified |
| 2026-08-06 | Project owner | 增加编辑器取消、快捷键开关、结果卡拖动/底角修复和截图指针放大镜 | 持久开关、取消清理、面板几何、放大镜边界与隐私验收；详见 `TASK-007` | Verified |
| 2026-08-06 | Project owner | 增加设置单一连续表面、移除右缘白条、显示 Esc 提示并处理设置窗口与截图层级 | 设置窗口 AppKit 样式、截图期间暂停/恢复设置、真实场景截图；详见 `TASK-008` | Verified |
| 2026-08-06 | Project owner | 真实使用发现 `Esc` 未退出截图，提升为会话级可靠取消 | 本地/全局按键监听、幂等取消、真实键盘事件验证；详见 `TASK-009` | Verified |
| 2026-08-07 | Project owner | 增加 Base URL/完整 URL 模式、紧凑行内 switch，以及按当前地址和 Key 获取模型 | 旧配置迁移、C ABI v2、URL/`/models` 推导、真实 API 流与模型列表；详见 `TASK-010` | Verified |
| 2026-08-07 | Project owner | 修复 API 编辑器首行蓝色 Focus Ring 顶部被滚动视口裁切 | 8pt 安全边距、浅色/深色前台窗口截图与五维复评；详见 `TASK-011` | Verified |

## Current evidence

- `MarlaSettingsStore` 当前持久化单个 `baseURL`/`modelName`，Keychain account 为 `translation-api-key`。
- `TranslationSessionStore.startRequest` 从全局字段构造 endpoint；`changeTarget` 已具备取消并重跑的生命周期模式。
- `TranslationCardView` 当前只显示目标语言菜单，没有 Provider 配置选择器。

## Proposed approach

Swift 侧新增 `TranslationAPIProfile`（稳定 UUID、名称、Base URL、模型），SettingsStore 持有有序 profiles 和 active/default ID，凭证通过 profile ID 派生 Keychain account；首次加载无 profiles 时把旧字段迁移成一个默认 profile。CardSession 保存 profile ID/显示名，SessionStore 按当前 profile 构造 FFI endpoint；新增 `changeAPIProfile` 复用源文本和目标语言并生成新的 request ID。设置 UI 使用列表式配置编辑器，保持现有 Warm Minimal/Liquid Glass 视觉和密钥不回显。

## Acceptance criteria

- [x] 初始请求和 Scope changes 中所有仍有效的要求都有对应验收项和可追溯的详细证据。
- [x] 设置可以新增、编辑、测试、排序、删除配置并设定默认配置；至少两个配置可同时存在。
- [x] 每个配置的 Key 独立保存在 Keychain，重命名不丢失，删除同步移除。
- [x] 旧单配置首次启动后可见为一个配置且旧 Key 可用；迁移不重复执行。
- [x] 新翻译使用默认配置；结果卡片显示配置短名称并可显式切换。
- [x] 切换会取消旧请求、使用新 request ID，迟到 delta 不得污染新译文；截图切换不重新 OCR。
- [x] `./scripts/check.sh` 通过：Rust 16 tests、Swift 24 tests、Xcode Debug App build、格式/空白和 `git diff --check` 均通过。
- [x] 真实 Debug App 设置与结果卡片截图完成五维 SwiftUI 评审，每维至少 7/10。
- [x] 相关规格、BACKLOG、IDEAS 和 STATUS 已同步。
- [x] 设置侧栏、独立 API 编辑器、空状态、快捷键开关和 OCR 说明按 `TASK-006/007` 的详细标准通过。
- [x] 结果卡拖动、底角、截图十字指针/放大镜以及设置窗口单层四角按 `TASK-007/008` 的详细标准通过。
- [x] 截图框选中的真实 `Esc` 在普通和设置已打开场景均可靠取消，且不产生 OCR 或翻译请求。
- [x] Base/完整 URL、模型发现、真实 `gpt-5.6-luna` SSE 和编辑器 Focus Ring 按 `TASK-010/011` 的详细标准通过。
- [x] 最终 `./scripts/check.sh` 通过 17 项 Rust、41 项 Swift 测试和 Xcode Debug 构建；固定 Release App 保持既有身份。

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

使用真实 App：创建并切换至少两个配置，确认旧请求停止、译文更新、截图不重新 OCR；逐项复核设置侧栏/编辑器、快捷键开关、结果卡拖动、截图放大镜和 Escape；使用 Base/完整 URL 获取模型并完成真实流式翻译；在浅色和深色下检查 Focus Ring。分阶段证据保存在 `artifacts/ui-review/task-005/` 至 `task-011/`。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `docs/versions/0.1.0/UI_SPEC.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `Sources/MarlaApp/SettingsView.swift`
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Sources/MarlaApp/MarlaApp.swift`
- `Sources/MarlaCore/RustCoreBridge.swift`
- `rust/marla-core/src/lib.rs`
- `Tests/MarlaAppTests/MarlaAppTests.swift`
- `Tests/MarlaCoreTests/MarlaCoreTests.swift`

## Risks and rollback

- 迁移失败时保留旧字段和旧 Keychain account，不能删除旧凭证；可回滚到单配置读取路径。
- 配置切换扩大卡片状态，必须依赖 request ID 隔离，避免迟到事件污染。
- 设置窗口内容增加可能影响小窗口可用性，保留滚动和最小尺寸。

## Decisions needed

None — 首期全局默认配置、当前卡片手动切换和直接替换译文已由本任务确定。

## Completion record

- Verified commit: Working tree (commit pending)
- Automated evidence: the final `./scripts/check.sh` run passed 17 Rust and 41 Swift tests, Swift/Xcode Debug builds, formatting, whitespace, and `git diff --check`; intermediate milestones are preserved in `TASK-006` through `TASK-011`.
- Manual evidence: real App evidence is preserved under `artifacts/ui-review/task-005/` through `task-011/`; each SwiftUI five-dimension review scored at least 7/10. Real Escape cancellation and the supplied endpoint's model/SSE paths were also verified in their detailed slices.
- Documentation updated: `STATUS.md`, `BACKLOG.md`, `IDEAS.md`, bilingual 0.1.0 specifications/acceptance, architecture, this canonical conversation Task, and retained detailed slices `TASK-006` through `TASK-011`.
- Remaining work promoted to: None
- Scope changes closed: Yes
