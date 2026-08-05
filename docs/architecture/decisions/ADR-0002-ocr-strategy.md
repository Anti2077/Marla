# ADR-0002: Cloud structured OCR with system fallback

Status: Accepted for post-0.1.0; scoped by ADR-0005

Date: 2026-08-05

## Context

The first screenshot workflow processes small user-selected regions. Mid-sized local document models add packaging and memory cost without clearly outperforming both macOS Vision for simple text and GLM-OCR for complex structure.

## Decision

Use cloud GLM-OCR as the planned structured screenshot OCR and macOS Vision as the local, offline, timeout, and failure fallback. Do not bundle a local OCR VLM in the initial product.

ADR-0005 narrows version 0.1.0 to macOS Vision only. This decision remains the planned structured-OCR direction after 0.1.0 and must not be interpreted as an active image-upload path in the Alpha.

## Consequences

- The application remains small and avoids multi-gigabyte model memory.
- Complex OCR requires network access and an explicit image-upload privacy disclosure.
- Local Vision OCR can preserve functionality but may lose complex table or layout structure.
- Future document workflows may revisit local structure models through a new ADR.
