# Marla 0.1.0 产品规格 / Product Specification

状态 / Status: Withdrawn before release — historical draft only

版本 / Version: 0.1.0

最后更新 / Last updated: 2026-08-18

> 本文每节先给出中文规范，再给出英文镜像。发生歧义时以中文为准；两种语言必须在同一次修改中同步。
>
> Each section contains the normative Chinese text followed by its English mirror. If they differ, the Chinese text controls. Both languages must be updated in the same change.

> 本发布目标已于 2026-08-18 在公开发布前撤回。正文保留当时的双语范围快照和证据语境，但不再约束当前孵化开发；当前版本策略见 `docs/development/VERSIONING.md`。
>
> This release target was withdrawn before public release on 2026-08-18. The body remains as a bilingual scope snapshot and evidence context, but no longer constrains current incubation; see `docs/development/VERSIONING.md` for the active policy.

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
| 划词翻译 | `⌃⌥D` | 通过受保护 Copy 取得当前前台应用的选中内容，在选区附近显示结果卡片 |
| 截图翻译 | `⌃⌥S` | 进入跨屏框选，使用 Vision 本地识别后翻译文字 |
| 快速输入 | `⌃⌥Space` | 在指针附近打开可输入和粘贴的翻译卡片 |

三个快捷键均可在设置中独立关闭或重新录制；关闭只停止对应全局监听，不隐藏菜单入口。录制时必须检测与 Marla 其他入口的内部冲突；如果系统或其他应用已经占用组合键但无法可靠检测，界面应明确提示用户实际试用并提供恢复默认值操作。

MenuBarExtra 标题区把 “Marla” 与副标题作为一组向上进行 14pt 视觉校正，使标题字形顶部到面板上边框的距离约为 24pt，即 16pt 左侧留白的 1.5 倍；右侧 33.6pt 全彩 Paper Lantern 保持既有尺寸和位置，包括原有的向下 2pt 视觉校正。

Marla 处于激活状态时，标准 macOS `⌘,` 应打开设置并复用已存在的设置窗口。该命令属于应用设置命令，不是跨应用全局监听，也不进入上述三个可录制翻译快捷键。

### English

0.1.0 provides three independent global entry points:

| Entry | Default shortcut | Behavior |
| --- | --- | --- |
| Selection translation | `⌃⌥D` | Acquire selected content from the frontmost app through protected Copy and present a result card near the selection |
| Screenshot translation | `⌃⌥S` | Enter cross-display region selection, recognize locally with Vision, then translate the text |
| Quick input | `⌃⌥Space` | Open a paste-and-type translation card near the pointer |

Each shortcut can be independently disabled or recorded in Settings. Disabling stops only that global listener and does not hide the menu entry. Recording must detect conflicts among Marla actions. When reliable detection of a system or third-party conflict is impossible, the UI must ask the user to test the shortcut and provide a restore-defaults action.

The MenuBarExtra header applies a 14pt upward optical adjustment to the “Marla” title and subtitle as one group, making the title glyph's approximately 24pt top inset 1.5 times its 16pt leading inset. The trailing 33.6pt full-color Paper Lantern retains its existing size and position, including its existing 2pt downward optical adjustment.

When Marla is active, the standard macOS `⌘,` command opens Settings and reuses an existing Settings window. This is an application Settings command, not a cross-application global listener or a fourth recordable translation shortcut.

## 4. 划词翻译 / Selection Translation

### 中文

触发后，Marla 固定当前前台应用并验证 Accessibility 权限，然后把一次受保护模拟 `⌘C` 作为生产划词内容的唯一来源。Copy 前必须在内存中完整备份 `NSPasteboard.general` 的全部可读 item、类型、顺序和数据，并确认快照期间 `changeCount` 稳定；发送 Copy 前和接受结果前都必须确认触发时应用仍在前台。Marla 只接受本次 Copy 产生的新 `changeCount` 和非空内容，绝不把未变化或既有剪贴板值当作选区。

恢复前读取本次新增的 Markdown、HTML、RTF/RTFD 和纯文本 representation。富 representation 只有在可见文字与同一 Pasteboard item 内的本次新纯文本一致时才可归一为 `semanticMarkdown`；冲突或不支持的结构降级为该 item 本次已验证的 `plainText`。HTML 必须结构化本地解析并移除脚本、样式、显式隐藏节点、图片资源和不安全链接，不执行内容、不加载远程资源。原 Pasteboard 在成功、空结果、异常、取消和超时路径恢复，并重新读取比较完整快照；若其他进程在 Marla Copy 后写入，则保留较新的内容而不覆盖。快照、焦点、Copy、超时、内容或恢复失败都不得发送翻译请求，必须显示具体错误和快速输入入口；重复划词快捷键先取消并清理当前事务。

