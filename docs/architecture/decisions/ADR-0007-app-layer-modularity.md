# ADR-0007: Layered application structure and structure gates

Status: Accepted

Date: 2026-08-14

## Context

The application layer grew `Sources/MarlaApp/MarlaApplicationModel.swift` into a single file of approximately 3,893 lines containing about 45 top-level types across Keychain, settings, translation sessions, the floating panel, shortcuts, screenshot selection, Vision OCR, and application lifecycle. TASK-024 extracted only a 31-line service container, leaving the file structurally unchanged. Without an explicit layout rule and an enforceable gate, any future subsystem would be appended to the same large file and the problem would recur as the product grows.

## Decision

Organize `Sources/MarlaApp/` into single-direction layers and enforce structure mechanically:

1. **Layered directories.** Dependencies may point only from an upper layer to a lower layer; reverse and cyclic dependencies are forbidden:

   ```text
   App → Settings/Sessions/Panel/Screenshot/Selection/OCR/Shortcuts → Persistence → Models
   ```

   `Models` is the bottom layer and must not import `AppKit` or `SwiftUI`.

2. **Structure gates.** A zero-dependency `scripts/check-structure.sh` runs as part of `scripts/check.sh` and fails when any source file exceeds 800 lines, any file declares more than 8 top-level types, or `Sources/MarlaApp/Models/` imports a UI framework. The 800/8 thresholds are the initial baseline that lets mechanical file-splitting land; they tighten as the orchestrator itself shrinks.

3. **Placement rule.** A new subsystem or a group of strongly related types must be created as new source files in the matching layer, never appended to `MarlaApplicationModel.swift` or to any file near a gate limit. This rule is also recorded in `AGENTS.md` and default acceptance criteria in `TASK_TEMPLATE.md`.

Implementation of the split itself is tracked by TASK-025; this ADR records the durable structure and gate policy, not the mechanical move.

## Consequences

- Regression risk from editing one giant file is removed; responsibility boundaries become reviewable.
- Structure health is verified on every `./scripts/check.sh` run, so oversized files fail the build instead of being silently tolerated.
- The orchestrator `MarlaApplicationModel` is intended to shrink further (target ≤ 400 lines) through later logical extraction; the 800-line gate is deliberately looser than the long-term 600-line target until that work lands.
- Keeping one SwiftPM target avoids multiplying the hand-maintained `project.pbxproj` cost; splitting into multiple library modules is deferred until a real boundary-enforcement or compile-time need appears.
