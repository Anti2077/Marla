# Marla 0.1.0 实施规格 / Implementation Specification

状态 / Status: Implemented — verification in progress

架构 / Architecture: SwiftUI/AppKit host + embedded Rust static library

> 中文为规范文本，英文为同步镜像。/ Chinese is normative; English is its synchronized mirror.

## 1. 当前基线 / Current Baseline

### 中文

仓库当前包含可构建的 Swift Package、原生 Xcode macOS App target、真实 Rust 流式翻译核心和完整的 0.1.0 UI 壳层。菜单栏、首次启动清单、会话内最近三条翻译、划词/截图/快速输入入口、非激活结果卡片、跨屏 ScreenCaptureKit 框选、Vision `OCRDocument`、Carbon 快捷键、Keychain 设置、权限引导、错误恢复、朗读、固定、对照和 Reduce Motion 都已接入并通过当前自动化测试。最近翻译只由 Swift `TranslationSessionStore` 在完成事件后写入有界数组，失败、取消和空结果不进入；点击条目构造完成态卡片而不发起网络请求，数组不接触任何持久化 API。macOS 26+ 的菜单、设置、结果卡片、快速输入和截图框选提示使用 SwiftUI Liquid Glass，macOS 14–25 使用单层材质回退。Xcode target 已使用稳定 `com.marla.app` 生成并验证 arm64 `.app`，Debug 和 Release 分别链接 Cargo 的 debug 与 release 产物；打包脚本默认用现有固定 App 的本机稳定签名身份安全覆盖 `artifacts/Marla_dev.app`，以降低 TCC 因路径或签名身份变化而重复授权的频率。

云端结构化 OCR 开关已删除。生产截图入口只在内存中经 Vision 生成带稳定行 ID 的文字文档，并且只把纯文字发送到 Rust；显式 UI 自动化夹具不改变生产入口。

启动凭据迁移在 `applicationDidFinishLaunching` 中执行，vault、根 account 和旧 profile account 查询复用同一个 `LAContext`；如果 vault 读取失败，本进程不会由保存或翻译再次重试 Keychain。

翻译 API profile 由 Swift 按稳定 UUID 有序持久化，启用状态和其它非敏感字段保存在偏好；全部 profile Key 作为独立逻辑条目保存在一个版本化 Keychain vault item 中。`MarlaSettingsStore` 不在构造期读取 Keychain；`MarlaApplicationModel` 在 App 完成启动后调用 vault 加载和旧 item 迁移，成功写入完整 vault 后才删除旧凭据。所有 scoped store 共享进程内 account→Key 缓存，翻译和配置切换只读取缓存，拒绝回退到物理 profile item。`MarlaSettingsStore` 保证默认 profile 属于启用集合；全部停用时默认值为空。结果卡只读取启用集合，`endpoint(for:)` 和切换入口再次拒绝停用项。API 列表由本地拖动 ID 驱动 `DropDelegate` 的悬停重排，`dropEntered` 在动画事务内持久化新顺序；被拖稳定 ID 的行隐藏内容但保留等高空槽，使空槽随顺序更新移动。AppKit `NSDraggingItem` 只携带透明 1×1pt 图像维持原生 drop；独立的非激活无边框 `NSPanel` 以固定 580×76pt 绘制可见整行，并由 `draggingSession(_:movedTo:)` 根据屏幕指针坐标与最初手柄抓取点直接移动，因此不进入系统拖拽图缩放管线。拖动结束后 Panel 立即隐藏，原行内容以短促淡入恢复到空槽，设置内容背景不参与窗口拖动。API 编辑器的模型获取与连接测试共用 `APIKeyDraftResolver`，非空草稿优先且不会先读取 Keychain 回退值。

TASK-019/TASK-022 增加全局母语/第二语言偏好（`zh-Hans`、`en`、`ja`、`fr`、`es`、`de`、`ko`），Swift 在每次明确触发的原文上运行 `NLLanguageRecognizer`，把支持的识别结果和偏好快照写入 `CardSession`，并在网络请求前解析明确目标。结果卡顶部只保留 API profile 与窗口控制，第二行提供源/目标菜单；未知源语言显示可见降级并路由到母语。源覆盖只重算自动目标，显式目标保持最高优先级；重试和 API 切换保留当前卡片语言快照。

