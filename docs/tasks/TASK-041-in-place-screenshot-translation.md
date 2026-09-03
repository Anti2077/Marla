# TASK-041：基于 GLM-OCR 几何的截图原位翻译

Status: Active

Owner: Project owner + Agent

Created: 2026-09-02

Updated: 2026-09-04

Origin: direct request / previously deferred GLM-OCR direction

Conversation: 2026-09-02，从 `main` 建分支实现新的截图原位翻译

## Initial request

项目所有者要求从 `main` 创建独立分支，恢复此前搁置的原位翻译。新的定义是：用户截图框选一个区域后，Marla 在该区域显示一份结构和位置与原区域一致的译文覆盖结果，并利用 GLM-OCR 输出的版面与坐标信息实现，而不是只把 OCR 文本放进附近结果卡。

## Outcome

Marla 提供与“截图翻译”并列的独立“原位翻译”入口。普通截图翻译继续按 OCR 设置选择 Vision 或 GLM-OCR，并始终把结果放在附近结果卡；原位翻译独立框选区域、强制使用 GLM-OCR，并在截图完成后立即显示与框选区域同尺寸的冻结截图 overlay。GLM-OCR 等待、完整稳定 ID 布局翻译、最终译文和失败状态都只更新同一个 panel/content view。文档、网页、设置面板和表格中的可靠译文块保持原有位置与阅读结构；单个不可靠块保留冻结原图，无可靠块或合同无效时在原 overlay 内显示失败，不跳到附近结果卡或 Vision。

## Why now

TASK-033 已实现 GLM-OCR 上传、Keychain、取消、Vision 回退以及带稳定 ID、阅读顺序和归一坐标的 `OCRDocument`，但其几何信息在生成 `semanticMarkdown` 后没有进入展示层。此前真实 GLM API 探针已经证明 `layout_details` 比 `md_results` 更适合作为几何输入；本次项目所有者明确授权把该方向实现为截图原位翻译。

现行 `PRODUCT.md` 和 `UX_PRINCIPLES.md` 仍记录旧的否定结论，即不覆盖源内容。该结论与本次直接要求冲突。本 Task 将以新的严格边界取代它：仅对用户主动截图、坐标可靠、冻结截图可重建且可立即撤销的会话允许覆盖；其它入口和不可靠结果继续使用附近结果卡。

## In Scope

- 从本地 `main` 的 `0b15e4d` 建立 `Anti2077/task-041-in-place-screenshot-translation` 独立分支和 worktree，不带入 TASK-040 的未提交改动。
- 独立原位翻译强制使用 GLM-OCR；成功后保留同次 `CapturedScreenshot`、`globalRect` 和规范 `OCRDocument` 到活动会话结束。普通截图翻译即使选择 GLM-OCR，也只把规范 Markdown 送入附近结果卡，不进入覆盖层。
- 新增版本化的布局翻译合同：一次请求携带有上下文的完整 block 集合、稳定 ID、类型和源文字；Provider 返回严格 ID 键控的译文集合，不按行或 block 分别发独立请求。
- 在 Rust Provider 层生成布局专用提示与结构化输出，校验 schema、ID 集合、重复/未知/缺失 ID、空译文和受保护 payload；任何无效结果不得进入覆盖层。
- Swift/AppKit 新增截图原位覆盖协调器、无边框非激活窗口和原生文字渲染视图；覆盖窗口 frame 与原 `globalRect` 一致，并正确处理多显示器与 macOS 全局坐标。
- 覆盖内容以冻结截图作为背景，只在有可靠 OCR block 的区域遮罩原文字并绘制译文；几何坐标独立于译文保存，不因目标语言重排而改写。
- 根据 block 类型、边界和译文长度选择原生字体层级、对齐、换行与有下限的自适应字号；译文无法在合理下限内适配时保留该块原图，无可靠块时在同一 overlay 内显示失败，不裁掉或隐藏内容。
- 表格、标题、段落、列表、代码、公式、caption 和其它 block 保持各自的边界与阅读顺序；首版不承诺恢复原应用的精确字体、材质、渐变或控件语义。
- 原位翻译路径在截图完成后立即创建同 frame overlay 并显示冻结截图；OCR 识别、布局翻译、完成和失败只更新这一个 panel/content view，不显示现有结果卡。
- `Esc`、关闭、新截图、取消、源会话替换和 App 退出会取消网络工作并销毁覆盖窗口及其内存数据；不增加持久化历史、截图文件或布局缓存。
- Vision 继续是普通截图翻译的默认、本机、纯文本路径；普通 GLM 截图也继续使用附近结果卡并可失败回退 Vision。原位翻译中的 GLM 请求失败后留在同一 overlay 显示失败，不进入没有布局合同的 Vision 或附近结果卡。
- 提供覆盖窗口的可发现关闭控件、键盘 Escape、VoiceOver 可读摘要和 Reduce Motion/Reduce Transparency/Increase Contrast 行为；展示本身不抢走源应用焦点。
- 新增可确定的 UI automation fixture，使无真实凭据时仍能对真实 Release App 的覆盖窗口完成浅色、深色和 Reduce Motion 截图评审；fixture 不冒充真实 GLM 成功调用。
- 新增或修订 Accepted ADR，明确冻结截图原位重建、可靠性门槛、隐私、降级和原生渲染边界；同步 Product、UX、截图功能规格、架构、数据合同、`STATUS.md` 与验证记录。
- 完成 Rust/Swift 单元与集成测试、统一检查、固定签名 Release 开发 App，以及真实覆盖窗口五维视觉评审，每一维至少 7/10。

