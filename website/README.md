# Marla Homepage Prototype

This isolated React + Vite prototype presents Marla's current product direction without changing the native macOS application or implying a public release.

## Run locally

```sh
npm install
npm run dev
```

Vite prints the local URL after startup. The page imports the canonical Paper Lantern SVG and selected real App screenshots from the parent repository so the prototype stays aligned with current product evidence.

## Verify

```sh
npm run lint
npm run build
```

The build emits static files under `website/dist/`. Motion respects the operating system's Reduce Motion preference through `prefers-reduced-motion` and GSAP media queries.

The three product-entry media slots currently use verified App screenshots. See [`DEMO_ASSETS.md`](DEMO_ASSETS.md) for the privacy-safe recording plan and the filenames expected when real MP4 demonstrations are approved.
