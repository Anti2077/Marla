# Selection Translation

## Status

In Progress. Accessibility acquisition is implemented; the 0.1.0 nearby-card presentation remains unimplemented and unverified.

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
- Reads selected text from the focused Accessibility element without changing it.
- Requests global selection bounds when the source element supports `AXBoundsForRange`.
- Captures the frontmost application's display name and Bundle ID.
- Exposes a temporary menu-bar probe for technical validation.

A stable Xcode application bundle now exists and has passed build, signature, and launch checks. Selection acquisition remains compile- and unit-tested only; real Accessibility permission persistence, cross-application acquisition, and nearby-card behavior are not yet accepted.

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
