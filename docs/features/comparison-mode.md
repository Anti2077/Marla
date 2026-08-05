# Comparison Mode

## Status

Planned for 0.1.0.

## Goal

Keep source and translated content visibly aligned without making the compact translation surface unnecessarily large.

## Behavior

- Compact surfaces use vertically aligned source and translation blocks.
- Expanded surfaces may use side-by-side columns.
- Tables retain shared rows and columns.
- Inline overlays show translation by default and may reveal source on interaction.
- Source and translation always share stable block identifiers.

## Acceptance criteria

- Switching modes does not re-run OCR or translation.
- Block order remains stable.
- Long content can scroll without losing alignment.
