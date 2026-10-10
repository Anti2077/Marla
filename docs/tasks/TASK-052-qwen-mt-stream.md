# TASK-052：修复 Qwen-MT Flash 增量流翻译

Status: Done

Owner: Project owner + Agent

Created: 2026-10-10

Updated: 2026-10-11

Origin: direct request / defect

Conversation: 2026-10-10，切换 Qwen-MT Flash 后翻译报不连续流式内容

## Execution context

- Worktree: `/private/tmp/marla-task-052-qwen-mt-stream`
- Branch: `Anti2077/task-052-qwen-mt-stream`
- Base commit: `ceda7cb0442876d6bdb440234db1d40f3a673909`
- Integration target: `main`
- Integration owner: `/Users/anti/Documents/ChatGPT/Marla`
- Integration status: Integrated
- Depends on: None
- Expected merge order: Independent of TASK-051
- Owned paths: `rust/marla-core/src/lib.rs`, `rust/marla-core/src/qwen_mt_stream_tests.rs`, this Task, `docs/features/language-routing.md` (Qwen stream contract), `docs/architecture/ARCHITECTURE.md` (Qwen stream paragraphs), `docs/architecture/decisions/ADR-0009-semantic-markdown-translation-contract.md` (provider stream capability correction)
- Known overlaps: TASK-051 may also synchronize architecture / ADR-0009; reconcile only the Qwen stream wording during integration, preserving its math scope.

## Initial request

“貌似 qwen-mt-turbo 不提供了，我切到 mt-flash 结果显示不连续，修复一下。” Owner screenshot shows Qwen-MT-flash, partial `What`, and “翻译服务返回了不连续的流式内容。”

## Outcome

Qwen-MT Flash translation streams to completion without a false discontinuity error, while legacy cumulative Qwen-MT output retains strict normalization. Provide a verified fixed-path signed development App for owner acceptance.

## Why now

The current Rust adapter recognizes all `qwen-mt-*` as cumulative streams. The official OpenAI-compatible Flash example concatenates incremental `delta.content`, reproducing the screenshot error under the existing normalizer.

## In Scope

- Model-specific stream capabilities for the existing OpenAI-compatible Qwen-MT adapter: Flash/Lite incrementally append; Turbo/Plus retain cumulative normalization.
- Preserve sole User Message, `translation_options`, language routing, thinking omission, canonical text, cancellation/timeouts and strict in-place block validation.
- Regression tests through the real Rust HTTP/SSE/FFI path, including repeated chunks, Unicode, empty final chunks, legacy cumulative streams and in-place translation.
- Synchronize the owning feature/architecture/accepted ADR's provider facts; run project verification and stable-signed local App packaging.

## Out of Scope

- Automatic migration or replacement of saved profiles, changing owner credentials, default vendor selection or automatic model fallback.
- Claiming Turbo is globally unavailable; endpoint/account availability is separate from this stream defect.
- UI redesign, new protocols, stream-format heuristics, screenshot persistence, public versions/releases, push or unapproved integration/cleanup.

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-10-10 | Project owner | Repair Flash translation failure | Complete incremental stream without false error | Verified |
| 2026-10-10 | Necessary support | Include Lite's same documented stream behavior and correct existing ADR's family-wide cumulative claim | Bounded model capability tests; preserve Turbo/Plus and other protocols | Verified |

## Current evidence

