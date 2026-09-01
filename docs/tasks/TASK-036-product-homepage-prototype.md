# TASK-036：构建符合 Marla 产品定位的官网首页原型

Status: Active

Owner: Project owner + Agent

Created: 2026-08-26

Updated: 2026-09-02

Origin: direct request

Conversation: 2026-08-26 Marla 精美产品首页

## Initial request

项目所有者希望使用 `gpt-taste` 或其他适合的设计 Skill，为 Marla 制作一版精美、符合产品定位、可以直接查看的首页原型。

## Outcome

仓库获得一个可独立运行的响应式官网首页原型。页面以 Paper Lantern 品牌和真实桌面录屏解释 Marla 的原地翻译体验；Hero/Markdown 共用一份原地翻译素材，其余入口和快捷键各自独立。三个 1:1 移动端入口素材仍由项目所有者后续补充，期间页面诚实地完整显示桌面版本，不用旧截图或网页伪动画冒充实机证据。页面提供经过桌面、移动端、键盘与 Reduce Motion 检查的实现证据，供项目所有者继续视觉迭代或决定是否正式部署。

## Why now

Marla 已有稳定的产品定义、Paper Lantern 品牌和可展示的真实 App UI，但尚无网页工程。先制作独立原型，可以在不影响原生 App 和发布状态的前提下验证官网的视觉方向与产品叙事。

## In Scope

- 在 `website/` 下新增独立的 React + Vite 官网首页原型。
- 使用 `gpt-taste` 规定的 AIDA 结构、真实 GSAP ScrollTrigger 动效和确定性视觉选择，并以 Marla 品牌边界覆盖不适用的泛用规则。
- 使用 Paper Lantern 正式标志和有明确比例、内容类型与替换边界的真实 App 视频；移动端成品缺失时完整显示桌面素材，不使用无关图库或网页模拟冒充产品。
- 为 Hero、划词、截图、Quick Input、结构化 Markdown 和快捷键展示预留明确媒体位，并记录后续素材采集、静态封面、移动端裁切与 Reduce Motion fallback 规格。
- 在不改变页面叙事和品牌边界的前提下升级 Hero、三入口、Bento 与滚动叙事的 GSAP 动效；动效只解释“明确触发、靠近原文、关闭后继续阅读”三项产品行为。
- 首页准确呈现划词翻译、截图翻译、Quick Input、结构化 Markdown、Provider 自选和隐私边界。
- 提供桌面与移动端响应式布局、键盘可访问性、清晰焦点状态和 `prefers-reduced-motion` 降级。
- 补充运行说明、自动化检查和浏览器截图证据，并同步 Task 与 `STATUS.md`。

## Out of Scope

- 修改 Swift、Rust、Xcode 工程或原生 App 行为。
- 部署域名、托管、分析、Cookie、账号、支付、定价或邮件收集。
- 创建公开下载链接、发布版本或暗示 Marla 已经公开发布。
- 声称完全离线、零数据上传、已拥有用户数量、媒体评价或未经证实的合作关系。
- 修改 Paper Lantern 主标志或 AppIcon。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-26 | Project owner | 使用 `gpt-taste` 或合适 Skill 直接制作一版首页供查看 | 需要交付可运行实现、真实浏览器截图和视觉评审 | Verified |
| 2026-08-26 | Project owner | 确认首页需要试机演示素材 | 本轮需提供真实截图降级和可替换媒体结构；真实录屏需另行确认测试内容与持久化边界 | Verified |
| 2026-08-30 | Project owner | 确认当前视觉方向正确，要求继续升级网页、增加更好的动画，真实素材以后再补且当前留空 | 旧实机截图需全部退出页面；所有展示位改成高质感、固定比例且可直接替换的空媒体舞台；重新验证 GSAP、响应式、键盘与 Reduce Motion | Verified |
| 2026-08-30 | Project owner | 先把当前 Task 保存为分支提交，后续继续制作，不合并到 `main` | 当前成果形成可恢复的分支检查点；TASK-036 保持 Active，不执行 merge 或 push | Verified |
| 2026-09-01 | Project owner | 重新激活 TASK-036，并明确全部待录制素材 | 在专用分支同步最新原生 App 基线；素材计划收敛为 3 段视频母版和 1 张快捷键设置截图，覆盖 6 个网页展示位；仍不把 TASK-036 合并到 `main` | Superseded |
| 2026-09-01 | Project owner | 不以减少工作量为目标；每个展示位独立制作视频，快捷键设置也必须展示真实动画 | 修正上一条复用方案：交付 6 段独立桌面视频，三入口另有 3 段 1:1 移动剪辑，共 9 个 MP4 和 9 个同名 WebP poster；快捷键覆盖展开、互斥切换和收拢 | Superseded |
| 2026-09-01 | Project owner | 建立专用素材目录并提供统一命名规则 | 审核通过的网页成品放入 `website/public/media/desktop/`、`mobile/` 和 `posters/`；命名采用 `marla-{scene}--{variant}-{ratio}.{ext}`，原始录屏不进入仓库 | Active |
| 2026-09-01 | Project owner | 将素材说明做成中文 | `website/DEMO_ASSETS.md`、`website/public/media/README.md` 和网站运行说明使用中文正文；技术标识、路径与 ASCII 文件名规则保持不变 | Verified |
| 2026-09-01 | Project owner | 桌面视频已经录制，接入网页；Hero 与结构化 Markdown 视为同一份素材 | 将 5 个唯一桌面母版转为 30fps H.264 和同名 WebP，覆盖 6 个展示位；Hero/Markdown 共用同一 URL，移动端素材保持待补；验证视口播放、入口互斥、播放控制和 Reduce Motion | Verified |
| 2026-09-01 | Project owner | 实机查看后发现多个视频被界面元素遮挡，允许调整视频位置、效果和页面布局 | 播放控制移出录屏画面；三入口由覆盖式手风琴改为三段切换和单一大舞台；快捷键卡片取消绝对定位；桌面与手机均按素材原始比例完整显示，并重新验证遮挡、溢出、键盘和 Reduce Motion | Verified |
| 2026-09-02 | Project owner | 所有视频展示位改为自动循环，并修复首次到达三入口区域时画面空白、看起来没有播放 | 移除视频的视口相交门槛和入口视频框的透明度入场；所有已挂载视频静音自动循环且进入画面时立即可见，入口切换后新挂载视频立即播放；保留手动暂停和 Reduce Motion 默认封面 | Verified |

