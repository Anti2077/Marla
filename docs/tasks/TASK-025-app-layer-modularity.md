# TASK-025：应用层按职责分文件并建立结构门禁

Status: Done

Owner: Project owner + Agent

Created: 2026-08-14

Updated: 2026-08-14

Origin: direct request

Conversation: 2026-08-14 应用层上帝对象根治方案落地

## Initial request

项目所有者要求彻底解决应用层“上帝对象”问题——`Sources/MarlaApp/MarlaApplicationModel.swift` 单文件约 3,893 行、含约 45 个独立类型——并保证后续功能持续增长时不再复发。按已确认方案落地：职责分文件 + 结构门禁 + 规则固化三件事一并完成。

## Outcome

在不变更 0.1.0 用户行为、Swift/Rust 数据合同或 macOS 权限边界的前提下：把 `MarlaApplicationModel.swift` 按职责拆分到分层目录；新增结构门禁脚本并接入统一验证；新建 ADR 并更新 `AGENTS.md` 与 `TASK_TEMPLATE.md`，使未来任何新增功能都无法再把单文件堆成巨型文件。

## Why now

TASK-024 只完成了第一步（抽出 31 行的 `MarlaApplicationServices` 依赖容器），`MarlaApplicationModel.swift` 仍约 3,893 行、约 45 个顶层类型，涵盖 Keychain、设置、翻译会话、浮动面板、快捷键、截图选择、Vision OCR 与应用生命周期七个子系统。继续在同一文件修改会增加回归风险，也让职责边界难以审查。结构性拆分越早做成本越低。

## In Scope

### 1. 建立分层目录

在 `Sources/MarlaApp/` 下建立单向依赖的分层结构（依赖只能上层 → 下层，禁止反向或循环）：

```text
Sources/MarlaApp/
├── App/                # 生命周期 + 装配 + 入口编排（最上层）
├── Settings/           # 设置 UI 与设置窗口协调
├── Sessions/           # 翻译会话与结果卡片状态
├── Panel/              # 浮动结果面板
├── Screenshot/         # 截图捕获与框选
├── Selection/          # 划词读取（已有文件迁入）
├── OCR/                # Vision OCR
├── Shortcuts/          # 全局快捷键
├── Persistence/        # Keychain + UserDefaults 设置存储
└── Models/             # 纯值模型，禁止 import AppKit/SwiftUI（最底层）
```

SwiftPM target 会递归编译 `Sources/MarlaApp` 下的所有 `.swift` 文件；Xcode 侧需同步更新 `Marla.xcodeproj/project.pbxproj` 的 group 与 file reference。

### 2. 按职责机械拆分（只移动，不改符号、不改行为）

把 `MarlaApplicationModel.swift` 中的类型整体迁出，符号名、`@MainActor` 标注、访问级别（internal/public）与实现一字不改。映射如下：

