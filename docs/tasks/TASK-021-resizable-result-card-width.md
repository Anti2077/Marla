# TASK-021：可调宽度的结果卡

Status: Done

Implementation: Complete

Owner: Project owner + Agent

Created: 2026-08-10

Updated: 2026-08-11

Origin: direct project-owner request

Conversation: 2026-08-10 继续改进翻译窗口宽度

## Initial request

项目所有者要求继续改进翻译窗口：允许用户调整结果卡宽度，把当前 380pt 宽度作为最小值，最大宽度为当前宽度的两倍，即 760pt。

## Outcome

结果卡保留 380pt 紧凑初始宽度，并可通过系统窗口边缘或角落拖动在 380–760pt 范围内调整；实际最大宽度同时受当前屏幕可见工作区约束。宽度变化会重新计算译文换行和内容驱动高度，同时继续遵守 TASK-020 的锚定边稳定、60% 高度封顶与正文内部滚动策略。

## Why now

TASK-020 已解决固定高度和流式增长，但结果卡仍以固定 380pt 宽度创建，长行、代码或需要更多横向阅读空间的译文只能通过增加高度展示。当前 `NSPanel` 没有 `.resizable`，布局上下文也把结果卡宽度保存为创建时常量。

## In Scope

- 结果卡初始和最小宽度保持 380pt。
- 结果卡最大宽度为 760pt；屏幕较窄时再限制到当前可见工作区可容纳的宽度。
- 用户可从系统窗口边缘或角落拖动调整宽度，不新增常驻宽度滑块或设置项。
- 宽度变化后重新计算译文换行、正文视口和结果卡总高度。
- 保持 TASK-020 的最大高度、正文滚动、Reduce Motion、选区锚定边与指针中心降级行为。
- 快速输入初始编辑态继续使用 420pt；提交并进入结果态后复用同一 380–760pt 结果卡宽度约束。
- 增加宽度约束、窄屏上限、宽度重排和位置稳定的回归测试。
- 同步双语产品规格、UI 规格、实现说明、验收合同、Task 与 `STATUS.md`。
- 构建固定签名 Release App，检查最小/最大宽度、长文本、浅色、深色和 Reduce Motion，并执行五维 SwiftUI 设计审查。

## Out of Scope