## Current evidence

- `STATUS.md` 在本 Task 前没有 Active Task，工作树位于干净的 `main`。
- 仓库没有 `package.json` 或现成网页工程。
- `PRODUCT.md`、`UX_PRINCIPLES.md`、`BRAND.md` 与 ADR-0008 已定义真实产品能力、Paper Lantern 正式标志和严格品牌边界。
- `artifacts/ui-review/` 仍保留原生 App 的历史视觉证据，但本首页不再直接加载这些截图。
- `website/` 已有 React + Vite 页面、Geist 字体、Lucide 图标、GSAP ScrollTrigger、固定比例媒体舞台和真实桌面录屏；没有修改原生 App 源码。2026-08-30 的追加范围先把旧截图替换成空舞台并升级动效，随后以真实视频和封面替换占位内容；本轮根据实机查看结果重做三入口与快捷键媒体布局，同时保留 Hero、Bento/故事的产品叙事和滚动关系。
- 2026-09-01 第一批成品为 5 个唯一桌面 MP4 和 5 个同名 WebP：Hero 与结构化 Markdown 按项目所有者决定复用同一份 5:4 素材；划词、截图、Quick Input 和快捷键各自独立。三个入口的 1:1 移动端剪辑和封面仍待补充，最终唯一文件总数调整为 8 个 MP4 和 8 个 WebP。
- 早期空舞台阶段浏览器实测 375/768/1024/1440px 均为两行 Hero；当前媒体布局重新实测 1440×1000 与 390×844，两个视口均为零横向溢出，桌面 Bento 继续以 12+6+6 填满 24 个栅格单元。
- Reduce Motion 实测匹配成功，pin spacer 为 0，Hero/层叠卡片全部直接可见，跑马灯动画降为 0.01ms；控制台无 warning/error。

## Proposed approach

在 `website/` 维护与原生 App 隔离的 Vite React 工程。视觉使用明亮纸张底色、品牌靛青结构、陶土红重点和暖金小范围照明，以固定比例真实录屏作为第一视口信号；用 GSAP 负责首屏入场、能力卡片堆叠和桌面滚动固定，CSS 与媒体播放状态共同负责响应式、静音自动循环、交互控制和 Reduce Motion 降级。

## Acceptance criteria

