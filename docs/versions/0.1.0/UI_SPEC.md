# Marla 0.1.0 UI 规范 / UI Specification

状态 / Status: Implemented — visual verification in progress

设计方向 / Direction: Restrained Native · Warm Minimal

设计技能 / Design skill: `swiftui-design-skill` 1.0.0

> 中文为规范文本，英文为同步镜像。/ Chinese is normative; English is its synchronized mirror.

## 1. 设计目标 / Design Goal

### 中文

Marla 应当像 macOS 自身长出来的一层安静工具：出现迅速、层级清楚、细节精确，但不会用视觉装饰争夺正在阅读的内容。0.1.0 选择 Warm Minimal 设计学派，并以功能克制校准它：系统材质、清楚排版、充足留白和一个明确的流式状态细节构成产品性格。

Paper Lantern 是 Marla 已选定的品牌标志和产品意象：像阅读旁边的一盏纸灯，只在用户明确邀请时照亮陌生语言，不接管页面。这个意象约束行为而不是装饰；品牌色不得替代系统强调色，也不得为了呼应纸灯而在功能界面增加发光、阴影或暖色底板。

在规划阶段已经比较过“克制原生精致”“未来透明感”和“专业工具感”三个方向；0.1.0 锁定第一个。不得在实现时重新引入大面积透明光晕、霓虹暗色或密集开发者面板。

TASK-026：API 编辑器把操作标为“保存并测试”；它先持久化当前 profile 与非空 Key 草稿，再从已保存 endpoint 测试，并保留既有的同行测试中/成功/失败状态。

### English

TASK-026: The API editor labels the action “Save and Test”; it persists the current profile and non-empty key draft before testing the saved endpoint, while keeping the existing inline testing/success/failure status.

Marla should feel like a quiet layer grown from macOS itself: immediate, clearly ordered, and precisely crafted without competing with the content being read. 0.1.0 adopts the Warm Minimal school, calibrated by functional restraint. System materials, clear typography, breathing room, and one intentional streaming detail define its character.

Paper Lantern is Marla's selected brand mark and product metaphor: a small light beside the reader that reveals unfamiliar language only when explicitly invited, without taking over the page. The metaphor constrains behavior rather than adding decoration. Brand colors do not replace the system accent, and functional surfaces do not gain glow, shadow, or warm backplates merely to echo the lantern.

Planning compared Restrained Native, Futuristic Transparency, and Professional Utility directions; 0.1.0 locks the first. Implementation must not reintroduce broad translucent glow, neon-dark styling, or dense developer panels.

## 2. 反粗糙规则 / Anti-Slop Rules

### 中文

正式界面禁止：

- 紫蓝渐变背景、霓虹边缘和纯黑赛博面板；
- Emoji 充当功能图标；
- 左侧彩色竖条加圆角卡片的模板布局；
- “欢迎使用 Marla”式占据大面积的营销首屏；
- Inter、Roboto 或网页字体替代 Apple 系统字体；
- 随机间距、随机圆角和没有语义的颜色值；
- 为了“高级感”堆叠模糊、玻璃和阴影；
- AI 生成的 SVG 插画或装饰性人物图形。

所有功能图标优先使用同一字重的 SF Symbols。Paper Lantern 已选为正式品牌标志，主文件和使用边界见 `docs/product/BRAND.md`；菜单、工具栏和设置操作不得用品牌标志替代 SF Symbols。macOS AppIcon asset catalog 已覆盖标准 1x/2x 槽位并接入 Debug 与 Release；所有 App 构建默认使用 Paper Lantern。

### English

Production UI forbids:

- purple-blue gradient backgrounds, neon edges, and pure-black cyber panels;
- emoji as functional icons;
- templated rounded cards with a colored left rail;
- large “Welcome to Marla” marketing hero areas;
- Inter, Roboto, or web fonts replacing Apple system typography;
- random spacing, radii, or non-semantic color values;
- blur, glass, and shadow stacked merely to look premium;
- AI-generated SVG illustrations or decorative people graphics.

Functional icons use SF Symbols at a consistent weight. Paper Lantern is the selected brand mark; its master asset and usage boundaries are defined in `docs/product/BRAND.md`. Menus, toolbars, and Settings actions may not replace SF Symbols with the brand mark. The macOS AppIcon catalog covers the standard 1x/2x slots and is integrated into Debug and Release, so all App builds use Paper Lantern by default.

## 3. 设计 Token / Design Tokens

### 中文

0.1.0 使用语义 Token，禁止在业务 View 中散落视觉常量。

**字体**

| Token | 规格 | 用途 |
| --- | --- | --- |
| `title` | SF Pro 17pt Semibold | 卡片主要状态和设置页标题 |
| `translation` | SF Pro 15pt Regular | 译文第一视觉层级 |
| `body` | SF Pro 14pt Regular | 快速输入和一般正文 |
| `bodyEmphasis` | SF Pro 14pt Medium | 主要操作与目标语言 |
| `caption` | SF Pro 12pt Regular | 来源、状态、隐私提示 |
| `source` | SF Pro 13pt Regular | 展开的原文对照 |
| `micro` | SF Pro 11pt Regular | 快捷键和次要元数据 |

