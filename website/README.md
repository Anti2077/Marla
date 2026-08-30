# Marla Homepage Prototype

This isolated React + Vite prototype presents Marla's current product direction without changing the native macOS application or implying a public release.

## Run locally

```sh
npm install
npm run dev
```

Vite prints the local URL after startup. The page imports the canonical Paper Lantern SVG and uses fixed-ratio media stages reserved for future approved real App footage; it does not present screenshots or simulate native App behavior.

## Verify

```sh
npm run lint
npm run build
```

The build emits static files under `website/dist/`. Motion respects the operating system's Reduce Motion preference through `prefers-reduced-motion` and GSAP media queries.

The Hero, three product-entry slots, Markdown Bento, and shortcut card currently use designed empty stages. See [`DEMO_ASSETS.md`](DEMO_ASSETS.md) for the privacy-safe recording plan, ratios, and filenames expected when real MP4 demonstrations are approved.