TASK-020 将结果卡从固定 300pt 改为内容驱动布局：`ResultCardLayout` 用系统字体换行测量短/中/长译文，默认约 224pt，最大不超过当前可见工作区 60%。`FloatingPanelCoordinator` 在会话发布新流式内容后按同一策略调整 AppKit 面板；有选区时保持靠近选区的边，指针降级时保持中心，Reduce Motion 下不做尺寸动画。达到上限后，译文 `ScrollView` 保留滚动视口，标题、语言、对照与操作区不被挤出。测量同时按实际渲染行高补足 AppKit `boundingRect` 与 SwiftUI `Text` 的逐行差值。

TASK-021 让同一结果面板支持原生式宽度调整：`ResultCardLayout` 把 380pt 定义为默认/最小宽度、760pt 定义为最大宽度，并按可见工作区减去 16pt 安全边距进一步限制上限。`ResultPanelLayoutModel` 在 AppKit 与 SwiftUI 间发布实时宽度和高度上限；`FloatingPanelCoordinator` 保留 `.resizable`、窗口尺寸委托和 380–760pt min/max 约束。结果面板使用隐藏标题栏的 `titled + fullSizeContentView` 组合，并把两个 8pt 透明 `ResultPanelHorizontalResizeHandleView` 放在 SwiftUI hosting view 上方，覆盖左右完整高度和角落、接收首击并拥有同一次 mouse-down/drag/up 序列。每个手柄只在 `resetCursorRects()` 中通过 `addCursorRect` 注册窗口框架 resize 光标：macOS 15+ 使用 `NSCursor.frameResize(position:directions:)`，macOS 14 使用横向 resize 回退。由于 `invalidateCursorRects(for:)` 对非 key `.nonactivatingPanel` 只延迟标记，`ResultPanelContentView` 在装载、布局与可调状态变化后直接调用窗口 `resetCursorRects()`，立即重建全部 WindowServer cursor rectangles。当前路径不使用 Carbon、定时轮询、事件监视器、手工 `NSCursor.set()/push()/pop()` 或 cursor-rectangle 禁用。宽度变化后，SwiftUI 重新排版，协调器按相同内容测量重新设置锚定高度；每次高度动画完成后再按最新会话和宽度无动画校正一次，旧 generation 的完成回调不会覆盖新结果；用户实时拖动与 Reduce Motion 都不执行尺寸动画。快速输入从 420pt 开始并复用同一范围。

### English

The repository now contains a buildable Swift Package, a native Xcode macOS App target, the real Rust streaming translation core, and the complete 0.1.0 UI shell. The menu bar, onboarding checklist, three in-session recent translations, selection/screenshot/quick-input entries, non-activating result card, cross-display ScreenCaptureKit selection, Vision `OCRDocument`, Carbon shortcuts, Keychain settings, permission guidance, error recovery, speech, pinning, comparison, and Reduce Motion handling are wired and covered by the current automated tests. Recent translations are appended only by Swift's `TranslationSessionStore` after completion into a bounded array; failed, cancelled, and empty results are excluded. Selecting an item constructs a completed card without a network request, and the array touches no persistence API. The menu, Settings, result card, quick input, and screenshot-selection labels use SwiftUI Liquid Glass on macOS 26+ and a single material fallback on macOS 14–25. The Xcode target has produced and verified an arm64 `.app` with stable identity `com.marla.app`; Debug and Release link the matching Cargo debug and release products. By default, the packaging script safely replaces `artifacts/Marla_dev.app` using the existing fixed App's stable local signing identity, reducing repeated TCC prompts caused by path or signing-identity changes.

The cloud structured OCR switch has been removed. Production screenshot entry keeps the in-memory Vision document with stable line IDs and sends text only to Rust; explicit UI automation fixtures do not alter production entry points.

Credential migration runs from `applicationDidFinishLaunching`, reusing one `LAContext` for the vault, root account, and legacy profile-account queries. If vault loading fails, saving or translating does not retry Keychain access in the same process.

