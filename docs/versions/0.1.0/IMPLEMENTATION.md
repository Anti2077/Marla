# Marla 0.1.0 实施规格 / Implementation Specification

状态 / Status: In Progress

架构 / Architecture: SwiftUI/AppKit host + embedded Rust static library

> 中文为规范文本，英文为同步镜像。/ Chinese is normative; English is its synchronized mirror.

## 1. 当前基线 / Current Baseline

### 中文

仓库当前同时包含可构建的 Swift Package 骨架和原生 Xcode macOS App target。SwiftUI 菜单栏壳层、Accessibility 选区读取、基础领域模型、Rust `staticlib`、C ABI 和 Bundle ID 表面分类桥接已经存在并通过测试。Xcode target 已使用稳定 `com.marla.app` 生成并验证临时签名的 arm64 `.app`，Debug 和 Release 分别链接 Cargo 的 debug 与 release 产物。真实翻译网络管线、Vision 截图流程、全局快捷键和结果卡片仍未实现。

部分占位设置仍显示云端结构化 OCR；这是当前代码与 0.1.0 目标的已知差异，实施时必须删除，而不是把占位 UI 当作已接受行为。

### English

The repository now contains both the buildable Swift Package foundation and a native Xcode macOS App target. A SwiftUI menu-bar shell, Accessibility selection reader, foundational domain models, Rust `staticlib`, C ABI, and Bundle-ID surface-classification bridge exist and pass tests. The Xcode target has produced and verified an ad-hoc-signed arm64 `.app` with stable identity `com.marla.app`; Debug and Release link the matching Cargo debug and release products. The real translation network pipeline, Vision screenshot flow, global shortcuts, and result card remain unimplemented.

Some placeholder Settings still expose cloud structured OCR. This is a known discrepancy between current code and the 0.1.0 target and must be removed during implementation rather than treated as accepted behavior.

## 2. 责任边界 / Responsibility Boundary

### 中文

| 子系统 | SwiftUI/AppKit | Rust Core |
| --- | --- | --- |
| 应用生命周期与菜单栏 | 拥有 | 不参与 |
| Accessibility、ScreenCaptureKit、Vision | 拥有 | 只接收规范化文字 |
| 全局快捷键与 Force Touch | 拥有 | 接收翻译意图 |
| 结果卡片、设置、权限、朗读 | 拥有 | 发送会话事件 |
| Keychain | 持久化与读取 | 每次请求临时接收 Key，不持久化 |
| 自动语言规则与提示词 | 提供用户策略 | 拥有最终提示词构造 |
| HTTP、SSE、超时、取消 | 不直接访问 | 拥有 |
| 会话状态与迟到事件隔离 | 映射到 UI | 拥有请求生命周期 |

Swift 不把 `AXUIElement`、`NSWindow`、`CGImage` 或 Objective-C 对象指针传给 Rust。Rust 不直接操作主线程 UI。0.1.0 不启动 localhost 服务或常驻 sidecar。

### English

| Subsystem | SwiftUI/AppKit | Rust Core |
| --- | --- | --- |
| App lifecycle and menu bar | Owns | Not involved |
| Accessibility, ScreenCaptureKit, Vision | Owns | Receives normalized text only |
| Global shortcuts and Force Touch | Owns | Receives translation intent |
| Result card, Settings, permissions, speech | Owns | Emits session events |
| Keychain | Persists and reads | Receives key temporarily per request; never persists |
| Automatic language rule and prompt | Supplies user policy | Owns final prompt construction |
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

打包脚本复制构建成功且验证过的 `.app`，按 Asia/Shanghai 当前时间生成 `Marla_test_yyyyMMddHHmm.app`。脚本不得修改内部 Bundle ID；产物至少验证架构、版本、签名状态和可执行文件存在。

### English

Create a native macOS App target fixed to:

- Product name: `Marla`;
- Bundle Identifier: `com.marla.app`;
- Marketing version: `0.1.0`;
- Minimum deployment: macOS 14;
- Architecture: `arm64`;
- LSUIElement/menu-bar app with no persistent Dock main window.

The Xcode build phase compiles the Rust static library for the matching configuration before linking Swift. Debug/testing uses Cargo debug output; Release/test-app uses Cargo release output. A Release app may never accidentally link `target/debug`. Rust header, ABI version, and Swift wrapper change together.

