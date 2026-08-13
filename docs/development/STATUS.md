# Project Status

Last updated: 2026-08-14

Release target: 0.1.0 Alpha

Overall state: In Progress — implementation baseline exists; release verification gaps remain

Active task: None

TASK-025 已立项：按职责把 `MarlaApplicationModel.swift` 拆分到分层目录，新增 `scripts/check-structure.sh` 结构门禁并接入 `check.sh`，新建 ADR-0007 并更新 `AGENTS.md` 与 `TASK_TEMPLATE.md`，防止单文件巨型化复发。

TASK-025 已完成源码职责拆分、Xcode 工程引用同步、结构门禁与固定 Release App 验证：`MarlaApplicationModel.swift` 已降至约 771 行，所有 Swift 源文件均低于 800 行，Models 目录无 UI framework import。`./scripts/check.sh` 全绿，固定 `artifacts/Marla_dev.app` 通过 Bundle ID、版本、arm64、稳定签名和 designated requirement 验证。

TASK-024 已完成第一阶段结构改造并合并到 `main`：新增 `MarlaApplicationServices` 集中构造应用级 Settings、Session、Floating Panel、Screenshot、Vision、Shortcut 与 Settings Window 服务；`MarlaApplicationModel` 保留兼容访问器和入口行为，不改变产品流程或 Swift/Rust 合同。授权环境下 `./scripts/check.sh` 已通过 20 项 Rust、97 项 Swift（3 项 Vision 图形服务限制 skip）、Swift Package、Xcode Debug、脚本语法、空白与 diff 检查；`artifacts/Marla_dev.app` 已通过固定 Release 打包、稳定签名和 designated requirement 验证。后续仍可按职责继续拆分同一大文件。

Blocked tasks:

- [TASK-013](../tasks/TASK-013-api-profile-activation-and-editor-actions.md) — 等待项目所有者确认拖拽动态中间态
- [TASK-016](../tasks/TASK-016-keychain-credential-prefetch.md) — 等待项目所有者在干净 Keychain 授权状态复验启动与首次翻译

## Current objective

TASK-023 已完成整体代码审查、自动化验证与固定 Release 测试 App 交付：Rust 翻译与模型列表取消从 10ms 轮询改为事件驱动唤醒，SSE 单个未完成帧增加 1 MiB 内存上限，严格 Clippy 与 shell 语法检查纳入统一验证，5 个公开 unsafe FFI 函数补齐安全合同；`artifacts/Marla_dev.app` 已重建并通过稳定签名验证。

TASK-022 已完成实现并收束：Français、Español、Deutsch、한국어 已接入既有语言路由、UI 菜单和 Swift/Rust 请求合同；Vision 已改为自动语言检测并按运行时能力过滤七门产品 OCR 候选。真实固定 Release 的日语/韩语截图路由仍是发布验收缺口；其余 Qwen-MT 语言暂不视为已适配。后续工作回到发布验证清单。

TASK-021 已完成：结果卡支持 380–760pt 横向调整，流式译文在未达到 60% 高度上限前完整推动窗口增长，动画竞态会在完成后按最新会话和宽度校正，且非激活划词路径的光标与拖动已完成实机复验。TASK-016 与 TASK-013 继续保持 Blocked。

## Current implemented baseline

