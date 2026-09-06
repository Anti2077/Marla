# 当前开发基线验证记录

这里区分“当前仍待真实环境补证据的验证项”和“已经关闭、仅供未来发布准备引用的基线证据”。验证项不是产品 Idea 或 Backlog；发现可复现代码缺陷时，才创建独立修复 Task。

## 当前待验证

| ID | 工作 | 状态 | 说明 |
| --- | --- | --- | --- |
| RV-005 | 原位表格背景修复后的实机验收 | In Progress | 所有者已确认迁移窗口可正常显示译文表格；授权的 3 次真实请求也都返回有效表格，故障已定位为原位背景误判。内部采样修复、本地原图扰动复测、234 项 Swift 和固定 App 构建通过，仍待修复后真实点击/外观验收。实验性开关与实验室页面的自动化门控已通过，但不替代真实 GLM/系统玻璃验收。 |

### RV-005：GLM-OCR 真实凭据成功路径

- 在固定签名 `artifacts/Marla_dev.app` 的 OCR 设置 SecureField 中，由项目所有者自行输入并保存 GLM Key；随后从菜单调用独立“原位翻译”入口或按 `⌃⇧I`，不通过普通“截图翻译”入口触发覆盖。
- 使用不含敏感信息、同时含标题、代码或表格结构的测试截图，确认框选完成后同尺寸 overlay 在 GLM-OCR 请求前立即出现，结构识别、按稳定 ID 返回的布局翻译和结果都在同一 panel/content view 内更新。可靠块覆盖译文，单个无坐标、重叠、无法适配或复杂背景块保留原截图；无可靠块、Provider 合同无效或绘制失败在同一 overlay 内显示具体失败。整个原位路径不出现附近结果卡或 Vision 回退。另行确认普通“截图翻译”在 Vision 与 GLM-OCR 设置下都只显示附近结果卡并保留既有回退。
- 证据只记录成功/失败、脱敏时延范围与结构类型统计；不记录 Key、Authorization Header、完整截图、Provider 账号或识别正文。
- 未完成本项不重新打开已完成的 TASK-033；当前 TASK-041 已因真实完成态复现的 Markdown/GFM 展示缺陷保持 Active。

### TASK-041 Qwen-MT 与 Markdown 原位投影证据

- 项目所有者的真实固定 App 截图显示同一原位 overlay 内的“翻译服务没有返回可安全定位的块级译文”，证明路径已越过截图与 overlay 创建，但不单独证明失败来自 Swift 或 Rust 哪一层。
- 代码核对确认 Qwen-MT 使用单 User Message 与 `translation_options`，会把整个 Message 当作待译文本。修复后 User Message 不含 JSON 控制说明或真实 stable ID，只含一次完整、有序、按请求 token 隔离的 block BEGIN/END 边界载荷；Rust 恢复真实 ID 后仍执行原有完整 block 集、非空译文和 protected-payload 校验。
- 项目所有者的后续真实固定 App 截图已显示中文完成态，证明 GLM-OCR、Qwen-MT 边界恢复和同一 overlay 更新实际成功；真实 GLM 粒度为标题、整张 GFM table、段落 3 个 block。截图同时证明旧 renderer 直接显示了标题 `##`、pipe 和 delimiter，这一展示缺陷不再归类为 Provider 合同失败。
- 项目所有者随后补充的 Markdown 源码截图文件时间为 2026-09-02 18:58:27，早于包含 `InPlaceMarkdownProjection` 与原生 table 展开的固定 Release 可执行文件时间 19:11:27；因此它继续作为旧 renderer 缺陷证据，不构成最新构建复测。19:11 构建已按绝对路径启动，真实网络完成态仍须在该运行实例中重新触发。
- 最新 `./scripts/check.sh` 通过 31 项 Rust 与 216 项 Swift 测试、Swift Package、Xcode Debug、Clippy、格式、工程结构、脚本、空白与 diff 门禁。新增完整 C ABI/mock 累计 SSE 回归证明 Provider 边界；8 项新富 Markdown 属性测试全部通过，原有 17 项 overlay 回归继续通过，原位/Markdown 定向过滤共 27 项。
- 最新 `./scripts/build-test-app.sh` 已重建固定 Release App，并验证 Release Rust 路径、Bundle ID `com.marla.app`、版本 `0.0.0`、macOS 14.0、arm64、Paper Lantern 资源、稳定签名与 designated requirement。完整富 Markdown 合成完成态已通过，最新真实网络完成态仍待项目所有者复测。

## 已完成验证证据（不是待办）