## Out of Scope

- 选中文本入口的单行覆盖、持续跟随滚动、浏览器 DOM 重写、实时视频/游戏翻译或自动监听页面变化。
- 对照片、毛玻璃、渐变、复杂海报、任意控件状态或原字体做像素级一致承诺。
- 编辑 OCR block、手工校正框、拖动/缩放译文块、导出翻译后图片、复制 HTML/RTF 或持久化截图/布局历史。
- Vision 估算布局、用指针位置冒充文本位置，或在 GLM 坐标失败时继续显示不精确覆盖层。
- 每个 OCR block 单独调用翻译 API；这会丢失句间、表格和标题上下文。
- 新 OCR Provider、本地 GLM-OCR/MLX/Ollama、Python、Tauri、WebView、localhost sidecar、账号、计费或公开发布准备。
- 改变翻译 Provider 默认值、OCR 默认值、产品版本或 `0.0.0` 开发占位。
- 要求 Agent 读取、输入、输出或保存真实 GLM-OCR/翻译 API Key；真实凭据路径仍由项目所有者在 App 中操作。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-09-02 | Project owner | 从 `main` 建独立分支，恢复此前搁置的原位翻译 | 增加隔离 worktree、Task、分支与基线核对 | Closed |
| 2026-09-02 | Project owner | 新定义为截图区域内结构和位置一致的译文覆盖，并使用 GLM-OCR 位置信息 | 取代旧的“只在附近显示结果卡”限制；增加布局翻译、截图重建、覆盖窗口和可靠降级验收 | Closed |
| 2026-09-02 | Necessary support | 现行 Product/UX 明确否定覆盖源内容，与新请求冲突 | 新增耐久 ADR，并同步 Product/UX/功能规格；限定为显式截图、冻结重建、可靠坐标和可撤销覆盖 | Closed |
| 2026-09-02 | Project owner | “原位翻译是一个独立的功能” | 重新打开 Task；新增与“截图翻译”并列的“原位翻译”菜单入口和独立快捷键。普通截图翻译始终使用附近结果卡；只有独立原位入口强制使用 GLM 几何覆盖，并重建固定 App 做真实 UI 验收 | Closed |
| 2026-09-02 | Project owner | 固定 App 真实使用时直接显示“原位排版不可用” | 重新打开 Task；将单块失败拖垮整次覆盖的全有或全无展示门改为可靠块覆盖，修正背景采样对文字边缘的误判，并补充混合质量布局测试和固定 App 复验 | Closed |
| 2026-09-02 | Project owner | 截图完成后应立即在原区域建立同尺寸覆盖层；OCR 等待、翻译和最终译文都在同一层内更新，全程不弹附近结果卡 | 再次打开 Task；新增单一 overlay 状态机、截图后立即展示、原位路径与 nearby panel 完全分离、关闭取消与过期回调拒绝验收 | Closed |
| 2026-09-02 | Project owner | 真实表格截图出现英文重影、块状白底和行底色断裂 | 废止每块纯色 mask + `NSTextField` 的最终绘制；改为连续自绘表面和逐扫描线背景修复，并增加交替行底色、网格线和多行单元格 fixture | Closed |
| 2026-09-02 | Necessary support | 扩大文字擦除边界以清掉 inline-code 装饰时可能误伤相邻表格竖线；原位权限/框选失败与成功生命周期也需彻底脱离附近结果卡 | 基于原始像素保护贯穿文字上下的竖向结构线；新增 inline-code/网格回归、pre-capture intent 策略和成功 session 收束，并以项目所有者真实截图做离线几何诊断 | Closed |
| 2026-09-02 | Project owner | 固定 App 真实调用显示“翻译服务没有返回可安全定位的块级译文” | 再次打开 Task；修正 Qwen-MT User-only 请求不能承载 JSON 控制说明的问题，以单次完整边界载荷恢复 block，并补充累计 SSE 的 C ABI 回归、完整检查与固定 App 重建；真实网络结果保留给项目所有者复测 | Closed |
| 2026-09-02 | Project owner | 真实 GLM 成功结果把 `##` 标题和整张 GFM 表格源码直接画进 overlay | 再次打开 Task；普通 block 先投影为可见文本，整表 block 原生展开为同一源 ID 下的单元格几何，并补充表格原子背景恢复、真实三块 fixture、固定 App 截图和完整回归 | Active |
| 2026-09-04 | Project owner | 提交全部现有改动并推送全部本地分支 | 授权把当前实现作为进行中快照提交并推送；不关闭真实 GLM 网络复测验收项 | Active |

