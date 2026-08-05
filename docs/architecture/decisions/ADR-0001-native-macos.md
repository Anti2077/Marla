# ADR-0001: Native macOS implementation

Status: Superseded in part by ADR-0004

Date: 2026-08-05

## Context

Marla depends on Accessibility selection geometry, ScreenCaptureKit, non-activating panels, global triggers, system speech, and highly polished macOS interaction.

## Decision

Use Swift 6 with SwiftUI and AppKit for the native application layer. AppKit owns capabilities where SwiftUI does not expose sufficient focus or window control.

ADR-0004 moves non-UI business-core responsibilities to Rust while preserving this native presentation and platform-integration decision.

## Consequences

- Best access to macOS platform behavior and performance.
- A macOS-only initial product.
- Full Xcode is required for final application packaging and permission validation.
- Cross-platform UI frameworks are not introduced in the initial architecture.
