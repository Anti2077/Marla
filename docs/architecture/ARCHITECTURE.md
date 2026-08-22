# Architecture

## Status

Current incubation architecture accepted. The 2026-08-17 reopened TASK-028 completed streaming native Markdown projection and unified TextKit height measurement. No public release target is currently assigned.

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
  -> Overlay Presenter
```

Platform acquisition and presentation nodes run in Swift/AppKit. Provider orchestration, normalized processing, context classification, caching, and translation-session logic move through the Rust core. Swift-facing models remain at the bridge boundary until their Rust equivalents and ABI contracts are implemented.

In the current implemented baseline, contextual window collection and persistent caches are disabled. Rust owns translation prompt construction, OpenAI-compatible HTTP/SSE, the GLM-OCR cloud adapter and structure normalization, timeout, cancellation, and provider-independent events.

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

The default global shortcuts are `⌃⇧D` for selection, `⌃⇧S` for screenshot, and `⌃⇧Space` for quick input. All are configurable. Selection translation has no pressure-event or source-covering experimental path.

### Selection reader

Production selection content comes only from one Swift/AppKit protected simulated `⌘C` transaction initiated by the explicit selection trigger. Before Copy, Marla binds and verifies the frontmost source application and captures every readable Pasteboard item, type, order, and data representation while `changeCount` remains stable. It accepts only content written after a new `changeCount`, rechecks the source application immediately before acceptance, and reads the new Markdown, HTML, RTF/RTFD, and plain representations. Rich/plain visible-text validation is scoped to representations of the same Pasteboard item. Marla then restores and re-verifies the complete original snapshot. A concurrent external write is never overwritten. Rust receives only the normalized `TranslationContent`, never Pasteboard or platform objects.

Accessibility retains permission/trust and non-content positioning duties only. It may inspect selection ranges or Text Marker ranges to request `AXBoundsForRange` or `AXBoundsForTextMarkerRange`, but it must not use selected strings, attributed values, `AXStringForRange`, `AXStringForTextMarkerRange`, or any other AX content as input or fallback. Missing geometry degrades to pointer placement without changing the content path. Missing, empty, timed-out, focus-invalid, unrestorable, or otherwise unsafe Copy transactions produce an actionable error and Quick Input path; they do not start translation.

### Native formatted-content normalization

Swift/AppKit owns one session-only normalization boundary shared by selection acquisition and Quick Input Paste. Explicit Markdown source passes through unchanged. Native attributed text, HTML, and RTF/RTFD are converted to semantic Markdown only for reliable structure that agrees with the visible plain text; otherwise the boundary emits `plainText`. HTML uses structured local parsing that removes scripts, styles, explicitly hidden nodes, image resources, and unsafe links. The boundary never uses a WebView, executes content, loads remote resources, or persists native or normalized representations.

Quick Input invokes this boundary from its native Paste command and inserts the resulting Markdown source into the draft. Selection invokes it only on the new representation evidence returned by the protected Copy transaction; Accessibility evidence never enters content normalization. Vision does not infer formatting and always emits `plainText`; GLM-OCR structure normalization emits `semanticMarkdown` only from canonical layout blocks.

### Screenshot capture

Uses ScreenCaptureKit to capture every active display before presenting selection windows. The AppKit selection layer, loupe, and final crop all use those session-only frozen frames; confirmation composites the cross-display crop without a second live capture. Full-display frames are released when selection finishes. The selected crop enters Vision locally by default. When the user explicitly selects GLM-OCR, Swift encodes the crop in memory as PNG or bounded JPEG (9.5 MB safety cap below the Provider's 10 MB limit), transfers only request bytes across the in-process FFI, and releases crop/encoding/response references when OCR completes, is cancelled, or is replaced. Marla does not persist screenshots or active layout blocks.

### OCR provider

OCR Settings persists a Provider choice with Vision as the default. Vision enables automatic language detection, limits explicit candidates to the seven product-language identifiers supported by the current runtime, and normalizes recognized lines into stable `plainText` blocks and reading order.

The owner-authorized TASK-033 adds cloud GLM-OCR through the fixed official `layout_parsing` endpoint and `glm-ocr` model. Swift owns the explicit upload disclosure, Keychain credential, image encoding and lifecycle. Rust owns HTTP, timeout/cancellation, response parsing, block-label mapping, coordinate normalization, safe literal-table conversion and deterministic `semanticMarkdown` reconstruction. `layout_details` is canonical; Provider `md_results` is not accepted as lossless source because it may alter URLs, code, commands, variables and placeholders. A missing saved GLM Key stops before upload and opens OCR Settings. Network, timeout, rate-limit, authorization, encoding, Provider and invalid-response failures visibly fall back to Vision; user cancellation never does.

### Context engine

The accepted future engine may build bounded context only when translation is triggered. The current implementation does not send application identity, surface classification, window title, nearby text, or terminology. Existing surface classification remains local groundwork only; implementation requires a separate owner-authorized Task under ADR-0003.

### Translation providers

The current implementation exposes multiple named OpenAI-compatible Chat Completions streaming profiles, with an ordered enabled subset, one enabled default for new sessions when available, and explicit switching among enabled profiles on result cards. Each profile supplies a URL mode, address, model, optional API Key, and persisted enabled state. Base URL mode appends `/chat/completions`; Complete URL mode preserves the supplied request URL. Rust also derives and requests the standard `/models` endpoint for the current URL mode, returning provider-independent model IDs through the versioned asynchronous C ABI. Swift persists non-sensitive profile data and enabled/order/default invariants in preferences, while all profile credentials use independent logical entries inside one versioned Keychain vault item. The vault is loaded after application launch and cached for the process so translation and profile switching perform no Keychain lookup. Model discovery and connection testing receive the current non-empty editor key draft before falling back to the cached profile credential. Rust owns URL resolution, model discovery, request prompting, SSE parsing, timeouts, explicit retry, cancellation, and normalized events. No default vendor or automatic fallback is selected.

Swift also persists one global native language and a different secondary language from the `zh-Hans`/`en`/`ja`/`fr`/`es`/`de`/`ko` product set. For each explicitly triggered source, Swift uses macOS Natural Language locally, snapshots the detected/overridden source plus preferences into the card, resolves automatic target routing, and sends JSON request schema v3 with `sourceContent`, optional source language, and explicit target. Quick Input and GLM-OCR submit `semanticMarkdown`; selection does so only when protected-Copy representation evidence survives normalization; Vision always uses `plainText`. Rust validates the content format and language codes, then uses Provider capabilities to choose System/User roles, prompt versus `translation_options` language instructions, and delta versus cumulative stream normalization. An unknown source uses Provider source detection but still has an explicit native-language target; detection text, identifier, and confidence are not persisted.

### Presentation

Selection and screenshot translation use the same nearby non-activating result card in the current implementation. The source-covering and pointer-estimate single-line experiment was rejected after real use and removed; live-image rewriting is not part of the current architecture. Quick input uses an activatable version of the same surface near the pointer.

TASK-028 requires presentation to treat formatted content and its display as separate layers. The translation session retains the complete Provider-returned string and its `plainText` or `semanticMarkdown` format as canonical content. Copy, retry, source/target changes, API-profile switching, and in-memory recent restoration read that canonical content, never a rendered projection. Awaiting remains raw. From the first non-empty streaming delta, `semanticMarkdown` attempts the same safe SwiftUI/AppKit-native read-only projection used in `completed`; a temporarily incomplete or unparseable fragment falls back to its current raw characters without changing canonical content. Dense updates are coalesced on a bounded interval of approximately 40ms, avoiding a full attributed-document rebuild and window animation for every character. `plainText`, failed partial output, and cancelled sessions keep the existing plain presentation. The projection uses no WebView, executes no HTML or scripts, and loads no remote resources. A persistent incremental Markdown AST remains outside the current architecture slice.

The streaming and completed projection is a single native selectable text surface backed by an attributed document. Selection can cross headings, paragraphs, lists, quotes, code, and tables; it is not assembled from separate SwiftUI `Text` blocks. GFM pipe tables render headers, rows, columns, empty cells, escaped/code pipes, and alignment metadata when well formed, while malformed tables safely fall back to the current canonical Markdown snapshot. Parsing recognizes GFM alignment markers and canonical Markdown plus canonical Markdown copy retain them, while the local projection centers the header and every cell uniformly rather than visually left/right-aligning from `:---` or `---:`. Tables fit the result card's usable body width. Each column receives a relative width derived from the longest visible text among its header and all cells, bounded by reasonable minimum and maximum weights; content exceeding its column width wraps naturally. Headings, paragraphs, lists, quotes, and code remain fixed in the card, while the result keeps the same continuous selectable surface and cross-block selection contract. `**strong**` and `__strong__` remain visibly bold in paragraphs, lists, links, and italic combinations. These are translated-Markdown display semantics only; Vision screenshot OCR continues to produce plain text and does not recover table structure.

The result body viewport and outer panel derive height from the same current attributed document through TextKit. When `completed` arrives, the streaming cursor is removed and the final document is measured again before one final frame reconciliation. Width changes within 380–760pt reflow that document; the panel still caps at 60% of the visible workspace. One native vertical scroll view owns overflow, with no horizontal scroller or horizontal elasticity, and Reduce Motion introduces no new positional animation.

The primary copy action reads canonical Markdown and removes only terminal non-semantic `\n`/`\r`. The menu's plain-text action is a read-only derived projection (link labels only; Markdown tables as TSV). Selection `⌘C` uses the same terminal-newline policy. Canonical session content, including meaningful line breaks, remains unchanged, and no copy operation emits HTML/RTF multi-representation output.

## State machine

```text
idle
  -> acquiring
  -> recognizing (Vision / GLM structure / visible Vision fallback)
  -> awaitingFirstToken
  -> streaming
  -> completed / failed / cancelled
