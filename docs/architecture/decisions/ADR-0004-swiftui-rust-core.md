# ADR-0004: SwiftUI application with an embedded Rust core

Status: Accepted

Date: 2026-08-05

## Context

Marla requires top-tier native macOS interaction while its translation orchestration, provider integrations, structured OCR normalization, caching, and cancellation logic benefit from a strongly isolated systems core. The project is still early enough to establish this boundary without a costly migration.

## Decision

Use a hybrid architecture:

- SwiftUI and AppKit own presentation, Accessibility, ScreenCaptureKit, keyboard triggers, pasteboard compatibility, Keychain access, system speech, and macOS lifecycle.
- Rust owns translation orchestration, translation and cloud-OCR provider adapters, normalized structured-content processing, context classification, bounded caches, retry policy, cancellation, and provider-independent session state.
- Compile Rust as a static library embedded in the app. Expose a versioned C ABI and wrap it with ergonomic Swift types.
- Do not introduce Tauri, a web view, a localhost HTTP server, or a continuously running Rust sidecar.

The current bridge starts with synchronous API-version and application-surface classification calls. Later asynchronous operations will use opaque request handles, explicit cancellation and destruction functions, and callbacks whose payloads are copied before the call returns.

## Ownership and safety rules

- Swift keeps API credentials in Keychain and provides credentials to narrowly scoped Rust requests; Rust does not invent a second persistent secret store.
- Swift owns macOS framework objects. Rust never receives `AXUIElement`, `NSWindow`, or other Objective-C object pointers.
- FFI functions never unwind across the C boundary.
- Every Rust allocation returned across FFI must have one documented Rust deallocator.
- ABI changes increment `marla_core_api_version` and update the checked-in C header and Swift wrapper together.
- UI callbacks are marshalled onto Swift's `MainActor` before changing observable state.

## Consequences

- Native interaction remains first-class and does not depend on a cross-platform UI framework.
- Business logic can be tested with fast Rust unit tests and kept independent of SwiftUI.
- The app has no service port or extra background process to manage.
- Cargo must build the static library before Swift/Xcode links the application.
- FFI schemas and ownership require deliberate maintenance; complex Swift and Rust types cannot cross the boundary directly.
