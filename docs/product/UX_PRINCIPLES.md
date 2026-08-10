# UX Principles

## Stay in place

Translation belongs near the selected text, captured region, or pointer. Marla should not make a main window the default destination.

## Show intent immediately

The stable result surface should appear before network work completes. Streaming content fills an already-positioned container rather than repeatedly changing the surrounding geometry.

## Preserve focus

Transient translation surfaces should use non-activating AppKit panels where practical. Clicking into a result may intentionally activate it, but merely presenting a result should not disrupt the source application.

## Prefer reversible overlays

Marla never mutates or visually covers source content. Selection translation uses a nearby anchored card with honest pointer fallback when exact geometry is unavailable.

## Degrade honestly

When exact line geometry is unavailable, present a nearby translation panel. Do not pretend an imprecise overlay is exact.

## Keep privacy visible

The interface must distinguish image upload, text-only cloud translation, and local OCR. A local OCR fallback does not imply that translation itself is offline.

## Keep comparison aligned

Source and translated content share stable block identifiers so that comparison mode never relies on visual guesswork or a model-generated reorder.
