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
2. Screenshot translation of a selected screen region.
3. Quick input when no source text is already available.

## Initial output modes

- translation-first mode;
- aligned comparison mode;
- pinned or transient presentation;
- system speech using macOS voices.

## Explicitly deferred

- PDF, Office, and batch document translation;
- a full document workspace;
- local GLM-OCR;
- cloud structured OCR in 0.1.0; macOS Vision is the only 0.1.0 OCR path;
- source-text-covering in-place translation, rejected after the experimental surface performed poorly in real use;
- contextual window metadata and nearby-text enhancement in 0.1.0;
- persistent translation history in 0.1.0;
- arbitrary live-page pixel-perfect replacement;
- browser-specific DOM rewriting;
- cloud synchronization and accounts;
- automatic persistent glossary learning.

## Success criteria

- translation can be invoked without opening a main window;
- the result appears near the user's work and does not unnecessarily steal focus;
- normal operation remains below the documented memory budget;
- the 0.1.0 privacy boundary sends only explicitly triggered source text; bounded context enhancement remains a later release;
- failures degrade to a usable local or nearby-panel experience.
