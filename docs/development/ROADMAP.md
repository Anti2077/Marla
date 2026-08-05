# Roadmap

## Active release: 0.1.0 Alpha

0.1.0 takes a deliberately bounded path through M1-M4:

1. Stable Xcode macOS app target, Bundle ID, permissions, Rust build integration, and timestamped test-app packaging.
2. OpenAI-compatible streaming translation through the versioned Rust FFI.
3. Selection translation in a nearby non-activating card; in-place source covering is deferred.
4. Vision-only local screenshot OCR; cloud structured OCR is deferred until after 0.1.0.
5. Quick input, comparison, copy, retry, system speech, pinning, configurable shortcuts, and permission onboarding.
6. Compatibility, performance, memory, privacy, and real-app visual acceptance.

The complete release contract is under `docs/versions/0.1.0/`.

## M0: Product planning and durable documentation

- Define initial scope, architecture, feature specifications, and decisions.
- Establish the Agent reading and documentation-update workflow.

## M1: Technical feasibility

- Build a native menu-bar application skeleton.
- Establish and validate the embedded Rust static-library bridge.
- Validate Accessibility selected-text and bounds behavior.
- Validate non-activating inline presentation.
- Test whether global Force Touch is reliable enough to ship as an optional trigger.
- Validate ScreenCaptureKit across displays and scale factors.
- Measure OCR and translation latency with representative samples.

## M2: Inline translation vertical slice

- Reliable keyboard trigger.
- Selection acquisition without contextual window data in 0.1.0.
- Streaming translation provider.
- Nearby non-activating result card for 0.1.0; in-place overlay remains future work.
- Translation-first and comparison presentation.

## M3: Screenshot translation vertical slice

- Region-selection experience.
- Vision-only local OCR and plain-text rendering for 0.1.0.
- Cloud structured OCR and layout-aware rendering after 0.1.0.

## M4: Productization

- Permission onboarding.
- Settings, Keychain credentials, privacy controls, and optional history.
- Compatibility, performance, accessibility, signing, notarization, and update strategy.

## M5: Universal translation workspace

- Main document interface.
- PDF and common document formats.
- Re-evaluate local structured OCR and document models.