The packaging script copies a successfully built and verified `.app`, naming it `Marla_test_yyyyMMddHHmm.app` from current Asia/Shanghai time. It does not change the internal Bundle ID and verifies at least architecture, version, signing state, and executable presence.

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
  "schemaVersion": 1,
  "requestID": "D4E7B70E-…",
  "sourceText": "Hello world",
  "target": {
    "mode": "automatic",
    "language": null
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

`target.mode` 只允许 `automatic` 或 `explicit`；`explicit` 要求 `language` 为 `zh-Hans` 或 `en`。所有文本按 UTF-8 传输。源文本去除首尾纯空白只用于空值校验，实际翻译内容保留用户原始换行。

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
  "schemaVersion": 1,
  "requestID": "D4E7B70E-…",
  "sourceText": "Hello world",
  "target": {
    "mode": "automatic",
    "language": null
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

`target.mode` accepts only `automatic` or `explicit`; `explicit` requires `language` to be `zh-Hans` or `en`. All text is UTF-8. Leading/trailing whitespace is trimmed only for empty validation; the translated payload preserves original line breaks.

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

SSE 解析接受 `data:` 帧、空行分隔、跨网络分片的 UTF-8 和 `[DONE]`。只读取 `choices[0].delta.content`，同时容忍没有内容的角色帧。无法解析的有效 HTTP 响应返回 `invalid_response`，不得把原始响应体直接展示给用户或写入日志。

自动模式的系统提示词语义固定为：把用户输入视为待翻译数据；自动识别源语言；中文译成英文，非中文译成简体中文；只输出译文；保留换行、标点、专有名词、代码标识符和终端参数。显式模式把目标替换为选定语言。源文本使用明确分隔符包裹，降低把内容当指令执行的风险。

不做可能造成重复计费的静默自动重试。连接失败、超时、429 和流中断都产生可重试错误，只有用户按“重试”才创建新 request ID。首个 delta 后的部分内容保留在 Swift 会话中。

### English

Rust uses one process-wide asynchronous runtime and one shared HTTP client. The OpenAI-compatible request goes to normalized `{baseURL}/chat/completions` with `stream: true`. A non-empty key adds a Bearer Header. Custom headers are unsupported.

SSE parsing accepts `data:` frames, blank-line separation, UTF-8 split across network chunks, and `[DONE]`. It reads only `choices[0].delta.content` while tolerating role frames with no content. An unparseable successful HTTP response becomes `invalid_response`; raw response bodies are neither shown to the user nor logged.

The automatic system prompt has fixed semantics: treat user input as translation data; detect source language; translate Chinese to English and non-Chinese to Simplified Chinese; output translation only; preserve line breaks, punctuation, proper nouns, code identifiers, and terminal arguments. Explicit mode replaces the target with the selected language. Clear delimiters surround source text to reduce instruction confusion.

There is no silent automatic retry that could duplicate billing. Connection failure, timeout, 429, and interrupted stream produce retryable errors; only the Retry action creates a new request ID. Partial content after the first delta remains in the Swift session.

## 7. 本地输入管线 / Local Input Pipelines

### 中文

**划词**：从触发瞬间的前台进程和聚焦 Accessibility 元素读取 `AXSelectedText`、`AXSelectedTextRange` 和可用的 `AXBoundsForRange`。不读取附近文字和窗口标题，不把已有 Rust 应用分类放入请求。坐标不可用时使用触发时指针位置。

**截图**：ScreenCaptureKit 负责跨显示器坐标和 Retina 缩放；裁剪后立即交给 Vision。`VNRecognizeTextRequest` 使用 `.accurate`，启用自动语言识别，并把候选按屏幕阅读顺序排序。输出是带稳定行 ID 和换行的纯文本；不调用 GLM-OCR，不上传像素。

**快速输入**：SwiftUI 编辑器本地持有草稿；提交前不跨 FFI。空白校验通过后创建与其他入口相同的翻译请求。

### English

**Selection**: read `AXSelectedText`, `AXSelectedTextRange`, and available `AXBoundsForRange` from the frontmost process and focused Accessibility element at trigger time. Do not read nearby text or window title, and do not include the existing Rust app classification in the request. Use trigger-time pointer position when geometry is unavailable.

**Screenshot**: ScreenCaptureKit owns cross-display coordinates and Retina scaling; the crop immediately enters Vision. `VNRecognizeTextRequest` uses `.accurate`, enables automatic language detection, and sorts candidates into screen reading order. Output is plain text with stable line IDs and line breaks. Do not call GLM-OCR or upload pixels.

**Quick input**: the SwiftUI editor owns its draft locally and crosses no FFI boundary before submission. After whitespace validation, it creates the same translation request as other entries.

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

每张卡片持有唯一 request ID。所有事件先比较 request ID；旧请求事件直接丢弃。关闭卡片、切换目标、重试或开始替代请求时先调用 `cancel`，随后 `release`。OCR 成功后翻译失败仍保留源文本，不回到截图阶段。

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

Each card owns a unique request ID. Every event first checks request ID; stale-request events are discarded. Closing, target change, retry, or replacement calls `cancel` then `release`. A translation failure after successful OCR preserves source text and does not return to screenshot capture.

## 9. 实施阶段 / Implementation Phases

### 中文

1. **App 基础（2026-08-05 已验证）**：建立 Xcode App target、稳定 Bundle ID、权限声明、Rust Debug/Release 构建阶段和时间戳测试包脚本。
2. **翻译核心**：实现 JSON schema、FFI 句柄、异步运行时、OpenAI-compatible SSE、Keychain 设置桥和模拟服务器测试。
3. **划词垂直切片**：全局快捷键、选区获取、非激活结果卡片、流式状态、复制/重试/关闭。
4. **截图垂直切片**：跨屏框选、ScreenCaptureKit、Vision、纯文本归一化和同一结果卡片。
5. **快速输入与完整控件**：IME、多行输入、对照、朗读、固定、目标切换、快捷键录制和权限引导。
6. **实验与产品化**：Force Touch 公共 API 可行性、性能/内存测量、视觉技能审查、兼容矩阵和时间戳测试 App。

每个阶段完成时同时更新 `STATUS.md` 和相关 0.1.0 文档；不得等到版本末尾集中补文档。

### English

1. **App foundation (verified 2026-08-05)**: create Xcode App target, stable Bundle ID, permission declarations, Rust Debug/Release build phase, and timestamped test-app script.
2. **Translation core**: implement JSON schema, FFI handles, async runtime, OpenAI-compatible SSE, Keychain settings bridge, and mock-server tests.
3. **Selection vertical slice**: global shortcut, selection acquisition, non-activating result card, streaming state, copy/retry/close.
4. **Screenshot vertical slice**: cross-display selection, ScreenCaptureKit, Vision, plain-text normalization, and the same result card.
5. **Quick input and full controls**: IME, multiline input, comparison, speech, pin, target switching, shortcut recording, and permission onboarding.
6. **Experiment and productization**: public-API Force Touch feasibility, performance/memory measurement, design-skill review, compatibility matrix, and timestamped test app.

Every phase updates `STATUS.md` and affected 0.1.0 documentation when completed; documentation is not deferred to the end of the release.
