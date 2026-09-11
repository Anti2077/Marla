# Screenshot Translation

## Status

The nearby-result-card workflow and the bounded GLM-only in-place reconstruction path are implemented in the current incubation baseline. The in-place path is experimental and disabled by default; users enable it from Settings > 实验室. When enabled, the overlay uses complete native attributed Markdown presentation, including heading hierarchy, inline semantics, code, quotes, lists and rich table cells. Automated checks, fixed Release App evidence and the remaining owner-operated real-GLM boundary are recorded in [`STATUS.md`](../development/STATUS.md) and [`VERIFICATION.md`](../development/VERIFICATION.md).

TASK-041's 2026-09-05 scope adds SwiftUI glass edge chrome and an explicit completed-result transfer to the existing translation window. The contract below defines that authorized work; its implementation and visual acceptance remain in progress until recorded in the Task and verification documents.

TASK-043 adds a user-controlled degradation action to the ordinary nearby-card path: while ordinary screenshot translation is still in the GLM-OCR recognition stage, the user may choose “快速降级至 Vision”. The implementation preserves the independent in-place contract and the existing automatic fallback after a configured GLM-OCR failure; real-provider acceptance remains tracked separately in RV-006.

## Goal

Provide two explicit screenshot-region workflows. “截图翻译” uses the configured Vision or GLM-OCR service and always presents a nearby result card. The independent “原位翻译” entry always uses GLM-OCR structure recognition and reconstructs the frozen selected region in place with translated text occupying the same reliable layout blocks.

TASK-046 extends only ordinary “截图翻译”. Its selection overlay starts from the persisted OCR default but may temporarily select `1` Vision, `2` local Ollama GLM-OCR or `3` cloud GLM-OCR for that capture without changing settings. With no active region, Space toggles a window mode backed by the same `SCShareableContent` snapshot; hover uses the converted AppKit global frame and a click captures the original `SCWindow` through `SCContentFilter(desktopIndependentWindow:)`. During an active region drag, holding Space moves the whole rectangle inside the union of visible display frames and releasing Space resumes resizing without a geometry jump. “原位翻译” hides and disables these temporary controls and remains fixed to cloud GLM-OCR.

## Trigger

The configurable global shortcuts default to `⌃⇧S` for ordinary screenshot translation and `⌃⇧I` for independent in-place translation. Settings composes each from independently selected `fn / ⇧ / ⌃ / ⌥ / ⌘` modifiers and one captured primary key; cancellation or failed Carbon registration keeps the previous binding. Fn/Globe is never a standalone trigger and does not add a persistent event tap.

## Current flow

1. Enter a cross-display selection overlay.
2. Capture the selected region in memory with ScreenCaptureKit.
3. Route by explicit entry. Ordinary screenshot translation reads the persisted OCR Provider; Vision keeps the crop local, while GLM-OCR performs cloud structure recognition and uses the nearby card. Independent in-place translation is available only when enabled in Settings > 实验室; it always selects GLM-OCR regardless of the ordinary screenshot preference and immediately creates an overlay containing the frozen crop at its unchanged global frame plus a compact recognizing state before starting the upload. Peripheral glass chrome may expand the panel, never the screenshot content.
4. Vision normalizes lines into stable `plainText`. Rust normalizes GLM `layout_details` into stable blocks and safe `semanticMarkdown` without trusting lossy raw Provider Markdown.
5. Ordinary screenshot translation sends canonical OCR text/Markdown to the configured translation API and presents the shared nearby card, including after successful GLM OCR. Independent in-place translation sends the complete stable-ID GLM block set in one layout-translation request. Image pixels never cross the translation boundary.
6. Update the existing overlay with eligible validated blocks. Individual unreliable blocks keep their frozen source pixels; invalid Provider output, a layout with no reliable block, GLM failure or rendering failure changes only the compact status in that overlay. The independent intent never enters Vision or automatically opens the shared nearby result card after capture.
7. Only after successful completion, the user may explicitly choose “移到翻译窗口” to move the full validated result into the existing translation window without repeating capture, OCR or translation. This closes the overlay and releases its screenshot and layout context; it is not a failure fallback.

