# Data Contracts

## Status

The OCR, translation and bounded geometry-aware screenshot contracts below describe the implemented incubation baseline. Real GLM credential acceptance remains separately tracked as `RV-005`; synthetic overlay evidence does not replace it.

The 2026-09-05 TASK-041 glass edge and explicit completed-result transfer contract is an authorized extension in progress. The requirements below do not imply completed implementation or visual acceptance; those remain recorded by the Task and verification documents.

## Translation intent

A `TranslationIntent` records the user's requested operation, its input kind, source and target language, presentation preference, and contextual snapshot.

## Text selection

A selection preserves canonical `TranslationContent`, its visible plain-text projection, and available global screen bounds plus source-application identity. Production content is created only from the new representations written by the explicit trigger's protected simulated `⌘C` transaction. Content can be acquired even when Accessibility bounds are unavailable; presentation then uses pointer placement. Accessibility may contribute trust state and non-content geometry, but no AX string, attributed value, range-derived string, or Text Marker-derived string may populate or replace `TranslationContent`.

## Native formatted-content evidence

Swift/AppKit may receive explicit Markdown, HTML, RTF/RTFD, `NSAttributedString`, and plain-text representations. The acquisition boundary keeps them in memory only and produces one canonical `TranslationContent`:

- explicit Markdown source passes through unchanged;
- Quick Input Paste considers Markdown, HTML, RTF/RTFD, then plain text and inserts normalized semantic Markdown source into its draft when reliable rich structure exists;
- a protected selection Copy transaction reads all newly written representations before restoring the original Pasteboard snapshot and is the only selection-content provenance;
- every rich representation must agree with the visible plain-text projection from the same Pasteboard item; disagreement, unsafe content, or failed parsing degrades to that item's verified `plainText`.

The protected transaction records the trigger-time source identity, the stable pre-Copy `changeCount`, a complete original snapshot, the Copy-result `changeCount`, the normalized content, and a redacted restoration outcome. It never accepts unchanged Pasteboard data. Focus change, cancellation, timeout, missing content, snapshot failure, or failed restoration produces no `TranslationContent`; a newer external write prevents restoration and is preserved. These outcomes route to a specific error and Quick Input action rather than AX content fallback.

HTML is structurally parsed in-process. Scripts, styles, explicitly hidden nodes, image resources, and unsafe links are discarded; no content executes, no remote resource loads, and neither the native representation nor its normalized Markdown is persisted. Vision OCR has no rich-format evidence and always produces `plainText`. GLM-OCR may produce `semanticMarkdown`, but only after Rust reconstructs it from normalized canonical layout blocks; raw `md_results` is not a trusted content contract.

## Content blocks

All OCR and translation content is normalized into stable blocks containing:

- stable identifier;
- semantic kind;
- source text;
- normalized bounds when known;
- reading order;
- confidence when known.

Translation updates may refer to stable acquisition blocks when the source and presentation have a reliable correspondence. Providers must not silently invent geometry. A generated target-language Markdown document may naturally merge, split, move, or omit semantic nodes and is not required to preserve a one-to-one source Block or Inline mapping.

Vision blocks represent recognized lines and reading order only. Table, Markdown, formula, and document-layout semantics are not inferred. GLM-OCR maps Provider labels into the same `ContentBlockKind`, assigns stable page/block IDs, treats absent confidence as unknown, and accepts either 0...1 coordinates or pixel coordinates divided by returned page dimensions. Geometry remains activity-scoped and is not added to recent translations.

TASK-041 does not change generated `semanticMarkdown` into an isomorphic document format. It introduces a separate layout-translation result whose only correspondence is an exact stable-ID mapping back to the canonical GLM blocks. Source `bounds` and `readingOrder` remain immutable acquisition evidence; translated text never carries replacement bounds or becomes a new source of geometry.

Markdown inside a translated in-place block remains content, not presentation geometry. Swift may derive a non-authoritative render projection from that content using the shared native Markdown parser. Non-table blocks contribute visible characters without structural markers. A `.table` source block may expand only when its target is exactly one bounded, rectangular GFM table; every derived cell retains the original stable ID plus local row/column metadata. Cell frames, widths, heights and grid lines are renderer-owned derivatives inside the immutable source table bound. Provider IDs, source bounds and the result contract remain one block, and background/fit rejection plus rendered/omitted counts are atomic at that source-block boundary.

## FFI OCR request

The Swift/Rust OCR boundary uses UTF-8 JSON request `schemaVersion: 1` and event schema version 1 under C ABI version 4. A request contains request ID, Base64 image bytes, `image/png` or `image/jpeg`, the request-scoped GLM API Key, and connect/overall timeouts. Rust adds the fixed data-URL prefix and sends `model: glm-ocr`, disabled crop/visualization returns, and the same request ID to the fixed official endpoint. The Authorization header contains the raw API Key required by this Provider contract. Unknown schema, empty credentials, unsupported MIME type and empty payload are rejected.

