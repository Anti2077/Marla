# TASK-035：组合式全局快捷键编辑器与新默认键位

Status: Done

Owner: Project owner + Agent

Created: 2026-08-22

Updated: 2026-08-23

Origin: direct request / discussed BL candidate

Conversation: 2026-08-22，Fn/Globe 与组合式快捷键编辑器

## Initial request

项目所有者要求不再只用“录制整组组合键”的方式编辑全局快捷键，而是提供可单击切换的 `fn`、`⇧`、`⌃`、`⌥`、`⌘` 修饰键和一个可自行输入的主键；同时把默认键位改为划词翻译 `⌃⇧D`、截图翻译 `⌃⇧S`、快速输入 `⌃⇧Space`，创建 Task 和专用分支后直接实现。

## Outcome

快捷键设置保留紧凑的三行全局入口，点击当前组合键后直接在该行的中间留白内组合修饰键并捕获一个主键，不打开 popover、sheet 或额外窗口；确认后一次性验证和注册。新安装与恢复默认使用 `⌃⇧D / ⌃⇧S / ⌃⇧Space`；Fn/Globe 作为可选修饰键接入现有 Carbon 全局热键路径，并对注册失败提供不破坏旧绑定的明确反馈。

## Why now

当前录制器只能监听一次完整 `keyDown`，用户无法清楚地组合或修正单个修饰键。快捷键数据与 Carbon 注册已经集中在 Swift 应用层，适合在不改变翻译、OCR、Rust 或窗口行为的前提下改善设置体验，并验证平台已暴露但当前尚未转换的 Fn 修饰位。

## In Scope

- 用“当前组合键按钮 + 同行编辑器”替换每行的纯录制入口；编辑器直接使用操作名称与启用开关之间的现有留白，不创建浮层或额外窗口。
- 同一时间只允许一行进入编辑状态；其它行继续显示紧凑的当前组合键按钮。
- 在同行编辑器中提供 `fn`、`⇧`、`⌃`、`⌥`、`⌘` 单击切换控件、一次只捕获一个主键的输入控件，以及紧凑的取消和应用按钮。
- 主键继续支持 A-Z、Space、Return、Tab、Delete 等现有 Carbon 虚拟键，显示与持久化继续以虚拟 key code 为准。
- 草稿只在确认后写入；取消、Escape、点击外部或页面离开不修改当前绑定。
- 将 Fn 的 AppKit modifier flag 显示与 Carbon modifier mask 接入现有 `ShortcutBinding`，并保持注册失败时回滚上一组有效热键。
- 禁止无修饰键和仅 Shift 的全局字母/特殊键组合；Fn、Command、Control 或 Option 至少选择一个，Shift 可作为补充修饰键。
- 默认键位改为划词 `⌃⇧D`、截图 `⌃⇧S`、快速输入 `⌃⇧Space`。
- 新安装和“恢复默认”使用新默认；完整等于旧默认的已保存配置自动迁移，自定义配置保持不变。
- 同步快捷键功能规格、测试、Task 与 `STATUS.md`；构建固定 Release App 并完成浅色/深色截图五维复审。
- 展开同行编辑器时保持设置窗口宽度不变；macOS 26 使用原生 Liquid Glass 几何转场表现快捷键 chip 向编辑条的融合展开，Reduce Motion 与 macOS 14–25 提供无障碍降级。

## Out of Scope

