# Recent translations

## Scope

The menu keeps the three most recent unique completed translations in memory. Quitting clears them. Each row shows a plain-text translation/source summary; canonical content remains unchanged.

## Actions

- Clicking the summary or right-pointing chevron restores the complete result in the existing translation card.
- While the pointer hovers anywhere in a row, or a row control has keyboard focus, a compact copy group slides in from the right. It retracts when both leave. The native source menu keeps the group revealed throughout menu tracking; Reduce Motion removes displacement and animated resizing. Hidden controls do not accept pointer hits or appear in the accessibility tree. The summary also exposes named accessibility copy actions.
- The group has a shared 1pt outline and divider: a 28pt translation button and attached 20pt arrow segment, 28pt high. Increased Contrast strengthens the outline.
- The adjacent `doc.on.doc` button copies the row's full canonical translation immediately.
- The downward-chevron native menu offers “复制原文”, copying the row's full canonical source text.
- Both copy actions remove only terminal CR/LF characters, matching the existing result-copy policy. Markdown, internal line breaks, code and links remain intact. Copy never uses the shortened visual summary.
- Successful copy briefly replaces the corresponding control icon with a checkmark. Tooltips and accessible labels identify translation, source, and success. The reset is cancelled when the row disappears or a newer copy supersedes it; feedback itself does not require motion.
- Copy does not open the result card, restore or cancel the current session, change history order, or submit any request. Missing/evicted IDs or empty copy payloads leave the clipboard unchanged.

## Verification

TASK-050 owns automated history-copy isolation, content fidelity, stale-ID and empty-source checks, plus real-App light/dark visual and interaction evidence, including hover entry/exit and native menu tracking. History persistence, search, deletion and additional copy formats are outside this feature.

The project owner accepted the hover/split-control behavior on 2026-09-21. Automated checks and real clipboard verification passed. Independent Agent hover/keyboard replay and the final expanded light/dark screenshot pair were not obtained; see TASK-050 for the evidence boundary.
