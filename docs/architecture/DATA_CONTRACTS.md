# Data Contracts

## Translation intent

A `TranslationIntent` records the user's requested operation, its input kind, source and target language, presentation preference, and contextual snapshot.

## Text selection

A `TextSelection` preserves the source text exactly and may carry global screen bounds plus source-application identity. Text can be acquired even when bounds are unavailable; presentation must then choose the nearby-panel fallback.

## Content blocks

All OCR and translation content is normalized into stable blocks containing:

- stable identifier;
- semantic kind;
- source text;
- normalized bounds when known;
- reading order;
- confidence when known.

Translation updates refer to the same block identifiers. Providers must not silently invent new geometry.

For 0.1.0 Vision OCR, blocks represent recognized lines and reading order only. Table, Markdown, formula, and document-layout semantics are not inferred.

## Context snapshot

Context is supporting evidence, not content to translate. It includes bounded nearby text and locally derived classifications. Raw window metadata should be sanitized before transmission.

No `ContextSnapshot` fields cross the translation boundary in 0.1.0. The type remains groundwork for a later version.

## FFI translation request

The Swift/Rust translation boundary uses UTF-8 JSON request `schemaVersion: 2` while provider events remain schema version 1. A request contains a request ID, exact source text, an optional resolved source language, one explicit resolved target language, endpoint configuration, optional request-scoped credential, and timeouts. Supported language codes are `zh-Hans`, `en`, `ja`, `fr`, `es`, `de`, and `ko`. A missing source means the Provider may detect source; target is never implicit at the Rust boundary. Rust copies request bytes synchronously and never retains a Swift buffer.

Swift snapshots native/secondary preferences into each card, resolves automatic routing before encoding, and preserves that snapshot across retry or API-profile switching. Source/target UI changes create a new request ID from the existing source text. Detection identifiers and confidence are not persisted.

The API Key is transferred in request memory only and must never be logged. Swift persistently owns one versioned Keychain vault item containing independent logical entries keyed by profile identity; Rust never receives or persists the vault.

## Provider events

Streaming translation emits lifecycle and block-update events so presentation can remain vendor-independent:

- started;
- delta;
- completed;
- failed with a stable code and retryability;
- cancelled.

Every event includes schema version and request ID. Swift discards events whose request ID no longer owns the card. Callback bytes are valid only during the callback and must be copied before returning.