Swift persists translation API profiles in order under stable UUIDs, with enabled state and other non-sensitive fields in preferences. All profile keys live as independent logical entries inside one versioned Keychain vault item. `MarlaSettingsStore` does not read the Keychain during construction; after the App finishes launching, `MarlaApplicationModel` loads the vault and migrates legacy physical items, deleting them only after the complete vault is written. All scoped stores share an in-process account-to-key cache, and translation/profile switching never falls back to a physical profile item. `MarlaSettingsStore` keeps the default inside the enabled set and uses no default when every profile is disabled. Result cards read only the enabled set, while `endpoint(for:)` and the switch entry reject disabled profiles again. The API list feeds a local drag identifier into a `DropDelegate` for hover reordering, and `dropEntered` persists the new order inside an animation transaction. The row carrying the dragged stable ID hides its content but retains a full-height empty slot, so the slot moves with the updated order. The AppKit `NSDraggingItem` carries only a transparent 1×1pt image to preserve native drop handling. A separate nonactivating borderless `NSPanel` renders the visible row at a fixed 580×76pt and moves through `draggingSession(_:movedTo:)` using the screen pointer and original handle grab point, bypassing the system drag-image scaling pipeline. When dragging ends, the panel hides immediately and row content fades back into the slot. The Settings content background never participates in window dragging. Model discovery and connection testing in the API editor share `APIKeyDraftResolver`, preferring a non-empty draft without first reading the Keychain fallback.

TASK-019/TASK-022 add global native/secondary preferences (`zh-Hans`, `en`, `ja`, `fr`, `es`, `de`, and `ko`). Swift runs `NLLanguageRecognizer` only on each explicitly triggered source, snapshots supported detection plus preferences into `CardSession`, and resolves one explicit target before networking. The card header now keeps only API profile and window controls; a second row contains source and target menus. Unknown source is a visible degradation routed to native. A source override recomputes automatic target only, explicit target remains highest priority, and retry/API switching preserve the card's language snapshot.

TASK-020 changes the result card from a fixed 300pt frame to content-driven layout. `ResultCardLayout` measures wrapped short/medium/long translations with the system font, starting around 224pt and never exceeding 60% of the current visible workspace. `FloatingPanelCoordinator` resizes the AppKit panel when the session publishes new stream content; it keeps the edge nearest a selection fixed, keeps the pointer fallback centered, and skips size animation with Reduce Motion. The measurement also compensates for the per-line difference between AppKit `boundingRect` and SwiftUI `Text`. Once capped, the translation `ScrollView` keeps a body viewport while header, language, comparison, and actions remain visible.

TASK-021 adds native-style width adjustment to the same result panel. `ResultCardLayout` defines 380pt as the default/minimum and 760pt as the maximum, further constraining the maximum to the visible workspace minus a 16pt safety inset. `ResultPanelLayoutModel` publishes live width and the height cap between AppKit and SwiftUI. `FloatingPanelCoordinator` retains `.resizable`, window resize delegates, and 380–760pt min/max constraints. The panel uses a hidden `titled + fullSizeContentView` combination and places two transparent 8pt `ResultPanelHorizontalResizeHandleView`s above the SwiftUI hosting view. They cover the complete left/right heights including corners, accept the first click, and own one mouse-down/drag/up sequence. Each handle registers its frame-resize cursor only from `resetCursorRects()` via `addCursorRect`: macOS 15+ uses `NSCursor.frameResize(position:directions:)`, while macOS 14 uses the horizontal-resize fallback. Because `invalidateCursorRects(for:)` only defers invalidation for a non-key `.nonactivatingPanel`, `ResultPanelContentView` calls the window's `resetCursorRects()` directly after attachment, layout, and resize-state changes so all WindowServer cursor rectangles are rebuilt immediately. The current path uses no Carbon cursor call, polling timer, event monitor, manual `NSCursor.set()/push()/pop()`, or cursor-rectangle disabling. Width changes reflow SwiftUI, then the coordinator reapplies the same content measurement at the anchored height; each height animation finishes with one latest-session, no-animation frame reconciliation, while stale generations cannot overwrite newer text. Live dragging and Reduce Motion skip size animation. Quick input starts at 420pt and shares the same range.

## 2. 责任边界 / Responsibility Boundary

### 中文

| 子系统 | SwiftUI/AppKit | Rust Core |
| --- | --- | --- |
| 应用生命周期与菜单栏 | 拥有 | 不参与 |
| Accessibility、ScreenCaptureKit、Vision | 拥有 | 只接收规范化文字 |
| 全局快捷键 | 拥有 | 接收翻译意图 |
| 结果卡片、设置、权限、朗读 | 拥有 | 发送会话事件 |
| Keychain | 单一 vault 持久化，启动完成后加载并缓存 | 每次请求临时接收 Key，不持久化 |
| 语言识别与自动路由 | 本机识别、偏好与明确源/目标解析 | 校验语言并构造最终提示词/Provider 参数 |
| HTTP、SSE、超时、取消 | 不直接访问 | 拥有 |
| 会话状态与迟到事件隔离 | 映射到 UI | 拥有请求生命周期 |

