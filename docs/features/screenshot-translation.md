# Screenshot Translation

## Status

Proposed for 0.1.0. Technical spike not yet implemented.

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

- Escape cancels without persistence or upload.
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