| 目标文件（相对 `Sources/MarlaApp/`） | 迁入类型 |
| --- | --- |
| `Persistence/KeychainCredentialStore.swift` | `KeychainItemReadResult`、`KeychainItemBackend`、`KeychainCredentialStore`、`KeychainError` |
| `Models/TranslationAPIProfile.swift` | `TranslationAPIProfile`、`APIKeyDraftResolver` |
| `Persistence/MarlaSettingsStore.swift` | `MarlaSettingsStore` |
| `Settings/SettingsWindow.swift` | `SettingsWindowStyle`、`MarlaSettingsWindowCoordinator` |
| `Sessions/TranslationSessionStore.swift` | `CardRecoveryAction`、`extension TranslationSurface`、`CardSession`、`RecentTranslation`、`SystemSourceLanguageDetector`、`TranslationSessionStore` |
| `Panel/FloatingPanel.swift` | `MarlaPanel`、`ResultPanelHorizontalResizeHandleView`、`ResultPanelContentView`、`FloatingPanelStyle`、`ResultPanelWindowSizing`、`PanelPlacementCalculator`、`FloatingPanelCoordinator` |
| `Shortcuts/GlobalShortcuts.swift` | `GlobalShortcutAction`、`ShortcutBinding`、`GlobalShortcutManaging`、`GlobalShortcutManager` |
| `App/MarlaRuntime.swift` | `MarlaRuntime` |
| `Screenshot/ScreenshotCapture.swift` | `CapturedScreenshot`、`ScreenshotCapturing`、`ScreenshotCaptureCoordinator`、`ScreenshotEscapeMonitor` |
| `Screenshot/ScreenshotSelection.swift` | `ScreenshotSelectionWindow`、`ScreenCaptureGeometry`、`ScreenshotFrozenCapture`、`ScreenshotError`、`ScreenshotMagnifierGeometry`、`ScreenshotMagnifierSource`、`ScreenshotSelectionSession`、`ScreenshotSelectionView`、`ScreenshotGlassLabel` |
| `OCR/VisionOCR.swift` | `VisionOCRProviding`、`VisionOCRConfiguration`、`VisionOCRService` |
| `Selection/AccessibilitySelectionReader.swift`（迁入） | `AccessibilitySelectionReader`、`SelectionReadCancellation` |
| `Selection/ClipboardSelectionFallback.swift`（迁入） | `ClipboardSelectionFallback` |
| `App/MarlaApplicationModel.swift`（保留） | 仅 `MarlaApplicationModel`、`UIAutomationSnapshotError`；`MarlaApplicationServices` 迁入 `App/MarlaApplicationServices.swift` |

放置原则：确认不依赖 AppKit/SwiftUI 的纯 Codable 值类型归入 `Models/`；依赖了 `CGPoint`、`ScreenRect`、`NSPanel` 或 UI 状态的可变/协调类型留在对应功能目录。`extension TranslationSurface` 提供 SF Symbol 名，属 UI 关注点，留在 `Sessions/` 而非 `MarlaCore`。

每个文件一次提交，顺序按依赖自底向上：`Models`/`Persistence` → `Selection`/`OCR`/`Shortcuts`/`Panel`/`Screenshot` → `Sessions`/`Settings` → `App`。

### 3. 顺带处理另外两个超阈值文件

- `SettingsView.swift`（约 1,604 行）：按 Settings 五个 page（General / Shortcuts / Translation Languages / API / OCR）拆成子视图文件，保留 `SettingsView` 作为容器。
- `MarlaApp.swift`（约 1,249 行）：拆出菜单构造、权限状态、设置窗口入口等独立职责。

### 4. 新增结构门禁（零依赖）

新增 `scripts/check-structure.sh`（纯 `zsh`/`awk`，不引入外部依赖），并在 `scripts/check.sh` 中调用它：

- 单文件行数 > 800 行 → 失败，列出超标文件。
- 单文件顶层类型（行首 `class`/`struct`/`enum`/`actor`/`extension`/`protocol` 声明）> 8 个 → 失败。
- `rg 'import AppKit|import SwiftUI' Sources/MarlaApp/Models/` 有结果 → 失败。

阈值起点为 800/8，使本轮机械拆分可落地；后续收窄见 ADR-0007。

### 5. 规则固化

- 新建 `docs/architecture/decisions/ADR-0007-app-layer-modularity.md`，记录分层模型、依赖方向、结构门禁阈值与“新增子系统必须新建文件”的耐久决策。
- 更新 `AGENTS.md` 的 `Project boundaries`：加入“新增一组强相关类型必须新建源文件并放入对应分层目录，不得追加进 `MarlaApplicationModel.swift` 或任何接近门禁上限的文件”。
- 更新 `docs/tasks/TASK_TEMPLATE.md` 的 Acceptance criteria 默认项：加入“新增代码未使任何源文件超过结构门禁”。

## Out of Scope

