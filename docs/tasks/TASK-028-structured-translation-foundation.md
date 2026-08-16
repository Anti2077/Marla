# TASK-028：结构化翻译合同与 Markdown 快速输入闭环

Status: Active

Owner: Project owner + Agent

Created: 2026-08-16

Updated: 2026-08-16

Origin: IDEA-013 / direct request

Conversation: 2026-08-16，结构化内容一等公民、Markdown 模型实测与首阶段实施

## Initial request

项目所有者要求把划词、截图和快速输入中的结构化内容保留作为底层管线的一等公民；不同语言允许自然重组，不做源/译节点或字符位置机械回填。随后项目所有者要求实测 `qwen-mt-turbo` 的 Markdown 输入/输出能力，并在确认可用后把 IDEA-013 提升为 Task 开始实施。

## Outcome

Marla 的翻译边界不再只接受一个无格式字符串，而是接受带明确内容格式的完整输入。显式 Markdown 源码、Quick Input 富文本粘贴，以及划词时受保护 Copy 事务取得的 HTML、RTF/RTFD 或 Markdown representation 会在 Swift/AppKit 会话内清洗并归一为语义 Markdown，再进入 Rust、Provider、流式会话和复制链路；没有可靠结构证据时诚实降级为纯文本。生产划词不再把 Accessibility 选区字符串作为内容源或失败兜底，AX 只保留权限和非内容定位职责。流式阶段显示尚未闭合的原始 Markdown，完成后在结果卡中切换为安全、可跨块连续选择的原生富文本投影；GFM pipe table、明确可辨的粗体，以及 Markdown/纯文本两种显式复制结果都属于同一完成态投影边界。

## Why now

真实 `qwen-mt-turbo` 请求已经证明模型可以接收并返回包含标题、列表、粗体、链接、代码围栏、命令、变量和占位符的 Markdown，但它不接受 System Message，并以累计内容流式返回。实施前的 FFI schema v2、Swift 会话和 Rust 请求以 `sourceText: String` 为唯一内容模型，无法表达输入格式，也无法让 Provider 根据能力选择格式策略。

先建立共享格式合同和一个窄入口，可以验证端到端边界而不提前承诺 HTML/RTF 清洗、Accessibility 富文本选择、截图结构推断或实时 Markdown 渲染。第一阶段完成后，项目所有者确认只显示原始 Markdown 不能构成完整的窗口内阅读体验，因此把完成态原生渲染加入同一 Task；实时增量渲染仍留待后续。

## In Scope

