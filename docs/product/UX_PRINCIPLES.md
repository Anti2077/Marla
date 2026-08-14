# UX Principles

## Be a quiet light

Marla is a paper lantern beside the reader: it illuminates unfamiliar language without becoming the destination. The brand metaphor reinforces behavior rather than decoration. Marla appears only after explicit intent, stays near the source, keeps functional controls native, and leaves the reading context intact when dismissed.

## Stay in place

Translation belongs near the selected text, captured region, or pointer. Marla should not make a main window the default destination.

## Show intent immediately

The stable result surface should appear before network work completes. Streaming content grows the card away from its initial anchor while the anchored edge stays fixed; after the visible-workspace limit, only the translation body scrolls.

## Grow with the translation

Short results should not reserve a large empty panel. The result card starts at a compact content-driven height, grows smoothly as streamed text wraps to additional lines, and stops at 60% of the current screen's visible workspace so surrounding work remains visible.

The card also starts at a compact 380pt width. Users may widen it from the native window edges or corners up to 760pt, subject to the visible workspace; reflow updates the content-driven height instead of introducing a separate width control.

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
