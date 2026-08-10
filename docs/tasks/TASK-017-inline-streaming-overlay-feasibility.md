# TASK-017：单行原位流式覆盖可行性原型

Status: Cancelled — removed by project-owner decision in TASK-019

Implementation: Removed

Owner: Project owner + Agent

Created: 2026-08-10

Updated: 2026-08-10

Origin: IDEA-002 / direct request

Conversation: 2026-08-10 开始尝试 IDEA-002

## Initial request

项目所有者要求创建新分支并开始尝试 IDEA-002“原位流式覆盖翻译”。

## Outcome

Marla 曾获得一个默认关闭、可随时退出的单行静态选区覆盖原型：可靠几何满足保守条件时，译文在原选区位置流式出现；缺少 bounds 的短单行使用明确标记“附近”的鼠标旁译文条。项目所有者真实试用后认为两种表现都不理想，并在 TASK-019 中要求完整删除；当前划词翻译只使用既有完整附近结果卡。

## Why now

IDEA-002 已记录原位覆盖可以进一步减少视线移动，但也明确指出它依赖可靠的选区几何、背景遮盖、滚动生命周期和多行退化。项目所有者现在选择先在独立分支验证最小切片，而不是直接承诺完整产品行为。

## In Scope

- 新增默认关闭的“单行原位覆盖”实验开关，继续复用现有划词快捷键和翻译请求。
- 对有可靠 bounds、单行文本、合理宽高且完整落在一个可见屏幕区域内的选区启用精确原位覆盖。
- Copy compatibility 无法提供 bounds 时，短单行文本使用选区触发时的鼠标位置显示轻量“附近”译文条；该表面必须明确标记为近似定位，不冒充精确覆盖。
- 在不激活 Marla、不修改源应用内容的前提下，用独立视觉层流式显示译文。
- 用户可将原位覆盖展开为现有完整结果卡；失败状态自动回到完整结果卡。
- 对多行、过长、尺寸异常、跨屏或屏幕边缘选区自动使用现有完整结果卡。
- 原位覆盖在 `Esc`、源应用内外部点击或滚动时关闭；不尝试跟随滚动重排。
- 增加可确定验证的布局、资格判定、设置持久化和 UI 验收场景，并同步相关规格、IDEA 与状态文档。

## Out of Scope

- 修改网页 DOM、TextKit 内容或任何源应用文本。
- 多行逐行覆盖、背景颜色采样、字号/字重精确复刻、滚动实时跟随和窗口重排跟踪。
- 截图翻译、快速输入、最近翻译或正式 0.1.0 默认呈现行为的改变。
- 新的 Rust 请求、FFI、Provider、上下文采集或持久化数据。
- Force Touch 入口与悬停自动翻译。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-10 | Project owner | 创建新分支并开始尝试 IDEA-002 | 建立独立 feasibility Task；实现保守单行原型并保留附近卡片回退 | In progress |
| 2026-08-10 | Project owner | 开启实验功能后真实划词仍出现原 380×300 结果卡 | 真实 Copy compatibility 路径没有 bounds，推翻“首版已覆盖真实路径”的暗示；增加明确标记的鼠标附近单行译文条并修正 AX/AppKit 坐标转换 | In progress |
| 2026-08-10 | Project owner | 转而开始截图冻结覆盖改进 | TASK-017 保留当前实现并转为 Blocked，等待日后复验；新的截图范围由 TASK-018 独立跟踪 | Blocked |
| 2026-08-10 | Project owner | 真实试用后删除 IDEA-002 原位译文和另一个 Force Touch 实验 | TASK-019 删除设置、持久化状态、专用 View/面板/布局/生命周期、自动化夹具和测试；TASK-017 取消且不再等待复验 | Removed |

## Current evidence

- `TextSelection` 已携带可选的全局 `ScreenRect`；Copy compatibility 明确没有几何。项目所有者的首轮真实复验确认实验开关已保存，但触发了原 380×300 结果卡，证明首版对真实 Copy 路径的静默降级不可用。
- AX Range 与 Web Text Marker 返回的是 Accessibility/Quartz 左上角坐标，首版未经转换直接当作 AppKit 左下角坐标使用，精确定位路径同样需要修正。
- `TranslationSessionStore` 已集中维护请求 ID、流式译文、失败、取消和完成状态；原型可以复用它而不改变 Rust 或数据合同。
- `FloatingPanelCoordinator` 原先只支持 380×300 附近卡片；TASK-017 现增加复用同一 `NSPanel` 的精确和近似两种单行轻量布局。
- 当前 feature spec 和 0.1.0 architecture 都明确声明正式实现只使用附近卡片，原位覆盖被延后。
- TASK-019 已按项目所有者最终决定移除整个原型；上述证据保留为历史，不再描述当前代码基线。

