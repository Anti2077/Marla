# Architecture

## Status

0.1.0 target architecture accepted; its implemented baseline is being extended under TASK-028 for rich selection and Quick Input acquisition, and release verification remains in progress.

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

For 0.1.0, contextual window collection and persistent caches are disabled. Rust owns translation prompt construction, OpenAI-compatible HTTP/SSE, timeout, cancellation, and session state.

## Runtime boundary

```text
SwiftUI / AppKit
  -> Swift bridge types
  -> versioned C ABI
  -> embedded Rust static library
```

The bridge is in-process. Marla does not start a localhost backend or a separate always-running Rust service. The first working bridge exposes its API version and classifies an application's surface from its Bundle ID; that classification is technical groundwork and is not sent as translation context in 0.1.0.

## Core boundaries

### Trigger providers

The default global shortcuts are `⌃⌥D` for selection, `⌃⌥S` for screenshot, and `⌃⌥Space` for quick input. All are configurable. Selection translation has no pressure-event or source-covering experimental path.

### Selection reader

Production selection content comes only from one Swift/AppKit protected simulated `⌘C` transaction initiated by the explicit selection trigger. Before Copy, Marla binds and verifies the frontmost source application and captures every readable Pasteboard item, type, order, and data representation while `changeCount` remains stable. It accepts only content written after a new `changeCount`, rechecks the source application immediately before acceptance, and reads the new Markdown, HTML, RTF/RTFD, and plain representations. Rich/plain visible-text validation is scoped to representations of the same Pasteboard item. Marla then restores and re-verifies the complete original snapshot. A concurrent external write is never overwritten. Rust receives only the normalized `TranslationContent`, never Pasteboard or platform objects.

Accessibility retains permission/trust and non-content positioning duties only. It may inspect selection ranges or Text Marker ranges to request `AXBoundsForRange` or `AXBoundsForTextMarkerRange`, but it must not use selected strings, attributed values, `AXStringForRange`, `AXStringForTextMarkerRange`, or any other AX content as input or fallback. Missing geometry degrades to pointer placement without changing the content path. Missing, empty, timed-out, focus-invalid, unrestorable, or otherwise unsafe Copy transactions produce an actionable error and Quick Input path; they do not start translation.

### Native formatted-content normalization

Swift/AppKit owns one session-only normalization boundary shared by selection acquisition and Quick Input Paste. Explicit Markdown source passes through unchanged. Native attributed text, HTML, and RTF/RTFD are converted to semantic Markdown only for reliable structure that agrees with the visible plain text; otherwise the boundary emits `plainText`. HTML uses structured local parsing that removes scripts, styles, explicitly hidden nodes, image resources, and unsafe links. The boundary never uses a WebView, executes content, loads remote resources, or persists native or normalized representations.

Quick Input invokes this boundary from its native Paste command and inserts the resulting Markdown source into the draft. Selection invokes it only on the new representation evidence returned by the protected Copy transaction; Accessibility evidence never enters content normalization. Vision does not infer formatting and always emits `plainText`.

### Screenshot capture

Uses ScreenCaptureKit to capture every active display before presenting selection windows. The AppKit selection layer, loupe, and final crop all use those session-only frozen frames; confirmation composites the cross-display crop without a second live capture. Full-display frames are released when selection finishes, and only the selected crop enters macOS Vision. Version 0.1.0 sends no image pixels across FFI or to a cloud provider.

### OCR provider

macOS Vision is the only 0.1.0 OCR provider. It enables automatic language detection, limits explicit candidates to the seven product-language identifiers supported by the current Vision runtime, and normalizes recognized lines into stable plain-text blocks and reading order. Cloud GLM-OCR and layout-aware blocks remain post-0.1.0 under ADR-0002 and ADR-0005.

### Context engine

The accepted future engine may build bounded context only when translation is triggered. Version 0.1.0 does not send application identity, surface classification, window title, nearby text, or terminology. Existing surface classification remains local groundwork only.

### Translation providers

Version 0.1.0 exposes multiple named OpenAI-compatible Chat Completions streaming profiles, with an ordered enabled subset, one enabled default for new sessions when available, and explicit switching among enabled profiles on result cards. Each profile supplies a URL mode, address, model, optional API Key, and persisted enabled state. Base URL mode appends `/chat/completions`; Complete URL mode preserves the supplied request URL. Rust also derives and requests the standard `/models` endpoint for the current URL mode, returning provider-independent model IDs through the versioned asynchronous C ABI. Swift persists non-sensitive profile data and enabled/order/default invariants in preferences, while all profile credentials use independent logical entries inside one versioned Keychain vault item. The vault is loaded after application launch and cached for the process so translation and profile switching perform no Keychain lookup. Model discovery and connection testing receive the current non-empty editor key draft before falling back to the cached profile credential. Rust owns URL resolution, model discovery, request prompting, SSE parsing, timeouts, explicit retry, cancellation, and normalized events. No default vendor or automatic fallback is selected.

