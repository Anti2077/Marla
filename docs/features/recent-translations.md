# Recent translations

## Scope

The menu keeps the three most recent unique completed translations in memory. Quitting clears them. Each row shows a plain-text translation/source summary; canonical content remains unchanged.

## Actions

- Clicking the summary or right-pointing chevron restores the complete result in the existing translation card.
- The adjacent `doc.on.doc` button copies the row's full canonical translation immediately.
- The downward-chevron native menu offers “复制原文”, copying the row's full canonical source text.
- Both copy actions remove only terminal CR/LF characters, matching the existing result-copy policy. Markdown, internal line breaks, code and links remain intact. Copy never uses the shortened visual summary.
- Successful copy briefly replaces the corresponding control icon with a checkmark. Tooltips and accessible labels identify translation, source, and success. The reset is cancelled when the row disappears or a newer copy supersedes it; no motion is required.
- Copy does not open the result card, restore or cancel the current session, change history order, or submit any request. Missing/evicted IDs or empty copy payloads leave the clipboard unchanged.

## Verification

TASK-050 owns automated history-copy isolation, content fidelity, stale-ID and empty-source checks, plus real-App light/dark visual and interaction evidence. History persistence, search, deletion and additional copy formats are outside this feature.
