# Marla 0.1.0 产品规格 / Product Specification

状态 / Status: Active Alpha verification

版本 / Version: 0.1.0

最后更新 / Last updated: 2026-08-09

> 本文每节先给出中文规范，再给出英文镜像。发生歧义时以中文为准；两种语言必须在同一次修改中同步。
>
> Each section contains the normative Chinese text followed by its English mirror. If they differ, the Chinese text controls. Both languages must be updated in the same change.

## 1. 版本定位 / Release Positioning

### 中文

Marla 0.1.0 是供项目所有者日常试用的 macOS Alpha，而不是公开发行版。它验证一个核心命题：用户无需打开传统翻译主窗口，即可从当前工作位置发起翻译、在附近阅读结果，然后继续原来的任务。

0.1.0 必须交付可运行的 `.app`，三个入口和真实流式翻译均可用。兼容性和高级能力可以有限，但不接受只能演示、需要修改源码才能配置或使用模拟译文的技术样品。

### English

Marla 0.1.0 is a daily-usable macOS Alpha for the project owner, not a public release. It validates one central proposition: a user can request translation from the current work context, read the result nearby, and continue without opening a traditional translation window.

0.1.0 must deliver a runnable `.app` with all three entry points and real streaming translation. Compatibility and advanced capabilities may remain limited, but a demo-only build, source-code configuration, or mocked translation is not acceptable.

## 2. 用户与成功标准 / Users and Success Criteria

### 中文

首要用户是在 macOS 上频繁阅读英文网页、终端输出、代码文档、邮件和聊天内容，并主要在中文与英文之间翻译的个人用户。

版本成功需要同时满足：

- 三个入口无需打开主窗口即可调用；
- 结果表面靠近选区、截图区域或指针；
- 选择翻译和截图翻译展示时不无故抢走源应用焦点；
- 截图像素永不上传，只有 Vision 识别后的文字可以进入翻译请求；
- 用户能够理解当前状态、取消请求并从错误中恢复；
- 空闲、常规和 OCR 工作时内存均满足验收预算；
- SwiftUI 界面通过浅色、深色、Reduce Motion 和五维视觉审查。

### English

The primary user is an individual who frequently reads English web pages, terminal output, code documentation, email, and chat on macOS, mainly translating between Chinese and English.

The release succeeds only when all of the following are true:

- all three entry points work without opening a main window;
- results appear near the selection, captured region, or pointer;
- selection and screenshot results do not unnecessarily steal focus;
- screenshot pixels are never uploaded, and only Vision-recognized text may enter a translation request;
- users can understand state, cancel work, and recover from errors;
- idle, normal, and OCR memory remain within the acceptance budgets;
- the SwiftUI interface passes light, dark, Reduce Motion, and five-dimension visual review.

## 3. 入口与默认快捷键 / Entry Points and Default Shortcuts

### 中文

0.1.0 提供三个相互独立的全局入口：

| 入口 | 默认快捷键 | 行为 |
| --- | --- | --- |
| 划词翻译 | `⌃⌥D` | 读取当前前台应用的选中文本，在选区附近显示结果卡片 |
| 截图翻译 | `⌃⌥S` | 进入跨屏框选，使用 Vision 本地识别后翻译文字 |
| 快速输入 | `⌃⌥Space` | 在指针附近打开可输入和粘贴的翻译卡片 |

三个快捷键均可在设置中独立关闭或重新录制；关闭只停止对应全局监听，不隐藏菜单入口。录制时必须检测与 Marla 其他入口的内部冲突；如果系统或其他应用已经占用组合键但无法可靠检测，界面应明确提示用户实际试用并提供恢复默认值操作。

Force Touch 是默认关闭的实验入口。它只复用划词翻译意图，没有独立的后续行为，不使用私有 API，也不作为 0.1.0 发布阻塞项。

### English

0.1.0 provides three independent global entry points:

