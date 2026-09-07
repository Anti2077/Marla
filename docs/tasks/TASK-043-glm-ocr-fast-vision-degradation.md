# TASK-043：GLM-OCR 识别中的快速降级至 Vision

Status: Done

Owner: Project owner + Agent

Created: 2026-09-07

Updated: 2026-09-07

Origin: direct request / GLM-OCR usability improvement

Conversation: 2026-09-07，普通截图翻译增加 GLM-OCR 识别中的快速降级入口

Related: TASK-033 GLM-OCR cloud provider; TASK-041 in-place screenshot translation

## Initial request

项目所有者要求：在截图识别使用 GLM-OCR 且仍在进行时，翻译窗口提供“快速降级至 Vision”入口；用户点击后立即停止等待中的 GLM-OCR，并把同一次截图的识别工作交给本机 Vision 处理。

## Outcome

普通“截图翻译”使用 GLM-OCR 识别时，结果窗口在识别等待态显示一个可发现的快速降级按钮。点击后不重新截图，取消当前 GLM-OCR 请求，复用内存中的 `CapturedScreenshot` 启动 Vision，沿用现有普通截图翻译结果卡和后续翻译流程。

## Why now

GLM-OCR 能提供更丰富的结构，但云端网络或响应速度可能让用户等待过久。当前普通截图卡已经有 `visionFallback` 状态和 Vision 识别路径，但只有 GLM 请求失败后才会自动进入；用户在失败前没有主动控制。快速降级应补足用户控制，同时保持 Vision 默认、本机识别和普通附近结果卡语义不变。

## In Scope

- 普通“截图翻译”结果窗口在 `recognizing + GLM-OCR` 阶段显示“快速降级至 Vision”按钮。
- 点击按钮后取消当前 GLM-OCR 网络请求和旧 OCR Task，复用同一份截图在内存中启动 Vision OCR。
- 将会话状态更新为现有“正在改用 Vision”状态，Vision 成功后继续现有普通截图翻译请求和结果卡流程。
- 按 request ID 和一次性操作保护，拒绝过期、重复或已进入 Vision/翻译阶段的降级操作。
- 保持原位翻译独立路径不显示该按钮、不允许降级至 Vision；保持 GLM 自动失败后的既有 Vision fallback。
- 添加会话/路由/按钮可见性和共享截图复用的回归测试；更新截图功能规格、验证记录、`STATUS.md` 和本 Task。

## Out of Scope

- 不改变原位翻译的 GLM-only 几何覆盖合同或 TASK-041 的待验收项。
- 不重新执行截图选择、不上传第二份截图、不创建新的 OCR Provider、不修改 GLM API/Keychain 合同。
- 不改变 Vision 默认值、普通 GLM 失败自动回退、翻译 Provider、产品版本或快捷键。
- 不在 GLM 已经完成、Vision 已开始、翻译已开始或结果已完成后提供该动作。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-09-07 | Project owner | 普通截图翻译的 GLM-OCR 识别进行中增加快速降级至 Vision | 新增按钮状态、取消与同一截图复用、Vision 后续翻译和重复/过期保护测试 | Closed |

## Current evidence

- 普通截图流程已经在 `ScreenshotTranslation.swift` 中持有 `CapturedScreenshot`，GLM 失败时可调用 `beginVisionFallback(for:)` 并进入现有 Vision 识别。
- `TranslationCardView` 已有 `OCRActivity.glmOCR` 与 `OCRActivity.visionFallback` 两种可见状态，但尚无用户主动降级动作。
- 当前代码在 GLM 识别闭包内部直接捕获截图；快速降级需要把活动截图和 request ID 以会话级、短生命周期上下文保存，避免重新截图。
- 当前工作树从 `main` 创建了独立分支 `Anti2077/task-043-glm-ocr-fast-vision-degradation`；TASK-041 的现有提交和待验收记录保持不变。
- 首轮固定 App 等待态截图发现新增说明与按钮仍使用空译文的 28pt 高度估算，导致 224pt 卡片裁掉底部操作行。`ResultCardLayout` 现仅为 `recognizing + glmOCR` 预留 68pt 内容高度，并有布局回归测试约束；其它紧凑、流式、Vision 与原位状态的高度合同不变。
- 最终固定 App fixture 已覆盖 GLM 等待态和用户主动 Vision 降级态的浅色、深色与 Reduce Motion。等待态为 760×524 Retina 像素，按钮和底部操作行均完整；主动降级态为 760×448，使用中性“正在改用本机 Vision…”而非失败警告。五维复审为 Philosophy 8、Visual Hierarchy 8、Craft 8、Functionality 9、Originality 7。