RV-001～004 均已关闭，不属于当前工作队列。保留这些编号和摘要，是为了让 `STATUS.md`、历史 Task 与未来发布准备能够引用已经发生的真实验收；不应据此自动重新安排工作。

| ID | 已验证工作 | 关闭证据 |
| --- | --- | --- |
| RV-001 | 跨应用划词翻译 | 项目所有者确认固定 App 的整体成功率很高；原 BL-001 已关闭。 |
| RV-002 | 截图裁剪、冻结、取消与权限持久化 | 项目所有者于 2026-08-18 确认完整真实环境复验通过。 |
| RV-003 | UI 延迟与内存预算 | 30 组固定 Release 本地样本及四类 RSS 口径均在预算内。 |
| RV-004 | “保存并测试”与真实翻译凭据一致性 | 项目所有者于 2026-08-18 确认同一已保存 profile 的两条真实路径均通过。 |

### TASK-041 合成原位覆盖证据

- 2026-09-05 表格背景误拒绝定位：所有者 18:04 迁移截图证明同次译文已是中文原生表格；此前把单一 HTML 规范化断点当作该样本确定根因的结论不完整。经所有者明确授权，修复前 3 次实际 GLM-OCR + 已配置翻译调用均返回 3 个 block、合法 5×3 表格，源/译解析一致，均生成 15 个 cell；背景修复得到 0、15、15 个表格 cell。只记录结构计数，不保留完整 OCR/译文 JSON、请求、配置或密钥。
- 本地原图以相同文字/译文做 ±6px 几何扰动，旧 perimeter sampler 得到成功/拒绝/成功；改用原始 cell 内部密集主色采样后三者均生成并修复 15 个 cell。普通文字阈值不变；新增非用户合成回归覆盖浅/深背景跨边界字形、棋盘格采样混叠、宽渐变和单个复杂象限。
- 最终完整检查为 31 Rust、234 Swift、Xcode Debug、结构与 diff 门禁全通过；固定签名 Release App 已重建。修复后另启动的网络对照迟未产生可确认结果，已停止该测试进程，不计入通过次数，也不推断是 API 还是凭据等待。临时联网入口和含原图文字的探针已移除；最终 App 不包含诊断入口，不保存 OCR/译文 JSON 或截图。原图未删除。
- 最新 2026-09-05 顶部边框修订：41 项 InPlace、31 Rust、230 Swift、Xcode Debug 与固定签名 Release 构建通过。复现到隐藏 `FloatingPanelCoordinator` 的 local/global dismissal handler 会在原位按钮 action 前调用 `hide()` 清空共享 session；现要求 panel 可见才有权关闭/消费事件。新增集成回归按“点击监听→实际 app handoff→已显示结果卡的外部点击”顺序验证不清空原位、可以迁移、正常结果卡仍关闭；已显示后隐藏的窗口也不再误清下一会话。
- 常态 6pt、展开侧/底 10pt；顶部外扩 36pt，28pt 高按钮居中。侧/底 12pt、顶部 40pt 固定预留让截图坐标不随展开改变。`/private/tmp/marla-041-topbar-in-place-overlay-hover-light.png`、`/private/tmp/marla-041-topbar-in-place-overlay-small-dark.png`、`/private/tmp/marla-041-topbar-in-place-overlay-light.png` 和 `/private/tmp/marla-041-topbar-in-place-overlay-transfer-light.png` 为新 Release 的降低透明度布局截图，不冒充系统玻璃或真实鼠标证据。新增布局五维为 8/8/8/7/7，截图外顶部按钮不与内容相交。
- 交互 fixture `in-place-overlay-interactive` 已显式启用生产结果卡事件监听（其它无凭据/无全局快捷键限制不变）。临时独立 App 标识用于避免操作所有者的真实实例；Computer Use 连接两次 timeout，未成功执行真实鼠标点击或完成系统玻璃复审。关闭测试进程后交给所有者复测，不把程序直接调用 transfer 的旧 fixture 标为该点击链路验收。
- 2026-09-05 玻璃边框/主动迁移：当前目录 `./scripts/check.sh` 通过 31 Rust、228 Swift 和 Xcode Debug，39 项 InPlace 定向测试通过；固定 `artifacts/Marla_dev.app` Release 及稳定签名验证通过。新增 8 项测试验证实际截图 content globalRect 不变、边缘迟滞/操作区、只在完成态单次迁移、失败/过期动作保护、完整 Markdown/无坐标块保留、语言/profile 不变、无凭据读取和无自动最近记录。旧测试数为上一轮证据，不代表当前总数。
- 新离线图位于 `/private/tmp/marla-041-in-place-overlay-light.png`、`/private/tmp/marla-041-in-place-overlay-dark.png`、`/private/tmp/marla-041-in-place-overlay-hover-light.png`、`/private/tmp/marla-041-in-place-overlay-hover-dark.png`、`/private/tmp/marla-041-in-place-overlay-small-light.png`、`/private/tmp/marla-041-in-place-overlay-transfer-light.png` 和 `/private/tmp/marla-041-chrome-reduced.png`。确认靠近态动作标签、小区域图标、迁移后现有结果卡及可滚动 Markdown。离屏 cache 不包含完整系统 glass effect，不能用于宣称真实玻璃材质通过；本轮另通过 Computer Use 的系统合成图确认浅色细环可见。
- 本轮五维仅针对新增边框/动作区与迁移窗口：Philosophy 8、Hierarchy 8、Craft 7、Functionality 7、Originality 7；现有富文本 fixture 中 H1/H3 间距偏紧不作为本轮修复完成项。真实指针靠近/离开及深色系统材质、键盘/VoiceOver 和真实 GLM 验收继续待所有者操作；不把内部设定 proximity 的 fixture 当鼠标实测。
- `./scripts/check.sh` 通过 31 项 Rust 与 217 项 Swift 测试、Swift Package、Xcode Debug、Clippy、Rust formatting、工程结构、脚本、空白与 diff 门禁；`plutil -lint Marla.xcodeproj/project.pbxproj` 通过。8 项新属性测试明确验证 H1-H6、行内语义、代码、引用、任务/嵌套列表、表格 cell 富文本和同一 attributed document 的拟合/绘制合同；GLM literal HTML 整表、既有 GFM 原子表格、intent 分流、背景修复与 Qwen-MT 边界回归继续通过。
- `./scripts/build-test-app.sh` 从 Release Rust 库重建固定 `artifacts/Marla_dev.app`，验证 Bundle ID `com.marla.app`、版本 `0.0.0`、macOS 14.0、arm64、Paper Lantern 资源、稳定签名 `API Usage Monitor Dev` 和 designated requirement。
- 最新完成态 fixture 已改为真实 GLM 的标题、整表、段落 3 个源 block，并生成 `/private/tmp/marla-task041-md-table-clean-light.png` 与 `/private/tmp/marla-task041-md-table-clean-dark.png`。两张均为 1520x960 Retina 像素，对应 760x480 逻辑覆盖 frame；标题无 `##`，表格无 pipe/delimiter 源码，原生三列五行网格、多行换行和交替行底色完整，且无旧英文横向拖影。原有 `final2` waiting、Reduce Motion 和 failure 图继续覆盖未改变的状态。
- 新增回归复现 GLM `layout_details` 直接返回 literal HTML 整表的形态；布局层在源表校验前调用 `LiteralHTMLTableNormalizer`，与 `InPlaceTranslationService` 的 canonical GFM 输入保持一致。测试确认 3 列 5 行表格生成 15 个 native cells，而不是因源 HTML 无法被 GFM parser 识别而整表冻结。
- 最新固定 Release App 以单块 GLM literal HTML 表格输入生成 `/private/tmp/marla-task041-glm-html-table.png`；截图确认中文原生表格、网格与行内样式可见，没有 HTML/GFM 标记或英文源文字。五维复审为 8/9/9/9/8。
- 最终完整富 Markdown fixture 为 `/private/tmp/marla-task041-rich-markdown-final-light.png` 与 `/private/tmp/marla-task041-rich-markdown-final-dark.png`。两张均为 1720x1240 Retina 像素，对应 860x620 逻辑覆盖 frame；H1/H3/H6 层级、粗体/斜体/粗斜体/删除线、链接、行内代码、整块 fenced-code 背景、引用、任务/嵌套列表及富文本表格 cell 清楚可见，无 Markdown 控制标记、裁切或重叠。
- 相同新 Release 产物的菜单浅色/深色证据为 `/private/tmp/marla-task041-final2-menu-light.png` 与 `/private/tmp/marla-task041-final2-menu-dark.png`；OCR 设置浅色/深色证据为 `/private/tmp/marla-task041-final2-ocr-settings-light.png` 与 `/private/tmp/marla-task041-final2-ocr-settings-dark.png`。菜单明确并列“截图翻译” `⌃⇧S` 和“原位翻译” `⌃⇧I`；设置明确原位翻译始终使用 GLM-OCR，而普通截图翻译继续显示附近结果卡。
- 实验性开关验证：`MarlaSettingsStore` 的 `inPlaceTranslationEnabled.v1` 默认值为 `false` 且可恢复；设置侧栏显示“实验室”及“原位翻译”开关。关闭时菜单和快捷键设置隐藏独立入口，`.inPlace` 不注册但保留用户偏好，直接触发被拒绝；重新开启恢复入口和快捷键，关闭活动实验会话会取消请求并关闭 overlay。普通“截图翻译”入口与行为未改变。
- 混合质量布局由自动化验证：一个完整返回但无坐标的 block 会保留冻结原图，其它可靠 block 仍继续排版；当前确定性完成态 fixture 覆盖 3 个真实粒度源 block，其中整表在 renderer 内派生 15 个 cell，但完成态仍按 1 个 table source block 统计。
- 项目所有者提供的 1640x838 真实表格截图经本机 Vision 临时诊断得到 22 个文字框，并完整经过生产 `InPlaceOverlayLayoutBuilder` 与 `ScreenshotBackgroundRestorer`；输出 `/private/tmp/marla-task041-user-screenshot-restored-structure.png` 已目视确认旧英文、inline-code 空壳和块状白框消失，三列表格横竖线及交替行底色连续。该诊断的译文是临时人工映射，几何来自 Vision，只证明真实截图像素和生产修复管线，不是 GLM-OCR 或翻译 Provider 的真实网络证据。
- `swiftui-design-skill` 对独立功能的菜单、OCR 设置与覆盖层做最终五维复审，Philosophy / Visual Hierarchy / Craft Quality / Functionality / Originality 为 8/9/9/9/8；全部高于 7 分门槛。实现使用非激活 `NSPanel`、冻结截图背景、连续背景修复位图、单一 AppKit 自绘文字表面、SF Symbol 关闭按钮、VoiceOver block 元素和现有已测试的 session-scoped Escape monitor。
- 这些 fixture 图片只含合成内容，是窗口、几何、遮罩、排版与外观证据；项目所有者提供的旧完成态截图才是本轮真实网络已到达中文结果的证据。真实 Key 仍只能由项目所有者在 App SecureField 中自行输入，`RV-005` 保持 In Progress，等待最新 renderer 的真实复测。

