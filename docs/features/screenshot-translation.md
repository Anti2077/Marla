# Screenshot Translation

## Status

Implemented in the current incubation baseline. Completed real-environment evidence and remaining language-specific evidence boundaries are recorded in [`STATUS.md`](../development/STATUS.md) and [`VERIFICATION.md`](../development/VERIFICATION.md).

## Goal

Translate text from a small user-selected screen region using either default local macOS Vision OCR or explicitly selected cloud GLM-OCR structure recognition.

## Trigger

The configurable global shortcut defaults to `⌃⇧S`. Settings composes it from independently selected `fn / ⇧ / ⌃ / ⌥ / ⌘` modifiers and one captured primary key; cancellation or failed Carbon registration keeps the previous binding. Fn/Globe is never a standalone trigger and does not add a persistent event tap.

## Flow

1. Enter a cross-display selection overlay.
2. Capture the selected region in memory with ScreenCaptureKit.
3. Read the persisted OCR Provider. Vision keeps the crop local. GLM-OCR immediately shows “正在解析结构 / GLM-OCR 正在识别文字与版面…”, encodes the crop below the upload limit and sends it only to the fixed official endpoint.
4. Vision normalizes lines into stable `plainText`. Rust normalizes GLM `layout_details` into stable blocks and safe `semanticMarkdown` without trusting lossy raw Provider Markdown.
5. Send canonical OCR text/Markdown, never image pixels, to the configured translation API.
6. Present translation-first or comparison output in the shared result card. Translation retry and language/API switching reuse canonical OCR content without uploading again.

When the shared translation-window setting is automatic, the result card first attempts to sit 12pt to the right of the selected screenshot region without intersecting it. If the visible workspace cannot contain the minimum-width card there, placement deterministically tries the left, below, and above sides. If an unusually large region leaves no non-overlapping side, the card remains fully visible and uses the candidate with the least overlap rather than extending beyond the workspace.

## Acceptance criteria

- Escape cancellation belongs to the active screenshot session and does not depend on a selection view retaining keyboard focus. The selection window handles raw `sendEvent`, AppKit key-equivalent, and `cancelOperation` routing, with session-scoped local/global monitors and a system event-tap fallback removed as soon as the session finishes.
- Escape cancels without OCR, translation, persistence, or upload.
- An already-open Marla Settings window never covers the selection layer and is restored without stealing source-application focus.
- Vision is the default and never uploads image pixels. Selecting GLM-OCR is explicit authorization to upload each selected crop under the disclosure shown in OCR Settings.
- GLM-OCR requires one saved Keychain API Key; missing Key stops without upload or silent fallback and provides a direct OCR Settings action.
- A configured cloud failure visibly falls back to Vision. User cancellation never triggers fallback, and stale callbacks cannot replace a newer session.
- Screenshot pixels, encoded bytes, Base64, response and layout blocks remain memory-only and are released when the active request completes, cancels or is replaced.
- OCR success is retained if translation fails.
- Vision promises plain text and reading order only. GLM structure is normalized into Markdown, but pixel-identical page reconstruction is not promised.
- Multi-display scale and coordinates are correct.
- Automatic placement prefers the selected region's right side, never overlaps it when a non-overlapping visible candidate exists, and remains inside one display's visible workspace at screen edges.

## Not included

- persistent screenshot history;
- custom OCR endpoint/model/quality controls or additional cloud OCR providers;
- OCR preview, block editing, pixel-identical layout reconstruction or in-place overlay;
- arbitrary live background reconstruction;
- document or multi-page input.