结果卡片属于工具界面，不使用大号衬线标题。正文应允许系统文字设置和无障碍缩放，不截断关键状态。

**间距与尺寸**

| Token | 值 | 用途 |
| --- | --- | --- |
| `spaceXS` | 4pt | 图标与短标签 |
| `spaceS` | 8pt | 同组控件 |
| `spaceM` | 12pt | 紧凑卡片内部间距 |
| `spaceL` | 16pt | 卡片内边距和区块间距 |
| `spaceXL` | 24pt | 设置页大区块 |
| `radiusS` | 8pt | 小控件背景 |
| `radiusM` | 12pt | 输入和次级表面 |
| `radiusL` | 16pt | 结果卡片和快速输入表面 |

所有其他间距使用 4pt 网格。指针控件可保持 macOS 的紧凑视觉尺寸，但点击区域不得小于 32×32pt，并且必须支持键盘访问、Hover 和清楚的 Focus Ring。

**颜色与材质**

- 交互强调色使用 `Color.accentColor`，尊重系统或用户选择；同一视图不增加第二品牌强调色；
- 背景、文字、分隔和语义状态使用适配浅色/深色的系统语义色；
- 菜单、设置、结果卡、快速输入和截图框选提示各自使用单层 macOS HUD/Popover 类材质，避免叠加多层模糊；macOS 26+ 使用系统 Liquid Glass，macOS 14–25 使用 `regularMaterial` 或等价系统材质回退；
- 正文对比度至少 4.5:1，大号文字至少 3:1；
- 成功、警告和错误颜色只表达状态，不承担装饰作用。

### English

0.1.0 uses semantic tokens; business views may not scatter raw visual constants.

**Typography**

| Token | Specification | Use |
| --- | --- | --- |
| `title` | SF Pro 17pt Semibold | Primary card state and Settings titles |
| `translation` | SF Pro 15pt Regular | First visual level for translation |
| `body` | SF Pro 14pt Regular | Quick input and general body text |
| `bodyEmphasis` | SF Pro 14pt Medium | Primary actions and target language |
| `caption` | SF Pro 12pt Regular | Source, status, and privacy notes |
| `source` | SF Pro 13pt Regular | Expanded source comparison |
| `micro` | SF Pro 11pt Regular | Shortcuts and secondary metadata |

The result card is a utility surface and does not use oversized serif titles. Body text honors system text settings and accessibility scaling, and critical state is never truncated.

**Spacing and size**

| Token | Value | Use |
| --- | --- | --- |
| `spaceXS` | 4pt | Icon-to-short-label gap |
| `spaceS` | 8pt | Controls in one group |
| `spaceM` | 12pt | Compact card internal spacing |
| `spaceL` | 16pt | Card inset and section spacing |
| `spaceXL` | 24pt | Major Settings sections |
| `radiusS` | 8pt | Small control backgrounds |
| `radiusM` | 12pt | Inputs and secondary surfaces |
| `radiusL` | 16pt | Result and quick-input surfaces |

All other spacing follows a 4pt grid. Pointer controls may retain compact macOS visual sizing, but hit areas are at least 32×32pt and must support keyboard access, hover, and a visible focus ring.

**Color and material**

- interactive emphasis uses `Color.accentColor`, respecting the system or user choice; a view adds no second brand accent;
- background, text, divider, and semantic states use adaptive system semantic colors;
- the menu, Settings, result card, quick input, and screenshot-selection labels each use one macOS HUD/Popover-class material without stacked blur layers; macOS 26+ uses system Liquid Glass, while macOS 14–25 uses `regularMaterial` or an equivalent system-material fallback;
- body contrast is at least 4.5:1 and large text at least 3:1;
- success, warning, and error colors communicate state only and are not decoration.

## 4. 结果卡片 / Result Card

### 中文

卡片默认和最小宽度为 380pt；用户可从原生式窗口边缘或角落拖动到最多 760pt，实际最大宽度取 760pt 与当前屏幕可见工作区减去 16pt 安全边距中的较小值。无边框面板在 SwiftUI 内容上方提供左右各 8pt、覆盖完整高度与角落的透明 AppKit 手柄，持续显示横向 resize 光标并接收首击，但不增加可见控件或无障碍噪声。译文按新行宽重排，总高度随内容重新计算。短译文和等待状态从约 224pt 的紧凑内容高度开始，随着流式译文换行逐步增高。最大高度为当前屏幕可见工作区的 60%，达到上限后外框停止增长、译文正文内部滚动。卡片与选区或指针保持 8pt 安全间隔，并完整限制在可见工作区内。结果卡首次定位后，自动高度增长保持靠近选区/指针的锚定边和水平位置不变，增长只作用于远离锚点的一边；用户调宽时尊重正在拖动的窗口边缘，并继续限制在可见工作区内。