Events are `started`, `completed`, `failed`, or `cancelled`. Completion contains the actual Provider, normalized `OCRDocument`, and canonical `TranslationContent`. Swift copies callback bytes before return, discards stale request IDs, and retains only canonical content for translation retry. The opaque OCR handle uses the same explicit cancel/release lifecycle as translation; cancellation never starts fallback.

For the implemented nearby-card path, including ordinary screenshot translation with GLM-OCR, Swift retains only canonical content after OCR. One exception applies to the independent in-place entry: its screenshot task and coordinator retain the same captured image, selection `globalRect` and normalized GLM `OCRDocument` in activity-scoped memory until the overlay closes, is replaced, or explicitly transfers a completed result. Raw response and Base64/upload bytes are not part of that retained context. Ordinary screenshot completion, Vision completion and GLM-to-Vision fallback never retain geometry for presentation.

## Context snapshot

Context is supporting evidence, not content to translate. It includes bounded nearby text and locally derived classifications. Raw window metadata should be sanitized before transmission.

No `ContextSnapshot` fields cross the current translation boundary. The type remains groundwork for a future owner-authorized context Task.

## FFI translation request

The implemented Swift/Rust translation boundary uses UTF-8 JSON request `schemaVersion: 4` while Provider events remain schema version 1. A request contains a request ID, `sourceContent`, an optional resolved source language, one explicit resolved target language, endpoint configuration, optional request-scoped credential, timeouts and an optional `inPlaceBlocks` collection. `sourceContent` has an exact `text` value plus `format`, currently `plainText` or `semanticMarkdown`; unknown formats and old request schemas are rejected. Supported language codes are `zh-Hans`, `en`, `ja`, `fr`, `es`, `de`, and `ko`. A missing source language means the Provider may detect source; target is never implicit at the Rust boundary. Rust copies request bytes synchronously and never retains a Swift buffer. Ordinary callers omit `inPlaceBlocks` and otherwise preserve the prior schema-v3 semantics.

Swift snapshots native/secondary preferences and complete source content into each card, resolves automatic routing before encoding, and preserves those snapshots across retry or API-profile switching. Source/target UI changes create a new request ID from the existing content without reacquisition. Quick Input and GLM-OCR submit canonical `semanticMarkdown`; selection uses it only when protected-Copy structure evidence is reliable and otherwise uses the newly copied `plainText`; Vision OCR always uses `plainText`. Detection identifiers, OCR confidence and layout geometry are not persisted.

API Keys are transferred in request memory only and must never be logged. Swift persistently owns one versioned Keychain vault item containing independent logical entries keyed by translation-profile identity plus one fixed GLM-OCR account; Rust receives only the credential for one narrow request and never receives or persists the vault.

## TASK-041 layout translation contract

Layout translation is a distinct semantic mode inside the shared schema-v4 translation request/result contract. It does not make ordinary `plainText` or `semanticMarkdown` content block-isomorphic. The request schema remains synchronized across Rust and Swift. The C ABI stays at version 4 because TASK-041 changes no exported function signature, callback lifetime or ownership rule; JSON request evolution is an independent compatibility identifier.

One request contains:

- one request ID and `schemaVersion: 4`;
- the resolved optional source and explicit target language;
- the configured translation endpoint, request-scoped credential and timeouts;
- an `inPlaceBlocks` collection containing the complete ordered block set from one canonical GLM `OCRDocument`;
- for each `InPlaceTranslationSourceBlock`, exactly its stable ID, `ContentBlockKind` and complete source text.

The request sends the blocks as one contextual group. It must not issue independent Provider calls per line or block, because those calls would lose document, sentence, list and table context. Screenshot pixels, normalized bounds, `globalRect`, confidence and AppKit objects are not required by the translation Provider and do not cross this Rust translation boundary.

For System+User providers, the Provider-facing prompt requires one non-empty target string for each input ID. Qwen-MT is different: it accepts one User Message plus `translation_options` and treats that entire Message as text to translate, so Marla must not place JSON control instructions in it. Its one complete User Message contains the ordered source texts between exact request-scoped BEGIN/END boundaries derived from the block index and an allowlisted `ContentBlockKind`; it does not expose the real stable IDs. Rust accepts a strict structured result when available, otherwise restores the bounded texts in source order, reattaches the canonical source IDs, and then runs the same validation as every other Provider.

