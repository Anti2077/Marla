# Development Workflow

Marla uses a single-active-task workflow. Release documents define the target; they do not act as the daily queue.

## Capturing discussion

When a conversation produces a future possibility:

1. Add or update a detailed entry in `docs/backlog/IDEAS.md`.
2. Preserve the user problem, scenarios, options, risks, privacy/performance impact, open questions, and promotion conditions.
3. Keep it `Captured` or `Exploring` unless the project owner explicitly confirms the direction.
4. Do not add the idea to current implementation scope.

When the project owner confirms work should eventually be done, promote it to `docs/backlog/BACKLOG.md`. This confirms intent, not schedule.

## Selecting one task

1. Choose one narrow result from a Backlog item or direct request.
2. Copy `docs/tasks/TASK_TEMPLATE.md` to the next `TASK-xxx-short-name.md`.
3. Complete Outcome, In Scope, Out of Scope, evidence, acceptance, verification, and Required Reading.
4. Mark it `Ready`; the project owner starts it by approving the plan or requesting implementation.
5. Mark it `Active` and link it from `STATUS.md`. No second Task may be Active.

If a request is too large for one coherent verification cycle, split it before implementation.

## Starting implementation

1. Read `AGENTS.md`.
2. Read `STATUS.md`, the active Task, its Required Reading, and the universal required files.
3. Inspect relevant code and tests; live code is the current-behavior source of truth.
4. Compare code, tests, Task, release specification, and accepted ADRs.
5. Report and deliberately resolve mismatches before implementation.
6. Implement only the Task's In Scope. Record new ideas without expanding the Task.

## Finishing work

1. Run relevant automated and manual checks.
2. Update affected feature specifications.
3. Fill the Task completion record and mark it `Done` only when acceptance is met.
4. Update `STATUS.md` to current verified state and clear the Active Task.
5. Update the Backlog entry: close it, reduce its remaining scope, or split follow-up work.
6. Update the roadmap only when broad capability order changes.
7. Create or supersede an ADR only when a durable decision changes.
8. Keep implementation, tests, Task, and affected documentation synchronized in the same change.

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
