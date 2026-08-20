# ADR-0002: Cloud structured OCR with system fallback

Status: Accepted; implementation authorized by TASK-033

Date: 2026-08-05

## Context

The first screenshot workflow processes small user-selected regions. Mid-sized local document models add packaging and memory cost without clearly outperforming both macOS Vision for simple text and GLM-OCR for complex structure.

## Decision

Use cloud GLM-OCR as the planned structured screenshot OCR and macOS Vision as the local, offline, timeout, and failure fallback. Do not bundle a local OCR VLM in the initial product.

ADR-0010 superseded the former `post-0.1.0` timing. On 2026-08-19, the project owner explicitly authorized TASK-033, which defines the upload disclosure, one-Key credential UI, fixed Provider contract, normalized structure contract, cancellation, Vision fallback and acceptance required here. Vision remains the default; selecting GLM-OCR is the upload authorization.

## Consequences

- The application remains small and avoids multi-gigabyte model memory.
- Complex OCR requires network access and an explicit image-upload privacy disclosure.
- Local Vision OCR can preserve functionality but may lose complex table or layout structure.
- Future document workflows may revisit local structure models through a new ADR.
