# Marla Homepage Demo Assets

The homepage needs four source captures from the real stable-signed development App: three short recordings and one shortcut-settings still. These four captures cover all six homepage media slots through reuse and cropping; do not record six separate videos. Until recording content and repository persistence are explicitly approved, the page uses designed empty media stages with fixed ratios; it does not use screenshots as substitute evidence or simulate native App behavior.

## Capture count

| Source capture | Type | Duration / frame | Reused by homepage slots |
| --- | --- | --- | --- |
| Selection translation master | 16:10 video | 8–12 seconds | Hero 5:4 + Selection entry 7:5 |
| Screenshot translation master | 16:10 video | 10–15 seconds | Screenshot entry 7:5 |
| Quick Input + Markdown master | 16:10 video | 8–12 seconds | Quick Input entry 7:5 + Markdown Bento 5:4 |
| Shortcut settings | Still image | One clean completed frame | Shortcut settings Bento 7:5 |

Total acquisition work: **3 video recordings + 1 still image**. The 1:1 mobile versions are central crops from the same masters and are not separate recordings.

## Video masters

| Flow | Duration | Story | Proposed file |
| --- | --- | --- | --- |
| Selection translation | 8–12 seconds | Select one English paragraph in a clean test page, trigger `⌃⇧D`, and let the nearby result card reach a readable completed state. | `public/media/selection-translation.mp4` |
| Screenshot translation | 10–15 seconds | Trigger `⌃⇧S`, frame a small deterministic region with the loupe visible, then show the OCR wait state and nearby result. | `public/media/screenshot-translation.mp4` |
| Quick Input + Markdown | 8–12 seconds | Open Quick Input, paste a short fixture containing a heading, list, table, link, and code, then show the structured completed result. | `public/media/quick-input-markdown.mp4` |

## Website image outputs

Export six WebP images after the masters are approved. Video slots use these as posters, and Reduce Motion uses them as the complete static experience.

| Output | Ratio | Source |
| --- | --- | --- |
| `hero-selection.webp` | 5:4 | Selection master |
| `selection-translation.webp` | 7:5 | Selection master |
| `screenshot-translation.webp` | 7:5 | Screenshot master |
| `quick-input-markdown.webp` | 7:5 | Quick Input + Markdown master |
| `markdown-completed.webp` | 5:4 | Completed frame from Quick Input + Markdown master |
| `shortcut-settings.webp` | 7:5 | Dedicated shortcut-settings still |

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

The three MP4 files each have a same-name `.webp` poster. Hero additionally uses `hero-selection.webp`, while Markdown and shortcut settings use their dedicated static outputs. The current `MediaStage` components reserve the layout and can be replaced without changing the surrounding page structure. `prefers-reduced-motion` should continue to use static WebP rather than autoplay.

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

After the assets are approved, add the 3 MP4 and 6 WebP files under `website/public/media/`, replace the corresponding stages with video-plus-poster or static media components, and verify autoplay, looping, poster fallback, mobile cropping, and Reduce Motion in a real browser. The videos are demonstrations, not acceptance evidence for unverified providers or public release readiness.
