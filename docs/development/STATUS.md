# Project Status

Last updated: 2026-08-10

Release target: 0.1.0 Alpha

Overall state: In Progress — implementation baseline exists; live acceptance remains incomplete

Active task: [TASK-018](../tasks/TASK-018-frozen-screenshot-selection.md) — 冻结全屏截图框选

Blocked tasks:

- [TASK-013](../tasks/TASK-013-api-profile-activation-and-editor-actions.md) — 等待项目所有者确认拖拽动态中间态
- [TASK-016](../tasks/TASK-016-keychain-credential-prefetch.md) — 等待项目所有者在干净 Keychain 授权状态复验启动与首次翻译
- [TASK-017](../tasks/TASK-017-inline-streaming-overlay-feasibility.md) — 等待项目所有者复验原位/附近译文条和关闭生命周期

## Current objective

项目所有者确认不继续系统式虚拟指针路线，选择在 `Anti2077/screenshot-hover-preservation` 分支实现截图快捷键触发瞬间的全显示器内存冻结：框选层、未调暗选区、放大镜和最终 Vision 裁剪必须来自同一组静态帧，避免真实指针移动或 Marla 激活后丢失悬停界面。TASK-017 保留已实现原型并转为等待复验的 Blocked；TASK-016 与 TASK-013 继续保持 Blocked。

## Current implemented baseline

- Native SwiftUI/AppKit menu-bar application with selection translation, screenshot translation, and quick input.
- Nearby result card with streaming, comparison, copy, retry, system speech, pinning, cancellation, target switching, and actionable error states.
- Accessibility selection reader with standard range and Web Text Marker support, trigger-time frontmost-app binding, frontmost-app/window/focused roots, identity-checked system focused-application roots, dual application/system-wide pointer hit paths, renderer/helper identity checks, global graph deduplication, ungated AX child probes, and bounded pointer fallback.
- Default-off Copy compatibility that snapshots every readable pasteboard representation, accepts only a new Copy result, restores on success/failure/cancellation, avoids overwriting a newer external write, rejects focus changes, and reports only redacted lifecycle evidence.
- Default-off single-line in-place translation feasibility surface that reuses the existing streaming session. Its first real Copy compatibility test exposed a missing-bounds fallback defect; the repaired build adds an honestly labeled pointer-near mode while preserving the complete card for multi-line, long, or unsafe input.
- Pre-selection full-display ScreenCaptureKit freezing with Marla-window exclusion, same-frame cross-display selection/loupe/crop composition, in-memory Vision OCR, stable line order, and text-only translation requests.
- Embedded Rust static library with versioned C ABI, shared async runtime, generic OpenAI-compatible SSE, Qwen-MT adaptation, timeouts, cancellation, and stale-event isolation.
- Grouped Settings, Carbon shortcuts, Keychain credential storage, permission guidance, light/dark appearance, Reduce Motion, and verified test-app packaging.
- Xcode SwiftUI previews for the main menu, Settings, translation-card states, and quick input, with preview-safe fixtures that avoid system integrations.
- Menu setup status that automatically yields to three bounded in-memory recent translations once API, Accessibility, and Screen Recording are ready; selecting a recent result performs no network request and quitting clears the list.
- Single-layer macOS 26 Liquid Glass with a macOS 14–25 system-material fallback across the menu, Settings, result card, quick input, and screenshot-selection labels; screenshot entry icons use the available `viewfinder` symbol.
- Fixed-path Release development packaging that stages, stable-signs, and verifies a new `artifacts/Marla_dev.app` before replacing the previous App; missing stable identities fail instead of falling back to ad-hoc signing.
- Multiple named OpenAI-compatible API profiles with one versioned Keychain vault, legacy single-endpoint/per-profile migration, shared in-memory credentials, default selection, settings CRUD/reordering, and explicit result-card switching are implemented under TASK-005/TASK-016.
- Every API profile supports explicit Base URL or Complete URL semantics. The editor uses an inline Base/Complete switch and can fetch a Rust-owned `/models` list with the current profile credential, then expand and select a model at the bottom of the form.
- The API editor gives its first scroll-content row an 8pt focus-ring safety inset, keeping the native macOS Focus Ring complete in light and dark appearance.
- Settings use a four-page native sidebar, summary-only API list and independently clipped editor sheet; global shortcuts have persistent switches, result cards support background dragging, and screenshot selection includes an in-memory 6× pointer magnifier.
- Settings use a transparent full-size title bar with traffic lights inside one continuous four-corner surface, hidden scroll indicators, and a fixed `Esc` screenshot-cancellation row. Screenshot selection temporarily suspends an open Settings window and restores it without activating it; `Esc` cancellation is owned by the active selection session rather than a single view's first-responder state, with window key-equivalent/cancel-operation routing and a listen-only event-tap fallback.
- Translation API profiles have persistent enabled states and only enabled profiles can be selected or invoked. The summary list uses native switches, a Set Default/Delete menu, accessibility move actions, and a trailing reorder handle. Settings content no longer moves the window; the newest fixed App uses a complete-row drag preview and 220ms animated hover reordering, pending owner confirmation of that final pointer feedback.
- Project-scoped Serena 1.6.1 provides read-only Swift/Rust semantic navigation through Codex. A custom Context and fixed tool allowlist expose only nine retrieval/diagnostic tools; source edits, shell, project switching, onboarding, memories, Dashboard, and Headroom remain disabled.