- 新增共享格式化内容模型，至少区分 `plainText` 与 `semanticMarkdown`，并让纯文本继续作为明确降级格式。
- 版本化升级 Swift/Rust 翻译请求 schema，使格式与完整内容跨过 FFI，而不是只传 `sourceText`。
- 在 Rust Provider 层用明确能力描述区分通用 OpenAI-compatible 模型与 Qwen-MT，而不是让请求构造和流式规则分散判断。
- 通用模型在 Markdown 输入时收到只输出译文 Markdown、允许自然语序重组、保留大致块结构并保护代码/URL/变量/命令/占位符的提示。
- Qwen-MT 继续只发送 User Message 和 `translation_options`；Markdown 原文直接输入，累计流归一为统一增量事件。
- 快速输入把完整输入作为 `semanticMarkdown` 发送；普通文本作为 Markdown 子集保持现有行为。
- Quick Input 必须在原生编辑器的 Paste 命令中读取本次明确粘贴的 Markdown、HTML、RTF/RTFD 和纯文本 representation；富文本先清洗、转换为语义 Markdown 源码再插入草稿，普通文本与直接键入的 Markdown 源码保持原样。
- 生产划词内容统一来自受保护的模拟 `⌘C` 事务；不得先接受 Accessibility 纯文本，也不得在 Copy 失败时以 AX 字符串静默兜底。
- AX 可继续承担辅助功能授权、触发时前台应用身份和可选定位职责，但不再决定发送给 Provider 的文本或格式。
- 受保护 Copy 事务必须在恢复原 Pasteboard 前读取本次新增的 Markdown、HTML、RTF/RTFD 和纯文本 representation，并按同一 Pasteboard item 的可见文本一致性校验后选择最可靠内容。
- HTML 必须通过结构化解析器处理并移除脚本、样式、显式隐藏节点、图片资源和不安全链接；不得使用 WebView、执行内容或加载远程资源。结构化 representation 与纯文本可见内容不一致时降级为纯文本。
- `semanticMarkdown` 译文在流式阶段继续显示原始字符，只有会话进入 `completed` 后才在结果卡切换为原生富文本渲染。
- 完成态渲染覆盖 Foundation Markdown 支持的标题、强调、列表、引用、行内代码、代码围栏和链接；解析失败必须诚实降级为原始 Markdown。
- 完成态额外识别本地 GFM pipe table，并以只读原生表格呈现；支持表头、普通行、空单元格、转义管道、行内代码中的管道，并识别/保留规范 Markdown 中的左/中/右对齐标记。结果窗口的表头和所有单元格统一居中，避免小卡片中视觉左右跳动；复制 Markdown 仍保留原始对齐标记。表格固定使用结果卡正文可用宽度；每列按该列表头和全部单元格中的最长可见内容分配相对宽度，并用合理的最小/最大权重避免极端比例，超出列宽的内容自然换行，不引入水平滚动。畸形表格必须诚实降级为普通 Markdown 文本，不猜测行列。
- `strong` / bold 必须显式映射为可辨认的粗体字重，并在段落、列表、链接与斜体组合中保持；不得只依赖可能被外围字体覆盖的解析 intent。
- 完成态富文本必须形成一个连续原生文本选区，允许跨标题、段落、列表、引用、代码和表格拖选；从渲染视图复制选区不得凭空增加末尾空行。
- 完成态 Markdown 只允许一个原生纵向滚动所有者；滚轮或触控板位于普通段落、表头或单元格上时都必须能上下滚动，表格不得因滚动条显隐改变正文宽度而反复横跳，也不得产生水平滚动或横向弹性。
- 渲染是只读展示投影，不改变会话保存、重试、语言/API profile 切换、最近记录、复制或 Rust/FFI 中的完整 Markdown 字符串。
- 结果卡主复制动作保持一击复制规范 Markdown；完成态 `semanticMarkdown` 同一控件的菜单提供显式“复制纯文本”，纯文本由同一完成态文档投影生成，链接只保留可见 label，表格按 TSV 输出。两种复制都移除非语义性的末尾换行，但不修改会话中的规范字符串。
- 复制成功反馈使用约 0.7 秒的稳定 `checkmark` 与格式化辅助功能文案；重复复制必须取消旧复位任务，旧任务不得提前清除新反馈。
- 渲染不得使用 WebView、执行 HTML/脚本或自动加载远程图片；纯文本会话和流式 Markdown 的现有显示行为保持不变。
- Vision 截图继续显式发送 `plainText`；划词按受保护 Copy 实际取得的 representation 发送 `semanticMarkdown` 或 `plainText`，不得伪造不存在的结构。
- 重试、语言切换、API profile 切换和会话状态保留原始内容格式。
- 增加 Swift/Rust 回归并同步数据合同、架构、功能规格、Accepted ADR、0.1.0 双语合同和 `STATUS.md`。
- 沿用已接受的 Paper Lantern 品牌，增加适配 18pt 菜单栏的单色 template 派生图标，并替换现有 `character.bubble` 状态项占位符；浅色、深色、选中态和辅助外观由 macOS 着色。
- 把 MenuBarExtra 面板标题区右上角的非交互 `character.bubble.fill` 身份占位符替换为 33.6pt 全彩 Paper Lantern，并相对初稿向下偏移 2pt；标题文字继续提供可访问的 App 身份，菜单功能动作仍使用 SF Symbols。

## Out of Scope

