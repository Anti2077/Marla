# ADR-0011: Reliable in-place translation over a frozen screenshot region

Status: Accepted

Date: 2026-09-02

Amended: 2026-09-07 (experimental Lab gate, SwiftUI perimeter chrome and owner-triggered result-window handoff)

## Context

Marla previously experimented with covering selected text using an estimated single-line AppKit panel. Real use rejected both its exact-bounds and pointer-estimate variants: selection APIs did not reliably provide line geometry, the surface had no frozen source pixels with which to hide the original glyphs, and imprecise coordinates made the result look attached to the wrong content. That experiment was removed and remains removed.

TASK-033 later added an explicitly selected GLM-OCR path whose normalized `OCRDocument` retains stable block IDs, block kinds, reading order and optional coordinates from `layout_details`. The screenshot selector already produces one memory-only frozen crop and its exact AppKit global rectangle. The project owner has now explicitly authorized a separate in-place function: an independent entry reconstructs the chosen screenshot region at its original frame, covers only reliable OCR text blocks and renders block-keyed translations at the same positions. Ordinary screenshot translation remains a nearby-card function even when it uses GLM-OCR.

This conflicts with the former Product and UX wording that prohibited every source-covering presentation. A durable decision is required so the new authorization does not silently erase the reasons the old experiment failed.

## Decision

Marla permits in-place translation only for a user-initiated session from the independent “原位翻译” entry that satisfies all of these conditions:

- the same frozen, memory-only screenshot crop is available as the overlay background;
- GLM-OCR returns a complete block set with stable unique IDs and reliable normalized bounds;
- one translation request carries the complete block set and returns every stable ID exactly once;
- Rust rejects unknown, duplicate, missing or empty block results and any damage to protected URLs, code, commands, variables or placeholders before UI presentation;
- native layout can place at least one translated block at its source position at a readable font size without severe overlap;
- surrounding pixels provide sufficiently stable row-wise background samples for removing the original glyphs of each presented block;
- the screenshot content frame exactly equals the captured AppKit global rectangle, does not take focus on presentation, and can be dismissed immediately; exterior room (12pt sides/bottom, 40pt top) carries SwiftUI glass chrome without moving or rescaling any captured pixel or OCR block.

The independent entry is an experimental capability. Its persisted Lab switch defaults to off and gates only the independent menu action and shortcut. When disabled, the application releases the `.inPlace` registration and rejects direct invocation; if an in-place session is active, disabling the switch cancels its owned OCR/layout work and closes the overlay. Ordinary screenshot translation, its OCR Provider selection, nearby-card presentation and ordinary GLM-to-Vision fallback are unaffected.

Immediately after capture, Swift creates one borderless overlay at the captured frame and displays the frozen crop inside it. That same panel and content view move from recognizing to translating to translated or failed; pending work never opens a nearby result card or replaces the overlay with another window. The final surface is one composited drawing: ordinary accepted blocks use row-wise local-background interpolation before native AppKit text is drawn. Geometry remains owned by the OCR block; target-language text may wrap or use a smaller bounded font but never changes the source block coordinates.

Markdown control syntax is parsed by the shared native Markdown document parser into one attributed overlay document instead of being drawn literally. The projection distinguishes H1-H6 and preserves strong, emphasis, combined strong-emphasis, strikethrough, links, inline code, fenced code, block quotes, task-list state, and ordered or unordered nested-list structure. Links are visually distinct but non-interactive because the overlay remains nonactivating. Measurement and final drawing consume the same attributed document, including its fonts, paragraph styles, markers, indentation and wrapping. If that complete document cannot fit at the readable lower bound, the complete OCR source block keeps its frozen pixels; the renderer does not clip, flatten or partially style it to force a fit.

One valid GFM table returned inside a `.table` block is renderer-locally expanded into native cells and a grid inside the original table bound. Supported inline attributed runs survive inside each cell. All cells retain the same source ID and are fitted, restored, overlapped, accepted and counted atomically; a failed or non-fitting cell leaves the complete table frozen. The renderer does not create one opaque rectangle or one text control per block or cell. Title, heading, paragraph, list, table, code, formula and caption blocks retain distinct native typography roles. This is structural reconstruction, not pixel-identical restoration of the source application's font, controls, materials or semantics.