Implementation baseline commit: `88954bb`.

## Release gaps

- Full release selection verification remains incomplete in Terminal, Safari, TextEdit, Zen, Ghostty, and the final VSCodium build.
- Real screenshot `Esc` cancellation needs re-verification after the project owner reproduced a regression against the older TASK-009 evidence.
- Real screenshot crop accuracy and Screen Recording permission persistence remain unverified across representative display layouts.
- P95 shell latency, Rust-delta-to-visible-Swift latency, and idle/translation/Vision memory budgets have not been measured.
- Force Touch public-API feasibility remains an optional experiment and does not block 0.1.0.
- The unchecked items in `docs/versions/0.1.0/ACCEPTANCE.md` remain authoritative release gaps.

## Next selectable work

TASK-013 is not selectable until the project owner confirms its pending drag-preview motion in the existing fixed App.

1. `BL-001` — cross-application selection translation verification.
2. `BL-002` — real screenshot crop and TCC permission verification.
3. `BL-003` — latency and memory measurement.
4. `BL-004` — optional Force Touch feasibility evidence.

TASK-014 is complete; remaining product verification gaps stay separately selectable.

TASK-015 已完成；剩余发布矩阵继续保留在 BL-001，截图 `Esc` 与裁剪/权限复验保留在 BL-002。

## Current risks

- A visible VSCodium selection failed in an earlier live build; the latest AX/Copy chain passes automation and the project owner has now confirmed one formerly failing Codex selection plus clipboard restoration. A WeChat selection also reached the real translation request and returned Provider `unauthorized`, proving text acquisition; its clipboard/focus checks, Zen, Ghostty, VSCodium, and the remaining matrix still need current-build confirmation.
- Community evidence (SelectedTextKit/Easydict and portable-translator) and project-owner testing of Bob identify simulated `⌘C` with pasteboard backup/restore as the key compatibility path for custom Electron/WeChat surfaces. TASK-015 implements that path behind a default-off setting; remaining cross-application geometry/focus/clipboard proof belongs to BL-001. Copy-menu, browser, and PopClip/Service bridges remain future IDEA-011 slices.
- Screenshot coordinate conversion has unit coverage but not a final visual comparison against the real selected region.
- The fixed-path development App is locally signed, not Developer ID signed or notarized; it is not a public distribution artifact.
- Real DashScope Qwen-MT translation succeeded, but representative TTFT, throughput, and live error mapping remain unmeasured.

## Latest verification

