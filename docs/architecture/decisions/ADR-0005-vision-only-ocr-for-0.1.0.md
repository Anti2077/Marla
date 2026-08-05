# ADR-0005: Vision-only screenshot OCR for 0.1.0

Status: Accepted

Date: 2026-08-05

## Context

Marla 0.1.0 translates small user-selected screen regions and is intended as a lightweight daily-usable Alpha. Cloud structured OCR would add an image-upload privacy path, provider credentials, response normalization, latency, and layout acceptance before the core instantaneous interaction has been validated.

macOS Vision already provides local text recognition suitable for the Alpha's short screenshots. It does not reliably recover complex tables, formulas, Markdown, or document layout, and the version must describe that limitation honestly.

## Decision

Use macOS Vision as the only screenshot OCR provider in 0.1.0.

- Process the selected crop in memory and never upload image pixels.
- Preserve recognized plain text, line order, and line breaks only.
- Send only recognized text to the configured translation API.
- Expose no cloud OCR toggle or GLM-OCR credential in 0.1.0 UI.
- Keep cloud GLM-OCR as a post-0.1.0 structured-OCR direction under ADR-0002.

## Consequences

- The Alpha has a smaller binary, lower memory demand, fewer credentials, and a clearer privacy boundary.
- Screenshot translation remains usable offline through the OCR stage, although text translation still requires the configured endpoint.
- Table and layout fidelity are explicitly outside 0.1.0 acceptance.
- Adding cloud OCR later requires explicit image-upload disclosure, provider implementation, normalized structure contracts, and new acceptance evidence.
