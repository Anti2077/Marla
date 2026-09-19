# Worktree State Template

This optional local file identifies the Task and ownership of one worktree. Copy the fenced example to `.marla/worktree-state.md` only when it improves coordination or recovery.

The destination file is ignored by Git. It is not a project record: scope, decisions, acceptance, verification, dependencies, handoff facts, and integration evidence must remain in the tracked Task or specifications.

```md
---
schema_version: 1
worktree_root: "/absolute/path/to/worktree"
branch: "Anti2077/task-xxx-short-name"
state: "active"
task_id: "TASK-XXX"
task_path: "docs/tasks/TASK-XXX-short-name.md"
owner: "conversation or responsible agent"
started_from: "40-character Git commit"
integration_target: "main"
updated_at: "YYYY-MM-DDTHH:MM:SS+08:00"
---

## Write ownership

- `Sources/...`
- `Tests/...`
- `docs/features/...`

## Handoff note

- Durable details are recorded in the tracked Task.
```

## Rules

- `state` may be `idle`, `active`, `ready-for-integration`, `blocked`, `handoff`, or `recovery-required`.
- When `state` is `idle`, `task_id`, `task_path`, `owner`, `started_from`, and `integration_target` are `null`, and Write ownership is `None`.
- `started_from` records the original task baseline and does not move after every commit.
- `updated_at` is only a coordination hint. It is not a lease and does not authorize another worktree to take ownership.
- Do not store API keys, credentials, clipboard contents, screenshots, source text, translations, or other sensitive user data.
- A missing local state file does not block read-only work and does not override an explicitly assigned tracked Task.
- Before relying on the file, compare `worktree_root`, `branch`, `task_id`, `task_path`, `started_from`, `integration_target`, and Write ownership with live Git and the tracked Task. A branch switch does not automatically remove ignored state.

## Initialize Or Recover

1. Run `git status --short --branch`, `git rev-parse --show-toplevel`, and `git rev-parse HEAD`.
2. Confirm the tracked Task, branch, base commit, integration target, and owned paths.
3. Create the local state only after those facts agree. Use `recovery-required` when an existing dirty worktree has unclear ownership.
4. If any recorded identity, Task, base, target, or ownership field differs from live Git or the tracked Task, stop writing and rebuild the local state from tracked evidence.
5. Before handoff or worktree removal, move every durable fact into tracked files. The ignored pointer may then be deleted.

## Verify

```sh
git check-ignore -v .marla/worktree-state.md
git ls-files .marla/worktree-state.md
```

The first command must report the repository ignore rule. The second command must print nothing. `./scripts/check.sh` enforces the same boundary without requiring the optional local file to exist.
