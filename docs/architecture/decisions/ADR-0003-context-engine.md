# ADR-0003: Bounded on-demand context

Status: Accepted

Date: 2026-08-05

## Context

Translation quality benefits from surrounding text and domain knowledge, but continuous window capture would create privacy, latency, energy, and stale-context problems.

## Decision

Collect bounded context only when translation is triggered. Maintain a short-lived per-application-window text and terminology cache. Do not continuously screenshot windows or treat provider prompt caching as semantic memory.

Version 0.1.0 defers this engine entirely: it sends no nearby text, window title, or application classification to the translation provider. The decision remains accepted for a later version.

## Consequences

- Context is useful without background surveillance.
- Application identity remains a weak hint; nearby text has higher priority.
- Persistent glossary entries require explicit user approval.
- Context limits and sanitization become testable product behavior.
