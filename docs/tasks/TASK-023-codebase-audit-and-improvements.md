# TASK-023：整体代码审查与高置信改进

Status: Done

Owner: Project owner + Agent

Created: 2026-08-12

Updated: 2026-08-12

Origin: direct project-owner request

Conversation: 2026-08-12 整体代码审查与优化

## Initial request

项目所有者要求新建分支，审查整体代码是否有可优化空间，并进行改进。

## Outcome

在独立分支上完成一次覆盖 Swift、Rust、构建脚本和测试的证据驱动审查，实施不会改变既有产品行为且能够由自动化验证的高置信改进，并明确记录未实施候选及原因。

## Why now

TASK-022 已收束，当前没有 Active Task；现有实现已经跨越原生 macOS 表现层、嵌入式 Rust 核心、FFI 与构建脚本，适合在继续发布验收前检查可靠性、性能、可维护性和测试盲点。

## In Scope

- 审查当前 Swift、Rust、FFI、构建/验证脚本和测试中的重复工作、无效状态、错误处理、资源生命周期、并发安全、性能热点和可维护性风险。
- 只实施高置信、范围有限、保持现有产品合同且能以测试或静态验证证明的改进。
- 为修复的问题增加或调整针对性回归测试。
- 同步本 Task 与 `docs/development/STATUS.md` 的当前事实。
- 构建并验证一份包含本轮改进的固定路径 Release 测试 App，供项目所有者现场查看。

## Out of Scope

- 新增用户功能、改变产品流程或扩大 0.1.0 发布范围。
- 未经新 ADR 授权的架构迁移、依赖替换、Provider 变更、持久化行为或隐私边界变化。
- UI 重设计、视觉风格调整或仅凭偏好进行的大规模重构。
- 处理需要真实应用矩阵或产品所有者现场确认的既有发布验收缺口。
- 仅为追求抽象、行数减少或理论性能而进行、缺少可观察收益的改写。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-12 | Project owner | 新建分支并审查整体代码，实施可验证优化 | 建立独立分支；全库盘点后只落地高置信改进；运行完整验证 | Verified |
| 2026-08-12 | Project owner | 构建一份测试 App 供现场查看 | 运行固定路径 Release 打包，验证 Bundle、架构与稳定签名后交付 `artifacts/Marla_dev.app` | Verified |

## Current evidence

- 开始时 `main` 与 `origin/main` 对齐且工作区干净；已创建并切换到 `codex/task-023-codebase-audit`。
- `STATUS.md` 在本 Task 创建前显示没有 Active Task；TASK-013 与 TASK-016 仍因外部现场确认而 Blocked，不属于本轮修复范围。
- 审查覆盖 6 个 MarlaApp Swift 文件、7 个 MarlaCore Swift 文件、C Header/桥、1,800 余行 Rust 核心、2,400 余行 Swift 测试和 3 个 shell 脚本；通过 Serena 检查关键符号、引用、诊断和 FFI/会话生命周期，再以 `rg` 检查不安全操作、监听器、异步任务和显式崩溃点。
- Swift 会话的 request ID 隔离、MainActor 回调、句柄 cancel/release，截图监听器清理、Copy fallback 完整恢复，以及 Keychain 启动期缓存已有针对性测试和明确所有权。本轮没有发现值得冒行为回归风险的 Swift 改写；文件拆分等纯结构整理未达到“可观察风险 + 可验证收益”的实施门槛。
- Rust 取消路径原先由每个等待中的翻译或模型列表请求每 10ms 轮询一次 `AtomicBool`；现改为 `AtomicBool + tokio::sync::Notify` 的持久事件信号，取消立即唤醒且不再周期空转。
- SSE 解码器原先可在 Provider 永不结束单帧时无限累计 `buffered_bytes`/`data_lines`；现把整个未完成帧限制为 1 MiB，超限按既有 `invalid_response` 路径失败。
- 严格 `cargo clippy --workspace --all-targets -- -D warnings` 最初发现 5 个公开 unsafe FFI 函数缺少 `# Safety` 合同；合同已补齐，Clippy 与全部 shell 脚本语法现进入统一检查。
- 实施规格中请求 schema 标题误写为 v1，而示例和实际合同均为 v2；中英文标题已同步修正。