## Ordinary GLM recognition degradation

TASK-043 applies only to ordinary “截图翻译”, whose result is presented in the nearby card. When the selected OCR Provider is GLM-OCR and the session is still recognizing, that card shows “快速降级至 Vision”. The action is a user-requested route change, not an OCR error state.

1. Keep the selected `CapturedScreenshot` in the short-lived active screenshot session and use it as the input for the local Vision request. Do not start a second selection, capture a new image or upload the screenshot to GLM-OCR again.
2. On one valid click, cancel the in-flight GLM-OCR request and its OCR task, advance the same session to the existing `visionFallback` state, and let the normal nearby-card translation flow continue after Vision returns `plainText`.
3. Guard the action by the current session and OCR request identity. Once GLM-OCR has completed or failed, Vision has started, translation has started, the session is completed/failed/cancelled, or the session has been replaced or closed, the action is hidden or has no effect. Repeated and stale clicks cannot start another Vision request or update a newer session.
4. Keep this explicit action distinct from automatic fallback. A configured GLM-OCR network, timeout, authorization, encoding or response failure continues to use the existing visible “云端结构识别失败，正在改用本机 Vision…” state; an intentional user click is not reported as a failure. User cancellation still does not trigger fallback.
5. This action never appears in the independent “原位翻译” overlay. That path remains GLM-only after capture because Vision does not provide the geometry contract required for in-place reconstruction; its GLM failure remains in the same overlay.

## GLM in-place flow

The independent entry is an opt-in experimental feature. Its switch is persisted, defaults to off, and gates only the independent menu action and shortcut. Disabling it does not change ordinary screenshot translation; if an in-place session is active, disabling the switch cancels its owned requests and closes the overlay.

1. Start only from the independent “原位翻译” menu action or shortcut. Keep its selected `CapturedScreenshot`, macOS global rectangle and canonical GLM `OCRDocument` together in one activity-scoped in-memory context. Ordinary screenshot translation and Vision do not create this context.
2. Before starting GLM-OCR, present one borderless non-activating panel whose screenshot content remains at the original `globalRect`. The panel reserves 12pt at the sides and bottom and 40pt above the crop for exterior chrome; neither the crop nor its translated blocks move or scale when chrome changes. Its content view draws the frozen crop and a compact recognizing state; it is not a result card and does not change source-application focus.
3. After GLM-OCR completes, update that same content view to translating and send the complete ordered block set to the configured translation Provider in one layout request. Generic models receive stable IDs, semantic kinds and source text under a strict JSON prompt. Qwen-MT receives the same full source set as one instruction-free User Message with exact request-scoped block boundaries, because it treats all User content as text to translate. Blocks are never translated through independent per-line requests.
4. Require one translated value for every requested stable ID. For Qwen-MT, Rust recovers the bounded outputs in source order and reattaches the canonical IDs before common validation. Rust rejects schema, exact ID set, duplicate, unknown or missing ID, modified/missing boundary, extra output, empty translation and protected-payload failures before translated pixels can be drawn. The result carries translated text keyed to source IDs and never supplies or modifies geometry.
5. Let Swift/AppKit combine validated blocks with the same frozen screenshot and source `OCRDocument`. Source normalized bounds remain authoritative. Before fitting, reuse the canonical native Markdown parser to build an attributed projection rather than a second overlay-specific grammar. The target projection preserves H1-H6 hierarchy; strong, emphasis, combined strong-emphasis, strikethrough, link and inline-code runs; fenced code; block quotes; task-list state; and ordered, unordered and nested-list structure. Markdown control syntax is not display text. Links receive a distinct native visual treatment but are not interactive because the overlay remains non-activating.
6. Treat all parsed Markdown blocks belonging to one OCR source block as one fitting and fallback unit. Measurement and final drawing must consume the same attributed document, including the same fonts, paragraph styles, markers, indentation, wrapping, inline-code treatment and link styling. If that complete document cannot fit the source frame at the readable lower bound, keep the source block's frozen pixels instead of clipping, dropping runs or rendering only a subset.
7. A `.table` block that contains exactly one valid GFM table expands into native row/column cells under the same source block ID; pipe characters and delimiter rows are never display text. Build table geometry inside the original table bound. Column widths use measured source/target cell content with square-root weighting so a long description column does not consume the full table; row heights follow wrapped target content, all cells share one readable fitted size, the header and first column are centered, and remaining cells honor GFM alignment. Each cell uses the same attributed inline projection, so strong, emphasis, strikethrough, links and inline code survive inside the table. Background restoration, overlap acceptance and result counts treat all generated cells as one atomic source block: if any cell is unreliable or the complete rich table cannot fit at 8pt, the whole table keeps its frozen pixels rather than rendering a partial grid.
8. For ordinary non-table blocks, one composite drawing restores each accepted glyph region by interpolating same-row pixels from both sides, preserving local tone. Table-background qualification uses a staggered 24×24 interior sample lattice from the original pixels, not the renderer-derived cell perimeter, which may cross source glyphs. A dominant color must cover at least 62% of samples and at least 45% of each quadrant within the bounded color tolerance; checkerboards, broad gradients or localized complex areas still reject the entire table. Restore each accepted row interior to one robust sampled background, then draw all attributed cell content and one native grid in the single AppKit surface. The renderer does not create a mask view or text field for each block or cell.
9. Apply the quality gate per source block. Missing or out-of-range bounds, unsafe overlap, unsupported background reconstruction, or translated attributed content that cannot fit without clipping or unreadably small type keeps that source block's frozen pixels while other reliable blocks render.
10. Keep recognizing, translating, translated and failed states in the same panel/content view. Every update is request-ID guarded; stale callbacks cannot change a replacement overlay. Missing credentials or any OCR, Provider, layout or rendering failure leaves the frozen crop and a compact specific failure state in place until close, `Esc` or a new request.