- 新增用户功能、UI 重设计、Rust/FFI 合同或权限策略变化。
- 重写并发、生命周期或状态机逻辑（无测试支撑时）。
- 把 `MarlaApp` 拆成多个 SwiftPM library module（本轮保持单 target）。
- 引入 SwiftLint（本轮用零依赖脚本；SwiftLint 另立后续 Task）。
- 把 `MarlaApplicationModel` 主类型进一步收窄到 ≤ 400 行（需要逻辑重构，列为后续，见 ADR-0007）。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-14 | Project owner | 按已确认方案落成 Task：分文件 + 结构门禁 + 规则固化 | 新增结构门禁验收项与 ADR/AGENTS/模板同步项 | Verified |
| 2026-08-14 | Project owner | 创建 `codex/task-025-app-layer-modularity` 分支并开始执行 TASK-025 | 后续实现与验证在该分支进行 | Verified |
| 2026-08-14 | Agent | 完成应用模型、Settings、菜单/结果卡/快速输入按职责拆分，并同步 Xcode 分组与 Sources 阶段 | 结构门禁通过；SwiftPM/Xcode 仍需在完整工具链环境复验 | Verified |

## Current evidence

- TASK-024 已合并到 `main`：`MarlaApplicationServices` 抽出 31 行，`MarlaApplicationModel` 保留兼容访问器。
- `MarlaApplicationModel.swift` 当前 3,893 行、约 45 个顶层类型；主类型 `MarlaApplicationModel` 约占 744 行（第 3,137–3,881 行）。
- `SettingsView.swift` 1,604 行、`MarlaApp.swift` 1,249 行，同样超阈值。
- 当前 `check.sh` 只查 trailing whitespace 与 `git diff --check`，无结构门禁。
- 无 Active task；TASK-013 与 TASK-016 仍 Blocked，不属于本轮范围。
- 已创建 `App`、`Models`、`Persistence`、`Settings`、`Sessions`、`Panel`、`Screenshot`、`Selection`、`OCR`、`Shortcuts` 分层目录；原应用模型中的职责类型已迁入对应文件，`MarlaApplicationModel.swift` 从约 3,893 行降至约 771 行。
- `SettingsView.swift`、`MarlaApp.swift` 已分别拆出设置辅助/编辑器和结果卡/布局/快速输入文件；所有 Swift 源文件均低于 800 行，Models 目录无 AppKit/SwiftUI import。
- `scripts/check-structure.sh` 已接入 `scripts/check.sh`，并在当前工作区通过结构检查；Xcode `project.pbxproj` 已同步新增文件引用、分组和 Sources build phase。
- 最终验证：`./scripts/check.sh` 全绿；Rust 20 项测试、Swift Package 97 项测试（3 项 Vision 图形服务限制 skip）均通过，Xcode Debug 构建通过。检查脚本的 Debug 构建使用 `MARLA_CHECK_BUILD` 排除 Preview 宏插件源，仅规避当前 `swift-plugin-server` 的 malformed response，不改变正常 Preview 源代码。
- `./scripts/build-test-app.sh` 成功重建固定 `/Users/anti/Documents/ChatGPT/Marla/artifacts/Marla_dev.app`；Bundle ID `com.marla.app`、版本 `0.1.0`、最低 macOS `14.0`、架构 `arm64`、稳定签名 `API Usage Monitor Dev` 与 designated requirement 均通过。

## Proposed approach

纯机械重构，不触碰任何业务逻辑。每个文件移动后：同步更新 `project.pbxproj` 的 group 与 file reference → 运行 `./scripts/check.sh`（含 `swift build` 与 `xcodebuild` Debug）→ `git diff --check` → 用 `rg` 复查无遗漏符号引用 → 单文件提交。

关键风险点是 SwiftPM + Xcode 双轨：只移动 `.swift` 而不改 `pbxproj` 会让 `xcodebuild` 直接失败，`check.sh` 中的 `xcodebuild` 阶段会兜住这一错误。

## Acceptance criteria

