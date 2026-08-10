# TASK-022：建立并行工作树文档流程

Status: Ready for integration

Implementation: Documentation workflow complete in feature worktree

Owner: Project owner + Agent

Created: 2026-08-10

Updated: 2026-08-10

Origin: direct request / workflow defect

Conversation: 2026-08-10 多分支并行时的 Task 与文档状态管理

## Execution context

- Worktree: `/private/tmp/marla-parallel-docs`
- Branch: `codex/parallel-worktree-docs`
- Base commit: `b26e734a12edafed769da0c1401945beb1fedbca`
- Integration target: `main`
- Integration status: Unmerged
- Depends on: None
- Owned paths: `.gitignore`、`AGENTS.md`、`scripts/check.sh`、本文列出的工作流文档
- Known overlaps: 主工作树正在用未提交的 TASK-020 修改 `docs/development/STATUS.md`；整合时必须人工协调，禁止覆盖其新事实

## Initial request

项目所有者确认采用新的文档管理方式：长期文档继续由 Git 管理；移除 `STATUS.md` 作为全仓唯一 Active Task 槽位的职责；每个独立工作树使用不提交的本地状态指向自己的 Task，从而允许多个分支和 Agent 并行施工。

## Outcome

每个开发对话仍有一个受 Git 管理的 Task，每个工作树通常只有一个写入型 Task，但整个仓库可以同时存在多个隔离工作树任务。`STATUS.md` 只描述目标分支已集成、已验证的产品基线；Agent 通过 `.marla/worktree-state.md` 找到当前工作树的 Task，并在合并阶段由整合负责人串行更新全局状态。

## Why now

当前流程已经允许独立工作树并行，却仍要求所有 Task 把自己写进 `STATUS.md` 的单一 Active Task 字段。实际并行中，功能分支会争写 Status、互相清除任务状态，并把未提交工作误写成主线事实。主工作树当前还有 TASK-020 的未提交实现，正好证明“主线事实”和“工作树瞬时进度”必须分离。

## In Scope

- 重写根 `AGENTS.md` 的启动顺序、工作树授权、Status 所有权、子 Agent 边界和真相优先级。
- 将 `STATUS.md` 改成只描述当前分支已经集成并验证的基线，不再保存全仓 Active Task 指针。
- 增加被精确忽略的 `.marla/worktree-state.md` 约定和受 Git 管理的模板。
- 更新 Workflow、Task 指南和 Task 模板，增加执行上下文、路径所有权、`Ready for integration` 和整合记录。
- 更新文档入口、Backlog 提升规则、Roadmap 和 Release 说明，消除单一 Active Task 假设。
- 明确 Task ID 由主线协调者在并行工作开始前集中分配或预留。
- 在统一检查脚本中验证本地状态确实被忽略且没有被 Git 跟踪。
- 使用两个只读子 Agent 审查规则覆盖和本地状态安全，由主 Agent 统一写入、整合和验证。

## Out of Scope

- 修改 Marla 产品功能、Swift/Rust 代码、发布范围/验收，或 TASK-020 的实现与证据；0.1.0 IMPLEMENTATION 只同步工作流措辞。
- 自动创建、删除或强制接管其它工作树。
- 引入 GitHub Projects、外部数据库或常驻协调服务。
- 迁移所有历史 Task 的旧状态词或补写历史工作树元数据。
- 在主工作树存在未提交 TASK-020 改动时直接合并或覆盖 `main`。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-10 | Project owner | 采用“Git 管长期文档、每工作树本地状态、Status 只管主线事实”的并行模式 | 建立独立分支、工作树元数据和全套规则同步 | Verified in worktree |
| 2026-08-10 | Repository evidence | 主工作树切回 `main` 后出现 TASK-020 未提交代码/规格/Status，而本工作树保持独立 | 本 Task 使用独立工作树，禁止修改或覆盖 TASK-020；整合前必须协调 Status | Recorded |
| 2026-08-10 | Concurrent worktree evidence | 本分支最初分配 TASK-021 后，主工作树并行创建了另一个 TASK-021 | 不修改对方文件；本 Task 改用 TASK-022，并把集中预留从建议提升为明确规则 | Resolved |