布局从上到下为：

1. 状态行：入口、当前翻译 API 配置、固定状态和关闭；
2. 语言行：两个等层级紧凑菜单，左侧显示自动识别或显式源语言，右侧始终显示实际目标语言，中间使用克制的方向箭头；
3. 译文区：第一视觉层级，支持选择文字和流式增长；
4. 对照区：默认折叠，展开后显示原文并与译文保持稳定顺序；
5. 操作行：朗读、复制、重试和更多状态。

语言菜单使用单层语义浅表面、SF Symbols 和 4/8/12pt Token，不使用旧目标胶囊或第二套强调色。菜单提供七门产品语言；源语言自动状态必须显示“自动识别：语言”或“自动识别：未知”，让识别与覆盖关系可见。

卡片的标志性细节是“稳定流式游标”：等待首字时在译文首行使用低对比度呼吸点；首个 delta 到达后转为克制的尾部插入游标；完成时在 120ms 内淡出。它只表达状态，不循环播放装饰动画。

卡片出现前计算最终锚点，使用 160ms ease-out 的 4pt 位移与淡入。流式文本只改变内部内容，不重复执行出现动画；每次高度动画结束后，协调器必须按当前会话和实时宽度做一次无动画最终校正，避免首个 delta 与出现动画重叠时留下过时外框。固定时使用 180ms 的轻弹性位置确认，不改变卡片尺寸。用户可从非控件区域拖动卡片；外层阴影只由 AppKit 面板绘制，SwiftUI 内容裁切到连续圆角，避免窗口底角出现矩形边缘。

### English

The card defaults to a minimum width of 380pt. Users can drag native-style window edges or corners up to the smaller of 760pt and the current screen's visible work area minus a 16pt safety inset. Above the SwiftUI content, the borderless panel supplies transparent 8pt AppKit handles covering the full left and right heights including corners. They keep the horizontal resize cursor stable and accept the first click without adding a visible control or accessibility noise. Translation reflows at the new line width and total height is recomputed from content. Short translations and waiting states start at a compact content-driven height of about 224pt and grow as streamed text wraps to more lines. Maximum height is 60% of the current screen's visible work area; the outer frame stops there and the translation body scrolls beyond that. The card keeps an 8pt safe gap from selection or pointer and remains fully inside the visible work area. After first placement, automatic height growth keeps the anchored edge near the selection/pointer and the horizontal position stable, affecting only the edge away from the anchor. User-driven width changes respect the window edge being dragged and remain constrained to the visible work area.

Top-to-bottom structure:

1. status row: entry, current translation API profile, pin state, and close;
2. language row: two equal compact menus, with automatic or explicit source on the left, the effective target on the right, and a restrained direction arrow between them;
3. translation area: primary visual level, selectable and stream-growing;
4. comparison area: collapsed by default, preserving stable source/translation order when expanded;
5. action row: speech, copy, retry, and secondary state.

Language menus use one semantic secondary surface, SF Symbols, and the 4/8/12pt tokens, without the previous target capsule or a second accent color. Menus provide all seven product languages. Automatic source visibly reads “Auto-detected: Language” or “Auto-detected: Unknown” so detection and override remain understandable.

The card's signature detail is a stable streaming caret. Before first token, a low-contrast breathing dot occupies the first translation line. After the first delta, it becomes a restrained trailing insertion caret and fades out within 120ms on completion. It communicates state and never loops as decoration.

The final anchor is computed before presentation. Entry uses a 160ms ease-out fade with 4pt movement. Streamed text changes internal content only and never replays entry motion; after each height animation completes, the coordinator must reconcile once without animation against the current session and live width so an early delta overlapping entry cannot leave a stale outer frame. Pinning uses a light 180ms positional confirmation without resizing the card. The card is draggable from non-control regions. AppKit alone owns the outer shadow, while SwiftUI content clips to continuous corners so no rectangular edge protrudes at the bottom.

## 5. 截图框选层 / Screenshot Selection Layer

### 中文

非选中区域只做足以建立范围感的系统暗化，不使用彩色渐变。选区边界使用 1pt 高对比描边和四角短控制标记；拖动时在相邻位置显示紧凑尺寸标签。未开始拖动时在上方显示“拖动框选要翻译的区域 · Esc 取消”，光标使用系统十字样式。指针旁显示 6× 像素放大镜、蓝色中心准星和紧凑坐标；放大镜与精确落点保持间距，在四边自动换位，并且只使用当前会话的内存屏幕快照。

标志性细节是选区四角在确认瞬间进行一次 120ms 向内收束，随后立即退出并开始 Vision；Reduce Motion 下取消位移，只改变透明度。框选层不得显示营销文案、工具栏或与任务无关的品牌元素。

### English