## Glass edge and explicit transfer contract

- SwiftUI owns the thin, translucent native glass edge and native action controls; AppKit continues to own the non-activating panel and screenshot rendering. The glass is an exterior ring, not a translucent sheet over the screenshot or translated text.
- Reserve fixed exterior space: 12pt on the sides and bottom, 40pt above the immutable screenshot rectangle. In AppKit global coordinates, the panel origin is the selection origin minus `(12, 12)` and its size is the selection size plus `(24, 52)`. The ring is 6pt at rest; on approach the sides and bottom become 10pt, while the top becomes a 36pt glass band. Hover never resizes the panel, shifts the screenshot or changes OCR coordinate mapping.
- Proximity uses an overlay-session-local `NSTrackingArea`, removed with the overlay. Its stable region includes the reserved header so moving into the expanded band and onto its button does not collapse it. Do not add global mouse polling, a persistent pointer monitor or source-window tracking.
- Only after expansion, a completed result shows the transfer button centered inside the top glass band, entirely outside the screenshot. The button is 28pt high and uses a native control, tooltip and accessible action name. Keyboard and assistive-technology access must reveal the expanded action without requiring pointer hover. Recognizing, translating and failed states must not enable transfer; the existing close action remains discoverable.
- Transfer consumes the complete validated source-ID result in canonical reading order, including translated blocks omitted from the overlay for layout or background quality. It must not assemble content from derived rendered table cells or copy only the visibly accepted blocks. Preserve Markdown, source content, language routing and API-profile metadata needed by the existing completed result card.
- The explicit action makes one request-ID-guarded transition to the existing translation window. It must not capture, upload, rerun OCR, retranslate, or allow repeated clicks and stale callbacks to create duplicate results. The overlay closes and releases screenshot pixels, canonical OCR geometry, masks, render plans and tracking; only the card's text and existing session metadata survive.
- Local/global dismissal monitors owned by the ordinary result panel must act only while that panel is visible. A hidden result panel cannot consume an overlay click or Escape, clear the shared session, or invalidate the transfer before its action runs.
- Transfer does not automatically add the result to recent translations or persistent history. Existing result-card selection, canonical Markdown/plain-text copy and close behavior apply after transfer.
- Reduce Motion avoids edge-expansion animation; Reduce Transparency and Increase Contrast retain a visible boundary and readable controls with native material fallback. Merely showing or approaching the overlay does not activate the source-replacing panel.

