# UX Principles

## Be a quiet light

Marla is a paper lantern beside the reader: it illuminates unfamiliar language without becoming the destination. The brand metaphor reinforces behavior rather than decoration. Marla appears only after explicit intent, stays near the source, keeps functional controls native, and leaves the reading context intact when dismissed.

## Stay in place

Translation belongs near the selected text, captured region, or pointer. Marla should not make a main window the default destination. The independent in-place screenshot surface is experimental and opt-in from Settings > 实验室, so ordinary screenshot translation remains the predictable default path.

## Show intent immediately

The stable result surface should appear before network work completes. Streaming content grows the card away from its initial anchor while the anchored edge stays fixed; after the visible-workspace limit, only the translation body scrolls.

## Grow with the translation

Short results should not reserve a large empty panel. The result card starts at a compact content-driven height, grows smoothly as streamed text wraps to additional lines, and stops at 60% of the current screen's visible workspace so surrounding work remains visible.

The card also starts at a compact 380pt width. Users may widen it from the native window edges or corners up to 760pt, subject to the visible workspace; reflow updates the content-driven height instead of introducing a separate width control.

## Preserve focus

Transient translation surfaces should use non-activating AppKit panels where practical. Clicking into a result may intentionally activate it, but merely presenting a result should not disrupt the source application.

## Prefer reversible overlays

Marla never mutates source content. Selection and ordinary screenshot translation use a nearby anchored card with honest pointer fallback when exact geometry is unavailable. The independent in-place translation entry temporarily covers only its own captured rectangle: the frozen pixels appear immediately after capture, and the same nonactivating surface owns recognition, translation, completion and failure. Reliable GLM-OCR glyph regions are restored from their row-wise neighboring pixels before block-keyed translations are drawn at those coordinates. The window must remain visibly dismissible and memory-only; closing it reveals the untouched source application beneath it.

## Reveal actions deliberately

The active TASK-041 glass-chrome revision keeps a visible boundary around the frozen region: SwiftUI renders a translucent 6pt idle ring, expanding to 10pt sides/bottom and a 36pt top glass band on edge approach. Fixed exterior reserves of 12pt at the sides/bottom and 40pt above the screenshot prevent movement, scaling or reflow. The 28pt-high transfer button appears centered inside the expanded top band, never over the screenshot; the existing close action stays discoverable. Session-local tracking includes the header so reaching its action does not collapse it and is removed with the overlay; this does not authorize global polling or source-window monitoring. Keyboard and accessibility actions can reveal the expanded controls without pointer hover. Reduced-motion, reduced-transparency and increased-contrast preferences preserve a clear boundary and readable actions.

After successful completion only, the user may explicitly move the full validated translation into the existing translation window. This is a presentation choice, never an automatic transition or error fallback. Preserve all ordered Markdown, including translations omitted by the overlay quality gate, without capture, OCR or translation repeating; close the overlay and release its screenshot/layout context. Retain only the card's text and existing metadata, without automatically adding history. These are the extension's required behaviors; its implementation and visual acceptance remain tracked by the active Task.

Input belongs to the visible surface. A hidden ordinary translation window must not consume the overlay's click or Escape or clear its shared session before an action executes. Interaction verification must exercise the production dismissal monitors, not only an isolated rendering fixture.

## Degrade honestly

For selection and ordinary screenshot translation, present a nearby translation panel when exact line geometry is unavailable. Do not pretend an imprecise overlay is exact.

Inside independent screenshot reconstruction, Provider ID mismatch, no reliable positioned block or rendering failure keeps the frozen screenshot in the same overlay and changes its compact status to the specific failure. It does not open a nearby result card. A complete validated block translation may still contain individual OCR regions with missing bounds, severe overlap, unreadable fit or complex background; those regions keep their frozen source pixels while reliable blocks render in place. Never estimate Vision layout, invent coordinates or draw a rejected block approximately.

## Keep privacy visible

The interface must distinguish image upload, text-only cloud translation, and local OCR. A local OCR fallback does not imply that translation itself is offline.

## Keep comparison aligned

Source and translated content share stable block identifiers only where acquisition and presentation retain a reliable correspondence. Generated semantic Markdown may naturally merge, split, move, or omit target-language nodes, so comparison treats it as complete formatted content instead of inventing a one-to-one mapping.