- [x] 首页第一视口明确出现 Marla 名称、Paper Lantern 标志、原地翻译定位和可替换的 5:4 Hero 媒体舞台；当前不出现旧截图或伪装成实机的网页模拟。
- [x] 页面完整覆盖 Navigation、Attention、Interest、Desire、Action，并且没有虚构发布、价格、用户量或隐私承诺。
- [x] 桌面 Bento 为 12 列 24 单元无空洞，移动端无横向溢出、文字遮挡或不可操作控件。
- [x] GSAP ScrollTrigger 动效真实运行且解释明确触发、结果靠近、阅读上下文保留；桌面动效使用 transform/autoAlpha，移动端取消固定和重叠，Reduce Motion 下内容直接处于可读终态且无滚动固定。
- [x] Hero、三条产品入口、Markdown 与快捷键展示均使用固定比例真实 App 视频；Hero/Markdown 共用一份 5:4 素材，三入口和快捷键使用 7:5 桌面素材；1:1 移动端成品加入前使用完整显示桌面视频的诚实降级，不以网页伪动画冒充 App 运行。
- [x] 所有链接和按钮可通过键盘访问，焦点清晰，主要文字和按钮达到 WCAG AA 对比要求。
- [x] `npm run build`、静态检查、浏览器控制台检查和 `git diff --check` 通过。
- [x] 至少完成 1440px 桌面和 390px 移动端真实浏览器截图检查。
- [x] 运行说明、Task 和 `STATUS.md` 已同步到待项目所有者视觉确认的状态。
- [x] 素材分镜、导出规格、隐私检查、目录和命名说明均提供中文正文，技术标识与文件路径保持可直接使用。
- [x] 所有已挂载视频展示位均静音自动循环且不依赖视口相交；首次到达三入口区域时视频框不经过透明隐藏，切换入口时当前视频立即可见并播放；每个展示位提供键盘可操作的播放/暂停按钮，手动暂停保持有效，Reduce Motion 默认停在 WebP 封面。

## Verification

### Automated

```sh
cd website
npm run build
npm run lint
```

```sh
git diff --check
```

2026-08-30 最终结果：`npm run lint`、`npm run build`、`git diff --check` 与仓库级 `./scripts/check.sh` 全部通过；Vite 生产构建成功打包 React/GSAP、字体和当前空媒体舞台，无旧截图媒体引用。

2026-09-01 桌面素材接入结果：`npm run lint`、`npm run build` 和 `git diff --check` 通过。5 个唯一 MP4 均为 H.264、`yuv420p`、30fps、无音轨并带 fast-start；总大小约 13 MB。5 个同名 WebP 尺寸与视频一致。

2026-09-01 视频布局修正结果：`npm run lint`、`npm run build` 和 `git diff --check` 通过。播放控制位于画面外工具条；桌面入口视频视口实测为 7:5，Hero/Markdown 为 5:4；快捷键文案底部与视频工具条顶部之间保持正间距。

2026-09-02 自动循环与首次显示修正结果：`npm run lint`、`npm run build` 和 `git diff --check` 通过。入口视频不再由 ScrollTrigger 或切换动画写入透明隐藏；所有挂载视频使用静音 `autoplay`、`loop` 与提前加载，并由播放状态逻辑保留手动暂停和 Reduce Motion 降级。

### Manual

- 在真实浏览器分别以 1440px 桌面和 390px 移动端视口检查第一视口、整页布局、导航、CTA、滚动动效、控制台和横向溢出。
- 以 Reduce Motion 检查所有内容保持可见、没有滚动固定或依赖动效才能理解的信息。
- 截图证据存放在 `artifacts/ui-review/task-036/`。
- 后续只需补充划词翻译、截图翻译和 Quick Input 的 1:1 移动端 MP4 与 WebP，并在接入后复跑移动端媒体源选择与加载检查。

2026-08-30 浏览器证据：

- `homepage-desktop-top.png`：1440×1000 第一视口，Paper Lantern、两行 Hero、双 CTA 与 5:4 空媒体舞台完整可见。
- `homepage-desktop-entry-demo.png`：三入口横向手风琴及固定 7:5 空媒体舞台。
- `homepage-desktop-story.png`：GSAP 左侧固定标题与右侧层叠卡片，无交叉遮挡。
- `homepage-mobile-top.png`：390×844 两行 Hero、完整 CTA、5:4 空媒体舞台且无横向溢出。
- `homepage-mobile-experience.png`：移动端三入口纵向结构；入口舞台实际为 1:1，且无文字越界。
- `homepage-desktop-reduce-motion.png`：Reduce Motion 内容终态截图；动态检查确认无 pin spacer。

2026-08-30 空舞台阶段动效验证：`npm run lint`、`npm run build`、`git diff --check` 通过；Hero signal、媒体关系线、Bento/故事 hover 样式均已进入构建产物，深色快捷键舞台的关系线使用浅色对比度。当时真实录屏尚未加入，所有媒体位置保持可替换空舞台。

2026-08-30 空舞台阶段 Web 五维复审：产品定位 9/10、视觉层级 9/10、响应式 9/10、交互与无障碍 8/10、动效与性能 8/10。所有维度均达到 7/10 以上；当时真实录屏尚未采集，因此媒体说服力保留为后续项目所有者决策。