### RV-002 关闭边界

项目所有者的结论关闭真实裁剪、冻结画面、取消路径、代表性显示器布局与 TCC 持久性验证。记录没有补写未提供的显示器型号、排列参数或用户截图。TASK-022 的日/韩/中/英固定开发 App OCR 与语言路由证据是独立范围，不由 RV-002 自动扩写。

### RV-003 性能与内存基线

- 预算：UI 壳层 P95 约 150ms 内；Rust 回调到 Swift 可见 delta P95 低于 50ms；空闲低于 150MB、常规低于 300MB、Vision 期间低于 500MB，任何验收场景低于 1GB。
- 2026-08-18 在 Apple M4、macOS 26.6.1 的固定签名 `artifacts/Marla_dev.app` 上完成 30 组本地样本。每组使用独立 Release 进程；入口到面板完成布局、显示提交且可见的 P50/P95/max 为 131.869/145.947/149.332ms；Rust callback 解码后到对应 `.streaming` 会话完成主线程布局与显示提交的 P50/P95/max 为 35.068/43.957/44.074ms。
- delta 样本只连接 `127.0.0.1` SSE fixture，不包含外部网络 TTFT、完整响应时间或吞吐。临时证据 `/private/tmp/marla-rv003-latency.jsonl` 共 60 行，只含 schema、metric 与纳秒时长，不含凭据或内容。
- RSS：空闲约 126.1 MiB；常规 Markdown 完成态约 128.9 MiB；真实 ScreenCaptureKit 全显示器冻结/框选约 325.3 MiB；沙盒外 2400×1600 Vision accurate OCR 约 147.3 MiB。冻结/框选与 Vision 分开测量，没有把未发生的同时峰值伪写为实测组合。
- “动画期间主观流畅”和“关闭会话后无持续增长”没有被预算结果替代；它们可由未来相关 Task 或发布准备按需复验，但不是当前 RV。

### RV-004 关闭边界

项目所有者自行输入已有 Key 后，“保存并测试”与同一已保存 profile 的一次真实翻译均成功。记录不包含 Key、endpoint、Header、翻译内容或 Provider 账号；TASK-026 保持 Done。

## 工作规则

1. 当前待验证表只列没有完成的项目；完成后移动到“已完成验证证据”，不得继续表现为待办。
2. 验证发现的可复现代码缺陷，创建或启动独立 `TASK-xxx`，不把修复混入 RV。
3. 新产品能力先进入 `backlog/IDEAS.md`，经项目所有者确认后进入 `backlog/BACKLOG.md`。