| Entry | Default shortcut | Behavior |
| --- | --- | --- |
| Selection translation | `⌃⌥D` | Read selected text from the frontmost app and present a result card near the selection |
| Screenshot translation | `⌃⌥S` | Enter cross-display region selection, recognize locally with Vision, then translate the text |
| Quick input | `⌃⌥Space` | Open a paste-and-type translation card near the pointer |

Each shortcut can be independently disabled or recorded in Settings. Disabling stops only that global listener and does not hide the menu entry. Recording must detect conflicts among Marla actions. When reliable detection of a system or third-party conflict is impossible, the UI must ask the user to test the shortcut and provide a restore-defaults action.

Force Touch is an experimental entry point that is off by default. It only reuses the selection-translation intent, has no unique downstream behavior, uses no private API, and cannot block the 0.1.0 release.

## 4. 划词翻译 / Selection Translation

### 中文

触发后，Marla 通过 Accessibility 读取选中文字和可用的选区范围。检索同时考虑前台应用、窗口和系统焦点，以及应用/system-wide 指针命中及其有界父链；标准选区与 Web Text Marker 必须在同一元素上合并评估，不能因为某一机制为空而跳过其它机制。检索必须有全局去重、元素与总耗时上限，并把 renderer/helper AX 节点绑定到触发时前台应用。0.1.0 不把译文覆盖到原文字体和位置，而是在选区的上方或下方放置非激活结果卡片；空间不足时选择可见面积更大的方向。无法得到可靠选区坐标时，卡片降级到指针附近。

没有选中文字时，不自动把任意既有剪贴板内容当成输入。默认关闭的“兼容性取词”设置允许用户明确授权 Marla 模拟一次 `⌘C`：它必须先在内存中备份 `NSPasteboard.general` 的全部可读 item、类型、顺序和数据，且快照前后 `changeCount` 保持稳定；只接受源应用仍在前台且本次 `changeCount` 变化后获得的非空文本，并在成功、空结果、异常、取消和超时路径恢复原内容。恢复后必须重新读取并比较完整快照。若恢复前检测到其他进程已再次写入，则不覆盖更新后的剪贴板并报告脱敏状态；快照不完整、恢复不一致或恢复失败时不发送翻译请求。重复划词快捷键取消当前兼容事务并先完成清理。兼容模式关闭时，Marla 只使用 Accessibility 并显示快速输入提示。

### English

On invocation, Marla reads selected text and available selection bounds through Accessibility. Retrieval considers the frontmost application, window and system focus, plus application/system-wide pointer hits and bounded ancestor paths. Standard selection and Web Text Marker mechanisms must be evaluated together on the same element; an empty result from one mechanism may not suppress another. The search uses global deduplication, element/time budgets, and binds renderer/helper AX nodes to the trigger-time frontmost application. 0.1.0 does not cover the source text in place. It places a non-activating result card above or below the selection, choosing the side with more visible space. If reliable selection geometry is unavailable, the card falls back to the pointer.

When no text is selected, Marla does not silently use arbitrary existing clipboard content. An off-by-default “Copy compatibility” setting lets the user explicitly authorize one simulated `⌘C`: Marla must first snapshot every readable item, type, order, and data representation in `NSPasteboard.general` while `changeCount` remains stable, accept non-empty text only after this trigger changes the count and while the source app remains frontmost, and restore the original contents on success, empty result, error, cancellation, and timeout. It must re-read and compare the complete restored snapshot. If another process writes again before restoration, Marla must not overwrite the newer clipboard and reports only a redacted status; incomplete, mismatched, or failed restoration sends no translation request. A repeated selection shortcut cancels the active compatibility transaction and finishes cleanup first. With compatibility disabled, Marla uses Accessibility only and shows the quick-input action.

## 5. 截图翻译 / Screenshot Translation

### 中文

