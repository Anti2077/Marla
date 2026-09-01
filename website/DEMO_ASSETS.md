# Marla Homepage Demo Assets

The homepage uses six independently directed real-App videos, one for each media slot. The three entry videos also receive purpose-edited square versions for mobile. Shortcut settings is a video because its inline editor motion is part of the product evidence; it must not be replaced by a still.

## Final delivery count

- 6 desktop MP4 videos: Hero, Selection, Screenshot, Quick Input, Structured Markdown, Shortcut Settings.
- 3 mobile MP4 videos: square versions of Selection, Screenshot, and Quick Input.
- 9 same-name WebP posters, one for every MP4.
- Total: **9 MP4 + 9 WebP**.

The square versions may come from the same raw takes only when the pointer, source content, selection region, and Marla surface remain legible in a deliberate 1:1 composition. Otherwise record a separate square-safe take. Do not rely on an accidental `object-fit: cover` crop.

## Storage and naming

Only approved web outputs enter the repository:

```text
website/public/media/
  desktop/
  mobile/
  posters/
    desktop/
    mobile/
```

Final naming pattern:

```text
marla-{scene}--{variant}-{ratio}.{ext}
```

- `{scene}`: `hero-in-place`, `selection`, `screenshot`, `quick-input`, `structured-markdown`, or `shortcut-settings`.
- `{variant}`: `desktop` or `mobile`.
- `{ratio}`: `5x4`, `7x5`, or `1x1`; use `x`, not `:` or `/`.
- `{ext}`: `mp4` for video and `webp` for its poster.
- Use lowercase ASCII kebab-case. Do not add spaces, Chinese characters, dates, `final`, `new`, or version suffixes to approved web files.
- A poster uses the exact same basename as its MP4 and lives under the matching `posters/` variant directory.

Raw takes remain outside the repository and use:

```text
marla-{scene}--raw-{YYYYMMDD}-take-{NN}.mov
```

Example: `marla-shortcut-settings--raw-20260901-take-03.mov`.

## Shared master specification

- Record the stable-signed `artifacts/Marla_dev.app`, not a Preview or web reconstruction.
- Use a clean 16:10 desktop at 2560×1600 or 1920×1200. A deterministic 1600×1000 logical workspace is preferred.
- Capture at 60 fps when available so native window and shortcut-editor motion has enough temporal detail; export website files at 30 fps.
- Export H.264 MP4, `yuv420p`, SDR/sRGB, with no microphone, system audio, or audio track.
- Keep important content inside the central square-safe area. Use short, deliberate pointer travel and leave the pointer still while text streams.
- Record light appearance first. Dark variants are a later optional set, not part of the first delivery.
- Do not add cursor spotlights, artificial click rings, post-production zooms, speed ramps, baked captions, device frames, or fake keyboard overlays.
- Trim dead time rather than accelerating real App motion. Preserve native panel entry, streaming, resizing, and shortcut-editor timing.
- Target roughly 3–6 MB per desktop video and 2–4 MB per square video after visual inspection.

## Video 1: Hero in-place translation

**Purpose:** establish the complete Marla product idea in the first viewport: explicit intent, a result near the source, and an immediate return to reading.

- Video: `desktop/marla-hero-in-place--desktop-5x4.mp4`
- Poster: `posters/desktop/marla-hero-in-place--desktop-5x4.webp`
- Ratio: **5:4**
- Export: **2000×1600**, 30 fps
- Duration: **12–16 seconds**
- Composition: show enough of the quiet source App to understand the reading context; keep selected text and the result card visible together.

Shot sequence:

1. `0.0–1.5s`: Hold on a clean reading page with Marla absent.
2. `1.5–3.0s`: Deliberately select two or three lines of English text near the visual center.
3. `3.0–3.5s`: Trigger `⌃⇧D`; do not add a synthetic shortcut overlay.
4. `3.5–5.5s`: Let the real nearby result card enter and settle without covering the selection.
5. `5.5–11.5s`: Show real streaming until the translation reaches a readable completed state.
6. `11.5–13.5s`: Hold the completed source-and-result relationship long enough to inspect.
7. `13.5–16.0s`: Close the card and end on the unchanged reading context.

