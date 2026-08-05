# Development Workflow

## Starting work

1. Read `AGENTS.md`.
2. Read `STATUS.md` and its required-reading list.
3. Inspect current code and tests.
4. Confirm that the requested work belongs to the current milestone.
5. Record or report any documentation mismatch before implementation.

## Finishing work

1. Run relevant automated and manual checks.
2. Update affected feature specifications.
3. Update `STATUS.md` to the verified current state.
4. Update the roadmap only when milestone scope changes.
5. Create or supersede an ADR only when a durable decision changes.
6. Keep implementation and its documentation synchronized in the same change.

## Current verification command

Run:

```sh
./scripts/check.sh
```

The script checks Rust formatting, runs Rust tests, builds the Rust static library, selects `/Applications/Xcode.app` through `DEVELOPER_DIR` only for its own process, builds and tests Swift, checks source files for trailing whitespace, and checks Git diffs for whitespace errors. `--disable-sandbox` disables SwiftPM's nested sandbox because the agent environment already applies an outer filesystem sandbox.

## Documentation statuses

- Proposed: designed but not implemented.
- In Progress: implementation exists but acceptance is incomplete.
- Implemented: code path exists.
- Verified: acceptance criteria have current evidence.
- Deferred: intentionally outside the current milestone.

## History

Do not append session transcripts to `STATUS.md`. Use Git commits and release notes for historical detail. Keep only current progress, current risks, and the next ordered work.
