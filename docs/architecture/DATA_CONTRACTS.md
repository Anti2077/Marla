# Data Contracts

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

## FFI OCR request

The Swift/Rust OCR boundary uses UTF-8 JSON request `schemaVersion: 1` and event schema version 1 under C ABI version 4. A request contains request ID, Base64 image bytes, `image/png` or `image/jpeg`, the request-scoped GLM API Key, and connect/overall timeouts. Rust adds the fixed data-URL prefix and sends `model: glm-ocr`, disabled crop/visualization returns, and the same request ID to the fixed official endpoint. The Authorization header contains the raw API Key required by this Provider contract. Unknown schema, empty credentials, unsupported MIME type and empty payload are rejected.

Events are `started`, `completed`, `failed`, or `cancelled`. Completion contains the actual Provider, normalized `OCRDocument`, and canonical `TranslationContent`. Swift copies callback bytes before return, discards stale request IDs, and retains only canonical content for translation retry. The opaque OCR handle uses the same explicit cancel/release lifecycle as translation; cancellation never starts fallback.

## Context snapshot

Context is supporting evidence, not content to translate. It includes bounded nearby text and locally derived classifications. Raw window metadata should be sanitized before transmission.

No `ContextSnapshot` fields cross the current translation boundary. The type remains groundwork for a future owner-authorized context Task.

## FFI translation request

The Swift/Rust translation boundary uses UTF-8 JSON request `schemaVersion: 3` while provider events remain schema version 1. A request contains a request ID, `sourceContent`, an optional resolved source language, one explicit resolved target language, endpoint configuration, optional request-scoped credential, and timeouts. `sourceContent` has an exact `text` value plus `format`, currently `plainText` or `semanticMarkdown`; unknown formats and old request schemas are rejected. Supported language codes are `zh-Hans`, `en`, `ja`, `fr`, `es`, `de`, and `ko`. A missing source language means the Provider may detect source; target is never implicit at the Rust boundary. Rust copies request bytes synchronously and never retains a Swift buffer.

Swift snapshots native/secondary preferences and complete source content into each card, resolves automatic routing before encoding, and preserves those snapshots across retry or API-profile switching. Source/target UI changes create a new request ID from the existing content without reacquisition. Quick Input and GLM-OCR submit canonical `semanticMarkdown`; selection uses it only when protected-Copy structure evidence is reliable and otherwise uses the newly copied `plainText`; Vision OCR always uses `plainText`. Detection identifiers, OCR confidence and layout geometry are not persisted.

API Keys are transferred in request memory only and must never be logged. Swift persistently owns one versioned Keychain vault item containing independent logical entries keyed by translation-profile identity plus one fixed GLM-OCR account; Rust receives only the credential for one narrow request and never receives or persists the vault.

## Provider events

Streaming translation emits lifecycle and block-update events so presentation can remain vendor-independent:

- started;
- delta;
- completed;
- failed with a stable code and retryability;
- cancelled.

Every event includes schema version and request ID. Swift discards events whose request ID no longer owns the card. Callback bytes are valid only during the callback and must be copied before returning.

The request content format determines the expected translated content format for the current first-stage session. Streaming events continue to carry string deltas so Swift remains Provider-independent; Qwen-MT cumulative chunks are normalized to deltas before crossing the callback. The completed string is retained with its session format for retry, profile switching, recent in-memory restoration, and copy.

## Markdown result projection and copy

`semanticMarkdown` rendering is a read-only projection shared by streaming and completed states. Awaiting remains raw; from the first non-empty streaming delta, presentation attempts the native projection. A temporarily incomplete or unparseable snapshot falls back to its current raw characters without changing the exact canonical string. Dense snapshots are coalesced on a bounded interval of approximately 40ms before rebuilding the attributed document; this does not create a persistent incremental AST. `plainText`, failed partial output, and cancelled sessions do not enter Markdown rendering. A single native selectable text surface spans headings, paragraphs, lists, quotes, code, and tables. Well-formed GFM pipe tables preserve header/row/column structure, empty cells, escaped or code pipes, and alignment metadata; malformed tables fall back to raw Markdown. Parsing recognizes GFM alignment markers and canonical Markdown plus canonical Markdown copy retain them, while the local projection centers the header and every cell uniformly rather than visually left/right-aligning from `:---` or `---:`. Tables fit the result card's usable body width. Each column receives a relative width derived from the longest visible text among its header and all cells, bounded by reasonable minimum and maximum weights; content exceeding its column width wraps naturally. Headings, paragraphs, lists, quotes, and code remain fixed. The result retains its continuous surface and cross-block selection contract. Strong markers (`**strong**` and `__strong__`) remain visibly bold in paragraphs, lists, links, and italic combinations. This applies only to translated Markdown results, not Vision table/OCR semantics.

The streaming visual cursor exists only in the attributed projection and is excluded from selection copy and canonical Markdown. Streaming and completion use that same attributed document and TextKit measurement semantics for the body viewport and outer result panel. Completion removes the cursor and triggers a final measurement/frame reconciliation. The 380–760pt width range, 60% visible-workspace height cap, single native vertical scrolling owner, disabled horizontal scrolling/elasticity, and Reduce Motion contract remain unchanged.

Copy has three distinct projections: the primary action copies canonical Markdown; the menu-only plain-text action derives a read-only plain projection where links contribute their visible labels and Markdown tables become TSV; selection `⌘C` copies the selected native projection. Each removes only terminal non-semantic `\n`/`\r` at the copy boundary. The canonical session string and format retain all original line breaks, and no action emits HTML/RTF multi-representation output or writes a derived projection back into session state.
