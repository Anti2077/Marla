# Marla Website Media

This directory stores approved, web-ready Marla homepage media only. Raw captures, editing projects, rejected takes, and private review exports stay outside the repository.

## Directory layout

```text
desktop/          Approved desktop MP4 files
mobile/           Approved square mobile MP4 files
posters/desktop/  Desktop WebP posters
posters/mobile/   Mobile WebP posters
```

## Final naming rule

```text
marla-{scene}--{variant}-{ratio}.{ext}
```

Allowed scene names:

- `hero-in-place`
- `selection`
- `screenshot`
- `quick-input`
- `structured-markdown`
- `shortcut-settings`

Allowed variants and ratios:

- `desktop-5x4`
- `desktop-7x5`
- `mobile-1x1`

Allowed extensions:

- `mp4` for video
- `webp` for poster

Examples:

```text
desktop/marla-hero-in-place--desktop-5x4.mp4
desktop/marla-shortcut-settings--desktop-7x5.mp4
mobile/marla-selection--mobile-1x1.mp4
posters/desktop/marla-shortcut-settings--desktop-7x5.webp
posters/mobile/marla-selection--mobile-1x1.webp
```

Every MP4 must have one WebP poster with the exact same basename in the matching poster directory.

## Raw take naming

Raw takes remain outside this directory and outside Git:

```text
marla-{scene}--raw-{YYYYMMDD}-take-{NN}.mov
```

Example: `marla-shortcut-settings--raw-20260901-take-03.mov`.

Do not use spaces, Chinese characters, `final`, `new`, `latest`, or arbitrary version suffixes in media filenames. See `website/DEMO_ASSETS.md` for the complete shot list and export specifications.