## Current evidence

- 分支从本地 `main` `0b15e4d` 建立；原工作树仍在 `Anti2077/task-040-provider-thinking-policy`，其 5 处未提交改动未被暂存、切换或带入本分支。
- 翻译 JSON 请求升级到 schema v4；普通调用省略 `inPlaceBlocks` 并保持旧语义，原位调用一次发送完整有序 block 集。Rust 为通用与 Qwen Provider 生成布局提示，缓冲完整结果，并严格拒绝 schema、ID、空译文和受保护 payload 错误。
- 独立原位入口在同一活动任务内保留 `CapturedScreenshot`、`globalRect` 和规范 `OCRDocument`，完成布局翻译与纯几何 plan 后交给非激活 AppKit overlay；普通截图翻译、Vision 和 GLM-to-Vision fallback 从不进入覆盖层或合成坐标。
- 覆盖窗口在 OCR 前使用冻结截图背景和源 frame 出现；结果阶段把可靠 block 的原文字区域按扫描线从左右邻域插值为一张连续背景，再直接绘制译文。单个无 bounds、过小、严重重叠、复杂背景或 8pt 下仍无法适配的块保留冻结原图；无可靠块、Provider 合同无效或绘制失败只更新同一 overlay 的失败状态。
- 最新统一检查通过 31 项 Rust 与 208 项 Swift；原位 overlay 定向套件为 17 项。新增回归覆盖 Markdown heading 可见文本投影、一个 GFM table block 展开为原生单元格、按唯一源 ID 统计、表格背景/适配原子拒绝，以及不得把旧单元格文字横向拉成灰线。
- 项目所有者提供的 1640x838 表格截图经本机 Vision 临时诊断得到 22 个真实文字框，并完整经过生产 `InPlaceOverlayLayoutBuilder` 与 `ScreenshotBackgroundRestorer`。输出 `/private/tmp/marla-task041-user-screenshot-restored-structure.png` 已确认旧英文、inline-code 空壳和块状白框消失，三列表格横竖线及交替行底色连续。该诊断只验证真实截图像素和生产几何/背景修复；译文是临时人工映射，OCR 几何来自 Vision，不冒充 GLM 网络证据。
- 先前真实 GLM API 样本的 `bbox_2d` 是相对 `1983×2806` 页面的整数像素；现有 adapter 已按实际 page dimensions 归一。项目所有者本轮真实固定 App 调用已经成功经过 GLM-OCR 与 Qwen-MT 并显示中文完成态；可见结果由 3 个源 block 组成：标题、整张 GFM table 和段落。这同时暴露旧 renderer 将 Markdown 源码当普通文字绘制的问题。
- 项目所有者最新补充的 Markdown 源码截图时间为 2026-09-02 18:58:27，早于修复版固定 Release 可执行文件的 19:11:27；该截图仍证明旧 renderer 缺陷，但不能作为新版回归。当前 PID `17988` 的实际路径已核对为本 Task 的 `/private/tmp/marla-task-041/artifacts/Marla_dev.app/Contents/MacOS/Marla`，等待在此实例中重新触发真实网络完成态。
- 修复后的 Qwen-MT 适配仍以一次请求发送完整有序 block 集，但 User Message 只包含带请求 token、顺序和 allowlist kind 的不透明 BEGIN/END 边界及源文字，不再包含控制说明或真实稳定 ID。Rust 在累计流结束后恢复边界、重新附上源稳定 ID，再执行既有完整 ID、非空译文和 protected-payload 校验；修改/缺失边界或额外文字仍会拒绝。
- 新的三块 Release fixture 生成 `/private/tmp/marla-task041-md-table-clean-light.png` 和 `/private/tmp/marla-task041-md-table-clean-dark.png`：标题中无 `##`，整表中无 pipe/delimiter 源码，三列五行网格、多行译文和交替行背景完整，且无旧英文横向拖影。fixture 复现真实 GLM block 粒度但只含合成内容，不冒充网络调用；最新固定 App 的真实凭据复测仍由项目所有者操作。

