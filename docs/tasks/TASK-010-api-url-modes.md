# TASK-010：API Base URL 与完整 URL 模式

Status: Complete

Owner: Project owner + Agent

Created: 2026-08-07

Updated: 2026-08-07

Origin: direct request / live defect

Conversation: `TASK-005` 多 API 配置与设置、截图交互持续迭代（历史详细切片）

## Initial request

项目所有者要求为 API profile 增加 Base URL 与完整 URL 模式；随后要求把模式 switch 压缩进 URL 行，并在模型字段右侧获取、展开和选择当前地址与 Key 可用的模型。

## Outcome

每个翻译 API 配置可以在 `Base URL` 与 `完整 URL` 两种模式之间切换；前者自动追加 `/chat/completions`，后者严格请求用户填写的完整地址。编辑器还能通过当前地址和 Key 获取 OpenAI-compatible `/models` 列表，避免手工猜测可用模型。

## Why now

项目所有者使用 `https://api.anti2077.xyz:16666` 测试 `gpt-5.6-luna` 时，Marla 请求了 `/chat/completions`，该路径返回管理站 HTML 和 HTTP 200，最终显示“翻译流意外结束”。不同 OpenAI-compatible 服务对 Base URL 的约定不一致，需要显式 URL 语义而不是猜测。

## In Scope

- 为每个 `TranslationAPIProfile` 持久化 URL 模式。
- 旧配置缺少新字段时迁移为 `Base URL`，不丢失 profile ID、Keychain account 或默认配置。
- API 编辑窗口在 URL 输入行的固定标签区增加原生紧凑滑块，左侧 Base、右侧完整，并随模式更新帮助文字和示例。
- 模型选择移动到编辑区最下面，右侧提供获取图标；Rust 根据当前 URL 模式推导 `/models`，返回后展示可折叠选择列表并回填模型名。
- Swift/Rust 请求契约携带模式；Base URL 继续追加 `/chat/completions`，完整 URL 不改写路径。
- 测试连接和真实翻译共用同一 URL 解析规则。
- 增加迁移、URL 解析、请求编码和 UI 状态自动化；同步双语规格与状态文档。
- 用项目所有者提供的端点和 `gpt-5.6-luna` 做真实完整 URL 测试，Key 只用于本轮请求，不写入源码或文档。

## Out of Scope

- 自动探测或轮询多个候选路径。
- Provider 专属路由模板、自动 fallback 或代理重写规则。
- 自定义翻译提示词。
- 改变 Keychain account 或现有多 API 切换语义。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-07 | Project owner | 增加 Base URL/完整 URL 模式 | 旧配置迁移、最终请求地址、测试连接和真实翻译共用解析规则 | Verified |
| 2026-08-07 | Project owner | 模式 switch 改为 URL 行内的 `Base [switch] 完整` | 固定标签列和浅色/深色几何验收 | Verified |
| 2026-08-07 | Project owner | 模型字段移到底部，并通过当前 URL/Key 获取模型列表 | `/models` 推导、C ABI v2、排序去重、展开选择和真实 API 验收 | Verified |

## Current evidence

- `endpoint_url` 当前无条件在配置地址后追加 `/chat/completions`。
- 根地址的 `/chat/completions` 返回 HTTP 200 HTML 管理页，SSE 解码器没有得到完成事件后报告“翻译流意外结束”。
- `TranslationAPIProfile` 当前只保存 `id`、`name`、`baseURL` 和 `modelName`。
- API 编辑窗口当前只有一个固定的 `Base URL` 字段。

## Proposed approach

新增可编码的 `TranslationEndpointURLMode`（`baseURL` / `completeURL`），使用自定义解码为旧 profile 提供 `baseURL` 默认值。Swift FFI 请求把模式编码为稳定字符串；Rust 使用带 serde 默认值的对应字段，集中在 `endpoint_url` 决定是追加标准路径还是保留完整 URL。编辑窗口把 `Base [滑块] 完整` 收进 URL 输入行的固定标签区，不增加独立模式行或新的卡片层级。

## Acceptance criteria

- [x] 旧 API 配置加载后保持可用并默认为 Base URL 模式。
- [x] Base URL 模式继续自动追加 `/chat/completions`。
- [x] 完整 URL 模式严格使用填写地址，不追加或删除路径。
- [x] 两种模式都拒绝非 HTTP(S)、无 host、含 query 或 fragment 的无效地址。
- [x] API 编辑窗口清楚显示当前模式、对应字段名和示例。
- [x] 测试连接与真实翻译使用相同的模式和最终地址。
- [x] 模型名称位于编辑区最下面，获取图标使用当前地址和 Key，并能展开、选择 Rust 返回的可用模型。
- [x] Base URL 的模型地址追加 `/models`；完整 URL 将尾部 `/chat/completions` 替换为 `/models`，无法安全推导时给出明确错误。
- [x] `gpt-5.6-luna` 通过正确完整 URL 返回有效流式译文。
- [x] `./scripts/check.sh` 与 `./scripts/build-test-app.sh` 通过，固定 App 身份不变。
- [x] 真实 App 浅色/深色截图五维评分全部至少 7/10。

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

在固定 `artifacts/Marla_dev.app` 中打开 API 编辑器，分别检查浅色和深色模式下的行内滑块、固定输入宽度、最底部模型字段、获取图标和展开列表。使用完整 URL `https://api.anti2077.xyz:16666/v1/chat/completions` 获取模型列表，确认包含 `gpt-5.6-luna`，再测试连接并翻译 `Hello`；证据保存到 `artifacts/ui-review/task-010/`。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/UI_SPEC.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `Sources/MarlaCore/RustCoreBridge.swift`
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Sources/MarlaApp/SettingsView.swift`
- `rust/marla-core/src/lib.rs`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Risks and rollback

- 新字段若没有兼容解码会让全部旧 profile 数据解码失败；必须用旧 JSON fixture 覆盖。
- URL 模式若只在 UI 生效、未进入 Rust 请求契约，会导致测试连接与真实翻译不一致；两条路径必须共用 endpoint 配置。
- 回滚时可移除完整 URL UI，但保留解码兼容，避免已保存的配置无法加载。

## Decisions needed

None — 项目所有者已明确选择同时支持 Base URL 和完整 URL。

## Completion record

- Verified commit: uncommitted project-owner worktree
- Automated evidence: `./scripts/check.sh` passed with 17 Rust and 41 Swift tests plus Swift/Xcode Debug builds and repository hygiene checks. Coverage includes legacy-profile migration, URL-mode persistence and FFI encoding, Base/Complete endpoint resolution, `/models` derivation, authenticated model-list FFI, sorting/deduplication, and invalid URL rejection.
- Manual evidence: the supplied Complete URL returned HTTP 200 `text/event-stream` for `gpt-5.6-luna`, with content delta “你好”, `finish_reason: stop`, and `[DONE]`. Its `/v1/models` endpoint returned 20 model IDs and included `gpt-5.6-luna`; the credential was neither printed nor persisted. The stable Release `artifacts/Marla_dev.app` produced light/dark inline-slider and expanded-model-list captures under `artifacts/ui-review/task-010/`, scoring 8/8/8/8/7 in the five-dimension review. Computer Use could not enumerate this LSUIElement app, so the exact on-screen Marla window IDs were captured after verifying the sole fixed Release process rather than treating the AX timeout as evidence.
- Documentation updated: Task, Backlog, Status, architecture, bilingual specification, UI specification, acceptance record, and C ABI version contract.
- Remaining work promoted to: None; automatic endpoint probing, provider-specific model routes, and fallback remain explicitly out of scope.
- Scope changes closed: Yes