- Native SwiftUI/AppKit menu-bar application with selection translation, screenshot translation, and quick input.
- Nearby result card with streaming, comparison, copy, retry, system speech, pinning, cancellation, target switching, and actionable error states.
- Result cards start at a compact 380pt width and content-driven height, resize horizontally up to 760pt or the visible-workspace limit, reflow height with streamed wrapping while keeping their anchored edge stable, and cap at 60% of the visible workspace before scrolling translation content internally.
- Accessibility selection reader with standard range and Web Text Marker support, trigger-time frontmost-app binding, frontmost-app/window/focused roots, identity-checked system focused-application roots, dual application/system-wide pointer hit paths, renderer/helper identity checks, global graph deduplication, ungated AX child probes, and bounded pointer fallback.
- Default-off Copy compatibility that snapshots every readable pasteboard representation, accepts only a new Copy result, restores on success/failure/cancellation, avoids overwriting a newer external write, rejects focus changes, and reports only redacted lifecycle evidence.
- Selection translation always uses the complete nearby result card; the rejected single-line source-covering and pointer-estimate prototype has been removed together with its setting and runtime path.
- Pre-selection full-display ScreenCaptureKit freezing with Marla-window exclusion, same-frame cross-display selection/loupe/crop composition, in-memory Vision OCR with automatic language detection and runtime-filtered candidates for the seven product languages, stable line order, and text-only translation requests.
- Embedded Rust static library with versioned C ABI, shared async runtime, generic OpenAI-compatible SSE, Qwen-MT adaptation, timeouts, cancellation, and stale-event isolation.
- Grouped Settings, Carbon shortcuts, Keychain credential storage, permission guidance, light/dark appearance, Reduce Motion, and verified test-app packaging.
- Xcode SwiftUI previews for the main menu, Settings, translation-card states, and quick input, with preview-safe fixtures that avoid system integrations.
- Menu setup status that automatically yields to three bounded in-memory recent translations once API, Accessibility, and Screen Recording are ready; selecting a recent result performs no network request and quitting clears the list.
- Single-layer macOS 26 Liquid Glass with a macOS 14–25 system-material fallback across the menu, Settings, result card, quick input, and screenshot-selection labels; screenshot entry icons use the available `viewfinder` symbol.
- Fixed-path Release development packaging that stages, stable-signs, and verifies a new `artifacts/Marla_dev.app` before replacing the previous App; missing stable identities fail instead of falling back to ad-hoc signing.
- Multiple named OpenAI-compatible API profiles with one versioned Keychain vault, legacy single-endpoint/per-profile migration, shared in-memory credentials, default selection, settings CRUD/reordering, and explicit result-card switching are implemented under TASK-005/TASK-016.
- Every API profile supports explicit Base URL or Complete URL semantics. The editor uses an inline Base/Complete switch and can fetch a Rust-owned `/models` list with the current profile credential, then expand and select a model at the bottom of the form.
- The API editor gives its first scroll-content row an 8pt focus-ring safety inset, keeping the native macOS Focus Ring complete in light and dark appearance.
- Settings use a five-page native sidebar including Translation Languages, plus a summary-only API list and independently clipped editor sheet; global shortcuts have persistent switches, result cards support background dragging, and screenshot selection includes an in-memory 6× pointer magnifier.
- Global native/secondary preferences support Simplified Chinese, English, Japanese, French, Spanish, German, and Korean under TASK-022. New sessions locally detect source language, route native to secondary and other/unknown source to native, expose source/target overrides in the result card and quick input, and send consistent explicit target semantics through generic and Qwen-MT providers; expanded-language Release UI verification remains pending.
- Settings use a transparent full-size title bar with traffic lights inside one continuous four-corner surface, hidden scroll indicators, and a fixed `Esc` screenshot-cancellation row. Screenshot selection temporarily suspends an open Settings window and restores it without activating it; `Esc` cancellation is owned by the active selection session rather than a single view's first-responder state, with window key-equivalent/cancel-operation routing and a listen-only event-tap fallback.
- Translation API profiles have persistent enabled states and only enabled profiles can be selected or invoked. The summary list uses native switches, a Set Default/Delete menu, accessibility move actions, and a trailing reorder handle. Settings content no longer moves the window; the newest fixed App uses a complete-row drag preview and 220ms animated hover reordering, pending owner confirmation of that final pointer feedback.
- Project-scoped Serena 1.6.1 provides read-only Swift/Rust semantic navigation through Codex. A custom Context and fixed tool allowlist expose only nine retrieval/diagnostic tools; source edits, shell, project switching, onboarding, memories, Dashboard, and Headroom remain disabled.

Implementation baseline commit: `27203b5`.

## Release gaps

- Real screenshot `Esc` cancellation needs re-verification after the project owner reproduced a regression against the older TASK-009 evidence.
- Real screenshot crop accuracy and Screen Recording permission persistence remain unverified across representative display layouts.
- Real Japanese, Korean, Chinese, and English screenshot OCR plus source-language routing require final verification in the fixed Release App after the TASK-022 Vision repair.
- P95 shell latency, Rust-delta-to-visible-Swift latency, and idle/translation/Vision memory budgets have not been measured.
- The unchecked items in `docs/versions/0.1.0/ACCEPTANCE.md` remain authoritative release gaps.

## Next selectable work

TASK-013 is not selectable until the project owner confirms its pending drag-preview motion in the existing fixed App.

1. `RV-002` — real screenshot crop and TCC permission verification.
2. `RV-003` — latency and memory measurement.

TASK-014 is complete; remaining product verification gaps stay separately selectable.

TASK-015 已完成；项目所有者已确认关闭跨应用划词验证（RV-001）。截图 `Esc` 与裁剪/权限复验保留在 RV-002，延迟与内存预算保留在 RV-003。

## Current risks

