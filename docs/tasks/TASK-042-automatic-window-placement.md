# TASK-042：按来源位置自动放置翻译窗口

Status: Active

Owner: Project owner + Agent

Created: 2026-09-02

Updated: 2026-09-02

Origin: direct request

Conversation: 2026-09-02 自动识别划词与截图位置并避让来源

## Initial request

从本地 `main` 新建专用分支和 Task，为翻译窗口新增“自动”出现位置。自动模式识别划词与截图的位置；截图翻译窗口在不遮挡框选区域的前提下优先出现在其右侧，并明确划词翻译的合适定位方式。

## Outcome

用户可选择新的“自动”窗口位置模式。截图结果优先出现在框选区域右侧且不覆盖该区域；划词结果优先在选区下方或上方就近出现，避免遮挡正在阅读的文字；几何信息缺失时诚实回退到鼠标附近。

## Why now

现有四种位置模式只使用统一规则，未针对截图矩形和文字选区的阅读语义优化。代码已经在会话中保留两类来源的全局屏幕坐标，本 Task 只完善原生窗口定位，不改变采集、OCR 或翻译边界。

## In Scope

- 在通用设置中新增并持久化“自动”翻译窗口位置模式，作为未保存偏好的新默认值；保留现有四种手动模式及其持久化值。
- 自动模式区分划词、截图和 Quick Input：
  - 截图优先位于框选区域右侧，窗口与框选区域至少间隔 12pt，并且两者不得相交；
  - 右侧无法容纳最小宽度时，按不相交和可用空间选择左侧、下方或上方，绝不为了坚持右侧而覆盖截图；
  - 划词优先位于选区下方、其次上方，再以左右两侧兜底，尽量保持原文可见；
  - Quick Input 与缺少可靠来源几何的划词/错误态继续在触发鼠标附近出现。
- 自动定位必须限制在可见工作区内，并正确处理屏幕边缘、超大选区与多显示器坐标。
- 流式增长继续沿选定的避让方向扩展，不因内容更新重复跳位或覆盖来源。
- 同步相关功能规格、设置测试和纯几何单元测试。

## Out of Scope

- 自动监听鼠标划词、松开鼠标即翻译或新增全局事件监听；当前仍由显式快捷键触发。
- 改变受保护 Copy、Accessibility 仅提供非内容几何、ScreenCaptureKit、OCR、翻译 Provider 或 FFI 合同。
- 实时追踪滚动后的选区、移动来源应用窗口或重新捕获屏幕。
- 原地覆盖翻译、浏览器 DOM 改写、截图像素级重建或跨显示器悬跨一个结果窗口。
- 重设计结果卡、设置页或新增定位预览控件。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-09-02 | Project owner | 新增按划词/截图位置自动避让的窗口模式，截图优先显示于框选区右侧 | 新增入口感知几何测试、设置持久化测试与真实截图/划词检查 | Implemented; owner verification pending |
| 2026-09-02 | Necessary support | 明确空间不足时的确定性非重叠回退，而不是缩小到低于最小宽度或越出屏幕 | 覆盖右侧不足、四周候选和超大来源矩形 | Implemented |
| 2026-09-02 | Necessary support | 用户主动切换为更宽预设时，当前方向若无法继续保留 12pt 间距则重新选边 | 新增保留方向与空间不足换边测试；流式更新仍不重算位置 | Implemented |

## Current evidence

- `TranslationWindowPlacement` 当前提供固定居中、跟随鼠标、固定横坐标和记住上次位置，未提供自动模式；未保存偏好时默认跟随鼠标。
- 划词成功路径把可选 `selection.bounds` 传给 `FloatingPanelCoordinator`；几何不可用时已经使用触发鼠标回退。
- 截图成功路径把 `CapturedScreenshot.globalRect` 转成 `ScreenRect` 并传给相同协调器。
- 当前 `PanelPlacementCalculator` 对所有入口使用同一锚点/鼠标规则，窗口可能覆盖大块截图区域，也未把入口类型纳入候选排序。
- TASK-034 已验证记住左上角、流式顶边锚定、宽度预设和子窗口事件路由；本 Task 必须保持这些手动模式不变。

## Proposed approach

在 Panel 层引入轻量的入口语义和纯几何自动定位器。定位器以来源矩形、目标窗口尺寸、候选显示器可见区域和 12pt 间距生成候选 frame；先按入口定义的方向优先级排序，再要求 frame 完整位于可见工作区且不与来源相交。没有完整容纳候选时，选择裁切到工作区后与来源重叠最小、可用空间最大的方向。现有 `PanelPlacementCalculator` 继续拥有四种手动模式，自动模式只在 Panel 层消费会话入口，不向 Rust 或持久化会话添加平台对象。

划词采用“下、上、右、左”的顺序，因为文字选区经常横跨一行或多行，左右余量通常更小；下方更符合从原文继续向下阅读的视线流。截图采用“右、左、下、上”的顺序，直接匹配项目所有者要求。

## Acceptance criteria

