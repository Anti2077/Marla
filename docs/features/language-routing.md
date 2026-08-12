# Configurable Language Routing

## Status

Implemented under TASK-019 and expanded under TASK-022; current expanded-language artifact verification is in progress.

## Goal

Choose a predictable translation direction from one global native language and one different secondary language, while keeping the detected source and effective target visible and correctable on each result card.

## Supported languages

The product set is Simplified Chinese (`zh-Hans`), English (`en`), Japanese (`ja`), French (`fr`), Spanish (`es`), German (`de`), and Korean (`ko`). System-detected Chinese variants normalize to the Simplified Chinese product option; Traditional Chinese is not yet an independent preference.

macOS Natural Language recognized representative full-sentence samples for all seven product languages on the TASK-022 development system. Qwen-MT's current provider documentation lists 92 languages, including the four TASK-022 additions, but languages outside Marla's product set are not treated as supported until local detection, Swift/Rust validation, UI density, and provider mapping are explicitly verified.

## Routing

- When the resolved source equals the user's native language, automatic target routes to the secondary language.
- Every other supported source and an unknown source route to the native language.
- An explicit target overrides automatic routing for the current card.
- An explicit source override recomputes the target only while the target remains automatic.
- Changing language controls cancels the current request and retranslates the already acquired text; it does not repeat Accessibility acquisition, clipboard fallback, screenshot capture, or Vision OCR.

## Detection and degradation

For screenshot input, Vision first enables automatic language detection and intersects the seven product OCR identifiers with the current runtime's supported recognition languages. Swift then uses macOS `NLLanguageRecognizer` on the resulting plain text, or on text acquired by another entry, before starting the network request. The recognized text, identifier, and hypotheses are not persisted. Common results from all seven product languages map into the supported set. Unsupported or non-linguistic results are shown as unknown; Marla then routes to the native language and lets the Provider detect source unless the user selects an explicit source.

## Provider boundary

Swift resolves every request to an optional supported source plus one explicit supported target. Translation JSON schema v2 carries both values to Rust. Generic OpenAI-compatible models receive source/target instructions in the system prompt. Qwen-MT receives matching `translation_options.source_lang` and `target_lang`, using `auto` only when Swift has no supported source.

## UI

Settings has a dedicated Translation Languages page for Native Language and Secondary Language. The two selections cannot match. The result-card header keeps the API profile selector and window controls; a second row contains source and target menus. Automatic source labels include the detected language or Unknown, and the target label always shows the effective destination.

## Not included

- an independent Traditional Chinese option;
- per-profile, per-entry, or per-application language preferences;
- a downloaded or remote language detector;
- automatic retranslation of an already open card after global settings change;
- formality, terminology, name-order, or Japanese style controls.