Accessibility 只保留权限与非内容定位职责。它可以用选区 range 或 Text Marker range 请求边界，但不得把 `AXSelectedText`、attributed value、`AXStringForRange`、`AXStringForTextMarkerRange` 或任何其它 AX 内容用于输入或兜底。无法得到可靠坐标时，完整结果卡降级到指针附近；内容仍只来自受保护 Copy。旧的默认关闭“兼容性取词”设置以及 AX-first/Copy-fallback 行为不再属于 0.1.0 合同。

### English

On invocation, Marla binds the current frontmost application, verifies Accessibility permission, and uses one protected simulated `⌘C` as the only production source of selected content. Before Copy it snapshots every readable item, type, order, and data representation in `NSPasteboard.general` and verifies that `changeCount` remained stable; it verifies the trigger-time application before sending Copy and immediately before accepting the result. Marla accepts only non-empty content written under a new `changeCount` by this Copy and never treats an unchanged or pre-existing clipboard value as the selection.

Before restoration, Marla reads the new Markdown, HTML, RTF/RTFD, and plain-text representations. Rich content normalizes to `semanticMarkdown` only when its visible text agrees with the newly copied plain text from the same Pasteboard item; conflict or unsupported structure degrades to that item's verified new `plainText`. HTML is parsed structurally in-process with scripts, styles, explicitly hidden nodes, image resources, and unsafe links removed, with no content execution or remote loading. The original Pasteboard is restored on success, empty result, error, cancellation, and timeout, then re-read and compared completely. A newer external write after Marla's Copy is preserved rather than overwritten. Snapshot, focus, Copy, timeout, content, or restoration failure sends no translation request and must show a specific error plus a Quick Input action. A repeated selection shortcut first cancels and cleans up the active transaction.

Accessibility retains permission and non-content positioning duties only. It may use selection ranges or Text Marker ranges to request bounds, but `AXSelectedText`, attributed values, `AXStringForRange`, `AXStringForTextMarkerRange`, and all other AX content are forbidden as input or fallback. Without reliable geometry the complete card falls back near the pointer; content still comes only from protected Copy. The former off-by-default “Copy compatibility” setting and AX-first/Copy-fallback behavior are no longer part of the 0.1.0 contract.

## 5. 截图翻译 / Screenshot Translation

### 中文

截图入口先在任何框选窗口出现前把所有活动显示器捕获为会话内存中的静态帧，再用这些冻结帧显示覆盖所有显示器的轻量框选层。依赖悬停的弹层保留触发瞬间画面，视频和动画在框选阶段显示为静止帧。系统十字光标旁显示来自同一冻结帧的短生命周期像素放大镜、中心准星和指针坐标，并在显示器边缘自动换位；拖动期间展示清晰边界和尺寸反馈，选区内外不得露出后续实时桌面。`Esc`、右键或未形成有效区域时取消，不进行 OCR、翻译或持久化。`Esc` 由当前截图会话统一处理，并同时保留 View、窗口 `sendEvent`/key-equivalent/`cancelOperation`、本地/全局监听和会话级系统事件 tap 路径，不依赖某一个框选 View 保持键盘焦点；会话结束后必须移除临时按键监听。冻结帧和放大镜采样只存在于当前框选会话内存中。进入框选时，Marla 临时隐藏自己已打开的设置窗口；框选结束后只恢复其原有可见状态，不得让设置窗口越过框选层或抢占源应用焦点。

确认区域后直接从同一组冻结帧按跨屏坐标和显示器缩放合成裁剪，不再次捕获实时桌面。随后释放全屏冻结帧，只在内存中保留裁剪图像，并使用 macOS Vision `VNRecognizeTextRequest` 本地识别。Vision 必须开启自动语言检测，并只把当前运行时实际支持的七门产品语言 OCR 标识作为候选；不能用固定中英文配置阻断日语、韩语或其它已适配语言。0.1.0 只保留纯文本、行顺序和换行，不承诺表格、公式、代码块、Markdown 或页面布局恢复。识别出的文字进入与其他入口相同的翻译管线，截图像素不进入 Rust 网络请求，也不上传给翻译服务。

没有识别到文字时显示重新框选和关闭操作，不发送空翻译请求。

### English

Before showing any selection window, the screenshot entry captures every active display into session-only static frames and uses those frozen frames for the lightweight cross-display selection layer. Hover-dependent surfaces retain their trigger-time appearance, and video or animation appears paused during selection. A short-lived pixel loupe from the same frozen frame beside the system crosshair shows a center reticle and pointer coordinates, flipping sides near display edges. Dragging shows a clear boundary and size feedback; neither the selected area nor the dimmed background may reveal the later live desktop. `Esc`, right-click, or an invalid region cancels without OCR, translation, or persistence. The active screenshot session owns `Esc` handling and retains View, window `sendEvent`/key-equivalent/`cancelOperation`, local/global monitor, and session-scoped system event-tap routes instead of relying on any one selection view to retain keyboard focus; all temporary key monitors are removed when the session finishes. Frozen frames and loupe sampling exist only in memory for the active selection session. When selection starts, Marla temporarily hides any open Settings window of its own. After selection, it only restores the previous visibility state; Settings may not rise above the selection layer or steal focus from the source application.