## Video 2: Selection translation entry

**Purpose:** explain the selection workflow more tightly than the Hero, emphasizing the trigger and nearby placement.

- Desktop video: `desktop/marla-selection--desktop-7x5.mp4`
- Desktop poster: `posters/desktop/marla-selection--desktop-7x5.webp`
- Desktop ratio/export: **7:5**, **1680×1200**, 30 fps
- Mobile video: `mobile/marla-selection--mobile-1x1.mp4`
- Mobile poster: `posters/mobile/marla-selection--mobile-1x1.webp`
- Mobile ratio/export: **1:1**, **1200×1200**, 30 fps
- Duration: **8–12 seconds**

Shot sequence:

1. Start with one concise English paragraph and no Marla surface visible.
2. Select one complete sentence; avoid a selection that touches the frame edges.
3. Trigger `⌃⇧D` and keep the pointer still.
4. Capture the result card entering near the selected sentence and the first streamed text appearing.
5. Hold the readable completed result for at least two seconds.
6. Close the card and leave the source paragraph in the same position for the final beat.

The square version must keep the sentence, selection highlight, and most of the result card visible simultaneously. Reframe or re-record rather than cropping either subject away.

## Video 3: Screenshot translation entry

**Purpose:** show that the user chooses an exact screen region and that Marla uses the real frozen-selection, loupe, and OCR flow.

- Desktop video: `desktop/marla-screenshot--desktop-7x5.mp4`
- Desktop poster: `posters/desktop/marla-screenshot--desktop-7x5.webp`
- Desktop ratio/export: **7:5**, **1680×1200**, 30 fps
- Mobile video: `mobile/marla-screenshot--mobile-1x1.mp4`
- Mobile poster: `posters/mobile/marla-screenshot--mobile-1x1.webp`
- Mobile ratio/export: **1:1**, **1200×1200**, 30 fps
- Duration: **10–15 seconds**

Shot sequence:

1. `0.0–1.0s`: Show a clean page containing one small deterministic image/text region.
2. `1.0–2.0s`: Trigger `⌃⇧S`; capture the real frozen and dimmed selection surface.
3. `2.0–5.5s`: Drag a compact region at a steady speed, keeping the real loupe visible and inside the safe area.
4. `5.5–6.5s`: Pause briefly on the completed selection before confirming.
5. `6.5–9.0s`: Confirm and show the genuine OCR/translation waiting state if it occurs; do not lengthen it artificially.
6. `9.0–13.0s`: Let the nearby result card appear and reach a readable completed state.
7. `13.0–15.0s`: Hold the final result without moving the pointer.

Use Vision for the first public-facing capture unless cloud OCR has separately approved live evidence. The video must not imply that the configured translation Provider is offline.

## Video 4: Quick Input entry

**Purpose:** show the path for text that is not already selectable on screen. Keep this story simple; rich Markdown has its own video.

- Desktop video: `desktop/marla-quick-input--desktop-7x5.mp4`
- Desktop poster: `posters/desktop/marla-quick-input--desktop-7x5.webp`
- Desktop ratio/export: **7:5**, **1680×1200**, 30 fps
- Mobile video: `mobile/marla-quick-input--mobile-1x1.mp4`
- Mobile poster: `posters/mobile/marla-quick-input--mobile-1x1.webp`
- Mobile ratio/export: **1:1**, **1200×1200**, 30 fps
- Duration: **8–12 seconds**

Shot sequence:

1. Begin on a neutral desktop or source App with no Marla window visible.
2. Trigger `⌃⇧Space` and capture the real Quick Input entrance motion.
3. Paste or type one short two-line plain-text fixture; do not use personal clipboard content.
4. Submit the translation and keep the pointer clear of the text.
5. Capture the waiting/streaming transition and content-driven panel growth.
6. Hold the completed result for at least two seconds, then dismiss it.

For the square version, compose the Quick Input panel centrally and keep both the input and first completed output lines readable.

## Video 5: Structured Markdown

**Purpose:** prove that structured content remains structured rather than becoming an undifferentiated text block.

