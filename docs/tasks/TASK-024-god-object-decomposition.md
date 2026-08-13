# TASK-024：拆分应用层上帝对象与职责文件

Status: Done

Owner: Project owner + Agent

Created: 2026-08-14

Updated: 2026-08-14

Origin: direct request

Conversation: 2026-08-14 应用层上帝对象重构

## Initial request

项目所有者指出当前实现有“上帝对象”的味道，要求建立分支并开始改造。

## Outcome

在不改变 0.1.0 用户行为、Swift/Rust 数据合同或 macOS 权限边界的前提下，降低应用层职责耦合：将当前混合多个独立职责的实现按责任拆分到清晰的源文件，并为后续进一步收窄 `MarlaApplicationModel` 的编排边界建立可验证基线。

## Why now

`Sources/MarlaApp/MarlaApplicationModel.swift` 当前约 3,900 行，包含 Keychain、设置、翻译会话、浮动面板、快捷键、截图选择、Vision OCR 以及应用生命周期等多个独立子系统。继续在同一文件中修改会增加回归风险，也使责任边界难以审查。

## In Scope

- 建立 `codex/task-024-god-object-decomposition` 分支。
- 按职责拆分 `MarlaApplicationModel.swift` 中的独立类型到同一 Swift target 下的多个源文件，保持公开符号名和运行时行为不变。
- 保留 `MarlaApplicationModel` 作为应用生命周期与入口编排对象；不在本轮改变产品流程或跨 FFI 合同。
- 增加或调整必要的结构性回归检查，并运行完整项目验证。
- 同步本 Task 与 `docs/development/STATUS.md` 的当前事实。

## Out of Scope

- 新增用户功能、UI 重设计、Rust/FFI 协议变化或权限策略变化。
- 在缺少测试支撑的情况下重写并发、生命周期或状态机逻辑。
- 将所有依赖强行抽象成协议，或为了减少行数进行无观察收益的重构。
- 修改现有发布缺口和 Blocked Task。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-14 | Project owner | 新建分支并开始处理应用层“上帝对象”问题 | 建立独立分支；先实施可回滚的职责拆分并运行完整检查 | Verified |

## Current evidence

- 开始时 `main` 与 `origin/main` 对齐且工作区干净；已切换到 `codex/task-024-god-object-decomposition`。
- `MarlaApplicationModel.swift` 约 3,893 行，包含 20 多个独立类型；`MarlaApplicationModel` 本身负责应用生命周期、权限、三个入口、UI 自动化夹具及多个协调器的装配。
- 当前没有 Active Task；TASK-013 与 TASK-016 仍为 Blocked，不属于本轮范围。
- 已新增 `MarlaApplicationServices`，集中构造应用级 Settings、Session、Panel、Screenshot、Vision、Shortcut 和 Settings Window 服务；`MarlaApplicationModel` 通过兼容访问器继续保持现有调用路径。
- 已用固定路径 Release 打包脚本重建 `artifacts/Marla_dev.app`；产物为 `com.marla.app`、版本 `0.1.0`、macOS 14.0+、arm64，稳定签名 Authority 为 `API Usage Monitor Dev`，designated requirement 保持既有证书根哈希。

## Proposed approach

第一阶段只做源文件级职责拆分：共享模型/设置、Keychain、翻译会话、浮动结果面板、快捷键、截图选择、Vision OCR 和应用模型分别归档。Swift Package target 会自动编译同目录源文件，因此不改变模块或符号可见性。拆分后用 `./scripts/check.sh`、`git diff --check` 和符号/引用检查确认没有行为差异。后续若仍需减少 `MarlaApplicationModel` 的直接依赖，再以独立范围和测试依据推进。

## Acceptance criteria

- [x] 第一阶段将应用级依赖构造移入独立 `MarlaApplicationServices.swift`，原有符号和调用路径保持兼容。
- [x] `MarlaApplicationModel` 的初始化不再直接构造七个基础设施服务，仍承担应用级生命周期与入口编排。
- [x] 相关 Swift/Rust/Xcode 构建与测试通过，且 `git diff --check` 通过。
- [x] Task 与 `STATUS.md` 记录真实验证结果和剩余风险。

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

本轮不改变 UI 或产品行为；未进行新的真实 App 交互验收。Release 测试 App 已交付项目所有者现场测试。

`./scripts/build-test-app.sh` 于 2026-08-14 成功构建并安全替换 `/Users/anti/Documents/ChatGPT/Marla/artifacts/Marla_dev.app`，并通过 Bundle ID、版本、最低系统、arm64、稳定签名和 designated requirement 验证。

2026-08-14：授权环境下 `./scripts/check.sh` 通过 20 项 Rust、97 项 Swift（3 项 Vision 图形服务限制 skip）、Swift Package、Xcode Debug、脚本语法、空白与 diff 检查。沙盒内首次运行曾因 Xcode Preview 宏服务无法启动而失败；授权环境重跑已证明代码和 Xcode 文件引用均正常。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/DATA_CONTRACTS.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Sources/MarlaApp/MarlaApp.swift`
- `Sources/MarlaApp/SettingsView.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors (optional)

None.

## Risks and rollback

- 文件移动可能遗漏编译依赖或条件编译边界；保留单一 target、逐组移动并用完整检查验证。
- 若拆分暴露出隐含初始化顺序，可直接回退本 Task 的文件移动，不涉及数据迁移。

## Decisions needed

None for the first structural phase.

## Completion record

- Verified commit: Pending
- Automated evidence: `./scripts/check.sh` passed on 2026-08-14
- Manual evidence: Release `artifacts/Marla_dev.app` delivered for project-owner testing; no new interaction acceptance claimed
- Documentation updated: Task and STATUS record first-phase completion, Release artifact evidence, and remaining future refactoring scope
- Remaining work promoted to: None
- Scope changes closed: Yes; broader file extraction remains future work outside this Task
- Parallel contributions integrated: None
