# Marla

Marla is a native macOS instantaneous translation layer designed to translate without pulling the user away from their current work.

Its UI and macOS integration use SwiftUI/AppKit. Translation orchestration, provider integrations, normalized processing, context logic, and bounded caches live in an embedded Rust static library connected through a versioned C ABI.

The current incubation baseline includes:

- selected-text translation in a nearby floating card;
- region screenshot translation using default local macOS Vision or explicitly selected cloud GLM-OCR;
- a compact quick-input translator;
- a configurable OpenAI-compatible streaming text-translation endpoint.

The current implementation uploads screenshot pixels only when the user explicitly selects GLM-OCR under the disclosure in OCR Settings; Vision keeps screenshot pixels local. It does not collect contextual window text, save translation history, or cover source text in place. These are current capability and privacy facts, not a frozen release scope.

Marla is in unversioned incubation and has not started public release preparation. The native Xcode application, translation core, and core UI vertical slices are implemented. Start with [`docs/README.md`](docs/README.md) for the documentation map, [`docs/development/STATUS.md`](docs/development/STATUS.md) for verified progress, and [`docs/development/VERSIONING.md`](docs/development/VERSIONING.md) for the release-time version policy. Daily work uses one focused Task; confirmed future work and uncommitted ideas are kept separate.

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

Build and verify the stable-signed fixed-path Release development app with:

```sh
./scripts/build-test-app.sh
```

The artifact is written to `artifacts/Marla_dev.app` with development Marketing Version `0.0.0`. This is a required numeric bundle placeholder, not a public release. Each successful build replaces that same App only after a staged copy has been signed and verified; earlier test binaries are not retained. DMG packaging, notarization, automatic updates, and public distribution require a separate owner-authorized release Task.

### Stable local development signing

Ad-hoc signing (`CODE_SIGN_IDENTITY=-`) changes the code hash on every rebuild, so macOS TCC may ask for Accessibility and Screen Recording again. A helper process cannot grant those permissions on behalf of Marla. The packaging script therefore requires a stable local code-signing identity and never silently falls back to ad-hoc signing.

For the first fixed-path build, provide an identity name or certificate hash reported by `security find-identity -v -p codesigning`:

```sh
MARLA_CODE_SIGN_IDENTITY="Your Local Code Signing Identity" \
./scripts/build-test-app.sh
```

The identity name is only an example. Later no-argument builds recover the certificate hash from the existing `Marla_dev.app`, require that identity to remain valid in the login keychain, and verify that the designated requirement has not changed before replacing the old App. A custom existing output path still requires `MARLA_ALLOW_ARTIFACT_REPLACE=1`.

This is for local testing only, does not bypass or guarantee TCC persistence, and does not provide Developer ID signing or notarization. Authorize `artifacts/Marla_dev.app` in System Settings and keep launching that same path. Xcode can normally create an Apple Development identity from a free Apple account for personal local testing; paid Developer Program membership is needed later for normal Developer ID distribution and notarization.
