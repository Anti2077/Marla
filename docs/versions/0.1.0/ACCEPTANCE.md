# Marla 0.1.0 验收清单 / Acceptance Checklist

状态 / Status: Verification in progress — Alpha not yet accepted

适用产物 / Artifact: `artifacts/Marla_dev.app`

> `[ ]` 表示未验证，`[x]` 只允许在当前代码和真实产物上取得证据后填写。中文为规范文本，英文为同步镜像。
>
> `[ ]` means unverified. `[x]` is allowed only with evidence from current code and a real artifact. Chinese is normative; English is its synchronized mirror.

## 1. 自动化门禁 / Automated Gates

### 中文

- [x] `cargo fmt --all --check` 通过。
- [x] Rust workspace 全部测试通过，包含 JSON、FFI、SSE、超时、取消和 panic 隔离。
- [x] Swift build 和全部测试通过，包含桥接、状态隔离、快捷键和输入归一化。
- [x] 模拟 SSE 覆盖单帧、多帧、跨 UTF-8 分片、角色空帧、`[DONE]`、非法 JSON 和中途断线。
- [x] `git diff --check` 和源文件尾随空格检查通过。
- [x] Release 配置链接 Cargo release 静态库，不含 debug Rust 产物。

### English

- [x] `cargo fmt --all --check` passes.
- [x] All Rust workspace tests pass, including JSON, FFI, SSE, timeout, cancellation, and panic isolation.
- [x] Swift build and all tests pass, including bridge, stale-state isolation, shortcuts, and input normalization.
- [x] Mock SSE covers single frame, multiple frames, split UTF-8, empty role frame, `[DONE]`, invalid JSON, and interrupted stream.
- [x] `git diff --check` and source trailing-whitespace checks pass.
- [x] Release links the Cargo release static library and contains no debug Rust artifact.

## 2. 划词翻译 / Selection Translation

### 中文

- [ ] `⌃⌥D` 在 Terminal、Safari、代码编辑器和 TextEdit 中触发。
- [ ] 成功读取选中文字，原文不被修改，剪贴板不被覆盖。
- [ ] 坐标可用时卡片靠近选区且完全位于可见工作区。
- [ ] 坐标不可用时卡片回退到触发时指针附近。
- [ ] 无选区时显示可操作提示，不发送翻译请求。
- [ ] 卡片出现不抢走源应用焦点；点击控件后可正常交互。

### English

- [ ] `⌃⌥D` triggers in Terminal, Safari, a code editor, and TextEdit.
- [ ] Selected text is read, source is unchanged, and clipboard is preserved.
- [ ] With geometry, the card anchors near selection and remains in the visible work area.
- [ ] Without geometry, the card falls back to trigger-time pointer position.
- [ ] No selection shows an actionable message and sends no translation request.
- [ ] Presentation does not steal source focus; clicking controls enables normal interaction.

## 3. 截图翻译 / Screenshot Translation

### 中文

- [ ] `⌃⌥S` 在单显示器、Retina 和多显示器环境进入正确框选层。
- [ ] 跨屏坐标、负坐标原点和不同缩放比例下裁剪区域正确。
- [x] 真实 `Esc` 在普通框选和设置已打开的焦点场景中取消，且不产生 OCR、网络请求或文件。
- [ ] 右键和无效区域取消，且不产生 OCR、网络请求或文件。
- [ ] Vision 对短句、多行和长截图文字输出稳定阅读顺序。
- [ ] 空 OCR 显示重新框选操作，不发送空请求。
- [ ] 翻译失败后仍保留 Vision 源文本。
- [ ] 网络抓包或 Provider 模拟证明请求只含文字，不含图片字节或完整屏幕。

### English

- [ ] `⌃⌥S` enters the correct selection layer on single-display, Retina, and multi-display setups.
- [ ] Crop is correct with cross-screen coordinates, negative origins, and mixed scale factors.
- [x] A real `Esc` cancels both ordinary selection and the open-Settings focus scenario, with no OCR, network request, or file.
- [ ] Right-click and invalid regions cancel with no OCR, network request, or file.
- [ ] Vision produces stable reading order for short, multiline, and long captured text.
- [ ] Empty OCR offers reselect and sends no empty request.
- [ ] Translation failure preserves Vision source text.
- [ ] Network capture or provider mock proves requests contain text only, with no image bytes or full screen.

