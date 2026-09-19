# Development Workflow

Marla uses conversation-scoped Tasks and isolated Git worktrees. One implementation-focused development conversation maps to one evolving tracked Task. The primary worktree exclusively checks out local `main` and acts as the integration owner; ordinary feature implementation happens on named Task branches in separate worktrees.

During incubation there is no release target. When the project owner explicitly starts release preparation, release documents define that target but never act as the daily queue. Product-version timing is defined in `VERSIONING.md`.

## Roles And Ownership

### Primary worktree

The primary worktree is `/Users/anti/Documents/ChatGPT/Marla` unless the project owner explicitly changes it. It normally remains clean on `main` and owns:

- assigning the next unique Task ID;
- creating the Task branch/worktree from the intended base commit;
- recording dependencies, path ownership, known overlaps, and merge order;
- reviewing feature commits, diffs, verification, and remaining acceptance gaps;
- resolving integration conflicts and performing target-branch-only fixes;
- updating `STATUS.md`, global Backlog/Roadmap/index files, and final Task integration records;
- running target-branch verification;
- pushing only with explicit authorization and verifying the remote ref;
- removing integrated worktrees or branches only when cleanup is explicitly requested or already authorized.

`scripts/main-worktree.sh` is the primary-only entry point for integration. It identifies the primary checkout by its real `.git` directory, requires symbolic branch `main`, rejects in-progress Git operations, and can require a completely clean tree. Its merge mode also validates the Task branch, matching tracked Task, `Ready for integration` status, linked feature-worktree cleanliness, and ancestry before running `git merge --no-ff`.

The primary worktree is not limited to mechanical merges. It may edit code for conflict resolution, an explicit integration/release Task, or a defect discovered by target-branch verification. Unrelated feature implementation still receives its own Task branch/worktree.

### Feature worktree

Each feature worktree:

- checks out one named Task branch;
- normally has one write-owning Task;
- writes only its recorded owned paths;
- implements the feature, tests, Task-local specifications, and durable evidence;
- records proposed target-branch Status, Backlog, Roadmap, or index changes in the Task's integration notes;
- becomes `Ready for integration` after worktree verification;
- cannot mark itself `Done` or claim target-branch integration, push, or cleanup.

Sub-Agents inside one worktree contribute to that worktree's Task. They do not create separate Tasks, expand scope, change global project state, or commit/merge/push unless the worktree's responsible Agent explicitly assigns that authority.

## Capturing Discussion

When a conversation produces a future possibility:

1. Add or update a detailed entry in `docs/backlog/IDEAS.md`.
2. Preserve the user problem, scenarios, options, risks, privacy/performance impact, open questions, and promotion conditions.
3. Keep it `Captured` or `Exploring` unless the project owner explicitly confirms the direction.
4. Do not add the idea to current implementation scope.

When the project owner confirms a future product capability should eventually be done, promote it to `docs/backlog/BACKLOG.md`. This confirms intent, not schedule. Current-baseline testing, manual acceptance, and performance measurement belong in `docs/development/VERIFICATION.md`, not in the product Backlog.

## Reserving And Starting A Task

1. Receive an explicit implementation request from the project owner, whether it comes from Backlog or directly from the conversation.
2. In the primary worktree, inspect live Git, all current worktrees, local branches, and tracked Task files.
3. Assign the next unique Task ID. Do not let separate worktrees independently guess the next number.
4. Create a named `Anti2077/task-NNN-short-name` branch and isolated worktree from the intended target-branch commit.
5. Create the Task from `docs/tasks/TASK_TEMPLATE.md` and record the request, execution context, scope, exclusions, evidence, acceptance, verification, Required Reading, ownership, dependencies, overlaps, and expected merge order.
6. Commit the initial Task before implementation. That branch plus initial Task commit is the durable Task-ID reservation.
7. Mark the Task `Ready`; after the project owner approves implementation, mark it `Active` and continue using it for the lifetime of that conversation.
8. Optionally initialize `.marla/worktree-state.md` from `WORKTREE_STATE_TEMPLATE.md`. This ignored file is only a local identity pointer and never replaces the tracked Task or live Git.

Example persistent worktree creation:

```sh
worktree_root="$HOME/.codex/worktrees/task-XXX/Marla"
git worktree add \
  -b Anti2077/task-XXX-short-name \
  "$worktree_root" \
  main
```

The coordinator may choose another safe persistent local path. Codex-managed worktrees normally live under `~/.codex/worktrees/<id>/Marla`; do not infer that active worktrees are temporary merely because stale, prunable `/private/tmp` metadata exists. Use `/private/tmp` only for a deliberately disposable worktree. Ordinary branches cannot be checked out in two worktrees simultaneously.

