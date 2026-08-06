# TASK-009：可靠取消截图框选

Status: Complete

Owner: Project owner + Agent

Created: 2026-08-06

Updated: 2026-08-06

Origin: direct request / live defect

## Outcome

截图框选期间无论设置窗口或其它 Marla 窗口的焦点状态如何，按 `Esc` 都会立即取消当前截图会话，不进入截图捕获、Vision OCR 或翻译。

## Why now

TASK-008 只验证了 `ScreenshotSelectionView` 收到 Escape 事件后的处理，但项目所有者在固定 App 中确认真实 `Esc` 没有退出截图。这证明把取消行为绑定到单个 View 的首响应者不足以覆盖真实窗口焦点变化。

## In Scope

- 将 Escape 监听提升到截图会话协调器层，不依赖某一个框选 View 是否为首响应者。
- 保留 View 级 Escape 处理作为直接路径，并保证取消幂等。
- 截图结束、取消和错误时清理所有临时键盘监听。
- 增加焦点无关的自动化回归与真实固定 App 键盘验收。
- 允许在构建和验收时关闭所有旧 Marla 实例；项目所有者已明确授权。
- 同步截图规格、验收、Task、Backlog 和 `STATUS.md`。

## Out of Scope

- 改变截图捕获、Vision OCR、翻译请求或快捷键数据模型。
- 让用户关闭或重新绑定 Escape。
- 新增截图工具栏、历史或图片持久化。

## Current evidence

- 框选提示已经显示 `Esc 取消`。
- `ScreenshotSelectionView.keyDown` 对 keyCode 53 调用 `session.cancel()`，但真实固定 App 中 Escape 没有退出。
- 框选窗口声明可成为 Key 并尝试设置首响应者；真实缺陷说明事件仍可能绕过该 View。
- `ScreenshotSelectionSession.cancel()` 已有幂等结束保护，可安全接收协调器级取消。

## Proposed approach

`ScreenshotCaptureCoordinator` 在 `present` 时安装截图会话专用键盘监听，同时覆盖 Marla 活跃时的本地事件和焦点落在其它进程时的全局事件。两条路径都只识别 Escape 并调用当前 `selectionSession.cancel()`；`finish` 无条件移除监听。View 级 `keyDown` 保留为最短路径。

## Acceptance criteria

- [x] 截图框选期间按真实 `Esc` 立即退出覆盖层。
- [x] Escape 取消不产生截图、OCR、翻译请求或错误卡片。
- [x] 设置窗口打开或焦点变化时 Escape 仍有效。
- [x] 结束会话后不残留全局或本地键盘监听，不影响其它应用中的 Escape。
- [x] `./scripts/check.sh` 通过。
- [x] `./scripts/build-test-app.sh` 覆盖固定 `artifacts/Marla_dev.app`，签名身份和 designated requirement 不变。

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

先关闭所有 Marla 进程，再启动固定 `artifacts/Marla_dev.app`。分别从普通前台应用和已打开设置窗口触发截图，按真实 `Esc`，确认覆盖层立即消失且不会出现结果卡。证据记录到 `artifacts/ui-review/task-009/`。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/features/screenshot-translation.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0005-vision-only-ocr-for-0.1.0.md`
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Risks and rollback

- 全局按键监听必须只在截图会话存续期间存在；集中安装和清理并用测试验证。
- 全局监听可能受辅助功能权限影响；本地监听与 Key Window 路径共同保留作为互补。

## Decisions needed

None — 项目所有者已确认 Escape 必须可靠取消，并授权构建时关闭旧 Marla 实例。

## Completion record

- Verified commit: uncommitted project-owner worktree
- Automated evidence: `./scripts/check.sh` passed with 16 Rust and 37 Swift tests plus Swift/Xcode Debug builds and repository hygiene checks.
- Manual evidence: all old fixed-path processes were closed; Computer Use sent real `Escape` events to the sole Release `artifacts/Marla_dev.app` in ordinary screenshot and open-Settings screenshot scenarios, and both overlays disappeared without a result card. Evidence is under `artifacts/ui-review/task-009/`; the Mac auto-locked while the final post-cancellation desktop image was being copied, after both exits had already been re-read successfully.
- Documentation updated: Task, Backlog, Status, screenshot feature spec, bilingual 0.1.0 specification, and acceptance record.
- Remaining work promoted to: None; real crop accuracy and TCC persistence remain separately tracked by BL-002.