- TASK-018 captures every active display before presenting selection windows, excludes Marla's own windows, redraws the background/undimmed selection/loupe from the same frozen frame set, and composites the final crop without a second live capture. Cross-display mixed-scale layout tests pass; `./scripts/check.sh` passes 17 Rust and 83 Swift tests plus Swift/Xcode Debug, and the stable-signed fixed Release passes packaging. Three 3420×2224 Release captures under `artifacts/ui-review/task-018/` cover light, dark, and Reduce Motion and score 8/8/8/7/7. Real hover/video, physical multi-display, real `Esc`, and memory recovery remain pending owner acceptance.
- TASK-017 live owner feedback invalidated the first prototype's missing-geometry behavior: the experiment toggle persisted, but the real shortcut still showed the original 380×300 result card because Copy compatibility returns no bounds. The repair now converts AX top-left coordinates to AppKit, places short single-line missing-bounds selections in a visibly labeled “附近” pointer-estimate bar, and keeps the complete card for multi-line, long, or unsafe input. `./scripts/check.sh` passes 17 Rust and 81 Swift tests plus Swift/Xcode Debug; the repaired stable-signed Release passes packaging, and new light/dark/Reduce Motion `inline-estimated` captures score 8/8/8/7/7. Project-owner re-verification of the real shortcut remains pending.
- TASK-017's first prototype passes 17 Rust and 79 Swift tests plus the Swift/Xcode Debug build. New coverage verifies default-off persistence, eligible negative-coordinate placement, visible-frame clamping, missing/multi-line/tall/edge-crossing rejection, compact non-draggable panel styling, and terminal expand/close transitions. The stable-signed fixed Release App passed packaging verification; light, dark, and Reduce Motion `inline-streaming` captures are under `artifacts/ui-review/task-017/` and score 8/8/8/7/7 in the required five-dimension review. Real external-app selection geometry and focus preservation remain pending.
- TASK-016's first live authorization test invalidated the `kSecMatchLimitAll` behavior claim. The follow-up uses one vault and one `LAContext`, but its first two Release packages respectively crashed from nil `NSApp` during construction and remained alive without an openable menu surface after adding a custom App Delegate plus early `NSApplication.shared` access. The final lifecycle repair removes both construction-time AppKit paths and listens only for `NSApplication.didFinishLaunchingNotification`. `./scripts/check.sh` passes 17 Rust and 74 Swift tests plus the Xcode Debug build; the stable-signed fixed Release App is valid, idles in the normal AppKit event loop, creates no new crash report, and successfully captures its complete built-in menu acceptance surface. Clean live authorization behavior remains unverified.
- Rust: 17 tests passed.
- Swift: 83 tests passed.
- Xcode Debug application build passed.
- TASK-014 installed `uv 0.12.2`, `serena-agent 1.6.1`, and rustup `rust-analyzer 1.96.0`; Serena health check passed and indexed 15 Swift files plus 1 Rust file while project/build caches remained ignored.
- TASK-014's real stdio MCP session exposed exactly nine read-only semantic tools, with no edit, shell, project-switching, memory, or onboarding tools. Swift symbol/reference queries covered `TranslationAPIProfile` and `RustTranslationClient/start`; Rust covered `marla_translation_start` and four semantic test references.
- A separate read-only `codex exec` process loaded the project `.codex/config.toml`, called Serena successfully, and returned `ACTIVE_PROJECT=Marla CONTEXT=codex-readonly-context ACTIVE_TOOLS=9`.
- A second independent read-only `codex exec` process actually called `serena.find_symbol` and located `TranslationAPIProfile` at `Sources/MarlaApp/MarlaApplicationModel.swift:81-138`; root `AGENTS.md` now preserves the semantic-first usage rule, navigation-only boundary, ignored paths, and `rg`/normal-read fallback.
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
- The 2026-08-06 to 2026-08-07 multi-API/settings development conversation is retrospectively consolidated in canonical `TASK-005`; `TASK-006` through `TASK-011` remain linked detailed evidence slices rather than separate conversation boundaries.
- TASK-013's fixed `artifacts/Marla_dev.app` retains Bundle ID `com.marla.app`, arm64, Authority `API Usage Monitor Dev`, and the existing designated requirement. Static light/dark list and editor captures passed the five-dimension review under `artifacts/ui-review/task-013/`; the owner confirmed that dragging the handle no longer moves the Settings window. Computer Use completed and reversed a real cross-row handle drag, restoring the prior order. After the owner still observed system drag-image scaling, the visible preview moved to a fixed 580×76pt nonactivating Panel while the native drag item became transparent 1×1pt; final owner confirmation of the Panel, exact handle anchor, moving empty slot, and release fade is pending.
- A real DashScope `qwen-mt-turbo` request translated `Hello` to “你好”; the credential remained in Keychain.
- TASK-015 is complete. Standard/range/marker resolution, pointer/focused/window root ordering, trigger-time application binding, system focused-application roots, ungated AX child probes, CFArray child conversion, global AX graph deduplication, cyclic references, search budgets, Unicode offsets, window-level Escape routing, and the complete Copy transaction lifecycle all pass. The fixed `artifacts/Marla_dev.app` is stable-signature-verified. The project owner confirmed a formerly failing Codex selection plus clipboard restoration, confirmed WeChat reached the real translation request, then accepted the goal complete after observing a high success rate. The downstream Provider `unauthorized` is a missing local profile credential and is excluded from TASK-015. Remaining release evidence stays in BL-001/BL-002.

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
