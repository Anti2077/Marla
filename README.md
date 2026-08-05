# Marla

Marla is a native macOS instantaneous translation layer designed to translate without pulling the user away from their current work.

Its UI and macOS integration use SwiftUI/AppKit. Translation orchestration, provider integrations, normalized processing, context logic, and bounded caches live in an embedded Rust static library connected through a versioned C ABI.

The active 0.1.0 Alpha scope is:

- selected-text translation in a nearby floating card;
- region screenshot translation using local macOS Vision OCR only;
- a compact quick-input translator;
- a configurable OpenAI-compatible streaming text-translation endpoint.

0.1.0 does not upload screenshot pixels, collect contextual window text, save translation history, cover source text in place, or provide cloud structured OCR. See [`docs/versions/0.1.0/SPEC.md`](docs/versions/0.1.0/SPEC.md) for the complete bilingual release contract.

The native Xcode application foundation is in place, and implementation is now entering the translation-core phase. Start with [`docs/development/STATUS.md`](docs/development/STATUS.md) for verified progress and next steps.

## Development prerequisites

- macOS 14 or later
- Xcode 26.5 or a compatible full Xcode installation
- Swift 6.2 or later
- Rust 1.85 or later

The Swift Package foundation and Debug Xcode app can be checked together with:

```sh
./scripts/check.sh
```

This formats, builds, and tests the Rust core and Swift layer, then builds the native Debug `.app` with the Cargo debug library. It selects full Xcode only for the command and does not change machine-wide `xcode-select`.

Build and verify an ad-hoc-signed timestamped Release test app with:

```sh
./scripts/build-test-app.sh
```

The artifact is written under `artifacts/` as `Marla_test_yyyyMMddHHmm.app`. DMG packaging, notarization, automatic updates, and public distribution remain outside 0.1.0.
