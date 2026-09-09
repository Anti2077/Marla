# TASK-044：泛用大模型接口协议适配

Status: Active

Owner: Project owner + Agent

Created: 2026-09-07

Updated: 2026-09-09

Origin: direct request

Conversation: 2026-09-07，深度适配几种通用接入的大模型接口并增加泛用型

## Initial request

项目所有者要求深度适配几种通用接入的大模型接口，增加泛用型接入能力。

## Outcome

Marla 的一个 API profile 可以明确选择协议类型，并由 Rust 核心统一处理协议对应的请求地址、鉴权、请求体、流式事件和模型列表响应。现有 OpenAI-compatible 配置保持兼容，同时新增 OpenAI Responses、Anthropic Messages 和 Google Gemini 的通用接入路径。

## Why now

当前 profile 名义上支持多个 API，但实际请求固定为 OpenAI Chat Completions；只更换 URL 和模型无法覆盖 Anthropic Messages、Gemini Generate Content 或 OpenAI Responses 的消息结构、鉴权头和流式事件。协议差异继续留在模型名推断或 Swift UI 中会扩大误路由和凭据泄露风险。

## In Scope

- 在共享 endpoint 合同中增加向后兼容的协议类型字段。
- 支持以下四种协议：OpenAI-compatible Chat Completions、OpenAI Responses、Anthropic Messages、Google Gemini Generate Content。
- 按协议生成请求地址、请求 JSON、鉴权头和流式解析；保留现有 Qwen-MT 的 OpenAI-compatible 特例。
- 按协议解析可用模型列表；对没有安全标准模型列表语义的情况提供明确失败状态。
- 在 API profile 编辑器中增加协议选择、协议相关地址提示和请求地址预览。
- 保留 Base URL/完整 URL、空 Key 本地端点、请求取消、超时、迟到事件隔离、原位严格 block 校验和现有 Keychain 边界。
- 为所有协议增加 Rust payload/SSE/模型列表回归，为 Swift 增加 profile 编解码和 endpoint 序列化回归。
- 同步架构、数据合同、API 相关规格、`STATUS.md` 与本 Task。

## Out of Scope

- 厂商专属参数面板、工具调用、图片输入、音频输入、批量请求、自动 fallback 或多模型并发。
- 自动探测协议、根据模型名猜测协议、自动改写用户填写的完整 URL。
- 代理转售、统一账号、Marla 服务端、API Key 明文日志或真实凭据代填。
- 声称已通过每个云厂商的真实账号/配额/区域验收；真实凭据验收仍需项目所有者自行执行。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-09-07 | Project owner | 从单一 OpenAI-compatible Chat Completions 扩展为四种通用协议 | 增加协议选择、协议级 URL/鉴权/JSON/SSE/模型列表回归；保留旧配置默认行为 | Closed |

## Current evidence

- `TranslationEndpointConfiguration` 现在包含显式 `providerProtocol`，旧 profile 与旧 endpoint JSON 缺少该字段时恢复为 OpenAI-compatible。
- Rust `request_json`、`endpoint_url`、`model_list_url` 和 `SseDecoder` 已按四种协议分派；Qwen-MT 的 User-only、`translation_options` 和累计流只在显式 OpenAI-compatible 下启用。
- Swift profile 编辑器已提供协议 Picker、协议相关 URL placeholder、请求地址预览、模型获取和连接测试传递；凭据仍由既有 Keychain/进程内边界处理。
- Rust 36 项测试、宿主环境 `./scripts/check.sh`、固定 Release `./scripts/build-test-app.sh` 均已通过；Responses 失败/未知事件、Anthropic `message_delta`、空 Key 版本头和版本段归一化已补充回归。
- 当前实现已由项目所有者授权合并到本地 `main`；本地 `main` 仍领先 `origin/main`，真实云端凭据与独立 UI 验收继续保留为 owner acceptance gap。

## Proposed approach

新增 `TranslationProviderProtocol` 并把它放入 `TranslationEndpointConfiguration`，默认值为 `.openAICompatible`。Rust 先按显式协议选择 URL、请求构造、鉴权和模型列表解析，再把各协议的流式帧归一化为现有 `started/delta/completed/failed/cancelled` 事件。只有 OpenAI-compatible 协议进入模型名前缀 capability 分支；其它协议使用各自通用消息策略。Swift 只持久化非敏感协议选择并在编辑器中提供原生 Picker；旧 profile 缺少字段时按 OpenAI-compatible 恢复。

协议边界如下：OpenAI-compatible 使用 `/chat/completions` 与 Bearer；OpenAI Responses 使用 `/responses` 与 Bearer；Anthropic 使用 `/v1/messages`、`x-api-key` 与固定版本头；Gemini 使用 `/{version}/models/{model}:streamGenerateContent`、`x-goog-api-key` 与 SSE。完整 URL 模式严格使用用户填写的请求地址，但不会阻止协议所需的鉴权头和 body 适配。

## Acceptance criteria