Unselected space receives only enough system dimming to establish scope, with no colored gradient. The region uses a 1pt high-contrast outline and short corner markers, with a compact adjacent size label during drag. Before dragging, it shows “Drag to select text to translate · Esc to cancel”; the pointer uses the system crosshair. A 6× pixel loupe beside the pointer adds a blue center reticle and compact coordinates. It stays clear of the exact target, flips at all four edges, and uses only the active session's in-memory screen snapshot.

Its signature detail is a single 120ms inward confirmation of the four corners before dismissal and Vision start. With Reduce Motion, movement is removed and opacity changes only. The selection layer contains no marketing copy, toolbar, or unrelated brand decoration.

## 6. 快速输入 / Quick Input

### 中文

快速输入复用结果卡片外壳，初始宽度 420pt，并沿用结果卡 380–760pt 的原生边缘/角落调宽范围。输入区至少显示三行但按内容增长到卡片最大高度；底部清楚显示 `⌘Return` 提交和 `Esc` 关闭。主要动作由键盘完成，不添加巨大提交按钮。

输入状态复用结果卡语言行：提交前左侧可选择自动识别或显式源语言，右侧显示按当前母语/第二语言偏好计算的实际目标并允许覆盖。两个菜单保持紧凑，不使用旧固定中英胶囊或渐变。

### English

Quick input reuses the result-card shell, starts at 420pt wide, and inherits the result card's native edge/corner resizing range of 380–760pt. The editor shows at least three lines and grows with content up to the card maximum. The footer clearly shows `⌘Return` to submit and `Esc` to close. Keyboard is primary; no oversized submit button is added.

The input state reuses the result-card language row. Before submission the left menu selects automatic or explicit source, while the right shows the effective target derived from current native/secondary preferences and allows an override. Both menus remain compact, with no fixed Chinese-English capsule or gradient.

## 7. 设置与首次启动 / Settings and First Launch

### 中文

“通用”页只保留权限、兼容性取词和隐私边界，不显示 Force Touch、单行原位译文或通用“实验功能”区。

Marla 激活时，标准 `⌘,` 打开或复用同一个设置窗口，不产生重复设置表面，也不改变三个可配置的全局翻译快捷键。

设置使用原生 macOS 侧栏，不制造卡片网格。窗口使用透明全尺寸标题栏，原生红黄绿按钮位于与侧栏和内容连续的同一个四角圆角表面内；不得在标题栏下再叠放第二张圆角卡片，也不显示常驻滚动指示条。内容背景不得成为窗口拖动区，窗口移动只由原生标题栏承担，避免抢占开关、菜单和排序手柄的指针手势。侧栏固定包含“通用”“翻译语言”“翻译 API”“快捷键”“OCR”五项，默认打开“通用”。“翻译语言”页面用两个原生紧凑菜单设置互不相同的母语和第二语言，并以三条简洁方向示例解释当前路由；不使用配置卡片网格。“翻译 API”页面只展示配置名称、模型、默认/完整状态和启用开关；点击配置后才打开独立编辑窗口。配置菜单只保留“设为默认”和“删除配置”，最右侧使用 `line.3.horizontal` 手柄直接拖拽排序，并提供对应的无障碍移动操作。原生拖拽项只携带透明 1×1pt 图像负责 drop 命中，不能作为用户可见预览；抓起时由不激活、不接收鼠标事件的无边框浮层以固定 580×76pt 绘制完整配置行，并保持指针位于用户实际抓取的尾部三横杠位置，整行由该锚点向左展开。浮层尺寸全程固定，不得缩放、把中心吸附到指针或变成缩略图。列表中的原行内容同时变空，但保留稳定 ID 与等高占位槽。进入另一配置行时立即移动该空槽，并使用约 220ms 的短促弹性过渡让其它行平滑让位；松手后内容以短促淡入恢复到当前空槽。API 编辑窗口使用固定标签列与统一输入宽度，保留足够焦点环边距；底部操作只保留右对齐的取消和保存，保存同时持久化配置与非空 Key 草稿，取消新增时不保留临时配置或 Key。测试连接位于模型区域下方，按钮旁直接展示测试中、成功或具体失败结果；URL、模式、模型或 Key 草稿改变后清除旧结果。首行输入框必须在滚动内容顶部保留至少一个 8pt Token，使系统向控件外扩展的 Focus Ring 四边完整可见。URL 模式使用 URL 输入行左侧固定标签区内的原生紧凑 switch，左侧 Base、右侧完整，不另占一行；示例和单行“请求地址”预览随模式同步，长地址只在固定宽度内截断。模型名称是最后一个输入字段，右侧是获取/刷新图标；获取成功后下方出现默认展开且可折叠的模型列表，选择一项回填并收起列表。快捷键页为每个全局监听提供原生 switch，并以不可关闭的固定行说明 `Esc` 用于取消截图框选。OCR 页面只读展示本机 Vision 和截图隐私边界。