```

Cancellation propagates to OCR and translation network work. A translation failure must not discard successfully recognized source content.

## Storage

- translation and GLM-OCR API credentials: independent logical entries in one versioned Keychain vault
- screenshots: memory-only by default
- contextual window cache: disabled in the current implementation
- persistent history: not present in the current implementation
- durable terminology: explicit user approval required

## Current packaging boundary

The repository retains Swift Package Manager for fast core compilation and tests and now also contains a native Xcode application target. Full Xcode 26.5 is selected per command through `DEVELOPER_DIR`, without changing the machine-wide `xcode-select` setting.

The Xcode target emits a stable macOS `.app` with Bundle ID `com.marla.app`, macOS 14 deployment, LSUIElement behavior, development Marketing Version sentinel `0.0.0`, and arm64 architecture. The sentinel is required bundle metadata and is not a public release version. Stable local-certificate signing, process launch, Keychain authorization, TCC persistence, Accessibility, and Screen Recording evidence are recorded in the current verification history.

Keychain startup migration uses one shared `LAContext` for the vault and legacy item reads; the operating system's per-item ACL behavior still belongs to the manual authorization check.

Cargo emits `libmarla_core.a`; SwiftPM links it through `MarlaRustFFI`. The Xcode target uses a configuration-aware build phase and library search path so Debug links `target/debug` and Release links `target/release`. The unified verification script builds both the Swift Package foundation and the Debug Xcode app target.

Fixed-path Release development packaging is implemented through `scripts/build-test-app.sh`. It stages the new bundle beside `artifacts/Marla_dev.app`, signs and validates it with the existing stable local certificate, verifies the designated requirement, and only then replaces the previous App. A custom existing path retains an explicit overwrite guard, and the script fails instead of falling back to ad-hoc signing when no stable identity is available. DMG, notarization, updater, and public distribution remain deferred.
