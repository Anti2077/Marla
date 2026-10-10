# Project Status

Last updated: 2026-10-11

Development stage: Incubation / Unreleased

Release target: None. A version is assigned only when the project owner explicitly starts release preparation.

Overall state: In Progress — unversioned product incubation; no active release contract

Scope: This document records the locally integrated and verified baseline of target branch `main`. It is not a registry for unmerged feature-worktree Tasks. Completed implementation detail belongs in tracked Tasks, [`VERIFICATION.md`](VERIFICATION.md), and Git.

## Current integrated baseline

- Marla is a native SwiftUI/AppKit menu-bar translation layer with four explicit entry points: selected text, ordinary screenshot translation, experimental in-place screenshot translation, and Quick Input.
- Selection content uses one protected simulated-Copy transaction with complete Pasteboard backup/restore and source-application verification. Accessibility supplies permission and optional non-content geometry only; it is not a text-content fallback.
- Screenshot selection uses same-session frozen ScreenCaptureKit frames across displays. Ordinary screenshot translation supports visible-window targeting, drag-time Space panning, notch-safe guidance, and session-only `1/2/3` OCR choice without changing the saved default.
- Vision remains the default local OCR path. Ordinary screenshots may explicitly use cloud GLM-OCR or a user-managed local Ollama `glm-ocr` Provider and still present a nearby result card. The independent in-place path is default-off, cloud-GLM-only, memory-only, and never estimates layout with Vision.
- The nearby result card supports streaming, semantic Markdown, native GFM and bounded HTML tables, comparison, copy, retry, speech, pinning, cancellation, target/profile switching, deterministic automatic placement, and 380–760pt responsive width.
- The three in-memory recent translations support independent result restoration plus hover/focus-revealed actions for copying the full canonical translation or source without changing the active session or history order.
- Translation profiles support OpenAI-compatible Chat Completions, OpenAI Responses, Anthropic Messages, and Google Gemini Generate Content. Qwen-MT and Provider-specific thinking behavior remain bounded adapters rather than inferred protocols; the documented OpenAI-compatible `qwen-mt-flash`/`qwen-mt-lite` families now use incremental stream deltas, while legacy `qwen-mt-turbo`/`qwen-mt-plus` and other Qwen-MT names retain cumulative normalization.
- Global native/secondary language routing supports Simplified Chinese, English, Japanese, French, Spanish, German, and Korean. Credentials stay in a versioned Keychain vault; screenshots, OCR geometry, overlay render plans, and translations are not persisted as screenshot artifacts.
- Swift 6, SwiftUI/AppKit, the embedded Rust core, C ABI v4, request schema v4, strict cancellation/timeouts, structure gates, and the project verification wrapper remain the implementation boundary.
- Development Apps use the non-public `0.0.0` Marketing Version sentinel. Fixed-path Release packaging is locally stable-signed and verified; no Developer ID, notarized, updater, or public distribution artifact exists.
- The primary worktree `/Users/anti/Documents/ChatGPT/Marla` exclusively owns local `main`, integration, target-branch verification, `STATUS.md`, final global documentation, and separately authorized push/cleanup. Feature worktrees use one bounded Task and finish at `Ready for integration`.
- Primary integration is guarded by `scripts/main-worktree.sh`: it verifies the real primary checkout and symbolic `main`, rejects in-progress or dirty state, validates the Task branch and linked feature worktree, requires current-main ancestry, and performs only a no-fast-forward merge.

## Recent integrated changes

- [`TASK-046`](../tasks/TASK-046-screenshot-selection-efficiency.md) added ordinary screenshot window targeting, drag-time Space panning, per-session OCR switching, and notch-safe guidance.
- [`TASK-047`](../tasks/TASK-047-release-homepage-links.md) integrated GitHub Releases and author links across the website and multilingual repository README without claiming a public release.
- [`TASK-048`](../tasks/TASK-048-parallel-worktree-workflow.md) established primary-main ownership, isolated feature Tasks, `Ready for integration`, and separate merge/verification/push/cleanup states.
- [`TASK-049`](../tasks/TASK-049-main-integration-guard-and-status-hygiene.md) added the executable primary-worktree guard and reduced this file to current-state information.
- [`TASK-050`](../tasks/TASK-050-history-quick-copy.md) added compact hover/focus history-copy controls, native source-copy menu tracking, clipboard isolation, and accessible copy actions.
- [`TASK-052`](../tasks/TASK-052-qwen-mt-stream.md) corrected Qwen-MT Flash/Lite incremental stream handling while preserving strict cumulative normalization for legacy Qwen-MT families.