## 4. 快速输入与语言 / Quick Input and Language

### 中文

- [ ] `⌃⌥Space` 在当前指针屏幕打开并聚焦输入区。
- [ ] 中文 IME、英文、多行、粘贴和 `⌘Return` 提交正常，原剪贴板保持不变。
- [ ] 空白内容不可提交，`Esc` 可关闭。
- [ ] 中文在自动模式译成英文；英文及其他语言译成简体中文。
- [ ] 手动选择简体中文或 English 后严格使用目标语言。
- [ ] 切换目标取消旧请求、复用源文本，截图入口不重复 OCR。

### English

- [ ] `⌃⌥Space` opens on the pointer's display and focuses the editor.
- [ ] Chinese IME, English, multiline, paste, and `⌘Return` submission work; clipboard remains unchanged.
- [ ] Whitespace cannot submit and `Esc` closes.
- [ ] Chinese auto-translates to English; English and other languages auto-translate to Simplified Chinese.
- [ ] Explicit Simplified Chinese or English target is obeyed.
- [ ] Target change cancels old request and reuses source; screenshot entry does not rerun OCR.

## 5. 翻译、错误与取消 / Translation, Errors, and Cancellation

### 中文

- [x] Base URL 模式追加 `/chat/completions`，完整 URL 模式原样使用地址；两种模式拒绝 query/fragment，并由测试连接和真实翻译共用。
- [x] 模型获取由 Rust 根据 URL 模式推导 `/models`，携带当前配置 Key，返回排序去重列表；编辑器可展开并选择模型。
- [ ] 获取模型和测试连接都优先使用当前非空 Key 草稿，草稿为空时回退 Keychain；相关字段变化会清除旧测试结果。
- [ ] 只有启用配置可出现在结果卡选择器并发起请求；禁用默认、全部禁用、重新启用和“设为默认”保持默认值不变量。
- [ ] 模型和空/非空 Key 都按协议构造请求；Key 只在非空时加入 Header。
- [ ] API Key 存在 Keychain，不出现在 UserDefaults、日志、错误或诊断输出。
- [ ] 首字前显示等待状态，delta 增量显示，完成后内容与 Provider 一致。
- [ ] 401/403、429、网络、首字超时、总超时、非法响应和断流显示对应恢复动作。
- [ ] 取消是幂等的；关闭、重试和语言切换后迟到事件不能更新新卡片。
- [ ] 部分译文在断流后保留，重试生成新 request ID。
- [ ] 连接测试不会写入历史或泄露 Key。

### English

- [x] Base URL mode appends `/chat/completions`; Complete URL mode uses the address unchanged. Both reject query/fragment and are shared by connection testing and real translation.
- [x] Rust derives `/models` from the URL mode, uses the current profile key, and returns sorted unique IDs; the editor expands and selects a model.
- [ ] Model discovery and connection testing both prefer the current non-empty key draft and fall back to Keychain only when the draft is empty; related field changes clear stale test results.
- [ ] Only enabled profiles appear in the result-card picker and may start requests; disabling the default, disabling all, re-enabling, and Set as Default preserve the default invariant.
- [ ] Model and empty/non-empty key build the specified request; Header is added only for non-empty key.
- [ ] API Key lives in Keychain and never appears in UserDefaults, logs, errors, or diagnostics.
- [ ] Waiting appears before first token, deltas render incrementally, and completion matches provider output.
- [ ] 401/403, 429, network, first-token timeout, total timeout, invalid response, and stream interruption show matching recovery actions.
- [ ] Cancellation is idempotent; late events after close, retry, or language change cannot update the new card.
- [ ] Partial translation remains after interruption and Retry creates a new request ID.
- [ ] Connection test persists no history and leaks no key.

## 6. 结果卡片功能 / Result Card Features

### 中文

- [ ] 原文对照展开和折叠不重新翻译，内容顺序稳定。
- [ ] 复制只复制当前译文并提供克制反馈。
- [ ] 系统朗读可开始、停止和切换新译文，不打包额外模型。
- [ ] 固定卡片不会因外部点击关闭；取消固定后恢复临时行为。
- [ ] `Esc` 和外部点击关闭临时卡片并取消请求。
- [ ] 长文本在卡片内部滚动，卡片锚点不因 delta 跳动。
- [ ] 所有图标有 Tooltip、无障碍标签和键盘焦点。
- [x] 三项准备完成后菜单隐藏权限状态条，并展示最多三条只在内存保留的最近完成翻译。
- [x] 最近翻译排除失败、取消和空结果；点击恢复完成态卡片且不发起新请求。

