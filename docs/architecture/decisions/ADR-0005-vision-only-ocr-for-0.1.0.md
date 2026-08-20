# ADR-0005: Vision-only screenshot OCR for 0.1.0

Status: Historical incubation boundary; cloud-path portion superseded by TASK-033 under ADR-0002

Date: 2026-08-05

## 2026-08-19 amendment

The project owner explicitly authorized TASK-033 after the provisional release contract was withdrawn. TASK-033 fulfills this ADR's prerequisites for a bounded cloud path: Vision remains default and local, GLM-OCR requires an explicit Provider choice and upload disclosure, one Keychain credential, normalized structure contracts, cancellation, visible Vision fallback and new acceptance evidence. The original Vision-only rule below remains historical `0.1.0` context and continues to describe Vision mode; it no longer prohibits the owner-authorized GLM path during unversioned incubation.

## 2026-08-18 amendment

ADR-0010 withdrew the provisional `0.1.0` release target and removed version-number scheduling from incubation. At the time of this amendment, the substantive boundary remained accepted: Vision was the only implemented screenshot OCR path, screenshots remained memory-only and were not uploaded, and adding cloud OCR still required an explicit Task, disclosure, provider/structure contracts, fallback behavior, and new acceptance evidence. TASK-033 later supplied that authorization and evidence. The references to `0.1.0` below preserve the original decision context; they do not describe the current provider set or freeze incubation scope.

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