- 任意应用私有、不可解释或不可与可见文字交叉验证的 representation 转换。
- 使用 Accessibility selected text 作为生产划词内容源或受保护 Copy 失败后的内容兜底。
- 截图结构 OCR、云端 OCR、PDF/Office 或文档工作区。
- 严格 Markdown AST/Block/Inline 一一映射、按原位置回填或要求源/译结构同构。
- 流式 Markdown 实时富渲染或增量 AST；WebView、远程资源加载或脚本执行。
- 在同一次复制中同时写入 HTML/RTF/RTFD 等多 representation；本阶段只提供显式 Markdown 或显式纯文本单 representation 动作。
- 自动重试、Provider fallback、按 profile 配置结构化支持开关或完整 Provider 质量评分系统。
- 把 Paper Lantern 用作菜单命令、设置、工具栏或结果卡的功能图标；修改菜单内容、状态项交互、AppIcon 主标志或品牌色。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-16 | Project owner | 明确不同语言不能按原节点或字符位置机械回填，只要求模型大致保持 Markdown 结构 | 验收改为完整上下文翻译、自然语序与软结构保持，不做 AST 同构比较 | Verified |
| 2026-08-16 | Project owner | 要求实测 `qwen-mt-turbo` Markdown 能力 | 增加真实标题、列表、链接、代码、变量和占位符样本；记录累计流行为 | Verified |
| 2026-08-16 | Project owner | 将 IDEA-013 提升为 Task 并开始实施 | 激活共享格式合同、Provider capability 与快速输入 Markdown 第一阶段 | Verified |
| 2026-08-16 | Project owner | 指出只在窗口显示原始 Markdown 不构成完整用户价值，要求直接补入完成后渲染；实时渲染后续再做 | 扩展同一 Task：完成态安全原生富渲染、流式原文不变、复制仍保留完整 Markdown | Verified |
| 2026-08-16 | Project owner | 用 FluxMarkdown 实测发现划词翻译和 Quick Input 富文本粘贴都会在采集入口压平，要求扩展 Task 并继续 | 扩展同一 Task：原生富文本归一、AX/Copy 划词闭环、Quick Input 富文本 Paste、真实多 representation 验收 | Implemented; Manual Verification Pending |
| 2026-08-16 | Project owner | GitHub README 实测继续得到纯文本；确认浏览器 AX 选区被压平后，要求生产划词以后只使用模拟 `⌘C` 内容路线 | 废止 AX-first/default-off Copy fallback：受保护 Copy 成为唯一生产内容源，AX 仅保留非内容职责；Copy 失败必须明确失败 | Implemented; Manual Verification Pending |
| 2026-08-16 | Project owner | AppIcon 已使用 Paper Lantern，但状态栏仍是占位图标，要求制作并接入正式状态栏图标 | 增加 18pt 单色 template 资产、编译产物检查、浅色/深色/选中态截图与五维复审；菜单内容与功能 SF Symbols 不变 | Verified |
| 2026-08-16 | Project owner | 确认状态栏灯笼已看到，并要求把菜单面板标题区右上角的蓝色 `character.bubble.fill` 也换成那盏灯 | 增加独立 32/64px 全彩 asset rendition、固定 App 编译检查及浅色/深色菜单面板复审；该位置只表达 App 身份，不改变交互或功能图标 | Verified |
| 2026-08-16 | Project owner | 指出复制按钮长时间发白、需要复制纯文本入口，并要求增强 Markdown 表格与粗体 | 默认一击复制 Markdown，原生菜单增加显式纯文本；反馈改为短促可取消的勾选；增加 GFM 表格与显式 strong 样式 | In Progress |
| 2026-08-16 | Project owner | 指出完成态 Markdown 只能在一个文本块内拖选，且拖选/复制出现额外末尾换行 | 完成态改为一个连续原生文本选区；跨块选择和无多余末尾空行纳入自动化与实机验收 | In Progress |
| 2026-08-16 | Project owner | 真实查看首版表格后认为自动压缩排版很差；先要求表格横向滚动和按最长内容自适应，随后明确接受固定正文宽度并让长单元格换行 | 最终收敛为表格占正文可用宽度、各列按最长可见内容分配受限比例、内容自然换行；不保留整页或表格水平滚动 | In Progress |
| 2026-08-16 | Project owner | 查看按 GFM 标记呈现的左/中/右对齐后认为文字位置跳动，要求统一居中 | 结果窗口表头和单元格统一居中；解析与规范 Markdown 复制继续保留原始对齐标记 | In Progress |
| 2026-08-16 | Project owner | 查看首版真实深色面板后，要求灯笼向下移动一点并放大 20% | 视觉规格从 28pt 调整为 33.6pt、向下偏移 2pt，源 rendition 重导出为 34/68px；重新构建并复审对齐、清晰度与视觉权重 | Verified |
| 2026-08-16 | Project owner | 真实浏览器中混合段落与表格选择会失败，重复同一选择还会让 Marla 崩溃 | 增加混合 HTML 段落/表格归一回归；修复完成态原生文本视图在 `layout()` 中反复失效 intrinsic size 导致的 AppKit/SwiftUI 布局递归；固定 App fixture 启动无崩溃，真实浏览器混合选择仍需复验 | Implemented; Manual Verification Pending |
| 2026-08-16 | Project owner | 重启后确认不再崩溃，但完成态表格宽度反复横跳，右侧纵向滚动条反复出现/消失且无法上下滚动 | 完成态 Markdown 改为单一原生 `NSScrollView` 所有者，纵向 scroller 固定为 overlay、关闭水平 scroller/弹性，并移除 SwiftUI/AppKit 双重高度测量与 intrinsic 失效链；增加滚动配置和等价文档不重复更新回归 | Verified |

