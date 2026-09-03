# Screenshot Translation

## Status

The nearby-result-card workflow and the bounded GLM-only in-place reconstruction path are implemented in the current incubation baseline. Automated checks, fixed Release App evidence and the remaining owner-operated real-GLM boundary are recorded in [`STATUS.md`](../development/STATUS.md) and [`VERIFICATION.md`](../development/VERIFICATION.md).

## Goal

Provide two explicit screenshot-region workflows. “截图翻译” uses the configured Vision or GLM-OCR service and always presents a nearby result card. The independent “原位翻译” entry always uses GLM-OCR structure recognition and reconstructs the frozen selected region in place with translated text occupying the same reliable layout blocks.

## Trigger

The configurable global shortcuts default to `⌃⇧S` for ordinary screenshot translation and `⌃⇧I` for independent in-place translation. Settings composes each from independently selected `fn / ⇧ / ⌃ / ⌥ / ⌘` modifiers and one captured primary key; cancellation or failed Carbon registration keeps the previous binding. Fn/Globe is never a standalone trigger and does not add a persistent event tap.

## Current flow

1. Enter a cross-display selection overlay.
2. Capture the selected region in memory with ScreenCaptureKit.
3. Route by explicit entry. Ordinary screenshot translation reads the persisted OCR Provider; Vision keeps the crop local, while GLM-OCR performs cloud structure recognition and uses the nearby card. Independent in-place translation always selects GLM-OCR regardless of the ordinary screenshot preference and immediately creates a same-frame overlay containing the frozen crop plus a compact recognizing state before starting the upload.
4. Vision normalizes lines into stable `plainText`. Rust normalizes GLM `layout_details` into stable blocks and safe `semanticMarkdown` without trusting lossy raw Provider Markdown.
5. Ordinary screenshot translation sends canonical OCR text/Markdown to the configured translation API and presents the shared nearby card, including after successful GLM OCR. Independent in-place translation sends the complete stable-ID GLM block set in one layout-translation request. Image pixels never cross the translation boundary.
6. Update the existing same-frame overlay with eligible validated blocks. Individual unreliable blocks keep their frozen source pixels; invalid Provider output, a layout with no reliable block, GLM failure or rendering failure changes only the compact status in that overlay. The independent intent never enters Vision or the shared nearby result card after capture.

## GLM in-place flow

1. Start only from the independent “原位翻译” menu action or shortcut. Keep its selected `CapturedScreenshot`, macOS global rectangle and canonical GLM `OCRDocument` together in one activity-scoped in-memory context. Ordinary screenshot translation and Vision do not create this context.
2. Before starting GLM-OCR, present one borderless non-activating panel at the original `globalRect`. Its content view draws the frozen crop and a compact recognizing state; it is not a result card and does not change source-application focus.
3. After GLM-OCR completes, update that same content view to translating and send the complete ordered block set to the configured translation Provider in one layout request. Generic models receive stable IDs, semantic kinds and source text under a strict JSON prompt. Qwen-MT receives the same full source set as one instruction-free User Message with exact request-scoped block boundaries, because it treats all User content as text to translate. Blocks are never translated through independent per-line requests.
4. Require one translated value for every requested stable ID. For Qwen-MT, Rust recovers the bounded outputs in source order and reattaches the canonical IDs before common validation. Rust rejects schema, exact ID set, duplicate, unknown or missing ID, modified/missing boundary, extra output, empty translation and protected-payload failures before translated pixels can be drawn. The result carries translated text keyed to source IDs and never supplies or modifies geometry.
5. Let Swift/AppKit combine validated blocks with the same frozen screenshot and source `OCRDocument`. Source normalized bounds remain authoritative. Before fitting, parse block text through the existing native Markdown projection: headings, inline emphasis/code and lists contribute visible characters rather than literal source markers. A `.table` block that contains exactly one valid GFM table expands into native row/column cells under the same source block ID; pipe characters and delimiter rows are never display text.
6. Build table geometry inside the original table bound. Column widths use measured source/target cell content with square-root weighting so a long description column does not consume the full table; row heights follow wrapped target content, all cells share one readable fitted size, the header and first column are centered, and remaining cells honor GFM alignment. Background restoration, overlap acceptance and result counts treat all generated cells as one atomic source block: if any cell is unreliable or cannot fit at 8pt, the whole table keeps its frozen pixels rather than rendering a partial grid.
7. For ordinary non-table blocks, one composite drawing restores each accepted glyph region by interpolating same-row pixels from both sides, preserving local tone. For an accepted table, restore each row interior to one robust sampled background, then draw all cell text and one native grid in the single AppKit surface. The renderer does not create a mask view or text field for each block or cell.
8. Apply the quality gate per source block. Missing or out-of-range bounds, unsafe overlap, unsupported background reconstruction, or translated text that cannot fit without clipping or unreadably small type keeps that source block's frozen pixels while other reliable blocks render.
9. Keep recognizing, translating, translated and failed states in the same panel/content view. Every update is request-ID guarded; stale callbacks cannot change a replacement overlay. Missing credentials or any OCR, Provider, layout or rendering failure leaves the frozen crop and a compact specific failure state in place until close, `Esc` or a new request.

