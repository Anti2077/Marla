# Comparison Mode

## Status

Implemented in the current nearby-card baseline; generated semantic Markdown remains complete formatted content rather than a fabricated one-to-one source mapping.

## Goal

Keep source and translated content visibly aligned without making the compact translation surface unnecessarily large.

## Behavior

- Compact surfaces use vertically aligned source and translation blocks.
- Expanded surfaces may use side-by-side columns.
- Acquired tables retain shared rows and columns only when both sides carry reliable row/column correspondence; generated Markdown does not promise source-isomorphic table structure.
- Inline overlays show translation by default and may reveal source on interaction.
- Source and translation share stable block identifiers only where acquisition and presentation retain a reliable correspondence. Generated Markdown may naturally merge, split, move, or omit target-language nodes and is compared as complete formatted content rather than forced into source-node positions.

## Acceptance criteria

- Switching modes does not re-run OCR or translation.
- Acquired block order remains stable where reliable correspondence exists; generated Markdown may use a natural target-language order without fabricated source-node alignment.
- Long content can scroll without losing alignment.