## Current evidence

- 用户提供的两份 21:42 崩溃报告均为 `EXC_BREAKPOINT/SIGTRAP`，异常链落在 `MarkdownSelectableTextView.layout()` 触发 `invalidateIntrinsicContentSize()` 后反复请求 SwiftUI/AppKit 布局；移除该布局回调中的自失效后，固定 Release App 的完成态 Markdown fixture 已启动、截图并自动退出，无同类崩溃。
- 项目所有者在重新构建的固定 App 中复验同类混合内容，确认“不再崩溃”；随后准确观察到表格宽度与右侧纵向滚动条反复显隐的耦合抽搐，最终固定 App 改为单一原生滚动所有者后再次确认“正常啦”，表格区域可上下滚动且不再横跳。
- 完成态 Markdown 不再把裸 `NSTextView` 嵌入 SwiftUI `ScrollView`，也不再用 `sizeThatFits`、intrinsic height 和反复 intrinsic invalidation 共同驱动同一文档。专用 `NSScrollView` 使用 overlay 纵向 scroller、关闭水平 scroller 和横向弹性；`MarkdownSelectableTextView` 以不可变输入快照判断内容变化，避免 TextKit 规范化属性后把等价文档误判为整篇变化并重复安装。
- 新增段落 + HTML table + 后续段落的单 representation 归一回归，证明混合内容会构成一个完整 `semanticMarkdown` 文档，而不是只保留表格；`NativeFormattedContentTests` 当前 13/13 通过。
- `qwen-mt-turbo` 真实请求接受完整 Markdown，并返回可用 Markdown；标题、列表、粗体、链接目标、代码围栏、命令、`MARLA_API_KEY` 和 `{{STATUS}}` 均保留。
- 同一真实请求产生 19 次累计内容更新；现有 Rust Qwen-MT 分支已能把累计内容归一为增量事件。
- Rust 已集中 `ProviderCapabilities`，由消息角色、语言指令和流内容模式三个维度描述通用模型与 Qwen-MT 的差异。
- FFI schema v3、`TranslationFFIRequest`、会话与最近记录使用 `TranslationContent { format, text }`；schema v2 与未知格式都会被拒绝。
- Quick Input 将完整输入声明为 `semanticMarkdown`，并在重试、语言切换、profile 切换和最近记录恢复中保留格式。
- 生产划词入口现在无条件进入受保护 Copy 内容事务：只使用本次新 Markdown、HTML、RTF/RTFD 或纯文本 representation 构造 `TranslationContent`；Copy 失败不会读取 AX 内容兜底，Vision 始终为 `plainText`。
- Foundation 全量 Markdown 解析结果现在按块投影为原生 SwiftUI 标题、段落、列表、引用、代码和链接；远程图片属性被移除并只保留替代文字。
- 状态门控只允许 `semanticMarkdown + completed` 使用富文本投影；流式、失败部分内容、取消和所有 `plainText` 继续显示原始字符。
- 项目所有者的 FluxMarkdown 实测证明原第一阶段只保留“已经是 Markdown 源码的字符串”，由此触发的扩展已在工作树加入：Copy 在恢复前读取富 representation，Quick Input 以原生 `NSTextView` 拦截 Paste 并插入规范化 Markdown 或已校验的纯文本降级。项目所有者随后确认旧固定 App 的 FluxMarkdown 划词已能得到 Markdown，但 Zen/GitHub 仍因 AX-first 路径得到纯文本；新的 Copy-only 固定 App 复验仍待完成。
- Zen 中真实 GitHub README 的 AX 树可见标题、列表标记、链接与代码节点，但 Computer Use 的当前选区只暴露一条压平字符串；同一选区手动 Copy 可被 Quick Input 和 Obsidian 从 HTML 等 Pasteboard representation 转为 Markdown。项目所有者据此授权不再使用 AX 内容路线。
- 旧补全事务只等待 350ms；浏览器生成较大 HTML representation 时超时会被 AX-first 路径静默掩盖为纯文本。Copy-only 路径把上限调整为 800ms，取得新 `changeCount` 后仍立即继续，不固定增加等待。
- 项目所有者已在固定 App 中确认新的状态栏灯笼可见。菜单面板标题区使用独立的全彩 `PaperLanternMark` 1x/2x rendition，并以 33.6pt、向下偏移 2pt 的非交互品牌位替换 `character.bubble.fill`；它不继承系统 accent，也不改变菜单内功能 SF Symbols。
- 重新打包后的固定 Release App 已通过内置 UI 场景生成 `/private/tmp/marla-task-028-menu-dark-final.png` 与 `/private/tmp/marla-task-028-menu-light-final.png`。两种外观中灯笼边缘清晰、无裁切，与标题形成次级身份焦点；项目所有者现场确认尺寸和位置“刚刚好”。五维复审为 Philosophy 8、Visual Hierarchy 8、Craft 9、Functionality 9、Originality 8。

