# TASK-049：加固主工作树整合入口并精简状态文档

Status: Active

Owner: Project owner + Agent

Created: 2026-09-19

Updated: 2026-09-19

Origin: direct workflow review follow-up

Conversation: 2026-09-19 工作树流程优化批注

## Execution context

- Worktree: `/Users/anti/.codex/worktrees/049/Marla`
- Branch: `Anti2077/task-049-main-integration-guard`
- Base commit: `a0f65228185b2861405105dc6f2c9e6980b4e049`
- Integration target: `main`
- Integration owner: primary worktree `/Users/anti/Documents/ChatGPT/Marla`
- Integration status: Unmerged
- Depends on: TASK-048
- Expected merge order: After TASK-048
- Owned paths: `AGENTS.md`, `docs/README.md`, `docs/development/WORKFLOW.md`, `docs/development/STATUS.md` during integration only, `docs/tasks/README.md`, `docs/tasks/TASK_TEMPLATE.md`, `scripts/main-worktree.sh`, this Task
- Known overlaps: The primary worktree alone owns the final `STATUS.md` compaction and integration record; no legacy Task status is reclassified in this Task

## Initial request

Apply the approved workflow refinements: keep merges and final global documentation in the primary worktree, make the primary worktree actively verify that it is the real primary checkout on `main` before integration, add one primary-only integration command, and compact `STATUS.md` so completed detail remains in Tasks, `VERIFICATION.md`, and Git. Do not add push reminders or automatic push behavior.

## Outcome

Future integrations use one guarded command that rejects linked worktrees, non-`main` branches, dirty primary state, dirty feature worktrees, stale feature branches, and Tasks that are not `Ready for integration`. The primary worktree then owns final Task/Status documentation. `STATUS.md` becomes a concise current-baseline document instead of a historical transcript.

## Why now

TASK-048 established the ownership model, but its first integration still relied on manual branch checks and a direct `git merge --no-ff`. The current `STATUS.md` also retains substantial completed history despite the new current-state-only rule. This bounded follow-up makes the intended process executable without changing product behavior or remote publication policy.

## In Scope

- Add `scripts/main-worktree.sh` with a read-only `check` mode and guarded `merge <feature-branch>` mode.
- Detect the primary checkout structurally, require branch `main`, reject in-progress Git operations, and optionally require a clean tree.
- Before merge, verify the local feature branch exists, follows the new Task branch naming convention, has exactly one matching tracked Task at `Ready for integration`, has no uncommitted work in its linked worktree, and includes current `main`.
- Perform only `git merge --no-ff`; never push, delete a worktree, delete a branch, or rewrite history.
- Update workflow entry documents and templates so primary integration uses the command and final global documentation remains primary-only.
- After integration, compact `STATUS.md` to the current integrated baseline, open acceptance gaps, current risks/decisions, and Required Reading.
- Preserve existing legacy Task records without mass-changing their lifecycle status; future integrations follow the guarded path.
- Record that active Codex worktrees are in persistent Codex worktree paths; no conclusion about those worktrees is based on the stale `/private/tmp` entries.

## Out of Scope

- Product, Swift, Rust, website, Provider, OCR, release, signing, or distribution changes.
- Moving or deleting any existing worktree, pruning stale metadata, or deleting branches.
- Reclassifying TASK-036, TASK-041, TASK-042, TASK-044, TASK-045, or TASK-046.
- Adding an ahead-count threshold, push reminder, automatic push, or remote mutation.
- A general task queue, external database, Git hook installation, or automatic conflict resolution.
- Replacing full feature-worktree or mainline verification with a lighter check.

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-09-19 | Project owner | Compact `STATUS.md` and make primary-main integration self-checking | Add guarded command, update workflow, compact Status only during main integration | Active |
| 2026-09-19 | Project owner | Owner handles pushes directly | Preserve explicit authorization boundary; add no reminder or automatic remote behavior | Active |
| 2026-09-19 | Project owner | Clarify that the other active worktrees are not under `/private/tmp` | Treat persistent Codex worktrees separately from stale temporary metadata | Active |

## Current evidence

- The primary worktree is clean on local `main@a0f6522` before TASK-049 starts.
- Live Git lists active linked worktrees under `/Users/anti/.codex/worktrees/`; two older `/private/tmp` entries are prunable missing paths, while TASK-048 remains separately retained under `/private/tmp`.
- `scripts/check.sh` validates the local-state ignore boundary but does not identify the primary checkout or require `main` before integration.
- `WORKFLOW.md` currently documents direct `git switch main` plus `git merge --no-ff` commands.
- `STATUS.md` is 217 lines and contains extensive completed Task history even though `AGENTS.md` and `WORKFLOW.md` now require current-state-only content.

