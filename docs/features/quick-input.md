# Quick Input

## Status

Proposed.

## Goal

Provide translation near the pointer when no text is already selectable, without opening a traditional main window.

## Flow

1. User invokes the quick-translation shortcut with no selection.
2. A compact input surface appears near the pointer.
3. User types or pastes text.
4. Translation streams into the same stable surface.

The default shortcut is `⌃⌥Space`. `⌘Return` submits and `Escape` closes. Empty input is rejected without starting a request.

## Acceptance criteria

- Opening the input is fast and predictable.
- Pasting does not modify the system clipboard.
- The surface can expand into comparison mode without losing content.
- Chinese IME and multiline text work correctly.
