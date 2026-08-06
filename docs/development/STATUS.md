# Project Status

Last updated: 2026-08-06

Release target: 0.1.0 Alpha

Overall state: In Progress — implementation baseline exists; live acceptance remains incomplete

Active task: None — awaiting the project owner's next single-task selection

## Current objective

Finish 0.1.0 through small, owner-selected Tasks without expanding the release scope. The next Task should be chosen from the verified gaps in `docs/backlog/BACKLOG.md`; future product ideas remain in `docs/backlog/IDEAS.md` until explicitly promoted.

## Current implemented baseline

- Native SwiftUI/AppKit menu-bar application with selection translation, screenshot translation, and quick input.
- Nearby result card with streaming, comparison, copy, retry, system speech, pinning, cancellation, target switching, and actionable error states.
- Accessibility selection reader with standard range and Web Text Marker support plus pointer fallback.
- Cross-display ScreenCaptureKit selection, in-memory Vision OCR, stable line order, and text-only translation requests.
- Embedded Rust static library with versioned C ABI, shared async runtime, generic OpenAI-compatible SSE, Qwen-MT adaptation, timeouts, cancellation, and stale-event isolation.
- Grouped Settings, Carbon shortcuts, Keychain credential storage, permission guidance, light/dark appearance, Reduce Motion, and verified test-app packaging.
- Xcode SwiftUI previews for the main menu, Settings, translation-card states, and quick input, with preview-safe fixtures that avoid system integrations.

Implementation baseline commit: `88954bb`.

## Release gaps

- Live selection verification remains incomplete in Terminal, Safari, TextEdit, and the final VSCodium build.
- Real screenshot crop accuracy and Screen Recording permission persistence remain unverified across representative display layouts.
- P95 shell latency, Rust-delta-to-visible-Swift latency, and idle/translation/Vision memory budgets have not been measured.
- Force Touch public-API feasibility remains an optional experiment and does not block 0.1.0.
- The unchecked items in `docs/versions/0.1.0/ACCEPTANCE.md` remain authoritative release gaps.

## Next selectable work

1. `BL-001` — cross-application selection translation verification.
2. `BL-002` — real screenshot crop and TCC permission verification.
3. `BL-003` — latency and memory measurement.
4. `BL-004` — optional Force Touch feasibility evidence.

Before implementation, select exactly one item and create a `Ready` then `Active` file from `docs/tasks/TASK_TEMPLATE.md`.

## Current risks

- A visible VSCodium selection failed in an earlier live build; the latest expanded AX traversal passes automation but still needs live confirmation.
- Screenshot coordinate conversion has unit coverage but not a final visual comparison against the real selected region.
- The fixed-path development App is locally signed, not Developer ID signed or notarized; it is not a public distribution artifact.
- Real DashScope Qwen-MT translation succeeded, but representative TTFT, throughput, and live error mapping remain unmeasured.

## Latest verification

- `./scripts/check.sh` passed on 2026-08-06.
- Rust: 16 tests passed.
- Swift: 18 tests passed.
- Xcode Debug application build passed.
- SwiftUI preview support compiled in the Swift Package and Xcode Debug build.
- Xcode Preview launched and loaded `__preview.dylib` while the fixed-path development app remained running; Debug allows the Preview host instance while Release remains single-instance.
- `Marla_test_202608060135.app` passed Bundle ID, version, deployment target, arm64, executable, and signature checks.
- Real-app visual scenarios passed the five-dimension SwiftUI review with every dimension at least 7/10.
- A real DashScope `qwen-mt-turbo` request translated `Hello` to “你好”; the credential remained in Keychain.

## Pending product decisions

Default translation vendor, contextual translation controls, cloud structured OCR controls, persistent history, final app icon, public signing/notarization, and public distribution remain outside the current Task. Their context is recorded in `docs/backlog/IDEAS.md` or accepted ADRs.

## Required Reading

These files are universal for every task:

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/architecture/ARCHITECTURE.md`

The active Task must list any additional UI, implementation, acceptance, feature, data-contract, source, test, and ADR files it actually requires.