## Open acceptance gaps

- [`RV-005`](VERIFICATION.md#rv-005glm-ocr-真实凭据成功路径) still requires latest fixed-App real GLM/Qwen completion and current Markdown/GFM in-place rendering confirmation. The implementation and synthetic evidence remain recorded in [`TASK-041`](../tasks/TASK-041-in-place-screenshot-translation.md).
- [`RV-006`](VERIFICATION.md#rv-006普通截图翻译-glm-ocr-识别中的主动降级) still requires owner confirmation that manual GLM-to-Vision fallback cancels the current request, reuses the same captured screenshot, and performs no duplicate upload.
- [`RV-007`](VERIFICATION.md#rv-007本机-ollama-glm-ocr-普通截图路径) still requires real local Ollama OCR-to-translation-to-native-table acceptance, including cancel/fallback, copy, and light/dark window behavior.
- Fixed-App interaction evidence remains open for TASK-046 window snapping, Space panning, three temporary OCR choices, saved-default preservation, and light/dark/narrow/Reduce Motion behavior.
- Additional owner-only evidence remains in the existing records for TASK-042 automatic placement, TASK-044 live four-protocol accounts and UI review, expanded-language screenshots, and physical Fn/Globe shortcut behavior. Their historical lifecycle labels are not reclassified here.
- TASK-047 still lacks an actual deployed website URL, first public GitHub Release, and independent narrow-screen field capture. These are publication inputs, not proof that a release already exists.

## Current risks and product decisions

- Marla remains locally signed and unreleased. Public version, Developer ID signing, notarization, distribution, update delivery, and rollback policy are unselected.
- Independent in-place translation is intentionally experimental and default-off. It covers only an explicitly captured frozen region and must remain reversible and memory-only.
- Cross-application selection reliability depends on the protected Copy transaction. Browser extensions, Services, PopClip integration, and Accessibility text fallback are not current plans.
- Real Provider latency, throughput, account-specific error mapping, and broad live-account coverage remain narrower than the automated protocol evidence.
- Default translation vendor, contextual translation controls, persistent history, public distribution, and durable terminology learning remain unselected future product decisions.
- Open owner acceptance does not automatically block unrelated incubation Tasks. A reproducible defect discovered during acceptance receives its own bounded Task.

## Next selectable work

There is no single global Active-Task slot. The project owner may complete an existing owner-only acceptance item or select one bounded feature/fix/documentation Task. The primary integration owner assigns its unique Task ID, branch, worktree, ownership, dependencies, and merge order before implementation.

## Latest verification

- On the real primary worktree after the TASK-050 merge, `./scripts/main-worktree.sh check` verified `/Users/anti/Documents/ChatGPT/Marla` on symbolic `main` before final documentation updates.
- `MARLA_BUILD_CACHE_ROOT=/private/tmp/marla-task-050-main-cache ./scripts/check.sh` passed on the final documented `main`: 52 Rust tests, 272 Swift tests, Swift Package build/test, Xcode Debug, structure, all shell syntax, source whitespace, and `git diff --check`. Existing Swift 6/AppKit actor warnings remain baseline warnings.
- After TASK-052 integration, `MARLA_BUILD_CACHE_ROOT=/private/tmp/marla-task-052-main-cache ./scripts/check.sh` passed on merged `main`: 58 Rust tests, 272 Swift tests, Swift Package build/test, Xcode Debug, structure, all shell syntax, source whitespace, and `git diff --check`. The fixed Release development App was separately built and verified with the existing stable local signature.
- TASK-050's signed fixed Release App, real clipboard actions, accessibility actions, and project-owner hover/split-control acceptance remain recorded in the Task. The integration did not rebuild the unchanged feature artifact.

## Required Reading

These files are universal for every Task:

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/development/VERSIONING.md`
- `docs/architecture/ARCHITECTURE.md`

The current worktree Task lists any additional UI, implementation, acceptance, feature, data-contract, source, test, and ADR files it actually requires.