- Video: `desktop/marla-structured-markdown--desktop-5x4.mp4`
- Poster: `posters/desktop/marla-structured-markdown--desktop-5x4.webp`
- Ratio: **5:4**
- Export: **1600×1280**, 30 fps
- Duration: **12–16 seconds**
- Fixture: one heading, paragraph, bulleted list, block quote, link, inline code, fenced code block, and compact GFM table.

Shot sequence:

1. Open Quick Input with `⌃⇧Space` and paste the deterministic Markdown fixture.
2. Hold for one second so the source hierarchy can be inspected.
3. Submit and capture the first streaming delta becoming native structured content.
4. Let the result panel grow naturally without post-production scaling.
5. After completion, make one slow vertical scroll that reveals the table and code block.
6. Stop scrolling and hold on a frame where at least three distinct structures are visible together.

Do not use HTML rendering, a browser mockup, or a fixture containing URLs, tokens, account names, or commands that could be mistaken for credentials.

## Video 6: Shortcut settings motion

**Purpose:** showcase the real inline shortcut editor, especially the 320 ms matched-geometry fusion, one-row-at-a-time editing, and clean return to the collapsed state.

- Video: `desktop/marla-shortcut-settings--desktop-7x5.mp4`
- Poster: `posters/desktop/marla-shortcut-settings--desktop-7x5.webp`
- Ratio: **7:5**
- Export: **1400×1000**, 30 fps
- Capture master: 60 fps strongly preferred
- Duration: **10–14 seconds**

Shot sequence:

1. `0.0–1.5s`: Hold on the real Shortcuts Settings page with all three rows collapsed and defaults readable.
2. `1.5–3.0s`: Click the Selection shortcut chip and let it fuse into the inline editor at native speed.
3. `3.0–5.0s`: Toggle one modifier and capture one main-key input so controls visibly respond. Use a clean test preference state.
4. `5.0–7.5s`: Activate the Screenshot row while Selection is still expanded; capture the first row collapsing as the second expands, proving mutual exclusivity.
5. `7.5–10.0s`: Use Cancel or restore the intended binding, then apply or close the active editor.
6. `10.0–12.5s`: Hold on the three collapsed rows with no error state.
7. `12.5–14.0s`: Optionally move the pointer out of the window for a neutral final frame.

Keep the entire 820×592 Settings window logically stable during capture. Do not show API profiles, account information, Keychain prompts, or unrelated settings pages. Restore default bindings after recording if the test state changed.

## Poster selection

- Export one same-name WebP poster for every MP4 at the video's exact pixel dimensions.
- Choose a stable frame after motion has settled, never a blurred transition or half-streamed sentence.
- Hero poster: completed result beside the selection.
- Selection poster: sentence, highlight, and nearby result all visible.
- Screenshot poster: completed region with loupe, or completed result; choose the clearer frame after layout review.
- Quick Input poster: input and readable result visible together.
- Markdown poster: heading, list, and table or code visible together.
- Shortcut poster: one inline editor fully expanded with the other two rows still legible.
- Encode WebP in sRGB without metadata that exposes the machine or user account.

## Privacy and truth checklist

- Use a dedicated test macOS account or clean capture desktop with no personal files, notifications, bookmarks, account names, IP addresses, or unrelated menu-bar utilities visible.
- Use deterministic public or repository-owned fixtures. Do not record email, chat, browsing history, clipboard history, or a real user's document.
- Never reveal API keys, endpoint credentials, Keychain prompts, Provider account details, authentication methods, or private model names.
- Review every raw take frame-by-frame around notifications, menu-bar changes, pointer movement, and window transitions before approval.
- Keep rejected raw takes outside the repository. Add only approved, edited web assets under `website/public/media/`.

## Integration verification

After approval, add all 9 MP4 and 9 WebP files under `website/public/media/`. Use responsive sources for the three square entry videos. Verify autoplay, muted/playsInline behavior, loop boundaries, poster fallback, mobile source selection, loading performance, and Reduce Motion static fallback in a real browser. These videos demonstrate the real App; they do not constitute acceptance evidence for unverified Providers or public release readiness.