After confirmation, Marla composites the crop directly from the same frozen frames using cross-display coordinates and display scales; it does not recapture the live desktop. It then releases the full-display frames, keeps only the crop in memory, and uses macOS Vision `VNRecognizeTextRequest` for local recognition. Vision must enable automatic language detection and use only the seven product-language OCR identifiers that the current runtime actually supports; a fixed Chinese/English configuration may not block Japanese, Korean, or another adapted language. 0.1.0 preserves plain text, line order, and line breaks only; it does not promise table, formula, code-block, Markdown, or page-layout recovery. Recognized text enters the same translation pipeline as other entries. Screenshot pixels never enter the Rust network request and are never uploaded to the translation service.

When no text is recognized, the result offers reselect and close actions and sends no empty translation request.

## 6. 快速输入 / Quick Input

### 中文

快速输入在指针所在屏幕附近打开紧凑、可激活的输入卡片并立即聚焦编辑区。它支持中文输入法、英文输入、多行文字和粘贴，不修改已有剪贴板内容。显式输入或粘贴的 Markdown 源码原样进入草稿；原生 Paste 命令从 Markdown、HTML、RTF/RTFD 和纯文本 representation 中选择，富文本经会话内清洗并归一为语义 Markdown 源码后插入。富 representation 的可见文字必须与纯文本一致；冲突、不安全或无法解析时降级为可见纯文本。HTML 处理不得执行内容、加载远程资源或持久化输入。完整草稿按 `semanticMarkdown` 进入翻译合同；普通文本是其合法子集。

`⌘Return` 提交翻译，`Esc` 关闭。空白输入不能提交。提交后同一卡片平滑转为结果状态，保留原文格式以供对照、重试、语言切换和 API profile 切换。`semanticMarkdown` 在等待首个非空增量前显示原始字符；从首个非空增量开始，流式与完成态使用同一个安全原生只读投影。过密更新以约 40ms 的有界间隔合并，未闭合或暂不可解析的快照诚实显示当前原始字符，不丢失或修改 canonical Markdown。`completed` 到达时移除只属于视觉投影的流式游标，并按最终 attributed document 重新校正高度。完整 Markdown 字符串始终用于会话状态与复制；不承诺 HTML/RTF 多 representation 输出复制或跨事件持久化的增量 AST。

### English

Quick input opens a compact activatable card near the pointer on the current display and immediately focuses the editor. It supports Chinese IME input, English input, multiline text, and paste without modifying existing clipboard contents. Explicitly typed or pasted Markdown source enters the draft unchanged. The native Paste command chooses among Markdown, HTML, RTF/RTFD, and plain-text representations, cleaning rich content and inserting normalized semantic Markdown source. A rich representation's visible text must agree with plain text; conflict, unsafe content, or parse failure degrades to visible plain text. HTML handling may not execute content, load remote resources, or persist the input. The complete draft enters the translation contract as `semanticMarkdown`, with ordinary text as a valid subset.

`⌘Return` submits and `Esc` closes. Whitespace-only input cannot be submitted. After submission, the same card transitions smoothly into the result state and retains the source format for comparison, retry, language changes, and API-profile switching. A `semanticMarkdown` session shows raw characters until its first non-empty delta, then uses the same safe native read-only projection for streaming and completion. Dense updates are coalesced on a bounded interval of approximately 40ms. An incomplete or temporarily unparseable snapshot honestly shows its current raw characters without dropping or modifying canonical Markdown. On `completed`, the visual-only streaming cursor is removed and height is reconciled against the final attributed document. The complete Markdown string always backs session state and copy; multi-representation HTML/RTF output copy and a persistent incremental AST are not promised.

## 7. 结果卡片 / Result Card

### 中文