- 不支持 Fn/Globe 单击、双击修饰键、按键序列、鼠标按键或无主键组合。
- 不引入 CGEventTap、持续全局事件监听、新的 Input Monitoring 权限或系统设置自动修改。
- 不承诺外接键盘固件级 Fn 一定向 macOS 暴露；只对当前固定 App 和可验证键盘陈述证据。
- 不改变标准应用设置命令 `⌘,`、三个快捷键的独立启用开关、翻译入口行为、Rust/C ABI、Provider、OCR 或产品版本。
- 不把撤回的 `0.1.0` 合同重新激活为发布范围。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-22 | Project owner | 将默认键位改为 Control + Shift + D/S/Space | 增加新安装、恢复默认、旧默认迁移和菜单显示回归 | Implemented |
| 2026-08-22 | Project owner | 直接创建 Task、专用分支并开始实现 | 激活 TASK-035；要求完整自动化、固定 App 和视觉验收 | Active |
| 2026-08-23 | Project owner | 不需要额外弹出界面，直接在快捷键行中间的留白位置编辑 | 移除 popover；改为单行互斥的卡片内编辑；旧 UI、AX 与截图证据失效并重新验证 | Active |
| 2026-08-23 | Project owner | 展开编辑器不能把默认宽度窗口撑宽，并希望有 Apple Liquid Glass 常见的分身融合动效 | 固定行内编辑轨道；macOS 26 使用原生 glass matched-geometry transition，Reduce Motion 与旧系统降级；窗口尺寸和视觉证据重新验证 | Active |
| 2026-08-23 | Project owner | 动画方向正确，但折叠 chip 有双层圆角，展开条两端控件与外层玻璃边角冲突 | macOS 26 折叠态只保留一层玻璃轮廓；展开态统一内缩首尾控件，由外层 capsule 单独负责四角；视觉证据重新验证 | Active |
| 2026-08-23 | Project owner | 展开条左右端点仍未收好，并且展开会把设置窗口高度顶高 | 编辑轨道固定 32pt 高；只保留横向安全边距；macOS 26 内部改为 segmented 状态与内收圆形确认键，外层 capsule 独占端点 | Active |
| 2026-08-23 | Project owner | 自定义主键无需保持旧输入框宽度，应与修饰键单元同宽 | macOS 26 玻璃态主键改为 32pt segmented 单元；Space 使用单行自适应字号，旧系统保留宽降级样式 | Active |
| 2026-08-23 | Project owner | 将快捷键动画继续优化到完美 | 统一折叠/展开 interactive glass 与 28pt 几何高度；收起焦点延后到 morph 完成且切换行不抢焦点；状态变化短动画遵循 Reduce Motion；警告不越出 capsule | Active |
| 2026-08-23 | Project owner | 编辑态确认勾和主键捕获状态仍不完美 | 捕获态在固定 32pt 单元内改为居中省略号与描边反馈；确认键缩为 24pt 并保留四周玻璃间距；两者切换不改变编辑条几何 | Active |
| 2026-08-23 | Project owner | 静态控件修正后融合动画消失，要求保留先前认可的动画 | 撤销导致转场失效的双 interactive 材质统一：折叠 chip 保持 `.regular.interactive()`，展开条恢复 `.regular`，主 morph 恢复 0.32 秒；24pt 确认键和 32pt 主键宽度不回退 | Active |
| 2026-08-23 | Project owner | 主按键视觉上贴近外框，要求与修饰键同高并加宽玻璃边框 | 主按键内容高度由 22pt 收到与修饰键一致的 20pt；外层 capsule 增加 4pt 上下内边距，总轨道仍固定为 32pt，窗口尺寸不得变化 | Active |
| 2026-08-23 | Project owner | 无法保存时使用感叹号，悬停显示具体原因，并将提示延迟设为 0 秒 | 保留无效确认按钮的 disabled/AX 语义；增加独立 hover 命中层与无动画即时原因提示，安全校验、内部冲突和 Carbon 注册失败均显示当前具体原因 | Active |

## Current evidence