## Proposed approach

在 `MarlaApplicationModel` 增加普通截图 OCR 活动上下文和一次性降级入口：启动 GLM 时保存截图、request ID 与 intent；按钮回调通过 `FloatingPanelCoordinator` 传给 model，先验证当前 session/request/ocrActivity，再取消 GLM 与 OCR Task，设置 `visionFallback`，使用保存的截图启动 Vision Task。Vision 结果继续调用 `sessionStore.submitOCRResult`，由现有翻译请求处理。完成、失败、关闭、新截图和会话替换时清理上下文。

按钮只由普通结果卡在 GLM 识别状态渲染，并通过 tooltip、辅助功能名称和 Reduce Motion 兼容现有卡片控件风格。若降级入口不再有效，按钮隐藏或动作无效且不影响当前会话。

## Acceptance criteria

- [x] 普通截图翻译在 GLM-OCR 识别进行时显示“快速降级至 Vision”。
- [x] 点击后取消 GLM 请求，立即进入“正在改用 Vision”，不重新截图或再次上传。
- [x] Vision 使用与 GLM 相同的 `CapturedScreenshot`，成功后沿用现有翻译请求和结果卡。
- [x] 原位翻译、Vision 已开始、翻译已开始、完成/失败态不显示或不执行该按钮。
- [x] 关闭、新截图、会话替换和取消会清理截图上下文；旧 GLM/Vision 回调不能更新新会话。
- [x] 自动 GLM 失败回退仍保持原行为，用户主动降级不显示为错误。
- [x] Swift 单元/集成测试覆盖按钮可见性、状态迁移、共享截图复用和重复/过期点击保护。
- [x] `./scripts/check.sh`、`./scripts/build-test-app.sh` 和 `git diff --check` 通过。
- [x] 相关功能规格、验证记录、`STATUS.md` 与当前实现一致；固定 App 浅色/深色/Reduce Motion 截图确认按钮、状态信息与底部操作行不重叠、不裁切，五维复审每项至少 7/10。
- [ ] 项目所有者使用真实 GLM 配置确认按钮点击会取消当前请求、复用同一截图交给 Vision，且不产生第二次截图选择或 GLM 上传；作为 RV-006 保留，不以 fixture 代替。

## Verification

### Current verified evidence

- 最终授权 `./scripts/check.sh` 返回 0：31 项 Rust 与 240 项 Swift 测试通过，Swift Package、Xcode Debug、严格 Rust format/Clippy、结构、脚本、空白与 diff 门禁通过。
- `./scripts/build-test-app.sh` 在最终布局修复后重新构建并验证固定 `artifacts/Marla_dev.app`：Bundle ID `com.marla.app`、版本 `0.0.0`、macOS 14.0+、arm64、Paper Lantern 资源、稳定签名 `API Usage Monitor Dev` 与 designated requirement 均有效。
- 定向回归覆盖 GLM 等待/自动回退状态、按钮可见性、同一 `CGImage` 复用与一次性行为、取消清理，以及 GLM 等待态专用高度测量。受限沙盒曾在既有 `FloatingPanel.swift:342` 因 `NSScreen` 不可用崩溃；完整 macOS 授权重跑通过，不把该宿主限制记为实现失败。

### Automated

```sh
./scripts/check.sh
./scripts/build-test-app.sh
git diff --check
```

### Manual

