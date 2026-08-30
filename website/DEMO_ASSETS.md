# Marla Homepage Demo Assets

The homepage should eventually use three short recordings of the real stable-signed development App. Until recording content and repository persistence are explicitly approved, the page uses designed empty media stages with fixed ratios; it does not use screenshots as substitute evidence or simulate native App behavior.

## Delivery set

| Flow | Duration | Story | Proposed file |
| --- | --- | --- | --- |
| Selection translation | 8–12 seconds | Select one English paragraph in a clean test page, trigger `⌃⇧D`, and let the nearby result card reach a readable completed state. | `public/media/selection-translation.mp4` |
| Screenshot translation | 10–15 seconds | Trigger `⌃⇧S`, frame a small deterministic region with the loupe visible, then show the OCR wait state and nearby result. | `public/media/screenshot-translation.mp4` |
| Quick Input + Markdown | 8–12 seconds | Open Quick Input, paste a short fixture containing a heading, list, table, link, and code, then show the structured completed result. | `public/media/quick-input-markdown.mp4` |

## Homepage slot ratios

Use these ratios for the first approved export. Record a larger 16:10 desktop master when possible, and keep the important cursor, selection, loupe, source text, and result card inside the central square-safe area so the same take can be cropped for mobile.

| Homepage slot | Desktop ratio | Suggested export | Notes |
| --- | --- | --- | --- |
| Hero media stage | 5:4 | 2000×1600 | Main product-context take; keep the reading surface and nearby result relationship visible. |
| Selection / screenshot / Quick Input entries | 7:5 | 1680×1200 | One ratio for all three accordion panels; use the same dimensions for MP4 and WebP poster. |
| Structured Markdown Bento | 5:4 | 1600×1280 | A completed-state still or a short close-up of headings, lists, tables, links, and code. |
| Shortcut settings Bento | 7:5 | 1400×1000 | Keep the shortcut rows readable without showing account or personal settings. |
| Mobile-safe crop | 1:1 | 1200×1200 | Central crop from the master; do not record a separate take unless the desktop composition cannot survive the crop. |

The web stages reserve these ratios before any media is added, so replacing an empty stage with an approved clip does not change surrounding layout or cause a content shift.

Each MP4 needs a same-name `.webp` poster. The current `MediaStage` components reserve the layout and can be replaced by an approved video plus poster without changing the surrounding page structure. `prefers-reduced-motion` should continue to use the static poster rather than autoplay.

## Capture setup

- Capture the stable-signed fixed App at a deterministic 1440×900 or 1600×1000 logical desktop layout.
- Record at 30 fps without microphone or system audio; trim dead time instead of accelerating the interaction.
- Export H.264 MP4, yuv420p, without an audio track. Keep each clip below roughly 5 MB for the prototype.
- Use one quiet, neutral test page and the repository's structured-translation fixtures. Keep pointer travel short and deliberate.
- Produce light appearance first. A dark set is useful only after the first three clips are approved.
- Do not add cursor spotlights, fake clicks, zoom cuts, captions baked into the image, or browser chrome that competes with Marla.

## Privacy and truth checklist

- Use a dedicated test macOS account or a clean capture desktop with no personal files, notifications, bookmarks, account names, IP addresses, or menu-bar utilities visible.
- Use deterministic public or repository-owned fixture text. Do not record email, chat, browsing history, clipboard history, or a real user's document.
- Never reveal API keys, endpoint credentials, Keychain prompts, provider account details, or authentication methods.
- Do not label Vision OCR as fully offline translation. The clip may show local OCR, while the accompanying page copy must continue to distinguish OCR from the configured translation Provider.
- Do not persist raw capture takes until the project owner approves the test content and storage location. Keep rejected takes outside the repository.
- Review every exported frame at normal speed and at several seek points before replacing the current poster fallback.

## Integration

After the assets are approved, add the media under `website/public/media/`, replace the corresponding stage with a video-plus-poster media component, and verify autoplay, looping, poster fallback, mobile cropping, and Reduce Motion in a real browser. The videos are demonstrations, not acceptance evidence for unverified providers or public release readiness.