- `ShortcutEditorRow` 已改为卡片内同行编辑：设置页统一持有当前编辑 action，因此同一时间只有一行展开；其它行继续显示紧凑组合键按钮。源码不再包含快捷键 `.popover`、专用 Popover View 或 modal accessibility trait。
- 五个 modifier Toggle、单主键捕获和草稿提交均在行内完成。编辑行展开期间只安装 Escape 本地 monitor，主键按钮只在捕获期间另装 `.keyDown` monitor；两个 monitor 都在相应视图消失时清理。
- `ShortcutModifier.function` 已映射 AppKit `.function` 与 Carbon `kEventKeyModifierFnMask`；显示顺序固定为 `fn / ⇧ / ⌃ / ⌥ / ⌘`，安全校验拒绝无修饰键和仅 Shift。
- 新默认值为 `⌃⇧D / ⌃⇧S / ⌃⇧Space`；完整历史默认 `⌃⌥D / ⌃⌥S / ⌃⌥Space` 自动迁移，任一自定义字典保持不变。
- `GlobalShortcutManager.set` 只在冲突检查和 Carbon 注册成功后写入；失败恢复上一组注册并保留旧 binding。内部冲突比较有效 Carbon key code/mask，忽略 numeric-pad 等无关设备位。
- 行内改造后，Shortcut-focused 6 项测试、完整 `./scripts/check.sh`、固定 Release `./scripts/build-test-app.sh` 和 `git diff --check` 已通过。固定 App 保持 `com.marla.app`、`0.0.0`、arm64、macOS 14.0、Paper Lantern 资源与稳定签名。
- 最新固定 App 的 AX 树只包含一个标准设置窗口；编辑区是当前行内的 `container`，没有 popover 或子窗口。真实交互验证了三行互斥、Fn 切换、单主键 K 捕获、取消保留旧绑定、提交 `⌃⇧K` 后持久显示、恢复默认，以及修改草稿后 Escape 取消。
- macOS 26 最终 fixed App 使用 `GlassEffectContainer`、`glassEffectID` 和 matched-geometry glass transition；折叠 chip 使用 `.regular.interactive()`，展开条使用 `.regular`，并由 0.32 秒 `.smooth` 动画完成融合。双 interactive 材质曾使真实点击不再产生可见中间几何，恢复上述已认可组合后项目所有者确认动画已基本恢复。
- 最后一轮固定 App 深色实机复核确认：展开态保持固定 332×32pt 轨道，32pt 宽主键与修饰键使用相同 20pt 内容高度，外层 capsule 以 4pt 上下内边距提供更宽的连续玻璃边框；主键捕获态仍只显示居中的蓝色 `ellipsis`，应用键仍为 24pt 圆形。AX 分别报告主键 `Value: 等待按键, ID: ellipsis` 与应用键 `Value: 可应用, ID: checkmark`，没有截断或尺寸跳变。
- 确认键只在 `validationMessage` 非空时显示 `exclamationmark`；无修饰键或仅 Shift 时继续保持 disabled，但透明命中层允许鼠标悬停。自定义原因提示由同一次 `onHover` 状态更新直接显示，不设置 sleep、transition 或 animation；系统 `.help` 和 AX value 同时保留为降级与辅助技术路径。固定 App 的 AX 已确认仅 Shift 状态报告完整原因“请选择 fn、Control、Option 或 Command；Shift 不能单独使用。”。
- Computer Use 对折叠、`D` 展开与 `Space` 展开三种最终状态测得窗口截图均为 820×592px；没有展开导致的宽高变化。最终深色状态五维复审为 8/8/9/9/8。此前浅色与 Reduce Motion 截图来自边角修正前构建，不能继续作为最终视觉证据。

## Proposed approach

在 `Shortcuts` 层新增受支持修饰键的单一枚举，集中声明显示顺序、AppKit flag、Carbon mask 和可访问名称；`ShortcutBinding` 复用该枚举生成显示文本、验证安全全局修饰键并转换注册参数。设置页统一持有当前编辑行；每个 `ShortcutEditorRow` 在非编辑态显示当前组合键，在编辑态直接用同一行的中间区域替换为 modifier Toggle、主键捕获与取消/应用按钮。编辑行展开期间的本地 monitor 只处理 Escape，主键控件只在捕获期间安装另一个短生命周期 monitor；关闭路径都清理各自 monitor。管理器的 `set` 返回是否成功，使注册或内部冲突失败时编辑行保持展开且旧绑定不变。

旧默认迁移只在完整已保存字典与历史三组默认完全一致时执行，避免猜测部分自定义配置。Fn 仍走现有短生命周期 Carbon 注册，不新增后台监听；固定 App 必须验证真实键盘触发，无法验证的硬件边界保留为明确证据缺口而不是伪写为支持。

## Acceptance criteria

