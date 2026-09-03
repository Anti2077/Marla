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

Marla never mutates source content. Selection and ordinary screenshot translation use a nearby anchored card with honest pointer fallback when exact geometry is unavailable. The independent in-place translation entry temporarily covers only its own captured rectangle: the frozen pixels appear immediately after capture, and the same nonactivating surface owns recognition, translation, completion and failure. Reliable GLM-OCR glyph regions are restored from their row-wise neighboring pixels before block-keyed translations are drawn at those coordinates. The window must remain visibly dismissible and memory-only; closing it reveals the untouched source application beneath it.

## Degrade honestly

For selection and ordinary screenshot translation, present a nearby translation panel when exact line geometry is unavailable. Do not pretend an imprecise overlay is exact.

Inside independent screenshot reconstruction, Provider ID mismatch, no reliable positioned block or rendering failure keeps the frozen screenshot in the same overlay and changes its compact status to the specific failure. It does not open a nearby result card. A complete validated block translation may still contain individual OCR regions with missing bounds, severe overlap, unreadable fit or complex background; those regions keep their frozen source pixels while reliable blocks render in place. Never estimate Vision layout, invent coordinates or draw a rejected block approximately.

## Keep privacy visible

The interface must distinguish image upload, text-only cloud translation, and local OCR. A local OCR fallback does not imply that translation itself is offline.

## Keep comparison aligned

Source and translated content share stable block identifiers only where acquisition and presentation retain a reliable correspondence. Generated semantic Markdown may naturally merge, split, move, or omit target-language nodes, so comparison treats it as complete formatted content instead of inventing a one-to-one mapping.
