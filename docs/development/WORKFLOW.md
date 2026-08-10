# Development Workflow

Marla uses a conversation-scoped task workflow. One implementation-focused development conversation maps to one evolving Task. Release documents define the target; they do not act as the daily queue.

## Capturing discussion

When a conversation produces a future possibility:

1. Add or update a detailed entry in `docs/backlog/IDEAS.md`.
2. Preserve the user problem, scenarios, options, risks, privacy/performance impact, open questions, and promotion conditions.
3. Keep it `Captured` or `Exploring` unless the project owner explicitly confirms the direction.
4. Do not add the idea to current implementation scope.

When the project owner confirms work should eventually be done, promote it to `docs/backlog/BACKLOG.md`. This confirms intent, not schedule.

## Starting a development conversation

1. Receive an explicit implementation request from the project owner, whether it comes from Backlog or directly from the conversation.
2. The main/integration coordinator reserves the next unique Task ID before parallel work begins. Do not independently guess the next number in two worktrees.
3. Copy `docs/tasks/TASK_TEMPLATE.md` to the reserved `TASK-xxx-short-name.md` and record the conversation's request, execution context, scope, exclusions, evidence, acceptance, verification, and Required Reading.
4. Record the branch, worktree root, base commit, integration target, owned paths, known overlaps, and dependencies in the Task. Initialize `.marla/worktree-state.md` from its tracked template.
5. Mark the Task `Ready`; the project owner starts it by approving the plan or requesting implementation. Then mark it `Active` in the Task and local state, not in `STATUS.md`.
6. Continue using this Task for the lifetime of that development conversation. A shared worktree normally has one write-owning Task; explicitly arranged isolated worktrees may each have their own Active Task.

`STATUS.md` is not a global Task registry. It describes only the target branch's integrated baseline, risks, and next selectable work.

## Evolving scope during the conversation

The initial Task scope is a baseline, not a frozen contract.

1. When the project owner adds a feature, interaction, fix, or refinement in the same development conversation, append it to the Task's scope-change record.
2. Update In Scope, Out of Scope, acceptance criteria, verification, Required Reading, risks, and documentation impact as needed before claiming the addition complete.
3. Keep already verified requirements checked; add new requirements unchecked until evidence exists.
4. Agent-discovered supporting work may join the Task when it is necessary to complete an authorized requirement. State why it is necessary instead of silently expanding the product.
5. A newly noticed possibility that the owner did not request remains in Ideas or Backlog and is not implemented merely because it is nearby.
6. If an addition requires new authority, destructive migration, a durable architecture decision, materially different product behavior, or separate branch isolation, explain the impact and ask whether to include it or create a follow-up Task.
7. Do not create a new Task for every small addition inside the same conversation. Conversely, do not reopen a completed Task for a later development conversation; create a new Task and link the prior one.

## Parallel worktree execution

Use this section when two or more independent branches/worktrees are active at once.

1. The coordinator assigns each Task a unique ID, owner, worktree, branch, base commit, integration target, owned paths, known overlaps, dependencies, and expected merge order.
2. Each worktree has at most one write-owning Task. Sub-Agents working inside that worktree remain contributors to that Task; they do not create additional Tasks or local coordination states.
3. The tracked Task is the durable contract. `.marla/worktree-state.md` is an ignored local pointer containing only worktree identity, current Task, owner, write ownership, and handoff notes.
4. A feature worktree must not update target-branch `STATUS.md`, global Backlog, Roadmap, or indexes unless it is explicitly the integration worktree. Proposed changes belong in the Task's integration notes.
5. A completed feature worktree uses `Ready for integration`, not `Done`. The integration owner merges it, resolves overlaps, updates target-branch Status/Backlog/indexes, runs final checks, and only then marks the Task `Done`.
6. Completing or blocking one Task never clears, edits, or claims another worktree's Task. `updated_at` in local state is not an automatic lease or expiry.
7. Before deleting or handing off a worktree, write all permanent scope, decisions, evidence, and acceptance into tracked files. An ignored local state file must never be the only handoff record.
8. If local state is missing while the worktree is dirty, use `recovery-required`; inspect Git, Task files, and history before writing. If state root or branch does not match Git, stop and rebuild it.