## Implemented approach

1. 在 `MarlaCore` 定义 `InPlaceTranslationRequest/Result/Block`，让 OCR 几何与目标文字以稳定 ID 连接；译文绝不修改 bounds。
2. 扩展 Rust translation request schema 和 Provider 适配：通用模型一次发送完整 block JSON 并要求严格 JSON；Qwen-MT 的单个 User Message 只发送完整有序的边界载荷。流结束后 Rust 恢复为稳定 ID 结果，执行同一套严格校验，再通过现有事件通道返回规范结果。
3. 由独立原位翻译入口、截图任务与 overlay coordinator 共同持有仅内存的活动上下文，包括冻结图像、全局 frame、OCR document 和取消生命周期；普通截图翻译、选择、Quick Input 与 Vision 不接触它。
4. `ScreenshotTranslationOverlayCoordinator` 在 capture 成功后立即创建固定 frame 的非激活 panel，并以 request ID 守护 `recognizing -> translating -> translated/failed` 状态；更新始终复用同一 window/content view。
5. 普通 block 通过共享 Markdown parser 投影可见文字后排版；一个合法 GFM table block 在原 bbox 内展开为共用源 ID 的原生单元格，按源文/译文测量宽度、换行高度、alignment 和统一字号构建几何。
6. `ScreenshotBackgroundRestorer` 在单张位图中按扫描线插值普通文字区域；表格按源 ID 原子接受并逐行重建连续背景，再由一个自绘 AppKit view 直接绘制全部译文和细网格，不创建逐块/逐 cell mask view 或 `NSTextField`。
7. 用纯几何/排版 plan 单元测试覆盖坐标、字体适配、ID 验证和多显示器 frame；用真实三块粒度 UI fixture 与固定 App 验证 Markdown 投影、窗口、Escape、焦点、外观和适配偏好。

## Acceptance criteria

