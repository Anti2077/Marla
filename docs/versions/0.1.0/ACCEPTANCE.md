# Marla 0.1.0 验收清单 / Acceptance Checklist

状态 / Status: Not yet accepted

适用产物 / Artifact: `Marla_test_yyyyMMddHHmm.app`

> `[ ]` 表示未验证，`[x]` 只允许在当前代码和真实产物上取得证据后填写。中文为规范文本，英文为同步镜像。
>
> `[ ]` means unverified. `[x]` is allowed only with evidence from current code and a real artifact. Chinese is normative; English is its synchronized mirror.

## 1. 自动化门禁 / Automated Gates

### 中文

- [ ] `cargo fmt --all --check` 通过。
- [ ] Rust workspace 全部测试通过，包含 JSON、FFI、SSE、超时、取消和 panic 隔离。
- [ ] Swift build 和全部测试通过，包含桥接、状态隔离、快捷键和输入归一化。
- [ ] 模拟 SSE 覆盖单帧、多帧、跨 UTF-8 分片、角色空帧、`[DONE]`、非法 JSON 和中途断线。
- [ ] `git diff --check` 和源文件尾随空格检查通过。
- [ ] Release 配置链接 Cargo release 静态库，不含 debug Rust 产物。

### English

- [ ] `cargo fmt --all --check` passes.
- [ ] All Rust workspace tests pass, including JSON, FFI, SSE, timeout, cancellation, and panic isolation.
- [ ] Swift build and all tests pass, including bridge, stale-state isolation, shortcuts, and input normalization.
- [ ] Mock SSE covers single frame, multiple frames, split UTF-8, empty role frame, `[DONE]`, invalid JSON, and interrupted stream.
- [ ] `git diff --check` and source trailing-whitespace checks pass.
- [ ] Release links the Cargo release static library and contains no debug Rust artifact.

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
- [ ] `Esc`、右键和无效区域取消，且不产生 OCR、网络请求或文件。
- [ ] Vision 对短句、多行和长截图文字输出稳定阅读顺序。
- [ ] 空 OCR 显示重新框选操作，不发送空请求。
- [ ] 翻译失败后仍保留 Vision 源文本。
- [ ] 网络抓包或 Provider 模拟证明请求只含文字，不含图片字节或完整屏幕。

### English

- [ ] `⌃⌥S` enters the correct selection layer on single-display, Retina, and multi-display setups.
- [ ] Crop is correct with cross-screen coordinates, negative origins, and mixed scale factors.
- [ ] `Esc`, right-click, and invalid regions cancel with no OCR, network request, or file.
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

- [ ] Base URL、模型和空/非空 Key 都按协议构造请求；Key 只在非空时加入 Header。
- [ ] API Key 存在 Keychain，不出现在 UserDefaults、日志、错误或诊断输出。
- [ ] 首字前显示等待状态，delta 增量显示，完成后内容与 Provider 一致。
- [ ] 401/403、429、网络、首字超时、总超时、非法响应和断流显示对应恢复动作。
- [ ] 取消是幂等的；关闭、重试和语言切换后迟到事件不能更新新卡片。
- [ ] 部分译文在断流后保留，重试生成新 request ID。
- [ ] 连接测试不会写入历史或泄露 Key。

### English

- [ ] Base URL, model, and empty/non-empty key build the specified request; Header is added only for non-empty key.
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

### English

- [ ] Expanding/collapsing comparison does not retranslate and preserves content order.
- [ ] Copy copies current translation only and gives restrained feedback.
- [ ] System speech starts, stops, and switches to new translation with no bundled model.
- [ ] Pinned card survives outside clicks; unpin restores transient behavior.
- [ ] `Esc` and outside click close transient card and cancel the request.
- [ ] Long text scrolls inside the card and streaming does not move the anchor.
- [ ] Every icon has tooltip, accessibility label, and keyboard focus.

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

- [ ] 使用真实 `.app` 截图验证浅色和深色的所有主要状态。
- [ ] Reduce Motion 下没有位置弹簧、呼吸缩放或角点位移。
- [ ] 短句、长段、多行、加载、流式、空、错误和固定状态无裁切或布局跳动。
- [ ] 无紫蓝渐变、霓虹、Emoji 图标、AI SVG、随机间距和模板左边框卡片。
- [ ] `swiftui-design-skill` 五维审查每项至少 7/10，并记录问题与复评结果。
- [ ] 流式游标、截图角点和语言路由胶囊是克制的状态细节，不遮挡正文。

### English

- [ ] Real `.app` screenshots validate every primary state in light and dark appearance.
- [ ] Reduce Motion removes positional springs, breathing scale, and corner movement.
- [ ] Short, long, multiline, loading, streaming, empty, error, and pinned states have no clipping or layout jump.
- [ ] No purple-blue gradient, neon, emoji icon, AI SVG, random spacing, or templated left-rail card.
- [ ] `swiftui-design-skill` five-dimension review scores at least 7/10 in every dimension, with issues and rescore recorded.
- [ ] Streaming caret, screenshot corners, and language-route capsule remain restrained state details and never obscure content.

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
- [ ] 不采集或发送附近文字、窗口标题、应用分类、分析事件或崩溃正文。
- [ ] 设置准确说明 Vision 本地 OCR 和文字云端翻译的区别。
- [ ] `.app` 内部版本为 0.1.0、Bundle ID 为 `com.marla.app`、架构为 arm64、最低系统为 macOS 14。
- [ ] 产物使用开发或临时签名，签名状态和可执行文件通过检查。
- [ ] 产物名严格为当前上海时间的 `Marla_test_yyyyMMddHHmm.app`，且不会覆盖先前测试包。
- [ ] 未把 DMG、公证、自动更新或公开发布误报为完成。

### English

- [ ] No history database, screenshot file, source file, or translation file exists.
- [ ] Nearby text, window titles, app classification, analytics, and crash content are neither collected nor sent.
- [ ] Settings accurately distinguish local Vision OCR from cloud text translation.
- [ ] `.app` internal version is 0.1.0, Bundle ID is `com.marla.app`, architecture is arm64, and minimum system is macOS 14.
- [ ] Artifact uses development or ad-hoc signing and passes signing/executable checks.
- [ ] Artifact name exactly matches current Shanghai time as `Marla_test_yyyyMMddHHmm.app` and does not overwrite prior test apps.
- [ ] DMG, notarization, auto-update, and public release are not falsely reported complete.

## 11. 发布判定 / Release Decision

### 中文

0.1.0 只有在所有非 Force Touch 条目通过、没有 P0 崩溃/数据泄漏/焦点破坏问题、五维视觉审查全部至少 7/10、内存硬上限满足，并交付经过检查的时间戳 `.app` 后才能标记完成。任何未验证项必须留为 `[ ]` 并在 `STATUS.md` 中列为阻塞或风险。

### English

0.1.0 may be marked complete only when every non-Force-Touch item passes, no P0 crash/data leak/focus-destruction issue remains, every visual dimension scores at least 7/10, memory hard limit passes, and a verified timestamped `.app` is delivered. Any unverified item remains `[ ]` and is recorded as a blocker or risk in `STATUS.md`.
