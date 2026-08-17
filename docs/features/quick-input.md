# Quick Input

## Status

Semantic Markdown exchange, native rich-text Paste normalization, and completed-state native rendering are implemented under TASK-028. TASK-029 implements both the literal HTML table normalization contract and GFM-aware rich/plain consistency validation described below; automated and fixed-App build verification pass, while project-owner interaction confirmation remains pending.

## Goal

Provide translation near the pointer when no text is already selectable, without opening a traditional main window.

## Flow

1. User invokes the quick-translation shortcut with no selection.
2. A compact input surface appears near the pointer.
3. User types or pastes text.
4. Translation streams into the same stable surface.

Quick Input treats the complete draft as `semanticMarkdown`. Ordinary text remains valid as a Markdown subset, while explicitly typed or pasted Markdown source passes through unchanged. Its native Paste command selects the best representation from explicit Markdown, HTML, RTF/RTFD, and plain text. A rich representation is cleaned and normalized locally into semantic Markdown source before insertion into the draft; a plain representation is inserted unchanged. The conversion does not rewrite the Pasteboard.

Rich and plain representations must describe the same visible text. For semantic Markdown, that comparison uses Marla's own GFM-aware document projection, so task-list markers and pipe-table row/cell boundaries are compared using the same parsing semantics as the native renderer instead of Foundation's lossy Markdown projection. A web-backed checkbox represented at the start of a plain-projection line by U+FFFC is normalized as a visual task marker. Pasteboard HTML that is valid UTF-8 is decoded to a native string before structural parsing, preventing raw nonbreaking-space bytes from acquiring a spurious `Â` when the representation omits a charset declaration; non-UTF-8 data retains the parser fallback. A mismatch, unsafe or unparseable content, or missing reliable structure still degrades to the visible plain text instead of claiming `semanticMarkdown` structure; neither content length nor representation size is a trust signal. HTML is parsed structurally in-process; scripts, styles, explicitly hidden nodes, image resources, and unsafe links are removed. Marla does not execute pasted content, load remote resources, or persist native or normalized representations.

TASK-029 extends the same safe native normalization boundary to a narrow plain-text case. A genuine `.html` Pasteboard representation keeps the general HTML converter, while a trusted plain-text value containing a literal `<table>...</table>` fragment uses a stricter table-only parser before submission. Literal conversion is accepted only for simple rectangular tables made from `tr`, `th`, and `td`; the first row becomes the GFM header row, followed by the separator and remaining rows. Cell values preserve template placeholders such as `${BUILD_ID}$` byte-for-byte, preserve the visible values of HTML entities, escape literal `|` characters for GFM, and retain empty cells. Text before, between, and after converted tables keeps its original document order.

The literal path is all-or-nothing for the complete pasted value. A `rowspan` or `colspan`, nested table, non-rectangular, malformed, or empty table, or any failed safety/consistency check returns the original value as `plainText` rather than partially inventing Markdown structure. Conversion uses no WebView, executes no HTML or script, and loads no local or remote resource. It changes only the source normalization performed before the existing Provider request: the Provider/FFI schema, result-side canonical Markdown and copy behavior, and Vision's `plainText` contract remain unchanged.

On submission, the resulting complete draft reaches the Provider without further flattening. Generic models receive Markdown output rules; Qwen-MT receives the unchanged Markdown source as its User Message because it does not support a System Message.

While a `semanticMarkdown` request is awaiting or streaming content, the result body displays the raw Markdown characters and streaming cursor. Only after that session enters `completed` does the result body switch to a safe native rich-text projection. The projection is one continuous selectable native text surface covering headings, paragraphs, lists, blockquotes, code, and tables; it supports well-formed GFM pipe-table headers, rows, empty cells, escaped/code pipes, and alignment metadata, and keeps `**strong**`/`__strong__` visibly bold in paragraphs, lists, links, and italic combinations. Parsing recognizes GFM alignment markers and canonical Markdown plus canonical Markdown copy retain them, while the completed local projection centers the header and every cell uniformly rather than visually left/right-aligning from `:---` or `---:`. Tables fit the result card's usable body width. Each column adapts to the longest visible text among its header and all cells with reasonable minimum and maximum weights; text exceeding the column width wraps naturally. Non-table blocks stay fixed, and the continuous result surface and cross-block selection contract remain in force. Malformed tables or failed parsing honestly fall back to the raw characters. `plainText` sessions keep their existing presentation in every state. Screenshot OCR remains plain text and does not infer tables.

The complete Markdown string remains the canonical session content behind that projection. The primary copy action copies canonical Markdown, trimming only terminal non-semantic `\n`/`\r`; the menu's plain-text action derives a read-only projection (link labels only, Markdown tables as TSV). Selection `⌘C` follows the same terminal-newline rule. Copy never emits HTML/RTF multi-representation output and never writes the derived projection back. Retry, language changes, API-profile switching, and recent-result restoration all use the original string and format rather than rendered text. Rendering does not use a WebView, execute HTML or scripts, or load remote resources. Real-time incremental Markdown rendering remains outside this slice.

The default shortcut is `⌃⌥Space`. `⌘Return` submits and `Escape` closes. Empty input is rejected without starting a request.

## Acceptance criteria

- Opening the input is fast and predictable.
- Pasting does not modify the system clipboard.
- Explicit Markdown source passes through unchanged; HTML and RTF/RTFD paste normalize locally into semantic Markdown only when their visible text matches the plain representation.
- GFM tables and task lists use Marla's renderer-compatible visible-text projection during rich/plain validation; an incomplete or conflicting plain projection still forces an honest `plainText` fallback.
- Valid UTF-8 HTML is decoded without introducing mojibake for raw nonbreaking spaces; the resulting rich projection must still pass the same strict plain-visible-text check, and non-UTF-8 data keeps a safe fallback.
- A genuine `.html` representation and trusted literal HTML table plain text share one safe local converter; a valid rectangular `tr`/`th`/`td` table becomes a GFM pipe table before Provider submission.
- Literal conversion preserves placeholder bytes, entity-visible values, escaped pipes, empty cells, and surrounding paragraph order; `rowspan`/`colspan`, nested, non-rectangular, malformed, or empty tables return the complete original input as `plainText`.
- Unsafe, inconsistent, or unparseable rich input degrades to visible plain text without executing content or loading resources.
- The surface can expand into comparison mode without losing content.
- Chinese IME and multiline text work correctly.
- Retry, language changes, profile switching, recent restoration, and copy preserve the Markdown content format.
- Streaming Markdown remains readable as raw source; only a completed `semanticMarkdown` result uses the native rich-text projection.
- Completed projection permits one continuous cross-block selection and Cmd-C without a semantic trailing newline; canonical session text and meaningful internal/newline structure remain unchanged.
- GFM table columns adapt to the longest visible header/cell text with reasonable minimum and maximum weights, wrap naturally within the card body, and keep non-table blocks fixed while preserving the continuous result/cross-block selection contract. The 380pt/760pt, light/dark, Reduce Motion, wrapping, and selection-gesture checks remain pending.
- Primary copy is canonical Markdown; plain-text copy is derived read-only text with link labels and TSV tables, and no HTML/RTF multi-representation output.
- Parsing failure falls back to raw Markdown without changing or losing the canonical translation.
