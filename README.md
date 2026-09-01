<div align="center">
  <img src="Resources/Brand/PaperLantern/logo-512.png" width="112" alt="Marla Paper Lantern mark">
  <h1>Marla</h1>
  <p><strong>Translation that stays beside what you are reading.</strong></p>
  <p>A native macOS translation layer that appears on intent, stays close to the source, and gets out of the way.</p>
  <p>在原文旁点亮翻译，读完即走，不把你带离当前工作。</p>

  <p>
    <img src="https://img.shields.io/badge/status-incubation-C86652?style=flat-square" alt="Status: incubation">
    <img src="https://img.shields.io/badge/platform-macOS%2014%2B-393554?style=flat-square&amp;logo=apple&amp;logoColor=white" alt="Platform: macOS 14 or later">
    <img src="https://img.shields.io/badge/Swift-6.2-C86652?style=flat-square&amp;logo=swift&amp;logoColor=white" alt="Swift 6.2">
    <img src="https://img.shields.io/badge/Rust-1.85-E6B86A?style=flat-square&amp;logo=rust&amp;logoColor=393554" alt="Rust 1.85">
  </p>

  <p>
    <a href="#why-marla">Why Marla</a> ·
    <a href="#three-ways-in">Workflows</a> ·
    <a href="#privacy-without-hand-waving">Privacy</a> ·
    <a href="#development">Development</a> ·
    <a href="docs/README.md">Documentation</a>
  </p>
</div>

<p align="center">
  <strong><a href="website/public/media/desktop/marla-hero-in-place--desktop-5x4.mp4">Watch the real Marla workflow (MP4)</a></strong>
</p>

<p align="center"><sub>Real native macOS app capture. GitHub opens the MP4 in its media viewer.</sub></p>

## Why Marla

Most translation tools become another destination. Marla keeps the user's current application as the primary surface: invoke it with a shortcut, read a nearby result, dismiss it, and continue from the same place.

- **Stays in place.** Selection and screenshot results appear in a nearby native card instead of a main translation window.
- **Shows intent immediately.** The stable result surface appears before the network response and grows with streamed content.
- **Preserves structure.** Quick Input and supported rich selections keep semantic Markdown through translation and native rendering.
- **Keeps providers replaceable.** Named OpenAI-compatible profiles make the text-translation endpoint and model an explicit user choice.

## Three ways in

| Entry | Default shortcut | What happens |
| --- | --- | --- |
| **Selected text** | `⌃⇧D` | Marla safely acquires the current selection and streams a result beside the source. |
| **Screen region** | `⌃⇧S` | A frozen multi-display frame supports region selection, local Vision OCR, and an explicitly selected GLM-OCR option. |
| **Quick Input** | `⌃⇧Space` | A compact editor translates typed or pasted content, including supported Markdown structure. |

The shortcuts are configurable. Completed results support comparison, copy, retry, system speech, pinning, language changes, and provider switching without turning Marla into a document workspace.

## Native where it matters

```text
Explicit trigger
  → SwiftUI / AppKit acquisition and presentation
  → versioned in-process C ABI
  → embedded Rust core for providers, streaming, normalization, and cancellation
  → nearby native result surface
```

Marla is a Swift 6 macOS app with SwiftUI for durable surfaces and AppKit for menu-bar, panel, focus, and screen-level behavior. The Rust 2024 core is embedded as a static library: there is no localhost backend or separate always-running service.

## Privacy, without hand-waving

| Path | Current boundary |
| --- | --- |
| **Selection translation** | Only an explicitly triggered, protected Copy transaction may provide content. Accessibility is used for permission and positioning, not as a hidden text source. |
| **Vision screenshot OCR** | The selected screenshot crop remains local for OCR. Text translation may still use the configured cloud provider. |
| **GLM-OCR** | Screenshot pixels are uploaded only when the user explicitly selects GLM-OCR under the disclosure in Settings. |
| **Storage** | Screenshots and recent translations are session-only. Persistent translation history and contextual window-text collection are not implemented. |

Marla does not claim to be fully offline. The exact provider, OCR, and data boundaries are intentionally visible rather than collapsed into a single privacy slogan.

## Project status

Marla is in **Incubation / Unreleased**. The native application and its core workflows are implemented, but public release preparation has not started: there is no public download, assigned product version, notarized package, updater, or selected public license yet.

- [Verified development status](docs/development/STATUS.md)
- [Product definition](docs/product/PRODUCT.md)
- [Architecture](docs/architecture/ARCHITECTURE.md)
- [Paper Lantern brand](docs/product/BRAND.md)
- [Website prototype](website/README.md)

## Development

### Prerequisites

- macOS 14 or later on Apple Silicon
- Xcode 26.5 or a compatible full Xcode installation
- Swift 6.2 or later
- Rust 1.85 or later

Run the complete repository check:

```sh
./scripts/check.sh
```

The script formats, builds, and tests the Rust core and Swift layer, builds the native Debug app against the Cargo debug library, validates the project structure, and checks the diff. It selects the full Xcode installation only for its own commands and does not change the machine-wide `xcode-select` setting.

Build the fixed-path, stable-signed Release development app:

```sh
./scripts/build-test-app.sh
```

The verified artifact is written to `artifacts/Marla_dev.app` with the development-only Marketing Version `0.0.0`. This numeric value is bundle metadata, not a public release version.

<details>
<summary><strong>First local signed build</strong></summary>

The packaging script requires a stable local code-signing identity and never silently falls back to ad-hoc signing. Pass an identity name or certificate hash reported by `security find-identity -v -p codesigning`:

```sh
MARLA_CODE_SIGN_IDENTITY="Your Local Code Signing Identity" \
./scripts/build-test-app.sh
```

Later no-argument builds recover the certificate hash from the existing fixed app and verify that its designated requirement remains stable before replacement. This supports local testing only; it does not provide Developer ID distribution, notarization, or automatic TCC approval.

</details>

### Repository map

| Path | Role |
| --- | --- |
| `Sources/MarlaApp/` | SwiftUI/AppKit application, acquisition, settings, sessions, and presentation |
| `Sources/MarlaCore/` | Swift-facing bridge models and provider contracts |
| `Sources/MarlaRustFFI/` | Versioned C bridge between Swift and Rust |
| `rust/marla-core/` | Embedded provider, streaming, OCR normalization, and cancellation core |
| `website/` | Independent React/Vite product-homepage prototype |
| `docs/` | Product truth, architecture, Tasks, status, and verification evidence |
| `scripts/` | Repository checks, packaging, and artifact verification |

Start with the [documentation map](docs/README.md), then read the [current status](docs/development/STATUS.md) and its active Task before making changes. The repository keeps product ideas, confirmed backlog, active implementation, and verified evidence deliberately separate.

---

<p align="center"><sub>Paper Lantern: a little light beside the reader.</sub></p>