## Acceptance criteria

### Implemented baseline

- Escape cancellation belongs to the active screenshot session and does not depend on a selection view retaining keyboard focus. The selection window handles raw `sendEvent`, AppKit key-equivalent, and `cancelOperation` routing, with session-scoped local/global monitors and a system event-tap fallback removed as soon as the session finishes.
- Escape cancels without OCR, translation, persistence, or upload.
- An already-open Marla Settings window never covers the selection layer and is restored without stealing source-application focus.
- Vision is the default for ordinary screenshot translation and never uploads image pixels. Selecting GLM-OCR for ordinary screenshots or explicitly invoking in-place translation authorizes upload of that selected crop under the disclosure shown in OCR Settings.
- GLM-OCR requires one saved Keychain API Key; missing Key stops without upload or silent fallback and provides a direct OCR Settings action.
- A configured cloud failure in ordinary screenshot translation visibly falls back to Vision. Independent in-place translation does not fall back because Vision has no eligible geometry; it keeps failure in the same overlay. User cancellation never triggers fallback, and stale callbacks cannot replace a newer session.
- Screenshot pixels, encoded bytes, Base64, response and layout blocks remain memory-only. Upload bytes and raw responses are released after OCR; an eligible frozen crop and canonical geometry survive only until its overlay closes, cancels or is replaced.
- OCR success is retained if translation fails.
- Vision promises plain text and reading order only. GLM structure is normalized into Markdown, but pixel-identical page reconstruction is not promised.
- Multi-display scale and coordinates are correct.

### Implemented GLM in-place path

- Only a GLM-OCR success originating from the independent in-place entry with at least one usable normalized block bound is eligible for reconstruction. Ordinary screenshot translation always uses the existing nearby result card, even when GLM-OCR succeeds. Vision and GLM-to-Vision fallback results never synthesize geometry.
- One contextual translation request covers the complete ordered block set. Qwen-MT uses one request-scoped boundary payload rather than JSON instructions inside its translated User Message; other providers use strict stable-ID JSON. In both cases the normalized result is rejected unless the canonical stable IDs match exactly and every translated value and protected payload passes validation.
- The overlay window uses the original selection `globalRect`; its block frames derive only from the source normalized bounds. Target-language text cannot rewrite, guess or recover geometry.
- The frozen screenshot is preserved as the overlay background, source text is masked only inside accepted block regions, and translated title, heading, paragraph, list, table, code, formula and caption blocks remain in their source layout and reading order. Markdown control syntax is projected rather than drawn literally; one valid GFM table block renders as native cells and grid under one source-block identity.
- Text fitting has a readable lower bound. A block with clipping, hidden text, irrecoverable overlap or unreliable background reconstruction is not drawn; its original frozen pixels remain visible. When no reliable block remains or the validated contract/render fails, the same overlay shows a compact failure over the frozen crop and no nearby card appears.
- Swift/AppKit owns the overlay coordinator, non-activating window, native rendering view, focus behavior, accessibility surface and mapping between normalized image coordinates and macOS global screen coordinates. Rust never receives `CGImage`, `NSWindow` or other AppKit objects.
- Presentation does not steal focus. A discoverable close control, `Esc`, a new screenshot, explicit cancellation, source-session replacement and App termination cancel outstanding network work, close the overlay and release the screenshot, geometry, masks and translated blocks.
- Screenshot pixels, encodings, GLM responses, canonical blocks, translated blocks and render plans remain activity-scoped memory only. They are not written to files, Preferences, logs, recent translations or a persistent layout cache.
- Reduce Motion does not introduce positional animation; Reduce Transparency and Increase Contrast retain readable masking, text and controls. VoiceOver exposes a useful summary and a close action without claiming semantic access to the source application.
- A deterministic synthetic fixture may verify the real Release App overlay without credentials. It must not be reported as a real GLM request, and real user screenshots, text and credentials must not enter fixture evidence.

## Not included

- persistent screenshot history;
- custom OCR endpoint/model/quality controls or additional cloud OCR providers;
- OCR preview, block editing, manual block correction, translated-block dragging/resizing or pixel-identical reconstruction;
- arbitrary live background reconstruction;
- selection-text overlays, live-page tracking, browser DOM rewriting, video/game translation or automatic source-change monitoring;
- export of a translated screenshot or persistent screenshot/layout history;
- document or multi-page input.
