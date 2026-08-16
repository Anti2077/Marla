# ADR-0009: Semantic Markdown as the structured translation exchange format

Status: Accepted

Date: 2026-08-16

## Context

Marla's acquisition paths can encounter plain text, Markdown source, HTML, RTF, attributed text, and OCR lines, but translation request schema v2 reduced every source to one string before the Rust boundary. That prevented the Provider layer and session from knowing whether formatting evidence existed.

Translation cannot safely preserve structure by translating isolated inline spans and writing them back to the same positions. Languages reorder, merge, split, emphasize, and omit content differently. Strict source/target AST isomorphism would damage natural translation and still fail to protect payloads such as code, URLs, commands, variables, and template placeholders.

Generic chat models can receive format rules in a System Message. Qwen-MT is different: it accepts only a User Message plus `translation_options`, and its stream contains cumulative rather than incremental content. A real `qwen-mt-turbo` sample preserved a heading, list, emphasis, link destination, fenced code, command, variable, and placeholder across 19 cumulative updates, but one sample is evidence for a candidate, not a universal guarantee.

## Decision

- Make formatted content an explicit translation contract. `TranslationContent` carries a format and complete text; the first formats are `plainText` and `semanticMarkdown`.
- Use complete semantic Markdown as the first structured exchange format. The model receives the whole document context and may naturally reorganize target-language sentences and inline emphasis.
- Do not require source and target Markdown ASTs, blocks, inline spans, or character positions to be one-to-one. Stable IDs remain valid for acquisition evidence and geometry that actually exists; they are not a reconstruction mandate for generated target text.
- Treat code, link destinations, variables, commands, template placeholders, and explicitly non-translatable identifiers as protected payloads. Other Markdown structure is prompted and quality-checked softly rather than mechanically restored.
- Swift/AppKit owns native representations, user-triggered acquisition, sanitization, and HTML/RTF/attributed-text normalization. Rust owns the versioned formatted-content request, Provider capabilities, prompts, HTTP/SSE behavior, and provider-independent streaming events.
- Represent Provider differences as capabilities covering message roles, language instructions, and stream content mode. Generic models use System plus User Messages and format-specific prompting. Qwen-MT uses User-only messages, `translation_options`, and cumulative-stream normalization.
- Explicit Markdown source passes through unchanged. Quick Input's native Paste command chooses among Markdown, HTML, RTF/RTFD, and plain text, then inserts cleaned semantic Markdown source into the draft when reliable rich structure exists. Plain typed or pasted text remains a valid Markdown subset.
- Production selection content comes only from the protected Copy transaction defined by ADR-0006. It reads the new Markdown, HTML, RTF/RTFD, and plain representations before restoring the original Pasteboard, and emits `semanticMarkdown` only when that evidence survives normalization. Accessibility content values are not input or fallback. Vision OCR remains `plainText`.
- Require every rich representation to agree with its visible plain text. Conflict, unsafe content, or parse failure degrades to `plainText`. Parse HTML structurally in-process and remove scripts, styles, explicitly hidden nodes, image resources, and unsafe links; never execute acquired content or load its remote resources.
- Apply ADR-0006's revised always-protected-Copy boundary. Every explicit selection trigger may perform exactly one guarded Copy transaction; the former default-off setting and AX-first fallback split are superseded.
- Keep raw Markdown visible while a `semanticMarkdown` session is awaiting or streaming content. Only after the session enters `completed` may SwiftUI/AppKit replace that raw display with a safe native rich-text projection. Parsing failure falls back to the raw characters; `plainText`, failed partial output, and cancelled sessions keep their existing plain presentation.
- The completed projection uses one native selectable text surface, not a group of independent SwiftUI text blocks. Selection may cross headings, paragraphs, lists, quotes, fenced code, inline code, and tables without losing document order or introducing a semantic trailing newline.
- The completed projection supports GFM pipe tables (header, body rows, columns, empty cells, escaped/code pipes, and alignment metadata) and visibly preserves `**strong**`/`__strong__` in paragraphs, lists, links, and italic combinations. Parsing recognizes GFM alignment markers and canonical Markdown plus canonical Markdown copy retain them, while the completed local projection centers the header and every cell uniformly instead of visually left/right-aligning from `:---` or `---:`. Malformed tables or unsupported constructs fall back to the raw canonical Markdown instead of inventing structure. This projection contract applies to translated Markdown results only; Vision screenshot OCR does not infer tables.
- GFM tables fit the result card's usable body width. Each column receives a relative width derived from the longest visible text among its header and all cells, bounded by reasonable minimum and maximum weights; content exceeding its column width wraps naturally. Headings, paragraphs, lists, quotes, and code remain fixed in the card. The completed result retains one continuous native selectable surface and the cross-block selection contract.
- Treat the native rendering as a read-only projection. The complete Markdown string and format remain canonical for session state, copy, retry, language or API-profile switching, and in-memory recent-result restoration.
- The primary one-click copy action copies canonical Markdown after removing only terminal non-semantic `\n`/`\r` characters. A menu-only plain-text action derives a read-only projection in which links keep their visible labels and Markdown tables become TSV. Selection `⌘C` follows the same terminal-newline policy. No operation emits HTML/RTF multi-representation output, and no derived projection writes back to canonical content.
- Do not implement the projection with a WebView, execute HTML or scripts, or load remote resources. Incremental Markdown rendering and HTML/RTF multi-representation output copy require later evidence and work.
- Keep all native and normalized representations session-only. This decision does not authorize continuous clipboard reads, Copy outside an explicit selection trigger, screenshot upload, or persistent document storage.

## Consequences

- Translation request schema becomes version 3 with `sourceContent: { format, text }`; the embedded core API version increments with the ABI contract.
- Retry, language changes, API-profile switching, recent in-memory results, and copy must retain the content format and complete original string; presentation parsing must not mutate either.
- Plain representations from protected Copy and Vision screenshot text remain `plainText` and avoid Markdown-specific prompt cost. Only reliable rich representations written by the current protected Copy may upgrade a production selection to `semanticMarkdown`; Quick Input may separately normalize its explicit native Paste input.
- Markdown output quality remains Provider-dependent. Qwen-MT cannot receive the generic System Message, so its structured support must stay evidence-based and may require future profile capability controls or honest degradation.
- HTML, RTF/RTFD, native attributed Paste input, and rich protected-Copy representation normalization are part of TASK-028's session-only acquisition boundary. Accessibility attributed selection is not an input. Incremental rendering and HTML/RTF multi-format output copy remain later work. A session-only native attributed projection of completed Markdown does not authorize persistent document conversion or broader clipboard access.
- Canonical session text is retained byte-for-byte, including meaningful terminal line breaks. Only Markdown copy, plain-text copy, and selection `⌘C` apply presentation-time removal of terminal non-semantic line breaks; internal and meaningful newlines remain unchanged.