- [x] 新安装和“恢复默认”显示并注册 `⌃⇧D / ⌃⇧S / ⌃⇧Space`。
- [x] 完整旧默认配置自动迁移到新默认；任一自定义配置存在时保持用户保存的完整配置不变。
- [x] 点击每行当前组合键直接在同一行的中间留白内进入编辑；不出现 popover、sheet 或额外窗口，同时只有一行处于编辑态。
- [x] 同行 `fn / ⇧ / ⌃ / ⌥ / ⌘` 可独立切换且选中状态不只依赖颜色表达；主键控件一次只捕获一个虚拟键，A-Z、Space、Return、Tab、Delete 显示和提交正确，不受中文输入法文本组合影响。
- [x] 确认成功后才替换并持久化绑定；取消、Escape、切换编辑行、页面离开和注册失败均保留先前绑定；注册失败时当前行保持编辑态。
- [x] 无修饰键和仅 Shift 组合被拒绝；Fn、Command、Control 或 Option 中至少一个可构成安全候选，Shift 可叠加。
- [x] Fn 的显示、AppKit flag 和 Carbon mask 有自动化回归；固定签名 App 中实体 Fn + 主键触发仍待项目所有者按其键盘/Globe 设置现场验证，此处不声明已通过。
- [x] Marla 内部重复组合与 Carbon 注册失败继续显示可操作错误，不破坏其它已注册入口。
- [x] 组合键触发器、修饰键 Toggle、主键捕获和确认/取消具有唯一可读标签、状态和值；取消后焦点恢复到该行组合键触发器。
- [x] 标准 `⌘,`、独立启用开关、固定 Esc 行和三个翻译入口行为不回归；固定设置宽度下所有同行控件无重叠或截断。
- [x] 从默认 820pt 宽度展开或收起任一快捷键编辑器时，设置窗口 frame 宽度保持不变，控件无重叠或截断。
- [x] macOS 26 的折叠 chip 与同行编辑条使用原生 Liquid Glass matched-geometry 融合转场；macOS 14–25 的短淡入缩放降级通过部署目标编译。
- [x] macOS 26 折叠 chip 不出现 bordered 与 glass 的双层轮廓；展开条首尾控件完整内收于外层 capsule，四角连续且没有裁切、突起或半径冲突。
- [x] 从默认高度展开或收起任一快捷键编辑器时，设置窗口 frame 高度保持不变；编辑条固定在 32pt 轨道内且玻璃效果不被纵向裁切。
- [x] macOS 26 的自定义主键与修饰键单元同宽；`D`、`S` 与 `Space` 都不截断，并保持清晰的主键捕获状态。
- [x] 最终边角构建在 Reduce Motion 下不产生位移动效，并补齐浅色与 Reduce Motion 最终截图复审。
- [x] 折叠 chip 的 interactive glass 与展开条的 regular glass 通过 0.32 秒 matched-geometry 连续融合；不得再次统一为会使真实点击转场消失的双 interactive 材质。
- [x] 收起后焦点仅在 morph 完成后回到同一触发器；直接切换编辑行时旧行不抢焦点。
- [x] 修饰键、捕获态与警告状态的短过渡遵循 Reduce Motion；警告完整保留在固定确认键内，不改变编辑条尺寸。
- [x] 主键捕获态在 32pt 宽、20pt 高单元内不压缩或截断文案，以居中符号和描边明确表达等待输入；确认键为 24pt，外层 capsule 使用 4pt 上下内边距且总轨道仍为 32pt。
- [x] 确认键正常时显示勾，仅在安全校验或注册失败时显示感叹号；鼠标进入感叹号后以 0 秒延迟立即显示具体原因，同时保留 disabled 状态、系统 help 与可读 AX value。
- [x] 新增聚焦自动化测试通过，新增代码未使任何源文件超过结构门禁。
- [x] `./scripts/check.sh`、固定 Release App 构建和 `git diff --check` 通过。
- [x] 最终边角构建的浅色、深色和 Reduce Motion 真实设置页截图完成五维复审且每维至少 7/10；三种状态均为 8/8/9/9/8。
- [x] 相关功能规格和 `STATUS.md` 已同步为已验证事实。

## Verification

### Automated

```sh
./scripts/check.sh
git diff --check
```

### Manual

