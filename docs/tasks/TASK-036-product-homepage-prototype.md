# TASK-036：构建符合 Marla 产品定位的官网首页原型

Status: Active

Owner: Project owner + Agent

Created: 2026-08-26

Updated: 2026-09-01

Origin: direct request

Conversation: 2026-08-26 Marla 精美产品首页

## Initial request

项目所有者希望使用 `gpt-taste` 或其他适合的设计 Skill，为 Marla 制作一版精美、符合产品定位、可以直接查看的首页原型。

## Outcome

仓库获得一个可独立运行的响应式官网首页原型。页面以 Paper Lantern 品牌和明确的演示素材舞台解释 Marla 的原地翻译体验；真实录屏与截图由项目所有者后续补充，当前页面不得用旧截图或网页伪动画冒充实机证据。页面需要提供经过桌面、移动端、键盘与 Reduce Motion 检查的实现证据，供项目所有者继续视觉迭代或决定是否正式部署。

## Why now

Marla 已有稳定的产品定义、Paper Lantern 品牌和可展示的真实 App UI，但尚无网页工程。先制作独立原型，可以在不影响原生 App 和发布状态的前提下验证官网的视觉方向与产品叙事。

## In Scope

- 在 `website/` 下新增独立的 React + Vite 官网首页原型。
- 使用 `gpt-taste` 规定的 AIDA 结构、真实 GSAP ScrollTrigger 动效和确定性视觉选择，并以 Marla 品牌边界覆盖不适用的泛用规则。
- 使用 Paper Lantern 正式标志；当前以有明确比例、内容类型和替换边界的空媒体舞台代替旧 App 截图，不使用无关图库或网页模拟冒充产品。
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
| 2026-09-01 | Project owner | 重新激活 TASK-036，并明确全部待录制素材 | 在专用分支同步最新原生 App 基线；素材计划收敛为 3 段视频母版和 1 张快捷键设置截图，覆盖 6 个网页展示位；仍不把 TASK-036 合并到 `main` | Active |

## Current evidence

- `STATUS.md` 在本 Task 前没有 Active Task，工作树位于干净的 `main`。
- 仓库没有 `package.json` 或现成网页工程。
- `PRODUCT.md`、`UX_PRINCIPLES.md`、`BRAND.md` 与 ADR-0008 已定义真实产品能力、Paper Lantern 正式标志和严格品牌边界。
- `artifacts/ui-review/` 仍保留原生 App 的历史视觉证据，但本首页不再直接加载这些截图。
- `website/` 已有 React + Vite 页面、Geist 字体、Lucide 图标、GSAP ScrollTrigger、固定比例空媒体舞台和试机录屏规格；没有修改原生 App 源码。2026-08-30 的追加范围已把旧截图媒体替换成空舞台并升级动效，新增 Hero 的“选区→关系线→附近结果”低频信号、入口切换反馈、媒体流动线、Bento/故事 hover 和滚动 reveal。
- 2026-09-01 重新激活后，采集工作明确为 4 份源素材：划词、截图、Quick Input + Markdown 三段 16:10 视频母版，以及一张快捷键设置截图；它们通过复用和裁切覆盖 Hero、三入口、Markdown 与快捷键共 6 个展示位。
- 浏览器实测 375/768/1024/1440px 均为两行 Hero、零横向溢出和零首屏文字越界；桌面 Bento 12+6+6 正好填满 24 个栅格单元。
- Reduce Motion 实测匹配成功，pin spacer 为 0，Hero/层叠卡片全部直接可见，跑马灯动画降为 0.01ms；控制台无 warning/error。

## Proposed approach

在 `website/` 建立与原生 App 隔离的 Vite React 工程。视觉使用明亮纸张底色、品牌靛青结构、陶土红重点和暖金小范围照明，以固定比例的空媒体舞台作为第一视口信号；用 GSAP 负责首屏入场、能力卡片堆叠和桌面滚动固定，CSS 负责响应式、交互状态与 Reduce Motion 降级。

## Acceptance criteria

