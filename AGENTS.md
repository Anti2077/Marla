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

## Project boundaries

- Marla is a native macOS instantaneous translation layer.
- Marla 0.1.0 focuses on selection translation in a nearby card, Vision-only screenshot translation, and quick input.
- Use Swift 6, SwiftUI, and AppKit for presentation and macOS integration. Use the embedded Rust core for business logic according to ADR-0004. Do not introduce Tauri, Python, a localhost sidecar, or a bundled local VLM without an accepted ADR.
- macOS Vision is the only OCR provider in 0.1.0. Cloud GLM-OCR remains a post-0.1.0 plan and must not appear in active 0.1.0 UI or network flows.
- 0.1.0 does not send contextual window data, keep translation history, or cover source text in place.
- PDF, Office documents, batch processing, and a full document workspace are deferred.
- Screenshots are ephemeral by default and must not be persisted without an explicit product decision.
- Do not add unrelated features merely because they are convenient to implement.

## Working discipline

- At the start of every task, compare `STATUS.md`, relevant specifications, code, and tests.
- If they disagree, report and resolve the mismatch instead of silently choosing one source.
- Keep at most one task under `docs/tasks/` in `Active` state. A task is the Agent's immediate implementation contract and must have explicit in-scope, out-of-scope, and acceptance sections.
- Keep `STATUS.md` current-state only. Git history is the historical log.
- Record uncommitted future possibilities in `docs/backlog/IDEAS.md` with their context, tradeoffs, risks, and open questions. Discussion does not authorize implementation.
- Move an idea to `docs/backlog/BACKLOG.md` only after the project owner confirms it should be done or an accepted ADR requires it. Move a backlog item into a Task only when it is selected for work.
- Update a feature specification when its behavior or acceptance criteria change.
- Create an ADR only for a durable architectural or product decision.
- Update `ROADMAP.md` only when broad capability order changes. Do not use it as a task checklist.
- Treat `docs/versions/0.1.0/` as the active release contract and acceptance target, not as the daily task tracker.
- Keep the Chinese and English portions of every 0.1.0 version document synchronized in the same change. Chinese is normative if they disagree.
- A task is not complete until relevant tests pass and documentation reflects the verified state.
- Preserve user changes and keep edits focused.

## UI design requirement

Before implementing or materially changing 0.1.0 SwiftUI surfaces, read and use the installed `swiftui-design-skill`. If it is unavailable, install `wholiver/swiftui-design-skill@swiftui-design-skill` before UI work. After implementation, run its five-dimension review against real app screenshots; every dimension must score at least 7/10.

## Command teaching

如果识别到用户正在学习命令，尽量解释每个命令和关键参数的作用，不只给出可复制的命令。

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
3. Active version specifications describe the accepted release target.
4. Accepted ADRs describe durable intent.
5. Architecture and feature specifications describe the broader design.
6. `STATUS.md` describes current execution state and known gaps.
7. Backlog, ideas, and roadmap describe future possibilities or ordering; they do not prove implementation.

If code contradicts an accepted ADR, record the discrepancy in `STATUS.md` and resolve it deliberately.