## Evolving Scope During The Conversation

The initial Task scope is a baseline, not a frozen contract.

1. When the project owner adds a feature, interaction, fix, or refinement in the same development conversation, append it to the Task's scope-change record.
2. Update In Scope, Out of Scope, acceptance criteria, verification, Required Reading, risks, ownership, overlaps, dependencies, and documentation impact as needed before claiming the addition complete.
3. Keep already verified requirements checked; add new requirements unchecked until evidence exists.
4. Agent-discovered supporting work may join the Task when necessary to complete an authorized requirement. State why it is necessary instead of silently expanding the product.
5. A newly noticed possibility that the owner did not request remains in Ideas or Backlog and is not implemented merely because it is nearby.
6. If an addition requires new authority, destructive migration, a durable architecture decision, materially different product behavior, or separate branch isolation, explain the impact and ask whether to include it or create a follow-up Task.
7. Do not create a new Task for every small addition inside the same conversation. Conversely, do not reopen a completed Task for a later development conversation; create a new Task and link the prior one.

## Starting Implementation

1. Read `AGENTS.md`.
2. Inspect live Git and confirm the current worktree, branch, `HEAD`, and dirty state.
3. Read `STATUS.md` as the integration target's verified baseline.
4. Read the Task explicitly assigned to this conversation/worktree, its Required Reading, and the universal required files.
5. If `.marla/worktree-state.md` exists, verify its root and branch against live Git before relying on it.
6. Inspect relevant code and tests; live code is the current-behavior source of truth.
7. Compare code, tests, Task, current specifications, accepted ADRs, and the active release contract only when `STATUS.md` names one.
8. Report and deliberately resolve mismatches before implementation.
9. Implement only the Task's accumulated In Scope and necessary owner-visible support work. Record unrequested ideas without implementing them.

If no tracked Task is explicitly assigned, read-only help may continue, but implementation must stop until the primary integration owner assigns and reserves one.

## Parallel Worktree Coordination

When two or more feature worktrees are active:

1. The primary integration owner assigns each Task a unique ID, branch, worktree, base commit, integration target, owner, owned paths, dependencies, known overlaps, and expected merge order.
2. One path has one write owner at a time. If Tasks need the same file, define a merge order and make the later Task reconcile with updated `main`.
3. A feature worktree never edits target-branch `STATUS.md`. It does not edit global Backlog/Roadmap/index files merely to register itself; it may edit one only when the Task lists that file in Owned paths as substantive scope. The integration owner performs final target-branch reconciliation.
4. Completing, blocking, handing off, or cancelling one Task never clears or edits another worktree's Task.
5. The optional local state file is not a lease. `updated_at` does not authorize takeover.
6. Before handoff or worktree deletion, move every durable scope, decision, evidence, acceptance, and dependency fact into tracked files.
7. Concurrent `./scripts/check.sh` runs use distinct `MARLA_BUILD_CACHE_ROOT` paths or run serially to avoid build-database contention.

For a dependent or overlapping Task, integrate its predecessor first. Then merge the updated `main` into the later feature branch, resolve semantic conflicts there, rerun feature verification, and only then integrate it.

## Parallel Documentation Work

For substantial multi-file documentation work, the responsible Agent creates a bounded contributor table in the Task:

| Contributor | Objective | Required Reading | Write ownership | Output |
| --- | --- | --- | --- | --- |
| Agent A | Check current code and test facts | Specified source and tests | None | Evidence report |
| Agent B | Update one independent specification | Relevant Feature/ADR | Assigned document | Documentation change |
| Agent C | Review terminology and links | Documentation entry points | None | Review report |

Rules:

1. Split by independent files, sections, evidence checks, or review duties, not by having several contributors edit the same passage.
2. One file has one writer at a time. Use read-only reviewers for additional perspectives.
3. `AGENTS.md`, the worktree Task, documentation indexes, and one bilingual document normally have one sequential owner.
4. Target-branch `STATUS.md` and global coordination files remain owned by the primary integration owner.
5. Contributors report evidence, conflicts, and unknowns rather than making product or architecture decisions silently.
6. The responsible Agent integrates all contributions, reviews the whole diff, and reconciles duplicate IDs, links, terminology, bilingual content, and claims against live code/tests.
7. Small or tightly coupled documentation changes should remain serial when parallelism would add coordination cost.

## Finishing A Feature Worktree

