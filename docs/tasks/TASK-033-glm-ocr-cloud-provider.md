# TASK-033：GLM-OCR 云端结构识别与 Vision 回退

Status: Done

Owner: Project owner + Agent

Created: 2026-08-19

Updated: 2026-08-20

Origin: BL-006 / direct request

Conversation: 2026-08-19，OCR 设置页 Provider 选择、GLM-OCR 云端调用与截图翻译等待态

## Initial request

项目所有者要求在现有 OCR 设置卡片中直接增加 GLM-OCR 下拉菜单并完成适配，只让用户填写一个 API Key；先完成云端 GLM-OCR 调用，再让截图翻译触发后的结果窗口显示等待 GLM-OCR 返回富文本结果的状态。

## Outcome

用户可在 OCR 设置中显式选择本机 Vision 或云端 GLM-OCR；选择 GLM-OCR 并保存 Key 后，截图会以内存态上传到固定官方接口，结构化识别结果直接进入现有语义 Markdown 翻译和原生渲染管线。云端等待、缺少凭据和 Vision 降级都在当前结果卡中清楚可见。

## Why now

TASK-028 已使 `semanticMarkdown` 成为翻译、流式会话、复制和原生渲染的一等内容格式，但当前截图入口仍只通过 Vision 生成纯文本，无法恢复表格、代码块、公式和版面结构。ADR-0002 已接受 GLM-OCR 加本机 Vision 回退方向，项目所有者本次明确授权图片上传路径、设置入口和实现 Task。

## In Scope

- 在 OCR 页面顶部用独立卡片增加原生 Menu 风格 Provider Picker，选项为“本机 Vision”和“云端 GLM-OCR”；默认和迁移值保持 Vision。
- 本机 Vision 与云端 GLM-OCR 各自使用独立设置卡片并同时保留在页面中；Provider Picker 只选择调用路线，不把某一家服务的说明或凭据动态替换进选择器卡片，为后续其它 OCR 服务保留清楚的扩展模式。
- Vision 模式保留本机处理、截图不上传和纯文本范围说明。
- GLM-OCR 模式渐进显示图片上传披露、一个 SecureField、已保存状态、显式“保存”和独立“移除 Key”操作；空白草稿不得覆盖或删除已有 Key。
- GLM-OCR endpoint 与 model 固定为官方 `https://open.bigmodel.cn/api/paas/v4/layout_parsing` 和 `glm-ocr`，不提供 URL、模型或额外质量参数。
- Swift/AppKit 负责 Provider 偏好、Keychain、ScreenCaptureKit 图像生命周期和编码；API Key 仅存 Keychain，不进入偏好、日志、Task、测试 fixture 或截图。
- Rust 负责 GLM-OCR HTTP 请求、超时/取消、响应解析和 provider-independent 结构化 OCR 归一；通过升级后的版本化 C ABI 和 Swift wrapper 暴露异步事件。
- GLM 请求携带 PNG data URL；超过 9.5 MB 安全阈值时先转 JPEG，再按比例有界缩小，且单张上传不超过 Provider 的 10 MB 限制。
- 截图、编码数据、Base64、请求响应和几何块只保留在活动会话内；完成、取消或替换请求后释放，不持久化截图或活动布局。
- 将 `layout_details` 归一为稳定的 `OCRDocument` 块、类型、阅读顺序和 0...1 坐标；同时生成规范 `TranslationContent`。
- 不把 `md_results` 作为内容合同；始终从规范 `layout_details` 块确定性重建 Markdown，安全转换块内字面量 HTML 表格并保留公式、URL、代码、命令、变量和占位符。
- 成功的 GLM 结果以 `semanticMarkdown` 直接进入现有结构化翻译和原生 Markdown 渲染，不增加 OCR 预览或确认步骤。
- 截图选择完成后立即显示结果卡等待态：标题“正在解析结构”，详情“GLM-OCR 正在识别文字与版面…”；该状态不虚构已经获得的识别内容。
- GLM 已选择但没有已保存 Key 时停止在可操作错误态，并提供直接打开 OCR 设置的操作；不得静默改用 Vision。
- 已配置请求遇到网络、超时、限流、认证、无效响应、编码或无有效结构内容错误时自动改用 Vision，并显示“云端结构识别失败，正在改用本机 Vision…”；降级成功后继续普通翻译。
- 用户取消、面板关闭、新截图或会话替换应取消 OCR 和翻译；取消不得触发 Vision 回退，过期回调按 request ID 丢弃。
- OCR 成功后的翻译重试、语言切换或 API profile 切换复用规范 OCR 内容，不重新上传或重新 OCR。
- 增加 Rust mock-server、归一/安全/取消测试，以及 Swift 设置、Keychain 语义、FFI、会话、等待/错误/回退状态测试。
- 同步架构、数据合同、截图翻译功能、Backlog、`STATUS.md` 和相关 Accepted ADR 的当前事实。
- 构建固定签名 Release 开发 App，以真实浅色/深色截图完成 `swiftui-design-skill` 五维复审，每一维至少 7/10。

