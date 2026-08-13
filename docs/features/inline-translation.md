# Selection Translation

## Status

Implemented; the project owner accepted the current cross-application selection outcome and closed verification as `RV-001`. The TASK-017 single-line in-place prototype was removed after real use showed that both exact and pointer-estimate variants performed poorly. Future app-specific regressions require a new Task; they do not reopen the closed verification item.

## Goal

Translate selected text in a nearby anchored card without unnecessarily activating Marla or mutating the source application.

## Trigger

- Configurable keyboard shortcut.

## Flow

1. Resolve focused application and selected text.
2. Resolve selection bounds without collecting nearby context text.
3. Present a stable non-activating card above or below the selection, or near the pointer when reliable bounds are unavailable.
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
- Selection translation always uses the complete nearby result card. The removed TASK-017 prototype no longer contributes a setting, panel style, placement branch, or runtime fallback.

A stable signed Xcode application bundle exists and has passed build, signature, and launch checks. The redacted audit compares complete pre/post pasteboard snapshots and reports only whether they match; it never serializes pasteboard or selected text. The project owner confirmed a formerly failing Codex selection plus clipboard restoration, confirmed a WeChat selection reached the real translation request, and accepted TASK-015 complete after observing a high success rate. The downstream `unauthorized` is a missing local profile credential, not a selection failure. The broad cross-application verification is closed as RV-001; a later app-specific regression should be tracked as a new Task.

## Degradation

- If precise bounds are unavailable, place the complete result card near the pointer without changing or retrying the translation request.
- If Accessibility selection is unavailable and Copy compatibility is disabled, show an actionable message. When compatibility is enabled, a failed or unsafe clipboard transaction reports an actionable error and sends no translation request.
- If the source application scrolls, moves, or loses focus, dismiss an unpinned overlay.

## Acceptance criteria

- Source focus remains unchanged on presentation.
- The keyboard trigger remains the supported selection-translation trigger.
- Missing or multi-line geometry never claims line-perfect source covering.
- Escape or outside interaction can dismiss transient output.
- Streaming updates do not repeatedly move the panel.

## Not included

- modifying source text;
- source-text-covering or pointer-estimate lightweight translation surfaces;
- collecting nearby text or window-title context in 0.1.0;
- automatic clipboard-copy simulation when the compatibility mode is disabled;
- browser DOM rewriting;
- guaranteed live tracking during scrolling.
