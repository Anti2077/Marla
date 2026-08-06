# Screenshot Translation

## Status

Implemented for the 0.1.0 Alpha; end-to-end manual acceptance remains in progress.

## Goal

Translate text from a small user-selected screen region using local macOS Vision OCR. 0.1.0 preserves plain text and reading order, not document structure.

## Flow

1. Enter a cross-display selection overlay.
2. Capture the selected region in memory with ScreenCaptureKit.
3. Constrain the in-memory crop and send it only to macOS Vision.
4. Normalize recognized lines into stable plain-text blocks and reading order.
5. Send recognized text, never image pixels, to the configured translation API.
6. Present translation-first or comparison output in the shared result card.

## Acceptance criteria

- Escape cancellation belongs to the active screenshot session and does not depend on a selection view retaining keyboard focus. Session-scoped local and global monitors are removed as soon as the session finishes.
- Escape cancels without OCR, translation, persistence, or upload.
- An already-open Marla Settings window never covers the selection layer and is restored without stealing source-application focus.
- No image crop is uploaded in 0.1.0.
- OCR success is retained if translation fails.
- Plain text and line breaks remain readable; table structure is not promised.
- Multi-display scale and coordinates are correct.

## Not included

- persistent screenshot history;
- cloud GLM-OCR and image upload;
- Markdown, table, formula, code-block, or layout reconstruction;
- arbitrary live background reconstruction;
- document or multi-page input.
