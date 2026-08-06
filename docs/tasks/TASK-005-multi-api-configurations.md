# TASK-005：多翻译 API 配置与结果卡片手动切换

Status: Complete

Owner: Project owner + Agent

Created: 2026-08-06

Updated: 2026-08-06

Origin: BL-007 / direct request / IDEA-010

## Outcome

用户可以在设置中保存多个具名 OpenAI-compatible 翻译端点、独立管理每个 API Key，并在当前翻译结果卡片中显式切换配置；切换会取消旧请求，用同一份源文本和目标语言重新翻译。

## Why now

当前设置只支持一个端点，切换服务商需要离开结果卡片并修改全局字段。项目所有者已明确要求直接实现 IDEA-010 的首期核心交互。

## In Scope

- 多配置数据模型、稳定配置 ID、默认配置和旧单配置迁移。
- 配置的创建、命名、编辑、测试、排序、删除和设为默认。
- 每个配置使用独立 Keychain account；删除同步删除凭证。
- 选择、截图、快速输入结果卡片显示配置名并提供切换菜单。
- 切换时取消旧请求、隔离迟到事件、复用源文本/目标语言；截图不重新截图或 OCR。
- 自动化测试、0.1.0 中英文实现文档和 STATUS 同步。

## Out of Scope

- 自动 fallback、静默路由和按失败类型自动改发。
- Provider 专属参数、图片直传、上下文控制、持久化历史和多模型对比。
- 为每个入口单独记忆默认配置。

## Current evidence

- `MarlaSettingsStore` 当前持久化单个 `baseURL`/`modelName`，Keychain account 为 `translation-api-key`。
- `TranslationSessionStore.startRequest` 从全局字段构造 endpoint；`changeTarget` 已具备取消并重跑的生命周期模式。
- `TranslationCardView` 当前只显示目标语言菜单，没有 Provider 配置选择器。

## Proposed approach

Swift 侧新增 `TranslationAPIProfile`（稳定 UUID、名称、Base URL、模型），SettingsStore 持有有序 profiles 和 active/default ID，凭证通过 profile ID 派生 Keychain account；首次加载无 profiles 时把旧字段迁移成一个默认 profile。CardSession 保存 profile ID/显示名，SessionStore 按当前 profile 构造 FFI endpoint；新增 `changeAPIProfile` 复用源文本和目标语言并生成新的 request ID。设置 UI 使用列表式配置编辑器，保持现有 Warm Minimal/Liquid Glass 视觉和密钥不回显。

## Acceptance criteria

- [x] 设置可以新增、编辑、测试、排序、删除配置并设定默认配置；至少两个配置可同时存在。
- [x] 每个配置的 Key 独立保存在 Keychain，重命名不丢失，删除同步移除。
- [x] 旧单配置首次启动后可见为一个配置且旧 Key 可用；迁移不重复执行。
- [x] 新翻译使用默认配置；结果卡片显示配置短名称并可显式切换。
- [x] 切换会取消旧请求、使用新 request ID，迟到 delta 不得污染新译文；截图切换不重新 OCR。
- [x] `./scripts/check.sh` 通过：Rust 16 tests、Swift 24 tests、Xcode Debug App build、格式/空白和 `git diff --check` 均通过。
- [x] 真实 Debug App 设置与结果卡片截图完成五维 SwiftUI 评审，每维至少 7/10。
- [x] 相关规格、BACKLOG、IDEAS 和 STATUS 已同步。

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

使用真实 Debug App：创建 Qwen 快速和 GPT 高质量两个配置，分别测试连接；从划词、截图和快速输入结果卡片切换配置，确认旧请求停止、译文更新、截图不重新捕获；重启后确认配置和默认项保留但译文历史仍不持久化。

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

- 迁移失败时保留旧字段和旧 Keychain account，不能删除旧凭证；可回滚到单配置读取路径。
- 配置切换扩大卡片状态，必须依赖 request ID 隔离，避免迟到事件污染。
- 设置窗口内容增加可能影响小窗口可用性，保留滚动和最小尺寸。

## Decisions needed

None — 首期全局默认配置、当前卡片手动切换和直接替换译文已由本任务确定。

## Completion record

- Verified commit: Working tree (commit pending)
- Automated evidence: `./scripts/check.sh` — Rust 16 tests and Swift 24 tests passed; Xcode Debug build and source checks passed.
- Manual evidence: `artifacts/ui-review/task-005/settings.png`, `artifacts/ui-review/task-005/card.png`; settings/card review 8/8/8/8/7.
- Documentation updated: `STATUS.md`, `BACKLOG.md`, `IDEAS.md`, this Task.
- Remaining work promoted to: None