截图入口显示覆盖所有活动显示器的轻量框选层。系统十字光标旁显示短生命周期像素放大镜、中心准星和指针坐标，并在显示器边缘自动换位；拖动期间展示清晰边界和尺寸反馈。`Esc`、右键或未形成有效区域时取消，不进行 OCR、翻译或持久化。`Esc` 由当前截图会话统一处理，并同时保留 View、窗口 `sendEvent`/key-equivalent/`cancelOperation`、本地/全局监听和会话级系统事件 tap 路径，不依赖某一个框选 View 保持键盘焦点；会话结束后必须移除临时按键监听。放大镜采样只存在于当前框选会话内存中。进入框选时，Marla 临时隐藏自己已打开的设置窗口；框选结束后只恢复其原有可见状态，不得让设置窗口越过框选层或抢占源应用焦点。

确认区域后只在内存中保留裁剪图像，并使用 macOS Vision `VNRecognizeTextRequest` 本地识别。0.1.0 只保留纯文本、行顺序和换行，不承诺表格、公式、代码块、Markdown 或页面布局恢复。识别出的文字进入与其他入口相同的翻译管线，截图像素不进入 Rust 网络请求，也不上传给翻译服务。

没有识别到文字时显示重新框选和关闭操作，不发送空翻译请求。

### English

The screenshot entry presents a lightweight selection layer across all active displays. A short-lived pixel loupe beside the system crosshair shows a center reticle and pointer coordinates, flipping sides near display edges. Dragging shows a clear boundary and size feedback. `Esc`, right-click, or an invalid region cancels without OCR, translation, or persistence. The active screenshot session owns `Esc` handling and retains View, window `sendEvent`/key-equivalent/`cancelOperation`, local/global monitor, and session-scoped system event-tap routes instead of relying on any one selection view to retain keyboard focus; all temporary key monitors are removed when the session finishes. Loupe sampling exists only in memory for the active selection session. When selection starts, Marla temporarily hides any open Settings window of its own. After selection, it only restores the previous visibility state; Settings may not rise above the selection layer or steal focus from the source application.

After confirmation, only the cropped image remains in memory and macOS Vision `VNRecognizeTextRequest` performs local recognition. 0.1.0 preserves plain text, line order, and line breaks only; it does not promise table, formula, code-block, Markdown, or page-layout recovery. Recognized text enters the same translation pipeline as other entries. Screenshot pixels never enter the Rust network request and are never uploaded to the translation service.

When no text is recognized, the result offers reselect and close actions and sends no empty translation request.

## 6. 快速输入 / Quick Input

### 中文

快速输入在指针所在屏幕附近打开紧凑、可激活的输入卡片并立即聚焦编辑区。它支持中文输入法、英文输入、多行文字和粘贴，不修改已有剪贴板内容。

`⌘Return` 提交翻译，`Esc` 关闭。空白输入不能提交。提交后同一卡片平滑转为结果状态，保留原文以供对照和重试。

### English

Quick input opens a compact activatable card near the pointer on the current display and immediately focuses the editor. It supports Chinese IME input, English input, multiline text, and paste without modifying existing clipboard contents.

`⌘Return` submits and `Esc` closes. Whitespace-only input cannot be submitted. After submission, the same card transitions smoothly into the result state and retains the source for comparison and retry.

## 7. 结果卡片 / Result Card

### 中文

结果卡片先稳定定位和显示骨架，再接收流式内容；文本增长不得反复改变锚点。默认显示译文，用户可以展开对照原文。卡片提供：

- 复制译文；
- 重试当前请求；
- 使用 macOS 系统语音朗读译文，不打包 TTS 模型；
- 固定或取消固定；
- 切换目标语言并重新翻译；
- 关闭或取消进行中的请求。

选择翻译和截图翻译的卡片首次出现时不激活 Marla。用户点击卡片控件时可以主动激活。临时卡片在 `Esc` 或外部点击时关闭并取消未完成请求；固定卡片不会因外部点击关闭。关闭、重试或切换语言都必须先取消旧请求，迟到事件不得覆盖新会话。

### English

