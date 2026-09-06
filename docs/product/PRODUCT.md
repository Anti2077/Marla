# Marla Product Definition

## Status

Accepted initial product definition.

## Product statement

Marla is a native macOS instantaneous translation layer. Its primary surface is the user's current application, not a traditional translation window.

The user should be able to notice text, express translation intent, read the result near the original content, dismiss it, and continue working with minimal context switching.

## Product metaphor

Marla is a paper lantern beside the reader: a small, warm light that reveals unfamiliar language without taking over the page. It appears only when invited, stays close to the source, preserves the reader's context, and recedes when the translation is no longer needed.

The metaphor describes product behavior, not decoration. Marla does not turn the reading surface into a branded destination or spread brand colors across functional controls. The selected Paper Lantern mark and its usage boundaries are defined in [`BRAND.md`](BRAND.md).

## Initial users

- people reading multilingual web pages, software interfaces, terminal output, documentation, email, and chat;
- people who frequently translate short passages or small screen regions;
- users who value macOS-native interaction, low latency, and clear privacy boundaries.

## Initial entry points

1. Translation of selected text in a nearby card, triggered by a configurable shortcut.
2. Screenshot translation of a selected screen region into a nearby card.
3. Independent in-place translation of a selected screen region using GLM-OCR geometry (experimental; enabled from Settings > 实验室).
4. Quick input when no source text is already available.

## Initial output modes

- translation-first mode;
- aligned comparison mode;
- pinned or transient presentation;
- system speech using macOS voices.
- bounded same-frame screenshot reconstruction for the independent in-place entry.

## Current non-capabilities

These items are not implemented in the current incubation baseline. This list records product truth; it is not a release freeze. The project owner may select one through a future Task, subject to the required product, privacy, architecture, and verification decisions.

- PDF, Office, and batch document translation;
- a full document workspace;
- local GLM-OCR;
- selected-text inline covering, rejected after the experimental surface performed poorly in real use and still removed;
- contextual window metadata and nearby-text enhancement;
- persistent translation history;
- arbitrary live-page pixel-perfect replacement;
- browser-specific DOM rewriting;
- cloud synchronization and accounts;
- automatic persistent glossary learning.

## Success criteria

- translation can be invoked without opening a main window;
- the result appears near the user's work and does not unnecessarily steal focus;
- normal operation remains below the documented memory budget;
- the current privacy boundary sends only explicitly triggered source content; Vision keeps screenshot pixels local, while explicitly selected GLM-OCR uploads only the chosen crop under its Settings disclosure; bounded context enhancement requires a separate owner-authorized Task and the Accepted ADR constraints;
- failures degrade to a usable local or nearby-panel experience.

When the user explicitly invokes the independent in-place translation entry, Marla immediately places the same frozen crop in a temporary nonactivating overlay at the captured frame, then keeps GLM-OCR waiting, layout translation, completion and failure inside that one surface. Ordinary screenshot translation remains a nearby-card function even when its selected OCR Provider is GLM-OCR; independent in-place translation never automatically opens that card after capture and does not fall back to Vision geometry. The screenshot content is limited to the captured region, keeps all pixels and layout data memory-only, remains immediately dismissible, and redraws only blocks whose coordinates, text fit and row-wise background reconstruction are reliable; an individual rejected block keeps its frozen source pixels. Invalid block identity, no reliable block or rendering failure leaves an explicit compact failure state over the same frozen region. This does not authorize live-page replacement, Vision-estimated geometry, selected-text covering or pixel-perfect restoration of source UI.

The owner-authorized 2026-09-05 TASK-041 extension adds a SwiftUI glass boundary outside that unchanged region. Its updated contract uses a 6pt idle ring; on approach the sides/bottom become 10pt and the top expands into a 36pt glass band. Fixed exterior reserves of 12pt at the sides/bottom and 40pt at the top keep the screenshot stationary. Only a completed result exposes “移到翻译窗口”, centered as a 28pt-high native button inside the expanded top band, never over the screenshot. The action moves the full validated, ordered Markdown, including blocks omitted from the overlay's visual reconstruction, into the existing translation window without another capture, OCR or translation request. It releases the screenshot and layout while retaining only text and existing card metadata; it does not automatically add history. The existing close action stays discoverable, and a hidden ordinary result window cannot intercept the overlay's input or clear its session. The visual and interaction acceptance remains tracked by TASK-041; this is not a claim that every real-App pointer and system-glass scenario has already been verified.

The independent in-place path is intentionally experimental. It is disabled by default and can be enabled or disabled from the Settings sidebar's “实验室” page. The switch gates only the independent menu and shortcut path; ordinary screenshot translation, including its Vision default and nearby-card presentation, remains available and unchanged. Disabling the switch also cancels and closes an active in-place overlay so the experimental surface cannot remain unexpectedly visible.