首次启动不显示大幅欢迎页，而是直接显示三项可完成清单：配置翻译 API、授予辅助功能、授予屏幕录制。应用完成启动后读取包含全部 API Key 的单一 Keychain vault，使正常启动最多只授权一个当前凭据 item；旧版逐 profile item 仅在一次性迁移时集中处理，迁移查询复用同一个认证上下文，不得把提示延迟到首次翻译。每项解释它影响哪个入口，并允许暂时跳过；快速输入始终可用于验证 API。

菜单的准备状态只在任一项未完成时存在。全部完成后，同一区域切换为“最近翻译”：最多三行，每行显示入口图标、单行译文、单行原文和进入箭头；无结果时显示克制空状态，并始终标注“退出即清空”。截图翻译统一使用目标系统可用的 `viewfinder` SF Symbol。

### English

When Marla is active, the standard `⌘,` command opens or reuses the same Settings window without creating a duplicate surface or changing the three configurable global translation shortcuts.

Settings uses a native macOS sidebar rather than a card grid. The window has a transparent full-size title bar, placing the native traffic-light controls inside the same continuous four-corner surface as the sidebar and content. It may not stack a second rounded card below the title bar or show a persistent scroll indicator. The content background is not a window-drag region; only the native title bar moves the window, so switches, menus, and reorder handles retain their pointer gestures. The sidebar has five items: General, Translation Languages, Translation API, Shortcuts, and OCR, with General selected by default. Translation Languages uses two compact native menus for different Native and Secondary values plus three concise route examples; it does not introduce a card grid. The Translation API page shows only profile name, model, default/completeness state, and an enabled switch; clicking a profile opens a separate editor window. The profile menu retains only Set as Default and Delete Profile. A trailing `line.3.horizontal` handle provides direct drag reordering plus matching accessibility move actions. The native dragging item carries only a transparent 1×1pt image for drop hit testing and is never used as the visible preview. On pickup, a nonactivating, mouse-ignoring borderless panel renders the complete row at a fixed 580×76pt. It follows the pointer while preserving the exact grab point inside the trailing three-line handle and expands leftward from that anchor. The panel size never changes, its center never snaps beneath the pointer, and it never becomes a thumbnail. The source row becomes empty while preserving its stable ID and full-height slot. Entering another profile row moves that empty slot immediately and uses a short, approximately 220ms spring transition to let surrounding rows make room. On release, the row content returns to the current slot with a short fade. The API editor uses a fixed label column, uniform input width, and enough focus-ring inset. Its footer contains only right-aligned Cancel and Save; Save persists the profile and any non-empty key draft, while cancelling a new profile leaves neither a placeholder nor its key. Connection Test sits below the model area and shows testing, success, or a specific failure beside the button. Changing URL, mode, model, or key draft clears stale results. The first field keeps at least one 8pt token above it inside the scroll content so all four sides of the system Focus Ring remain visible as it expands outside the control. URL mode uses a compact native switch inside the URL row's fixed label area, with Base on the left and Complete on the right, rather than consuming a separate row. The example and single-line Request URL preview update with the mode, and long addresses truncate within the fixed width. Model Name is the last input field, with a fetch/refresh icon to the right. A successful fetch reveals an initially expanded, collapsible model list below it; choosing one fills the field and collapses the list. Each global listener has a native switch on the Shortcuts page, while a non-disableable fixed row explains that `Esc` cancels screenshot selection. The OCR page is read-only and explains local Vision and screenshot privacy boundaries.

First launch does not show a large welcome hero. It directly presents a three-item completion list: configure translation API, grant Accessibility, and grant Screen Recording. After launch, the application reads one Keychain vault containing all API Keys, so a normal startup authorizes at most one current credential item. Legacy per-profile items are handled together only during one-time migration and reuse one authentication context; prompts may not be deferred until first translation. Each item explains the affected entry and may be skipped; quick input remains available to validate the API.

The menu's setup status exists only while any item is incomplete. Once all are ready, the same region becomes Recent Translations: up to three rows, each showing an entry-point icon, one translation line, one source line, and a disclosure chevron. An empty state remains restrained and the section always states that quitting clears it. Screenshot translation consistently uses the `viewfinder` SF Symbol available on the target systems.

General contains permissions, Copy compatibility, and the privacy boundary; it has no Force Touch, single-line in-place translation, or generic Experimental section.

## 8. 状态、主题与无障碍 / States, Themes, and Accessibility

### 中文

每个主要表面必须设计并验证：默认、Hover、Focus、Pressed、加载、流式、完成、空、错误、禁用和固定状态。错误使用简短标题、原因和一个最相关恢复动作，不用红色覆盖整张卡片。

浅色和深色都使用系统语义颜色与材质，不分别创造两套视觉语言。跟随系统实时切换，切换过程中内容和状态不丢失。

开启 Reduce Motion 时移除位置弹簧、角点收束和呼吸缩放，只保留不超过 120ms 的必要透明度变化。所有图标有无障碍标签，工具栏操作有 Tooltip，键盘焦点顺序与视觉顺序一致，译文可选择和复制。