- [x] 旧 profile JSON 缺少协议字段时解码为 OpenAI-compatible，现有请求 payload 不发生变化。
- [x] 四种协议均能生成经过校验的 URL、请求体和鉴权头；空 Key 仍允许协议请求发出。
- [x] 四种协议的增量/累计/事件型流都能归一化为现有 Swift 事件；Provider 错误、空结果、异常结束和取消仍有明确结果。
- [x] OpenAI-compatible Qwen-MT 的 User-only、`translation_options` 和累计流行为不回归；其它协议不误套用 Qwen 特例。
- [x] 模型列表可按协议读取支持的标准响应；无法安全推导或解析时返回明确错误，不伪造模型。
- [x] API profile 编辑器可以选择协议，已有 Base/完整 URL 语义、保存并测试、模型获取和 Keychain 行为保持一致。
- [x] 原位翻译的完整 block、ID、保护负载和过期请求校验不因协议扩展放宽。
- [x] Rust 与 Swift 定向测试通过，未新增明文凭据、用户内容或完整 Provider 响应日志。
- [x] `./scripts/check.sh`、结构门禁、`git diff --check` 和固定 Release 构建验证通过。
- [x] 架构、数据合同、API 规格和 `STATUS.md` 与实际实现同步；真实云端凭据验收缺口单独标记。

## Verification

### Automated

```sh
./scripts/check.sh
./scripts/build-test-app.sh
```

2026-09-07 宿主环境结果：Rust `cargo test` 36 项通过；`./scripts/check.sh` 全部通过，包含 Rust 格式/Clippy、Swift Package 与 Xcode Debug 构建、Swift 全量测试、结构门禁、脚本语法、空白检查和 `git diff --check`；`./scripts/build-test-app.sh` 成功重建并验证固定 Release `artifacts/Marla_dev.app`，Bundle ID 为 `com.marla.app`、版本为 `0.0.0`、最低系统为 macOS 14.0、架构为 arm64，稳定签名为 `API Usage Monitor Dev`，designated requirement 验证通过。补充回归覆盖 Responses `response.failed`、Anthropic `message_delta` 不提前完成、空 Key 版本头和 `/v1`/`/v1beta` 路径归一化。

### Manual

使用固定 `artifacts/Marla_dev.app`，分别配置脱敏的四类协议端点或本地 mock，检查协议选择、请求地址预览、模型列表、连接测试、取消和普通翻译结果。自动化 mock 与离线协议回归已完成；真实 OpenAI-compatible、OpenAI Responses、Anthropic Messages、Google Gemini 账号/配额/区域验收仍为 `Pending owner acceptance`。独立 TASK-044 SwiftUI 五维截图复审也仍为 `Pending owner acceptance`。真实 Key 由项目所有者自行输入；证据只记录协议、状态和脱敏时延，不记录 Key、Header、源文、译文或完整响应。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/development/VERSIONING.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/DATA_CONTRACTS.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `Sources/MarlaCore/TranslationModels.swift`
- `Sources/MarlaApp/Models/TranslationAPIProfile.swift`
- `Sources/MarlaApp/Persistence/MarlaSettingsStore.swift`
- `Sources/MarlaApp/Settings/SettingsEditor.swift`
- `Sources/MarlaCore/RustCoreBridge.swift`
- `rust/marla-core/src/lib.rs`
- `Tests/MarlaAppTests/MarlaAppTests.swift`
- `Tests/MarlaCoreTests/MarlaCoreTests.swift`

## Parallel contributors (optional)

None; protocol construction, shared JSON contract and UI persistence are tightly coupled and have one write owner in this Task.

## Risks and rollback

- 新增字段或协议分支可能破坏旧 profile；通过显式默认值、旧 JSON 解码回归和默认 payload 断言降低风险。
- 不同 Provider 的流式事件可能出现无文本事件、事件名与 data 不一致或非 SSE 结束；统一解析器必须对未知事件安全忽略，对空/断流明确失败。
- Gemini 与 Anthropic 的模型列表/URL 约定可能因代理而不同；完整 URL 保留高级用户控制，不能把推导失败伪装成可用。
- 回滚时可保留新字段但将默认 profile 与新协议选择恢复到 OpenAI-compatible，删除协议特有分支即可，不触碰 Keychain vault。

## Decisions needed

None for this bounded compatibility slice. Provider-specific extensions remain future decisions.

## Completion record

- Verified commit: Owner authorized the local `main` merge on 2026-09-09; the merge commit is recorded in local Git history.
- Automated evidence: 2026-09-07 host-run `./scripts/check.sh` and `./scripts/build-test-app.sh` passed; Rust 36 tests passed and fixed Release app validation passed.
- Manual evidence: Protocol-specific local/mock coverage is represented by automated fixtures. Real four-provider credential acceptance and the independent TASK-044 UI five-dimension screenshot review remain pending owner acceptance.
- Documentation updated: `docs/architecture/ARCHITECTURE.md`, `docs/architecture/DATA_CONTRACTS.md`, `docs/features/language-routing.md`, `docs/versions/0.1.0/SPEC.md`, `docs/versions/0.1.0/IMPLEMENTATION.md`, `docs/development/STATUS.md`, and this Task record.
- Remaining work promoted to: None; owner-only cloud and visual acceptance remain as explicit evidence gaps in this Task, not implementation scope.
- Scope changes closed: Yes; the four-protocol compatibility implementation slice is complete within the authorized scope, while Task closure awaits owner-only evidence.
- Parallel contributions integrated: None