## Out of Scope

- 自定义 GLM endpoint、模型、温度、质量参数、图片 URL 输入或任意 OpenAI-compatible OCR profile。
- 每次截图上传前再次确认；选择云端 Provider 和设置页披露即为持续的显式授权。
- OCR 结果预览、块编辑、框选校正、页面重建或像素一致的原位覆盖层。
- PDF、多页文档、批量文件、持久化截图、持久化布局块或云端 OCR 历史。
- 本地 OCR VLM、Python、Tauri、localhost sidecar、WebView、脚本执行或远程资源加载。
- GLM-OCR 之外的新 Provider、账号体系、订阅、用量计费或公开发布准备。
- 分配或提升产品版本；开发 App 继续使用 TASK-032 的 `0.0.0` 技术占位。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-19 | Project owner | 在现有 OCR 卡片增加 GLM-OCR 下拉菜单，只填写一个 API Key，并完成云端调用适配 | 增加 Provider 设置、Keychain、固定接口、Rust adapter、FFI 和结构化结果验收 | Implemented; live credential pending |
| 2026-08-19 | Project owner | 截图翻译触发后在翻译窗口显示等待 GLM-OCR 富文本结果的状态 | 增加立即可见的结构解析等待态、取消和过期事件验收 | Verified |
| 2026-08-19 | Project owner + implementation clarification | Vision 默认；缺 Key 明确阻止并引导设置；已配置云端失败自动回退 Vision；GLM 成功直接进入结构化翻译 | 增加默认/迁移、错误、降级通知和不重复 OCR 的验收矩阵 | Automated; live credential pending |
| 2026-08-19 | Project owner | GLM-OCR 必须另起一张设置卡片，不能与 Vision 内容在同一框内切换；以后还可能增加其它服务 | 设置页改为独立 Provider 选择卡 + 独立 Vision 卡 + 独立 GLM-OCR 卡，并重新做真实 App 视觉验收 | Verified |
| 2026-08-20 | Project owner | 完成本 Task，合并到 `main` 并推送 | 真实 GLM Key 成功调用不伪写为已验证，迁移为独立 `RV-005`；授权提交 TASK-032/TASK-033 累积改动、合并和推送 | Accepted |

## Current evidence

- Task 开始时，截图路径只调用 macOS Vision 并输出 `plainText`，设置页也没有 Provider 偏好或云端 OCR 凭据；当前实现已增加默认 Vision / 可选 GLM-OCR 路由和独立设置卡片。
- TASK-028 已完成 `plainText` / `semanticMarkdown` 共享合同、Rust 翻译 request schema v3、完成态/流式原生 Markdown、安全 HTML table 到 GFM 转换，以及重试时保留规范内容。
- 现有 Rust C ABI 已有可取消的翻译请求 opaque handle 和 Swift async wrapper，可作为 OCR ABI 生命周期的实现基线；任何 ABI 变化必须同步 header、Swift wrapper 与 API version。
- 官方 GLM-OCR 接口要求 `model: "glm-ocr"` 和图片 `file` data URL；响应提供 `md_results`、`layout_details`、页面尺寸、usage 和 request ID。
- 先前真实 API 样本证明 `layout_details` 比 `md_results` 更适合作为规范结构证据；样本中的 bbox 为基于页面像素的整数，confidence 缺失，`md_results` 曾损坏标题层级、链接、代码围栏、命令、`${BUILD_ID}` 和 `{{STATUS}}`，并产生 literal HTML table，因此不能未经验证直接作为规范结果。
- 当前工作树包含已完成但未提交的 TASK-032 版本策略改动；本 Task 必须保留这些改动并继续使用 `0.0.0` 开发占位。

