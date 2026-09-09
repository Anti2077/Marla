# Synthetic local OCR table evaluation

These are deterministic synthetic application tables, not captured websites or user screenshots.
The seven scenarios cover invoices, API parameters, feature comparison, bilingual inventory,
key/value properties, grouped column headers and row-group schedules. The two irregular shapes
are informed by the W3C WAI table tutorial; all text and numbers are original synthetic data.

The scripts are development-only tools. They do not run from Marla, install software, manage
Ollama, or read credentials. The Python standard library sends images directly to loopback,
bypassing proxy environment variables. Ollama must already be available on port 11434.

Run from the repository root:

```sh
mkdir -p artifacts/ocr-eval/task-045
python3 scripts/ocr-table-eval/fixtures.py artifacts/ocr-eval/task-045/fixtures.json
swift scripts/ocr-table-eval/render.swift artifacts/ocr-eval/task-045/fixtures.json artifacts/ocr-eval/task-045
python3 scripts/ocr-table-eval/run.py artifacts/ocr-eval/task-045
```

`run.py` snapshots the actual production OCR prompt and evaluates each fixture once, with a
120-second per-request limit. It saves raw output only for these synthetic images under ignored
`artifacts/`. Never place user screenshots in the fixture directory. Re-running overwrites the
artifact evidence: use a fresh output directory when comparing runs.

`results.json` has response timing, exact-title/footer substring flags, tags, spans and cell text.
Exact substring flags are not quality scores; code/Markdown formatting can make them false even
when visible text is retained. HTML counts do not prove a valid grid; compare with `fixtures.json`
and inspect all returned text for missing sections, repeated tables and altered commands.

Synthetic raw/canonical responses are checked in under `rust/marla-core/tests/fixtures/ocr-tables/`.
They are regression inputs, not model output to be blindly treated as correct. The Rust tests
assert that the checked-in canonical forms match the current normalizer; Swift tests project
those same canonical files into native tables. The API sample is intentionally rejected because
its extra unescaped pipe gives ambiguous cell ownership.

For optional native component snapshots (not a complete app/real translation acceptance):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
MARLA_OCR_UI_EVIDENCE_DIR="$PWD/artifacts/ocr-eval/task-045" \
swift test --disable-sandbox --filter HTMLTableProjectionTests
```

The full evidence and current limits are in `docs/development/OCR_TABLE_EVALUATION_2026-09-08.md`.
