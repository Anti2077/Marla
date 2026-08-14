# Marla Agent Guide

## Start here

Before changing the project, read these files in order:

1. `docs/development/STATUS.md`
2. The active `docs/tasks/TASK-xxx-*.md` linked from `STATUS.md`, if one exists
3. Every file listed under that task's `Required Reading` section
4. The universal files listed under the status document's `Required Reading` section
5. Relevant accepted ADRs under `docs/architecture/decisions/`

Then inspect the live code and tests. Do not assume that a chat transcript reflects the current repository state.

If `STATUS.md` says there is no active task, do not choose an implementation item from the roadmap, backlog, or idea pool. Help the project owner clarify one task first, then create or activate its task document.

Each implementation-focused development conversation maps to one Task. Keep using and updating that Task for the lifetime of the conversation, including requirements the project owner adds while work is in progress. Idea capture, explanation, review, and planning-only conversations do not require an implementation Task unless they turn into authorized project changes.

## Project boundaries

- Marla is a native macOS instantaneous translation layer.
- The currently implemented behavior and the active Task define what may be changed in this worktree. Do not infer new scope from an old release discussion.
- Use Swift 6, SwiftUI, and AppKit for presentation and macOS integration. Use the embedded Rust core for business logic according to ADR-0004. Do not introduce Tauri, Python, a localhost sidecar, or a bundled local VLM without an accepted ADR.
- Screenshots are ephemeral by default and must not be persisted without an explicit product decision.
- Do not add unrelated features merely because they are convenient to implement.
- New strongly related types or a new subsystem must be placed in a new source file under the matching application layer; do not append them to `MarlaApplicationModel.swift` or any file near a structure-gate limit.

## Working discipline

- At the start of every task, compare `STATUS.md`, relevant specifications, code, and tests.
- If they disagree, report and resolve the mismatch instead of silently choosing one source.
- Treat the current development conversation and its Task as one evolving unit of work. In the shared worktree, normally keep at most one Task in `Active` state unless separate branches or worktrees were explicitly arranged.
- A Task must have explicit current scope, exclusions, acceptance criteria, and a scope-change record. When the project owner adds work in the same conversation, update those sections and continue in the same Task instead of creating a new Task for every addition.
- Do not expand a Task merely because an extra feature is convenient. Agent-discovered supporting work may be added only when it is necessary for the requested outcome and is reported. Unrelated suggestions remain in Ideas or Backlog unless the project owner explicitly brings them into the current conversation's scope.
- Keep `STATUS.md` current-state only. Git history is the historical log.
- Record uncommitted future possibilities in `docs/backlog/IDEAS.md` with their context, tradeoffs, risks, and open questions. Discussion does not authorize implementation.
- Move an idea to `docs/backlog/BACKLOG.md` only after the project owner confirms it should be done or an accepted ADR requires it. Move a backlog item into a Task only when it is selected for work.
- Update a feature specification when its behavior or acceptance criteria change.
- Create an ADR only for a durable architectural or product decision.
- Update `ROADMAP.md` only when broad capability order changes. Do not use it as a task checklist.
- Treat the release contract linked from `STATUS.md` as a target and acceptance reference, not as the daily task tracker.
- When the active release contract has bilingual sections, keep both languages synchronized in the same change; the contract defines which language is normative.
- A task is not complete until relevant tests pass and documentation reflects the verified state.
- Preserve user changes and keep edits focused.

## Documentation collaboration

- For substantial documentation work, especially multi-file creation, restructuring, specification synchronization, or evidence review, the main Agent should normally evaluate whether multiple sub-Agents can work in parallel.
- Sub-Agents are contributors to the current conversation's Task, not separate Tasks. Parallel documentation work does not authorize additional product scope.
- Before delegating, the main Agent must define each contributor's bounded objective, Required Reading, allowed write files or sections, forbidden files, expected output, and whether the contributor is read-only or may edit.
- In the shared worktree, assign each file one write owner at a time. If several perspectives are needed for one file, use one writer and read-only reviewers. Do not have multiple Agents edit `AGENTS.md`, `STATUS.md`, the active Task, documentation indexes, or the same bilingual document concurrently.
- The main Agent owns interpretation of project rules, the active Task and scope-change record, `STATUS.md`, final wording, conflict resolution, whole-diff review, final verification, and the eventual commit or push.
- Sub-Agents must read the relevant `AGENTS.md`, `STATUS.md`, active Task, and Required Reading before contributing. They must report evidence, conflicts, and unknowns instead of silently making product or architecture decisions.
- Sub-Agents must not create or switch Active Tasks, promote Ideas to Backlog, accept or supersede ADRs, mark acceptance criteria complete, or commit/merge/push unless the main Agent explicitly assigns and authorizes that action.
- Before finishing, the main Agent must reconcile terminology, duplicate IDs, links, bilingual sections, and claims against live code/tests; run applicable documentation checks and `git diff --check`; and verify that no parallel contribution or existing user change was omitted.
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

This wrapper runs Rust formatting/tests/build first, selects the installed full Xcode for the Swift and Xcode commands, uses writable project-specific temporary caches, runs Swift build/tests, builds the Debug macOS app with the Cargo debug library, validates source whitespace, and runs `git diff --check`. It does not change the machine-wide `xcode-select` setting.

For a verified, stable-signed Release development app, run:

```sh
./scripts/build-test-app.sh
```

The packaging script verifies that Release resolves only `target/release`, stages and signs the build with the existing stable local identity, then safely replaces only `artifacts/Marla_dev.app`. It checks the fixed artifact's Bundle ID, version, minimum system, architecture, executable, LSUIElement setting, signature, and designated requirement. The first build requires an explicit `MARLA_CODE_SIGN_IDENTITY`; later builds recover it from the existing fixed App and never silently fall back to ad-hoc signing.

## Source-of-truth order

1. Live code and automated tests describe current behavior.
2. The active Task describes the current authorized work and its acceptance criteria.
3. `STATUS.md` describes the verified development state and known gaps.
4. Architecture and feature specifications describe the broader design.
5. Accepted ADRs describe durable intent.
6. The release contract linked from `STATUS.md` describes the current target, not necessarily implemented behavior.
7. Backlog, ideas, and roadmap describe future possibilities or ordering; they do not prove implementation.

If code contradicts an accepted ADR, record the discrepancy in `STATUS.md` and resolve it deliberately.