## Proposed approach

1. 新增共享 OCR Provider、规范文档/块、请求和事件模型；Vision 与 GLM 都返回实际 Provider、`OCRDocument` 和规范 `TranslationContent`。
2. 在 Rust 新增 GLM provider、响应归一和异步 OCR request handle，复用现有 runtime、HTTP、取消与 panic/FFI 安全模式；将 C ABI API version 从 3 提升到 4，而翻译 request schema 保持 3。
3. 在 Swift 增加 `RustOCRClient`、OCR Keychain store 和设置偏好；扩展 `TranslationSessionStore` 所有权，使它同时取消 OCR Task 与翻译 handle。
4. 截图 crop 先开启结果卡与 provider-specific 等待态，再按设置执行 Vision 或 GLM；只有已配置 GLM 的可回退错误走 Vision，成功后以规范内容开始现有翻译。
5. 使用独立的 Warm Minimal Provider 选择卡、本机 Vision 卡和云端 GLM-OCR 卡；原生 Picker 只决定路由，不动态替换服务卡片，也不引入第二层材质、通用 Provider 编辑器或 URL/模型表单。

## Acceptance criteria

- [x] 新旧安装都默认使用本机 Vision；Vision 行为、隐私文案和纯文本翻译回归不变。
- [x] OCR 设置页使用独立 Provider 选择卡，并同时保留独立 Vision 与 GLM-OCR 卡；GLM 仅显示一个 API Key 输入及上传披露，没有 URL、模型或质量字段。
- [x] Key 只写入 Keychain；显式保存、空白不覆盖、独立移除和已保存状态都有自动化覆盖。
- [x] 已选择 GLM 但缺 Key 时不上传、不降级，结果卡提供可直达 OCR 设置的明确错误操作。
- [x] 已配置 GLM 时，截图只以内存态发送到固定官方接口，文件大小被约束在 10 MB 内，完成/取消后不留下持久图片或布局。
- [x] 截图触发后立即显示“正在解析结构 / GLM-OCR 正在识别文字与版面…”，取消、关闭和新请求会停止 OCR 且不接受过期事件。
- [x] GLM 响应从规范块生成安全 `semanticMarkdown`，表格、公式、代码、URL、命令、变量和占位符的保护/降级矩阵通过。
- [x] GLM 成功直接进入现有结构化翻译与原生 Markdown 渲染；翻译重试和路由切换不重新上传。
- [x] 已配置云端请求失败时可见地自动降级到 Vision；用户取消不降级，Vision 降级失败保持可操作错误。
- [x] Swift/Rust ABI version、header、wrapper、请求/事件 schema、取消/释放职责和文档一致。
- [x] `./scripts/check.sh` 全绿，新增代码未使任何源文件超过结构门禁。
- [x] `./scripts/build-test-app.sh` 生成并验证 `0.0.0` 固定签名 Release 开发 App。
- [x] 浅色、深色和 Reduce Motion 的 OCR 设置与 GLM 等待/降级状态真实 App 截图五维评分均不低于 7/10；真实成功态仍随下一项 live credential 验收一起检查。
- [x] 项目所有者于 2026-08-20 决定不以真实 GLM Key 调用作为本 Task 的关闭门槛；未执行的真实成功路径已如实迁移为 `RV-005`，Agent 不读取、显示、记录或持久化 Key。
- [x] 相关规格、Backlog 和 `STATUS.md` 已同步。

## Verification

### Automated

```sh
./scripts/check.sh
./scripts/build-test-app.sh
git diff --check
```

### Manual

