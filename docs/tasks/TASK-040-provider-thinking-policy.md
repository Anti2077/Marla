# TASK-040：翻译 Provider 默认关闭思考

Status: Complete

Owner: Project owner + Agent

Created: 2026-09-02

Updated: 2026-09-04

Origin: direct request

Conversation: 2026-09-02 国产翻译模型接入与思考等级

## Initial request

项目所有者要求新开分支处理翻译请求的思考等级，并确认 Marla 能否检测 Provider 支持的思考等级，或是否应默认关闭思考、降到最低等级。

## Outcome

Marla 的翻译请求将使用显式、可测试的 Provider 思考策略：已知协议在请求体中关闭思考，不需要思考的专用翻译模型不发送多余字段，未知 OpenAI-compatible Provider 保持标准请求而不猜测非标准参数。翻译不会因为默认推理链增加首字延迟或输出额外解释。

## Why now

Marla 正在扩展 Qwen-MT 之外的国产模型候选。DeepSeek、GLM、Qwen 通用模型和火山方舟对“关闭思考”使用不同的非标准字段，而标准 `/models` 响应不声明这些能力；需要先建立 Provider 能力边界，才能安全比较首字延迟和翻译质量。

## In Scope

- 在 Rust Provider 能力中表达翻译请求的思考策略。
- 对已由官方协议确认的 Provider/模型组合显式关闭思考。
- Qwen-MT 和其他无需思考扩展字段的翻译专用模型保持其原请求合同。
- 未识别的 OpenAI-compatible Provider 不发送厂商私有思考字段。
- 为每种请求体策略增加聚焦回归测试。
- 同步数据合同、架构说明、本 Task 和 `STATUS.md`。

## Out of Scope

- 增加思考等级设置 UI 或让用户维护厂商参数枚举。
- 通过额外生成请求试探 Provider 能力。
- 使用、读取或保存任何真实 API Key。
- 运行真实付费 API 基准或更改默认翻译 Provider。
- 修改官网、TASK-036、模型选择菜单或发布版本。
- 接入本地模型运行时。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-09-02 | Project owner | 新开分支处理思考等级，评估检测或默认关闭策略 | 需要建立无付费探测的能力策略并验证实际请求 JSON | Complete |
| 2026-09-04 | Project owner | 提交全部现有改动并推送全部本地分支 | 授权提交并发布本 Task 的已验证实现；不改变功能范围或验收结论 | Complete |

## Current evidence

- Rust `ProviderCapabilities` 现在同时描述消息角色、语言指令、流内容模式和内部思考策略。
- 已确认的 DeepSeek V4、GLM 4.7 和方舟模型组合使用 `thinking: { type: "disabled" }`；已确认的 DashScope Qwen 混合思考组合使用 `enable_thinking: false`。
- Qwen-MT 请求继续使用 User-only、`translation_options` 和累计流规范化，不添加额外思考控制。
- GLM 5.3、方舟翻译专用模型、未知主机、中转和自托管端点省略厂商私有字段。
- 标准 OpenAI `/models` 响应只保证模型标识等基础信息，不提供跨厂商统一的思考模式或等级能力声明。

## Proposed approach

思考控制已实现为 Rust 内部 Provider capability，而不是 Swift/FFI 用户选项。策略解析同时检查端点主机和有边界的模型系列，避免仅凭常见模型前缀向任意代理端点发送厂商私有字段。请求构造只为已确认组合添加关闭思考的字段；其余组合省略该字段。这个扩展落实 ADR-0009 已接受的 Provider capability 方向，不创建新的产品或架构决策。

## Acceptance criteria

- [x] 已知支持关闭思考的 Provider 请求体发送其官方关闭值。
- [x] Qwen-MT 请求体不新增无效思考字段。
- [x] 未识别 Provider 只发送标准 OpenAI-compatible 字段。
- [x] 思考策略不改变现有消息角色、语言指令和流内容规范化。
- [x] 聚焦 Rust 测试与 `./scripts/check.sh` 通过。
- [x] 新增代码未使任何源文件超过结构门禁。
- [x] 数据合同、架构说明和 `STATUS.md` 与实现一致。

## Verification

### Automated

```sh
cargo test --manifest-path rust/marla-core/Cargo.toml thinking
./scripts/check.sh
```

### Manual

检查测试捕获的请求 JSON，确认已知 Provider 的关闭字段和未知 Provider 的省略行为。本 Task 不使用真实凭据或产生付费请求。

## Required Reading

- `docs/development/STATUS.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/DATA_CONTRACTS.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `docs/architecture/decisions/ADR-0009-semantic-markdown-translation-contract.md`
- `docs/tasks/TASK-028-structured-translation-foundation.md`
- `rust/marla-core/src/lib.rs`
- `Sources/MarlaCore/TranslationModels.swift`
- `Tests/MarlaCoreTests/MarlaCoreTests.swift`

## Parallel contributors (optional)

None.

## Risks and rollback

- 厂商私有字段若下发到不兼容的代理端点可能导致 HTTP 400；通过主机与模型双重匹配并对未知端点省略字段控制。
- 厂商未来可能修改参数名称或默认行为；能力映射集中在 Rust 并由请求体测试覆盖，可独立回退。
- 回滚时移除思考 capability 和对应请求字段即可恢复当前标准请求体。

## Decisions needed

None.

## Completion record

- Verified commit: 项目所有者已于 2026-09-04 授权提交并推送本分支；最终提交哈希由 Git 提交记录确定。
- Automated evidence: `cargo test --manifest-path rust/marla-core/Cargo.toml thinking` 2/2 通过；`./scripts/check.sh` 全绿，包含 26 项 Rust、全部 Swift Package 测试、Rust/Swift build、Xcode Debug、严格 Clippy、结构门禁、shell 语法、源码空白与 `git diff --check`。
- Manual evidence: 聚焦请求 JSON 断言确认 DeepSeek V4、GLM 4.7、方舟支持模型和 DashScope Qwen 使用各自关闭字段；GLM 5.3、方舟翻译专用模型、Qwen-MT 与未知端点均省略厂商私有字段。没有使用真实凭据或付费请求。
- Documentation updated: `ARCHITECTURE.md`、`DATA_CONTRACTS.md`、本 Task 与 `STATUS.md` 已同步。
- Remaining work promoted to: None。真实 Provider 延迟/质量基准仍需项目所有者另行授权并自行提供凭据，不是本 Task 的遗留验收项。
- Scope changes closed: Yes。
- Parallel contributions integrated: None。