2026-09-01 素材接入浏览器证据：1440×1000 下 Hero、三入口、Markdown 和快捷键视频均真实解码；Hero/Markdown 的 `currentSrc` 完全一致。入口切换只播放当前展开项，旧项暂停；播放/暂停按钮可点击并具有键盘焦点；控制台无 warning/error。Reduce Motion 新页面默认 `currentTime = 0`、`paused = true` 并使用 WebP poster。390×844 下 `scrollWidth = innerWidth = 390`，桌面视频在 1:1 入口中以完整显示降级，无横向溢出。

2026-09-01 视频布局修正浏览器证据：1440×1000 下三入口为三段式 Tab 和单一 963px 宽 7:5 舞台，说明位于独立右栏；快捷键文案与视频相互分离。390×844 下入口保持原始 7:5、Hero 保持 5:4，不再强制 1:1；`document.scrollWidth = innerWidth = 390`，隐私卡片正文与数据流标签分离。Tab 可用左右/Home/End 键切换，控制台无 warning/error。Reduce Motion 下 4 个当前 DOM 视频均为 `currentTime = 0`、`paused = true`，pin spacer 为 0，所有 Hero/Bento/故事内容可见；检查后浏览器已恢复普通动态模式。

2026-09-02 自动循环浏览器证据：新页面初始挂载的 Hero、当前入口、Markdown 与快捷键 4 个视频均为 `autoplay = true`、`loop = true`、`muted = true`、`paused = false`，包括尚未进入视口的展示位。按项目所有者截图对应的 1274×990 视口首次滚入入口区域后等待超过原 420ms 动画时长，视频框仍为 `opacity = 1`、`visibility = visible` 且时间持续前进；切换截图入口后同样立即可见并播放。Quick Input 实测跨过 9.27 秒片尾后从 5.39 秒回到 1.16 秒并继续播放；手动暂停期间时间保持 1.28 秒，恢复后继续前进。Reduce Motion 下 4 个视频均为 `currentTime = 0`、`paused = true`，显式播放仍可覆盖；恢复普通动态后 4 个视频全部继续播放，控制台无 warning/error。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/product/BRAND.md`
- `docs/development/VERSIONING.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/decisions/ADR-0008-paper-lantern-brand-identity.md`
- `artifacts/ui-review/task-028/markdown-final-light-760.png`
- `artifacts/ui-review/task-018/screenshot-frozen-light.png`
- `artifacts/ui-review/task-035/shortcuts-editor-light.png`

## Parallel contributors (optional)

None.

## Risks and rollback

- 新网页依赖与原生 App 分离，删除 `website/` 即可完整回滚，不影响 Swift/Rust 构建。
- 官网视觉可能过度装饰或写出超出实现的承诺；通过品牌文档、产品能力表和最终文案审计控制。
- 大尺寸真实截图可能增加网页体积；构建时转换为适配 Web 的尺寸与格式，并保留可读画面。

## Decisions needed

正式部署、下载入口、开源仓库地址和后续品牌文案需在项目所有者查看原型后另行决定。当前桌面录屏已经接入；三个 1:1 移动端入口视频与封面仍待项目所有者补充。页面不把旧截图设为 fallback。

## Checkpoint record

- Branch checkpoint: committed on `Anti2077/task-036-homepage-prototype`; exact identifier由 Git history 记录。TASK-036 于 2026-09-01 重新激活，等待素材采集和后续视觉迭代。
- Automated evidence: `npm run lint`, `npm run build`, `git diff --check`, and `./scripts/check.sh` pass.
- Manual evidence: 1440/390px screenshots plus 375/768/1024/1440 breakpoint, GSAP pin/stack, keyboard focus, console, and Reduce Motion checks under `artifacts/ui-review/task-036/`.
- Documentation updated: `website/README.md`, `website/DEMO_ASSETS.md`, this Task, and `STATUS.md`.
- Remaining work promoted to: None. 三个 1:1 移动端视频、对应封面和正式部署仍是当前 Task 的后续项目所有者输入，不提升为 Backlog。
- Scope changes closed: 2026-08-30 动效与空媒体舞台范围已通过验证；2026-09-01 的 5 个唯一桌面视频已完成网页编码、接入、交互和浏览器验证，Hero/Markdown 按项目所有者决定共用同一素材；后续遮挡修正已将控制与说明全部移出视频画面，并通过桌面、手机和 Reduce Motion 复核。
- Integration state: 本检查点只保存在专用分支；未合并到 `main`，也未推送远端。
- Parallel contributions integrated: None.