The result card establishes a stable position and shell before accepting streamed content; text growth must not repeatedly move its anchor. Translation is shown by default, with source comparison available on demand. The card provides:

- copy translation;
- retry current request;
- read translation through macOS system speech, with no bundled TTS model;
- pin and unpin;
- switch target language and retranslate;
- close or cancel in-flight work.

Selection and screenshot cards do not activate Marla when first presented. Clicking card controls may intentionally activate it. `Esc` or outside click closes a transient card and cancels unfinished work; pinned cards remain open. Close, retry, and target-language changes cancel the old request first, and late events may never overwrite a newer session.

## 8. 语言规则 / Language Rules

### 中文

自动模式由翻译模型判断源语言：中文输入默认译成英文，非中文输入默认译成简体中文。模型只返回译文，不在正文中加入“检测到的语言”、解释、引号或前言。

0.1.0 的结果卡片至少提供“自动”“简体中文”“English”三个目标选项。手动目标优先于自动规则。切换目标不会重新执行 Vision OCR，只会使用已经取得的源文本发起新翻译。

提示词必须把源文本明确标记为数据而不是指令，并要求尽量保留换行、标点、专有名词、代码标识符和终端参数。

### English

In automatic mode, the translation model detects the source language: Chinese defaults to English, while non-Chinese defaults to Simplified Chinese. The model returns translation only, without detected-language labels, explanations, quotation marks, or preambles.

The 0.1.0 result card provides at least Auto, Simplified Chinese, and English target choices. An explicit target overrides the automatic rule. Changing target does not rerun Vision OCR; it starts a new translation from the already acquired source text.

The prompt must clearly delimit source text as data rather than instructions and request preservation of line breaks, punctuation, proper nouns, code identifiers, and terminal arguments when practical.

## 9. 翻译 API 与设置 / Translation API and Settings

### 中文

0.1.0 支持多个命名的 OpenAI-compatible Chat Completions 流式配置，不绑定默认厂商。每个配置包括：

- URL 模式：Base URL 或完整 URL；
- 对应地址，例如 Base URL `https://example.com/v1`，或完整 URL `https://example.com/v1/chat/completions`；
- 模型名，可手工填写或从当前配置获取可用模型；
- 可选 API Key；
- 是否启用；
- 连接测试；
- 三个快捷键开关与录制器；
- Force Touch 实验开关；
- 快捷键恢复默认值。

Base URL 模式会在规范化地址后追加 `/chat/completions`；完整 URL 模式严格使用填写地址，不追加或删除路径。两种模式都要求 HTTP(S) host，且拒绝 query 和 fragment。测试连接与真实翻译共用同一解析规则；编辑器中非空的当前 Key 草稿优先于 Keychain 已保存值，草稿为空时才回退。获取模型使用同一 Key 选择规则：Base URL 追加 `/models`；完整 URL 只在尾部为 `/chat/completions` 时替换为 `/models`，不能安全推导则显示错误。模型列表网络请求由 Rust 核心执行，不创建新的凭据副本。如果 API Key 非空，则使用 `Authorization: Bearer <key>`；空 Key 允许兼容不要求认证的本地或代理端点。每个配置的 Key 只保存在其独立 macOS Keychain account 中；URL、模式、模型名、启用状态、顺序和其它非敏感偏好保存在应用偏好。

只有启用的配置才出现在结果卡片配置选择器中并可发起请求。默认配置必须属于启用集合：禁用当前默认时选择顺序中的下一个启用配置，没有任何启用配置时默认值为空；在默认值为空时启用配置会使其成为默认；对禁用配置执行“设为默认”会同时启用它。完整性状态与启用状态相互独立。0.1.0 不支持自动 fallback、自定义 Header、厂商专属请求参数、账号系统或 Marla 代理服务。

首次启动以紧凑清单引导配置 API、辅助功能权限和屏幕录制权限。快速输入本身不应因缺少辅助功能或屏幕录制权限而不可使用。菜单在任一准备项未完成时显示可操作状态；三项全部完成后自动隐藏该状态条，并在原区域展示最多三条仅本次运行保留的最近完成翻译。点击最近翻译只重新打开完成态结果，不重复网络请求。