- [x] 分支和 Task 从本地 `main` 建立，TASK-040 未提交改动保持原样。
- [x] GLM-OCR 路径一次性翻译完整 block 集，结果严格按稳定 ID 返回；未知、重复、缺失、空值或受保护 payload 损坏会被拒绝。
- [x] 成功覆盖窗口与用户框选区域同 frame，block 坐标在单显示器和跨显示器截图中保持正确，译文不改变源几何。
- [x] 冻结截图遮罩原文字，译文按标题/正文/代码/表格等类型原位排版；没有可见双字、越界裁切或不可读的小字。
- [x] 截图完成后，同尺寸无窗口装饰 overlay 在 GLM-OCR 请求开始前立即显示冻结截图；识别、翻译、完成与失败在同一个 panel/content view 内原地更新，不重建窗口。
- [x] 原位翻译路径在任何阶段都不显示附近结果卡；缺少 GLM Key、OCR/翻译失败、无可靠块或结构无效时，冻结截图和简短状态留在 overlay 内，普通截图翻译的附近结果卡行为保持不变。
- [x] 单个无 bounds、坐标越界、严重重叠、复杂背景或译文无法适配块保留冻结原图，其它可靠块继续原位覆盖；无可靠块或结构化返回无效时在同一 overlay 内显示具体原因。
- [x] 最终画面使用单一连续绘制面，不创建每块纯色矩形或文字控件；背景修复保留表格网格线、交替行底色与局部色调连续性，译文无英文重影、控件边框、突兀白框或遮罩接缝。
- [x] “截图翻译”和“原位翻译”是两个并列入口：前者无论使用 Vision 或 GLM 都显示附近结果卡并保留普通 GLM-to-Vision 回退，后者强制使用 GLM-OCR 几何且截图后不进入 nearby/Vision；普通选择和 Quick Input 行为不回归。
- [x] 覆盖窗口不抢焦点；关闭按钮、`Esc`、新截图、会话替换与 App 退出均清理窗口、网络句柄、截图和布局内存，过期 OCR/翻译回调不能更新新 overlay。
- [x] 截图与布局不写入磁盘、Preferences、日志、最近翻译或持久缓存；fixture 只使用合成内容且不含真实凭据/用户截图。
- [x] VoiceOver、键盘关闭、Reduce Motion、Reduce Transparency、Increase Contrast、浅色与深色行为可用。
- [x] Rust/Swift 模型、FFI/schema、窗口协调器、渲染 plan、取消/过期事件和降级均有自动化覆盖。
- [x] 新增代码放入匹配层的新文件，并保持每文件不超过 800 行、顶层类型不超过 8 个。
- [x] `./scripts/check.sh` 和 `./scripts/build-test-app.sh` 通过；固定 App 仍为 `com.marla.app`、`0.0.0`、macOS 14+、arm64 和稳定签名。
- [x] 真实固定 App 的浅色、深色和 Reduce Motion 原位覆盖截图完成五维复审，每一维至少 7/10；真实 GLM 凭据证据与 fixture 证据明确区分。
- [x] ADR、Product、UX、截图规格、Architecture、Data Contracts、Task、Verification 和 `STATUS.md` 与实时代码一致。
- [x] 菜单明确显示独立“原位翻译”入口及 `⌃⇧I` 默认快捷键；OCR 设置明确说明 GLM 依赖和与普通截图翻译的区别；真实固定 App 截图证明功能可发现。
- [x] Qwen-MT 原位翻译不把 JSON 控制说明当作待译内容；单次完整边界载荷可从累计 SSE 恢复 canonical stable-ID 结果，且边界/附加文字错误仍会被拒绝。
- [x] 修复后的 `./scripts/check.sh` 与固定 Release App 重建通过，并交由项目所有者使用已保存凭据复测真实 GLM-OCR + Qwen-MT 路径。
- [x] 合法 Markdown heading、inline syntax 和 GFM table 不作为源码字符串绘制；一个整表 block 原生展开为单元格并保持一个 Provider/source ID。
- [x] 表格布局、背景恢复、overlap 和完成态计数按源 block 原子处理；无法完整适配或任一 cell 背景不可靠时整表保留冻结图。
- [x] 固定 Release App 的真实三块粒度 fixture 在浅色/深色下无 `##`、pipe、delimiter、英文拖影、半表或断裂网格，五维复审每项至少 7/10。
- [ ] 项目所有者使用最新固定 App 对同一真实 GLM 标题/整表/段落截图复测，确认完成态不再显示 Markdown 源码。

