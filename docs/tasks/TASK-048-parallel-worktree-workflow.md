# TASK-048：建立主工作树整合与功能工作树并行流程

Status: Done

Owner: Project owner + Agent

Created: 2026-09-19

Updated: 2026-09-19

Origin: direct request / unmerged workflow branch review

Conversation: 2026-09-19 `codex/parallel-worktree-docs` 适用性审查与现行流程落地

## Execution context

- Worktree: `/private/tmp/marla-task-048-workflow`
- Branch: `Anti2077/task-048-parallel-worktree-workflow`
- Base commit: `f1377782b8f3dfd0de2f10320809ff26b7a829ca`
- Integration target: `main`
- Integration owner: primary worktree `/Users/anti/Documents/ChatGPT/Marla`
- Integration status: Integrated
- Depends on: None
- Owned paths: `.gitignore`, `AGENTS.md`, `docs/README.md`, `docs/development/STATUS.md` during integration only, `docs/development/UI_UX_SKILLS.md`, `docs/development/WORKFLOW.md`, `docs/development/WORKTREE_STATE_TEMPLATE.md`, `docs/tasks/README.md`, `docs/tasks/TASK_TEMPLATE.md`, `scripts/check.sh`, this Task
- Known overlaps: the primary worktree owns `main` and final `STATUS.md`; current product Tasks and release/version documents must not be rewritten by the feature worktree

## Initial request

Review the forgotten `codex/parallel-worktree-docs` branch, keep the still-useful workflow, and implement the agreed model: the primary worktree exclusively checks out `main` and owns coordination/integration, while feature worktrees implement bounded Tasks and become `Done` only after mainline integration and verification.

## Outcome

Marla will have one documented, enforceable workflow for parallel development. The primary worktree remains a clean integration surface; each feature worktree owns one bounded Task and branch; tracked Task records remain durable; optional ignored local state helps identify a worktree; and integration, mainline verification, global documentation, push state, and cleanup are reported separately.

## Why now

The old branch contains a sound coordination model but is 80 commits behind current `main`, conflicts with the existing `TASK-022`, and predates unversioned incubation plus current validation gates. Current documents still combine a single `STATUS.md` Active Task slot with explicitly permitted parallel worktrees, while the repository already has multiple feature worktrees. The rules need to be ported onto the current baseline rather than merged or cherry-picked unchanged.

## In Scope

- Keep the primary worktree on `main` and perform this implementation in a dedicated TASK-048 worktree.
- Define the primary worktree as integration owner: Task-ID allocation, worktree/branch coordination, merge review, conflict resolution, mainline verification, global documentation, authorized push, and cleanup.
- Define feature-worktree ownership: one write-owning Task, bounded paths, implementation, Task-local specifications and evidence, and `Ready for integration` as the pre-merge terminal state.
- Add Task execution context, dependencies, overlaps, integration notes, worktree verification, and integration verification to the Task template and guide.
- Add an ignored `.marla/worktree-state.md` pointer and tracked template without making that local file a durable source of truth or mandatory for read-only work.
- Preserve current Incubation / Unreleased rules, `0.0.0` sentinel, structure gate, Serena boundary, SwiftUI workflow, Clippy, shell validation, Xcode checks, and website ignores.
- Extend `scripts/check.sh` only with local-state ignore/tracking invariants; do not remove any current verification gate.
- Reconcile the old `codex/parallel-worktree-docs` design into current documentation without merging its duplicate TASK-022 or withdrawn `0.1.0` edits.
- Verify the feature branch, mark it `Ready for integration`, merge it from the clean primary worktree, rerun mainline verification, then update Task/Status to `Done`.

## Out of Scope

- Product behavior, Swift/Rust implementation, UI, Provider, OCR, release-version, signing, or distribution changes.
- Rewriting historical Tasks or assigning worktree metadata retroactively.
- Merging or cherry-picking `818a305` or `56a73b8` unchanged.
- Deleting old branches or pruning stale worktree metadata without a separate explicit cleanup decision.
- Pushing `main` or any branch without explicit authorization.
- Introducing GitHub Projects, an external task database, an automatic lease service, or mandatory cross-machine coordination.

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-09-19 | Project owner | Adopt the primary-main-worktree plus feature-worktree integration model | Create TASK-048 worktree, port current-safe rules, verify feature branch and mainline integration | Complete |

## Current evidence

- Primary worktree was clean at `main@f137778`, 19 commits ahead of `origin/main`, before TASK-048 started.
- `codex/parallel-worktree-docs` contains commits `818a305` and `56a73b8`; it is 80 commits behind current `main` and uses a prunable missing `/private/tmp/marla-parallel-docs` worktree.
- The old branch creates `TASK-022-parallel-worktree-documentation.md`, conflicting with the existing completed `TASK-022-expanded-language-support.md`.
- Current `AGENTS.md` and Workflow allow explicitly isolated parallel Tasks but still use `STATUS.md` as the Active Task entry point and completion slot.
- Current `scripts/check.sh` includes strict Clippy, structure validation, shell syntax checks, Swift/Xcode builds, whitespace checks, and `git diff --check`; these gates must remain.

## Proposed approach

Port the old branch's durable ideas onto the live files. Use the tracked Task as the authoritative scope/evidence record; use `.marla/worktree-state.md` only as an ignored local identity pointer validated against live Git; centralize Task-ID allocation in the integration owner; prevent feature worktrees from claiming global mainline state; and split completion into feature verification (`Ready for integration`) and target-branch verification (`Done`). Keep the primary worktree free of feature implementation and use it for final integration, global documentation, and authorized publication.

