# Selection Translation

## Status

The nearby-card baseline is implemented. TASK-028 replaces the former Accessibility-first, default-off Copy-fallback acquisition path with protected simulated Copy as the only production source of selected content. The older `RV-001` evidence remains historical and does not verify this new acquisition contract. The TASK-017 single-line in-place prototype remains removed.

## Goal

Translate selected content in a nearby anchored card without unnecessarily activating Marla or changing the source document.

## Trigger

- Configurable keyboard shortcut.

## Flow

1. Bind the trigger-time frontmost application and verify Accessibility trust.
2. Run one protected simulated `⌘C` transaction and normalize only the newly copied content.
3. Resolve optional selection bounds through non-content Accessibility geometry without collecting selected or nearby text.
4. Present a stable non-activating card above or below the selection, or near the pointer when reliable bounds are unavailable.
5. Stream translated block updates and allow transient, pinned, translation-only, and comparison presentation.

## TASK-028 production contract

- Requests and reports macOS Accessibility trust, which is required to send the user-triggered Copy event and may support non-content positioning.
- Fixes the trigger-time frontmost application before acquisition and rechecks it before Copy and immediately before accepting the new result.
- Captures every readable Pasteboard item, type, order, and data representation while `changeCount` remains stable, then sends exactly one public simulated `⌘C`.
- Accepts content only after that Copy produces a new `changeCount`; an unchanged or pre-existing Pasteboard value is never selection input.
- Reads the new Markdown, HTML, RTF/RTFD, and plain-text representations before restoration. Reliable rich content normalizes to `semanticMarkdown` only when its visible text agrees with the new plain representation from the same Pasteboard item; conflict or unsupported structure degrades to that verified new `plainText`.
- Restores and re-reads the complete original snapshot on success, empty result, error, cancellation, and timeout. If another process writes after Marla's Copy, restoration is skipped rather than overwriting the newer content; no translation request is sent from an unsafe or failed transaction.
- Accessibility may resolve selection range or Text Marker geometry for anchoring, but it does not read `AXSelectedText`, `AXStringForRange`, `AXStringForTextMarkerRange`, attributed values, or any other source content. Missing Copy content never falls back to AX text.
- Converts available Accessibility/Quartz bounds into AppKit's bottom-left global screen coordinates; missing or unreliable geometry falls back to the pointer without changing the copied content.
- Captures the frontmost application's display name and Bundle ID.
- Presents the shared non-activating result card, streams the real Rust result, and preserves request-ID cancellation rules.
- Selection translation always uses the complete nearby result card. The removed TASK-017 prototype no longer contributes a setting, panel style, placement branch, or runtime fallback.

When a completed selection result is `semanticMarkdown`, its body is one continuous native selectable text surface. Selection can cross headings, paragraphs, lists, quotes, code, and GFM pipe tables. Well-formed tables preserve header/rows/columns, empty cells, escaped/code pipes, and alignment metadata; parsing recognizes GFM alignment markers and canonical Markdown plus canonical Markdown copy retain them, while the completed local projection centers the header and every cell uniformly rather than visually left/right-aligning from `:---` or `---:`. Each column adapts to the longest visible text among its header and all cells, with reasonable minimum and maximum weights, and overflowing cell text wraps naturally within the result card body. Headings, paragraphs, lists, quotes, and code remain fixed. The continuous result surface and cross-block selection contract remain unchanged. Malformed tables fall back to canonical Markdown. Strong markers remain visibly bold across paragraphs, lists, links, and italic combinations. This display behavior is for translated Markdown only; screenshot/Vision content remains plain text.

The primary copy control copies canonical Markdown, removing only terminal non-semantic `\n`/`\r`. A menu-only plain-text copy derives link labels and TSV tables without mutating canonical content. Selection `⌘C` applies the same terminal-newline policy and does not emit HTML/RTF multi-representation output. Meaningful line breaks remain in session state.

The redacted audit may compare complete pre/post Pasteboard snapshots and report only lifecycle state; it never serializes copied content or representations. The previous Codex and WeChat acceptance evidence was collected against the superseded AX-first/optional-Copy path. TASK-028 added and completed fixed-App verification of Copy acquisition, rich-representation normalization, full restoration, focus preservation, failure messaging, and the Quick Input escape path; broader application coverage remains release evidence rather than an implementation blocker.

## Degradation

- If precise bounds are unavailable, place the complete result card near the pointer without changing or retrying the translation request.
- If protected Copy produces no new content, the source app changes, the transaction times out, or restoration cannot be verified, send no translation request and show a specific error with a Quick Input action.
- Do not use Accessibility content as a retry or fallback after any Copy failure.
- If the source application scrolls, moves, or loses focus, dismiss an unpinned overlay.

## Acceptance criteria

- Source focus remains unchanged on presentation.
- The keyboard trigger remains the supported selection-translation trigger.
- Every production selection request originates from one protected Copy transaction and never from Accessibility content.
- Original Pasteboard contents are fully restored unless a newer external write makes restoration unsafe; failure is explicit and starts no translation.
- Missing or multi-line geometry never claims line-perfect source covering.
- Escape or outside interaction can dismiss transient output.
- Streaming updates do not repeatedly move the panel.
- Completed GFM tables measure each column from the longest visible header/cell text with reasonable minimum and maximum weights, wrap overflowing cells naturally within the card body, and keep other blocks fixed while preserving the continuous result/cross-block selection contract. The 380pt/760pt, light/dark, Reduce Motion, wrapping, and cross-block-selection checks are verified under TASK-028.

## Not included

- modifying source text;
- source-text-covering or pointer-estimate lightweight translation surfaces;
- collecting nearby text or window-title context in 0.1.0;
- Accessibility-derived selected text, attributed content, or content fallback;
- a setting that disables protected Copy while retaining selection translation;
- browser DOM rewriting;
- guaranteed live tracking during scrolling.