## Proposed approach

在 Swift/AppKit 呈现边界增加一个纯函数式资格与布局计算器。通过后，`FloatingPanelCoordinator` 在原选区附近创建固定不移动的小型原位表面，SwiftUI 视图直接观察同一个 `TranslationSessionStore`；失败或用户展开时把同一个会话切换到现有完整卡片。开关使用非敏感 `UserDefaults` 并默认关闭。该原型不形成耐久架构决定，真实证据足够后再决定是否新增 ADR。

## Acceptance criteria

- [x] 实验开关默认关闭并可持久化；关闭时行为与当前附近卡片一致。
- [ ] 有可靠单行 bounds 的划词请求可在不激活 Marla、不修改源应用的情况下原位流式显示译文。
- [x] 无 bounds 的短单行 Copy compatibility 选择显示明确标记“附近”的轻量译文条，不再静默回退原 380×300 结果卡。
- [x] 多行、过长、尺寸异常、跨屏或超出可见区域时确定性回退完整结果卡。
- [x] 原位覆盖位置在负坐标副屏和屏幕边缘不会越出可见区域，也不会在流式更新中反复移动。
- [x] 失败自动展开完整错误卡；用户可主动展开完整结果卡。
- [ ] `Esc`、点击和滚动关闭未固定的原位覆盖，且翻译取消/释放保持现有规则。
- [x] Swift 单元测试、Swift/Xcode Debug 构建和 `git diff --check` 通过。
- [x] 固定 Release App 在浅色、深色和 Reduce Motion 下完成真实截图；SwiftUI 五维审查每项至少 7/10。
- [x] `docs/features/inline-translation.md`、`IDEAS.md`、本 Task 和 `STATUS.md` 与验证事实同步。

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

使用固定签名 Release `artifacts/Marla_dev.app`，在浅色、深色和 Reduce Motion 状态分别验证：有 bounds 的单行选区精确原位显示；无 bounds 的短单行显示明确标记“附近”的轻量条；多行、过长和不安全几何回退完整结果卡；`Esc`、点击、滚动、失败与展开行为；源应用焦点不变。截图与五维审查证据保存到 `artifacts/ui-review/task-017/`。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/features/inline-translation.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/DATA_CONTRACTS.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `Sources/MarlaApp/AccessibilitySelectionReader.swift`
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Sources/MarlaApp/MarlaApp.swift`
- `Sources/MarlaApp/SettingsView.swift`
- `Sources/MarlaCore/SelectionModels.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors (optional)

None

## Risks and rollback

- AX bounds 可能只代表联合矩形而非真实单行 glyph；资格判定保持保守。缺少 bounds 只允许短单行进入明确标记的近似模式，其余未知情况回退完整结果卡。
- 不采样源背景意味着原型无法做到视觉无缝替换；使用清晰、实色、可识别的 Marla 表面，避免伪装成源应用内容。
- 实验开关默认关闭；关闭即可完整回滚运行时行为，删除本 Task 的独立呈现层可回滚实现。

## Decisions needed

None. 项目所有者已选择退回附近结果卡并删除原型；未来若重新讨论，需要新的明确授权和 Task。

## Completion record

- Verified commit: 当前 TASK-019 分支未提交；移除工作由 TASK-019 验证
- Automated evidence: After the live fallback repair, `./scripts/check.sh` passed 17 Rust and 81 Swift tests plus Swift/Xcode Debug builds. Coverage includes default-off persistence, exact and pointer-estimate placement, Accessibility-to-AppKit coordinate conversion, negative-coordinate and visible-frame containment, conservative rejection, panel styling, and terminal expand/close transitions.
- Manual evidence: Stable-signed Release light/dark/Reduce Motion deterministic captures for exact and visibly labeled “附近” modes plus the five-dimension review are under `artifacts/ui-review/task-017/`. Real external-app selection/focus evidence and project-owner re-verification of the repaired Copy path remain pending.
- Documentation updated: `docs/features/inline-translation.md`, `docs/backlog/IDEAS.md`, `docs/development/STATUS.md`, and this Task.
- Remaining work promoted to: None；IDEA-002 已标记 Rejected
- Scope changes closed: Yes — prototype removed
- Parallel contributions integrated: None