## Acceptance criteria

- [x] Start instructions distinguish target-branch baseline, current worktree Task, and optional local worktree state without weakening live code/test precedence.
- [x] The primary worktree's integration-owner responsibilities and feature-worktree write boundaries are explicit.
- [x] Parallel Task IDs are centrally assigned before implementation; new Tasks record worktree, branch, base, target, dependencies, owned paths, overlaps, and merge order.
- [x] Lifecycle includes `Ready for integration`; only target-branch integration plus verification permits `Done`.
- [x] Feature worktrees do not use `STATUS.md` as their activity registry; global documents are edited only when substantive Task scope owns them, with final reconciliation at integration.
- [x] `.marla/worktree-state.md` is precisely ignored, has a safe tracked template, contains no durable-only facts or secrets, and is optional for read-only work.
- [x] `scripts/check.sh` rejects an unignored or tracked local state while preserving every current validation gate.
- [x] Incubation/versioning, structure, Serena, UI review, release packaging, website ignore, and source-of-truth rules remain intact.
- [x] Static searches find no current rule that requires every parallel feature worktree to overwrite a single global Active Task slot outside the historical current-main status text pending integration cleanup.
- [x] Feature-worktree checks and `git diff --check` pass.
- [x] After merge, full `./scripts/check.sh` passes on `main`; Task and `STATUS.md` record the integration truth separately from remote push state.

## Verification

### Automated

```sh
MARLA_BUILD_CACHE_ROOT=/private/tmp/marla-task-048-cache ./scripts/check.sh
```

After integration:

```sh
./scripts/check.sh
```

Also run focused static searches for stale single-slot wording and verify local-state ignore/tracking invariants.

### Manual

Walk through two hypothetical feature worktrees with unique Task IDs and disjoint ownership. Confirm one can reach `Ready for integration` without altering the other's state; integrate the first through the primary worktree; then ensure the second must reconcile with the updated `main` before integration. Confirm local merge, remote push, and worktree cleanup remain distinct reported states.

## Required Reading

- `AGENTS.md`
- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/development/STATUS.md`
- `docs/development/UI_UX_SKILLS.md`
- `docs/development/WORKFLOW.md`
- `docs/development/VERSIONING.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/tasks/README.md`
- `docs/tasks/TASK_TEMPLATE.md`
- `.gitignore`
- `scripts/check.sh`
- `docs/tasks/TASK-012-conversation-scoped-tasks.md`
- old branch commits `818a305` and `56a73b8` as historical design input only

## Parallel contributors

| Contributor | Objective | Required Reading | Write ownership | Permission | Output / status |
| --- | --- | --- | --- | --- | --- |
| workflow consistency reviewer | Check proposed current-doc changes for contradictory ownership, lifecycle, versioning, and verification rules | `AGENTS.md`, Status, Workflow, Task guide/template, Versioning, old branch diff | None | Read-only | Completed; seven findings reconciled before feature verification |

## Parallel worktree coordination

- TASK-048 was reserved by the primary integration owner on 2026-09-19 before documentation edits.
- The feature worktree owned the paths listed in Execution context except `STATUS.md`, which remained primary-worktree-only until integration.
- The primary worktree remained on `main`, merged the feature branch as `51c131a`, ran mainline verification, and updated `STATUS.md` plus this Task's integration record.
- No other current feature worktree is authorized to modify TASK-048 files.

## Risks and rollback

- An ignored local state can become stale after branch switching; every use must verify worktree root and branch against live Git.
- A central Task-ID allocator is a process rule, not a distributed lock; the integration owner must create/assign the Task before delegating work.
- Global documentation can still conflict when feature branches overlap; explicit ownership and merge order reduce but do not eliminate semantic review.
- Rollback consists of reverting TASK-048 documentation commits; no product code, user data, release metadata, or persistent runtime state changes.

## Decisions needed

None. The project owner approved this workflow on 2026-09-19.

## Completion record

- Worktree verified commit: `822c98f` (`Anti2077/task-048-parallel-worktree-workflow`)
- Integration commit: `51c131a6307b25dc4d2076b15988f07048808ab2`
- Integration verification: Authorized `MARLA_BUILD_CACHE_ROOT=/private/tmp/marla-task-048-main-cache ./scripts/check.sh` passed on local `main` on 2026-09-19.
- Automated evidence: The feature-worktree and mainline checks each passed Rust 52 tests, Swift Package tests, Xcode Debug build, strict Clippy, structure, shell syntax, local-state invariants, source whitespace, and `git diff --check`. The first restricted feature-worktree run failed at an AppKit window test (signal 5); the authorized host rerun passed the same test suite.
- Manual evidence: The primary worktree remained on `main`; the feature worktree owned TASK-048 and its recorded paths; read-only review findings were reconciled; the primary worktree performed the no-fast-forward merge; local merge, target-branch verification, remote push, and cleanup remain separate states.
- Documentation updated: Workflow, Task guidance/template, optional local-state template, entry documentation, UI/UX guidance, `AGENTS.md`, `scripts/check.sh`, `STATUS.md`, and this Task now describe the integrated workflow.
- Mainline documentation updated by: Primary integration worktree `/Users/anti/Documents/ChatGPT/Marla`
- Remaining work promoted to: None; remote publication and cleanup remain separately authorized lifecycle operations, not follow-up product work
- Scope changes closed: Yes after target-branch integration and verification
- Parallel contributions integrated: Read-only workflow consistency review reconciled
- Remote push state: Not pushed; no push authorization requested or implied
- Worktree cleanup state: Retained; no cleanup authorization was requested or implied
