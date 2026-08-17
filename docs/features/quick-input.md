# Quick Input

## Status

Semantic Markdown exchange, native rich-text Paste normalization, completed and streaming native rendering, and unified TextKit height measurement were implemented and verified under TASK-028. The project owner accepted the reopened streaming slice on 2026-08-17.

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

While a `semanticMarkdown` request is awaiting its first non-empty delta, the result body remains raw. From that delta onward, streaming and completion use the same safe native read-only projection. Dense updates are coalesced on a bounded interval of approximately 40ms; each accepted snapshot rebuilds a session-only attributed document rather than maintaining an incremental AST or rebuilding on every character. Temporarily incomplete or unparseable Markdown honestly falls back to the current raw characters without dropping or rewriting canonical content. The projection is one continuous selectable native text surface covering headings, paragraphs, lists, blockquotes, code, and tables; it supports well-formed GFM pipe-table headers, rows, empty cells, escaped/code pipes, and alignment metadata, and keeps `**strong**`/`__strong__` visibly bold in paragraphs, lists, links, and italic combinations. Parsing recognizes GFM alignment markers and canonical Markdown plus canonical Markdown copy retain them, while the local projection centers the header and every cell uniformly rather than visually left/right-aligning from `:---` or `---:`. Tables fit the result card's usable body width. Each column adapts to the longest visible text among its header and all cells with reasonable minimum and maximum weights; text exceeding the column width wraps naturally. Non-table blocks stay fixed, and the continuous result surface and cross-block selection contract remain in force. `plainText` sessions, failed partial output, and cancelled sessions keep their raw presentation. Screenshot OCR remains plain text and does not infer tables.

The streaming visual cursor belongs only to the attributed projection and is omitted from selection copy. Streaming and completion use the same attributed document and TextKit height semantics for the body viewport and outer panel. Completion removes the cursor and triggers final height reconciliation. Reflow across 380–760pt, the 60% visible-workspace cap, one native vertical scrolling owner, disabled horizontal scrolling/elasticity, and Reduce Motion behavior remain unchanged.

The complete Markdown string remains the canonical session content behind that projection. The primary copy action copies canonical Markdown, trimming only terminal non-semantic `\n`/`\r`; the menu's plain-text action derives a read-only projection (link labels only, Markdown tables as TSV). Selection `⌘C` follows the same terminal-newline rule. Copy never emits HTML/RTF multi-representation output and never writes the derived projection back. Retry, language changes, API-profile switching, and recent-result restoration all use the original string and format rather than rendered text. Rendering does not use a WebView, execute HTML or scripts, or load remote resources. A persistent incremental Markdown AST and HTML/RTF multi-representation output remain outside this slice.

Whenever “View Source” is expanded, canonical `semanticMarkdown` source renders through the same safe native Markdown/TextKit read-only projection when parsing succeeds, including headings, emphasis, lists, blockquotes, inline and fenced code, links, and GFM tables. The source is static canonical input rather than a stream: the same projection is available while translation is streaming or complete. The source viewport is capped at 110pt and owns exactly one native vertical scroller for overflow. Parse failure, `plainText`, and Vision OCR source remain plain text. The projection never changes canonical `sourceContent`; retry, source/target language changes, API-profile switching, and recent-result restoration continue to use canonical source rather than rendered text.

The default shortcut is `⌃⌥Space`. `⌘Return` submits and `Escape` closes. Empty input is rejected without starting a request.

## Acceptance criteria

- Opening the input is fast and predictable.
- Pasting does not modify the system clipboard.
- Explicit Markdown source passes through unchanged; HTML and RTF/RTFD paste normalize locally into semantic Markdown only when their visible text matches the plain representation.
- Unsafe, inconsistent, or unparseable rich input degrades to visible plain text without executing content or loading resources.
- The surface can expand into comparison mode without losing content in streaming or completed states; valid canonical `semanticMarkdown` source uses the shared native projection within a 110pt viewport and one vertical scroll owner, while parse failure, `plainText`, and Vision OCR remain plain text.
- Chinese IME and multiline text work correctly.
- Retry, language changes, profile switching, recent restoration, and copy preserve the Markdown content format.
- From the first non-empty delta, streaming `semanticMarkdown` attempts the same native projection as completion; incomplete/unparseable snapshots show their current raw characters and never modify canonical Markdown.
- Dense streaming updates are coalesced at approximately 40ms, and streaming/completion share attributed-document and TextKit height semantics; completion removes the visual cursor and performs final height reconciliation.
- The projection permits one continuous cross-block selection and Cmd-C without copying the streaming cursor or adding a semantic trailing newline; canonical session text and meaningful internal/newline structure remain unchanged.
- GFM table columns adapt to the longest visible header/cell text with reasonable minimum and maximum weights, wrap naturally within the card body, and keep non-table blocks fixed while preserving the continuous result/cross-block selection contract. Completed and streaming states are verified at 380pt/760pt in light, dark, and Reduce Motion configurations, including wrapping, selection, bounded growth, and final height reconciliation.
- Primary copy is canonical Markdown; plain-text copy is derived read-only text with link labels and TSV tables, and no HTML/RTF multi-representation output.
- Parsing failure falls back to raw Markdown without changing or losing the canonical translation.