结果卡片先稳定定位和显示紧凑骨架，再接收流式内容；短译文不预留大块空白。卡片以 380pt 作为默认和最小宽度，用户可从原生窗口边缘或角落拖动到最多 760pt，实际最大值同时受当前屏幕可见工作区约束；宽度改变后译文按新行宽重排，并重新计算内容驱动高度。`semanticMarkdown` 的正文 viewport 与外层窗口都以当前 attributed document 的同一 TextKit 测量语义为准，不再用原始字符高度估算富投影。流式文本增长只沿远离选区/指针的方向平滑增高，保持初始锚定边和水平位置不变，不重播出现动画；每次高度动画结束后按当前会话和实时宽度做一次无动画校正，`completed` 到达并移除流式游标后再按最终文档执行最终校正，不能让首个 delta、过密更新或旧动画留下过时外框。达到当前屏幕可见工作区 60% 的最大高度后，外框停止增长，译文正文由单一原生纵向滚动 owner 承担溢出；不启用水平滚动或横向弹性。Reduce Motion 下不为流式投影增加位置动画。默认显示译文，用户可以展开对照原文。选择翻译与截图翻译的顶部状态行以 24pt 全彩 `PaperLanternMark` 作为不可交互的身份标志，旁边的动态入口标题使用 17pt semibold；快速输入继续使用键盘 SF Symbol 和既有紧凑标题样式。当前翻译 API 配置菜单向下移动 2pt。固定、关闭、语言行和所有控制语义保持不变；其下独立语言行左侧显示源语言，右侧显示实际目标语言。卡片提供：

- 复制译文；
- 重试当前请求；
- 使用 macOS 系统语音朗读译文，不打包 TTS 模型；
- 固定或取消固定；
- 覆盖源语言或目标语言并重新翻译；
- 关闭或取消进行中的请求。

流式与完成态富文本只是只读展示投影，应由一个连续的原生可选中文本表面呈现标题、段落、强调、列表、引用、代码和链接，选择可以跨越多个 block。首个非空增量后以约 40ms 的有界间隔合并过密快照，再从当前完整字符串构造 attributed document；不得逐字符重建或把它描述为持久化增量 AST。未闭合或暂不可解析的片段回退当前原始字符。规范支持格式良好的 GFM pipe table（表头、行、列、空单元格、转义/代码 pipe 与对齐信息）；解析继续识别并在 canonical Markdown 与复制 Markdown 中保留 GFM 对齐标记，但本地投影视觉上将表头和所有单元格统一居中，不按 `:---` / `---:` 做左/右对齐。表格固定在结果卡正文可用宽度内；每列根据该列表头和全部单元格中最长的可见文本自适应计算相对列宽，并设置合理的最低/最高权重，超出列宽的单元格自然换行。fenced code block 使用 5pt 圆角背景与 0.5pt 边框；inline code 使用 3pt 圆角背景，背景高度按代码字体收紧并在字形首尾各扩展 3pt，使相邻两行之间保留可见间隙。以上都只是原生 TextKit 视觉属性，不改变行高、选择、复制或 canonical Markdown。标题、段落、列表、引用和代码保持固定不移动；连续原生表面与跨块选择合同不变。并在段落、列表、链接和斜体组合中保持 `**strong**`/`__strong__` 可见加粗；畸形表格回退原始 Markdown。该表格与代码样式能力适用于译文和可靠 `semanticMarkdown` 原文的本地投影，不意味着 Vision/OCR 能从截图中恢复表格结构。原始 Markdown 字符串和 `semanticMarkdown` 格式仍是复制、重试、源/目标语言切换、API profile 切换和会话内最近记录恢复的规范内容；流式游标与渲染投影不得反向写入它们。`plainText` 的流式和完成态显示保持不变，失败后的部分结果与取消态也不得进入 Markdown 富渲染。投影必须使用原生 SwiftUI/AppKit 能力，不使用 WebView，不执行 HTML 或脚本，也不自动加载远程图片或其它资源。

任何会话状态下展开“查看原文”时，如果 canonical `sourceContent.format` 为 `semanticMarkdown` 且解析成功，静态原文都复用同一套安全的原生 Markdown/TextKit 只读投影，支持标题、强调、列表、引用、行内与围栏代码、链接和 GFM 表格。原文 viewport 最高 110pt，溢出只由一个原生纵向滚动 owner 承担。解析失败、`plainText` 和 Vision OCR 原文继续显示纯文本。该投影不得修改 canonical `sourceContent`；重试、源/目标语言切换、API profile 切换和会话内最近记录恢复仍必须使用 canonical 原文，而不是渲染文本。

主复制动作复制规范 Markdown，仅移除末尾非语义的 `\n`/`\r`；菜单中的纯文本复制是只读派生投影，链接只保留可见标签、Markdown 表格转为 TSV。选区内 `⌘C` 同样只移除末尾非语义换行，不产生 HTML/RTF 多 representation 输出；规范会话字符串保留原样及所有有意义的换行。

选择翻译和截图翻译的卡片首次出现时不激活 Marla。用户点击卡片控件时可以主动激活。临时卡片在 `Esc` 或外部点击时关闭并取消未完成请求；固定卡片不会因外部点击关闭。关闭、重试或切换语言都必须先取消旧请求，迟到事件不得覆盖新会话。源/目标语言切换只复用已取得的原文，不重复受保护选择 Copy、截图捕获或 Vision OCR。