Swift also persists one global native language and a different secondary language from the `zh-Hans`/`en`/`ja`/`fr`/`es`/`de`/`ko` product set. For each explicitly triggered source, Swift uses macOS Natural Language locally, snapshots the detected/overridden source plus preferences into the card, resolves automatic target routing, and sends JSON request schema v3 with `sourceContent`, optional source language, and explicit target. Quick Input submits its normalized draft as `semanticMarkdown`; selection submits `semanticMarkdown` only when protected-Copy representation evidence survives normalization and otherwise uses the newly copied `plainText`; Vision always uses `plainText`. Rust validates the content format and language codes, then uses Provider capabilities to choose System/User roles, prompt versus `translation_options` language instructions, and delta versus cumulative stream normalization. An unknown source uses Provider source detection but still has an explicit native-language target; detection text, identifier, and confidence are not persisted.

### Presentation

Selection and screenshot translation use the same nearby non-activating result card in 0.1.0. The source-covering and pointer-estimate single-line experiment was rejected after real use and removed; live-image rewriting is not part of the current architecture. Quick input uses an activatable version of the same surface near the pointer.

TASK-028 requires presentation to treat formatted content and its display as separate layers. The translation session retains the complete Provider-returned string and its `plainText` or `semanticMarkdown` format as canonical content. Copy, retry, source/target changes, API-profile switching, and in-memory recent restoration read that canonical content, never a rendered projection. A `semanticMarkdown` result remains raw while awaiting or streaming and switches to a safe SwiftUI/AppKit-native rich-text projection only in `completed`; parsing failure falls back to the raw characters. `plainText`, failed partial output, and cancelled sessions keep the existing plain presentation. This completed-state projection uses no WebView, executes no HTML or scripts, and loads no remote resources. Incremental Markdown rendering remains outside the current architecture slice.

The completed projection is a single native selectable text surface backed by an attributed document. Selection can cross headings, paragraphs, lists, quotes, code, and tables; it is not assembled from separate SwiftUI `Text` blocks. GFM pipe tables render headers, rows, columns, empty cells, escaped/code pipes, and alignment metadata when well formed, while malformed tables safely fall back to canonical Markdown. Parsing recognizes GFM alignment markers and canonical Markdown plus canonical Markdown copy retain them, while the completed local projection centers the header and every cell uniformly rather than visually left/right-aligning from `:---` or `---:`. Tables fit the result card's usable body width. Each column receives a relative width derived from the longest visible text among its header and all cells, bounded by reasonable minimum and maximum weights; content exceeding its column width wraps naturally. Headings, paragraphs, lists, quotes, and code remain fixed in the card, while the completed result keeps the same continuous selectable surface and cross-block selection contract. `**strong**` and `__strong__` remain visibly bold in paragraphs, lists, links, and italic combinations. These are translated-Markdown display semantics only; Vision screenshot OCR continues to produce plain text and does not recover table structure.

The primary copy action reads canonical Markdown and removes only terminal non-semantic `\n`/`\r`. The menu's plain-text action is a read-only derived projection (link labels only; Markdown tables as TSV). Selection `⌘C` uses the same terminal-newline policy. Canonical session content, including meaningful line breaks, remains unchanged, and no copy operation emits HTML/RTF multi-representation output.

## State machine

```text
idle
  -> acquiring
  -> recognizing (screenshot only)
  -> awaitingFirstToken
  -> streaming
  -> completed / failed / cancelled
```

Cancellation propagates to OCR and translation network work. A translation failure must not discard successfully recognized source content.

## Storage

- API credentials: Keychain
- screenshots: memory-only by default
- contextual window cache: disabled in 0.1.0
- persistent history: not present in 0.1.0
- durable terminology: explicit user approval required

## Current packaging boundary

The repository retains Swift Package Manager for fast core compilation and tests and now also contains a native Xcode application target. Full Xcode 26.5 is selected per command through `DEVELOPER_DIR`, without changing the machine-wide `xcode-select` setting.

The Xcode target emits a stable macOS `.app` with Bundle ID `com.marla.app`, macOS 14 deployment, LSUIElement behavior, version `0.1.0`, and arm64 architecture. Stable local-certificate signing and process launch are verified. One-time Keychain authorization, TCC permission persistence, and complete Accessibility and Screen Recording interaction remain manual validation gaps.

Keychain startup migration uses one shared `LAContext` for the vault and legacy item reads; the operating system's per-item ACL behavior still belongs to the manual authorization check.

Cargo emits `libmarla_core.a`; SwiftPM links it through `MarlaRustFFI`. The Xcode target uses a configuration-aware build phase and library search path so Debug links `target/debug` and Release links `target/release`. The unified verification script builds both the Swift Package foundation and the Debug Xcode app target.

Fixed-path Release development packaging is implemented through `scripts/build-test-app.sh`. It stages the new bundle beside `artifacts/Marla_dev.app`, signs and validates it with the existing stable local certificate, verifies the designated requirement, and only then replaces the previous App. A custom existing path retains an explicit overwrite guard, and the script fails instead of falling back to ad-hoc signing when no stable identity is available. DMG, notarization, updater, and public distribution remain deferred.
