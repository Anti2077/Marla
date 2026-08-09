# ADR-0006: Opt-in simulated Copy compatibility for selection translation

Status: Accepted

Date: 2026-08-09

## Context

Some Electron, chat, and custom-rendered macOS applications visibly highlight text but do not expose a usable Accessibility selection. Bob and open-source tools such as SelectedTextKit demonstrate that simulating `⌘C`, reading the resulting selection, and restoring the original pasteboard can cover these surfaces.

Marla's original 0.1.0 boundary avoided all clipboard reads and writes. The project owner has now authorized a Bob-compatible fallback, provided it is explicit, disabled by default, bounded to one trigger, and cannot silently overwrite clipboard data.

## Decision

Keep Accessibility as the first selection path. Add a user-enabled, default-off compatibility mode owned by Swift/AppKit:

1. Capture every readable `NSPasteboard.general` item, type, order, and data representation in memory. The pasteboard `changeCount` must remain stable across capture; if any representation cannot be captured or the count changes, abort before sending `⌘C`.
2. Confirm the trigger-time source application is still frontmost before Copy and immediately before accepting text.
3. Send one public CGEvent `⌘C` and accept only non-empty text observed after a new pasteboard `changeCount`.
4. Restore the complete snapshot on success, empty result, error, cancellation, and timeout when the pasteboard still has the expected change count. Re-read every restored representation and treat any mismatch as restoration failure.
5. If another process writes after Marla's Copy, do not overwrite that newer content; expose only a redacted diagnostic status. If restoration fails, do not send a translation request.
6. Never log or persist selection text, pasteboard data, API keys, or snapshots. Rust receives only the selected text after Swift completes the transaction.

The compatibility toggle is persisted in application preferences and is off for existing and new installations.
A repeated selection shortcut while Copy is pending cancels the active read; cleanup completes before another transaction may begin.

## Consequences

- Codex, WeChat, and other custom text surfaces can use the application's own Copy implementation when AX is unavailable.
- The compatibility mode requires Accessibility permission and temporarily handles sensitive clipboard data in memory.
- The default path retains the previous no-clipboard privacy behavior.
- Complete restoration and concurrent-write checks add latency and require explicit manual validation with a multi-type clipboard.
- Browser extensions, DOM injection, private APIs, and per-application scripts remain outside this decision.