When the shared translation-window setting is automatic, the result card first attempts to sit 12pt to the right of the selected screenshot region without intersecting it. If the visible workspace cannot contain the minimum-width card there, placement deterministically tries the left, below, and above sides. If an unusually large region leaves no non-overlapping side, the card remains fully visible and uses the candidate with the least overlap rather than extending beyond the workspace.

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
- Automatic placement prefers the selected region's right side, never overlaps it when a non-overlapping visible candidate exists, and remains inside one display's visible workspace at screen edges.

### TASK-043 ordinary screenshot degradation contract

- During ordinary GLM-OCR recognition, the nearby result card exposes “快速降级至 Vision” and only then; the action is absent from the in-place overlay and from all later OCR, translation, completion, failure and cancellation states.
- A valid action cancels the current GLM-OCR request, reuses the same in-memory `CapturedScreenshot`, enters the existing `visionFallback` state and continues the ordinary nearby-card flow after local Vision OCR. It does not reselect, recapture or upload a second screenshot.
- Session/request identity and one-shot protection reject stale, repeated, replaced or late actions. GLM callbacks arriving after the user action cannot overwrite the Vision session or cause duplicate OCR/translation work.
- Automatic fallback after a configured GLM-OCR failure remains behaviorally distinct from the user action. The automatic path keeps its existing failure/degradation status; the user action is not presented as an error and does not alter the cancellation rule.
- The action's state transition, shared screenshot identity, cancellation ordering, route separation and card visibility are covered by dedicated regression tests and a fixed Release build. Real GLM cancellation and owner-operated fixed-App acceptance remain tracked in RV-006; existing TASK-033 automatic-fallback and TASK-041 in-place evidence do not substitute for that acceptance.

### Implemented GLM in-place path

- Only a GLM-OCR success originating from the independent in-place entry with at least one usable normalized block bound is eligible for reconstruction. Ordinary screenshot translation always uses the existing nearby result card, even when GLM-OCR succeeds. Vision and GLM-to-Vision fallback results never synthesize geometry.
- One contextual translation request covers the complete ordered block set. Qwen-MT uses one request-scoped boundary payload rather than JSON instructions inside its translated User Message; other providers use strict stable-ID JSON. In both cases the normalized result is rejected unless the canonical stable IDs match exactly and every translated value and protected payload passes validation.
- The overlay's screenshot content uses the original selection `globalRect`; its block frames derive only from the source normalized bounds. Fixed exterior reserves of 12pt at the sides/bottom and 40pt at the top enlarge only the panel, not the captured content. Target-language text and hover chrome cannot rewrite, guess or recover geometry.
- The frozen screenshot is preserved as the overlay background, source text is masked only inside accepted block regions, and translated title, heading, paragraph, list, table, code, formula and caption blocks remain in their source layout and reading order. Markdown control syntax is projected rather than drawn literally; one valid GFM table block renders as native cells and grid under one source-block identity.
- Text fitting has a readable lower bound. A block with clipping, hidden text, irrecoverable overlap or unreliable background reconstruction is not drawn; its original frozen pixels remain visible. When no reliable block remains or the validated contract/render fails, the same overlay shows a compact failure over the frozen crop and no nearby card appears.
- Swift/AppKit owns the overlay coordinator, non-activating window, native rendering view, focus behavior, accessibility surface and mapping between normalized image coordinates and macOS global screen coordinates. Rust never receives `CGImage`, `NSWindow` or other AppKit objects.
- Presentation does not steal focus. A discoverable close control, `Esc`, a new screenshot, explicit cancellation, source-session replacement and App termination cancel outstanding network work, close the overlay and release the screenshot, geometry, masks and translated blocks.
- Screenshot pixels, encodings, GLM responses, canonical blocks, translated blocks and render plans remain activity-scoped memory only. They are not written to files, Preferences, logs, recent translations or a persistent layout cache.
- Reduce Motion does not introduce positional animation; Reduce Transparency and Increase Contrast retain readable masking, text and controls. VoiceOver exposes a useful summary and a close action without claiming semantic access to the source application.
- A deterministic synthetic fixture may verify the real Release App overlay without credentials. It must not be reported as a real GLM request, and real user screenshots, text and credentials must not enter fixture evidence.