### English

- [ ] Expanding/collapsing comparison does not retranslate and preserves content order.
- [ ] Copy copies current translation only and gives restrained feedback.
- [ ] System speech starts, stops, and switches to new translation with no bundled model.
- [ ] Pinned card survives outside clicks; unpin restores transient behavior.
- [ ] `Esc` and outside click close transient card and cancel the request.
- [ ] Long text scrolls inside the card and streaming does not move the anchor.
- [ ] Every icon has tooltip, accessibility label, and keyboard focus.
- [x] Once all three setup items are ready, the menu hides permission status and shows up to three recent completed translations retained in memory only.
- [x] Recents exclude failed, cancelled, and empty results; selecting one restores a completed card without a new request.

## 7. 快捷键与 Force Touch / Shortcuts and Force Touch

### 中文

- [ ] 三个默认快捷键正确注册、可修改、可恢复默认值。
- [ ] Marla 内部重复组合键被阻止，并解释冲突。
- [ ] Force Touch 默认关闭，设置中明确标记“实验”。
- [ ] Force Touch 只使用公开 API，只复用划词意图；不可用时键盘入口不受影响。
- [ ] Force Touch 验证失败不会阻塞 0.1.0 发布。

### English

- [ ] Three default shortcuts register correctly, can be changed, and restore defaults.
- [ ] Duplicate Marla combinations are rejected with a conflict explanation.
- [ ] Force Touch is off by default and clearly labeled Experimental.
- [ ] Force Touch uses public API only and reuses selection intent; keyboard remains unaffected when unavailable.
- [ ] Failed Force Touch validation does not block 0.1.0 release.

## 8. 视觉与交互 / Visual and Interaction Quality

### 中文

- [x] 使用真实 `.app` 截图验证浅色和深色的主要状态。
- [x] Reduce Motion 下没有位置弹簧、呼吸缩放或角点位移。
- [x] 短句、长段、多行、加载、流式、空、错误和固定状态均有真实场景截图检查。
- [x] 无紫蓝渐变、霓虹、Emoji 图标、AI SVG、随机间距和模板左边框卡片。
- [x] `swiftui-design-skill` 五维审查每项至少 7/10，并记录问题与复评结果。
- [x] 流式游标、截图角点和语言路由胶囊是克制的状态细节，不遮挡正文。
- [x] 菜单、设置、结果卡、快速输入和截图框选提示使用 macOS 26 Liquid Glass，并为 macOS 14–25 提供单层材质回退。
- [x] 菜单和设置中的截图翻译使用目标系统可用且可见的 SF Symbol。
- [x] API 编辑器首行获得焦点时，系统 Focus Ring 四边完整，不被滚动视口顶部裁切。
- [ ] API 列表使用启用 Switch，菜单仅含设为默认/删除；原生拖拽图透明不可见，最右侧三横杠抓起后由固定 580×76pt 独立浮层绘制完整配置行，向左展开并保持原始抓取点且全程不缩放；列表原行变为等高空槽，空槽经过其它配置时以短促过渡实时移动和让位，松手后内容以短促动画恢复到空槽，且设置窗口本身不移动；编辑器底部仅含取消/保存，测试结果在表单内同行显示。

### English

- [x] Real `.app` screenshots validate the primary states exercised in light and dark appearance.
- [x] Reduce Motion removes positional springs, breathing scale, and corner movement.
- [x] Short, long, multiline, loading, streaming, empty, error, and pinned states have real scenario screenshots for inspection.
- [x] No purple-blue gradient, neon, emoji icon, AI SVG, random spacing, or templated left-rail card.
- [x] `swiftui-design-skill` five-dimension review scores at least 7/10 in every dimension, with issues and rescore recorded.
- [x] Streaming caret, screenshot corners, and language-route capsule remain restrained state details and never obscure content.
- [x] The menu, Settings, result card, quick input, and screenshot-selection labels use macOS 26 Liquid Glass with a single material fallback on macOS 14–25.
- [x] Screenshot translation uses an available and visible SF Symbol in both the menu and Settings.
- [x] When the API editor's first row is focused, all four sides of the system Focus Ring remain visible instead of clipping at the scroll viewport's top edge.
- [ ] The API list uses an enabled switch and a menu containing only Set as Default/Delete. The native drag image is transparent and invisible; picking up the trailing handle renders the complete row in an independent fixed 580×76pt panel that expands leftward, preserves the exact grab point, and never scales. The source becomes a full-height empty slot that moves through the list with short animated displacement, and release restores the row content into that slot without moving the Settings window. The editor footer contains only Cancel/Save and shows test results inline in the form.