## Implemented approach

Swift 定义跨入口共享的格式化内容值，入口负责声明自己实际拥有的格式证据。FFI schema v3 传递 `sourceContent: { format, text }`；Rust 验证格式并把内容交给 Provider adapter。Provider capability 统一描述消息策略与流内容模式：通用模型允许 System Message 并返回增量，Qwen-MT 只接受 User Message、使用专用语言字段并返回累计内容。

快速输入使用 `semanticMarkdown`，因为普通文本是合法 Markdown 子集，且显式 Markdown 源码无需猜测即可保留。结果卡在流式阶段继续显示原始 Markdown 字符和游标；只有完成态才通过 `MarkdownResultDocument` 的结构化解析结果构建原生 SwiftUI 块视图。解析失败回退原始字符，远程图片只显示替代文字。会话始终保存完整 Markdown，复制与请求重建链路不读取渲染投影。

原生采集由 `NativeFormattedContentNormalizer` 统一处理。Pasteboard 选择有效 Markdown UTI、HTML、RTFD、RTF 和纯文本；有 plain projection 时必须通过可见文字一致性校验，冲突即使用已校验的 plain 值。HTML 只做本地结构化解析，丢弃脚本、样式、明确隐藏的节点、图片资源和不安全链接。生产划词始终先快照 Pasteboard，再模拟一次 `⌘C` 并只接受本次变化；读取、清洗后恢复并复核完整快照。AX 不再参与内容选择。

## Acceptance criteria