Swift 不把 `AXUIElement`、`NSWindow`、`CGImage` 或 Objective-C 对象指针传给 Rust。Rust 不直接操作主线程 UI。0.1.0 不启动 localhost 服务或常驻 sidecar。

### English

| Subsystem | SwiftUI/AppKit | Rust Core |
| --- | --- | --- |
| App lifecycle and menu bar | Owns | Not involved |
| Accessibility, ScreenCaptureKit, Vision | Owns | Receives normalized text only |
| Global shortcuts | Owns | Receives translation intent |
| Result card, Settings, permissions, speech | Owns | Emits session events |
| Keychain | Persists one vault, loaded and cached after launch | Receives key temporarily per request; never persists |
| Language detection and automatic routing | Local detection, preferences, and explicit source/target resolution | Validates languages and owns final prompt/provider parameters |
| HTTP, SSE, timeout, cancellation | Does not access directly | Owns |
| Session state and late-event isolation | Maps to UI | Owns request lifecycle |

Swift never passes `AXUIElement`, `NSWindow`, `CGImage`, or Objective-C object pointers to Rust. Rust never directly mutates main-thread UI. 0.1.0 starts no localhost server or persistent sidecar.

## 3. 应用目标与打包 / Application Target and Packaging

### 中文

建立原生 macOS App target，固定：

- Product name: `Marla`；
- Bundle Identifier: `com.marla.app`；
- Marketing version: `0.1.0`；
- Minimum deployment: macOS 14；
- Architecture: `arm64`；
- LSUIElement/menu-bar app，不在 Dock 常驻显示主窗口。

Xcode 构建阶段必须先以对应配置编译 Rust 静态库，再链接 Swift App。Debug/测试使用 Cargo debug 产物，Release/测试 App 使用 Cargo release 产物，禁止让 Release App 意外链接 `target/debug`。Rust Header、ABI 版本和 Swift Wrapper 在同一变更中更新。

打包脚本默认输出并覆盖唯一的 `artifacts/Marla_dev.app`。它从现有固定 App 的 designated requirement 提取证书哈希，确认该稳定身份在钥匙串中有效，再把 Release 产物复制到同目录临时位置完成签名与验证；只有 Bundle ID、版本、架构、可执行文件、签名和 designated requirement 全部通过后才替换旧 App。首次构建允许显式提供 `MARLA_CODE_SIGN_IDENTITY`；缺少稳定身份时失败，不使用 ad-hoc。自定义的已有路径只有设置 `MARLA_ALLOW_ARTIFACT_REPLACE=1` 才允许覆盖。

### English

Create a native macOS App target fixed to:

- Product name: `Marla`;
- Bundle Identifier: `com.marla.app`;
- Marketing version: `0.1.0`;
- Minimum deployment: macOS 14;
- Architecture: `arm64`;
- LSUIElement/menu-bar app with no persistent Dock main window.

The Xcode build phase compiles the Rust static library for the matching configuration before linking Swift. Debug/testing uses Cargo debug output; Release/test-app uses Cargo release output. A Release app may never accidentally link `target/debug`. Rust header, ABI version, and Swift wrapper change together.

The packaging script outputs and replaces only `artifacts/Marla_dev.app` by default. It extracts the certificate hash from the existing fixed App's designated requirement, confirms that stable identity remains valid in the keychain, then copies the Release product to a sibling staging location for signing and verification. It replaces the old App only after Bundle ID, version, architecture, executable, signature, and designated requirement all pass. The first build may provide `MARLA_CODE_SIGN_IDENTITY` explicitly; a missing stable identity fails rather than using ad-hoc signing. An existing custom path may be overwritten only with `MARLA_ALLOW_ARTIFACT_REPLACE=1`.

## 4. FFI 公共接口 / Public FFI Interface

### 中文

在现有 `marla_core_api_version` 基础上增加不透明翻译句柄和三个 C ABI 操作。名称和所有权如下：

