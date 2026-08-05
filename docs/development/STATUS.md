# Project Status

Last updated: 2026-08-05

Current milestone: 0.1.0 Alpha — Phase 1 App foundation

Overall state: In Progress

## Current objective

Deliver the bilingual 0.1.0 contract, then build a stable native macOS `.app` with deterministic Rust linking as the foundation for the three accepted translation entry points.

## Completed

- Initial product definition and UX principles accepted.
- The bilingual 0.1.0 product, UI, implementation, and acceptance specifications are accepted under `docs/versions/0.1.0/`.
- 0.1.0 scope is locked to selection translation in a nearby card, Vision-only screenshot OCR, quick input, and a configurable OpenAI-compatible text translation endpoint.
- The `swiftui-design-skill` is installed and its anti-slop, typography, layout, and five-dimension review requirements are incorporated into `UI_SPEC.md`.
- Native SwiftUI/AppKit presentation and platform-integration architecture accepted.
- Embedded Rust business-core architecture accepted in ADR-0004.
- Cloud GLM-OCR remains accepted for post-0.1.0; ADR-0005 selects Vision as the only 0.1.0 OCR provider.
- Bounded on-demand context remains a future architecture; all contextual window data is disabled for 0.1.0.
- Feature specifications and durable documentation workflow established.
- Swift Package application and core-domain skeleton compile with full Xcode 26.5 and Swift 6.3.2.
- Seven Swift tests and two Rust tests pass.
- Accessibility selected-text reader, optional selection bounds acquisition, permission request flow, and a menu-bar probe are implemented.
- The Rust static library, versioned C ABI, C header, Swift wrapper, and application-surface classifier are linked and tested end to end.
- The selection probe consumes Rust surface classification from the source application's Bundle ID.
- A repeatable `scripts/check.sh` verification entry point is available for agents and local development.

## In progress

- Creating a proper Xcode macOS App target with Bundle ID `com.marla.app`, permission declarations, and deterministic Debug/Release Rust build phases.
- Replacing temporary technical-probe UI and outdated cloud-OCR settings with the accepted 0.1.0 surfaces.
- Preparing versioned JSON/FFI translation handles and an OpenAI-compatible streaming provider in Rust.

## Next

1. Introduce the Xcode app target, stable Bundle ID, permissions, Rust configuration-aware build phase, and timestamped test-app packaging.
2. Implement the version 1 JSON/FFI contract, request handles, cancellation, SSE parsing, Keychain-backed settings, and mock-provider tests.
3. Deliver the `⌃⌥D` selection-translation vertical slice with a nearby non-activating result card.
4. Deliver `⌃⌥S` cross-display capture, Vision OCR, and text-only translation.
5. Deliver `⌃⌥Space` quick input, comparison, copy, retry, system speech, pinning, language switching, and shortcut recording.
6. Run Force Touch feasibility, compatibility, performance, memory, privacy, and real-app visual acceptance; package a verified timestamped `.app`.

## Pending decisions

- No decision required to implement the accepted 0.1.0 scope.
- A default translation vendor, cloud GLM-OCR provider, contextual translation, persistent history, final app icon, and public distribution remain post-0.1.0 decisions.

## Risks and validation gaps

- Full Xcode 26.5 is installed and works when selected through project-local `DEVELOPER_DIR`; the system-wide active developer directory remains Command Line Tools.
- The repository does not yet contain an Xcode application project. SwiftPM currently produces a bare Mach-O executable rather than a stable `.app`, so TCC persistence, entitlements, signing, and real permission onboarding are not yet validated.
- The current FFI only covers API versioning and surface classification. Async request handles, cancellation, callback threading, and payload ownership remain to be implemented and tested before network providers cross the boundary.
- Current placeholder Settings still expose cloud structured OCR and do not implement the accepted API, shortcuts, or permission groups. This is a recorded implementation gap, not accepted 0.1.0 behavior.
- Cross-application Force Touch may not be supported reliably by public global event APIs.
- Accessibility selection geometry varies by application and may require nearby-panel degradation.
- Cloud latency targets remain unverified with representative local-region traffic.

## Verification — 2026-08-05

- `scripts/check.sh`: passed.
- `cargo fmt --all --check`: passed.
- `cargo test --workspace`: 2 tests passed, 0 failures.
- `cargo build --workspace`: passed; Rust static library produced.
- `swift build --disable-sandbox`: passed using Xcode 26.5 / Swift 6.3.2.
- `swift test --disable-sandbox`: 7 tests passed, 0 failures, including the linked Rust bridge.
- `git diff --check`: passed.
- 0.1.0 bilingual document structure, required-file presence, contradiction search, and source whitespace checks: passed on 2026-08-05.
- Manual Accessibility permission, cross-application selection, bounds accuracy, and UI interaction: pending until a stable `.app` target exists.

## Required reading

- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/UI_SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/DATA_CONTRACTS.md`
- `docs/features/inline-translation.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0002-ocr-strategy.md`
- `docs/architecture/decisions/ADR-0003-context-engine.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `docs/architecture/decisions/ADR-0005-vision-only-ocr-for-0.1.0.md`