## 9. 性能与内存 / Performance and Memory

### 中文

- [ ] 本地入口触发到 UI 壳层可见的 P95 不超过约 150ms。
- [ ] 网络 TTFT、完整响应时间、吞吐和本地 UI 开销分开记录，不把网络时间算作 UI 渲染延迟。
- [ ] Rust 回调到 Swift 可见 delta 的本地处理 P95 低于 50ms。
- [ ] OCR 和网络不阻塞主线程，动画期间保持流畅交互。
- [ ] 空闲常驻内存低于 150MB；常规翻译低于 300MB；Vision 活跃时低于 500MB；任何验收场景不得达到 1GB。
- [ ] 关闭会话后截图和请求缓冲区释放，无持续增长。

### English

- [ ] P95 from local entry trigger to visible UI shell is approximately 150ms or less.
- [ ] Network TTFT, total response, throughput, and local UI overhead are recorded separately; network time is not labeled UI render latency.
- [ ] P95 from Rust callback to visible Swift delta is below 50ms locally.
- [ ] OCR and network do not block the main thread, and interaction remains smooth during animation.
- [ ] Idle resident memory is below 150MB; normal translation below 300MB; active Vision below 500MB; no acceptance scenario reaches 1GB.
- [ ] Closing sessions releases screenshot and request buffers with no sustained growth.

## 10. 隐私、打包与交付 / Privacy, Packaging, and Delivery

### 中文

- [ ] 没有历史数据库、截图文件、原文文件或译文文件。
- [x] 最近三条翻译只存在于有界内存数组，退出清空，不写入 UserDefaults、数据库或文件。
- [ ] 不采集或发送附近文字、窗口标题、应用分类、分析事件或崩溃正文。
- [ ] 设置准确说明 Vision 本地 OCR 和文字云端翻译的区别。
- [x] `.app` 内部版本为 0.1.0、Bundle ID 为 `com.marla.app`、架构为 arm64、最低系统为 macOS 14。
- [x] 产物复用固定 App 的稳定本地签名身份，签名、可执行文件和 designated requirement 通过检查。
- [x] 默认产物严格为 `artifacts/Marla_dev.app`，成功验证后覆盖上一份测试包且不新增时间戳 App。
- [x] 未把 DMG、公证、自动更新或公开发布误报为完成。

### English

- [ ] No history database, screenshot file, source file, or translation file exists.
- [x] The three recent translations exist only in a bounded in-memory array, clear on termination, and never enter UserDefaults, a database, or a file.
- [ ] Nearby text, window titles, app classification, analytics, and crash content are neither collected nor sent.
- [ ] Settings accurately distinguish local Vision OCR from cloud text translation.
- [x] `.app` internal version is 0.1.0, Bundle ID is `com.marla.app`, architecture is arm64, and minimum system is macOS 14.
- [x] Artifact reuses the fixed App's stable local signing identity and passes signature, executable, and designated-requirement checks.
- [x] The default artifact is exactly `artifacts/Marla_dev.app`; it replaces the previous test App only after successful verification and creates no timestamped App.
- [x] DMG, notarization, auto-update, and public release are not falsely reported complete.

