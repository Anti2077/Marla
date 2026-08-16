# Quick Input

## Status

Semantic Markdown exchange, native rich-text Paste normalization, and completed-state native rendering are implemented and covered by automated tests under TASK-028. Real FluxMarkdown Paste and Provider acceptance remain pending in the same Task.

## Goal

Provide translation near the pointer when no text is already selectable, without opening a traditional main window.

## Flow

1. User invokes the quick-translation shortcut with no selection.
2. A compact input surface appears near the pointer.
3. User types or pastes text.
4. Translation streams into the same stable surface.

Quick Input treats the complete draft as `semanticMarkdown`. Ordinary text remains valid as a Markdown subset, while explicitly typed or pasted Markdown source passes through unchanged. Its native Paste command selects the best representation from explicit Markdown, HTML, RTF/RTFD, and plain text. A rich representation is cleaned and normalized locally into semantic Markdown source before insertion into the draft; a plain representation is inserted unchanged. The conversion does not rewrite the Pasteboard.

Rich and plain representations must describe the same visible text. A mismatch, unsafe or unparseable content, or missing reliable structure degrades to the visible plain text instead of claiming `semanticMarkdown` structure. HTML is parsed structurally in-process; scripts, styles, explicitly hidden nodes, image resources, and unsafe links are removed. Marla does not execute pasted content, load remote resources, or persist native or normalized representations.

On submission, the resulting complete draft reaches the Provider without further flattening. Generic models receive Markdown output rules; Qwen-MT receives the unchanged Markdown source as its User Message because it does not support a System Message.

While a `semanticMarkdown` request is awaiting or streaming content, the result body displays the raw Markdown characters and streaming cursor. Only after that session enters `completed` does the result body switch to a safe native rich-text projection. The projection is one continuous selectable native text surface covering headings, paragraphs, lists, blockquotes, code, and tables; it supports well-formed GFM pipe-table headers, rows, empty cells, escaped/code pipes, and alignment metadata, and keeps `**strong**`/`__strong__` visibly bold in paragraphs, lists, links, and italic combinations. Parsing recognizes GFM alignment markers and canonical Markdown plus canonical Markdown copy retain them, while the completed local projection centers the header and every cell uniformly rather than visually left/right-aligning from `:---` or `---:`. Tables fit the result card's usable body width. Each column adapts to the longest visible text among its header and all cells with reasonable minimum and maximum weights; text exceeding the column width wraps naturally. Non-table blocks stay fixed, and the continuous result surface and cross-block selection contract remain in force. Malformed tables or failed parsing honestly fall back to the raw characters. `plainText` sessions keep their existing presentation in every state. Screenshot OCR remains plain text and does not infer tables.

The complete Markdown string remains the canonical session content behind that projection. The primary copy action copies canonical Markdown, trimming only terminal non-semantic `\n`/`\r`; the menu's plain-text action derives a read-only projection (link labels only, Markdown tables as TSV). Selection `⌘C` follows the same terminal-newline rule. Copy never emits HTML/RTF multi-representation output and never writes the derived projection back. Retry, language changes, API-profile switching, and recent-result restoration all use the original string and format rather than rendered text. Rendering does not use a WebView, execute HTML or scripts, or load remote resources. Real-time incremental Markdown rendering remains outside this slice.

The default shortcut is `⌃⌥Space`. `⌘Return` submits and `Escape` closes. Empty input is rejected without starting a request.

## Acceptance criteria

- Opening the input is fast and predictable.
- Pasting does not modify the system clipboard.
- Explicit Markdown source passes through unchanged; HTML and RTF/RTFD paste normalize locally into semantic Markdown only when their visible text matches the plain representation.
- Unsafe, inconsistent, or unparseable rich input degrades to visible plain text without executing content or loading resources.
- The surface can expand into comparison mode without losing content.
- Chinese IME and multiline text work correctly.
- Retry, language changes, profile switching, recent restoration, and copy preserve the Markdown content format.
- Streaming Markdown remains readable as raw source; only a completed `semanticMarkdown` result uses the native rich-text projection.
- Completed projection permits one continuous cross-block selection and Cmd-C without a semantic trailing newline; canonical session text and meaningful internal/newline structure remain unchanged.
- GFM table columns adapt to the longest visible header/cell text with reasonable minimum and maximum weights, wrap naturally within the card body, and keep non-table blocks fixed while preserving the continuous result/cross-block selection contract. The 380pt/760pt, light/dark, Reduce Motion, wrapping, and selection-gesture checks remain pending.
- Primary copy is canonical Markdown; plain-text copy is derived read-only text with link labels and TSV tables, and no HTML/RTF multi-representation output.
- Parsing failure falls back to raw Markdown without changing or losing the canonical translation.
