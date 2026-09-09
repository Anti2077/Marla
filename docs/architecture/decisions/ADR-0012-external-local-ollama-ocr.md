# ADR-0012: Optional external Ollama GLM-OCR for nearby screenshot translation

Status: Accepted; implementation authorized by TASK-045

Date: 2026-09-08

## Context

ADR-0002 selected macOS Vision as the default local OCR and cloud GLM-OCR as the optional structured OCR path. It required a new decision before adopting a local structure model. The project owner has now authorized a bounded local GLM-OCR experiment through an existing Ollama installation.

Ollama is a user-managed process with its own model storage and update lifecycle. Marla's accepted architecture prohibits the app from starting a localhost backend, bundling a continuously running sidecar, or shipping a local VLM without an explicit decision. The local Ollama model also returns generated OCR text but has not demonstrated the stable normalized block bounds required by ADR-0011 for in-place screenshot reconstruction.

## Decision

Marla may offer `本机 Ollama GLM-OCR` as an explicit OCR Provider for ordinary nearby-card screenshot translation under these limits:

- the user installs, starts, updates and removes Ollama and the `glm-ocr` model independently of Marla;
- Marla connects only to the fixed loopback endpoint `http://127.0.0.1:11434/api/generate` and fixed model name `glm-ocr`;
- the request contains the explicitly selected, memory-only screenshot encoding, a fixed OCR prompt, `stream: false` and no credential;
- Rust owns the Ollama request, timeout, cancellation, response validation and provider-independent OCR event, while Swift owns capture, UI state and lifecycle;
- the returned `response` is accepted only when non-empty and structurally valid within the bounded OCR table dialect; simple tables become GFM, while spans and inline-rich tables remain inert canonical HTML rendered with native TextKit; no web view, resource loading or invented geometry/confidence is introduced;
- ordinary local Ollama failure may use the existing visible Vision fallback, including the user's one-click fallback while recognition is pending;
- Vision remains the persisted default for ordinary screenshots, and cloud GLM-OCR remains available under its existing disclosure and credential contract;
- independent in-place translation continues to force cloud GLM-OCR because that path requires canonical blocks with reliable normalized bounds.

Marla does not launch or supervise Ollama, download or delete models, expose arbitrary localhost URLs, persist screenshot bytes, or bundle a local model. Connecting to an already-running user-managed Ollama instance does not change ADR-0004's prohibition on a Marla-owned sidecar.

## Consequences

- Users can keep ordinary screenshot pixels on the machine while obtaining richer Markdown than Vision may provide.
- Local availability, model size, cold-start latency and output quality depend on the user's Ollama installation and machine.
- The local result is useful for the nearby translation pipeline but is not evidence for coordinate-aware in-place reconstruction.
- A future bundled runtime, configurable endpoint, model manager or local layout-coordinate contract requires another explicit Task and ADR amendment.