## Verification

### Automated

```sh
./scripts/check.sh
./scripts/build-test-app.sh
git diff --check
```

### Manual

- 使用固定 `artifacts/Marla_dev.app` 的合成 UI fixture 检查文档/网页式多 block 覆盖：浅色、深色、Reduce Motion、Reduce Transparency 和 Increase Contrast。
- 检查覆盖窗口 frame、block frame、无裁切/重叠、关闭按钮、`Esc`、新截图替换、源应用焦点和跨显示器坐标。
- 使用真实 GLM 路径时，由项目所有者在 App SecureField 中自行输入 Key；只记录脱敏 block 数量、状态与可见 UI，不记录 Key、完整用户截图或译文内容。
- 对混合了可靠块与无法适配长译文、无 bounds、坐标越界或重叠块的 fixture，确认可靠块继续覆盖且坏块保留原图；对全部块不可用和 Provider ID 不匹配 fixture，确认同一 overlay 保留冻结截图并显示具体原因，且 nearby card 不出现。

## Required Reading

- `AGENTS.md`
- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/product/BRAND.md`
- `docs/development/STATUS.md`
- `docs/development/VERSIONING.md`
- `docs/development/VERIFICATION.md`（RV-005）
- `docs/development/UI_UX_SKILLS.md`
- `docs/tasks/TASK-017-inline-streaming-overlay-feasibility.md`
- `docs/tasks/TASK-018-frozen-screenshot-selection.md`
- `docs/tasks/TASK-028-structured-translation-foundation.md`
- `docs/tasks/TASK-033-glm-ocr-cloud-provider.md`
- `docs/features/screenshot-translation.md`
- `docs/features/language-routing.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/DATA_CONTRACTS.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0002-ocr-strategy.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `docs/architecture/decisions/ADR-0007-app-layer-modularity.md`
- `docs/architecture/decisions/ADR-0009-semantic-markdown-translation-contract.md`
- `docs/architecture/decisions/ADR-0010-unversioned-incubation.md`
- `Sources/MarlaCore/ContentModels.swift`
- `Sources/MarlaCore/OCRModels.swift`
- `Sources/MarlaCore/TranslationModels.swift`
- `Sources/MarlaCore/RustCoreBridge.swift`
- `Sources/MarlaApp/App/ScreenshotTranslation.swift`
- `Sources/MarlaApp/OCR/GLMOCRService.swift`
- `Sources/MarlaApp/Screenshot/ScreenshotCapture.swift`
- `Sources/MarlaApp/Screenshot/ScreenshotSelection.swift`
- `Sources/MarlaApp/Screenshot/ScreenshotTranslationIntent.swift`
- `Sources/MarlaApp/Sessions/TranslationSessionStore.swift`
- `Sources/MarlaApp/Panel/FloatingPanel.swift`
- `Sources/MarlaApp/Panel/TranslationCardView.swift`
- `rust/marla-core/src/glm_ocr.rs`
- `rust/marla-core/src/lib.rs`
- `Tests/MarlaCoreTests/MarlaCoreTests.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors (optional)

本 Task 的 Task、`STATUS.md`、ADR 决策、范围解释、最终措辞、验收与集成由主 Agent 独占。规格/数据合同同步可在 Task 建立后委派给一个有界文档 contributor，且不得修改上述主 Agent 所有文件或自行扩大范围。

## Risks and rollback

- 目标语言通常更长，固定几何可能迫使字号过小或破坏阅读顺序；质量门必须宁可降级，也不能裁切或伪造精确性。
- OCR block 边界可能只包围字形而没有足够背景；遮罩颜色估算在照片、渐变和毛玻璃上可能明显失真。首版应拒绝或降级复杂背景，不承诺通用像素复原。
- 冻结截图覆盖真实应用区域会暂时隐藏其当前状态；窗口必须明显可撤销、非激活、会话短暂，并在新请求/取消时可靠消失。
- JSON 结构化输出仍受 Provider 行为影响；Rust 必须在任何 UI 展示前做完整 ID 和 payload 校验。
- 新窗口会增加 AppKit 生命周期、跨屏坐标和辅助技术风险；通过独立 coordinator、纯 plan 测试和现有 Escape/窗口模式复用控制影响。
- 功能可通过切回 Vision 完整停用；若覆盖构建失败，回滚点是保留 TASK-033 的 GLM semantic Markdown 结果卡路径。

## Decisions needed

None. 项目所有者已明确重新授权截图区域原位覆盖，并把 GLM-OCR 结构/位置信息指定为实现基础；最新范围要求截图后所有状态只使用同一 overlay，可靠块原位绘制，不可靠结果原地失败。

## Verification and reopen record

2026-09-02 项目所有者在首轮固定测试 App 中反馈“没看到原位翻译的功能”，随后明确“原位翻译是一个独立的功能”。本轮新增并验证了与“截图翻译”并列的“原位翻译”入口和 `⌃⇧I`。项目所有者随后先后报告“原位排版不可用”，以及真实表格结果存在英文重影、块状白底、行底色断裂并在等待时弹出附近结果卡。单一 overlay 状态机、连续背景修复与 Qwen-MT 边界恢复先后闭合这些问题。最新真实调用已经显示中文，但暴露标题和整表 Markdown 源码未被渲染；随后提供的同类截图时间早于 19:11 修复构建，未构成新版复测。Task 因此保持 Active，等待当前固定 App 的同一路径完成态。

- Verified commit: 项目所有者已于 2026-09-04 授权把当前工作树作为进行中快照提交并推送；Task 仍等待最新固定 App 的真实 GLM 网络复测，最终提交哈希由 Git 提交记录确定。
- Automated evidence: 最新 `./scripts/check.sh` 通过 31 项 Rust、208 项 Swift、Swift Package、Xcode Debug、Clippy、Rust formatting、工程结构、脚本、空白与 diff 门禁；原位 overlay 17 项定向测试包含 Markdown heading、GFM cell 几何、整表原子拒绝、唯一源 ID 计数和无横向拖影像素回归。`plutil -lint` 通过；最新 `./scripts/build-test-app.sh` 验证固定 Release App 的 Release Rust 路径、Bundle ID `com.marla.app`、`0.0.0`、macOS 14.0、arm64、Paper Lantern 资源、稳定签名和 designated requirement。
- Manual evidence: 最新三块粒度固定 Release fixture 为 `/private/tmp/marla-task041-md-table-clean-light.png` 与 `/private/tmp/marla-task041-md-table-clean-dark.png`，均为 760x480pt / 1520x960px；标题无 Markdown marker，表格无 pipe/delimiter 源码，原生三列五行网格、交替行背景和多行换行完整，无旧英文拖影。原有 waiting/Reduce Motion/failure/menu/OCR Settings 的 `final2` 证据继续覆盖未改变的状态与入口。新完成态五维复审为 8/9/9/9/8。
- Documentation updated: Accepted ADR-0011、Product、UX、截图规格、language routing、Architecture、Data Contracts、Task、Verification 与 STATUS 均已同步。
- Remaining work: 项目所有者使用 App 内已保存的真实凭据，对最新固定 App 重复同一 GLM 标题/整表/段落请求，确认原生 Markdown 投影也通过真实网络完成态；Agent 不读取、输入、输出或记录凭据。
- Open scope change: Markdown/GFM renderer 的代码、自动化、Release fixture 和文档已完成，等待项目所有者固定 App 复测后关闭。
- Parallel contributions integrated: `task041_contract_docs` 独占修改截图规格、Architecture 和 Data Contracts；主 Agent 已按最终 schema v4、完整 protected-payload 校验、C ABI v4 不变和真实 App 证据统一校正其 target wording 与具体类型描述。
