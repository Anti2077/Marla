# TASK-001: SwiftUI Preview Support

Status: Completed

Owner: Project owner + Agent

Created: 2026-08-06

Updated: 2026-08-06

Origin: direct request

## Outcome

Xcode can render representative Marla SwiftUI surfaces from Canvas/Preview without running the full app workflow.

## Why now

The project owner is learning where the UI lives and how to inspect it in Xcode. Preview fixtures reduce friction while keeping runtime behavior unchanged.

## In Scope

- Add Xcode `#Preview` entries for the main SwiftUI surfaces.
- Keep preview state deterministic and isolated from production UserDefaults, Keychain, global shortcuts, event monitors, screenshots, and live translation requests.
- Verify the project still builds and tests.
- Update task and status documentation.

## Out of Scope

- Redesigning Marla UI.
- Changing 0.1.0 product behavior, visual acceptance criteria, or runtime translation flows.
- Adding new production features.

## Current evidence

- `Sources/MarlaApp/MarlaApp.swift` contains the main SwiftUI surfaces.
- `Sources/MarlaApp/SettingsView.swift` contains Settings UI.
- The repository currently has no `#Preview` or `PreviewProvider` entries.
- Directly constructing `MarlaApplicationModel` in previews would initialize system integrations unless guarded.

## Proposed approach

Add a lightweight preview/runtime guard, allow preview-safe model construction, and add a separate `MarlaPreviews.swift` file with fixture helpers and representative previews.

## Acceptance criteria

- [x] Xcode exposes named previews for Menu Bar, Settings, result-card states, and Quick Input.
- [x] Preview fixtures avoid registering global hotkeys or event monitors.
- [x] Production app initialization remains unchanged outside Xcode Preview or explicit preview fixture construction.
- [x] Relevant automated verification passes.
- [x] `STATUS.md` reflects the verified state.

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

Open `Sources/MarlaApp/MarlaPreviews.swift` in Xcode, show Canvas with `Option + Command + Return`, and select the named previews.

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/architecture/ARCHITECTURE.md`
- `Sources/MarlaApp/MarlaApp.swift`
- `Sources/MarlaApp/SettingsView.swift`
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Risks and rollback

- Preview fixture code could accidentally alter runtime initialization. Keep preview guards explicit and covered by build/tests.
- Rollback is removing `MarlaPreviews.swift` and the preview-safe initializer parameters.

## Decisions needed

None.

## Completion record

- Verified commit: pending
- Automated evidence: `./scripts/check.sh` passed on 2026-08-06 with 16 Rust tests, 18 Swift tests, Xcode Debug app build, whitespace validation, and `git diff --check`.
- Manual evidence: Xcode Canvas use documented; no real-app UI behavior changed.
- Documentation updated: `docs/development/STATUS.md`; this task file.
- Remaining work promoted to: None.