- 允许宽度小于 380pt 或大于 760pt。
- 新增持久化宽度偏好、宽度预设、滑块或设置页选项。
- 改变字体、颜色、语言菜单、操作按钮、翻译协议或 Provider 行为。
- 改变快速输入编辑态的 420pt 初始宽度。
- 改变当前屏幕可见工作区 60% 的高度上限。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-10 | Project owner | 允许调节宽度，以当前 380pt 为最小值、两倍 760pt 为最大值 | 新增 AppKit resize、宽度约束、内容重排、真实最小/最大宽度验收 | Pending |
| 2026-08-10 | Necessary support | 最大宽度同时受当前屏幕可见工作区约束，宽度变化后重算内容驱动高度 | 增加窄屏和宽度后高度重排测试，保留现有高度与锚定策略 | Pending |
| 2026-08-10 | Project owner | 第一版边缘无法拖动；补充命中区后，横向 resize 光标仍只闪一下 | 不能把 `.resizable` 或父容器命中测试视为真实交互通过；必须让透明手柄位于 SwiftUI 内容上方并由项目所有者复验 | Implemented; owner retest pending |
| 2026-08-10 | Necessary support | 无边框非激活面板改用左右各 8pt 的顶层透明 AppKit 手柄，角落包含在完整高度命中区内 | 增加首击、顶层命中和左右边缘几何回归测试；保留纯横向 resize | Implemented; owner retest pending |
| 2026-08-10 | Project owner | 首个顶层透明手柄构建既不再显示横向光标，也仍不能调整宽度 | 该构建不满足真实交互验收；手柄必须在每次布局后重新贴合边缘，并持续持有光标与拖动事件 | Implemented; owner retest pending |
| 2026-08-10 | Necessary support | 为手柄增加 active-always tracking area，在布局时刷新 hosting view 与左右命中 frame，并恢复结果面板背景拖动 | 增加布局后边缘命中和容器拖动断言；重建、稳定签名并完整退出旧进程后启动固定 App | Implemented; owner retest pending |
| 2026-08-10 | Project owner | 最新构建已可拖动调整宽度，但鼠标仍保持普通箭头 | 宽度交互从不可用推进为可用；真实光标反馈仍未验收，不能关闭 Task | Implemented; owner retest pending |
| 2026-08-10 | Necessary support | 手柄同时接管 `cursorUpdate`、连续 `mouseMoved` 和拖动期间光标设置，结果面板开启 mouse-moved 事件 | 增加 tracking options 与面板事件设置回归断言；再次构建、签名并重启固定 App | Implemented; owner retest pending |
| 2026-08-10 | Project owner | 再次确认宽度可拖动，但光标仍不变 | 视图级 cursor 反馈仍被 AppKit/SwiftUI 事件结束后的箭头重置覆盖；继续保持真实光标验收未通过 | Implemented; owner retest pending |
| 2026-08-10 | Necessary support | 增加仅在结果卡显示期间启用的面板级本地/全局 mouse-moved 监视器，并在事件分发后异步重设光标 | 监视器按面板边缘屏幕坐标判断左右 8pt 区域，隐藏面板时移除并恢复箭头；需项目所有者复验最终光标 | Implemented; owner retest pending |
| 2026-08-11 | Necessary support | 非激活面板在部分事件循环中不稳定派发悬停事件；增加 50ms 主线程轮询，并保留隐藏标题栏的原生 titled/resizable 几何 | 轮询只在可调结果卡显示期间运行；实机复验确认左右边缘持续显示横向光标且仍可拖动 | Implemented |
| 2026-08-11 | Project owner | 复验最新固定 App：左右边缘光标可显示，宽度可拖动 | 关闭 TASK-021 的真实光标与拖动验收 | Accepted |
| 2026-08-11 | Project owner | 同一最新固定 App 的横向光标短暂可用后再次失效 | 撤回光标完成判定；确认唯一运行进程和产物时间后继续修复，必须覆盖多次结果卡替换与长期悬停复验 | Reopened |
| 2026-08-11 | Project owner | 复验 16ms `NSCursor.set()` 兜底版本，横向光标依旧不显示 | 证明高频重设仍会被窗口内重叠 cursor rectangles 覆盖，不能继续增加轮询频率或事件监视器 | Rejected |
| 2026-08-11 | Necessary support | 按 Apple 文档改为边缘期间独占光标：暂时停用窗口 cursor rectangles，离开后立即启用并重建完整映射 | 增加所有权幂等与恢复回归测试；重建、稳定签名并启动唯一固定 App，等待项目所有者长期实机复验 | Implemented; owner retest pending |
| 2026-08-11 | Project owner | 复验 PID 10694 的 Carbon `SetThemeCursor` 版本，横向光标仍不显示 | `noErr` 只证明调用返回成功，不能证明 WindowServer 采用该光标；该方案撤回 | Rejected |
| 2026-08-11 | Necessary support | Apple 文档确认 `invalidateCursorRects(for:)` 只在 key window 立即重建；改为顶层 AppKit handle 在 `resetCursorRects()` 中注册 frame-resize 光标，并由窗口直接重建 | 删除 Carbon、16ms 轮询、手工 `NSCursor.set()` 和 cursor-rectangle 禁用；增加非 key 面板立即注册、原生光标类型和顶层命中回归测试 | Implemented; owner retest pending |
| 2026-08-11 | Project owner | Agent 触发的 `activate: true` streaming 窗口横向光标持续正常，真实划词 `activate: false` 窗口持续失败 | A/B 排除构建、拖动命中和光标资源，根因收敛为非激活结果 Panel 的 key 状态；增加同路径自动场景和 hover key 交接 | Implementing |
| 2026-08-11 | Project owner | 复验 active-always hover/key 交接版本：真实划词结果窗口的横向光标与宽度拖动均正常 | 完成非激活路径、光标、拖动、源应用焦点和多次结果替换的最终实机验收 | Accepted |
| 2026-08-11 | Necessary support | 最终清理审计删除已拒绝方案的残留状态、事件开关、测试钩子与无用几何 API | 重新执行统一检查、Release 打包、源码引用/诊断检查和真实窗口截图复核 | Verified |
| 2026-08-11 | Project owner | 真实流式译文在未达到 60% 高度上限时，默认高度和后续增长仍各少一小段，正文底部、分隔线或操作行会被截住 | 重新打开本 Task；增加真实 SwiftUI/AppKit 布局与高度模型的对照测试，修正非封顶状态的内容高度，不改变 60% 上限 | In progress |
| 2026-08-11 | Necessary support | 流式高度动画与首次出现动画同时进行时，连续 delta 可能留下过时的窗口外框；用户拖宽触发立即布局后又恢复 | 在每次高度动画完成后按当前会话和实时宽度执行一次无动画最终校正；只允许最新 resize generation 生效，并用 40ms 非激活自动场景覆盖入场竞态 | Implemented; verified |

