# Architecture

## Status

Current incubation architecture accepted. The 2026-08-17 reopened TASK-028 completed streaming native Markdown projection and unified TextKit height measurement. TASK-041 implements bounded GLM-only screenshot reconstruction, including the Qwen-MT User-only boundary adapter and complete native attributed Markdown. Its 2026-09-05 SwiftUI glass chrome and explicit completed-result transfer extension is in progress; the contract below does not claim implementation or real-App acceptance for that extension. Real credential acceptance remains tracked separately as `RV-005`. No public release target is currently assigned.

## Platform

- Swift 6 for the native application layer
- SwiftUI for settings and durable content surfaces
- AppKit for menu-bar integration, non-activating panels, focus, and screen-level interaction
- Rust 2024 edition for the embedded business core
- A versioned C ABI and static library for Swift/Rust integration
- macOS 14 or later
- Apple Silicon is the first performance target

## High-level flow

```text
Trigger Provider
  -> Intent Router
  -> Selection Reader / Screen Capture / Quick Input
  -> Context Engine
  -> OCR Provider when required
  -> Translation Provider
  -> Translation Session
  -> Nearby Result Presenter

Independent in-place translation branch:
Screen Capture + globalRect + canonical OCRDocument
  -> Whole-block Layout Translation
  -> Strict ID / payload validation
  -> AppKit In-place Overlay Presenter
  -> explicit completed-result transfer only: Existing Result Presenter
```

Platform acquisition and presentation nodes run in Swift/AppKit. Provider orchestration, normalized processing, context classification, caching, and translation-session logic move through the Rust core. Swift-facing models remain at the bridge boundary until their Rust equivalents and ABI contracts are implemented.

In the current implemented baseline, contextual window collection and persistent caches are disabled. Rust owns translation prompt construction, the four supported translation protocol adapters, the GLM-OCR cloud adapter and structure normalization, timeout, cancellation, and provider-independent events.

## Runtime boundary

```text
SwiftUI / AppKit
  -> Swift bridge types
  -> versioned C ABI
  -> embedded Rust static library
```

The bridge is in-process. Marla does not start a localhost backend or a separate always-running Rust service. The first working bridge exposes its API version and classifies an application's surface from its Bundle ID; that classification is technical groundwork and is not sent as translation context in the current baseline.

## Core boundaries

### Trigger providers

The default global shortcuts are `⌃⇧D` for selection, `⌃⇧S` for ordinary screenshot translation, `⌃⇧I` for independent in-place translation, and `⌃⇧Space` for quick input. All are configurable. Independent in-place translation is an opt-in experimental action exposed through Settings > 实验室; while disabled, its menu/shortcut path is hidden and unregistered without changing the user's stored binding or the ordinary screenshot path. Selection translation has no pressure-event or source-covering experimental path.

### Selection reader

Production selection content comes only from one Swift/AppKit protected simulated `⌘C` transaction initiated by the explicit selection trigger. Before Copy, Marla binds and verifies the frontmost source application and captures every readable Pasteboard item, type, order, and data representation while `changeCount` remains stable. It accepts only content written after a new `changeCount`, rechecks the source application immediately before acceptance, and reads the new Markdown, HTML, RTF/RTFD, and plain representations. Rich/plain visible-text validation is scoped to representations of the same Pasteboard item. Marla then restores and re-verifies the complete original snapshot. A concurrent external write is never overwritten. Rust receives only the normalized `TranslationContent`, never Pasteboard or platform objects.

Accessibility retains permission/trust and non-content positioning duties only. It may inspect selection ranges or Text Marker ranges to request `AXBoundsForRange` or `AXBoundsForTextMarkerRange`, but it must not use selected strings, attributed values, `AXStringForRange`, `AXStringForTextMarkerRange`, or any other AX content as input or fallback. Missing geometry degrades to pointer placement without changing the content path. Missing, empty, timed-out, focus-invalid, unrestorable, or otherwise unsafe Copy transactions produce an actionable error and Quick Input path; they do not start translation.

### Native formatted-content normalization

Swift/AppKit owns one session-only normalization boundary shared by selection acquisition and Quick Input Paste. Explicit Markdown source passes through unchanged. Native attributed text, HTML, and RTF/RTFD are converted to semantic Markdown only for reliable structure that agrees with the visible plain text; otherwise the boundary emits `plainText`. HTML uses structured local parsing that removes scripts, styles, explicitly hidden nodes, image resources, and unsafe links. The boundary never uses a WebView, executes content, loads remote resources, or persists native or normalized representations.