### English

The result card establishes a stable position and compact shell before accepting streamed content; short translations do not reserve a large empty area. Its default and minimum width is 380pt. Users can drag native window edges or corners up to 760pt, with the actual maximum also constrained by the current screen's visible workspace; changing width reflows translation text and recomputes the content-driven height. For `semanticMarkdown`, the body viewport and outer window both use the current attributed document's TextKit measurement semantics instead of estimating a rich projection from raw-character height. As streamed text wraps to additional lines, the card grows smoothly away from the selection/pointer while keeping its initial anchored edge and horizontal position stable, without replaying the entry animation. It reconciles without animation after each height animation, then reconciles once more against the final document when `completed` removes the streaming cursor, so an early delta, dense update, or stale animation cannot leave an outdated frame. At 60% of the current screen's visible workspace, the outer frame stops growing and one native vertical scrolling owner handles body overflow, with no horizontal scrolling or elasticity. Reduce Motion adds no positional animation for streaming projection. Translation is shown by default, with source comparison available on demand. Selection and screenshot top status rows use a non-interactive 24pt full-color `PaperLanternMark` beside the dynamic entry title in 17pt semibold; Quick Input retains its keyboard SF Symbol and existing compact title treatment. The current translation API-profile menu moves 2pt downward. Pin, close, language-row, and all control semantics remain unchanged. A separate language row below shows source on the left and the effective target on the right. The card provides:

- copy translation;
- retry current request;
- read translation through macOS system speech, with no bundled TTS model;
- pin and unpin;
- override source or target language and retranslate;
- close or cancel in-flight work.

Streaming and completed rich text is a read-only projection rendered by one continuous native selectable text surface for headings, paragraphs, emphasis, lists, blockquotes, code, and links, allowing selection across blocks. After the first non-empty delta, dense snapshots are coalesced on a bounded interval of approximately 40ms before constructing an attributed document from the current complete string; the implementation may not rebuild on every character or describe this as a persistent incremental AST. Incomplete or temporarily unparseable fragments fall back to their current raw characters. Well-formed GFM pipe tables support headers, rows, columns, empty cells, escaped/code pipes, and alignment metadata. Parsing recognizes GFM alignment markers and canonical Markdown plus canonical Markdown copy retain them, while the local projection centers the header and every cell uniformly rather than visually left/right-aligning from `:---` or `---:`. Tables remain within the result card's usable body width. Each column adapts to the longest visible text among its header and all cells, bounded by reasonable minimum and maximum weights; cell text beyond its column width wraps naturally. Fenced code blocks use a 5pt rounded background with a 0.5pt border. Inline code uses a 3pt rounded background whose height follows the code font and extends 3pt beyond both glyph edges, leaving a visible gap between adjacent lines. These are native TextKit visual attributes only and do not alter line height, selection, copy, or canonical Markdown. Headings, paragraphs, lists, blockquotes, and code remain fixed, while the continuous surface and cross-block selection contract remain unchanged. `**strong**`/`__strong__` remains visibly bold in paragraphs, lists, links, and italic combinations; malformed tables fall back to raw Markdown. These table and code-style behaviors apply to local translated-result and reliable `semanticMarkdown` source projections; they do not make Vision/OCR recover table structure from screenshots. The raw Markdown string and `semanticMarkdown` format remain canonical for copy, retry, source/target changes, API-profile switching, and in-memory recent-result restoration; neither the visual cursor nor the projection may write back into them. Streaming and completed `plainText` presentation stays unchanged, while failed partial output and cancelled sessions do not enter Markdown rich rendering. The projection must use native SwiftUI/AppKit facilities, with no WebView, HTML or script execution, or automatic loading of remote images or other resources.

Whenever “View Source” is expanded in any session state, static canonical `sourceContent` whose format is `semanticMarkdown` reuses the same safe native Markdown/TextKit read-only projection when parsing succeeds, including headings, emphasis, lists, blockquotes, inline and fenced code, links, and GFM tables. The source viewport is capped at 110pt, and one native vertical scrolling owner handles any overflow. Parse failure, `plainText`, and Vision OCR source remain plain text. The projection may not modify canonical `sourceContent`; retry, source/target language changes, API-profile switching, and in-memory recent-result restoration continue to use canonical source rather than rendered text.

The primary copy action copies canonical Markdown, removing only terminal non-semantic `\n`/`\r`. Menu plain-text copy is a read-only derived projection (visible link labels only; Markdown tables as TSV). Selection `⌘C` applies the same terminal-newline rule and emits no HTML/RTF multi-representation output; canonical session text retains its original meaningful line breaks.