## Current evidence

- 当前工作树保留已完成但未提交的 TASK-020 改动；本 Task 在同一对话和工作树上接续，不重置或覆盖这些文件。
- `ResultCardLayout` 已集中定义 380pt 默认/最小宽度、760pt 最大宽度、窄屏上限和内容高度重排；`PanelPlacementCalculator` 对可调结果卡使用完整 380–760pt 范围，同时保留其他面板既有范围。
- `ResultCardLayout.measuredTextHeight` 以实际渲染行高补足 AppKit 字符串边界测量与 SwiftUI `Text` 的差值；结果卡的真实 `NSHostingView` 回归测试确认非封顶译文视口完整容纳渲染文本。
- `FloatingPanelCoordinator` 已把实时宽度写入 `ResultPanelLayoutModel`，宽度变化后重新计算译文换行与面板高度；程序化高度更新不会把宽度重置到 380pt。
- `FloatingPanelCoordinator` 的高度动画完成回调现在读取最新 `TranslationSessionStore` 会话和 `ResultPanelLayoutModel.width`，以最新 generation 做一次无动画 frame reconciliation；旧 delta 的完成回调不能覆盖较新的结果，Reduce Motion 和用户 live resize 仍直接采用目标 frame。
- 第一版只为无边框 `NSPanel` 增加 `.resizable`，项目所有者真实试用确认边缘无法拖动。第二版由父内容视图声明 8pt cursor rect 与 hit-test，项目所有者又确认横向 resize 光标只闪一下，说明铺满窗口的 SwiftUI hosting view 会重新取得光标/鼠标命中。
- 项目所有者先后确认 16ms `NSCursor.set()` 与 PID 10694 的 Carbon `SetThemeCursor` 版本都不显示横向光标。Apple 官方文档给出完整原因链：`.activeAlways` 不支持 `.cursorUpdate`；`NSCursor.current` 只是本应用的 cursor stack，可能不是屏幕可见光标；最关键的是 `invalidateCursorRects(for:)` 只在窗口成为 key 时立即重建，而真实划词结果刻意使用 `.nonactivatingPanel`。
- 当前修复保留隐藏标题栏的 `titled + fullSizeContentView` 原生窗口几何，在 SwiftUI hosting view 上方放置左右各 8pt 的 `ResultPanelHorizontalResizeHandleView`。每个手柄只在自己的 `resetCursorRects()` 中通过 `addCursorRect` 注册光标，macOS 15+ 使用专门的 `NSCursor.frameResize(position:directions:)`，macOS 14 回退到横向 resize 光标。手柄同时接管首击和 mouse-down/drag/up，宽度计算继续复用 380–760pt 与可见工作区约束。
- `ResultPanelContentView` 在装载、布局和可调状态变化后直接调用窗口 `resetCursorRects()`，让非 key 面板立即清除并重建全部 view cursor rectangles；不再依赖等待 key window 的 `invalidateCursorRects(for:)`。Carbon、16ms/50ms 轮询、事件监视器、`NSCursor.set()/push()/pop()` 与 `disableCursorRects()` 均已从当前路径移除。
- 激活自动场景与真实划词完成决定性 A/B：前者的 `activate: true` 会执行 `NSApp.activate` 和 `panel.makeKey()`，横向光标持续正常；后者的 `activate: false` 不执行这两步，横向光标持续失败。当前修复为左右 handle 增加 `.mouseEnteredAndExited + .activeAlways + .inVisibleRect` tracking；鼠标进入时只让 `.nonactivatingPanel` 临时成为 key 并重建 cursor rect，绝不激活 Marla，离开或拖动结束后仅在原应用仍为前台时重新确认其激活状态。
- 新增 `streaming-nonactivating` 自动化场景，以相同 fixture 明确调用 `showResult(..., activate: false)`，不再用激活窗口代替真实划词路径的光标验收。
- 既有宽度/光标回归覆盖左右顶层命中、非 key 面板立即执行 cursor-rectangle 注册、macOS 15 frame-resize 光标类型、相反边固定、380/760pt、窄屏上限、宽度重排和高度/锚定策略；本轮新高度竞态结果见下一条验证记录。
- 新增的高度回归场景在结果卡出现后 40ms 注入长译文，覆盖首次 160ms 入场动画与流式高度动画重叠的竞态；真实 `NSHostingView` 测试、17 项 Rust、80 项 MarlaApp 与 13 项 MarlaCore 测试通过，`./scripts/check.sh` 的 Swift Package、Xcode Debug、格式/空白/diff 阶段均通过。固定 Release 已重新打包并通过 Bundle ID、版本、最低系统、arm64、稳定签名与 designated requirement 验证；LaunchServices 生成的非激活竞态截图 `/private/tmp/marla-task-021-height-race-final.png` 显示译文、分隔线和操作行完整可见。
- 项目所有者在真实划词结果窗口 PID 13797 上确认横向光标和宽度拖动正常。最终 09:42:12 固定签名 Release 又通过 LaunchServices 以 `streaming-nonactivating` 启动为 PID 14749；Core Graphics 确认 Window ID 10078 为 380×224pt，窗口级临时截图 `/private/tmp/marla-task-021-final-window.png` 通过最终视觉复核。测试场景环境变量已清除。
- 清理审计确认结果面板路径中不再包含 Carbon 光标、16ms/50ms 轮询、面板级 mouse-moved 监视器、手工 cursor stack、cursor-rectangle 禁用、测试专用注册计数或废弃的窗口外命中 API。生产辅助类型均有运行时引用和针对性测试，三份变更 Swift 文件无 Serena 诊断。
- 项目所有者提供的 10:05 真实截图显示：流式结果仍低于 60% 上限，但译文底部已经进入分隔线/操作区，说明当前内容高度模型或增长时序仍少算一小段；不能通过提前启用内部滚动或提高最大高度掩盖该偏差。
- 现有 UI 风格为 Restrained Native · Warm Minimal；系统边缘拖动最符合原生工具窗口习惯，也不会给紧凑卡片增加常驻控件。