- Primary main is clean and matches live origin/main at the base commit. TASK-051 is reserved in a separate linked worktree; TASK-052 is newly reserved here.
- `run_translation` selects cumulative mode for every Qwen-MT name, and `normalized_stream_delta` rejects non-prefix continuation chunks.
- Official [Qwen-MT documentation](https://help.aliyun.com/zh/model-studio/machine-translation), checked 2026-10-10, distinguishes Flash/Lite incremental output from Plus cumulative output. Its OpenAI-compatible Flash example uses `stream: true` and appends `delta.content`, without DashScope-only `incremental_output`.
- ADR-0009's general cumulative-Qwen wording is stale relative to the currently documented Flash/Lite behavior; retain the historical Turbo sample while correcting current capabilities deliberately.

## Proposed approach

Select stream mode from explicit endpoint protocol and bounded model family before network event normalization. Do not guess mode from prefixes of returned text, because valid repeated delta chunks may otherwise disappear. Preserve existing Qwen-only request and validation behavior.

## Acceptance criteria

- [x] Flash/Lite ordinary translation emits all incremental content exactly once, including repeated text and Unicode, and completes on standard stop / DONE termination.
- [x] Turbo/Plus cumulative streams still normalize prefix snapshots, duplicates and empty terminal chunks; genuinely discontinuous cumulative output still fails.
- [x] Qwen-MT mode specialization does not affect other explicit protocols or falsely match similarly named models.
- [x] In-place Flash output reconstructs canonical IDs only after complete strict boundary/payload validation, with no partial layout deltas.
- [x] `./scripts/check.sh` passes, structure and whitespace gates included.
- [x] Fixed `artifacts/Marla_dev.app` builds with the existing stable signature and passes `scripts/verify-app.sh`; owner-only live-provider acceptance is clearly distinguished from mocks.
- [x] Feature specification, architecture and ADR facts agree; integration suggestions are recorded without editing target STATUS from this feature worktree.
- [x] Clean committed feature satisfies Task branch, current-main ancestry and Ready for integration gates. Integration and push remain separate authorization steps.

## Verification

### Automated

Run focused Rust stream regressions, then `MARLA_BUILD_CACHE_ROOT=/private/tmp/marla-task-052-cache ./scripts/check.sh`. Run `scripts/build-test-app.sh` with the primary fixed artifact directory and an isolated Release build directory.

### Manual

Owner retries the original ordinary screenshot translation with the saved Flash profile in the rebuilt signed App. Do not read or export Keychain secrets or persist acquired screenshots. Synthetic HTTP/FFI tests do not prove live-provider account acceptance.

## Required Reading

- Root `AGENTS.md`, `docs/development/STATUS.md` and its universal Required Reading.
- `docs/features/language-routing.md` and the Qwen block contract in `docs/features/screenshot-translation.md`.
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md` and `ADR-0009-semantic-markdown-translation-contract.md`.
- `rust/marla-core/src/lib.rs`: Qwen model detection, stream modes, request construction, SSE decoder, `run_translation`, and existing Qwen/FFI tests.
- `scripts/check.sh`, `scripts/build-test-app.sh`, `scripts/verify-app.sh`, `scripts/main-worktree.sh`.

## Parallel contributors

None. This is a small, tightly coupled provider correction; one writer owns the code, Task and synchronized documentation.

## Integration notes

- On authorized integration, primary owner uses `./scripts/main-worktree.sh merge Anti2077/task-052-qwen-mt-stream`, then `check`, full target verification and global STATUS reconciliation.
- STATUS should record the integrated bounded Flash/Lite delta versus legacy cumulative capability, without claiming global Turbo retirement or real-account acceptance.
- Review possible TASK-051 overlap in architecture/ADR before merging. No math or UI paths are owned here.

## Risks and rollback

- A relay that changes the documented stream semantics needs its own confirmed contract; no automatic text-based guessing is added.
- Revert this bounded provider change and rebuild the signed fixed App if required. Owner profile/credential data stays unchanged.

## Decisions needed

None for local fix and verification. Integration, remote push and worktree cleanup require separate owner authorization.

## Completion record

- Worktree verified commit: `15a07d4` (`fix: support Qwen MT incremental streams`)
- Integration commit: `4a928fd` (merge commit)
- Integration verification: `MARLA_BUILD_CACHE_ROOT=/private/tmp/marla-task-052-main-cache ./scripts/check.sh` passed on merged `main`.
- Automated evidence: `./scripts/check.sh` passed with Rust 58 tests, Swift/XCTest 272 tests, Xcode Debug build, structure, shell syntax, whitespace and diff checks; focused Qwen suite 6/6 passed. `build-test-app.sh` and `verify-app.sh` passed for signed `artifacts/Marla_dev.app` (Bundle ID `com.marla.app`, version `0.0.0`, macOS 14.0, arm64, `API Usage Monitor Dev`).
- Manual evidence: Project owner opened `/Users/anti/Documents/ChatGPT/Marla/artifacts/Marla_dev.app`, retried the original `Qwen-MT-flash` translation, and confirmed the complete result displayed normally without “不连续的流式内容”。
- Documentation updated: `docs/features/language-routing.md`, `docs/architecture/ARCHITECTURE.md`, and accepted ADR-0009 synchronized.
- Mainline documentation updated by: Primary integration owner
- Scope changes closed: Verified
- Parallel contributions integrated: None
- Remote push state: Not pushed
- Worktree cleanup state: Retained pending owner cleanup authorization