- [x] 首页第一视口明确出现 Marla 名称、Paper Lantern 标志、原地翻译定位和可替换的 5:4 Hero 媒体舞台；当前不出现旧截图或伪装成实机的网页模拟。
- [x] 页面完整覆盖 Navigation、Attention、Interest、Desire、Action，并且没有虚构发布、价格、用户量或隐私承诺。
- [x] 桌面 Bento 为 12 列 24 单元无空洞，移动端无横向溢出、文字遮挡或不可操作控件。
- [x] GSAP ScrollTrigger 动效真实运行且解释明确触发、结果靠近、阅读上下文保留；桌面动效使用 transform/autoAlpha，移动端取消固定和重叠，Reduce Motion 下内容直接处于可读终态且无滚动固定。
- [x] Hero、三条产品入口、Markdown 与快捷键展示均为固定比例、可直接替换的空媒体舞台；三入口使用 7:5 桌面比例并保留 1:1 移动端安全构图，不以网页伪动画冒充 App 运行。
- [x] 所有链接和按钮可通过键盘访问，焦点清晰，主要文字和按钮达到 WCAG AA 对比要求。
- [x] `npm run build`、静态检查、浏览器控制台检查和 `git diff --check` 通过。
- [x] 至少完成 1440px 桌面和 390px 移动端真实浏览器截图检查。
- [x] 运行说明、Task 和 `STATUS.md` 已同步到待项目所有者视觉确认的状态。

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

### Manual

- 在真实浏览器分别以 1440px 桌面和 390px 移动端视口检查第一视口、整页布局、导航、CTA、滚动动效、控制台和横向溢出。
- 以 Reduce Motion 检查所有内容保持可见、没有滚动固定或依赖动效才能理解的信息。
- 截图证据存放在 `artifacts/ui-review/task-036/`。
- 后续录屏建议使用无隐私测试页、固定窗口与确定性样本，分别采集划词翻译、截图翻译和 Quick Input / Markdown，每段 8–15 秒，并输出 WebM/MP4 与静态 poster。

2026-08-30 浏览器证据：

- `homepage-desktop-top.png`：1440×1000 第一视口，Paper Lantern、两行 Hero、双 CTA 与 5:4 空媒体舞台完整可见。
- `homepage-desktop-entry-demo.png`：三入口横向手风琴及固定 7:5 空媒体舞台。
- `homepage-desktop-story.png`：GSAP 左侧固定标题与右侧层叠卡片，无交叉遮挡。
- `homepage-mobile-top.png`：390×844 两行 Hero、完整 CTA、5:4 空媒体舞台且无横向溢出。
- `homepage-mobile-experience.png`：移动端三入口纵向结构；入口舞台实际为 1:1，且无文字越界。
- `homepage-desktop-reduce-motion.png`：Reduce Motion 内容终态截图；动态检查确认无 pin spacer。

本轮动效增量验证：`npm run lint`、`npm run build`、`git diff --check` 通过；Hero signal、媒体关系线、Bento/故事 hover 样式均已进入构建产物，深色快捷键舞台的关系线使用浅色对比度。真实录屏仍未加入，所有媒体位置继续保持可替换空舞台。

Web 五维复审：产品定位 9/10、视觉层级 9/10、响应式 9/10、交互与无障碍 8/10、动效与性能 8/10。所有维度均达到 7/10 以上；本轮替换空媒体舞台后已重新复跑浏览器布局检查，真实录屏尚未采集，因此媒体说服力保留为后续项目所有者决策。

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

正式部署、下载入口、开源仓库地址和后续品牌文案需在项目所有者查看原型后另行决定。项目所有者已决定真实试机录屏以后补充；当前原型只保留空媒体舞台，不把任何旧截图设为 fallback。

## Checkpoint record

- Branch checkpoint: committed on `Anti2077/task-036-homepage-prototype`; exact identifier由 Git history 记录。TASK-036 于 2026-09-01 重新激活，等待素材采集和后续视觉迭代。
- Automated evidence: `npm run lint`, `npm run build`, `git diff --check`, and `./scripts/check.sh` pass.
- Manual evidence: 1440/390px screenshots plus 375/768/1024/1440 breakpoint, GSAP pin/stack, keyboard focus, console, and Reduce Motion checks under `artifacts/ui-review/task-036/`.
- Documentation updated: `website/README.md`, `website/DEMO_ASSETS.md`, this Task, and `STATUS.md`.
- Remaining work promoted to: None. Real recording and public deployment remain explicit owner decisions, not Backlog commitments.
- Scope changes closed: 2026-08-30 动效与空媒体舞台追加范围已实现并通过网页、仓库级和 Reduce Motion 验证；后续增量加入产品关系信号、入口/媒体反馈和滚动 reveal，真实录屏仍是项目所有者后续决定，不阻塞当前网页交付。
- Integration state: 本检查点只保存在专用分支；未合并到 `main`，也未推送远端。
- Parallel contributions integrated: None.
