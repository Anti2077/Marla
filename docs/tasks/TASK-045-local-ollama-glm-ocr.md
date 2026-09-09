# TASK-045：本机 Ollama GLM-OCR 适配

Status: Active

Owner: Project owner + Agent

Created: 2026-09-08

Updated: 2026-09-09

Origin: direct request

Conversation: 2026-09-08，在当前工作树安装并适配本机 Ollama GLM-OCR

## Initial request

项目所有者要求在本机安装 GLM-OCR，并让 Marla 支持通过 Ollama 调用本地模型。

## In Scope

- 以本地 `main@4598dda` 为基线，在 `Anti2077/task-045-local-ollama-glm-ocr` 分支承载本 Task；不把本机 OCR 改动放入 `main`。
- 安装并记录本机 Ollama 与 `glm-ocr:latest` 模型状态；不记录任何私密凭据或用户截图内容。
- 在现有 Rust OCR FFI 中增加显式本机 Ollama GLM-OCR Provider，固定使用本机 Ollama API 与 `glm-ocr` 模型。
- 在 OCR 设置和普通截图翻译中提供本机 Provider，复用现有取消、超时、结果卡和 Vision 回退语义。
- 旧 profile、云端 GLM-OCR、Vision 默认和原位翻译行为保持兼容。
- 为本机请求、Ollama 响应归一和旧 JSON 兼容增加定向回归，并运行项目检查。
- 本轮增加常见应用表格的合成图片评测；按真实输出增强 HTML5 表格解析、保留合并单元格，并复用原生 TextKit 展示。合成素材可进入测试证据，用户截图与真实 OCR 正文仍不持久化。

## Out of Scope

- 不改变云端 GLM-OCR 的官方 endpoint、Keychain 或结构化坐标合同。
- 本机 Ollama 响应没有稳定布局坐标，因此不用于独立原位翻译覆盖层；原位入口继续强制云端 GLM-OCR。
- 不把模型权重打包进 Marla，不新增 Tauri、Python sidecar、WebView、Marla 自有 localhost 服务或远程代理。
- 不实现自动模型下载、模型管理器、厂商专属推理参数、批量 OCR、持久化截图或 OCR 历史。
- 本轮允许在专用分支提交实现与文档；不合并到 `main`，不推送任何分支。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-09-08 | Project owner | 从独立 worktree 改为当前工作树直接实施 | 形成了本机 OCR 适配改动；该临时归属已由 2026-09-09 的专用分支迁移记录取代 | Superseded |
| 2026-09-08 | Project owner | 现场截图显示本机 GLM-OCR 返回 literal HTML table，要求确认本地输出差异并加入提示词 | Ollama prompt 明确要求 GFM、禁止 table HTML；响应归一同时把安全 literal HTML table 转成 GFM 并保留表格前后文字；增加 Rust 回归 | Implemented; owner acceptance pending |
| 2026-09-08 | Project owner | 提供 4 张 Quantum Leap 文档截图作为本机模型素材 | 直接调用本机 `glm-ocr:latest` 做四图测试，记录尺寸、耗时、输出格式和表格闭合性；不保存 OCR 正文或截图副本 | Completed; improvement plan pending |
| 2026-09-08 | Project owner | 寻找常见表格场景、测试模型 HTML 输出并针对适配 | 七类合成表格、真实本机请求；HTML5 解析、普通表格 GFM、合并表格安全 HTML 与原生显示；内容遗漏与重复独立记为 OCR 质量缺口 | Implemented; verification gaps below |
| 2026-09-09 | Project owner + Agent | 修复 TASK-045 所有权冲突并迁移分支 | 废弃截图选择提效 TASK-045，保留其专用恢复 stash；删除旧 worktree/分支；将本机 Ollama 适配从 `main@4598dda` 迁入本 Task 分支；TASK-044 已由 `90db067` 与 `4598dda` 进入本地 `main` | Accepted |

## Acceptance criteria

- [x] 本机 Ollama 版本与模型安装状态有可复现命令证据；失败或部分完成如实记录。
- [x] OCR Provider Picker 可选择本机 Ollama GLM-OCR；本机路径不要求云端 API Key。
- [x] 普通截图选择本机 Provider 后，图片通过 Rust FFI 发送至固定本机 Ollama `/api/generate`，响应 Markdown 进入现有翻译结果卡。
- [x] 普通 HTML 表格转 GFM；合并单元格或格内富文本保留规范 HTML 子集，原生 TextKit 保留跨度。代码内字面 HTML 不转换，无法唯一判定的错列/非法跨度拒绝并沿用可见回退。
- [x] 本机请求支持取消、超时、空响应和网络/服务错误；普通截图失败仍进入既有 Vision 回退。
- [x] 原位翻译不误用本机 Provider，仍使用云端 GLM-OCR 结构和坐标合同。
- [x] 云端 GLM-OCR、Vision 默认、旧 OCR JSON 与已有 OCR 回归不受影响。
- [x] Rust 52 项、8 项新增 Swift 表格回归、结构/工程/diff 检查通过，固定 Release App 已重建。
- [x] 2026-09-09 宿主环境重跑完整 `./scripts/check.sh`：52 Rust、249 Swift、Xcode Debug、结构/脚本/空白/diff 检查全部通过；此前窗口和剪贴板失败未复现。
- [x] 文档只记录已验证事实；真实本地模型 OCR 成功路径与视觉验收单独标记为 owner acceptance gap。
- [ ] 固定 App 的真实本机 OCR→翻译→原生表格显示、取消/回退、复制与深浅色窗口验收完成。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/development/VERSIONING.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/DATA_CONTRACTS.md`
- `docs/architecture/decisions/ADR-0002-ocr-strategy.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `docs/architecture/decisions/ADR-0012-external-local-ollama-ocr.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `Sources/MarlaCore/OCRModels.swift`
- `Sources/MarlaCore/RustCoreBridge.swift`
- `Sources/MarlaApp/OCR/GLMOCRService.swift`
- `Sources/MarlaApp/App/ScreenshotTranslation.swift`
- `Sources/MarlaApp/Settings/OCRSettingsSection.swift`
- `rust/marla-core/src/glm_ocr.rs`
- `Tests/MarlaCoreTests/MarlaCoreTests.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Current evidence