```c
typedef struct MarlaTranslationHandle MarlaTranslationHandle;
typedef void (*MarlaTranslationEventCallback)(
    const uint8_t *event_json,
    size_t event_json_length,
    void *context
);

MarlaTranslationHandle *marla_translation_start(
    const uint8_t *request_json,
    size_t request_json_length,
    MarlaTranslationEventCallback callback,
    void *context
);

void marla_translation_cancel(MarlaTranslationHandle *handle);
void marla_translation_release(MarlaTranslationHandle *handle);
```

规则：

- `start` 在返回前复制请求字节，不保存 Swift 缓冲区指针；
- 回调中的事件缓冲区只在回调期间有效，Swift 必须立即复制；
- `cancel` 可重复调用并且幂等；
- 每个非空句柄恰好调用一次 `release`；`release` 先取消并安全等待资源退出，不再产生回调；
- 空指针、无效 UTF-8、无效 JSON 和未知 schema 不得 panic；
- 所有导出函数使用 `catch_unwind`，panic 不跨越 C ABI；
- 回调来自 Rust 后台线程，Swift 复制后通过 `Task { @MainActor in ... }` 更新状态。

### English

Extend the existing `marla_core_api_version` with an opaque translation handle and three C ABI operations. Names and ownership are:

```c
typedef struct MarlaTranslationHandle MarlaTranslationHandle;
typedef void (*MarlaTranslationEventCallback)(
    const uint8_t *event_json,
    size_t event_json_length,
    void *context
);

MarlaTranslationHandle *marla_translation_start(
    const uint8_t *request_json,
    size_t request_json_length,
    MarlaTranslationEventCallback callback,
    void *context
);

void marla_translation_cancel(MarlaTranslationHandle *handle);
void marla_translation_release(MarlaTranslationHandle *handle);
```

Rules:

- `start` copies request bytes before returning and retains no Swift buffer pointer;
- callback event bytes are valid only during the callback and Swift copies immediately;
- `cancel` is repeatable and idempotent;
- every non-null handle receives exactly one `release`; `release` first cancels and safely drains resources, then emits no further callback;
- null pointers, invalid UTF-8, invalid JSON, and unknown schemas never panic;
- every exported function uses `catch_unwind`; panic never crosses the C ABI;
- callbacks arrive on a Rust background thread, and Swift copies then uses `Task { @MainActor in ... }` for state changes.

## 5. JSON 协议 / JSON Protocol

### 中文

请求 schema 固定为版本 1：

```json
{
  "schemaVersion": 2,
  "requestID": "D4E7B70E-…",
  "sourceText": "Hello world",
  "sourceLanguage": "en",
  "target": {
    "mode": "explicit",
    "language": "zh-Hans"
  },
  "endpoint": {
    "baseURL": "https://example.com/v1",
    "model": "model-name",
    "apiKey": "optional-secret"
  },
  "timeouts": {
    "connectSeconds": 10,
    "firstTokenSeconds": 30,
    "overallSeconds": 120
  }
}
```

翻译请求 schema v2 的 `sourceLanguage` 可以为空，或为 `zh-Hans`、`en`、`ja`、`fr`、`es`、`de`、`ko`；空值表示 Provider 继续识别源语言。`target.mode` 在 Rust 边界必须为 `explicit`，且 `language` 为同一产品语言集合之一。自动策略已经由 Swift 按当前卡片的母语/第二语言快照解析。所有文本按 UTF-8 传输；去除首尾纯空白只用于空值校验，实际翻译内容保留用户原始换行。事件 schema 继续使用版本 1。

事件 schema 同样固定为版本 1：

```json
{"schemaVersion":1,"requestID":"…","type":"started"}
{"schemaVersion":1,"requestID":"…","type":"delta","text":"你"}
{"schemaVersion":1,"requestID":"…","type":"completed","text":"你好，世界"}
{"schemaVersion":1,"requestID":"…","type":"failed","code":"network","message":"…","retryable":true}
{"schemaVersion":1,"requestID":"…","type":"cancelled"}
```

错误 `code` 只允许：`invalid_configuration`、`unauthorized`、`rate_limited`、`network`、`timeout`、`provider`、`invalid_response`、`internal`。用户取消使用 `cancelled` 事件，不编码为失败。

日志可以记录 request ID、阶段、耗时、HTTP 状态和错误 code，但不得记录 API Key、Authorization Header、源文本或译文。

### English

Request schema is fixed at version 1:

```json
{
  "schemaVersion": 2,
  "requestID": "D4E7B70E-…",
  "sourceText": "Hello world",
  "sourceLanguage": "en",
  "target": {
    "mode": "explicit",
    "language": "zh-Hans"
  },
  "endpoint": {
    "baseURL": "https://example.com/v1",
    "model": "model-name",
    "apiKey": "optional-secret"
  },
  "timeouts": {
    "connectSeconds": 10,
    "firstTokenSeconds": 30,
    "overallSeconds": 120
  }
}
```

Translation request schema v2 allows `sourceLanguage` to be absent or one of `zh-Hans`, `en`, `ja`, `fr`, `es`, `de`, and `ko`; absence lets the Provider detect source. At the Rust boundary `target.mode` must be `explicit`, with `language` from the same product set. Swift has already resolved automatic policy against the card's native/secondary snapshot. All text is UTF-8; leading/trailing whitespace is trimmed only for empty validation, and the translated payload preserves original line breaks. Event schema remains version 1.

Event schema is also fixed at version 1:

```json
{"schemaVersion":1,"requestID":"…","type":"started"}
{"schemaVersion":1,"requestID":"…","type":"delta","text":"你"}
{"schemaVersion":1,"requestID":"…","type":"completed","text":"你好，世界"}
{"schemaVersion":1,"requestID":"…","type":"failed","code":"network","message":"…","retryable":true}
{"schemaVersion":1,"requestID":"…","type":"cancelled"}
```

Allowed error `code` values are `invalid_configuration`, `unauthorized`, `rate_limited`, `network`, `timeout`, `provider`, `invalid_response`, and `internal`. User cancellation emits `cancelled`, not failure.

Logs may contain request ID, phase, duration, HTTP status, and error code, but never API Key, Authorization Header, source text, or translation.

## 6. 翻译 Provider / Translation Provider

### 中文

Rust 使用单个进程级异步运行时和一个共享 HTTP Client。OpenAI-compatible 请求发送到规范化的 `{baseURL}/chat/completions`，设置 `stream: true`。Key 非空时添加 Bearer Header；不支持自定义 Header。

SSE 解析接受 `data:` 帧、空行分隔、跨网络分片的 UTF-8、`[DONE]` 和 `finish_reason` 完成。通用端点读取 `choices[0].delta.content` 并容忍没有内容的角色帧。无法解析的有效 HTTP 响应返回 `invalid_response`；HTTP 200 流内的 Provider 错误也必须映射为失败事件，不得把原始响应体直接展示给用户或写入日志。

通用模型的系统提示词把用户输入视为待翻译数据，使用 Swift 解析后的可选源语言和明确目标语言；源语言未知时才要求模型识别。目标支持七门产品语言：简体中文、English、日本語、Français、Español、Deutsch 和 한국어。提示词只允许输出译文，并要求保留换行、标点、专有名词、代码标识符和终端参数；源文本继续使用明确分隔符包裹。

当模型名以 `qwen-mt-` 开头时，Rust 使用 Qwen-MT 的兼容协议：不发送 `system` 角色，把 `zh-Hans`/`en`/`ja`/`fr`/`es`/`de`/`ko` 映射为 `Chinese`/`English`/`Japanese`/`French`/`Spanish`/`German`/`Korean` 的 `translation_options.source_lang` / `target_lang`，未知源语言使用 `auto`，并把 Provider 返回的累计 `delta.content` 归一化为 Marla 的增量事件。其他模型使用上述通用 OpenAI-compatible 系统提示词。

不做可能造成重复计费的静默自动重试。连接失败、超时、429 和流中断都产生可重试错误，只有用户按“重试”才创建新 request ID。首个 delta 后的部分内容保留在 Swift 会话中。

### English

Rust uses one process-wide asynchronous runtime and one shared HTTP client. The OpenAI-compatible request goes to normalized `{baseURL}/chat/completions` with `stream: true`. A non-empty key adds a Bearer Header. Custom headers are unsupported.

SSE parsing accepts `data:` frames, blank-line separation, UTF-8 split across network chunks, `[DONE]`, and `finish_reason` completion. Generic endpoints read `choices[0].delta.content` while tolerating role frames with no content. An unparseable successful HTTP response becomes `invalid_response`; provider errors carried inside an HTTP 200 stream also become failed events. Raw response bodies are neither shown to the user nor logged.