### Glass and transfer acceptance pending

- Light/dark idle and near-edge fixtures show a 6pt resting ring and expanded 10pt sides/bottom plus 36pt top band. The 28pt transfer control appears only inside the expanded top band, without covering screenshot pixels; small regions retain usable controls and unchanged screenshot placement.
- Completed results move once into the existing result card with their full ordered Markdown, including layout-omitted blocks, intact language/profile metadata and no new network request.
- Waiting/failed states cannot transfer; replacement, close, Escape and transfer remove local tracking and release screenshot/layout resources. Stale callbacks and repeated transfer actions cannot affect a newer session.
- An interactive offline fixture must enable the production result-panel event monitors and verify overlay transfer clicks and Escape while that result panel is hidden. Static or isolated fixtures that disable those monitors do not prove the shared-event path works. Evidence for this regression remains pending verification.
- Native keyboard and accessibility actions, Reduce Motion, Reduce Transparency, Increase Contrast, copy and close remain usable. These are acceptance requirements, not claims of completed real-App verification.

### Rich-Markdown acceptance contract

- H1-H6 have distinguishable native hierarchy while remaining bounded by the original OCR frame. Strong, emphasis, combined strong-emphasis, strikethrough, links, inline code and fenced code retain visible native attributes without leaking Markdown control markers.
- Ordered and unordered nested lists retain markers, depth and hanging indentation; block quotes retain paragraph treatment; task lists display their checked or unchecked state as structure rather than raw source syntax.
- Table cells retain supported inline attributed runs. A table remains one Provider/source block for fitting, overlap, background restoration, result counting and fallback, so no partial rich table can appear.
- Fitting and drawing use the same attributed document. A complete OCR block, or complete table, that cannot fit at the readable lower bound keeps its frozen source pixels atomically; it is not truncated, flattened, partially styled or partially drawn.
- Link styling is visually distinguishable but non-interactive in the non-activating overlay. No WebView, HTML/script execution or remote-resource loading is introduced.
- Fixed Release fixtures in light and dark appearances visibly exercise heading hierarchy, inline combinations, code, quotes, task and nested lists, and rich table cells. Fixture evidence remains separate from owner-operated real-Provider acceptance.

## Not included

- persistent screenshot history;
- custom OCR endpoint/model/quality controls or additional cloud OCR providers;
- OCR preview, block editing, manual block correction, translated-block dragging/resizing or pixel-identical reconstruction;
- arbitrary live background reconstruction;
- selection-text overlays, live-page tracking, browser DOM rewriting, video/game translation or automatic source-change monitoring;
- export of a translated screenshot or persistent screenshot/layout history;
- document or multi-page input.

## TASK-045 local Ollama table extension

Ordinary screenshot translation may select external local Ollama GLM-OCR without a cloud GLM credential. Rust validates the returned text and table structure before translation. Simple HTML tables become GFM; merged cells, row headers and supported inline-rich cells retain a bounded canonical HTML table subset. The existing native selectable TextKit surface preserves row/column spans, blank cells, code/emphasis and line breaks. Table captions and surrounding text remain part of the canonical content. Code examples are not interpreted as tables.

The parser rejects malformed/truncated/unsafe table markup, invalid span geometry and ambiguous GFM column counts through the existing visible Vision fallback. It cannot restore OCR-omitted titles or determine whether repeated identical tables were present in the image. No automatic retry, deduplication, arbitrary HTML execution or WebView is introduced. Independent in-place translation still uses cloud GLM coordinates and does not receive local HTML/span geometry.

Canonical Markdown copy can include the retained HTML table fragment; derived plain-text copy uses TSV and preserves merged-cell text once. Generic translation instructions request unchanged structural tags/spans, but actual Provider structural fidelity and complete App copy/interaction acceptance remain tracked by TASK-045/RV-007. Synthetic evaluation evidence is documented in `docs/development/OCR_TABLE_EVALUATION_2026-09-08.md`.