## Proposed approach

把结果卡宽度约束集中到 `ResultCardLayout`，并让 AppKit 面板保留 `.resizable` 和 min/max 尺寸约束。结果面板使用隐藏标题栏的 `titled + fullSizeContentView` 组合；SwiftUI hosting view 上方的左右 8pt AppKit 手柄拥有最顶层命中、首击、frame-resize cursor rectangle 与横向拖动。手柄在 `resetCursorRects()` 中注册当前平台的窗口框架 resize 光标，并用 `.mouseEnteredAndExited + .activeAlways + .inVisibleRect` 追踪非激活窗口的边缘悬停；进入时只让 `.nonactivatingPanel` 临时成为 key 并重建 cursor rect，不激活 Marla，离开或拖动结束后只为仍处于前台的原应用重新确认激活状态。该方案不使用 Carbon、定时轮询、面板级事件监视器、全局 `NSCursor.set()/push()/pop()` 或临时禁用 cursor rectangles。协调器继续监听结果面板尺寸变化，把约束后的实时宽度写回可观察布局状态；SwiftUI 结果卡使用实时宽度重新测量译文，协调器据此更新窗口高度。程序化高度调整和用户宽度调整必须区分，避免反馈循环或窗口跳回初始宽度。窗口位置继续根据既有锚定模式保持靠近选区的一边或指针中心，并限制在当前可见工作区。

## Acceptance criteria

- [x] 新结果卡以 380pt 打开，用户无法把它缩到 380pt 以下。
- [x] 用户可把结果卡加宽到 760pt，且无法超过 760pt；较窄屏幕的实际最大宽度不超出可见工作区。
- [x] 用户拖动系统窗口边缘或角落即可调整宽度，无需新增常驻宽度控件；左右边缘会长期稳定显示横向 resize 光标，多次替换结果卡后仍不失效。
- [x] 宽度变化后译文按新行宽重新换行，总高度随内容重新计算且不抖动、不跳回 380pt。
- [x] 选区上方/下方的靠近选区边与水平位置保持合理稳定；指针降级仍保持中心并限制在可见工作区。
- [x] 结果卡仍不超过可见工作区 60% 高度，达到上限后仅正文内部滚动。
- [x] 快速输入保持 420pt 初始编辑宽度，提交后的结果态可在相同范围内调整。
- [x] Reduce Motion 下尺寸重排不执行动画。
- [x] 自动化测试覆盖 380/760pt、窄屏上限、宽度后高度重排和位置稳定。
- [x] 统一检查中的 Rust/Swift 测试、Swift Package 与 Xcode Debug 构建、固定签名 Release 打包及 `git diff --check` 通过。
- [x] 固定 Release App 的 380pt、760pt、长文本、浅色、深色和 Reduce Motion 场景完成真实截图审查，五个维度均至少 7/10。
- [x] 双语规格、实现、验收、Task 与 `STATUS.md` 同步。
- [x] 未达到 60% 最大高度时，短译文的默认窗口和每次流式增长后的窗口都完整容纳当前译文、两处分隔线与操作行，不裁切底部内容，也不提前依赖正文内部滚动；特别复验 40ms 内首个长 delta 与 160ms 入场动画重叠时，动画完成后的最终 frame 仍与当前会话一致。