1. Confirm that the initial request and every recorded scope change have acceptance coverage.
2. Run targeted checks, then the Task's complete feature-worktree verification.
3. Update affected Task-local specifications and durable evidence.
4. Classify every remaining owner-only manual acceptance gap. A blocking criterion prevents `Ready for integration`; a non-blocking evidence item may survive only when the Task says why it does not block integration or the project owner authorizes transfer to `VERIFICATION.md` or a follow-up Task.
5. Review the entire branch diff and confirm it contains no unrelated work.
6. Fill the worktree completion record and mark the Task `Ready for integration`.
7. Commit that state and leave the linked feature worktree clean. Do not update target-branch `STATUS.md` or mark the Task `Done`.

Use an isolated cache when other worktrees may be validating concurrently:

```sh
MARLA_BUILD_CACHE_ROOT=/private/tmp/marla-task-XXX-cache ./scripts/check.sh
```

## Integrating Into Main

The primary integration owner performs integration from a clean primary worktree:

1. Run the primary preflight and inspect all worktrees plus the feature branch's current tip:

   ```sh
   ./scripts/main-worktree.sh check --clean
   git worktree list --porcelain
   ```

2. Review the commits and cumulative diff:

   ```sh
   git log --oneline main..Anti2077/task-XXX-short-name
   git diff --stat main...Anti2077/task-XXX-short-name
   git diff main...Anti2077/task-XXX-short-name
   ```

3. Confirm Task scope, verification evidence, ownership, dependencies, overlaps, and remaining acceptance gaps.
4. If `main` advanced materially, merge `main` into the feature branch, resolve conflicts in the feature worktree, and rerun feature verification before continuing.
5. From the clean primary worktree, run the guarded merge:

   ```sh
   ./scripts/main-worktree.sh merge Anti2077/task-XXX-short-name
   ```

   The command requires exactly one matching `docs/tasks/TASK-NNN-*.md` on the branch with `Status: Ready for integration`, rejects a dirty linked feature worktree, and requires the feature branch to contain current `main`. It performs no documentation update, push, cleanup, reset, rebase, or deletion.

6. Resolve conflicts by understanding both Tasks and current code. Do not accept an entire side mechanically when it would discard concurrent work. Use `git merge --abort` when safe resolution is not yet possible.
7. After a successful merge, run `./scripts/main-worktree.sh check` before editing final target-branch records.
8. Confirm that no blocking Task acceptance remains. Update the Task to `Done`, record the merge commit and target-branch verification, transfer any authorized non-blocking evidence gap, and synchronize `STATUS.md` plus any authorized global Backlog/Roadmap/index changes.
9. Keep `STATUS.md` concise: stage/release state, integrated baseline, open acceptance gaps, current risks/product decisions, and Required Reading. Completed detail remains in Tasks, `VERIFICATION.md`, and Git.
10. Run `./scripts/check.sh` against the final documented tree. Build the fixed Release development App when the Task or acceptance requires it, then commit the integration record.

A local merge is not a push. Report the local target branch and remote state separately.

## Push And Cleanup

Push only after explicit authorization:

```sh
git push origin main
```

Verify the remote ref before reporting success. Keep the feature worktree until integration, target-branch verification, final documentation, and any required push verification are complete. Worktree or branch deletion is a separate cleanup action and must not erase the tracked Task or evidence.

## Current Verification Command

Run:

```sh
./scripts/check.sh
```

The script checks the local-state ignore boundary, Rust formatting, strict Clippy, Rust tests/build, source structure, shell syntax, Swift build/tests, Xcode Debug, source whitespace, and Git diff whitespace. It uses `/Applications/Xcode.app` through `DEVELOPER_DIR` only for its own process and does not change the machine-wide `xcode-select` setting.

## Documentation Statuses

- Proposed: designed but not implemented.
- In Progress: implementation exists but acceptance is incomplete.
- Implemented: code path exists.
- Verified: acceptance criteria have current evidence.
- Deferred: intentionally outside the current milestone.

These specification statuses do not replace Task lifecycle states.

## History

Do not append session transcripts to `STATUS.md`. Use Git commits, tracked Tasks, verification records, and release notes for historical detail. Keep `STATUS.md` limited to stage/release state, the integration target's concise integrated baseline, open acceptance gaps, current risks or product decisions, and Required Reading.

Version documents are release contracts created only by explicit release preparation. Daily notes belong in the Task assigned to the current worktree; completed history belongs in Git and, at actual release time, `docs/releases/`. Withdrawn contracts remain historical and do not freeze incubation scope. Local worktree state is coordination metadata, not project history.