### English

Every primary surface designs and verifies default, hover, focus, pressed, loading, streaming, completed, empty, error, disabled, and pinned states. Errors use a short title, reason, and one most relevant recovery action rather than covering the card in red.

Light and dark appearances use system semantic colors and materials rather than separate visual languages. Appearance changes follow the system live without losing content or state.

With Reduce Motion, positional springs, corner convergence, and breathing scale are removed; only necessary opacity changes of at most 120ms remain. Every icon has an accessibility label, toolbar actions have tooltips, keyboard focus order follows visual order, and translation text is selectable and copyable.

## 9. 视觉验收 / Visual Acceptance

### 中文

实现后必须调用 `swiftui-design-skill` 的五维审查，并保存对以下状态的真实 App 截图证据：

- 浅色与深色；
- 短句、长段落和多行；
- 首字等待、流式、完成和部分失败；
- 原文对照展开；
- 固定与非固定；
- 快速输入、截图框选、设置和权限缺失；
- Reduce Motion。

哲学一致性、视觉层级、工艺质量、功能性和原创性五项都必须至少 7/10。任何低于 7 的项目修复后重新评分；不得只以源码存在证明 UI 验收通过。

2026-08-06 真实 Release App 复评：菜单、快速输入、等待/流式/完成/部分失败/长文/对照固定卡片、设置和截图框选场景均已从实际 `Marla_test_202608060135.app` 渲染并检查。五维评分为：哲学一致性 8/10、视觉层级 8/10、工艺质量 7/10、功能性 8/10、原创性 7/10；所有项目达到门槛。PNG 证据位于 `artifacts/ui-review/`，仅由显式 UI 自动化场景写入。macOS 26+ 的生产卡片使用 Liquid Glass，旧系统使用材质回退。后续 Qwen-MT、Web Text Marker 和截图坐标修复未改变 UI 表面；最终源码也已重新构建到固定签名的 `Marla_dev.app`。

TASK-003 复评：`Marla_test_202608061928.app` 的菜单最近翻译浅色/深色、设置、快速输入、对照卡和截图框选场景均已检查，证据位于 `artifacts/ui-review/task-003/`。首次检查发现设置透明标题栏在浅色离屏渲染中出现黑条，恢复系统标题栏材质后复评通过。评分为：哲学一致性 8/10、视觉层级 8/10、工艺质量 8/10、功能性 8/10、原创性 7/10。自动化截图显式渲染材质回退；生产路径在 macOS 26+ 调用 SwiftUI `glassEffect`，旧系统保持单层材质回退。

TASK-006 真实 Release App 验收：固定路径 `artifacts/Marla_dev.app` 生成通用浅色/深色、翻译 API 摘要列表、API 独立编辑器、快捷键和 OCR 状态页证据，位于 `artifacts/ui-review/task-006/`。侧栏宽度 180pt，编辑器标签列 120pt、输入框 360pt；五维评审为哲学一致性 8/10、视觉层级 8/10、工艺质量 8/10、功能性 8/10、原创性 7/10，全部达到 7/10 门槛。

TASK-007 真实 Release App 验收：固定路径 `artifacts/Marla_dev.app` 生成 API 编辑器、快捷键浅色/深色、结果卡和截图放大镜证据，位于 `artifacts/ui-review/task-007/`。编辑器 AppKit 承载层与 SwiftUI 内容共同裁切四个连续圆角，侧栏分隔线避开上下圆角；三个快捷键 switch、结果卡底角和 6× 指针放大镜均已检查。五维评审为哲学一致性 8/10、视觉层级 8/10、工艺质量 8/10、功能性 8/10、原创性 7/10，全部达到门槛。

TASK-008 真实 Release App 验收：固定路径 `artifacts/Marla_dev.app` 生成设置一体化浅色、快捷键深色和“设置已打开后进入截图”证据，位于 `artifacts/ui-review/task-008/`。透明全尺寸标题栏将交通灯纳入单一连续表面，左右四角共同裁切，右缘不再显示滚动白条；截图场景未出现设置窗口。五维评审为哲学一致性 8/10、视觉层级 8/10、工艺质量 8/10、功能性 8/10、原创性 7/10，全部达到门槛。

TASK-010 真实 Release App 验收：固定路径 `artifacts/Marla_dev.app` 生成完整 URL 编辑器浅色/深色证据，位于 `artifacts/ui-review/task-010/`。`Base [滑块] 完整` 位于 URL 行的 120pt 标签区，不再单独占行；模型字段位于最下面，右侧刷新图标和自动展开的可选模型列表完整可见。固定 360pt 内容列、请求地址预览、焦点环和底部操作均无裁切。五维评审为哲学一致性 8/10、视觉层级 8/10、工艺质量 8/10、功能性 8/10、原创性 7/10，全部达到门槛。

