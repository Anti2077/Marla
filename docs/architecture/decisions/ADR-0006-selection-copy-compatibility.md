# ADR-0006: Protected simulated Copy as the selection content source

Status: Accepted

Date: 2026-08-09

Updated: 2026-08-16

## Context

Some Electron, chat, Markdown-preview, and custom-rendered macOS applications visibly select structured content but expose incomplete, flattened, or inconsistent Accessibility values. The earlier ADR-0006 decision kept Accessibility as the primary content path and offered protected simulated Copy as an explicit default-off compatibility fallback. TASK-028 real-source testing showed that this split still flattened rich content and made acquisition behavior depend on a setting rather than the user's selection trigger.

The project owner has now authorized one deterministic production path: selection content always comes from the source application's own Copy representations under a protected, bounded transaction. Accessibility remains necessary for trust and may improve placement, but it is no longer a content source or fallback.

## Decision

Use one Swift/AppKit protected simulated Copy transaction for every production selection trigger:

1. Capture every readable `NSPasteboard.general` item, type, order, and data representation in memory. The pasteboard `changeCount` must remain stable across capture; if any representation cannot be captured or the count changes, abort before sending `⌘C`.
2. Confirm the trigger-time source application is still frontmost before Copy and immediately before accepting text.
3. Send one public CGEvent `⌘C`; accept content only after a new Pasteboard `changeCount`, recheck that the trigger-time application is still frontmost, and read the new Markdown, HTML, RTF/RTFD, and plain-text representations before any restoration. Validate rich and plain visible text only within the same Pasteboard item. Never accept an unchanged or pre-existing Pasteboard value.
4. Restore the complete snapshot on success, empty result, error, cancellation, and timeout when the pasteboard still has the expected change count. Re-read every restored representation and treat any mismatch as restoration failure.
5. If another process writes after Marla's Copy, do not overwrite that newer content; expose only a redacted diagnostic status. Snapshot, focus, Copy, timeout, content, or restoration failure sends no translation request and presents a specific error with a Quick Input action.
6. Normalize reliable rich representations locally to `semanticMarkdown`; otherwise emit `plainText`. HTML parsing removes scripts, styles, explicitly hidden nodes, image resources, and unsafe links without executing content or loading remote resources.
7. Never log or persist selection content, Pasteboard data, normalized Markdown, API keys, or snapshots. Rust receives only the normalized `TranslationContent` after Swift completes the transaction.
8. Accessibility may provide trust state, focused-application identity checks, selection ranges, Text Marker ranges, and bounds for non-content positioning. It must not provide selected strings, attributed values, range-derived strings, Text Marker-derived strings, or fallback content.

The former Copy-compatibility toggle and its default-off behavior are removed from the product contract. A repeated selection shortcut while Copy is pending cancels the active transaction; cleanup completes before another acquisition may begin.

## Consequences

- Codex, WeChat, FluxMarkdown, and other custom or rich text surfaces use the same source-owned Copy representation path instead of application-specific AX content behavior.
- Selection translation requires Accessibility trust and temporarily handles sensitive Pasteboard data in memory after each explicit trigger.
- The previous no-Pasteboard default path no longer exists for selection translation. This does not authorize continuous clipboard observation or using pre-existing clipboard content.
- Missing or failed Copy cannot silently fall back to Accessibility content; the user receives an actionable error and can open Quick Input.
- Complete restoration and concurrent-write checks add latency and require explicit manual validation with a multi-type clipboard.
- Browser extensions, DOM injection, private APIs, and per-application scripts remain outside this decision.
