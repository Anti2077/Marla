# Project Status

Last updated: 2026-08-06

Current milestone: 0.1.0 Alpha — native UI and translation vertical slice

Overall state: In Progress

## Current objective

Complete the remaining live interaction checks for the native SwiftUI/AppKit 0.1.0 shell around the real Rust streaming translation core. The current worktree contains all three entry points, local Vision OCR, provider-specific Qwen-MT compatibility, grouped Settings, Carbon shortcuts, Keychain storage, cancellation-safe sessions, and a verified arm64 Release test app. Remaining acceptance depends on representative cross-application and screenshot interaction plus performance measurements.

## Completed

- 0.1.0 scope is locked to selection translation in a nearby card, Vision-only screenshot OCR, quick input, and configurable OpenAI-compatible text translation. Cloud GLM-OCR, history, contextual window data, in-place replacement, and document workspaces remain out of scope.
- SwiftUI/AppKit uses the accepted Warm Minimal direction, semantic system colors, SF Pro typography, 4/8pt spacing tokens, system accent color, Reduce Motion handling, tooltips, selectable translation text, and no emoji, gradients, AI SVG, neon theme, or left-rail card pattern.
- Menu-bar Popover exposes the three entries, onboarding checklist, API/Accessibility/Screen Recording status, current session status, Settings, and Quit.
- Selection translation reads selected text without overwriting the source application or clipboard, searches a bounded Accessibility descendant tree, supports standard ranges and Web Accessibility Text Marker ranges used by Electron editors, prefers selection bounds, falls back to the trigger-time pointer, and clamps cards to the visible work area.
- Screenshot translation uses one AppKit overlay per active display, shared cross-display selection state, negative-coordinate support, Retina-aware per-display ScreenCaptureKit capture with explicit AppKit-bottom-left to display-top-left conversion, in-memory Vision OCR, stable OCR line IDs, reading order, and plain-text-only Rust requests.
- Quick Input uses a focused multi-line TextEditor, preserves IME and pasted whitespace, validates blank input without changing the submitted source, supports `⌘Return` and `Esc`, and morphs the same card into the result state.
- Result cards support awaiting, streaming, completed, comparison, partial failure, cancellation, retry, copy feedback, system speech, pinning, target-language switching, outside-click/Esc dismissal, and request-ID stale-event isolation.
- Settings uses native grouped sections for Translation API, shortcuts, permissions, and Force Touch experiment. API Keys are stored only in Keychain; Base URL, model, target language, and non-sensitive preferences use app settings. The retired `cloudStructuredOCR` switch is absent.
- Rust FFI owns copied request bytes and opaque cancellation-safe handles. The provider implements generic OpenAI-compatible streaming plus Qwen-MT request adaptation (`translation_options`, no system role), cumulative-to-incremental delta normalization, HTTP-200 SSE provider errors, `[DONE]` and `finish_reason` completion, UTF-8 framing, timeouts, interruption, and panic isolation without logging secrets or text.
- Explicit UI automation fixtures are opt-in through `MARLA_UI_TEST_SCENARIO`; normal production entry points always use the real Rust and Vision paths. The fixtures can render their own real-app window to a PNG for visual review without capturing the desktop or persisting user screenshots.
- The fixed-path signed app has received one-time Keychain authorization, and the real `translation-live` path translated `Hello` to “你好” through the configured DashScope `qwen-mt-turbo` endpoint.

## In progress

- Unlock the Mac and complete the latest VSCodium and screenshot result-card verification.
- Manual verification of Accessibility and Screen Recording persistence, selection behavior in Terminal/Safari/TextEdit, and real crop accuracy on single- and mixed-scale multi-display layouts.
- Measurement of P95 shell visibility, Rust-delta-to-Swift latency, and memory ceilings on representative translation/OCR workloads.
- Public-API Force Touch feasibility check; it remains disabled by default and is not a release blocker.

## Next

1. Manually unlock the Mac, then repeat the VSCodium result-card and real screenshot-crop checks against `artifacts/Marla_dev.app`.
2. Perform the remaining cross-application, permission-persistence, performance, and memory checks; leave unsupported claims unchecked.
3. Decide whether the Alpha is ready for a separate release action. Commit, push, and public release are outside this task.

## Pending decisions

- No decision is required for the accepted 0.1.0 scope.
- A default translation vendor, cloud GLM-OCR, contextual translation, persistent history, final app icon, public signing/notarization, and public distribution remain post-0.1.0 decisions.

## Risks and validation gaps

- A controlled VSCodium run kept the Monaco/Markdown sentence visibly selected but the earlier reader still returned “no selection.” The follow-up build now merges `AXChildren`, `AXVisibleChildren`, contents, and rows, prioritizes text/WebArea nodes, and accepts attributed-string Text Marker output. Automated checks pass, but the Mac locked before this final build could be live-retested. Terminal/Safari/TextEdit also remain unverified.
- Screenshot source-rectangle conversion is covered by negative-origin and scaled-compositing tests, but a real post-fix crop has not yet been manually compared with its selection rectangle. Screen Recording permission persistence also remains unverified.
- Stable-path development packaging now uses the persistent local `API Usage Monitor Dev` identity. `artifacts/Marla_dev.app` passes strict structural signature verification and has a certificate-root designated requirement; Gatekeeper distribution assessment still rejects it because it is not Developer ID signed or notarized.
- The configured DashScope Qwen-MT endpoint passed a real connection test. Representative TTFT/throughput measurements and live error-mapping checks are still absent.
- Test-only UI snapshots do not prove that Marla itself retains Screen Recording authorization or that the selected screenshot crop is correct.
- Memory and P95 performance budgets are specified but not yet measured with representative workloads.
- Cross-application Force Touch may not be supported reliably by public global event APIs.

## Verification — 2026-08-06

- `./scripts/check.sh`: passed on 2026-08-06 after the final Qwen-MT, expanded Web Text Marker traversal, and screenshot-coordinate changes (Rust mock-provider tests run with loopback permission).
- `cargo fmt --all --check`: passed.
- `cargo test --workspace`: 16 tests passed, 0 failures.
- `swift build --disable-sandbox`: passed with Xcode 26.5 / Swift 6.3.2.
- `swift test --disable-sandbox`: 18 tests passed, 0 failures.
- Release build and ad-hoc verification: `artifacts/Marla_test_202608060135.app` passed Bundle ID, version, deployment target, arm64, executable, and signature checks. Cargo now fixes `MACOSX_DEPLOYMENT_TARGET=14.0` for Rust and native dependencies, eliminating the earlier newer-target linker warnings.
- Stable local development build: the final Qwen-MT, expanded Web Text Marker traversal, and screenshot-coordinate source was rebuilt to `artifacts/Marla_dev.app` with `API Usage Monitor Dev`; Bundle ID, version, deployment target, arm64 architecture, executable, and strict signature checks passed. It is intentionally not claimed as Gatekeeper-approved distribution software.
- A real DashScope connection test succeeded with `qwen-mt-turbo`; the credential remained in Keychain and is not recorded in repository files or diagnostics.
- On macOS 26+, result and quick-input cards use SwiftUI Liquid Glass; macOS 14–25 use the material fallback. Explicit off-screen UI capture selects the fallback because the automation renderer cannot reliably rasterize Liquid Glass; normal production launches do not enable that fallback.
- Real-app visual scenarios rendered and inspected for menu, quick input, awaiting, streaming, comparison, partial failure, long text, Settings, screenshot selection, light/dark appearance, and Reduce Motion.
- `git diff --check`: passed as part of `./scripts/check.sh`.

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
