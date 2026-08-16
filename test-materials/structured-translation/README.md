# Structured Translation Test Materials

Manual fixtures for validating Marla's plain-text and semantic Markdown paths.

## Layout

- `plain-text/`: Chinese, English, Japanese, and Korean source text without Markdown markup.
- `markdown/`: The same four source languages with headings, lists, emphasis, links, quotes, tables, code, and protected tokens.

## Suggested checks

1. Translate each `.txt` file and confirm no Markdown styling is introduced unexpectedly.
2. Paste each `.md` file into Quick Input and confirm the source remains editable Markdown.
3. Confirm completed Markdown renders headings, lists, quotes, code, and links.
4. Copy the completed result and confirm tokens such as `MARLA_API_KEY`, `{{STATUS}}`, `${BUILD_ID}`, URLs, and commands remain intact.
