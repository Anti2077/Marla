# ADR-0003: Bounded on-demand context

Status: Accepted

Date: 2026-08-05

## Context

Translation quality benefits from surrounding text and domain knowledge, but continuous window capture would create privacy, latency, energy, and stale-context problems.

## Decision

Collect bounded context only when translation is triggered. Maintain a short-lived per-application-window text and terminology cache. Do not continuously screenshot windows or treat provider prompt caching as semantic memory.

The current implementation defers this engine entirely: it sends no nearby text, window title, or application classification to the translation provider. ADR-0010 removes the former release-number timing, but implementation still requires a separate owner-authorized Task with bounded collection, sanitization, disclosure, and acceptance.

## Consequences

- Context is useful without background surveillance.
- Application identity remains a weak hint; nearby text has higher priority.
- Persistent glossary entries require explicit user approval.
- Context limits and sanitization become testable product behavior.