- A visible VSCodium selection failed in an earlier live build; the latest AX/Copy chain passes automation and the project owner has now confirmed one formerly failing Codex selection plus clipboard restoration. A WeChat selection also reached the real translation request and returned Provider `unauthorized`, proving text acquisition. The project owner has now accepted the cross-application verification outcome; any future app-specific regression should become a new Task rather than reopen RV-001.
- Community evidence (SelectedTextKit/Easydict and portable-translator) and project-owner testing of Bob identify simulated `⌘C` with pasteboard backup/restore as the key compatibility path for custom Electron/WeChat surfaces. TASK-015 implements that path behind a default-off setting and RV-001 is closed. Copy-menu, browser, and PopClip/Service bridges remain future IDEA-011 slices.
- Screenshot coordinate conversion has unit coverage but not a final visual comparison against the real selected region.
- The fixed-path development App is locally signed, not Developer ID signed or notarized; it is not a public distribution artifact.
- Real DashScope Qwen-MT translation succeeded, but representative TTFT, throughput, and live error mapping remain unmeasured.
- TASK-022 的 Swift/Rust 语言合同与 Vision 修复已实现：七门语言的归一/路由、设置持久化、通用提示词、Qwen-MT 映射、未适配代码拒绝和 Vision 配置均有回归测试。最新固定 Release 已重建并签名通过；当前 xctest 图形服务无法创建 Vision CVPixelBuffer（OSStatus -6662），沙盒外探针已证明自动检测下日/韩/中/英样本有结果；现场固定 App 截图 OCR、长标签和完整窗口验收保留在发布缺口，不阻止本 Task 收束。

## Latest verification