TASK-011 真实 Release App 验收：固定路径 `artifacts/Marla_dev.app` 的 API 编辑器首行增加 8pt 滚动内容安全边距。前台浅色/深色窗口按 Core Graphics Window ID 捕获后，系统蓝色 Focus Ring 的上、下、左、右均完整可见，字段和底部操作区无布局回归；证据位于 `artifacts/ui-review/task-011/`。五维评审为哲学一致性 8/10、视觉层级 8/10、工艺质量 9/10、功能性 8/10、原创性 7/10，全部达到门槛。

TASK-019 真实 Release App 验收：固定路径 `artifacts/Marla_dev.app` 生成翻译语言设置浅色/深色、结果卡浅色/深色/Reduce Motion、快速输入浅色/深色证据，位于 `artifacts/ui-review/task-019/`。首轮结果卡截图发现 macOS Menu 把复合 label 压平后只显示“源语言 → 目标语言”，设置菜单也出现重复箭头；改为单行实际值并移除重复箭头后已重新构建、签名和采集。最终 380pt 卡片清楚显示“自动识别：English → 简体中文”，API 配置留在顶行，420pt 快速输入无截断。五维评审为 8/8/8/8/7，全部达到门槛。

TASK-020 真实 Release App 验收：固定路径 `artifacts/Marla_dev.app` 的结果卡从 224pt 紧凑高度开始，streaming-growth 中间阶段约 309pt，长译文在约 644pt（当前可见工作区 60%）封顶并保留标题、语言和操作行；浅色、深色和 Reduce Motion 均无布局回归。截图按项目默认规则保存在 `/private/tmp` 临时目录，五维评审为 8/8/8/9/7，全部达到门槛。

TASK-021 Release 证据：当前固定 App 的 380pt 截图为 760px，760pt 截图为 1520px；浅色、深色、Reduce Motion 和长文本封顶无视觉回归，五维评审为 8/8/8/8/7。第一版边缘无法拖动，父内容视图命中区又只让横向光标闪现，后续手工 NSCursor、轮询和 Carbon 方案也被真实非激活面板复验否定。当前版本使用隐藏标题栏的 titled/resizable 几何和位于 SwiftUI 内容上方的 8pt AppKit 手柄；手柄从 `resetCursorRects()` 注册 macOS 15+ frame-resize 光标并接管同一拖动序列，窗口在非 key 状态直接重建全部 cursor rectangles。宽度与既有视觉证据仍有效；本轮增加了高度动画完成后的最新会话 frame reconciliation，并将非激活回归场景提前到 40ms 以覆盖入场竞态。`./scripts/check.sh` 与固定 Release 打包均通过，LaunchServices 竞态截图 `/private/tmp/marla-task-021-height-race-final.png` 中译文、分隔线和操作行完整可见；项目所有者真实划词复验仍待完成。

### English

After implementation, invoke the `swiftui-design-skill` five-dimension review and retain real-app screenshot evidence for:

- light and dark appearance;
- short sentence, long paragraph, and multiline content;
- first-token wait, streaming, completion, and partial failure;
- expanded source comparison;
- pinned and transient states;
- quick input, screenshot selection, Settings, and missing permissions;
- Reduce Motion.

Philosophy alignment, visual hierarchy, craft quality, functionality, and originality must each score at least 7/10. Any lower dimension is fixed and rescored. Source code alone cannot prove UI acceptance.

2026-08-06 real Release App rescore: menu, quick input, awaiting/streaming/completed/partial-failure/long-text/comparison-pinned card, Settings, and screenshot-selection scenarios were rendered and inspected from `Marla_test_202608060135.app`. Scores are Philosophy Alignment 8/10, Visual Hierarchy 8/10, Craft Quality 7/10, Functionality 8/10, and Originality 7/10; every dimension meets the threshold. PNG evidence is under `artifacts/ui-review/` and is written only by explicit UI automation scenarios. Production cards use Liquid Glass on macOS 26+ and the material fallback on earlier supported systems. The later Qwen-MT, Web Text Marker, and screenshot-coordinate fixes do not change UI surfaces; the final source was also rebuilt into the fixed-path signed `Marla_dev.app`.

TASK-003 rescore: the recent-translations menu in light and dark appearance, Settings, quick input, comparison card, and screenshot-selection scenes from `Marla_test_202608061928.app` were inspected, with evidence under `artifacts/ui-review/task-003/`. The first pass found a black strip from the transparent Settings title bar in light off-screen rendering; restoring the system title-bar material passed the rescore. Scores are Philosophy Alignment 8/10, Visual Hierarchy 8/10, Craft Quality 8/10, Functionality 8/10, and Originality 7/10. Automation screenshots explicitly render the material fallback; production invokes SwiftUI `glassEffect` on macOS 26+ and retains a single-layer material fallback on older systems.