Quick Input invokes this boundary from its native Paste command and inserts the resulting Markdown source into the draft. Selection invokes it only on the new representation evidence returned by the protected Copy transaction; Accessibility evidence never enters content normalization. Vision does not infer formatting and always emits `plainText`; GLM-OCR structure normalization emits `semanticMarkdown` only from canonical layout blocks.

### Screenshot capture

Uses ScreenCaptureKit to capture every active display before presenting selection windows. The AppKit selection layer, loupe, and final crop all use those session-only frozen frames; confirmation composites the cross-display crop without a second live capture. Full-display frames are released when selection finishes. Ordinary screenshot translation enters Vision locally by default and may use the explicitly configured GLM-OCR Provider while retaining nearby-card presentation. The independent in-place entry always uses GLM-OCR. Swift encodes only an explicitly triggered GLM crop in memory as PNG or bounded JPEG (9.5 MB safety cap below the Provider's 10 MB limit), transfers only request bytes across the in-process FFI, and releases crop/encoding/response references when OCR completes, is cancelled, or is replaced. Marla does not persist screenshots or active layout blocks.

The independent in-place entry uses a narrower implemented lifetime: Swift creates the overlay from the selected crop and its `globalRect` immediately after capture, then adds the normalized `OCRDocument` and translated blocks to that same activity-scoped context as results arrive. Encoded upload bytes and raw Provider response do not survive OCR normalization. Ordinary screenshot translation, Vision and GLM-to-Vision fallback never create an in-place context. The screenshot, geometry, restored composite, render plan and translated blocks remain memory-only and are released together at the terminal session boundary.

### OCR provider

OCR Settings persists a Provider choice with Vision as the default. Vision enables automatic language detection, limits explicit candidates to the seven product-language identifiers supported by the current runtime, and normalizes recognized lines into stable `plainText` blocks and reading order.

The owner-authorized TASK-033 adds cloud GLM-OCR through the fixed official `layout_parsing` endpoint and `glm-ocr` model. Swift owns the explicit upload disclosure, Keychain credential, image encoding and lifecycle. Rust owns HTTP, timeout/cancellation, response parsing, block-label mapping, coordinate normalization, safe literal-table conversion and deterministic `semanticMarkdown` reconstruction. `layout_details` is canonical; Provider `md_results` is not accepted as lossless source because it may alter URLs, code, commands, variables and placeholders. A missing saved GLM Key stops before upload. Network, timeout, rate-limit, authorization, encoding, Provider and invalid-response failures in ordinary screenshot translation visibly fall back to Vision; user cancellation never does. The independent in-place intent keeps those failures in its already-present overlay and never starts Vision.

Only a GLM result produced by the independent in-place entry with at least one canonical block having usable, in-range normalized bounds is eligible for translated overlay drawing. A successful GLM result from ordinary screenshot translation still uses the nearby card. Absent confidence remains unknown and cannot be presented as measured certainty. Vision remains the default local plain-text path for ordinary screenshots. GLM request/contract failures and layouts with no reliable block in the independent intent retain the frozen crop and a compact failure status in the same overlay.

### Context engine

The accepted future engine may build bounded context only when translation is triggered. The current implementation does not send application identity, surface classification, window title, nearby text, or terminology. Existing surface classification remains local groundwork only; implementation requires a separate owner-authorized Task under ADR-0003.

### Translation providers

The current implementation exposes multiple named translation profiles with an explicit protocol, an ordered enabled subset, one enabled default for new sessions when available, and explicit switching among enabled profiles on result cards. Supported protocols are OpenAI-compatible Chat Completions, OpenAI Responses, Anthropic Messages, and Google Gemini Generate Content. Each profile supplies a protocol, URL mode, address, model, optional API Key, and persisted enabled state. Base URL mode derives the protocol's standard request path: `/chat/completions`, `/responses`, `/v1/messages`, or `/v1beta/models/{model}:streamGenerateContent?alt=sse`; Complete URL mode preserves the supplied request URL exactly. Rust derives model discovery only when the current protocol has a safe standard: OpenAI-compatible, OpenAI Responses, and Anthropic read `data[].id` from `/models`, while Gemini reads `models[].name` from `/v1beta/models` and removes the `models/` resource prefix. Swift persists non-sensitive profile data and enabled/order/default invariants in preferences, while all profile credentials use independent logical entries inside one versioned Keychain vault item. The vault is loaded after application launch and cached for the process so translation and profile switching perform no Keychain lookup. Model discovery and connection testing receive the current non-empty editor key draft before falling back to the cached profile credential. Rust owns URL resolution, protocol-specific request bodies and authentication headers, model discovery, request prompting, SSE parsing, timeouts, explicit retry, cancellation, and normalized events. Qwen-MT remains an explicit OpenAI-compatible model-name special case only; no protocol is inferred from a model name, and no default vendor or automatic fallback is selected.

Swift also persists one global native language and a different secondary language from the `zh-Hans`/`en`/`ja`/`fr`/`es`/`de`/`ko` product set. For each explicitly triggered source, Swift uses macOS Natural Language locally, snapshots the detected/overridden source plus preferences into the card, resolves automatic target routing, and sends JSON request schema v4 with `sourceContent`, optional source language, explicit target and optional `inPlaceBlocks`. Quick Input and ordinary translation omit `inPlaceBlocks`; Quick Input and GLM-OCR submit `semanticMarkdown`, selection does so only when protected-Copy representation evidence survives normalization, and Vision always uses `plainText`. Rust validates the content format and language codes, then the explicit protocol adapter chooses native message fields, language instructions, authentication and delta versus cumulative stream normalization. An unknown source uses Provider source detection but still has an explicit native-language target; detection text, identifier, and confidence are not persisted.

Schema v4 adds optional `inPlaceBlocks` to the shared translation envelope while leaving ordinary requests with that field absent. This is a distinct layout-translation semantic contract, not a change that makes `semanticMarkdown` one-to-one. One in-place request carries the complete ordered GLM block set with stable IDs, allowlisted kinds and source text so document, sentence and table context stays available. Rust owns the layout-specific prompt, protocol adaptation and strict validation of the response schema, exact ID set, duplicate/unknown/missing IDs, empty target values and protected payloads. Protocol adapters that support system instructions receive the strict JSON contract in their protocol-native system/developer field; Qwen-MT receives one instruction-free User Message containing the complete source set inside exact request-scoped block boundaries. After cumulative streaming, Rust restores canonical source IDs and applies the same strict validation. The validated result contains no Provider-authored bounds and cannot mutate source geometry. Any current contract failure stops translated drawing and updates the existing overlay failure state; stale results are ignored.

Translation requests also use an internal Provider thinking capability. Marla cannot infer this portably from the OpenAI-compatible `/models` response, so it does not probe with an extra paid generation request and does not expose a guessed reasoning level. Rust matches both the official Provider host and a bounded model family: confirmed switchable contracts receive that Provider's explicit disabled value, while Qwen-MT, forced-thinking models, translation-specialized models without this extension, relays, localhost, self-hosted endpoints, and unknown hosts omit private thinking fields. This policy minimizes translation latency without making an unsupported request-body claim and does not change the Swift/FFI schema.

### Presentation

Selection and ordinary screenshot translation use the same nearby non-activating result card, whether ordinary screenshots use Vision or GLM-OCR. The independent in-place entry uses the bounded overlay described below once capture succeeds; the active extension permits a completed result to enter the existing result card only on an explicit user transfer action. The source-covering and pointer-estimate single-line selection experiment was rejected after real use and remains removed; live-image rewriting is not part of the current architecture. Quick input uses an activatable version of the nearby surface near the pointer.

TASK-041 does not restore that rejected selection-text experiment. Its independent entry accepts only an explicitly captured, frozen GLM screenshot; ordinary screenshot translation never routes into this presenter. A dedicated Swift/AppKit coordinator immediately creates and owns the activity context, borderless non-activating window, window level/frame, multi-display global-coordinate mapping, request-ID guarded stages, close/Escape behavior and native rendering view. The screenshot content frame equals the original `globalRect`; the frozen crop is its background. The glass revision reserves 12pt outside the sides/bottom and 40pt above the crop by expanding only the panel frame, without changing crop or block geometry. In AppKit global coordinates, its origin is the capture origin minus `(12, 12)` and its size is the capture size plus `(24, 52)`. After validation, the overlay reuses the canonical native Markdown parser instead of maintaining a second grammar. Its attributed projection target distinguishes H1-H6 and preserves strong, emphasis, combined strong-emphasis, strikethrough, links, inline code, fenced code, block quotes, task lists and ordered/unordered nested lists. Links are visually distinct but non-interactive because the overlay remains non-activating. Literal Markdown control markers never enter drawing.

One OCR source block may project to multiple Markdown blocks, but those blocks remain one atomic overlay unit. Text fitting and final drawing consume the same attributed document with identical fonts, runs, paragraph styles, markers, indentation and wrapping. The overlay must not measure plain text and then draw richer content, or silently flatten/drop attributes to make a frame pass. When the complete attributed document cannot fit its source geometry at the readable lower bound, that source block retains its frozen pixels.

A GLM `.table` block containing exactly one valid GFM table becomes a set of native cells under the same source ID, with measured square-root-weighted columns, wrapped row heights, shared fitted typography and explicit cell alignment. Every cell uses the same attributed inline projection, preserving supported strong, emphasis, strikethrough, link and inline-code runs. Literal pipes and delimiter rows never enter drawing. Rust never receives or owns AppKit objects.

The Provider result still passes complete schema, ID-set and protected-payload validation before translated drawing. Swift then applies bounds, overlap, background-restoration and attributed-text-fit checks per source block: reliable blocks enter the render plan, while a rejected block keeps its frozen source pixels. Ordinary blocks use same-row background interpolation. Table cells are accepted, restored and counted atomically; each table row receives one robust sampled background across its cells before a single AppKit view draws attributed cell content and grid lines. If one table cell fails fit/background/overlap checks, or if any rich cell content cannot fit without clipping or attribute loss, the complete source table stays frozen, never a partial table. Invalid Provider output, no reliable block or render failure updates the compact status inside the same overlay; no nearby card is created. The reconstruction preserves reliable document structure and location, but does not claim the source application's exact font, control semantics, material, gradient or pixel-identical appearance.

The overlay remains reversible and does not activate merely by appearing. A discoverable close control, VoiceOver summary/close action, `Esc`, new capture, explicit cancellation, source-session replacement and App termination all cancel owned network work, close the window and release activity data. Reduce Motion removes the progress animation; contrast remains readable in the compact state and direct text drawing. The normal result card remains the only presentation for selection, Quick Input, Vision and ordinary GLM screenshot sessions.

Under the active glass/transfer contract, a SwiftUI-hosted exterior ring and native controls sit outside the AppKit screenshot drawing responsibility. The ring is 6pt idle; approach expands the sides/bottom to 10pt and the top to a 36pt glass band, without changing the reserved panel frame. The completed-result transfer button is 28pt high and centered inside that expanded top band, outside screenshot pixels. A session-local `NSTrackingArea` includes the stable header area so moving onto its button cannot collapse it, and is removed on teardown; no global pointer polling or persistent tracking is introduced. Native controls provide tooltips and accessible names; keyboard/accessibility access can reveal the expanded band without pointer hover. The existing close action stays discoverable. Reduce Motion disables edge expansion animation; Reduce Transparency and Increase Contrast retain the boundary and actions through native material fallback.

Only the completed stage permits an explicit transfer to the existing result window. The application layer obtains complete validated translated blocks in canonical source reading order, including blocks absent from the render plan, and preserves full Markdown plus source text, language snapshots and API-profile metadata. It never concatenates derived cells or regenerates content from drawn text. The request-ID-guarded, one-time transfer starts no capture, OCR or translation work; stale callbacks and repeated actions cannot publish another card or replace a newer session. Closing the overlay releases pixels, OCR geometry, masks, render plan and tracking, while the ordinary completed card retains only its needed text and existing metadata. Transfer adds neither automatic recent-result insertion nor persistence; the card's existing copy and close semantics remain in force.

The ordinary `FloatingPanel` owns result-card dismissal monitoring only while its panel is visible. Its local/global event callbacks must not consume overlay click/Escape events or clear the shared session while that result panel is hidden. The interactive offline regression fixture must enable these production monitors to exercise the real input-ownership boundary; fixtures that disable them prove isolated rendering only, and updated interaction evidence remains pending verification.

TASK-042 adds an optional persisted automatic result-window placement mode. Swift/AppKit consumes existing selection or screenshot global geometry, ranks deterministic non-overlapping candidates by surface intent, keeps frames inside the visible work area, preserves the chosen growth direction during streaming, and falls back to pointer placement when geometry is unavailable. It does not add global mouse listeners, Accessibility content fallback, source tracking, or Rust/FFI changes.

TASK-028 requires presentation to treat formatted content and its display as separate layers. The translation session retains the complete Provider-returned string and its `plainText` or `semanticMarkdown` format as canonical content. Copy, retry, source/target changes, API-profile switching, and in-memory recent restoration read that canonical content, never a rendered projection. Awaiting remains raw. From the first non-empty streaming delta, `semanticMarkdown` attempts the same safe SwiftUI/AppKit-native read-only projection used in `completed`; a temporarily incomplete or unparseable fragment falls back to its current raw characters without changing canonical content. Dense updates are coalesced on a bounded interval of approximately 40ms, avoiding a full attributed-document rebuild and window animation for every character. `plainText`, failed partial output, and cancelled sessions keep the existing plain presentation. The projection uses no WebView, executes no HTML or scripts, and loads no remote resources. A persistent incremental Markdown AST remains outside the current architecture slice.

The streaming and completed projection is a single native selectable text surface backed by an attributed document. Selection can cross headings, paragraphs, lists, quotes, code, and tables; it is not assembled from separate SwiftUI `Text` blocks. GFM pipe tables render headers, rows, columns, empty cells, escaped/code pipes, and alignment metadata when well formed, while malformed tables safely fall back to the current canonical Markdown snapshot. Parsing recognizes GFM alignment markers and canonical Markdown plus canonical Markdown copy retain them, while the local projection centers the header and every cell uniformly rather than visually left/right-aligning from `:---` or `---:`. Tables fit the result card's usable body width. Each column receives a relative width derived from the longest visible text among its header and all cells, bounded by reasonable minimum and maximum weights; content exceeding its column width wraps naturally. Headings, paragraphs, lists, quotes, and code remain fixed in the card, while the result keeps the same continuous selectable surface and cross-block selection contract. `**strong**` and `__strong__` remain visibly bold in paragraphs, lists, links, and italic combinations. These are translated-Markdown display semantics only; Vision screenshot OCR continues to produce plain text and does not recover table structure.

The result body viewport and outer panel derive height from the same current attributed document through TextKit. When `completed` arrives, the streaming cursor is removed and the final document is measured again before one final frame reconciliation. Width changes within 380–760pt reflow that document; the panel still caps at 60% of the visible workspace. One native vertical scroll view owns overflow, with no horizontal scroller or horizontal elasticity, and Reduce Motion introduces no new positional animation.

The primary copy action reads canonical Markdown and removes only terminal non-semantic `\n`/`\r`. The menu's plain-text action is a read-only derived projection (link labels only; Markdown tables as TSV). Selection `⌘C` uses the same terminal-newline policy. Canonical session content, including meaningful line breaks, remains unchanged, and no copy operation emits HTML/RTF multi-representation output.

## State machine

```text
idle
  -> acquiring
  -> recognizing (Vision / GLM structure / visible Vision fallback)
  -> nearby translation: awaitingFirstToken -> streaming -> completed
  -> independent in-place entry: overlayRecognizing -> overlayTranslating -> validating -> overlayTranslated
  -> explicit user transfer from overlayTranslated only: completed result card
  -> overlayFailed / cancelled
```

Cancellation propagates to OCR, ordinary translation and TASK-041 layout-translation network work. An in-place translation or render failure keeps its frozen source visible until the user closes or replaces the overlay. Stale request IDs and superseded activity contexts cannot update, present or replace a newer session.

## Storage

- translation and GLM-OCR API credentials: independent logical entries in one versioned Keychain vault
- screenshots, screenshot geometry, masks, translated layout blocks and overlay render plans: activity-scoped memory only; TASK-041 retains an eligible frozen crop only until its overlay session ends
- contextual window cache: disabled in the current implementation
- persistent history: not present in the current implementation
- durable terminology: explicit user approval required

## Current packaging boundary

The repository retains Swift Package Manager for fast core compilation and tests and now also contains a native Xcode application target. Full Xcode 26.5 is selected per command through `DEVELOPER_DIR`, without changing the machine-wide `xcode-select` setting.

The Xcode target emits a stable macOS `.app` with Bundle ID `com.marla.app`, macOS 14 deployment, LSUIElement behavior, development Marketing Version sentinel `0.0.0`, and arm64 architecture. The sentinel is required bundle metadata and is not a public release version. Stable local-certificate signing, process launch, Keychain authorization, TCC persistence, Accessibility, and Screen Recording evidence are recorded in the current verification history.

Keychain startup migration uses one shared `LAContext` for the vault and legacy item reads; the operating system's per-item ACL behavior still belongs to the manual authorization check.

Cargo emits `libmarla_core.a`; SwiftPM links it through `MarlaRustFFI`. The Xcode target uses a configuration-aware build phase and library search path so Debug links `target/debug` and Release links `target/release`. The unified verification script builds both the Swift Package foundation and the Debug Xcode app target.

Fixed-path Release development packaging is implemented through `scripts/build-test-app.sh`. It stages the new bundle beside `artifacts/Marla_dev.app`, signs and validates it with the existing stable local certificate, verifies the designated requirement, and only then replaces the previous App. A custom existing path retains an explicit overwrite guard, and the script fails instead of falling back to ad-hoc signing when no stable identity is available. DMG, notarization, updater, and public distribution remain deferred.