### English

0.1.0 supports multiple named OpenAI-compatible streaming Chat Completions profiles and binds to no default vendor. Each profile includes:

- URL mode: Base URL or Complete URL;
- its corresponding address, for example Base URL `https://example.com/v1` or Complete URL `https://example.com/v1/chat/completions`;
- model name, entered manually or selected from models fetched for the current profile;
- optional API Key;
- enabled state;
- connection test;
- three shortcut switches and recorders;
- experimental Force Touch toggle;
- restore-default-shortcuts action.

Base URL mode normalizes the address and appends `/chat/completions`; Complete URL mode uses the entered address exactly without adding or removing path components. Both modes require an HTTP(S) host and reject query or fragment components. Connection testing and real translation share the same resolution rule. A non-empty key draft in the editor takes precedence over the saved Keychain value, with an empty draft falling back to Keychain. Model discovery uses the same key-selection rule: Base URL appends `/models`; Complete URL replaces a trailing `/chat/completions` with `/models` and reports an error when the address cannot be derived safely. Rust performs the model-list request without creating a second credential copy. A non-empty API Key produces `Authorization: Bearer <key>`; an empty key supports local or proxy endpoints that require no authentication. Each profile's key is stored only in its independent macOS Keychain account. URL, mode, model, enabled state, order, and other non-sensitive preferences use application preferences.

Only enabled profiles appear in the result-card profile picker and may start requests. The default must belong to the enabled set: disabling the current default chooses the next enabled profile in order, no enabled profiles means no default, enabling a profile while no default exists makes it the default, and setting a disabled profile as default also enables it. Completeness and enabled state remain independent. Automatic fallback, custom headers, vendor-specific request options, accounts, and a Marla proxy service are not supported in 0.1.0.

First launch uses a compact checklist for API configuration, Accessibility permission, and Screen Recording permission. Quick input must remain usable when Accessibility or Screen Recording permission is absent. The menu shows actionable status while any setup item is incomplete. Once all three are ready, that status row hides automatically and its region shows up to three recent completed translations retained for the current run only. Selecting a recent translation reopens the completed result without repeating a network request.

## 10. 错误与恢复 / Errors and Recovery

### 中文

以下情况必须有独立、可操作的状态，而不是笼统显示“失败”：

- 没有选中文字：提示如何选择或使用快速输入；
- 缺少权限：说明需要哪项权限，并提供前往系统设置操作；
- Vision 无文字：提供重新框选；
- API 未配置或配置无效：打开设置并保留源文本；
- 401/403：提示检查 Key 和端点；
- 429：显示限流，不自动重复计费请求；
- 网络、首字超时或流中断：保留已取得的源文本和已显示的部分译文，并允许重试；
- 用户取消：安静结束，不显示错误警报。

任何失败都不得丢弃已经完成的 Vision 识别结果。0.1.0 不在后台无限重试。

### English

The following conditions require distinct actionable states rather than a generic “failed” message:

- no selected text: explain selection or quick input;
- missing permission: identify the permission and provide a System Settings action;
- no Vision text: offer region re-selection;
- missing or invalid API configuration: open Settings while preserving source text;
- 401/403: ask the user to verify key and endpoint;
- 429: show rate limiting and do not automatically repeat a potentially billable request;
- network, first-token timeout, or interrupted stream: preserve acquired source and visible partial translation, then allow retry;
- user cancellation: end quietly without an error alert.

No failure may discard completed Vision recognition. 0.1.0 performs no unbounded background retry.

## 11. 隐私与数据生命周期 / Privacy and Data Lifecycle

### 中文