- 在固定 `artifacts/Marla_dev.app` 中分别检查 Vision、GLM 无 Key、GLM 已保存 Key、云端等待、云端成功、云端失败后 Vision 降级、取消和翻译重试。
- 使用包含标题、链接、代码围栏、命令、变量、占位符、公式和表格的小区域截图；比较 canonical OCR 内容、翻译请求格式与完成态原生投影，不承诺像素级布局复原。
- 项目所有者在设置 SecureField 中直接输入真实 Key；证据只记录请求结果、时延范围、状态和脱敏结构统计，不记录 Key、完整截图或用户内容。
- 捕获 OCR 设置页和结果卡浅色、深色、380pt/760pt 与 Reduce Motion 证据，按 Philosophy、Visual Hierarchy、Craft、Functionality、Originality 五维复审。

## Required Reading

- `AGENTS.md`
- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/development/VERSIONING.md`
- `docs/development/STATUS.md`
- `docs/backlog/BACKLOG.md`（BL-006）
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/DATA_CONTRACTS.md`
- `docs/architecture/decisions/ADR-0002-ocr-strategy.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `docs/architecture/decisions/ADR-0005-vision-only-ocr-for-0.1.0.md`
- `docs/architecture/decisions/ADR-0009-semantic-markdown-translation-contract.md`
- `docs/architecture/decisions/ADR-0010-unversioned-incubation.md`
- `docs/features/screenshot-translation.md`
- `Sources/MarlaCore/TranslationModels.swift`
- `Sources/MarlaApp/OCR/VisionOCR.swift`
- `Sources/MarlaApp/Sessions/TranslationSessionStore.swift`
- `Sources/MarlaApp/Persistence/MarlaSettingsStore.swift`
- `Sources/MarlaApp/Persistence/KeychainCredentialStore.swift`
- `Sources/MarlaApp/SettingsView.swift`
- `Sources/MarlaApp/Panel/TranslationCardView.swift`
- `rust/marla-core/src/lib.rs`
- `rust/marla-core/include/marla_core.h`
- `Tests/MarlaCoreTests/MarlaCoreTests.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors (optional)

None. 本次 Task 的结构合同、FFI、会话状态、隐私披露和结果卡状态强耦合，由主 Agent 保持单一解释和写入所有权。

## Risks and rollback

- 云端 OCR 上传的是用户选择的截图像素，隐私边界比只上传 Vision 文本更敏感；默认必须保持 Vision，GLM 选择和披露必须明确。
- GLM `md_results` 可能丢失或改写代码与占位符；规范块验证和确定性重建是安全边界，不得为了视觉丰富直接信任 Provider Markdown。
- 图片编码和 JSON Base64 会显著增加瞬时内存；大小上限、有限重编码和请求结束释放必须有回归与真实 RSS 观察。
- 云端等待会增加首个翻译增量前的延迟；结果卡必须先出现并诚实区分 OCR 等待与翻译流式状态。
- ABI v4 必须原子同步 Rust、header、Swift 和 Xcode；失败时回滚整个 OCR ABI 与 Provider UI，Vision 路径和 schema v3 翻译合同应保持可用。
- GLM Provider 可通过切回 Vision 完整停用；移除 Key 后不得留下可调用的云端凭据。

## Decisions needed

None. 项目所有者已确认只配置一个 Key、先做固定 GLM-OCR 云端调用和结果卡等待态；默认 Vision、缺 Key 阻止并引导设置、已配置请求失败可见回退 Vision，以及 GLM 结果直接进入结构化翻译均已在本对话明确。

## Completion record

- 实现、自动化、固定 Release 打包与无凭据视觉验收均已完成；24 项 Rust 与 161 项 Swift 测试通过，其中 3 项既有 Vision 图片回归因宿主图形服务限制按规则 skip。
- 固定 `artifacts/Marla_dev.app` 已验证为 `com.marla.app`、开发占位版本 `0.0.0`、macOS 14.0、arm64，并保持 Paper Lantern 资源、稳定本地签名与 designated requirement。
- 项目所有者于 2026-08-20 明确要求完成本 Task，并授权提交 TASK-032/TASK-033 的累积改动、合并到 `main` 和推送。
- 真实 GLM Key 成功调用没有执行，也没有被写成已通过；该项迁移为 `docs/development/VERIFICATION.md` 中的 `RV-005`，不重新打开本实现 Task。
- Scope changes closed: 5/5 accepted or verified.
- Parallel contributions integrated: None; main Agent retained sole write ownership because the FFI、会话、隐私和文档合同强耦合。