- [x] 新分支从本地 `main@0b15e4d` 创建，Task/Status 明确本轮范围。
- [x] “自动”出现在设置菜单中并成为没有既有偏好时的默认值，原有 raw value 均可继续恢复。
- [x] 截图右侧空间足够时，结果窗口完整位于框选区右侧、间隔至少 12pt 且不相交（纯几何测试已验证；真实流程待项目所有者验收）。
- [x] 截图右侧空间不足时，结果窗口选择确定性的非重叠回退；若来源占满可见工作区，结果窗口仍保持完全可见并最小化覆盖（纯几何测试已验证；真实流程待项目所有者验收）。
- [x] 划词有可靠选区时优先显示于下方，其次上方，且不遮挡选区；无可靠几何时回退鼠标附近（纯几何测试已验证；真实流程待项目所有者验收）。
- [x] Quick Input 的自动模式维持鼠标附近语义。
- [x] 多显示器和负坐标可见工作区选择正确，结果窗口不会跨出所选工作区。
- [x] 流式增长不反复重新定位；锚边选择与初始避让方向一致；主动宽度切换只在原方向无法保留间距时换边。
- [x] 原有四种手动位置、宽度预设、拖动记忆、非激活呈现和 Reduce Motion 行为通过现有自动化回归；真实自动位置流程待项目所有者验收。
- [x] 定向测试和 `./scripts/check.sh` 通过，新增代码不突破结构门禁。
- [ ] 固定签名 Release App 已重建，设置页浅色/深色五维复审每项至少 7/10；真实划词/截图相对位置仍待项目所有者验收。
- [x] 相关规格、架构和 `STATUS.md` 与已验证状态同步。

## Verification

### Automated

```sh
swift test --filter AutomaticPanelPlacement
swift test --filter TranslationWindowPlacement
./scripts/check.sh
./scripts/build-test-app.sh
```

### Manual

- 在一个普通文字应用中分别选择单行、屏幕底部单行和多行文字，触发 `⌃⇧D`，确认窗口优先下/上且不遮挡选区。
- 在屏幕中央、右边缘和接近全屏的位置分别框选截图，触发 `⌃⇧S`，确认右侧优先与非重叠回退。
- 在浅色、深色和 Reduce Motion 下检查固定 App；证据写入 `artifacts/ui-review/task-042/`。
- 五维复审使用既有功能型 Paper Lantern 视觉语言，不因新增菜单项重做设置页或结果卡。

### Recorded evidence

- `swift test --filter AutomaticPanelPlacement`：10/10 通过，覆盖入口优先级、右侧不足回退、超大来源最小覆盖、多显示器、负坐标/指针回退、增长上限和宽度预设换边。
- `swift test --filter TranslationWindowPlacement`：1/1 通过。
- `./scripts/check.sh`：通过；包括 24 项 Rust 测试、完整 Swift 测试、SwiftPM/Xcode Debug 构建、结构/脚本/空白检查和 `git diff --check`。
- `./scripts/build-test-app.sh`：通过；固定 App 为 `artifacts/Marla_dev.app`，Bundle ID `com.marla.app`、开发占位版本 `0.0.0`、macOS 14+、arm64、稳定本地签名 `API Usage Monitor Dev` 和 designated requirement 均已验证。
- 设置页浅色/深色截图：`artifacts/ui-review/task-042/settings-automatic-light.png`、`artifacts/ui-review/task-042/settings-automatic-dark.png`。
- 设置入口五维复审：理念一致性 8/10、视觉层级 8/10、工艺质量 8/10、功能性 9/10、原创性 7/10；新增菜单项保持现有功能型 Paper Lantern 语言，浅/深色均无溢出或重叠。
- Computer Use 无法枚举无主窗口的 LSUIElement App 并超时，因此没有把自动化截图当作真实划词/截图相对位置证据；下列真实流程仍待项目所有者验收。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/development/VERSIONING.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/DATA_CONTRACTS.md`
- `docs/features/inline-translation.md`
- `docs/features/screenshot-translation.md`
- `docs/features/quick-input.md`
- `docs/tasks/TASK-034-history-plain-text-window-placement.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `docs/architecture/decisions/ADR-0006-selection-copy-compatibility.md`
- `Sources/MarlaApp/Settings/TranslationWindowPlacement.swift`
- `Sources/MarlaApp/Persistence/MarlaSettingsStore.swift`
- `Sources/MarlaApp/App/MarlaApplicationModel.swift`
- `Sources/MarlaApp/App/ScreenshotTranslation.swift`
- `Sources/MarlaApp/Panel/FloatingPanel.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors (optional)

None. Task 文档、规格、定位代码和同文件测试高度耦合，本轮由主 Agent 单独维护写入所有权。

## Risks and rollback

- 大型来源矩形可能没有任何完全不相交的可见位置；此时定位器必须保持窗口可见并最小化覆盖，不能承诺物理上不可能的零覆盖。
- 不正确的增长锚边会让初始不相交窗口在流式增长后侵入来源；用方向映射和增长测试约束。
- 新默认值只影响从未保存位置偏好的用户；已有持久化 raw value 保持原行为。回滚时删除 `.automatic` 分支并恢复默认 `.followMouse` 即可，不迁移或清除用户数据。

## Decisions needed

None. 项目所有者已明确授权自动模式；空间不足的回退和划词下/上优先是为满足“不遮挡”与阅读连续性所需的实现细化。

## Completion record

- Verified commit:
- Automated evidence: 定向自动布局 10/10、设置持久化 1/1、完整 `./scripts/check.sh`、固定 Release App 构建均通过。
- Manual evidence: 设置页浅色/深色截图和五维复审通过；真实划词/截图相对位置待项目所有者验收。
- Documentation updated: `STATUS.md`、架构说明及划词/截图/Quick Input 功能规格已同步。
- Remaining work promoted to:
- Scope changes closed: 实现项已关闭；项目所有者现场验收待完成。
- Parallel contributions integrated: None