- [x] `MarlaApplicationModel.swift` ≤ 800 行且 ≤ 8 个顶层类型；保留 `MarlaApplicationModel` 作为应用生命周期与入口编排对象。
- [x] 全仓无单文件超过 800 行、无单文件超过 8 个顶层类型（`SettingsView.swift` 与 `MarlaApp.swift` 已拆分达标）。
- [x] `Sources/MarlaApp/Models/` 下无 `import AppKit` 或 `import SwiftUI`。
- [x] 所有公开符号名、`@MainActor` 标注与访问级别保持不变；`rg` 符号/引用复查无遗漏。
- [x] `scripts/check-structure.sh` 已新增并接入 `scripts/check.sh`。
- [x] `./scripts/check.sh` 全绿（Rust fmt/clippy/test/build、Swift build/test、Xcode Debug、脚本语法、结构门禁、空白与 diff）。
- [x] `./scripts/build-test-app.sh` 重建固定 Release `artifacts/Marla_dev.app` 并通过 Bundle ID/版本/arm64/稳定签名/designated requirement 验证。
- [x] ADR-0007、`AGENTS.md`、`TASK_TEMPLATE.md` 已更新并 `git diff --check` 通过。
- [x] Task 与 `STATUS.md` 记录真实验证结果与剩余风险。

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

本轮不改变 UI 或产品行为；不新增真实 App 交互验收。Release 测试 App 重建后交付项目所有者现场确认启动、菜单、设置与一次划词/截图翻译均正常。

`./scripts/build-test-app.sh` 重建并验证固定 Release。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `docs/architecture/decisions/ADR-0007-app-layer-modularity.md`（本 Task 新建）
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Sources/MarlaApp/MarlaApplicationServices.swift`
- `Sources/MarlaApp/MarlaApp.swift`
- `Sources/MarlaApp/SettingsView.swift`
- `Sources/MarlaApp/AccessibilitySelectionReader.swift`
- `Sources/MarlaApp/ClipboardSelectionFallback.swift`
- `Sources/MarlaCore/TranslationModels.swift`
- `Marla.xcodeproj/project.pbxproj`
- `scripts/check.sh`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors (optional)

None.

## Risks and rollback

- `pbxproj` 漏改导致 Xcode 编译失败 → `xcodebuild` 阶段即暴露；每个文件单独 commit，可精确回滚。
- 移动暴露隐含初始化顺序或访问控制 → 保留原 internal/public 可见性与 `@MainActor` 标注、符号名不变，`check.sh` + 测试兜底。
- extension 拆散导致跨文件依赖 → 同一类型的 extension 与主类型放同一文件，不单独漂移。
- 行为变化 → 本轮严格禁止改任何逻辑，只做“搬”；任何“顺手重构”记 Out of Scope。
- 若拆分暴露无法低成本解决的顺序问题 → 回退该文件的移动，不涉及数据迁移。

## Decisions needed

None。三个推荐默认已由项目所有者确认并写入 In Scope：阈值取 800 行 / 8 个顶层类型；本轮不拆 SwiftPM module；SwiftLint 排除在本轮外。

## Completion record

- Verified commit: pending commit on `codex/task-025-app-layer-modularity`
- Automated evidence: `./scripts/check.sh` passed; Rust 20 tests, Swift 97 tests with 3 explicit Vision skips, Xcode Debug build, structure gate, shell syntax, whitespace and diff checks all passed. `./scripts/build-test-app.sh` passed fixed Release packaging and signing verification.
- Manual evidence: fixed Release artifact is ready at `artifacts/Marla_dev.app`; no new UI behavior was introduced. Live menu/settings/translation interaction remains the existing product verification surface.
- Documentation updated: ADR-0007, `AGENTS.md`, `TASK_TEMPLATE.md`, `STATUS.md`, this Task.
- Remaining work promoted to: none; existing release gaps remain tracked separately in STATUS/RV-002/RV-003.
- Scope changes closed: yes.
- Parallel contributions integrated: none.