- [x] Swift/Rust schema v3 使用带 `format` 和 `text` 的源内容对象，schema v2 不再被当前 App 发出或静默接受。
- [x] `plainText` 与 `semanticMarkdown` 都有明确验证、编码和回归测试；未知格式被拒绝为无效配置。
- [x] Provider capability 集中决定消息策略、语言参数策略和流内容模式。
- [x] 通用模型的 Markdown 请求包含格式保持与受保护负载规则；纯文本请求保持现有翻译提示语义。
- [x] Qwen-MT Markdown 请求没有 System Message，保留完整 Markdown，并继续正确归一累计流。
- [x] 快速输入发送 `semanticMarkdown`；划词按可靠证据发送 `semanticMarkdown` 或 `plainText`，Vision 发送 `plainText`。
- [x] 流式 `semanticMarkdown` 继续显示原始字符和游标，不提前富渲染；进入 `completed` 后切换为可选择的原生富文本。
- [x] 完成态标题、强调、列表、引用、行内代码、代码围栏和链接样本可读；无效 Markdown 或解析失败安全降级为原始字符。
- [x] 渲染投影不修改完整 Markdown；复制、重试、语言/API profile 切换和最近记录恢复继续使用原始内容。
- [x] `plainText` 完成态、失败后部分内容、取消和流式布局没有渲染行为回归。
- [x] 固定 Release App 中完成态 Markdown 通过浅色、深色与 Reduce Motion 截图复审，五个维度均不低于 7/10。
- [x] 重试、语言切换和 API profile 切换不丢失内容格式或重新采集源内容。
- [x] 现有纯文本翻译、取消、错误映射、最近记录和复制行为无回归。
- [x] 新增代码未使任何源文件超过结构门禁，且 Models 目录不引入 AppKit/SwiftUI。
- [x] `./scripts/check.sh` 通过。
- [ ] 固定 Release App 中用 Markdown 快速输入完成一条真实或项目所有者输入凭据后的手动验证；凭据不得进入测试、日志或文档。
- [x] IDEA-013、Accepted ADR、数据合同、架构、Quick Input、0.1.0 双语合同和 `STATUS.md` 与实际行为一致。
- [x] Markdown、HTML、RTF/RTFD、attributed text 和纯文本有确定的 representation 优先级、可见文本一致性校验、清洗与降级测试；HTML 转换不执行内容、不加载远程资源。
- [ ] Quick Input 富文本 Paste 转换为 Markdown 源码后进入草稿；普通粘贴、直接输入、中文输入法、选择替换、撤销和 `⌘Return` 行为无回归。
- [x] 生产划词内容只来自受保护 Copy；Accessibility selected text 不再进入会话，也不在 Copy 失败时兜底。
- [x] 受保护 Copy 事务在恢复前取得并转换本次新增的富 representation，继续通过完整快照恢复、并发写、取消、超时和焦点保护回归。
- [x] 旧的默认关闭兼容开关与 AX-first 文案已移除；设置页清楚披露每次划词会临时使用并完整恢复 Pasteboard。
- [x] 划词的富格式会话和 Quick Input 草稿以 `semanticMarkdown` 进入 Provider，完成后使用现有原生渲染；划词无结构证据时保持 `plainText`，Quick Input 普通草稿仍是合法 Markdown 子集。
- [ ] 使用 FluxMarkdown 或等价的真实 Markdown/HTML/RTF 多 representation 内容完成固定 Release App 的划词与 Quick Input 验收，并确认原 Pasteboard 完整恢复。
- [x] 菜单栏使用可辨认的 18pt 单色 Paper Lantern template，不再显示 `character.bubble`；Asset Catalog 同时包含 1x/2x rendition，固定 Release 包验证会检查两者。
- [x] 在真实固定 Release App 中检查菜单栏灯笼；图标清晰、无固定品牌色、无裁切或模糊，项目所有者已确认可见。
- [x] 菜单面板标题区使用 33.6pt 全彩 Paper Lantern 并向下偏移 2pt，不再显示蓝色 `character.bubble.fill`；Asset Catalog 同时包含 34/68px rendition，固定 Release 包验证会检查两者。
- [x] 真实固定 Release App 的浅色和深色菜单面板中，灯笼清晰、比例正确、与标题对齐且不争夺主操作；五维 UI 复审每项不低于 7/10，项目所有者确认尺寸和位置“刚刚好”。
- [ ] 完成态 GFM pipe table 以正文可用宽度的原生只读表格显示，覆盖表头、行列、空单元格、转义/代码管道和对齐标记解析；窗口内所有表头/单元格统一居中，规范 Markdown 复制保留原始对齐标记；各列按最长可见内容分配受限比例并自然换行，380pt/760pt 均无水平滚动或异常挤压，畸形表格安全降级。
- [ ] `**strong**` / `__strong__` 在段落、列表、链接和斜体组合中保持明确粗体，浅色与深色均可辨认。
- [ ] 完成态 Markdown 可跨标题、段落、列表、引用、代码和表格连续拖选；选区 Copy 不增加非语义末尾空行。
- [ ] 主复制动作一击复制规范 Markdown，菜单可复制派生纯文本；纯文本链接只保留 label、表格使用 TSV，两个动作都不修改规范会话内容。
- [ ] 复制反馈使用约 0.7 秒 `checkmark`，辅助功能文案区分 Markdown/纯文本；快速重复复制不会被旧复位任务提前清除。
- [ ] 380pt/760pt、浅色/深色/Reduce Motion 下表格、粗体、连续选区和复制控件不裁切、不撑坏卡片，五维评分均不低于 7/10。

## Verification

### Automated

```sh
./scripts/check.sh
```

Rust 请求捕获测试必须分别断言通用 Markdown、通用纯文本和 Qwen-MT Markdown payload；Swift 测试必须覆盖 schema v3 编码、入口格式、重试和 profile 切换。