Selection and screenshot cards do not activate Marla when first presented. Clicking card controls may intentionally activate it. `Esc` or outside click closes a transient card and cancels unfinished work; pinned cards remain open. Close, retry, and language changes cancel the old request first, and late events may never overwrite a newer session. Source/target changes reuse acquired text without repeating protected selection Copy, screenshot capture, or Vision OCR.

## 8. 语言规则 / Language Rules

### 中文

设置中的“翻译语言”页面提供全局母语和第二语言，产品选项为简体中文（`zh-Hans`）、English（`en`）、日本語（`ja`）、Français（`fr`）、Español（`es`）、Deutsch（`de`）和 한국어（`ko`），两者不能相同，默认分别为简体中文和 English。设置变化只影响之后的新翻译，不静默重译已经打开的卡片。

Swift 在本机用 `NLLanguageRecognizer` 处理本次明确触发的原文。系统识别到的中文家族归一为简体中文；支持的识别结果在请求前进入会话。自动目标规则为：源语言等于母语时译成第二语言，其他支持语言或未知源语言译成母语。无法映射为产品语言时显示“自动识别：未知”，目标仍明确为母语，并让 Provider 自动识别源语言。

结果卡源语言菜单提供自动识别和全部七门产品语言，目标菜单提供自动路由和全部七门产品语言。源语言覆盖只在目标仍为自动时重新路由；手动目标始终具有最高优先级。语言切换使用已有原文重新翻译。

提示词必须把源文本明确标记为数据而不是指令，并要求尽量保留换行、标点、专有名词、代码标识符和终端参数。

### English

The Translation Languages Settings page provides one global native language and one different secondary language. Product choices are Simplified Chinese (`zh-Hans`), English (`en`), Japanese (`ja`), French (`fr`), Spanish (`es`), German (`de`), and Korean (`ko`), defaulting to Simplified Chinese and English. Setting changes affect future translations only and do not silently retranslate an open card.

Swift uses `NLLanguageRecognizer` locally on the explicitly triggered source. System-detected Chinese variants normalize to the Simplified Chinese product option, and supported results enter the session before the request. Automatic routing sends the native language to the secondary language and every other supported or unknown source to the native language. An unmapped result is shown as “Auto-detected: Unknown”; the target is still explicitly the native language while the Provider detects source.

The result-card source menu provides automatic detection and all seven product languages. The target menu provides automatic routing and all seven languages. A source override recomputes direction only while target remains automatic; an explicit target always wins. Language changes retranslate already acquired source text.

The prompt must clearly delimit source text as data rather than instructions and request preservation of line breaks, punctuation, proper nouns, code identifiers, and terminal arguments when practical.

## 9. 翻译 API 与设置 / Translation API and Settings

### 中文

0.1.0 支持多个命名的泛用大模型协议流式配置，不绑定默认厂商。当前协议包括 OpenAI-compatible Chat Completions、OpenAI Responses、Anthropic Messages 和 Google Gemini Generate Content。每个配置包括：

- 显式接口协议；
- URL 模式：Base URL 或完整 URL；
- 对应地址，例如 OpenAI Base URL `https://example.com/v1`、Anthropic Base URL `https://api.anthropic.com`，或完整请求 URL；
- 模型名，可手工填写或从当前配置获取可用模型；
- 可选 API Key；
- 是否启用；
- 连接测试；
- 三个快捷键开关与录制器；
- 快捷键恢复默认值。

设置侧栏另有“翻译语言”页面；母语和第二语言属于全局非敏感偏好，不归属于单个 API profile。

Base URL 模式按显式协议推导请求地址：OpenAI-compatible 追加 `/chat/completions`，OpenAI Responses 追加 `/responses`，Anthropic 追加 `/v1/messages`，Gemini 追加 `/v1beta/models/{model}:streamGenerateContent?alt=sse`；已有 `/v1` 或 `/v1beta` 版本段不会重复追加。完整 URL 模式严格使用填写地址，不追加或删除路径。两种模式都要求 HTTP(S) host，且拒绝 query 和 fragment（Gemini 的 Base URL 生成的 `alt=sse` 除外）。连接测试使用“保存并测试”语义：先持久化当前 profile 的非敏感字段和非空 Key 草稿，再从同一份已保存 profile 与进程内凭据缓存构造测试 endpoint；真实翻译使用相同解析结果。获取模型时，编辑器中的非空 Key 草稿优先于已保存值，草稿为空时才回退。OpenAI-compatible、OpenAI Responses 和 Anthropic 从对应 `/models` 地址读取 `data[].id`；Gemini 从 `/v1beta/models` 读取 `models[].name` 并移除 `models/` 前缀。完整 URL 只有在能安全移除当前协议请求后缀时才推导模型列表，否则显示错误；不兼容的响应形状返回明确错误，不伪造空模型列表。模型列表网络请求由 Rust 核心执行，不创建新的凭据副本。OpenAI 协议使用 `Authorization: Bearer <key>`，Anthropic 使用 `x-api-key` 与 `anthropic-version: 2023-06-01`，Gemini 使用 `x-goog-api-key`；空 Key 允许兼容不要求认证的本地或代理端点。全部配置的 Key 只保存在一个版本化 macOS Keychain vault item 中，每个 profile UUID 在 vault 内对应独立逻辑条目；URL、协议、模式、模型名、启用状态、顺序和其它非敏感偏好保存在应用偏好。应用完成启动后、首次翻译前只授权并读取这个 vault；当前进程内的 profile 读取使用内存缓存，翻译或切换配置不得再访问逐 profile Keychain item。旧版独立 item 只在启动迁移阶段读取，迁移使用同一个认证上下文，完整 vault 写入成功后才删除。