## Proposed approach

Use the physical Git layout as the primary-worktree identity: the primary checkout has a real `.git` directory, while linked worktrees have a `.git` file. Resolve and compare the repository root, require symbolic branch `main`, and inspect Git operation sentinel paths. `check --clean` validates a merge-ready primary checkout. `merge` adds feature-branch and Task-state preflight checks before invoking `git merge --no-ff`.

Keep final documentation semantic and manual. The command proves location and branch ownership but does not generate product claims, mark a Task `Done`, push, or clean up. After the merge, the responsible Agent runs `check`, updates the Task and concise `STATUS.md`, runs full verification against the final documented tree, and commits the integration record.

## Acceptance criteria

- [ ] `check` succeeds only in the real primary checkout on symbolic branch `main` and rejects a linked feature worktree.
- [ ] `check --clean` rejects tracked, untracked, staged, or conflicted changes and in-progress merge/rebase/cherry-pick/revert operations.
- [ ] `merge <branch>` rejects `main`, nonexistent or nonconforming feature branches, dirty linked feature worktrees, Tasks not at `Ready for integration`, ambiguous/missing Task files, and feature branches that do not contain current `main`.
- [ ] A valid merge uses `--no-ff` and performs no push, branch/worktree deletion, cleanup, reset, rebase, or history rewrite.
- [ ] Agent/workflow/task documentation requires the primary command before merge and before final target-branch documentation.
- [ ] `STATUS.md` retains only current integrated baseline, open acceptance gaps, risks/decisions, and Required Reading; completed detail remains linked in Tasks, `VERIFICATION.md`, and Git.
- [ ] Existing active worktrees are described from live paths; stale temporary worktree metadata is not generalized to persistent Codex worktrees.
- [ ] Remote push policy remains explicit-owner authorization with no automatic threshold or reminder added.
- [ ] Shell syntax, focused command behavior, full `./scripts/check.sh`, static workflow searches, and `git diff --check` pass.

## Verification

### Automated

```sh
/bin/zsh -n scripts/main-worktree.sh
./scripts/main-worktree.sh check
./scripts/check.sh
git diff --check
```

Run linked-worktree, dirty-tree, wrong-branch, stale-main, invalid-branch, and Task-status failure probes in disposable repositories or against read-only command modes. The TASK-049 merge itself is the documented bootstrap exception because the command is not present on `main` until this branch is integrated.

### Manual

- Confirm command errors identify the violated invariant and recovery action.
- Confirm a successful merge stops before documentation, push, and cleanup.
- Review the compacted `STATUS.md` against live code, current Tasks, and `VERIFICATION.md` links.

## Required Reading

- `AGENTS.md`
- `docs/README.md`
- `docs/development/STATUS.md`
- `docs/development/WORKFLOW.md`
- `docs/development/VERIFICATION.md`
- `docs/tasks/README.md`
- `docs/tasks/TASK_TEMPLATE.md`
- `docs/tasks/TASK-048-parallel-worktree-workflow.md`
- `scripts/check.sh`
- `docs/development/WORKTREE_STATE_TEMPLATE.md`

## Parallel contributors

None. The script contract, workflow wording, Task record, and final Status compaction are tightly coupled and retain one write owner.

## Integration notes

- The primary worktree must compact `docs/development/STATUS.md` after merging this branch.
- TASK-049 is the final documented manual-merge bootstrap exception; subsequent Task integrations use `scripts/main-worktree.sh merge`.
- After merging, run `scripts/main-worktree.sh check` before editing final target-branch Task/Status records.
- Do not push or clean up without a separate explicit request.

## Risks and rollback

- Overly strict branch freshness checks may require merging `main` into a feature branch even when files do not overlap; this is intentional to make the verified integration input explicit.
- Git-layout detection assumes the documented primary checkout is the main repository checkout with a `.git` directory. If the project is deliberately relocated, update the documented primary path and revalidate the command.
- Rollback is removal of the script and its workflow references plus restoration of the prior Status layout; no product or user data changes.

## Decisions needed

None. The project owner selected primary-main integration, concise Status, owner-managed push, and no cleanup in this conversation.

## Completion record

- Worktree verified commit:
- Integration commit:
- Integration verification:
- Automated evidence:
- Manual evidence:
- Documentation updated:
- Mainline documentation updated by:
- Remaining work promoted to:
- Scope changes closed:
- Parallel contributions integrated: None
- Remote push state: Not pushed; owner-managed and outside this Task
- Worktree cleanup state: Retained unless separately authorized