自动化与视觉证据：`./scripts/check.sh` 在 2026-08-06 最终源码上通过（Rust 16 项、Swift 18 项、Xcode Debug、格式/空白/diff 检查）；`scripts/build-test-app.sh` 生成并验证了 `Marla_test_202608060135.app`。Cargo 固定 macOS 14 deployment target 后，Rust/native 依赖不再出现更高系统目标的链接警告；Release 构建设置和最终链接命令只引用 `target/release`。真实 App 场景 PNG 位于 `artifacts/ui-review/`。macOS 26 使用 Liquid Glass，macOS 14–25 使用材质回退；自动化离屏渲染显式使用回退以避免系统玻璃无法栅格化。包含 Qwen-MT、扩展 Web Text Marker 遍历和截图坐标修复的固定路径 `Marla_dev.app` 已使用持久本地身份重新签名并通过完整包验证。真实 DashScope `qwen-mt-turbo` 翻译返回“你好”，但 Mac 在最新 VSCodium 复测前锁定，真实截图裁剪也仍待验证，因此相关条目保持未勾选。

Automation and visual evidence: `./scripts/check.sh` passed on the final 2026-08-06 source (16 Rust tests, 18 Swift tests, Xcode Debug, format/whitespace/diff checks); `scripts/build-test-app.sh` produced and verified `Marla_test_202608060135.app`. After Cargo fixed the macOS 14 deployment target, Rust/native dependencies no longer emit newer-target linker warnings; Release build settings and the final link command reference only `target/release`. Real-app scenario PNGs are under `artifacts/ui-review/`. macOS 26 uses Liquid Glass and macOS 14–25 uses the material fallback; explicit off-screen automation selects the fallback because the system glass cannot be reliably rasterized there. The fixed-path `Marla_dev.app`, including Qwen-MT, expanded Web Text Marker traversal, and screenshot-coordinate fixes, was re-signed with the persistent local identity and passed complete bundle verification. A real DashScope `qwen-mt-turbo` translation returned “你好”, but the Mac locked before the latest VSCodium retest and a real screenshot crop is still pending, so their acceptance items stay unchecked.

TASK-003 自动化与视觉证据：`./scripts/check.sh` 通过（Rust 16 项、Swift 22 项、Swift/Xcode Debug 构建、格式/空白/diff 检查）；Swift 测试新增最近翻译容量/去重、失败排除、无网络恢复和截图 SF Symbol 覆盖；`Marla_test_202608061928.app` 通过 Release 包验证。菜单浅色/深色、设置、快速输入、对照卡和截图框选 PNG 位于 `artifacts/ui-review/task-003/`。离屏截图显式验证材质回退；macOS 26 生产代码路径编译并调用 SwiftUI `glassEffect`。`computer-use` 无法枚举这个无主窗口的 LSUIElement 菜单栏 App，因此未把该工具的超时误报成视觉证据。

TASK-003 automation and visual evidence: `./scripts/check.sh` passed (16 Rust tests, 22 Swift tests, Swift/Xcode Debug builds, formatting/whitespace/diff checks); Swift tests add coverage for recent capacity/deduplication, failed-result exclusion, restoration without networking, and screenshot SF Symbol availability; `Marla_test_202608061928.app` passed Release bundle verification. Menu light/dark, Settings, quick input, comparison-card, and screenshot-selection PNGs are under `artifacts/ui-review/task-003/`. Off-screen captures explicitly verify the material fallback; the macOS 26 production path compiles and invokes SwiftUI `glassEffect`. `computer-use` could not enumerate this no-main-window LSUIElement menu-bar app, so its timeout is not misreported as visual evidence.

TASK-004 自动化与产物证据：`zsh -n scripts/build-test-app.sh`、ad-hoc 拒绝门禁、自定义已有路径覆盖保护和 `./scripts/check.sh` 通过（Rust 16 项、Swift 22 项、Swift/Xcode Debug 构建、格式/空白/diff 检查）。无参数 `./scripts/build-test-app.sh` 成功覆盖并验证 `artifacts/Marla_dev.app`；Bundle ID 为 `com.marla.app`、版本 0.1.0、最低 macOS 14、arm64，签名 Authority 为 `API Usage Monitor Dev`。覆盖前后的 designated requirement 均绑定同一证书，已有时间戳 App 数量保持 17，且没有遗留 staging 目录。TCC 重启持久性仍属于 BL-002 的真实验收。

TASK-004 automation and artifact evidence: `zsh -n scripts/build-test-app.sh`, the ad-hoc rejection gate, the existing-custom-path overwrite guard, and `./scripts/check.sh` passed (16 Rust tests, 22 Swift tests, Swift/Xcode Debug builds, formatting/whitespace/diff checks). A no-argument `./scripts/build-test-app.sh` run successfully replaced and verified `artifacts/Marla_dev.app`; its Bundle ID is `com.marla.app`, version 0.1.0, minimum macOS 14, architecture arm64, and signing Authority `API Usage Monitor Dev`. The designated requirement remained bound to the same certificate before and after replacement, the existing timestamped-App count remained 17, and no staging directory remained. TCC persistence across restart remains real acceptance work under BL-002.

