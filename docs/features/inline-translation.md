# Selection Translation

## Status

Implemented; live compatibility verification remains in progress. The nearby result card and real translation path are present, while the complete cross-application matrix is not yet accepted.

## Goal

Translate selected text in a nearby anchored card without unnecessarily activating Marla or mutating the source application.

## Trigger

- Configurable keyboard shortcut.
- Experimental global Force Touch trigger, pending feasibility validation.

## Flow

1. Resolve focused application and selected text.
2. Resolve selection bounds without collecting nearby context text.
3. Present a stable non-activating card above or below the selection.
4. Stream translated block updates.
5. Allow transient, pinned, translation-only, and comparison presentation.

## Current implementation

- Requests and reports macOS Accessibility trust.
- Reads selected text from the focused Accessibility element or a bounded descendant tree without changing it.
- Supports standard `AXSelectedText`/range attributes and Web Accessibility Text Marker attributes used by Electron editors such as VSCodium.
- Requests global selection bounds through `AXBoundsForRange` or `AXBoundsForTextMarkerRange` when available.
- Captures the frontmost application's display name and Bundle ID.
- Presents the shared non-activating result card, streams the real Rust result, and preserves request-ID cancellation rules.

A stable signed Xcode application bundle exists and has passed build, signature, and launch checks. A controlled VSCodium run exposed a remaining descendant/Text Marker lookup failure while the sentence was visibly selected. The latest build merges all relevant child collections, prioritizes text/WebArea nodes, and accepts attributed-string Text Marker output; automated checks pass, but the Mac locked before the final live retest. Terminal, Safari, TextEdit, focus preservation, and anchor placement remain manual acceptance gaps.

## Degradation

- If precise bounds are unavailable, use a nearby panel.
- If Accessibility selection is unavailable, show an actionable message; clipboard simulation is deferred.
- If the source application scrolls, moves, or loses focus, dismiss an unpinned overlay.

## Acceptance criteria

- Source focus remains unchanged on presentation.
- The keyboard trigger works even when Force Touch is unavailable.
- Multi-line geometry failure never claims line-perfect source covering.
- Escape or outside interaction can dismiss transient output.
- Streaming updates do not repeatedly move the panel.

## Not included

- modifying source text;
- covering source text in place in 0.1.0;
- collecting nearby text or window-title context in 0.1.0;
- clipboard-copy simulation;
- browser DOM rewriting;
- guaranteed live tracking during scrolling.