### Manual

在固定 `artifacts/Marla_dev.app` 中从 FluxMarkdown 和 Zen/GitHub README 选择包含标题、列表、链接、强调与代码的内容：分别通过划词和 Quick Input Paste 验证输入先归一为 Markdown、流式内容不被剥离、完成后切换为原生富文本，且每次受保护 Copy 后原 Pasteboard 的全部 item/representation 完整恢复。再验证 Copy 超时、不可用或恢复失败时不发送 AX 纯文本，并提供明确错误/Quick Input 恢复动作。使用凭据的真实 Provider 验证由项目所有者输入或使用既有 Keychain profile，Agent 不读取或记录凭据。另用不接触凭据的 fixture 捕获浅色、深色和 Reduce Motion 结果卡与设置页，并捕获带全彩 Paper Lantern 标题身份位的浅色/深色菜单面板，执行五维复审。

## Required Reading

- `docs/backlog/IDEAS.md`（IDEA-013）
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/DATA_CONTRACTS.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `docs/architecture/decisions/ADR-0006-selection-copy-compatibility.md`
- `docs/architecture/decisions/ADR-0009-semantic-markdown-translation-contract.md`
- `docs/architecture/decisions/ADR-0008-paper-lantern-brand-identity.md`
- `docs/product/BRAND.md`
- `docs/features/quick-input.md`
- `docs/features/comparison-mode.md`
- `docs/features/language-routing.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/UI_SPEC.md`
- `Sources/MarlaApp/MarlaApp.swift`
- `Sources/MarlaCore/TranslationModels.swift`
- `Sources/MarlaCore/SelectionModels.swift`
- `Sources/MarlaApp/Content/NativeFormattedContent.swift`
- `Sources/MarlaApp/Selection/AccessibilitySelectionModels.swift`
- `Sources/MarlaApp/Selection/AccessibilitySelectionReader.swift`
- `Sources/MarlaApp/Selection/ClipboardSelectionFallback.swift`
- `Sources/MarlaApp/Sessions/TranslationSessionStore.swift`
- `Sources/MarlaApp/Sessions/QuickInputView.swift`
- `Sources/MarlaApp/Sessions/QuickInputMarkdownEditor.swift`
- `Sources/MarlaApp/Panel/TranslationCardView.swift`
- `Sources/MarlaApp/Panel/MarkdownResultText.swift`
- `Sources/MarlaApp/Panel/MarkdownResultSelectableText.swift`
- `Sources/MarlaApp/App/ResultPanelLayout.swift`
- `Sources/MarlaApp/App/MarkdownResultUIAutomation.swift`
- `rust/marla-core/src/lib.rs`
- `Tests/MarlaCoreTests/MarlaCoreTests.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`
- `Tests/MarlaAppTests/MarkdownResultTextTests.swift`
- `scripts/verify-app.sh`

## Parallel contributors (optional)

- `task028_docs`：独占同步完成态原生 Markdown 渲染相关 Quick Input、架构、ADR-0009 与 0.1.0 双语文档。
- `task028_rich_docs`：独占同步富文本采集相关 Quick Input、架构、数据合同、ADR-0006/0009 与 0.1.0 双语文档，并在实现后做只读一致性复核。
- 两名贡献者均不得编辑本 Task、`STATUS.md`、Ideas/Backlog、代码、测试或验收勾选；主 Agent 负责最终措辞、整合、冲突处理和验证。

## Risks and rollback

- Schema v3 同时影响 Swift、Rust、测试和文档；任何一侧遗漏都会导致请求被拒绝。版本升级必须原子验证。
- Markdown 提示增加 token 和 TTFT；纯文本入口不得无条件承担该成本。
- Qwen-MT 的格式保持来自模型能力而非 System Message 保证；回归只能证明样本，不得宣称所有输入可靠。
- Copy-only 会让每次划词都短暂改写 Pasteboard；完整快照恢复、前台身份、并发写和取消保护因此从可选兼容边界升级为生产正确性与隐私边界。
- 不再使用 AX 内容兜底后，不支持标准 Copy 的应用会明确失败并引导 Quick Input，而不会翻译一个结构已丢失的 AX 字符串。
- 原始 Markdown 在流式阶段可能视觉粗糙，但比解析未闭合结构更稳定；实时增量渲染仍需独立证据和 Task。
- 回滚时恢复 schema v2 单字符串请求、删除格式化内容类型和 Markdown 分支，并同步撤销相关合同；不得保留 Swift/Rust 半升级状态。