## Current evidence

- 旧 `AGENTS.md`、Workflow、Backlog 和文档入口都要求从 `STATUS.md` 找到或设置唯一 Active Task。
- 旧规则同时允许独立工作树并行，形成制度冲突：多个工作树都要修改同一个 tracked Status。
- 主工作树当前位于 `main`，HEAD 为 `b26e734`，另有未提交 TASK-020 代码、测试和双语规格；本 Task 位于独立的 `codex/parallel-worktree-docs` 工作树。
- 本分支最初按可见目录分配 TASK-021；施工期间主工作树并行创建了另一份 TASK-021，证明“各工作树自行选择下一编号”会真实冲突。本分支未触碰对方文件并改用 TASK-022。
- 基线 `STATUS.md` 已包含 TASK-019 的实现事实，但 `Implementation baseline commit` 仍写旧的 `27203b5`，且把 TASK-019 描述为未提交分支工作。
- `.gitignore` 尚未保护工作树本地状态；共享 `.git/info/exclude` 可作为旧分支迁移防线，但不能替代新克隆中的 tracked ignore 规则。
- 两个只读子 Agent 分别完成了规则引用审查和本地状态安全审查，没有写入文件或改变范围。

## Proposed approach

采用四层模型：一次开发对话对应一个 Task；一个工作树通常对应一个写入型 Task；仓库可有多个显式隔离的工作树 Task；`STATUS.md` 只描述目标分支已集成事实。`.marla/worktree-state.md` 仅保存当前工作树、分支、Task、负责人、写入所有权和交接提示，任何永久信息都回写 tracked Task。功能工作树完成后先进入 `Ready for integration`；整合负责人合并、处理冲突、更新 Status 并验证目标分支后，Task 才进入 `Done`。

## Acceptance criteria

- [x] `STATUS.md` 不再包含全仓 Active Task 槽位，并明确只记录当前分支已集成、已验证事实。
- [x] Agent 启动顺序能从本地状态确定当前工作树 Task；本地状态缺失、错分支和脏工作树恢复规则明确。
- [x] 一个工作树通常一个写入型 Task，但多个独立工作树可以并行，且不会互相清除任务状态。
- [x] Task 模板包含分支、工作树、基线、整合目标、路径所有权、重叠项、工作树验证和整合验证。
- [x] Task 生命周期包含 `Ready for integration`，且只有进入目标分支并完成整合验证后才能标记 `Done`。
- [x] Task ID 在并行工作开始前由协调者集中分配或预留，避免两个分支选择同一编号。
- [x] `.marla/worktree-state.md` 被精确忽略，有受 Git 管理的模板，且不得成为永久事实或敏感数据的唯一来源。
- [x] `./scripts/check.sh` 能拒绝本地状态未被忽略或已被 Git 跟踪的仓库。
- [x] 文档入口、Workflow、Task 指南、Backlog、Roadmap、Release 说明和 `AGENTS.md` 对职责边界表述一致。
- [x] 静态搜索不再发现把 `STATUS.md` 当作全仓 Active Task 注册表的现行规则；历史 Task 记录不做追溯改写。
- [x] `git diff --check` 和适用的文档检查通过；不修改 TASK-020 或产品代码。

## Verification

### Automated

```sh
./scripts/check.sh
```

本 Task 只修改文档与检查脚本；若完整 Swift/Xcode 构建耗时不成比例，至少运行本地状态不变量、静态规则搜索、shell 语法检查和 `git diff --check`，并如实记录边界。

### Manual

