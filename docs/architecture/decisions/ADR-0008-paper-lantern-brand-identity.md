# ADR-0008: Paper Lantern brand identity

Status: Accepted

Date: 2026-08-14

## Context

Marla is defined as a quiet macOS translation layer that stays near the source, preserves focus, and disappears when the user is done. The project previously had no selected brand mark and explicitly required a labeled placeholder rather than an improvised low-quality icon.

Three rounds of icon exploration moved from literal translation controls, through abstract organic marks, to recognizable but restrained objects. The project owner selected Paper Lantern and explicitly adopted the idea of “a little light beside the reader” as part of the software concept.

At the start of this decision, the repository had no AppIcon asset catalog or `CFBundleIcon` configuration. Choosing a durable brand mark therefore did not, by itself, integrate a production macOS App icon. The project owner subsequently expanded the same Task to require Paper Lantern in every future App build.

## Decision

Adopt Paper Lantern as Marla's primary brand mark and product metaphor.

- Marla is a paper lantern beside the reader: it reveals unfamiliar language without taking over the page.
- The product appears only after explicit intent, stays close to the source, preserves reading context, and recedes when dismissed.
- The canonical mark is the self-contained flat SVG at `Resources/Brand/PaperLantern/logo.svg`.
- The mark uses lantern-frame indigo `#393554`, paper terracotta `#C86652`, and warm-light gold `#E6B86A`.
- The Paper Lantern mark remains separate from functional UI iconography; menus, toolbars, settings, and translation controls continue to use native SF Symbols and semantic colors.
- The menu-bar status item is an application-identity surface rather than a functional command. It uses the purpose-built monochrome Paper Lantern template at `Resources/Brand/PaperLantern/status-bar.svg`; macOS supplies the foreground color for light, dark, selected, and accessibility appearances.
- The MenuBarExtra panel header is also an application-identity surface. Its trailing, non-interactive 33.6pt mark uses full-color 34px/68px renditions derived from the canonical SVG and is offset 2pt downward for optical alignment; the adjacent title supplies accessible identity text.
- The macOS AppIcon catalog uses the Paper Lantern master shape across the standard 16, 32, 128, 256 and 512pt slots at 1x and 2x. Xcode Debug and Release both compile `AppIcon` by default.
- Fixed-App verification requires `CFBundleIconName`, `CFBundleIconFile`, `AppIcon.icns`, `Assets.car`, all 10 AppIcon renditions, both status-bar renditions, and both menu-panel brand renditions; a missing or substituted icon fails packaging verification.

## Consequences

- Product language and visual identity now share one memorable metaphor aligned with the existing “stay in place” and “preserve focus” principles.
- The mark can be versioned and exported without changing the running application's functional UI or accent behavior.
- Brand warmth does not justify glow, shadows, decorative glass, gradients, mascots, or widespread brand-color use inside the app.
- The fixed development App and subsequent Xcode App builds use Paper Lantern without a manual post-build copy step.
- The status item remains recognizable as Marla without shrinking the three-color AppIcon or introducing an independently colored menu-bar control.
- The open menu panel reinforces the same identity with the canonical three-color mark while leaving every actionable icon in the native functional system.
- Public trademark clearance, App Store naming, Developer ID signing, notarization, and distribution remain separate decisions.