For substantial documentation work, create a delegation table in the Task with bounded objectives, Required Reading, write ownership, permission, and output. One file has one writer; use read-only reviewers for additional perspectives.

## Starting implementation

1. Read `AGENTS.md`.
2. Read `STATUS.md`, the Task attached to this conversation/worktree (from the local state when present), its Required Reading, and the universal required files.
3. Inspect relevant code and tests; live code is the current-behavior source of truth.
4. Compare code, tests, Task, release specification, and accepted ADRs.
5. Report and deliberately resolve mismatches before implementation.
6. Implement the Task's current accumulated In Scope, including owner-approved additions recorded during the conversation. Record unrequested ideas without implementing them.

## Parallel documentation work

对于较大的多文件文档工作，主 Agent 先在当前 Task 或工作记录中建立简短的拆分表：

| Contributor | Objective | Required Reading | Write ownership | Output |
| --- | --- | --- | --- | --- |
| Agent A | 核对当前代码和测试事实 | 指定源码与测试 | None | 证据报告 |
| Agent B | 更新某个独立功能规格 | 相关 Feature/ADR | 指定功能文档 | 文档修改 |
| Agent C | 审查术语、链接和中英文一致性 | 文档入口与版本合同 | None | 审查结果 |

规则：

1. 按独立文件、独立章节、事实核对或审查职责拆分，不按同一段文字多人抢写。
2. 共享工作树中一份文件同一时间只能有一个写入负责人；`AGENTS.md`、当前 Task、文档索引和同一份双语文档通常由该工作树主 Agent 串行维护；目标分支 `STATUS.md` 由整合负责人维护。
3. 子 Agent 是当前 Task 的协作者，不创建新的 Active Task，不改变产品范围，不自行接受 ADR，不提交或推送。
4. 子 Agent 开工前读取相关规则、Status、当前 Task 和 Required Reading；发现冲突或未知时回报主 Agent。
5. 子 Agent 完成只表示其分工已交回主 Agent；主 Agent 必须整合、处理冲突，并做完整 diff、链接、重复编号、术语、中英同步和代码/测试事实检查。
6. 如果必须并行编辑同一文件，应先使用独立分支或工作树并明确合并边界；不得依赖共享工作树中的隐式覆盖。
7. 小型或强耦合文档修改不强行并行；并行的目的是真正减少等待，不是增加协调成本。

## Finishing work

1. Confirm that the initial request and every recorded scope addition have acceptance coverage.
2. Run relevant automated and manual checks.
3. Update affected feature specifications.
4. In an isolated feature worktree, fill the worktree verification record and mark the Task `Ready for integration`; do not edit target-branch `STATUS.md` merely to register it.
5. The integration owner merges the Task, resolves documented overlaps, verifies the target branch, updates `STATUS.md` and any global Backlog/index files, then marks the Task `Done` and records both worktree and integration commits.
6. Update the Backlog entry only from the integration worktree: close it, reduce its remaining scope, or split follow-up work.
7. Update the roadmap only when broad capability order changes.
8. Create or supersede an ADR only when a durable decision changes.
9. If sub-Agents contributed, integrate their changes and evidence before marking the Task ready or done.
10. Keep implementation, tests, Task, and affected documentation synchronized in the same change; retain unresolved integration notes until the target branch is verified.

## Current verification command

Run:

```sh
./scripts/check.sh
```

The script checks Rust formatting, runs Rust tests, builds the Rust static library, selects `/Applications/Xcode.app` through `DEVELOPER_DIR` only for its own process, builds and tests Swift, checks source files for trailing whitespace, and checks Git diffs for whitespace errors. `--disable-sandbox` disables SwiftPM's nested sandbox because the agent environment already applies an outer filesystem sandbox.

## Documentation statuses

- Proposed: designed but not implemented.
- In Progress: implementation exists but acceptance is incomplete.
- Implemented: code path exists.
- Verified: acceptance criteria have current evidence.
- Deferred: intentionally outside the current milestone.

## History

Do not append session transcripts to `STATUS.md`. Use Git commits and Task/release records for historical detail. Keep only the target branch's integrated baseline, current risks, and next ordered work.

Version documents are release contracts. Daily notes belong in the Task attached to the current worktree; completed history belongs in Git and, at release time, `docs/releases/`. Local worktree state is coordination metadata, not project history.
