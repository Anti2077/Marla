# Development Workflow

Marla uses a conversation-scoped task workflow. One implementation-focused development conversation maps to one evolving Task. Release documents define the target; they do not act as the daily queue.

## Capturing discussion

When a conversation produces a future possibility:

1. Add or update a detailed entry in `docs/backlog/IDEAS.md`.
2. Preserve the user problem, scenarios, options, risks, privacy/performance impact, open questions, and promotion conditions.
3. Keep it `Captured` or `Exploring` unless the project owner explicitly confirms the direction.
4. Do not add the idea to current implementation scope.

When the project owner confirms a future product capability should eventually be done, promote it to `docs/backlog/BACKLOG.md`. This confirms intent, not schedule. Current-release testing, manual acceptance, and performance measurement belong in `docs/development/VERIFICATION.md`, not in the product Backlog.

## Starting a development conversation

1. Receive an explicit implementation request from the project owner, whether it comes from Backlog or directly from the conversation.
2. Copy `docs/tasks/TASK_TEMPLATE.md` to the next `TASK-xxx-short-name.md`.
3. Record the conversation's initial request, Outcome, initial In Scope, Out of Scope, evidence, acceptance, verification, and Required Reading.
4. Mark it `Ready`; the project owner starts it by approving the plan or requesting implementation.
5. Mark it `Active` and link it from `STATUS.md`. Continue using this Task until that development conversation's accumulated work is finished.

In the shared worktree, normally no second Task may be Active. Explicitly arranged parallel branches or worktrees may each have their own active conversation Task, but their ownership and merge boundaries must be clear.

## Evolving scope during the conversation

The initial Task scope is a baseline, not a frozen contract.

1. When the project owner adds a feature, interaction, fix, or refinement in the same development conversation, append it to the Task's scope-change record.
2. Update In Scope, Out of Scope, acceptance criteria, verification, Required Reading, risks, and documentation impact as needed before claiming the addition complete.
3. Keep already verified requirements checked; add new requirements unchecked until evidence exists.
4. Agent-discovered supporting work may join the Task when it is necessary to complete an authorized requirement. State why it is necessary instead of silently expanding the product.
5. A newly noticed possibility that the owner did not request remains in Ideas or Backlog and is not implemented merely because it is nearby.
6. If an addition requires new authority, destructive migration, a durable architecture decision, materially different product behavior, or separate branch isolation, explain the impact and ask whether to include it or create a follow-up Task.
7. Do not create a new Task for every small addition inside the same conversation. Conversely, do not reopen a completed Task for a later development conversation; create a new Task and link the prior one.

## Starting implementation

1. Read `AGENTS.md`.
2. Read `STATUS.md`, the active Task, its Required Reading, and the universal required files.
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
2. 共享工作树中一份文件同一时间只能有一个写入负责人；`AGENTS.md`、`STATUS.md`、当前 Task、文档索引和同一份双语文档通常由主 Agent 串行维护。
3. 子 Agent 是当前 Task 的协作者，不创建新的 Active Task，不改变产品范围，不自行接受 ADR，不提交或推送。
4. 子 Agent 开工前读取相关规则、Status、当前 Task 和 Required Reading；发现冲突或未知时回报主 Agent。
5. 子 Agent 完成只表示其分工已交回主 Agent；主 Agent 必须整合、处理冲突，并做完整 diff、链接、重复编号、术语、中英同步和代码/测试事实检查。
6. 如果必须并行编辑同一文件，应先使用独立分支或工作树并明确合并边界；不得依赖共享工作树中的隐式覆盖。
7. 小型或强耦合文档修改不强行并行；并行的目的是真正减少等待，不是增加协调成本。

## Finishing work

1. Confirm that the initial request and every recorded scope addition have acceptance coverage.
2. Run relevant automated and manual checks.
3. Update affected feature specifications.
4. Fill the Task completion record and mark it `Done` only when the accumulated acceptance criteria are met.
5. Update `STATUS.md` to current verified state and clear the Active Task.
6. Update the Backlog entry: close it, reduce its remaining scope, or split follow-up work.
7. Update the roadmap only when broad capability order changes.
8. Create or supersede an ADR only when a durable decision changes.
9. If sub-Agents contributed, integrate their changes and evidence before marking the Task complete.
10. Keep implementation, tests, Task, and affected documentation synchronized in the same change.

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

Do not append session transcripts to `STATUS.md`. Use Git commits and release notes for historical detail. Keep only current progress, current risks, and the next ordered work.

Version documents are release contracts. Daily notes belong in the active Task while it is open; completed history belongs in Git and, at release time, `docs/releases/`.