TASK-008 自动化与视觉证据：`./scripts/check.sh` 通过（Rust 16 项、Swift 34 项、Swift/Xcode Debug 构建、格式/空白/diff 检查）；新增测试覆盖设置全尺寸透明标题栏和连续四角、截图窗口 Key 能力、设置暂停/非 Key 恢复，以及 Escape `NSEvent` 的取消路径。固定 `artifacts/Marla_dev.app` 重新构建并保持 Bundle ID `com.marla.app`、arm64、签名 Authority `API Usage Monitor Dev` 和既有 designated requirement。浅色一体化设置、深色快捷键与“设置已打开后进入截图”证据位于 `artifacts/ui-review/task-008/`，五维评分为 8/8/8/8/7。由于机器上同时运行两个同路径 Marla 进程，Computer Use 无法把一次物理 Escape 唯一归属到验收进程；Agent 只停止了自己启动的进程，没有终止项目所有者原有实例。

TASK-008 automation and visual evidence: `./scripts/check.sh` passed (16 Rust tests, 34 Swift tests, Swift/Xcode Debug builds, formatting/whitespace/diff checks). New tests cover the transparent full-size Settings title bar and continuous four-corner surface, screenshot-window key eligibility, Settings suspension/non-key restoration, and cancellation through an Escape `NSEvent`. The fixed `artifacts/Marla_dev.app` was rebuilt while preserving Bundle ID `com.marla.app`, arm64, signing Authority `API Usage Monitor Dev`, and the existing designated requirement. Unified Settings light, Shortcuts dark, and “enter screenshot while Settings is open” evidence is under `artifacts/ui-review/task-008/`, with five-dimension scores of 8/8/8/8/7. Because two same-path Marla processes were running, Computer Use could not uniquely attribute one physical Escape press to the acceptance process. The Agent stopped only the process it launched and did not terminate the project owner's existing instance.

TASK-009 真实键盘与自动化证据：截图取消已提升为会话级本地/全局按键监听，原有 View 路径继续保留；结束时立即移除监听，迟到事件不能取消后续会话。`./scripts/check.sh` 通过（Rust 16 项、Swift 37 项、Swift/Xcode Debug 构建、格式/空白/diff 检查）。关闭固定路径的全部旧实例后，Computer Use 在唯一运行的 Release `artifacts/Marla_dev.app` 中发送真实 `Escape`，普通截图场景和“设置已打开后进入截图”场景的覆盖层均消失，未出现 OCR/翻译结果卡。固定 App 再次覆盖构建并保持 Bundle ID `com.marla.app`、arm64、Authority `API Usage Monitor Dev` 和既有 designated requirement。验收前截图与记录位于 `artifacts/ui-review/task-009/`；保存最后一张桌面截图时 Mac 自动锁定，但锁定前两次退出结果均已通过 Computer Use 的桌面状态重新读取确认。

TASK-009 real-keyboard and automation evidence: screenshot cancellation now uses session-scoped local/global key monitors while retaining the original view route; monitors are removed immediately on finish, and a late event cannot cancel a later session. `./scripts/check.sh` passed (16 Rust tests, 37 Swift tests, Swift/Xcode Debug builds, formatting/whitespace/diff checks). After every old fixed-path process was stopped, Computer Use sent a real `Escape` to the sole running Release `artifacts/Marla_dev.app`. The overlay disappeared in both the ordinary screenshot scenario and the open-Settings screenshot scenario, with no OCR/translation result card. The fixed App was rebuilt again while preserving Bundle ID `com.marla.app`, arm64, Authority `API Usage Monitor Dev`, and the existing designated requirement. The pre-cancellation capture and verification record are under `artifacts/ui-review/task-009/`; the Mac auto-locked while the final desktop capture was being saved, after Computer Use had already re-read and confirmed both successful exits.