## Decisions needed

None for this stage. 项目所有者已经确认完整 Markdown 交换、自然语序优先、结构软保持、完成态原生富渲染、固定为正文可用宽度并按最长可见内容自适应列比例/自然换行的 GFM pipe table、显式粗体、跨块连续选择，以及 Markdown/纯文本两个单 representation 复制动作。默认一击复制 Markdown；纯文本链接只保留 label，表格使用 TSV。流式实时富渲染与同次 HTML/RTF 多 representation 输出复制留待后续证据。

## Completion record

- Verified commit: 尚未提交；当前验证针对工作树实现。
- Automated evidence: 富采集扩展专测 13/13 通过，覆盖 Markdown/plain 一致与冲突、HTML 清洗/显式隐藏节点/不安全链接、混合段落与表格、RTF、RTFD、Foundation attributed semantics、plain 降级，以及 Quick Input 富 Paste 和已校验 plain fallback 的选择替换。新增 2 项生产划词测试证明受保护 Copy 的 `semanticMarkdown` 会进入会话，并且 Copy 超时不会回退 AX 内容。完成态滚动修复新增 3 项定向回归并全部通过：单一原生纵向滚动所有者/无水平弹性、长混合表格可纵向移动且无横向偏移、等价富文档不重复安装。当前无界面环境运行全量检查时，只有依赖系统 Pasteboard 读写的 2 个复制测试无法取得内容；Rust、其余 Swift 测试、新增混合内容测试和固定 Release 构建均通过。
- Manual evidence: Copy-only 扩展后的 `./scripts/build-test-app.sh` 已重建并验证固定 `artifacts/Marla_dev.app` 的 Release 路径、Bundle ID `com.marla.app`、版本 0.1.0、最低系统 14.0、arm64、可执行文件、稳定签名 `API Usage Monitor Dev` 与 designated requirement。项目所有者确认同类混合选择不再崩溃，并在原生滚动修复后的新固定 App 中确认表格与纵向滚动“正常啦”。修复后浅色/深色完成态证据位于 `/private/tmp/marla-task028-table-scroll-fixed-light.png` 与 `/private/tmp/marla-task028-table-scroll-fixed-dark.png`，五维复审为 8/8/8/9/7；原生 Quick Input 的对应 fixture 位于 `/private/tmp/marla-quick-input-light.png`、`/private/tmp/marla-quick-input-dark.png`、`/private/tmp/marla-quick-input-reduce-motion.png`，五维复审为 8/8/9/8/8。更新后的“通用”设置页浅色、深色与 Reduce Motion 证据位于 `artifacts/ui-review/task-028/`，五维复审为 8/8/8/9/7。
- Manual gap: 项目所有者已确认旧固定 App 的 FluxMarkdown 划词可得到 Markdown，但 Zen/GitHub 在旧 AX-first 路径仍为纯文本；本次真实浏览器混合选择的 Copy/Markdown 结果和新固定 App 的 Pasteboard 恢复仍需项目所有者复验。Computer Use 证实 GitHub AX 选区被压平；真实 Provider 请求同样仍待项目所有者使用既有 Keychain profile 验收。
- Documentation updated: IDEA-013、ADR-0006/0009、架构、数据合同、Quick Input、比较模式、语言路由、0.1.0 双语规格/实现与 STATUS 已同步。
- Remaining work promoted to: 固定 App 的真实 Markdown Provider 请求、FluxMarkdown 划词/Quick Input/Pasteboard 恢复保留在本 Task；截图结构 OCR、实时增量渲染和 HTML/RTF 多 representation 输出复制保留在 IDEA-013。
- Scope changes closed: 前四项已验证；第五项工作树实现与自动化已完成；本次混合内容、布局崩溃和滚动/表格抽搐修复已通过自动化、固定 fixture 与项目所有者现场复验。真实浏览器多 representation、Pasteboard 恢复和 Provider 请求仍待项目所有者现场完成，Task 保持 Active。
- Parallel contributions integrated: `task028_docs` 和 `task028_rich_docs` 的独占文档贡献已整合；后者的只读复核发现并推动修复了 Markdown/plain 校验绕过与 Quick Input plain fallback 绕过。
