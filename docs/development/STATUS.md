# Project Status

Last updated: 2026-08-07

Release target: 0.1.0 Alpha

Overall state: In Progress — implementation baseline exists; live acceptance remains incomplete

Active task: None

## Current objective

TASK-012 已完成：开发流程现在以一次开发对话对应一个可持续追加范围的 Task。当前没有活动实现任务；等待项目所有者开启下一次开发对话。

## Current implemented baseline

- Native SwiftUI/AppKit menu-bar application with selection translation, screenshot translation, and quick input.
- Nearby result card with streaming, comparison, copy, retry, system speech, pinning, cancellation, target switching, and actionable error states.
- Accessibility selection reader with standard range and Web Text Marker support plus pointer fallback.
- Cross-display ScreenCaptureKit selection, in-memory Vision OCR, stable line order, and text-only translation requests.
- Embedded Rust static library with versioned C ABI, shared async runtime, generic OpenAI-compatible SSE, Qwen-MT adaptation, timeouts, cancellation, and stale-event isolation.
- Grouped Settings, Carbon shortcuts, Keychain credential storage, permission guidance, light/dark appearance, Reduce Motion, and verified test-app packaging.
- Xcode SwiftUI previews for the main menu, Settings, translation-card states, and quick input, with preview-safe fixtures that avoid system integrations.
- Menu setup status that automatically yields to three bounded in-memory recent translations once API, Accessibility, and Screen Recording are ready; selecting a recent result performs no network request and quitting clears the list.
- Single-layer macOS 26 Liquid Glass with a macOS 14–25 system-material fallback across the menu, Settings, result card, quick input, and screenshot-selection labels; screenshot entry icons use the available `viewfinder` symbol.
- Fixed-path Release development packaging that stages, stable-signs, and verifies a new `artifacts/Marla_dev.app` before replacing the previous App; missing stable identities fail instead of falling back to ad-hoc signing.
- Multiple named OpenAI-compatible API profiles with per-profile Keychain credentials, legacy single-endpoint migration, default selection, settings CRUD/reordering, and explicit result-card switching are implemented under TASK-005.
- Every API profile supports explicit Base URL or Complete URL semantics. The editor uses an inline Base/Complete switch and can fetch a Rust-owned `/models` list with the current profile credential, then expand and select a model at the bottom of the form.
- The API editor gives its first scroll-content row an 8pt focus-ring safety inset, keeping the native macOS Focus Ring complete in light and dark appearance.
- Settings use a four-page native sidebar, summary-only API list and independently clipped editor sheet; global shortcuts have persistent switches, result cards support background dragging, and screenshot selection includes an in-memory 6× pointer magnifier.
- Settings use a transparent full-size title bar with traffic lights inside one continuous four-corner surface, hidden scroll indicators, and a fixed `Esc` screenshot-cancellation row. Screenshot selection temporarily suspends an open Settings window and restores it without activating it; `Esc` cancellation is owned by the active selection session rather than a single view's first-responder state.

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

TASK-012 was the latest owner-selected workflow refinement and is now complete; remaining product verification gaps stay separately selectable.

Before implementation, start the next development conversation with a `Ready` then `Active` file from `docs/tasks/TASK_TEMPLATE.md`; keep that Task updated as the project owner adds scope during the conversation.

## Current risks

- A visible VSCodium selection failed in an earlier live build; the latest expanded AX traversal passes automation but still needs live confirmation.
- Screenshot coordinate conversion has unit coverage but not a final visual comparison against the real selected region.
- The fixed-path development App is locally signed, not Developer ID signed or notarized; it is not a public distribution artifact.
- Real DashScope Qwen-MT translation succeeded, but representative TTFT, throughput, and live error mapping remain unmeasured.

## Latest verification

- `./scripts/check.sh` passed on 2026-08-07 after TASK-011.
- Rust: 17 tests passed.
- Swift: 41 tests passed.
- Xcode Debug application build passed.
- SwiftUI preview support compiled in the Swift Package and Xcode Debug build.
- Xcode Preview launched and loaded `__preview.dylib` while the fixed-path development app remained running; Debug allows the Preview host instance while Release remains single-instance.
- `Marla_test_202608060135.app` passed Bundle ID, version, deployment target, arm64, executable, and signature checks.
- Real-app visual scenarios passed the five-dimension SwiftUI review with every dimension at least 7/10.
- TASK-003 menu-recents, Settings, quick-input, comparison-card, and screenshot-selection captures passed the five-dimension rescore at 8/8/8/8/7; evidence is under `artifacts/ui-review/task-003/`.
- `Marla_test_202608061928.app` passed Bundle ID, version, deployment target, arm64, executable, and signature checks.
- TASK-005 settings and streaming-card screenshots passed the five-dimension SwiftUI review at 8/8/8/8/7; evidence is under `artifacts/ui-review/task-005/`.
- `artifacts/Marla_dev.app` was replaced by a no-argument Release build and passed Bundle ID, version, deployment target, arm64, executable, stable-signature, and designated-requirement checks; no timestamped App or staging residue was added.
- TASK-006 settings sidebar/API summary/editor/empty state, light/dark General, Shortcuts, and OCR screenshots passed the five-dimension SwiftUI review at 8/8/8/8/7; evidence is under `artifacts/ui-review/task-006/`.
- TASK-007 API editor, shortcut light/dark, result-card and screenshot-magnifier captures passed the five-dimension SwiftUI review at 8/8/8/8/7; evidence is under `artifacts/ui-review/task-007/`. Direct pointer-drag automation was unavailable for this LSUIElement app, so dragging is verified by AppKit panel configuration and automated regression coverage rather than a simulated mouse gesture.
- TASK-008 unified Settings light, Shortcuts dark, and screenshot-from-open-Settings captures passed the five-dimension SwiftUI review at 8/8/8/8/7; evidence is under `artifacts/ui-review/task-008/`.
- TASK-009 added session-scoped local/global Escape monitors plus idempotent cancellation coverage. After all old fixed-path instances were closed, Computer Use sent real `Escape` events to the sole Release `artifacts/Marla_dev.app`; both ordinary and open-Settings screenshot overlays disappeared without a result card. Evidence and the lock-interrupted final capture note are under `artifacts/ui-review/task-009/`.
- TASK-010 added per-profile Base/Complete URL routing, an inline URL-mode switch, Rust-owned `/models` discovery through C ABI v2, and bottom-of-form model selection. A real `gpt-5.6-luna` Complete URL stream returned “你好”, `finish_reason: stop`, and `[DONE]`; the related `/v1/models` endpoint returned 20 models including `gpt-5.6-luna`. Light/dark Release captures passed the five-dimension review at 8/8/8/8/7 under `artifacts/ui-review/task-010/`. The fixed App retained Bundle ID `com.marla.app`, arm64, Authority `API Usage Monitor Dev`, and its designated requirement.
- TASK-011 added an 8pt scroll-content safety inset above the first API editor field. Frontmost light/dark Release windows captured by verified Core Graphics Window ID show the native blue Focus Ring complete on all four sides; five-dimension scores are 8/8/9/8/7 under `artifacts/ui-review/task-011/`. The fixed App retained Bundle ID `com.marla.app`, arm64, Authority `API Usage Monitor Dev`, and its designated requirement.
- TASK-012 changed development tracking to one evolving Task per implementation conversation. Owner-added scope remains in the same Task with explicit scope-change, acceptance, and verification updates; `git diff --check` and stale-rule searches passed.
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