The generic-model system prompt treats user input as translation data and uses Swift's optional resolved source plus explicit target; it asks the model to detect source only when source is unknown. Targets support the seven product languages: Simplified Chinese, English, Japanese, French, Spanish, German, and Korean. Output is translation only, preserving line breaks, punctuation, proper nouns, code identifiers, and terminal arguments, with clear source delimiters.

When the model name starts with `qwen-mt-`, Rust uses the Qwen-MT-compatible protocol with no `system` role. It maps `zh-Hans`/`en`/`ja`/`fr`/`es`/`de`/`ko` to `Chinese`/`English`/`Japanese`/`French`/`Spanish`/`German`/`Korean` in `translation_options.source_lang` / `target_lang`, uses `auto` only for unknown source, and normalizes cumulative `delta.content` into Marla incremental events. Other models use the generic OpenAI-compatible prompt above.

There is no silent automatic retry that could duplicate billing. Connection failure, timeout, 429, and interrupted stream produce retryable errors; only the Retry action creates a new request ID. Partial content after the first delta remains in the Swift session.

## 7. 本地输入管线 / Local Input Pipelines

### 中文

**划词**：从触发瞬间的前台进程和聚焦 Accessibility 元素开始，在有界后代树内读取 `AXSelectedText`、`AXSelectedTextRange` / `AXStringForRange`，或 Electron/WebArea 使用的 `AXSelectedTextMarkerRange` / `AXStringForTextMarkerRange`。标准范围优先用 `AXBoundsForRange`，Text Marker 优先用 `AXBoundsForTextMarkerRange`。不读取附近文字和窗口标题，不把已有 Rust 应用分类放入请求；坐标不可用时使用触发时指针位置。

**截图**：在创建任何框选窗口前，每个活动显示器分别使用 ScreenCaptureKit 捕获完整静态帧，并明确排除 Marla 自身应用窗口。AppKit 框选层、未调暗选区和像素放大镜只绘制这些会话内冻结帧。确认后不再次捕获实时桌面，而是把 AppKit 全局左下原点选区与各显示器 frame 相交，按冻结图像像素缩放中的最高值合成最终裁剪；全屏帧随框选会话释放，裁剪立即交给 Vision。`VNRecognizeTextRequest` 使用 `.accurate` 和语言校正，开启自动语言检测，并把当前运行时支持列表与 `zh-Hans`、`en-US`、`ja-JP`、`fr-FR`、`es-ES`、`de-DE`、`ko-KR` 求交集后作为候选；能力查询失败或交集为空时保留 Vision 默认候选，避免强写不支持的标识。候选按屏幕阅读顺序归一化为带稳定行 ID、边界和置信度的 `OCRDocument`。只有其换行纯文本进入翻译请求；不调用 GLM-OCR，不上传像素。

**快速输入**：SwiftUI 编辑器本地持有草稿；提交前不跨 FFI。空白校验通过后创建与其他入口相同的翻译请求。

**语言识别**：所有入口取得纯文本后在 Swift 主流程中用 `NLLanguageRecognizer` 识别一次。系统中文家族归一为 `zh-Hans`；`zh-Hans`、`en`、`ja`、`fr`、`es`、`de`、`ko` 进入明确源语言字段，其他结果降级为未知。识别结果与偏好随卡片存在，不写入磁盘或日志。

### English

**Selection**: starting from the trigger-time frontmost process and focused Accessibility element, search a bounded descendant tree for `AXSelectedText`, `AXSelectedTextRange` / `AXStringForRange`, or the `AXSelectedTextMarkerRange` / `AXStringForTextMarkerRange` attributes used by Electron WebAreas. Standard ranges prefer `AXBoundsForRange`; Text Markers prefer `AXBoundsForTextMarkerRange`. Do not read nearby text or window title, and do not include the existing Rust app classification in the request. Use the trigger-time pointer when geometry is unavailable.