TASK-006 real Release App acceptance: the fixed `artifacts/Marla_dev.app` produced General light/dark, Translation API summary-list, separate API editor, Shortcuts, and OCR status-page evidence under `artifacts/ui-review/task-006/`. The sidebar is 180pt wide; the editor uses a 120pt label column and 360pt fields. Five-dimension scores are Philosophy Alignment 8/10, Visual Hierarchy 8/10, Craft Quality 8/10, Functionality 8/10, and Originality 7/10; every dimension meets the 7/10 threshold.

TASK-007 real Release App acceptance: the fixed `artifacts/Marla_dev.app` produced API-editor, Shortcuts light/dark, result-card, and screenshot-magnifier evidence under `artifacts/ui-review/task-007/`. The editor's AppKit host and SwiftUI content jointly clip all four continuous corners, and the sidebar divider stops short of the upper and lower corners; the three shortcut switches, result-card bottom corners, and 6× pointer magnifier were inspected. Five-dimension scores are Philosophy Alignment 8/10, Visual Hierarchy 8/10, Craft Quality 8/10, Functionality 8/10, and Originality 7/10; every dimension meets the threshold.

TASK-008 real Release App acceptance: the fixed `artifacts/Marla_dev.app` produced unified-Settings light, Shortcuts dark, and “enter screenshot while Settings is open” evidence under `artifacts/ui-review/task-008/`. The transparent full-size title bar places the traffic lights inside one continuous surface, both left and right corners share the same clipping, and the right-edge white scroll indicator is gone. The screenshot scene contains no Settings window. Five-dimension scores are Philosophy Alignment 8/10, Visual Hierarchy 8/10, Craft Quality 8/10, Functionality 8/10, and Originality 7/10; every dimension meets the threshold.

TASK-010 real Release App acceptance: the fixed `artifacts/Marla_dev.app` produced light/dark Complete URL editor evidence under `artifacts/ui-review/task-010/`. `Base [switch] Complete` occupies the URL row's 120pt label area rather than a separate row. Model Name is last, with the refresh icon and automatically expanded selectable model list fully visible. The fixed 360pt content column, Request URL preview, focus ring, and bottom actions show no clipping. Five-dimension scores are Philosophy Alignment 8/10, Visual Hierarchy 8/10, Craft Quality 8/10, Functionality 8/10, and Originality 7/10; every dimension meets the threshold.

TASK-011 real Release App acceptance: the fixed `artifacts/Marla_dev.app` gives the API editor's first row an 8pt scroll-content safety inset. Frontmost light/dark windows captured by verified Core Graphics Window ID show all four sides of the system blue Focus Ring, with no field or bottom-action layout regression; evidence is under `artifacts/ui-review/task-011/`. Five-dimension scores are Philosophy Alignment 8/10, Visual Hierarchy 8/10, Craft Quality 9/10, Functionality 8/10, and Originality 7/10; every dimension meets the threshold.

TASK-019 real Release App acceptance: the fixed `artifacts/Marla_dev.app` produced Translation Languages Settings light/dark, result-card light/dark/Reduce Motion, and quick-input light/dark evidence under `artifacts/ui-review/task-019/`. The first result-card capture exposed macOS Menu flattening that showed only “Source Language → Target Language” and duplicate Settings chevrons. After switching to one visible effective value and removing duplicate chevrons, the app was rebuilt, signed, and fully recaptured. The final 380pt card clearly reads “Auto-detected: English → Simplified Chinese,” retains the API profile in the top row, and fits quick input at 420pt without truncation. Five-dimension scores are 8/8/8/8/7; every dimension meets the threshold.

TASK-020 real Release App acceptance: the fixed `artifacts/Marla_dev.app` starts result cards at 224pt, reaches approximately 309pt in the streaming-growth intermediate stage, and caps long translation at approximately 644pt (60% of the visible workspace) while keeping header, language, and action rows visible. Light, dark, and Reduce Motion show no layout regression. Screenshots remain in `/private/tmp` under the project's ephemeral-screenshot policy; five-dimension scores are 8/8/8/9/7, meeting the threshold in every dimension.

TASK-021 Release evidence: the current fixed App renders 380pt at 760px and 760pt at 1520px. Light, dark, Reduce Motion, and capped long text show no visual regression, scoring 8/8/8/8/7. The first edge implementation could not be dragged, while the parent-content hit zone only flashed the horizontal cursor; later manual NSCursor, polling, and Carbon approaches were also rejected by real nonactivating-panel trials. The current build uses hidden titled/resizable geometry plus 8pt AppKit handles above SwiftUI. Each handle registers the macOS 15+ frame-resize cursor from `resetCursorRects()` and owns the matching drag sequence, while the non-key window directly rebuilds all cursor rectangles. Width and prior visual evidence remain valid; this pass adds latest-session frame reconciliation after each height animation and moves the nonactivating regression scenario to 40ms to cover overlap with entry animation. `./scripts/check.sh` and the fixed Release packaging pass, and the LaunchServices capture `/private/tmp/marla-task-021-height-race-final.png` keeps translation, dividers, and actions fully visible; project-owner real selection retest remains pending.
