# Selection Translation

## Status

Implemented; live compatibility verification remains in progress. The nearby result card and real translation path are present, while the complete cross-application matrix is not yet accepted. TASK-017 adds a default-off, single-line in-place feasibility prototype without changing the 0.1.0 default.

## Goal

Translate selected text in a nearby anchored card without unnecessarily activating Marla or mutating the source application.

## Trigger

- Configurable keyboard shortcut.
- Experimental global Force Touch trigger, pending feasibility validation.

## Flow

1. Resolve focused application and selected text.
2. Resolve selection bounds without collecting nearby context text.
3. Present a stable non-activating card above or below the selection. When the TASK-017 experiment is explicitly enabled and conservative single-line geometry checks pass, present the lightweight in-place surface instead.
4. Stream translated block updates.
5. Allow transient, pinned, translation-only, and comparison presentation.

## Current implementation

- Requests and reports macOS Accessibility trust.
- Reads selected text from the focused Accessibility element or a bounded descendant tree without changing it. The trigger-time frontmost application is fixed for the read. Candidate roots include the frontmost application's focused element/window, the identity-checked system-wide focused application, the system-wide focused element, and both application/system-wide pointer hits with a bounded ancestor path.
- Probes standard `AXSelectedText`/range attributes and Web Accessibility Text Marker attributes used by Electron editors such as VSCodium even when an application omits those selection attributes or child attributes from its advertised `AXAttributeNames`; AX child arrays are accepted in both Swift and CFArray forms, and an empty range no longer prevents another non-empty mechanism from being evaluated.
- Renderer/helper AX nodes are accepted only when they can be tied to the trigger-time frontmost application; the graph uses global deduplication, a 4,000-element limit, and a 250ms search budget.
- When the user explicitly enables Copy compatibility, an AX miss falls back to a protected simulated `⌘C`: Marla snapshots every readable item/type/data representation, accepts only text after a new pasteboard change while the trigger-time source remains frontmost, and restores the snapshot on every exit path. The mode is off by default, never consumes an unchanged clipboard value, treats a repeated selection shortcut as cancellation, and skips restoration rather than overwriting a newer external clipboard write.
- Requests selection bounds through `AXBoundsForRange` or `AXBoundsForTextMarkerRange` when available and converts the Accessibility/Quartz top-left display coordinates into AppKit's bottom-left global screen coordinates.
- Captures the frontmost application's display name and Bundle ID.
- Presents the shared non-activating result card, streams the real Rust result, and preserves request-ID cancellation rules.
- A default-off TASK-017 experiment reuses that same session for a solid, non-activating single-line surface. Reliable 10–36pt-high, at least 24pt-wide bounds fully contained in one visible frame produce an exact cover. When Copy compatibility supplies no bounds, a short single-line selection instead produces a lightweight pointer-near bar visibly labeled “附近”; it does not claim exact source covering. Multi-line, long, oversized, cross-screen, or edge-crossing input deterministically falls back to the complete result card. Provider failure expands the existing full error card; cancellation closes the surface.
- The in-place surface does not sample or impersonate the source application's background. Its opaque semantic system background, compact progress indicator, and explicit expand control make Marla's ownership visible while covering the selected source text.

A stable signed Xcode application bundle exists and has passed build, signature, and launch checks. The redacted audit compares complete pre/post pasteboard snapshots and reports only whether they match; it never serializes pasteboard or selected text. The project owner confirmed a formerly failing Codex selection plus clipboard restoration, confirmed a WeChat selection reached the real translation request, and accepted TASK-015 complete after observing a high success rate. The downstream `unauthorized` is a missing local profile credential, not a selection failure. Full Zen/Ghostty, Terminal, Safari, TextEdit, VSCodium, focus, and anchor evidence remains release work under BL-001.

## Degradation

- If precise bounds are unavailable for a short single-line Copy compatibility result, use the visibly labeled pointer-near lightweight bar. Other missing or unsafe geometry uses the complete result card.
- If the in-place experiment rejects the geometry, use the same nearby panel without changing or retrying the translation request.
- If Accessibility selection is unavailable and Copy compatibility is disabled, show an actionable message. When compatibility is enabled, a failed or unsafe clipboard transaction reports an actionable error and sends no translation request.
- If the source application scrolls, moves, or loses focus, dismiss an unpinned overlay.

## Acceptance criteria

- Source focus remains unchanged on presentation.
- The keyboard trigger works even when Force Touch is unavailable.
- Multi-line geometry failure never claims line-perfect source covering.
- Escape or outside interaction can dismiss transient output.
- Streaming updates do not repeatedly move the panel.

## Not included

- modifying source text;
- shipping source-text covering as the default 0.1.0 presentation; TASK-017 remains a default-off feasibility experiment;
- collecting nearby text or window-title context in 0.1.0;
- automatic clipboard-copy simulation when the compatibility mode is disabled;
- browser DOM rewriting;
- guaranteed live tracking during scrolling.