TASK-010 自动化、真实 API 与视觉证据：每个 profile 新增显式 Base URL/完整 URL 模式；URL 行左侧使用 `Base [滑块] 完整`，模型字段移动到最下面，并通过刷新图标调用 Rust `/models` 请求后展开选择列表。C ABI 升级到 v2；旧配置仍迁移为 Base URL，Keychain account 和 profile UUID 不变。`./scripts/check.sh` 通过（Rust 17 项、Swift 41 项、Swift/Xcode Debug 构建、格式/空白/diff 检查）。项目所有者提供的完整端点使用 `gpt-5.6-luna` 返回 HTTP 200 `text/event-stream`、“你好”、`finish_reason: stop` 和 `[DONE]`；其 `/v1/models` 返回 20 个模型且包含 `gpt-5.6-luna`，凭据未打印或持久化。固定 App 重新构建并保持 Bundle ID `com.marla.app`、arm64、Authority `API Usage Monitor Dev` 和既有 designated requirement。浅色/深色行内滑块与展开模型列表证据位于 `artifacts/ui-review/task-010/`，五维评分为 8/8/8/8/7。

TASK-010 automation, real-API, and visual evidence: every profile now has explicit Base URL/Complete URL semantics. The URL row uses `Base [switch] Complete`; Model Name is last, and its refresh icon invokes Rust `/models` discovery before revealing a selectable list. The C ABI is v2; legacy profiles still migrate to Base URL without changing Keychain accounts or profile UUIDs. `./scripts/check.sh` passed (17 Rust tests, 41 Swift tests, Swift/Xcode Debug builds, formatting/whitespace/diff checks). The project-owner-supplied Complete URL returned HTTP 200 `text/event-stream` with `gpt-5.6-luna`, “你好”, `finish_reason: stop`, and `[DONE]`. Its `/v1/models` endpoint returned 20 models including `gpt-5.6-luna`; the credential was neither printed nor persisted. The fixed App was rebuilt while preserving Bundle ID `com.marla.app`, arm64, Authority `API Usage Monitor Dev`, and the existing designated requirement. Light/dark inline-switch and expanded-model-list evidence is under `artifacts/ui-review/task-010/`, with five-dimension scores of 8/8/8/8/7.

TASK-011 自动化与视觉证据：API 编辑器滚动内容顶部增加 8pt Focus Ring 安全边距，并提供只由 UI 验收环境变量启用的确定性首行聚焦。`./scripts/check.sh` 通过（Rust 17 项、Swift 41 项、Swift/Xcode Debug 构建、格式/空白/diff 检查）。固定 `artifacts/Marla_dev.app` 重新构建并保持 Bundle ID `com.marla.app`、arm64、Authority `API Usage Monitor Dev` 和既有 designated requirement。前台浅色/深色 Release 窗口按 Core Graphics Window ID 捕获，蓝色 Focus Ring 四边完整；证据位于 `artifacts/ui-review/task-011/`，五维评分为 8/8/9/8/7。

TASK-011 automation and visual evidence: the API editor now gives its scroll content an 8pt top safety inset for the Focus Ring and exposes deterministic first-row focus only through the UI-acceptance environment. `./scripts/check.sh` passed (17 Rust tests, 41 Swift tests, Swift/Xcode Debug builds, formatting/whitespace/diff checks). The fixed `artifacts/Marla_dev.app` was rebuilt while preserving Bundle ID `com.marla.app`, arm64, Authority `API Usage Monitor Dev`, and the existing designated requirement. Frontmost light/dark Release windows captured by verified Core Graphics Window ID show all four sides of the blue Focus Ring; evidence is under `artifacts/ui-review/task-011/`, with five-dimension scores of 8/8/9/8/7.

## 11. 发布判定 / Release Decision

### 中文

0.1.0 只有在所有非 Force Touch 条目通过、没有 P0 崩溃/数据泄漏/焦点破坏问题、五维视觉审查全部至少 7/10、内存硬上限满足，并交付经过检查的固定路径 `.app` 后才能标记完成。任何未验证项必须留为 `[ ]` 并在 `STATUS.md` 中列为阻塞或风险。

### English

0.1.0 may be marked complete only when every non-Force-Touch item passes, no P0 crash/data leak/focus-destruction issue remains, every visual dimension scores at least 7/10, memory hard limit passes, and a verified fixed-path `.app` is delivered. Any unverified item remains `[ ]` and is recorded as a blocker or risk in `STATUS.md`.