只有启用的配置才出现在结果卡片配置选择器中并可发起请求。默认配置必须属于启用集合：禁用当前默认时选择顺序中的下一个启用配置，没有任何启用配置时默认值为空；在默认值为空时启用配置会使其成为默认；对禁用配置执行“设为默认”会同时启用它。完整性状态与启用状态相互独立。0.1.0 不支持自动 fallback、自定义 Header、厂商专属请求参数、账号系统或 Marla 代理服务。

首次启动以紧凑清单引导配置 API、辅助功能权限和屏幕录制权限。快速输入本身不应因缺少辅助功能或屏幕录制权限而不可使用。菜单在任一准备项未完成时显示可操作状态；三项全部完成后自动隐藏该状态条，并在原区域展示最多三条仅本次运行保留的最近完成翻译。点击最近翻译只重新打开完成态结果，不重复网络请求。

### English

0.1.0 supports multiple named streaming profiles for general-purpose model protocols and binds to no default vendor. Current protocols are OpenAI-compatible Chat Completions, OpenAI Responses, Anthropic Messages, and Google Gemini Generate Content. Each profile includes:

- an explicit interface protocol;
- URL mode: Base URL or Complete URL;
- its corresponding address, such as the OpenAI Base URL `https://example.com/v1`, the Anthropic Base URL `https://api.anthropic.com`, or a complete request URL;
- model name, entered manually or selected from models fetched for the current profile;
- optional API Key;
- enabled state;
- connection test;
- three shortcut switches and recorders;
- restore-default-shortcuts action.

The Settings sidebar also includes Translation Languages. Native and secondary language are global non-sensitive preferences, not fields of an API profile.

Base URL mode derives the request URL from the explicit protocol: OpenAI-compatible appends `/chat/completions`, OpenAI Responses appends `/responses`, Anthropic appends `/v1/messages`, and Gemini appends `/v1beta/models/{model}:streamGenerateContent?alt=sse`; an existing `/v1` or `/v1beta` version segment is not duplicated. Complete URL mode uses the entered address exactly without adding or removing path components. Both modes require an HTTP(S) host and reject query or fragment components (the `alt=sse` query is generated for Gemini Base URL mode). Connection Test uses “Save and Test”: it first persists the current profile's non-sensitive fields and non-empty key draft, then constructs the test endpoint from that same saved profile and the in-process credential cache; real translation uses the same resolution result. For model discovery, a non-empty editor key draft takes precedence over the saved value, with an empty draft falling back. OpenAI-compatible, OpenAI Responses, and Anthropic read `data[].id` from their derived `/models` endpoint; Gemini reads `models[].name` from `/v1beta/models` and removes the `models/` prefix. Complete URL mode derives a model-list URL only when the current protocol request suffix can be removed safely; otherwise it reports an error. An incompatible response shape is an explicit error rather than a fabricated empty list. Rust performs the model-list request without creating a second credential copy. OpenAI protocols use `Authorization: Bearer <key>`, Anthropic uses `x-api-key` plus `anthropic-version: 2023-06-01`, and Gemini uses `x-goog-api-key`; an empty key supports local or proxy endpoints that require no authentication. All profile keys live in one versioned macOS Keychain vault item, with each profile UUID represented by an independent logical entry inside the vault. URL, protocol, mode, model, enabled state, order, and other non-sensitive preferences use application preferences. After the application finishes launching and before first translation, Marla authorizes and reads only this vault. Profile reads use an in-memory cache for the current process, and translation or profile switching may not access legacy per-profile Keychain items. Legacy independent items are read only during startup migration, reuse one authentication context, and are deleted only after the complete vault is written successfully.

