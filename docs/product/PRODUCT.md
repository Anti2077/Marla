# Marla Product Definition

## Status

Accepted initial product definition.

## Product statement

Marla is a native macOS instantaneous translation layer. Its primary surface is the user's current application, not a traditional translation window.

The user should be able to notice text, express translation intent, read the result near the original content, dismiss it, and continue working with minimal context switching.

## Initial users

- people reading multilingual web pages, software interfaces, terminal output, documentation, email, and chat;
- people who frequently translate short passages or small screen regions;
- users who value macOS-native interaction, low latency, and clear privacy boundaries.

## Initial entry points

1. Translation of selected text in a nearby card, triggered by a configurable shortcut.
2. Experimental Force Touch trigger for the same selection translation intent.
3. Screenshot translation of a selected screen region.
4. Quick input when no source text is already available.

Force Touch is not allowed to replace the keyboard fallback until global cross-application reliability is verified.

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
- pixel-covering in-place translation in 0.1.0;
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
