# TASK-002: Xcode Preview Launch Reliability

Status: Completed

Owner: Project owner + Agent

Created: 2026-08-06

Updated: 2026-08-06

Origin: direct request / defect

## Outcome

Xcode SwiftUI Preview can launch while the fixed-path development app is already running, so UI iteration can happen without quitting Marla first.

## Why now

The project owner wants a high-quality visual workflow where Agents can inspect and tune SwiftUI surfaces through Xcode Preview during development.

## In Scope

- Diagnose the current Xcode Preview launch failure.
- Adjust Debug/Preview app launch configuration without changing Release behavior.
- Verify Swift Package and Xcode Debug builds still pass.
- Update `STATUS.md`.

## Out of Scope

- Redesigning UI surfaces.
- Changing production translation, OCR, shortcut, or permission flows.
- Public signing/notarization changes.

## Current evidence

- Xcode compiled `MarlaPreviews.swift` and generated `__preview.dylib`.
- Canvas reports `Failed to launch com.marla.app`.
- A fixed-path `artifacts/Marla_dev.app` process is already running with Bundle ID `com.marla.app`.
- The built Debug app has `LSMultipleInstancesProhibited = true`, which blocks a second preview host instance with the same Bundle ID.

## Proposed approach

Use a Debug-specific Info.plist so Debug and Xcode Preview builds set `LSMultipleInstancesProhibited` to false while Release keeps the production Info.plist value true.

## Acceptance criteria

- [x] Debug/Xcode Preview builds have `LSMultipleInstancesProhibited = false`.
- [x] Release builds have `LSMultipleInstancesProhibited = true`.
- [x] `./scripts/check.sh` passes.
- [x] Documentation reflects the verified state.

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

With `artifacts/Marla_dev.app` running, open `Sources/MarlaApp/MarlaPreviews.swift` in Xcode and refresh Canvas.

## Required Reading

- `docs/development/STATUS.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/architecture/ARCHITECTURE.md`
- `Resources/Info.plist`
- `Marla.xcodeproj/project.pbxproj`
- `Sources/MarlaApp/MarlaPreviews.swift`

## Risks and rollback

- Incorrect Info.plist preprocessing could break app metadata. Verify processed Debug and Release plists.
- Rollback by restoring a literal `LSMultipleInstancesProhibited` value.

## Decisions needed

None.

## Completion record

任务完成时填写：

- Verified commit: pending
- Automated evidence: `./scripts/check.sh` passed on 2026-08-06 with 16 Rust tests, 18 Swift tests, the Xcode Debug app build, whitespace validation, and `git diff --check`; processed Debug and Release plists report `false` and `true` respectively for `LSMultipleInstancesProhibited`.
- Manual evidence: while `artifacts/Marla_dev.app` remained running, Xcode launched a second `com.marla.app` process that loaded `__preview.dylib` and OOP JIT Preview artifacts.
- Documentation updated: `docs/development/STATUS.md`; this task file.
- Remaining work promoted to: None.
