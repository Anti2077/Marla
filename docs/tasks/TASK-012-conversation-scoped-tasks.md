# TASK-012：开发对话与可演进 Task 工作流

Status: Complete

Owner: Project owner + Agent

Created: 2026-08-07

Updated: 2026-08-07

Origin: direct request

Conversation: 将每次开发对话作为一个可持续追加范围的 Task

## Initial request

项目所有者要求改进现有单任务流程：一次开发对话对应一个 Task；在同一对话的开发过程中，用户可能继续追加功能、交互和修复，这些内容应继续进入当前 Task，而不是机械拆成多个新 Task。

## Outcome

Agent 工作规则、文档入口、开发流程、Task 说明和模板统一采用 conversation-scoped living Task：Task 跟随开发对话演进，用户追加的要求同步进入范围、验收和验证记录，同时保留防止 Agent 自行扩张产品范围的边界。

## Why now

旧规则把 Task 定义为开工前锁定的单一可验证结果，与实际开发对话中不断补充细节和相关功能的工作方式不一致，容易制造大量零碎 Task，也可能让后续 Agent 丢失同一对话的连续上下文。

## In Scope

- 明确一次实现型开发对话对应一个 Task。
- 允许项目所有者在同一对话中持续追加相关范围。
- 新增 Scope changes 记录，以及对应的验收、验证、风险和 Required Reading 同步规则。
- 明确必要支撑工作与 Agent 自行“顺便加功能”的区别。
- 仅在需要新授权、重大架构决策、破坏性迁移或并行隔离时建议拆分。
- 同步 `AGENTS.md`、文档入口、Workflow、Task 说明、Task 模板和 Backlog 提升规则。

## Out of Scope

- 追溯改写已经完成的历史 Task。
- 允许 Agent 未经请求自行增加便利功能。
- 自动允许多个 Agent 在同一共享工作树中并行修改。
- 修改应用功能代码或当前产品行为。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-07 | Project owner | 初始请求即为完整工作流调整，本次没有后续追加 | 检查所有工作流文件不再要求 Task 必须冻结为单一结果 | Verified |

## Current evidence

- 旧 `WORKFLOW.md` 要求选择一个 narrow result，并建议过大请求在实现前拆分。
- 旧 `tasks/README.md` 规定一个 Task 只追求一个用户可感知结果。
- 旧模板没有记录对话中范围变化的位置。

## Proposed approach

保留 Ideas → Backlog → Task 的决策层级，但把 Task 的边界从“单功能点”改为“一次开发对话”。Task 的当前 In Scope 始终反映累计要求，Scope changes 保留追加来源和验收影响。用户明确追加和必要支撑工作可以进入当前 Task；未请求的想法仍只能进入 Ideas 或 Backlog。

## Acceptance criteria

- [x] 初始请求和 Scope changes 中所有仍有效的要求都有对应验收项。
- [x] `AGENTS.md` 明确一次实现型开发对话对应一个持续更新的 Task。
- [x] 同一对话中用户追加的功能继续进入当前 Task，并同步验收与验证。
- [x] Agent 不得以“顺便”为由自行扩张功能。
- [x] 新 Task 模板包含 Initial request 和 Scope changes。
- [x] Workflow、文档入口、Task 说明和 Backlog 提升规则保持一致。
- [x] `git diff --check` 通过，旧的冻结范围表述已从相关工作流文件移除。

## Verification

### Automated

- `git diff --check`
- 搜索旧的 `one narrow result`、`一个 Task 只追求一个`、`不扩张当前 Task` 和 `split it before implementation` 表述。

### Manual

人工检查 Ideas、Backlog、Task 的职责仍然清楚，并确认新增规则不会把普通想法讨论自动变成实现授权。

## Required Reading

- `AGENTS.md`
- `docs/README.md`
- `docs/development/STATUS.md`
- `docs/development/WORKFLOW.md`
- `docs/tasks/README.md`
- `docs/tasks/TASK_TEMPLATE.md`
- `docs/backlog/BACKLOG.md`

## Risks and rollback

- Task 过度增长可能延迟完成；通过累计验收、范围变更记录和需要重大隔离时请求拆分来控制。
- “对话中追加”可能被误解为 Agent 可自行扩张；文档明确只有用户要求或必要支撑工作可以加入。
- 如实践后不适用，可恢复为固定范围 Task，但保留 Scope changes 仍有审计价值。

## Decisions needed

None — 项目所有者已经明确选择一次开发对话对应一个可演进 Task。

## Completion record

- Verified commit: Working tree (commit pending)
- Automated evidence: `git diff --check` passed; stale fixed-scope wording search returned no matches.
- Manual evidence: Workflow and template cross-check completed.
- Documentation updated: `AGENTS.md`, `docs/README.md`, `docs/development/WORKFLOW.md`, `docs/tasks/README.md`, `docs/tasks/TASK_TEMPLATE.md`, `docs/backlog/BACKLOG.md`, `docs/development/STATUS.md`.
- Remaining work promoted to: None
- Scope changes closed: Yes
