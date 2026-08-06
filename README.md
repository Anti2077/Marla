# Marla

Marla is a native macOS instantaneous translation layer designed to translate without pulling the user away from their current work.

Its UI and macOS integration use SwiftUI/AppKit. Translation orchestration, provider integrations, normalized processing, context logic, and bounded caches live in an embedded Rust static library connected through a versioned C ABI.

The active 0.1.0 Alpha scope is:

- selected-text translation in a nearby floating card;
- region screenshot translation using local macOS Vision OCR only;
- a compact quick-input translator;
- a configurable OpenAI-compatible streaming text-translation endpoint.

0.1.0 does not upload screenshot pixels, collect contextual window text, save translation history, cover source text in place, or provide cloud structured OCR. See [`docs/versions/0.1.0/SPEC.md`](docs/versions/0.1.0/SPEC.md) for the complete bilingual release contract.

The native Xcode application, translation core, and 0.1.0 UI vertical slices are implemented. Start with [`docs/README.md`](docs/README.md) for the documentation map and [`docs/development/STATUS.md`](docs/development/STATUS.md) for verified progress. Daily work uses one focused Task; confirmed future work and uncommitted ideas are kept separate.

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

### Stable local development signing

Ad-hoc signing (`CODE_SIGN_IDENTITY=-`) changes the code hash on every rebuild, so macOS TCC may ask for Accessibility and Screen Recording again. A helper process cannot grant those permissions on behalf of Marla. If a stable local codesigning identity is available in the login keychain, use it for a stable development artifact:

```sh
MARLA_CODE_SIGN_IDENTITY="Marla Local Development" \
MARLA_ARTIFACT_PATH="artifacts/Marla_dev.app" \
MARLA_ALLOW_ARTIFACT_REPLACE=1 \
./scripts/build-test-app.sh
```

The identity name is only an example. Create or select a persistent Code Signing identity in the login keychain, then find its exact name with `security find-identity -v -p codesigning`; the script deliberately fails if that identity is unavailable or untrusted. This is for local testing only, does not bypass TCC, and does not provide Developer ID signing or notarization. Authorize the stable `Marla_dev.app` once in System Settings and keep launching that same path. Xcode can normally create an Apple Development identity from a free Apple account for personal local testing; paid Developer Program membership is needed later for normal Developer ID distribution and notarization.