## Verification

### Automated

```sh
MARLA_BUILD_CACHE_ROOT=/private/tmp/marla-task-021-cache ./scripts/check.sh
```

当前结果：17 项 Rust、80 项 MarlaApp 与 13 项 MarlaCore 测试、Swift Package 和 Xcode Debug 构建通过；固定 Release App 通过 Bundle ID、版本、最低系统、arm64、稳定签名与 designated requirement 验证，`git diff --check` 通过。

### Manual

使用固定签名 `artifacts/Marla_dev.app` 打开结果卡，分别拖到 380pt 最小宽度和 760pt 最大宽度，确认继续拖动不会越界；以长文本检查换行和高度回流，并复核浅色、深色与 Reduce Motion。另在可用工作区小于 760pt 加安全边距的显示环境或纯布局测试中确认窄屏上限。截图遵循项目规则，仅保存在 `/private/tmp` 临时证据中。

视觉证据包括 `/private/tmp/marla-task-021-live-overlay-start-2.png`（760×448px）、`marla-task-021-overlay-max-final.png`（1520×784px）、`marla-task-021-overlay-max-dark-final.png`、`marla-task-021-overlay-max-reduce-final.png`、`marla-task-021-overlay-long-final-2.png`（760×1286px）与最终 `/private/tmp/marla-task-021-final-window.png`。五维审查为 8/8/8/8/7。项目所有者已在真实划词窗口 PID 13797 完成边缘光标、拖动、源应用焦点与多次结果替换复验；最终固定 Release 的 PID 14749 / Window ID 10078 复核了 380×224pt 初始窗口和未变化的可见渲染。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/UI_SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `docs/tasks/TASK-020-stream-growing-result-card.md`
- `Sources/MarlaApp/MarlaApp.swift`
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Sources/MarlaApp/MarlaPreviews.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors (optional)

None. AppKit 用户 resize、SwiftUI 实时宽度、内容高度和锚定位置形成同一条紧密反馈链；Task、STATUS 与双语规格由主 Agent 统一维护，拆分写入会增加竞态和文档不一致风险。

## Risks and rollback

- `NSWindow.didResizeNotification` 同时会被用户宽度拖动和程序化高度更新触发，必须防止互相递归或覆盖用户宽度。
- 非激活面板的 hover/key 交接必须继续避免激活 Marla，并只在原应用仍处于前台时重新确认其激活状态。
- 加宽导致内容高度下降时，错误的锚定处理可能让窗口跳动；布局计算必须同时覆盖增长与收缩。
- 可通过移除 `.resizable` 并恢复固定结果宽度回滚；不触碰翻译、凭据、输入获取或 Rust/FFI 数据。

## Decisions needed

None. 项目所有者已经明确最小宽度和最大倍数；使用原生窗口边缘/角落拖动是最小、可发现且不增加卡片视觉负担的实现。

## Completion record

- Verified commit: 待本次提交；项目所有者已要求完成 Task 并推送 `main`
- Automated evidence: `./scripts/check.sh` 通过 17 Rust、80 MarlaApp、13 MarlaCore、Swift Package、Xcode Debug、格式/空白与 `git diff --check`；固定签名 Release App 包、稳定签名和 designated requirement 通过；生产辅助类型引用完整，三份变更 Swift 文件无 Serena 诊断
- Manual evidence: 项目所有者在真实划词窗口 PID 13797 确认横向光标、宽度拖动、源应用焦点与多次结果替换正常；最终固定 Release 的 40ms 非激活高度竞态场景截图 `/private/tmp/marla-task-021-height-race-final.png` 为 380×346pt，译文、分隔线和操作行完整可见，五维复审为 8/8/8/9/7。项目所有者随后明确要求关闭本 Task；本次关闭依据该自动化/Release 证据，不把额外现场复验表述为独立证据。
- Documentation updated: `UX_PRINCIPLES.md`、0.1.0 `SPEC.md`/`UI_SPEC.md`/`IMPLEMENTATION.md`/`ACCEPTANCE.md`、TASK-021 与 `STATUS.md`
- Remaining work promoted to: None
- Scope changes closed: Yes
- Parallel contributions integrated: None
