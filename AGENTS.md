# Marla Agent Guide

## Start here

Before changing the project, read these files in order:

1. Live Git context: `git status --short --branch`, the worktree root, current branch, and `HEAD`
2. `docs/development/STATUS.md` for the integration target's verified baseline, known gaps, and risks
3. `.marla/worktree-state.md`, if present, after verifying its root and branch against live Git
4. The Task explicitly assigned to the current conversation/worktree
5. Every file listed under that Task's `Required Reading` section
6. The universal files listed under the status document's `Required Reading` section
7. Relevant accepted ADRs under `docs/architecture/decisions/`

Then inspect the live code and tests. Do not assume that a chat transcript reflects the current repository state.

`STATUS.md` is not a registry of every parallel Task. If no tracked Task is explicitly assigned to the current implementation conversation/worktree, do not write code or choose an item from the roadmap, backlog, or idea pool. Help the project owner clarify one Task first, then have the primary integration owner reserve its ID and create its branch/worktree. Read-only help does not require a local state file.

Each implementation-focused development conversation maps to one Task. Keep using and updating that Task for the lifetime of the conversation, including requirements the project owner adds while work is in progress. Idea capture, explanation, review, and planning-only conversations do not require an implementation Task unless they turn into authorized project changes.

## Project boundaries

- Marla is a native macOS instantaneous translation layer.
- The currently implemented behavior and the Task assigned to this worktree define what may be changed here. Do not infer new scope from an old release discussion or another worktree's Task.
- Use Swift 6, SwiftUI, and AppKit for presentation and macOS integration. Use the embedded Rust core for business logic according to ADR-0004. Do not introduce Tauri, Python, a localhost sidecar, or a bundled local VLM without an accepted ADR.
- Screenshots are ephemeral by default and must not be persisted without an explicit product decision.
- Do not add unrelated features merely because they are convenient to implement.
- New strongly related types or a new subsystem must be placed in a new source file under the matching application layer; do not append them to `MarlaApplicationModel.swift` or any file near a structure-gate limit.

## Working discipline

- At the start of every task, compare `STATUS.md`, relevant specifications, code, and tests.
- If they disagree, report and resolve the mismatch instead of silently choosing one source.
- Treat the current development conversation and its Task as one evolving unit of work. Each worktree normally has at most one write-owning Task; explicitly arranged isolated worktrees may each have their own `Active` Task.
- A Task must have explicit current scope, exclusions, acceptance criteria, and a scope-change record. When the project owner adds work in the same conversation, update those sections and continue in the same Task instead of creating a new Task for every addition.
- Do not expand a Task merely because an extra feature is convenient. Agent-discovered supporting work may be added only when it is necessary for the requested outcome and is reported. Unrelated suggestions remain in Ideas or Backlog unless the project owner explicitly brings them into the current conversation's scope.
- Keep `STATUS.md` current-state only for the integration target's integrated and verified baseline. Git history and tracked Task records hold worktree history and evidence.
- Record uncommitted future possibilities in `docs/backlog/IDEAS.md` with their context, tradeoffs, risks, and open questions. Discussion does not authorize implementation.
- Move an idea to `docs/backlog/BACKLOG.md` only after the project owner confirms it should be done or an accepted ADR requires it. Move a backlog item into a Task only when it is selected for work.
- Update a feature specification when its behavior or acceptance criteria change.
- Create an ADR only for a durable architectural or product decision.
- Update `ROADMAP.md` only when broad capability order changes. Do not use it as a task checklist.
- A release contract exists only while `STATUS.md` names an owner-authorized release target. During unversioned incubation, do not create, infer, or enforce a release contract from an old version draft.
- When an active release contract exists, treat it as a target and acceptance reference rather than the daily task tracker; keep bilingual sections synchronized in the same change and follow its normative-language rule.
- Product release versions are assigned only in an explicit release-preparation Task. Ordinary feature Tasks keep the development App on the documented sentinel version and do not increment a product version.
- A feature-worktree Task becomes `Ready for integration` after its local checks pass. It becomes `Done` only after integration into the target branch, target-branch verification, and global documentation synchronization.
- Preserve user changes and keep edits focused.

## Worktree ownership

- The primary worktree exclusively checks out local `main` and normally stays clean. It is the integration owner for Task-ID assignment, feature-worktree creation, merge review, conflict resolution, target-branch verification, `STATUS.md`, final global-document reconciliation, authorized push, and authorized cleanup.
- Ordinary feature implementation happens on a named Task branch in an isolated worktree. The initial tracked Task commit is the durable reservation of its centrally assigned ID.
- A feature worktree never edits target-branch `STATUS.md`. It may edit another global document only when the Task lists that file in Owned paths as substantive scope; otherwise proposed Backlog, Roadmap, or index changes remain in integration notes.
- The primary worktree may change code when resolving an integration conflict, performing an explicit release/integration Task, or fixing a defect discovered by target-branch verification. Unrelated feature work still receives a dedicated Task branch/worktree.
- `.marla/worktree-state.md` is an optional ignored identity pointer. It never replaces the tracked Task or live Git, and every durable decision or handoff fact must be committed to tracked documentation.

## Documentation collaboration