Rust parses the complete result before presentation and rejects it when the schema is wrong; an ID is duplicate, unknown or missing; a Qwen boundary is missing, modified or surrounded by extra output; an expected translation is empty; or a code span, URL, command, variable, template placeholder or other protected payload is damaged. Validation compares the result against the exact request block set. Provider order is not geometry and cannot replace source reading order.

The normalized `InPlaceTranslationResult` contains an ordered `blocks` array of `{ id, text }` values covering the validated source IDs. It contains no translated bounds. Swift joins each `InPlaceTranslatedBlock` back to the immutable source block only by ID, preserving source bounds, kind and reading order. Invalid or stale results never reach translated drawing. An invalid current result changes the existing overlay to failed; a stale request ID changes nothing.

Layout translation cancellation and release use the same opaque-handle discipline as other asynchronous FFI work. Callback bytes are valid only for the synchronous callback and must be copied before return. A cancelled, superseded or non-owning request ID cannot publish translated blocks or start overlay construction.

Provider thinking control is a Rust-internal request-body capability, not an FFI field or user preference. Standard `/models` data does not provide a cross-vendor reasoning capability contract. The current mapping requires both a recognized official host and a bounded model family: confirmed DeepSeek V4, GLM 4.7 and supported Volcengine Ark combinations receive `thinking: { type: "disabled" }`; supported DashScope Qwen hybrid-thinking combinations receive `enable_thinking: false`. Qwen-MT preserves its User-only `translation_options` request, GLM 5.3 and other forced-thinking models receive no false disabled claim, and unknown OpenAI-compatible endpoints receive neither private field. Capability detection never sends a generation request.

## Provider events

Streaming translation emits lifecycle and block-update events so presentation can remain vendor-independent:

- started;
- delta;
- completed;
- failed with a stable code and retryability;
- cancelled.

Every event includes schema version and request ID. Swift discards events whose request ID no longer owns the card. Callback bytes are valid only during the callback and must be copied before returning.

The request content format determines the expected translated content format for the current first-stage session. Streaming events continue to carry string deltas so Swift remains Provider-independent; Qwen-MT cumulative chunks are normalized to deltas before crossing the callback. The completed string is retained with its session format for retry, profile switching, recent in-memory restoration, and copy.

TASK-041 layout translation reuses event schema version 1 but does not emit ordinary Markdown `delta` events. Rust buffers the Provider stream, including Qwen-MT cumulative chunks, validates the full stable-ID result and emits its canonical `InPlaceTranslationResult` JSON only in `completed.text`. Partial or unvalidated block output cannot cross into in-place rendering.

## In-place presentation contract

Swift/AppKit owns the activity-scoped screenshot context and overlay presentation lifecycle. The screenshot task and overlay coordinator together retain one frozen `CGImage`, its macOS global `NSRect`, the canonical GLM `OCRDocument`, the validated translated blocks and the owning request identity for no longer than the active path requires. Rust never receives `CGImage`, `NSRect`, `NSWindow`, colors, fonts or render objects.

An overlay render plan maps each accepted source `NormalizedRect` into the frozen image and original global selection frame. Mapping uses source geometry only; target text length and Provider order never move a block. The plan may add native typography, alignment, wrapping, row-wise background restoration and a bounded font size. Missing/out-of-range bounds, unsafe overlap, unreliable background or text below the readable font floor rejects that block and leaves its frozen source pixels unchanged; Provider contract failure or a plan with no accepted block fails before translated drawing.

The overlay window is created immediately after capture, uses the frozen crop as its background and is non-activating on presentation. Its screenshot content retains the same global frame as the selection. The glass revision expands only the panel frame using 12pt side/bottom reserves and a fixed 40pt top reserve. For a capture rectangle `(x, y, width, height)` in AppKit global coordinates, the panel is `(x - 12, y - 12, width + 24, height + 52)`; the local screenshot inset maps back to the unchanged selection `globalRect`. The same panel and content view own recognizing, translating, translated and failed stages. Final rendering produces one composited background by interpolating same-row pixels across each accepted source glyph region, then draws all translated strings directly; it does not create per-block mask views or text controls. Invalid results, zero accepted blocks or rendering failure leave that overlay visible with a compact failure status. A rejected individual block is never approximated; its frozen original remains visible. Vision results and GLM-to-Vision fallback results are never eligible for this contract, and the independent intent never routes to them after capture.

The screenshot, global rectangle, canonical blocks, translated blocks, masks and render plan have one activity-scoped lifetime. Successful presentation retains them only while the overlay is visible. `Esc`, the close action, a new screenshot, cancellation, source-session replacement and App termination close the overlay, cancel owned work and release the whole context. None of those values may be written to files, Preferences, logs, recent translations or a persistent cache. The explicit transfer below is a text-only in-memory handoff, not permission to retain the screenshot or layout. Synthetic UI fixtures use only deterministic non-user content and are evidence for rendering, not for a real GLM request.