- 使用固定 `artifacts/Marla_dev.app` 配置 GLM-OCR，开始普通“截图翻译”并在 GLM 识别等待期间点击按钮。
- 确认同一框选区域直接进入 Vision，结果卡显示 Vision 识别后的普通翻译；没有第二次截图选择或第二次 GLM 上传。
- 检查浅色、深色、窄窗口、Reduce Motion 下按钮可发现、可读、不与状态文案重叠。
- 确认原位翻译和 GLM 已失败/已进入 Vision/翻译的卡片不出现该入口。

### Fixed-App visual evidence

- GLM 等待态：`/private/tmp/marla-task043-glm-awaiting-light-final2.png`、`/private/tmp/marla-task043-glm-awaiting-dark-final2.png`、`/private/tmp/marla-task043-glm-awaiting-dark-reduce-final2.png`。
- 用户主动降级态：`/private/tmp/marla-task043-glm-manual-fallback-light-final2.png`、`/private/tmp/marla-task043-glm-manual-fallback-dark-final2.png`、`/private/tmp/marla-task043-glm-manual-fallback-dark-reduce-final2.png`。
- 截图来自同一最终固定 Release 构建，未读取或使用 GLM 凭据；它们证明布局、文案和外观状态，不证明真实网络取消、截图对象复用或无重复上传。

## Required Reading

- `AGENTS.md`
- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/development/STATUS.md`
- `docs/development/VERIFICATION.md`
- `docs/development/UI_UX_SKILLS.md`
- `docs/features/screenshot-translation.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/DATA_CONTRACTS.md`
- `docs/architecture/decisions/ADR-0002-ocr-strategy.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `docs/architecture/decisions/ADR-0011-frozen-screenshot-in-place-translation.md`
- `docs/tasks/TASK-033-glm-ocr-cloud-provider.md`
- `docs/tasks/TASK-041-in-place-screenshot-translation.md`
- `Sources/MarlaApp/App/ScreenshotTranslation.swift`
- `Sources/MarlaApp/App/ResultPanelLayout.swift`
- `Sources/MarlaApp/Panel/FloatingPanel.swift`
- `Sources/MarlaApp/Panel/TranslationCardView.swift`
- `Sources/MarlaApp/OCR/GLMOCRService.swift`
- `Sources/MarlaApp/OCR/VisionOCR.swift`
- `Sources/MarlaApp/Sessions/TranslationSessionStore.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors (optional)

文档 contributor 已完成截图功能规格和验证记录草稿；主 Agent 保留本 Task、`STATUS.md`、代码、测试和最终整合。

## Risks and rollback

- GLM 取消回调与新 Vision Task 可能竞态；使用 request ID、当前 OCR 阶段和一次性上下文清理保护。
- 若截图只保存在局部闭包，降级可能误触发重新截图；通过活动上下文和共享截图回归测试约束。
- 回滚时删除按钮和主动降级入口，保留 TASK-033 已有的 GLM 失败自动 Vision fallback。

## Decisions needed

None.

## Completion record

任务完成时填写：

- Verified commit: `6be2c00`（已由合并提交 `58cc129` 合入本地 `main`；尚未推送 `origin/main`）
- Automated evidence: 31 Rust / 240 Swift，完整 `./scripts/check.sh` 与最终固定 Release 构建通过
- Manual evidence: 六张无凭据固定 App fixture 完成浅色、深色、380pt 窄宽和 Reduce Motion 五维复审 8/8/8/9/7；真实 GLM 操作尚未执行
- Documentation updated: `STATUS.md`、`VERIFICATION.md`、截图翻译功能规格和本 Task 已同步
- Remaining work promoted to: RV-006 项目所有者真实 GLM 取消、同一截图复用与无重复上传验收
- Scope changes closed: 2026-09-07 项目所有者提出的普通截图翻译 GLM-OCR 识别中快速降级至 Vision 已完成；真实 GLM 操作仍按 RV-006 单独保留为负责人验收，不改变本 Task 的实现完成状态。
- Parallel contributions integrated: 截图翻译功能规格与 `VERIFICATION.md` 草稿已整合；主 Agent 完成本 Task、`STATUS.md`、代码、测试和最终验证收束。