完整七场景实测见 [`OCR_TABLE_EVALUATION_2026-09-08.md`](../development/OCR_TABLE_EVALUATION_2026-09-08.md)。合成图片来自可重现的 AppKit 绘制程序，测试输入没有用户凭据或真实业务数据。原始/规范结果以合成 regression fixture 保存；产品内截图和 OCR 输出仍仅在内存中处理。

- Ollama `0.33.2`、`glm-ocr:latest`（磁盘约 2.2 GB、digest 前缀 `6effedd0dc8a`）可用。磁盘权重大小不是运行内存。
- 初始约 90 秒请求返回 `fetch failed`；后续 180 秒请求返回 curl 28、0 bytes。后来四张用户素材和本轮七张合成图都取得非空输出，因此旧超时不再代表当前无法推理。
- 七图各调用一次，HTTP 200，耗时 6.452–16.499 秒，5 图返回 HTML、2 图返回 GFM 风格文本。未控制加载状态，不能称为冷/热启动基准。`done=false` 与缺少计时字段仍是观测异常，不能用于证明完整或截断。
- 5 个 HTML 场景漏标题；配置表重复三份；API 表里未转义的 pipe 会造成错列；财务表缺少一个 row start。解析与展示修复不等于 OCR 准确率已经过关。
- 普通表转 GFM；`rowspan/colspan`、行表头、代码/粗体/换行等保留规范、惰性的 HTML 表格子集。规范输出不含 class/style/脚本/资源；原生投影不使用 WebView，不载入外部实体或资源。
- 受限 tokenizer 精确识别标签、带引号属性和实体，支持明确的省略 row start/cell close 修复；验证 128 行、32 列和跨度覆盖，拒绝嵌套表、越界跨度、危险标签和不规则网格。不是完整 HTML5 浏览器实现，也不声称支持所有 HTML。
- 代码围栏、行内代码、缩进代码不被改写；普通表前后文字保留。含糊的 GFM 多余 pipe 拒绝，沿用 Vision 回退，不猜测列归属。
- 原位路径仍使用云端坐标合同；新 HTML/span 投影不会被误当成矩形 GFM 网格送入原位布局。

## Verification

- 2026-09-09 宿主环境完整 `./scripts/check.sh` 通过：52 项 Rust、249 项 Swift、Xcode Debug、结构、脚本、空白与 diff 检查全部通过。此前沙箱内的 `NSScreen`/`FloatingPanel.swift:342` 中止和剪贴板 nil 断言未复现。
- `cargo fmt`、严格 Clippy、52 项 Rust：通过。测试包含实际七场景合成输出、混合 th/td、空格、实体、内联格式、非法跨度、代码保护与 canonical fixture 一致性。
- 新增 8 项 Swift HTML/native-span 回归通过；可选截图输出覆盖财务/排期/账单、380/760pt、浅/深色。为生产 TextKit 组件合成快照，不是固定 App 系统玻璃或真实翻译截图。
- 2026-09-09 宿主环境完整测试执行 249 项 Swift，0 失败；HTML/native table 定向测试 8 项全部通过。
- 历史记录：受限环境曾在 `FloatingPanel.swift:342` 的 `NSScreen.screens.first!` 中止，并报告沙箱下 `nice(5)` 不允许；2026-09-09 的完整宿主检查已通过，早期受限失败不再代表最新结果。

- 新 HTML5 crate 下载也曾被拒绝；依赖和 lockfile 已恢复到本轮开始状态，最终实现没有新增依赖。
- 固定 Release `artifacts/Marla_dev.app` 重建成功：`com.marla.app`、`0.0.0`、macOS 14+、arm64、稳定签名 `API Usage Monitor Dev` 与 designated requirement 通过。
- 结构门禁、工程 plist、`git diff --check`：通过。

## Remaining acceptance and next improvements

- 在固定 App 中完成真实本机截图→翻译→原生 HTML/span 表格、取消/回退、复制和深浅色窗口验收。
- 固定 App 的真实本机截图→已配置翻译→原生 HTML/span 表格显示、取消/回退、选择复制和深浅色窗口验收仍待完成；泛用翻译提示词已要求保留 HTML 标签、单元格顺序与 span 值，但 Qwen-MT 仍沿用原生翻译协议，未做真实账号测试。
- 后续重点是标题遗漏、重复输出和含糊 GFM：先扩充带人工期望的图像集，再验证重试或格式提示是否有效。不能自动补写不存在于 OCR 输出的标题，也不能无依据删除相同的表格。
- 尚未实现逐单元格 ID 翻译和译前/译后结构同构保证、模型驻留策略、嵌套表或任意 HTML5 支持。

## Completion record

Status remains Active due to the owner acceptance gaps above. Implementation commit `ee8d526` and this documentation repair are on `Anti2077/task-045-local-ollama-glm-ocr`; the branch is not merged to `main` and is not pushed. The retired screenshot experiment remains only in the explicitly named recovery stash.