### Glass chrome and completed-result handoff

SwiftUI owns the exterior glass ring and native controls; AppKit owns the panel, frozen drawing and a session-local `NSTrackingArea`. The ring is 6pt at rest. On approach, sides/bottom become 10pt and the top expands to a 36pt glass band within its fixed 40pt reserve. The completed-result transfer control is 28pt high and centered inside that band; it appears only in the expanded presentation and never covers screenshot pixels. The existing close action remains discoverable. Proximity state is presentation-only: it cannot change screenshot size, source bounds, text fitting, request identity or the panel frame. The tracking region includes the reserved header so reaching the button keeps the band expanded; tracking is removed when the overlay ends and introduces no global polling or persistent source tracking. Keyboard and accessibility actions can reveal the expanded band without pointer hover; reduced-motion and material/contrast preferences affect chrome only, not source geometry or result content.

The completed overlay may offer a user-triggered “移到翻译窗口” action with these invariants:

- The owning activity is still current and in its successful completed stage. Recognizing, translating, failed, cancelled and superseded contexts cannot transfer.
- Compose one complete `semanticMarkdown` document from the validated translated source blocks in canonical reading order, preserving each block once. Include blocks omitted from overlay drawing because of bounds, overlap, background or fit. Derived table cells and visible rendered strings are not transfer input and cannot duplicate or omit source blocks.
- Retain the existing source content, translated Markdown and existing result-card metadata, including resolved language/preference snapshots and API-profile identity. Do not carry `CGImage`, `OCRDocument` geometry, masks, render plans, upload bytes, Provider raw responses or credentials into the result window.
- Transfer is a one-time request-ID-guarded presentation transition, with no capture, OCR, upload or translation request. Release the screenshot/layout context and local tracking when closing the overlay. Repeated clicks or stale callbacks cannot recreate the overlay or overwrite a replacement card.
- A hidden ordinary result panel has no authority to consume overlay click/Escape events or clear the shared session. Its local/global dismissal monitors require a visible result panel before acting, so transfer cannot lose its owning session before its action executes. Interactive offline verification must keep production monitors enabled; passing isolated fixtures with those monitors disabled does not establish this invariant.
- The existing card displays the completed text and keeps native selection, canonical Markdown/plain-text copy and close behavior. The handoff does not automatically insert recent translations or enable persistent history. A later explicit card retry or language/profile change remains a separate existing user command, not part of the transfer.

## Markdown result projection and copy

`semanticMarkdown` rendering is a read-only projection shared by streaming and completed states. Awaiting remains raw; from the first non-empty streaming delta, presentation attempts the native projection. A temporarily incomplete or unparseable snapshot falls back to its current raw characters without changing the exact canonical string. Dense snapshots are coalesced on a bounded interval of approximately 40ms before rebuilding the attributed document; this does not create a persistent incremental AST. `plainText`, failed partial output, and cancelled sessions do not enter Markdown rendering. A single native selectable text surface spans headings, paragraphs, lists, quotes, code, and tables. Well-formed GFM pipe tables preserve header/row/column structure, empty cells, escaped or code pipes, and alignment metadata; malformed tables fall back to raw Markdown. Parsing recognizes GFM alignment markers and canonical Markdown plus canonical Markdown copy retain them, while the local projection centers the header and every cell uniformly rather than visually left/right-aligning from `:---` or `---:`. Tables fit the result card's usable body width. Each column receives a relative width derived from the longest visible text among its header and all cells, bounded by reasonable minimum and maximum weights; content exceeding its column width wraps naturally. Headings, paragraphs, lists, quotes, and code remain fixed. The result retains its continuous surface and cross-block selection contract. Strong markers (`**strong**` and `__strong__`) remain visibly bold in paragraphs, lists, links, and italic combinations. This applies only to translated Markdown results, not Vision table/OCR semantics.

The streaming visual cursor exists only in the attributed projection and is excluded from selection copy and canonical Markdown. Streaming and completion use that same attributed document and TextKit measurement semantics for the body viewport and outer result panel. Completion removes the cursor and triggers a final measurement/frame reconciliation. The 380–760pt width range, 60% visible-workspace height cap, single native vertical scrolling owner, disabled horizontal scrolling/elasticity, and Reduce Motion contract remain unchanged.

Copy has three distinct projections: the primary action copies canonical Markdown; the menu-only plain-text action derives a read-only plain projection where links contribute their visible labels and Markdown tables become TSV; selection `⌘C` copies the selected native projection. Each removes only terminal non-semantic `\n`/`\r` at the copy boundary. The canonical session string and format retain all original line breaks, and no action emits HTML/RTF multi-representation output or writes a derived projection back into session state.