**Screenshot**: before creating any selection window, ScreenCaptureKit captures a complete static frame for every active display while explicitly excluding Marla's own application windows. The AppKit selection layer, undimmed selected region, and pixel loupe draw only these session-frozen frames. Confirmation does not recapture the live desktop. Instead, it intersects the AppKit global bottom-left selection with each display frame and composites the final crop at the highest frozen-image pixel scale. Full-display frames are released with the selection session and the crop immediately enters Vision. `VNRecognizeTextRequest` uses `.accurate` with language correction, enables automatic language detection, and intersects the current runtime support list with `zh-Hans`, `en-US`, `ja-JP`, `fr-FR`, `es-ES`, `de-DE`, and `ko-KR`; if capability lookup fails or the intersection is empty, it preserves Vision's default candidates rather than forcing unsupported identifiers. Candidates become an `OCRDocument` with stable line IDs, bounds, confidence, and reading order. Only its newline-joined text enters the translation request; do not call GLM-OCR or upload pixels.

**Quick input**: the SwiftUI editor owns its draft locally and crosses no FFI boundary before submission. After whitespace validation, it creates the same translation request as other entries.

**Language detection**: after every entry obtains plain text, Swift runs `NLLanguageRecognizer` once in the local flow. System Chinese variants normalize to `zh-Hans`; `zh-Hans`, `en`, `ja`, `fr`, `es`, `de`, and `ko` enter the explicit source field, while other results degrade to unknown. Detection and preferences live with the card and enter neither disk nor logs.

## 8. 会话状态 / Session State

### 中文

统一状态机：

```text
idle
  -> acquiring
  -> recognizing       (仅截图 / screenshot only)
  -> awaitingFirstToken
  -> streaming
  -> completed
  -> failed | cancelled
```

每张卡片持有唯一 request ID 和创建时的母语/第二语言、源选择、识别结果与目标策略快照。所有事件先比较 request ID；旧请求事件直接丢弃。关闭卡片、切换源/目标、重试或开始替代请求时先调用 `cancel`，随后 `release`。重试和 API 切换保留语言快照；OCR 成功后翻译失败仍保留源文本，不回到截图阶段。

### English

Unified state machine:

```text
idle
  -> acquiring
  -> recognizing       (仅截图 / screenshot only)
  -> awaitingFirstToken
  -> streaming
  -> completed
  -> failed | cancelled
```

Each card owns a unique request ID plus creation-time snapshots of native/secondary languages, source selection, detection result, and target policy. Every event first checks request ID; stale-request events are discarded. Closing, source/target change, retry, or replacement calls `cancel` then `release`. Retry and API switching preserve the language snapshot. A translation failure after successful OCR preserves source text and does not return to screenshot capture.

## 9. 实施阶段 / Implementation Phases

### 中文

1. **App 基础（已验证）**：Xcode App target、稳定 Bundle ID、权限声明、Rust Debug/Release 构建阶段和固定路径稳定签名测试包脚本。
2. **翻译核心（已实现）**：JSON schema、FFI 句柄、异步运行时、OpenAI-compatible SSE、Keychain 设置桥和 mock-provider 测试。
3. **划词垂直切片（已实现）**：Carbon 全局快捷键、选区获取、非激活结果卡片、流式状态、复制/重试/关闭。
4. **截图垂直切片（已实现）**：跨屏框选、ScreenCaptureKit、Vision `OCRDocument`、纯文本归一化和同一结果卡片。
5. **快速输入与完整控件（已实现）**：IME、多行输入、对照、朗读、固定、目标切换、快捷键录制和权限引导。
6. **产品化（验证中）**：性能/内存测量、视觉技能审查、兼容矩阵和最终验收。

每个阶段完成时同时更新 `STATUS.md` 和相关 0.1.0 文档；不得等到版本末尾集中补文档。

### English

1. **App foundation (verified)**: Xcode App target, stable Bundle ID, permission declarations, Rust Debug/Release build phase, and fixed-path stable-signing test-app script.
2. **Translation core (implemented)**: JSON schema, FFI handles, async runtime, OpenAI-compatible SSE, Keychain settings bridge, and mock-provider tests.
3. **Selection vertical slice (implemented)**: Carbon global shortcuts, selection acquisition, non-activating result card, streaming state, copy/retry/close.
4. **Screenshot vertical slice (implemented)**: cross-display selection, ScreenCaptureKit, Vision `OCRDocument`, plain-text normalization, and the same result card.
5. **Quick input and full controls (implemented)**: IME, multiline input, comparison, speech, pin, target switching, shortcut recording, and permission onboarding.
6. **Productization (verification in progress)**: performance/memory measurement, design-skill review, compatibility matrix, and final acceptance.

Every phase updates `STATUS.md` and affected 0.1.0 documentation when completed; documentation is not deferred to the end of the release.