- 截图只存在于内存，Vision 完成或会话取消后释放；
- 只有用户明确触发的源文本发送到配置的翻译端点；
- 不发送窗口标题、附近文字、应用分类或完整屏幕；
- 不把翻译历史、截图、原文或译文写入磁盘；菜单最多保留三条内存最近翻译并在退出时清空；
- API Key 不写入日志、UserDefaults、错误消息或诊断文件；
- 退出应用后，除 Keychain 凭证和非敏感设置外不保留会话内容。

界面必须明确区分“Vision 本地识别”与“识别出的文字会发送到翻译 API”，不得使用含糊的“完全离线”表述。

### English

- screenshots exist in memory only and are released after Vision completes or the session is cancelled;
- only source text from an explicit user action is sent to the configured translation endpoint;
- window titles, nearby text, application classification, and full-screen imagery are not sent;
- translation history, screenshots, source, and translation are never written to disk; the menu keeps at most three in-memory recent translations and clears them on termination;
- API Keys never enter logs, UserDefaults, error messages, or diagnostic files;
- after app termination, no session content remains except Keychain credentials and non-sensitive settings.

The UI must distinguish “local recognition with Vision” from “recognized text is sent to the translation API” and must not claim the complete workflow is offline.

## 12. 0.1.0 范围外 / Out of Scope for 0.1.0

### 中文

- 覆盖原文位置的像素级原位翻译；
- 云端 GLM-OCR、Markdown、表格或版面结构恢复；
- 语境增强、附近文字、窗口缓存、术语记忆和提示词缓存；
- 持久历史、收藏、账号、同步和统计；
- PDF、Office、多页文档、批处理和主文档工作区；
- 浏览器 DOM 改写、可编辑原文替换和持续跟随滚动；
- 本地大语言模型、本地 OCR VLM 和自带 TTS 模型；
- Intel Mac、公开 DMG、Developer ID、公证、自动更新和 App Store 发布；
- 应用界面国际化；0.1.0 UI 使用简体中文。

### English

- pixel-perfect in-place translation that covers source text;
- cloud GLM-OCR, Markdown, table, or layout reconstruction;
- context enhancement, nearby text, window caches, terminology memory, or prompt caching;
- persistent history, favorites, accounts, sync, or analytics;
- PDF, Office, multipage documents, batch work, or a main document workspace;
- browser DOM rewriting, editable source replacement, or continuous scroll tracking;
- local LLMs, local OCR VLMs, or bundled TTS models;
- Intel Mac, public DMG, Developer ID, notarization, auto-update, or App Store release;
- application UI localization; the 0.1.0 UI is Simplified Chinese.

## 13. 测试产物 / Test Artifact

### 中文

应用内部版本为 `0.1.0`，Bundle Identifier 固定为 `com.marla.app`，最低系统为 macOS 14，首版只构建 Apple Silicon。日常测试 App 使用钥匙串中的稳定本地开发签名，并固定为：

```text
artifacts/Marla_dev.app
```

每次成功构建先在同目录完成复制、签名、包验证和 designated requirement 核对，再覆盖该固定路径，不保留上一份测试二进制。首次没有固定 App 时必须显式提供稳定签名身份；后续构建默认复用现有 App 的证书身份。身份不可用时构建失败，不退回 ad-hoc 签名。固定路径、Bundle ID 与稳定签名用于降低重复授权概率，但不构成 TCC 权限持久性的验收结论。

### English

The internal version is `0.1.0`, Bundle Identifier is fixed at `com.marla.app`, minimum system is macOS 14, and the first build supports Apple Silicon only. The daily test App uses a stable local development identity from the keychain and has the fixed path:

```text
artifacts/Marla_dev.app
```

Each successful build completes copying, signing, bundle verification, and designated-requirement comparison in a sibling staging directory before replacing that fixed path; the previous test binary is not retained. The first build without an existing fixed App requires an explicit stable signing identity. Later builds reuse the certificate identity from the existing App by default. An unavailable identity fails the build rather than falling back to ad-hoc signing. A fixed path, Bundle ID, and stable signature reduce repeated authorization risk but do not by themselves prove TCC permission persistence.