用两个工作树推演：A、B 获得不同 Task ID 和独立本地状态；两者都不通过 Status 注册任务；A 进入 Ready for integration 不影响 B；整合 A 后由整合负责人更新 Status；B 合并前检查新基线和重叠路径。

## Required Reading

- `AGENTS.md`
- `docs/README.md`
- `docs/development/STATUS.md`
- `docs/development/WORKFLOW.md`
- `docs/development/ROADMAP.md`
- `docs/tasks/README.md`
- `docs/tasks/TASK_TEMPLATE.md`
- `docs/backlog/BACKLOG.md`
- `docs/releases/README.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `.gitignore`
- `scripts/check.sh`
- `docs/tasks/TASK-012-conversation-scoped-tasks.md`

## Parallel contributors

| Contributor | Objective | Required Reading | Write ownership | Permission | Output / status |
| --- | --- | --- | --- | --- | --- |
| `doc_parallel_review` | 审查所有“Status 唯一 Active Task”依赖和逐文件改写范围 | AGENTS、Status、Workflow、Task docs、README、Backlog、Roadmap | None | Read-only | 已交付证据与验收建议 |
| `doc_parallel_safety` | 审查本地状态格式、忽略规则、恢复和误提交风险 | AGENTS、Status、Workflow、Task docs、`.gitignore` | None | Read-only | 已交付模板与安全不变量 |

## Parallel worktree coordination

- Task ID `TASK-022` 在发现主工作树已并行占用 TASK-021 后重新分配；整合负责人必须在后续并行工作开始前集中预留编号。
- 本工作树拥有本 Task `In Scope` 列出的规则文件；主工作树继续独占 TASK-020 的代码、测试、双语规格和未提交 Status 新事实。
- 合并前必须先提交或另行保存 TASK-020，并以内容合并 Status，不能用本分支版本覆盖主工作树。

## Risks and rollback

- 被忽略的本地状态可能在分支切换后残留；启动时必须校验路径和分支。
- Git ignore 可被 `git add -f` 绕过；检查脚本同时验证未被跟踪。
- Task ID 连续编号在并发分配时会冲突；必须由协调者集中预留。
- 全局规格仍可能发生内容冲突；本地状态只协调所有权，不替代合并审查。
- 回滚时可恢复旧规则并删除本地状态约定，但 Git 管理的 Task 和历史记录不受影响。

## Decisions needed

None. 项目所有者已确认采用本方案；未来若需要跨机器实时任务看板，再作为独立工作评估外部协调服务。

## Completion record

- Worktree verified commit: Pending commit; verified changes are in `codex/parallel-worktree-docs`
- Integration commit: Pending
- Integration verification: Pending
- Automated evidence: `./scripts/check.sh` passed outside the restricted sandbox: 17 Rust tests, 81 Swift tests, Swift build/test, Xcode Debug build, formatting, local-state invariants, source whitespace, and `git diff --check`. The first sandboxed run failed only because five mock-provider tests could not bind a local port (`Operation not permitted`); the authorized rerun passed.
- Manual evidence: Two real isolated worktrees were inspected: the main worktree retained dirty TASK-020/TASK-021 ownership while this branch moved its colliding ID to TASK-022 and kept its own ignored state. The observed duplicate TASK-021 allocation directly validates the centralized-ID rule. Static searches found no remaining current rule that uses `STATUS.md` as the repository-wide Active Task slot; historical Task records were intentionally left unchanged.
- Documentation updated: `.gitignore`, `AGENTS.md`, docs entry, Workflow, Status semantics, Roadmap, Backlog promotion, Task guide/template, worktree-state template, release guidance, and bilingual 0.1.0 implementation-phase wording; `scripts/check.sh` now enforces the local-state boundary.
- Mainline documentation updated by: Pending integration owner
- Remaining work promoted to: None
- Scope changes closed: Yes in worktree; integration remains pending
- Parallel contributions integrated: Both read-only reviews were reconciled into the final rules, recovery behavior, Task lifecycle, and validation checks
