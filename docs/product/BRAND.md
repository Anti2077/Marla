# Marla Brand Concept

Status: Accepted

Decision: Paper Lantern

Source: [ADR-0008](../architecture/decisions/ADR-0008-paper-lantern-brand-identity.md)

## 产品意象

Marla 是阅读旁边的一盏纸灯：它在用户明确需要时出现，用一小束温暖而克制的光照亮陌生语言，但不把页面变成自己的舞台。它靠近原文、保留阅读上下文，并在不再需要时退场。

这是一条产品行为原则，不是装饰口号。界面不应为了呼应纸灯而堆叠发光、阴影、暖色底板或品牌装饰，也不应让品牌色取代系统强调色和原生功能状态。

## Product metaphor

Marla is a paper lantern beside the reader: it appears when explicitly invited and uses a small, warm, restrained light to reveal unfamiliar language without turning the page into its own stage. It stays near the source, preserves reading context, and recedes when no longer needed.

This is a product-behavior principle, not a decorative slogan. The interface does not add glow, shadow, warm backplates, or brand ornament merely to echo the lantern, and brand colors do not replace the system accent or native functional states.

## Primary mark

The Paper Lantern mark is Marla's primary brand symbol. Its master source is:

```text
Resources/Brand/PaperLantern/logo.svg
```

The mark uses three flat planes:

| Role | Color | Meaning |
| --- | --- | --- |
| Lantern frame | `#393554` | quiet structure and the surrounding reading context |
| Paper body | `#C86652` | warmth, tactility, and human presence |
| Lit opening | `#E6B86A` | the small area of language being made legible |

The silhouette is intentionally a little asymmetric. It should feel like folded paper rather than a polished light bulb, festival lantern, character, or assistant mascot.

## Usage

- Use the SVG as the canonical editable source; derived PNGs are reference exports.
- Preserve the original aspect ratio and at least one-eighth of the mark width as clear space.
- Use the full-color mark at 32px or larger by default. The sanctioned 24pt selection/screenshot result-card identity described below is the only smaller full-color in-product exception. At 16px, retain the supplied master shape without adding detail.
- Place the transparent mark on quiet light or dark backgrounds with sufficient contrast.
- Use a purpose-built monochrome adaptation only when a destination cannot reproduce the three flat colors; do not recolor individual planes ad hoc.

## Menu-bar mark

The menu-bar status item is Marla's compact application-identity surface, not a functional action icon. It uses the purpose-built monochrome source at `Resources/Brand/PaperLantern/status-bar.svg` and the 18pt 1x/2x template renditions in `Resources/Assets.xcassets/StatusBarIcon.imageset`.

The adaptation retains the lantern shell and central opening but removes color planes and small details that do not survive menu-bar scale. It must remain a template image so macOS controls its foreground in light, dark, selected, increased-contrast, and other system appearances. Do not use the full-color AppIcon, a fixed brand color, or a surrounding badge in the status area.

## Menu-panel mark

The MenuBarExtra panel header is an application-identity surface rather than a command. Its “Marla” title and subtitle move 4pt upward together. The trailing 33.6pt `PaperLanternMark` uses 34px/68px full-color renditions derived directly from `Resources/Brand/PaperLantern/logo.svg` and remains at its existing size and position, including its 2pt downward optical offset. The adjacent “Marla” title already supplies the accessible identity, so the image is decorative to assistive technologies.

The panel mark has no badge, accent tint, glow, shadow, or interaction, and it does not replace any functional SF Symbol.

## Result-card mark

Selection and screenshot result-card headers use a 24pt full-color `PaperLanternMark` beside the dynamic 17pt semibold entry title. This is a compact identity treatment and the sanctioned exception to the default 32px minimum. The mark is non-interactive and hidden from assistive technologies because the adjacent title already names the entry.

Quick Input does not use this treatment. It keeps the keyboard SF Symbol and its existing compact title styling. The API-profile menu sits 2pt lower for optical alignment; its interaction is unchanged. Pin, close, language-row, and all other controls retain their existing SF Symbols, placement semantics, and behavior.

## Boundaries

- Paper Lantern is a brand mark, not a universal functional icon. Its in-product identity surfaces are the menu-bar status item, menu-panel header, and selection/screenshot result-card headers described above. Menu commands, toolbars, settings rows, screenshot actions, and result-card controls continue to use SF Symbols at a consistent weight.
- The mark does not authorize a second UI accent palette. Interactive emphasis continues to use `Color.accentColor` and native semantic colors.
- Do not add gradients, glow, drop shadows, glass, texture, facial features, speech bubbles, language glyphs, or translation arrows.
- Do not rotate, stretch, crop, outline, or place the mark inside an arbitrary badge.
- Do not imply that Marla, Vision OCR, or cloud translation is fully offline through the lantern metaphor.

## App icon status

Paper Lantern is integrated as the production macOS AppIcon. `Resources/Assets.xcassets/AppIcon.appiconset` provides the standard 16, 32, 128, 256 and 512pt macOS slots at 1x and 2x. Both Xcode Debug and Release configurations compile this set as `AppIcon`, so subsequent App builds use it without manual copying.

The fixed Release development App has been rebuilt and verified with `CFBundleIconName` and `CFBundleIconFile` set to `AppIcon`, plus compiled `AppIcon.icns` and `Assets.car` resources containing all 10 Paper Lantern renditions. Functional UI iconography remains separate and continues to use SF Symbols.