最新固定 App 已验证：编辑器位于设置卡片内部且 AX 只有一个标准窗口；三行互斥编辑；modifier 与单主键捕获；取消、Escape 与提交语义；提交后恢复默认；唯一动作标签和值。macOS 26 使用折叠 interactive/展开 regular glass 与 0.32 秒 matched geometry；导致动画消失的双 interactive 回归已撤销。最终折叠、`D` 展开和 `Space` 展开状态均保持 820×592；最新真实展开态进一步验证 32pt 宽、20pt 高主键单元、4pt 外框内边距、居中 `ellipsis` 和 24pt 应用键不改变轨道或窗口几何。仅 Shift 状态的 disabled 感叹号已在 AX 中确认携带完整原因；最新固定 App 改为无 sleep、无转场动画的同步 `onHover` 原因提示。浅色、深色和 Reduce Motion 最终状态均完成五维复审并得到 8/8/9/9/8；Reduce Motion 使用 identity glass transition 且关闭修饰键、捕获态与警告的短动画。真实键盘交互进一步确认直接切换编辑行不会让旧行抢回焦点，收起后同一触发器恢复键盘焦点。使用当前 Mac 实体键盘配置一个未被系统占用的 Fn + 字母组合并从其他应用真实触发仍需项目所有者按其键盘/Globe 设置现场验证；此设备相关边界不伪写为已通过，也不阻塞已完成的实现范围。

## Required Reading

- `AGENTS.md`
- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/development/VERSIONING.md`
- `docs/development/STATUS.md`
- `docs/development/UI_UX_SKILLS.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `docs/architecture/decisions/ADR-0007-app-layer-modularity.md`
- `docs/features/inline-translation.md`
- `docs/features/quick-input.md`
- `Sources/MarlaApp/Shortcuts/GlobalShortcuts.swift`
- `Sources/MarlaApp/Settings/SettingsSupport.swift`
- `Sources/MarlaApp/SettingsView.swift`
- `Sources/MarlaApp/MarlaApp.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors (optional)

None. Task 文档、快捷键模型、同行编辑器与测试高度耦合，主 Agent 保持单一写入所有权。

## Risks and rollback

- Fn/Globe 可能被 macOS 或键盘固件保留；注册失败必须保持旧绑定，删除 Fn 候选即可回到四种标准修饰键，不需要新的权限或持久化迁移。
- 修改默认值若无迁移会让固定 App 继续显示旧默认；迁移必须只命中完整历史默认，避免覆盖自定义配置。
- 同行 Escape monitor 或主键捕获 monitor 若未清理会吞掉设置窗口后续输入；两者各自只在编辑行或捕获控件存活期间安装，并在确认、取消、Escape、切换行、禁用、页面离开和消失路径清理。
- 旧交互可通过恢复 `ShortcutRecorderRow` 回滚；快捷键持久化结构继续使用原 `keyCode + modifiers`，不需要数据降级。

## Decisions needed

None. 项目所有者已确认组合式编辑器和新默认键位；Fn 只作为“修饰键 + 主键”候选，不作为单击入口。

## Completion record

当前收束记录：

- Verified commit: `02484d8`（`feat: add composable global shortcut editor`）；未推送远端。
- Automated evidence: 行内改造后 shortcut-focused 6 项测试通过；最终 `./scripts/check.sh` 通过 24 项 Rust、全部 Swift、Swift Package、Xcode Debug、结构、格式、脚本、空白与 diff 门禁；`./scripts/build-test-app.sh` 与独立 `git diff --check` 通过。
- Manual evidence: 最新固定 App 已验证单窗口行内编辑、三行互斥、Fn/modifier、单主键、取消、Escape、提交、恢复默认与 AX 标签；折叠、`D` 展开、`Space` 展开均为 820×592。macOS 26 动画恢复为折叠 interactive/展开 regular glass 和 0.32 秒 matched geometry；最终浅色、深色和 Reduce Motion 均完成 8/8/9/9/8 五维复审。Reduce Motion 没有位移或短状态动画；直接切换行不让旧行抢焦点，收起后同一触发器恢复键盘焦点。
- Documentation updated: architecture、inline translation、screenshot translation、quick input、`STATUS.md` 与本 Task。
- Remaining work promoted to: 无实现遗留；实体 Fn/Globe 触发保留为依赖具体键盘和系统 Globe 设置的现场验证边界。
- Scope changes closed: Control+Shift 新默认、专用 Task/分支和同行编辑范围均已实现。
- Parallel contributions integrated: None