- For substantial documentation work, especially multi-file creation, restructuring, specification synchronization, or evidence review, the main Agent should normally evaluate whether multiple sub-Agents can work in parallel.
- Sub-Agents inside one worktree are contributors to that worktree's Task, not separate Tasks. A separately arranged branch/worktree may have its own Task and owner; that is repository-level parallel work and does not authorize additional product scope.
- Before delegating, the main Agent must define each contributor's bounded objective, Required Reading, allowed write files or sections, forbidden files, expected output, and whether the contributor is read-only or may edit.
- In the same worktree, assign each file one write owner at a time. If several perspectives are needed for one file, use one writer and read-only reviewers. Do not have multiple Agents edit `AGENTS.md`, a Task, documentation indexes, or the same bilingual document concurrently.
- The worktree's main Agent owns its Task and scope-change record. The primary integration owner alone owns target-branch `STATUS.md`, final reconciliation of global documents, merge conflict decisions, whole-diff review, target-branch verification, and the eventual push.
- Sub-Agents must read the relevant `AGENTS.md`, `STATUS.md`, current worktree Task, and Required Reading before contributing. They must report evidence, conflicts, and unknowns instead of silently making product or architecture decisions.
- Sub-Agents must not create or switch Active Tasks, promote Ideas to Backlog, accept or supersede ADRs, mark acceptance criteria complete, or commit/merge/push unless the main Agent explicitly assigns and authorizes that action.
- Before finishing, the responsible Agent must reconcile terminology, duplicate IDs, links, bilingual sections, and claims against live code/tests; run applicable documentation checks and `git diff --check`; and verify that no parallel contribution or existing user change was omitted. The integration owner repeats this review against the target branch.
- For a small or tightly coupled documentation edit that cannot be divided safely, the main Agent may work alone and should not create artificial parallelism.

## UI design requirement

Before implementing or materially changing SwiftUI surfaces, read and use the installed `swiftui-design-skill`. If it is unavailable, install `wholiver/swiftui-design-skill@swiftui-design-skill` before UI work. After implementation, run its five-dimension review against real app screenshots; every dimension must score at least 7/10.

## Command teaching

如果识别到用户正在学习命令，尽量解释每个命令和关键参数的作用，不只给出可复制的命令。

## Serena semantic navigation

- For Swift or Rust source exploration, prefer Serena symbol overviews, symbol lookup, declaration, implementation, reference, and diagnostic queries before broad whole-file reads, especially for unfamiliar code and cross-file call paths.
- Call Serena's `initial_instructions` before the first Serena-assisted coding task in a new session.
- Serena is navigation-only in this repository. Do not enable or use Serena source editing, shell, project-switching, onboarding, or memory tools. Changing the Serena or Codex MCP allowlist requires explicit authorization in the current Task.
- Use `rg` and normal file reads for documentation, configuration, generated files, unsupported symbols, or whenever Serena is unavailable or returns incomplete results.
- Do not use Serena to index or navigate `.build/`, `.swiftpm/`, `target/`, `DerivedData/`, `artifacts/`, or `.serena/cache/`.
- Headroom is not part of the current toolchain. If recurring long test/build output, whole-repository or multi-file investigations, or repeated context compaction materially slow normal work, proactively tell the project owner that a separate Headroom evaluation and installation Task may now be worthwhile. Recheck current official guidance and obtain explicit authorization before installing Headroom, enabling its MCP integration, wrapping Codex, or changing related configuration.

## Verification

For the current hybrid Swift Package and Xcode phase, normally run:

```sh
./scripts/check.sh
```

This wrapper validates the ignored local-state boundary, Rust formatting, strict Clippy, Rust tests/build, source structure, all shell scripts, Swift build/tests, and an Xcode Debug build with `MARLA_CHECK_BUILD`; it then checks source whitespace and runs `git diff --check`. It selects the installed full Xcode only for its own process, uses writable project-specific temporary caches, and does not change the machine-wide `xcode-select` setting.

For a verified, stable-signed Release development app, run:

```sh
./scripts/build-test-app.sh
```

The packaging script verifies that Release resolves only `target/release`, stages and signs the build with the existing stable local identity, then safely replaces only `artifacts/Marla_dev.app`. It checks the fixed artifact's Bundle ID, version, minimum system, architecture, executable, LSUIElement setting, signature, and designated requirement. The first build requires an explicit `MARLA_CODE_SIGN_IDENTITY`; later builds recover it from the existing fixed App and never silently fall back to ad-hoc signing.

## Source-of-truth order

1. Live code and automated tests describe current behavior in the current worktree.
2. The Task assigned to the current conversation/worktree describes the current authorized work and its acceptance criteria.
3. `STATUS.md` describes the integration target's integrated, verified development state and known gaps.
4. Architecture and feature specifications describe the broader design.
5. Accepted ADRs describe durable intent.
6. An active release contract, when `STATUS.md` names one, describes the current release target but does not prove implementation.
7. The versioning policy describes when product versions and release contracts may be created; withdrawn version drafts are historical evidence only.
8. Backlog, ideas, and roadmap describe future possibilities or ordering; they do not prove implementation or assign a worktree.

If code contradicts an accepted ADR, record the discrepancy in the current Task and resolve it deliberately. The integration owner updates `STATUS.md` when that discrepancy enters the integrated baseline.