The Provider contract remains all-or-nothing: every requested block ID and protected payload must validate before translated pixels are drawn. Generic System+User models receive a strict stable-ID JSON contract. Qwen-MT's single User Message must contain only one complete request-scoped boundary payload, not JSON control instructions that it would treat as source text; Rust restores source IDs only after exact boundary recovery and then applies the same common validation. The native render plan is deliberately per-block because real GLM output can include decoration, nested regions or tight glyph boxes: a block with missing/invalid geometry, unsafe overlap, unreadable fit or unstable background keeps its frozen source pixels, while reliable blocks render at their own coordinates. Invalid Provider output, no reliable block or render failure leaves the frozen crop in the same overlay and changes only its compact status to a specific failure. Marla must not rerun OCR merely to degrade, estimate Vision geometry, use the pointer as a text coordinate, open a nearby result card for this intent or present a rejected block approximately.

The permission is narrow:

- Vision remains the default local, text-only screenshot path and continues to use the nearby card.
- Ordinary screenshot translation continues to use the nearby card after either Vision or GLM-OCR success.
- The independent in-place intent does not fall back to Vision because Vision has no eligible layout contract; GLM or layout failure remains visible in the same overlay.
- selection translation, Quick Input, live pages, scrolling content, video and browser DOM remain outside this overlay mode.
- the old selected-text inline experiment remains deleted and is not revived by this ADR.

The screenshot, OCR document, mask samples, translations and network handles belong only to the active session. Escape, the close control, a new translation intent, session replacement and App termination release them. No screenshot, layout or translated image is written to history, Preferences, logs or a persistent cache.

### Explicit result-window handoff

The owner-authorized exception to the no-nearby-card rule is a completed result's explicit “移到翻译窗口” action. A SwiftUI glass ring remains visible (6pt), widening (10pt sides/bottom) on proximity. The top expands outward into a 36pt band with a centered 28pt transfer control, entirely outside the unchanged screenshot. A session-local active-always tracking area includes that header and is released with the window; no global mouse polling is introduced. Close stays discoverable, the transfer has a tooltip and native button semantics, and keyboard focus/context-menu access do not require hover. The panel may receive key focus on explicit interaction but never activates merely on presentation. Reduce Motion disables thickness animation; Reduce Transparency substitutes a solid material and Increase Contrast strengthens the outline.

Dismissal event monitors belong to a visible nearby result panel only. When that panel is hidden, its local/global click and Escape handlers must neither consume an overlay event nor clear the shared session before the overlay button handles it. Interactive offline verification must enable those same production dismissal monitors; isolated snapshot renderers do not prove this event-order contract.

The existing result window receives the full validated translation in canonical reading order, including blocks rejected only by overlay geometry or fit. It never reconstructs text from drawn cells. Handoff preserves source text, Markdown, languages and profile metadata in the same completed text session, starts no capture/OCR/translation request, and neither records history automatically nor retains screenshot/layout data. A successful handoff releases the overlay without firing its cancellation callback; stale or repeated actions cannot transfer another session. Waiting/failure never opens a result window automatically and has no eligible transfer action.

## Consequences

- A successful independent in-place request can preserve visible document structure more directly than a nearby card while keeping the source application untouched underneath the temporary window; waiting and failure also stay spatially anchored to that same region.
- Reliability gates deliberately reduce per-block coverage on photos, gradients, glass, tightly packed blocks and unusually long target-language text; one rejected region no longer discards reliable translations elsewhere in the crop. Derived cells from one source table are the exception to independent rejection and remain atomic so the overlay never presents a structurally incomplete table.
- The Provider contract becomes stricter for this mode: block output is buffered and validated before presentation instead of streamed into partially positioned UI.
- A synthetic fixture can verify window geometry, layout, accessibility and appearance without representing a real GLM credential call. Real Provider success remains separate owner-operated evidence.
- AppKit owns the nonactivating window, native text and accessibility elements; Rust owns request construction and structural response validation. This preserves ADR-0004 and ADR-0007 boundaries.