Only enabled profiles appear in the result-card profile picker and may start requests. The default must belong to the enabled set: disabling the current default chooses the next enabled profile in order, no enabled profiles means no default, enabling a profile while no default exists makes it the default, and setting a disabled profile as default also enables it. Completeness and enabled state remain independent. Automatic fallback, custom headers, vendor-specific request options, accounts, and a Marla proxy service are not supported in 0.1.0.

First launch uses a compact checklist for API configuration, Accessibility permission, and Screen Recording permission. Quick input must remain usable when Accessibility or Screen Recording permission is absent. The menu shows actionable status while any setup item is incomplete. Once all three are ready, that status row hides automatically and its region shows up to three recent completed translations retained for the current run only. Selecting a recent translation reopens the completed result without repeating a network request.

## 10. 错误与恢复 / Errors and Recovery

### 中文

以下情况必须有独立、可操作的状态，而不是笼统显示“失败”：

- 没有选中文字：提示如何选择或使用快速输入；
- 受保护 Copy 无新内容、焦点变化、超时或无法安全恢复：不发请求，说明具体状态并提供快速输入；
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
- protected Copy produced no new content, lost source focus, timed out, or could not restore safely: send no request, explain the specific state, and offer Quick Input;
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
- 只有用户明确触发并在本机归一化后的源内容发送到配置的翻译端点；
- 划词触发会短暂读写通用 Pasteboard，但只接受本次受保护 Copy 的新内容，并在安全时完整恢复原快照；
- 不发送窗口标题、附近文字、应用分类或完整屏幕；
- 不把翻译历史、截图、原文或译文写入磁盘；菜单最多保留三条内存最近翻译并在退出时清空；
- API Key 不写入日志、UserDefaults、错误消息或诊断文件；
- 退出应用后，除 Keychain 凭证和非敏感设置外不保留会话内容。

界面必须明确区分“Vision 本地识别”与“识别出的文字会发送到翻译 API”，不得使用含糊的“完全离线”表述。

### English

- screenshots exist in memory only and are released after Vision completes or the session is cancelled;
- only locally normalized source content from an explicit user action is sent to the configured translation endpoint;
- a selection trigger temporarily reads and writes the general Pasteboard, accepts only the new protected-Copy result, and fully restores the original snapshot when safe;
- window titles, nearby text, application classification, and full-screen imagery are not sent;
- translation history, screenshots, source, and translation are never written to disk; the menu keeps at most three in-memory recent translations and clears them on termination;
- API Keys never enter logs, UserDefaults, error messages, or diagnostic files;
- after app termination, no session content remains except Keychain credentials and non-sensitive settings.

The UI must distinguish “local recognition with Vision” from “recognized text is sent to the translation API” and must not claim the complete workflow is offline.

## 12. 0.1.0 范围外 / Out of Scope for 0.1.0

### 中文

- 任何覆盖原文位置或以鼠标估算位置显示的轻量原位译文界面；
- 云端 GLM-OCR，以及从截图或文档恢复 Markdown、表格或版面结构；
- 语境增强、附近文字、窗口缓存、术语记忆和提示词缓存；
- 持久历史、收藏、账号、同步和统计；
- PDF、Office、多页文档、批处理和主文档工作区；
- 浏览器 DOM 改写、可编辑原文替换和持续跟随滚动；
- 跨事件持久化的增量 Markdown AST，以及 HTML/RTF 多 representation 复制；
- 本地大语言模型、本地 OCR VLM 和自带 TTS 模型；
- Intel Mac、公开 DMG、Developer ID、公证、自动更新和 App Store 发布；
- 应用界面国际化；0.1.0 UI 使用简体中文。

### English

- any lightweight translation surface that covers source text or estimates an in-place position from the pointer;
- cloud GLM-OCR, plus Markdown, table, or layout reconstruction from screenshots or documents;
- context enhancement, nearby text, window caches, terminology memory, or prompt caching;
- persistent history, favorites, accounts, sync, or analytics;
- PDF, Office, multipage documents, batch work, or a main document workspace;
- browser DOM rewriting, editable source replacement, or continuous scroll tracking;
- a persistent incremental Markdown AST across streaming events, and multi-representation HTML/RTF copy;
- local LLMs, local OCR VLMs, or bundled TTS models;
- Intel Mac, public DMG, Developer ID, notarization, auto-update, or App Store release;
- application UI localization; the 0.1.0 UI is Simplified Chinese.

## 13. 测试产物 / Test Artifact

### TASK-026 凭据一致性补充 / Credential Consistency Addendum

中文：连接测试使用“保存并测试”语义，先保存当前 profile 与非空 Key 草稿，再使用已保存 endpoint；真实请求在 profile 没有已保存凭据时显示不含 Key 的保存引导。

English: Connection Test uses “Save and Test”, persisting the current profile and non-empty key draft before testing the saved endpoint; a missing saved credential produces a key-free save instruction in the result card.

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