- TASK-023：`./scripts/check.sh` 通过严格 Rust formatting/Clippy、20 项 Rust、84 项 MarlaApp（3 项 Vision 图形服务限制 skip）、13 项 MarlaCore、Swift Package、Xcode Debug、3 个 shell 脚本语法、空白与 diff 检查。新增回归证明事件驱动取消会即时唤醒并保持幂等，SSE 未完成帧在 1 MiB 边界后被拒绝。`./scripts/build-test-app.sh` 随后成功重建固定 Release；`artifacts/Marla_dev.app` 通过 Bundle ID `com.marla.app`、版本 0.1.0、macOS 14.0+、arm64、稳定签名 `API Usage Monitor Dev` 和 designated requirement 验证，已交付项目所有者现场查看。
- TASK-021 已完成：宽度、非激活光标/拖动、源应用焦点和多次结果替换均已验收；本轮针对未封顶高度少算，增加了按 SwiftUI 实际行高补足的 `ResultCardLayout` 测量、真实 `NSHostingView` 回归，以及每次高度动画结束后按最新会话/宽度执行一次无动画 frame reconciliation。40ms 非激活场景覆盖了首个 delta 与 160ms 入场动画重叠的竞态。`./scripts/check.sh` 通过 17 Rust、80 MarlaApp、13 MarlaCore、Swift Package、Xcode Debug、格式/空白/diff；固定 Release 与 `/private/tmp/marla-task-021-height-race-final.png` 均验证通过。
- TASK-022：`./scripts/check.sh` 通过 18 Rust、84 MarlaApp（3 项 Vision 图片回归因 OSStatus -6662 明确 skip）、13 MarlaCore、Swift Package、非沙盒 Xcode Debug、格式/空白/diff；`./scripts/build-test-app.sh` 重建并验证固定签名 `artifacts/Marla_dev.app`。沙盒外探针验证自动检测下日/韩/中/英样本；现场固定 App 截图 OCR 和窗口视觉验收仍待完成。实现已按项目所有者授权收束，实现提交为 `978294e`，收束记录为 `c212400`。
- TASK-020 is complete. `./scripts/check.sh` passes 17 Rust, 71 MarlaApp Swift, and 13 MarlaCore Swift tests plus Swift/Xcode Debug, formatting, whitespace, and diff checks; the fixed Release `artifacts/Marla_dev.app` passes Bundle ID/version/minimum-system/arm64/stable-signature/designated-requirement verification. Real Release captures in `/private/tmp` show 224pt compact, approximately 309pt intermediate growth, approximately 644pt capped growth, dark appearance, and Reduce Motion; five-dimension review scores 8/8/8/9/7. Screenshots remain ephemeral per project policy and were not added to the repository.
- TASK-019 is complete on `Anti2077/ideas-012-translation-languages` with uncommitted branch changes. After the project-owner removal decision, `./scripts/check.sh` passes 17 Rust and 81 Swift tests plus Swift/Xcode Debug, formatting, whitespace, and diff checks; six dedicated inline-experiment tests were removed with that feature. The stable-signed fixed Release passes Bundle ID/version/minimum-system/arm64/signature/designated-requirement verification. Language settings, result-card, and quick-input captures under `artifacts/ui-review/task-019/` retain scores 8/8/8/8/7; final General light/dark captures without the Experimental section are under `artifacts/ui-review/task-019-removal/` and score 8/8/8/9/7. A live Japanese request against the Keychain-backed profile was not run because a new acceptance process raised system authorization; mock-provider payload tests verify `ja` mapping without exposing credentials.
- TASK-018 is complete at implementation commit `27203b5`. It captures every active display before presenting selection windows, excludes Marla's own windows, redraws the background/undimmed selection/loupe from the same frozen frame set, and composites the final crop without a second live capture. Cross-display mixed-scale layout tests pass; `./scripts/check.sh` passes 17 Rust and 83 Swift tests plus Swift/Xcode Debug, and the stable-signed fixed Release passes packaging. Three 3420×2224 Release captures under `artifacts/ui-review/task-018/` cover light, dark, and Reduce Motion and score 8/8/8/7/7. The project owner accepted Task closure; remaining real-environment evidence is tracked by RV-002/RV-003 rather than reported as verified.
- TASK-017's exact and pointer-estimate single-line surfaces were built and visually reviewed, but project-owner real use found both presentations unsatisfactory. TASK-019 now removes the prototype, its setting, runtime path, automation fixtures, and dedicated tests; the historical TASK-017 evidence remains available but no longer describes the current product baseline.
- TASK-016's first live authorization test invalidated the `kSecMatchLimitAll` behavior claim. The follow-up uses one vault and one `LAContext`, but its first two Release packages respectively crashed from nil `NSApp` during construction and remained alive without an openable menu surface after adding a custom App Delegate plus early `NSApplication.shared` access. The final lifecycle repair removes both construction-time AppKit paths and listens only for `NSApplication.didFinishLaunchingNotification`. `./scripts/check.sh` passes 17 Rust and 74 Swift tests plus the Xcode Debug build; the stable-signed fixed Release App is valid, idles in the normal AppKit event loop, creates no new crash report, and successfully captures its complete built-in menu acceptance surface. Clean live authorization behavior remains unverified.
- Rust: 17 tests passed.
- Swift: 81 tests passed.
- Xcode Debug application build passed.
- TASK-014 installed `uv 0.12.2`, `serena-agent 1.6.1`, and rustup `rust-analyzer 1.96.0`; Serena health check passed and indexed 15 Swift files plus 1 Rust file while project/build caches remained ignored.
- TASK-014's real stdio MCP session exposed exactly nine read-only semantic tools, with no edit, shell, project-switching, memory, or onboarding tools. Swift symbol/reference queries covered `TranslationAPIProfile` and `RustTranslationClient/start`; Rust covered `marla_translation_start` and four semantic test references.
- A separate read-only `codex exec` process loaded the project `.codex/config.toml`, called Serena successfully, and returned `ACTIVE_PROJECT=Marla CONTEXT=codex-readonly-context ACTIVE_TOOLS=9`.
- A second independent read-only `codex exec` process actually called `serena.find_symbol` and located `TranslationAPIProfile` at `Sources/MarlaApp/MarlaApplicationModel.swift:81-138`; root `AGENTS.md` now preserves the semantic-first usage rule, navigation-only boundary, ignored paths, and `rg`/normal-read fallback.
- SwiftUI preview support compiled in the Swift Package and Xcode Debug build.
- Xcode Preview launched and loaded `__preview.dylib` while the fixed-path development app remained running; Debug allows the Preview host instance while Release remains single-instance.
- `Marla_test_202608060135.app` passed Bundle ID, version, deployment target, arm64, executable, and signature checks.
- Real-app visual scenarios passed the five-dimension SwiftUI review with every dimension at least 7/10.
- TASK-003 menu-recents, Settings, quick-input, comparison-card, and screenshot-selection captures passed the five-dimension rescore at 8/8/8/8/7; evidence is under `artifacts/ui-review/task-003/`.
- `Marla_test_202608061928.app` passed Bundle ID, version, deployment target, arm64, executable, and signature checks.
- TASK-005 settings and streaming-card screenshots passed the five-dimension SwiftUI review at 8/8/8/8/7; evidence is under `artifacts/ui-review/task-005/`.
- `artifacts/Marla_dev.app` was replaced by a no-argument Release build and passed Bundle ID, version, deployment target, arm64, executable, stable-signature, and designated-requirement checks; no timestamped App or staging residue was added.
- TASK-006 settings sidebar/API summary/editor/empty state, light/dark General, Shortcuts, and OCR screenshots passed the five-dimension SwiftUI review at 8/8/8/8/7; evidence is under `artifacts/ui-review/task-006/`.
- TASK-007 API editor, shortcut light/dark, result-card and screenshot-magnifier captures passed the five-dimension SwiftUI review at 8/8/8/8/7; evidence is under `artifacts/ui-review/task-007/`. Direct pointer-drag automation was unavailable for this LSUIElement app, so dragging is verified by AppKit panel configuration and automated regression coverage rather than a simulated mouse gesture.
- TASK-008 unified Settings light, Shortcuts dark, and screenshot-from-open-Settings captures passed the five-dimension SwiftUI review at 8/8/8/8/7; evidence is under `artifacts/ui-review/task-008/`.
- TASK-009 added session-scoped local/global Escape monitors plus idempotent cancellation coverage. After all old fixed-path instances were closed, Computer Use sent real `Escape` events to the sole Release `artifacts/Marla_dev.app`; both ordinary and open-Settings screenshot overlays disappeared without a result card. Evidence and the lock-interrupted final capture note are under `artifacts/ui-review/task-009/`.
- TASK-010 added per-profile Base/Complete URL routing, an inline URL-mode switch, Rust-owned `/models` discovery through C ABI v2, and bottom-of-form model selection. A real `gpt-5.6-luna` Complete URL stream returned “你好”, `finish_reason: stop`, and `[DONE]`; the related `/v1/models` endpoint returned 20 models including `gpt-5.6-luna`. Light/dark Release captures passed the five-dimension review at 8/8/8/8/7 under `artifacts/ui-review/task-010/`. The fixed App retained Bundle ID `com.marla.app`, arm64, Authority `API Usage Monitor Dev`, and its designated requirement.
- TASK-011 added an 8pt scroll-content safety inset above the first API editor field. Frontmost light/dark Release windows captured by verified Core Graphics Window ID show the native blue Focus Ring complete on all four sides; five-dimension scores are 8/8/9/8/7 under `artifacts/ui-review/task-011/`. The fixed App retained Bundle ID `com.marla.app`, arm64, Authority `API Usage Monitor Dev`, and its designated requirement.
- TASK-012 changed development tracking to one evolving Task per implementation conversation. Owner-added scope remains in the same Task with explicit scope-change, acceptance, and verification updates; `git diff --check` and stale-rule searches passed.
- The 2026-08-06 to 2026-08-07 multi-API/settings development conversation is retrospectively consolidated in canonical `TASK-005`; `TASK-006` through `TASK-011` remain linked detailed evidence slices rather than separate conversation boundaries.
- TASK-013's fixed `artifacts/Marla_dev.app` retains Bundle ID `com.marla.app`, arm64, Authority `API Usage Monitor Dev`, and the existing designated requirement. Static light/dark list and editor captures passed the five-dimension review under `artifacts/ui-review/task-013/`; the owner confirmed that dragging the handle no longer moves the Settings window. Computer Use completed and reversed a real cross-row handle drag, restoring the prior order. After the owner still observed system drag-image scaling, the visible preview moved to a fixed 580×76pt nonactivating Panel while the native drag item became transparent 1×1pt; final owner confirmation of the Panel, exact handle anchor, moving empty slot, and release fade is pending.
- A real DashScope `qwen-mt-turbo` request translated `Hello` to “你好”; the credential remained in Keychain.
- TASK-015 is complete. Standard/range/marker resolution, pointer/focused/window root ordering, trigger-time application binding, system focused-application roots, ungated AX child probes, CFArray child conversion, global AX graph deduplication, cyclic references, search budgets, Unicode offsets, window-level Escape routing, and the complete Copy transaction lifecycle all pass. The fixed `artifacts/Marla_dev.app` is stable-signature-verified. The project owner confirmed a formerly failing Codex selection plus clipboard restoration, confirmed WeChat reached the real translation request, then accepted the goal complete after observing a high success rate. The downstream Provider `unauthorized` is a missing local profile credential and is excluded from TASK-015. Cross-application verification is closed as RV-001; screenshot and performance evidence remain RV-002/RV-003.

## Pending product decisions

Default translation vendor, contextual translation controls, cloud structured OCR controls, persistent history, final app icon, public signing/notarization, and public distribution remain outside the current Task. Their context is recorded in `docs/backlog/IDEAS.md` or accepted ADRs.

## Required Reading

These files are universal for every task:

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/architecture/ARCHITECTURE.md`

The active Task must list any additional UI, implementation, acceptance, feature, data-contract, source, test, and ADR files it actually requires.