## Proposed approach

先将产品、版本合同、架构、Accepted ADR 与当前代码/测试对照，再从编译器诊断、测试结构、资源和并发边界、热点路径及脚本健壮性五个方向形成候选清单。每个候选必须说明实际风险、最小修改面和验证方式；只实施满足本 Task 边界的项目。完成后运行全量检查并复核整个差异。

## Acceptance criteria

- [x] 审查覆盖 Swift 应用层、Swift 核心模型、Rust 核心、FFI 边界、测试及项目脚本，并记录有代码证据的结论。
- [x] 至少实施一项可证明的可靠性、性能或可维护性改进；若没有安全候选，则以审查证据说明不修改代码的原因并由项目所有者决定是否收束。
- [x] 每项代码行为修复都有针对性回归测试，或明确说明为何只能由静态/集成检查验证。
- [x] 不改变既有用户流程、数据合同、隐私边界和 Accepted ADR；若审查发现冲突，先记录并停止相关实施。
- [x] `./scripts/check.sh` 与 `git diff --check` 通过。
- [x] Task 和 `STATUS.md` 与最终验证事实同步，未实施候选不会被误写为已授权 Backlog。
- [x] `artifacts/Marla_dev.app` 已由规定脚本安全替换，并通过 Bundle ID、版本、最低系统、arm64、可执行文件、稳定签名和 designated requirement 验证。

## Verification

### Automated

```sh
./scripts/check.sh
```

2026-08-12 通过：严格 Rust formatting/Clippy、20 项 Rust 测试、Rust build、3 个 shell 脚本的 `zsh -n`、84 项 MarlaApp 测试（3 项 Vision 图形服务限制 skip）、13 项 MarlaCore 测试、Swift Package build/test、Xcode Debug App build、尾随空白和 `git diff --check`。

### Manual

本轮没有改变 UI、正常 Provider 协议或用户流程。事件驱动取消由异步唤醒回归覆盖，SSE 上限由完整/超限帧边界回归覆盖。项目所有者随后要求构建固定 Release 测试 App；打包验证完成后由其进行现场查看。

`./scripts/build-test-app.sh` 于 2026-08-12 成功重建并安全替换 `artifacts/Marla_dev.app`。最终产物验证为 Bundle ID `com.marla.app`、版本 `0.1.0`、最低 macOS `14.0`、`arm64`，稳定签名 Authority 为 `API Usage Monitor Dev`，designated requirement 继续绑定既有证书根哈希。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/DATA_CONTRACTS.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0002-ocr-strategy.md`
- `docs/architecture/decisions/ADR-0003-context-engine.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `docs/architecture/decisions/ADR-0005-vision-only-ocr-for-0.1.0.md`
- `docs/architecture/decisions/ADR-0006-selection-copy-compatibility.md`
- `Package.swift`
- `Sources/`
- `rust/marla-core/src/`
- `Tests/`
- `scripts/`

## Parallel contributors (optional)

None. 本轮代码审查需要由同一 Agent 统一判断跨 Swift/Rust/FFI 的范围与修改优先级；文档变更较小且与最终证据紧密耦合。

## Risks and rollback

- 全库审查容易演变为无边界重构；以“现有实际风险 + 最小差异 + 可验证收益”作为实施门槛。
- 内部优化可能意外改变时序或错误语义；保留现有合同测试并为相关边界增加回归。
- 每项实现保持独立、可由 Git 差异逐项回退；不进行数据迁移或破坏性操作。

## Decisions needed

None。若唯一合理候选需要改变产品或架构合同，将先向项目所有者请求决定。

## Completion record

- Verified commit: `a131956` on `codex/task-023-codebase-audit`, merged into local `main` by merge commit `be19ca8`
- Automated evidence: `./scripts/check.sh` passed 20 Rust and 97 Swift tests, strict Clippy, Rust/Swift/Xcode builds, shell syntax, whitespace and diff checks
- Manual evidence: Fixed Release `artifacts/Marla_dev.app` delivered for project-owner inspection
- Documentation updated: Task, STATUS, and bilingual 0.1.0 implementation contract
- Remaining work promoted to: None; existing release gaps remain unchanged
- Scope changes closed: Yes, including fixed Release test-App delivery
- Parallel contributions integrated: None
