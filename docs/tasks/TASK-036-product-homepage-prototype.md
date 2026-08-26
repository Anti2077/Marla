# TASK-036：构建符合 Marla 产品定位的官网首页原型

Status: Active

Owner: Project owner + Agent

Created: 2026-08-26

Updated: 2026-08-26

Origin: direct request

Conversation: 2026-08-26 Marla 精美产品首页

## Initial request

项目所有者希望使用 `gpt-taste` 或其他适合的设计 Skill，为 Marla 制作一版精美、符合产品定位、可以直接查看的首页原型。

## Outcome

仓库获得一个可独立运行的响应式官网首页原型。页面以 Paper Lantern 品牌和真实 App 画面解释 Marla 的原地翻译体验，并提供经过桌面、移动端、键盘与 Reduce Motion 检查的实现证据，供项目所有者决定是否继续迭代或正式部署。

## Why now

Marla 已有稳定的产品定义、Paper Lantern 品牌和可展示的真实 App UI，但尚无网页工程。先制作独立原型，可以在不影响原生 App 和发布状态的前提下验证官网的视觉方向与产品叙事。

## In Scope

- 在 `website/` 下新增独立的 React + Vite 官网首页原型。
- 使用 `gpt-taste` 规定的 AIDA 结构、真实 GSAP ScrollTrigger 动效和确定性视觉选择，并以 Marla 品牌边界覆盖不适用的泛用规则。
- 使用 Paper Lantern 正式标志和仓库内真实 App 截图，不使用无关图库冒充产品。
- 为划词、截图和 Quick Input 三条真实试机录屏预留明确的媒体位、静态封面与 Reduce Motion fallback，并记录后续素材采集规格。
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

## Current evidence

- `STATUS.md` 在本 Task 前没有 Active Task，工作树位于干净的 `main`。
- 仓库没有 `package.json` 或现成网页工程。
- `PRODUCT.md`、`UX_PRINCIPLES.md`、`BRAND.md` 与 ADR-0008 已定义真实产品能力、Paper Lantern 正式标志和严格品牌边界。
- `artifacts/ui-review/` 已有可用于官网叙事的真实 App 截图。
- `website/` 现已实现 React + Vite 页面、Geist 字体、Lucide 图标、GSAP ScrollTrigger、三入口媒体组件和试机录屏规格；没有修改原生 App 源码。
- 浏览器实测 375/768/1024/1440px 均为两行 Hero、零横向溢出和零首屏文字越界；桌面 Bento 12+6+6 正好填满 24 个栅格单元。
- Reduce Motion 实测匹配成功，pin spacer 为 0，Hero/层叠卡片全部直接可见，跑马灯动画降为 0.01ms；控制台无 warning/error。

## Proposed approach

在 `website/` 建立与原生 App 隔离的 Vite React 工程。视觉使用明亮纸张底色、品牌靛青结构、陶土红重点和暖金小范围照明，以真实产品截图作为第一视口信号；用 GSAP 负责首屏入场、能力卡片堆叠和桌面滚动固定，CSS 负责响应式、交互状态与 Reduce Motion 降级。

## Acceptance criteria

- [x] 首页第一视口明确出现 Marla 名称、Paper Lantern 标志、原地翻译定位和真实产品画面。
- [x] 页面完整覆盖 Navigation、Attention、Interest、Desire、Action，并且没有虚构发布、价格、用户量或隐私承诺。
- [x] 桌面 Bento 为 12 列 24 单元无空洞，移动端无横向溢出、文字遮挡或不可操作控件。
- [x] GSAP ScrollTrigger 动效真实运行；Reduce Motion 下内容直接处于可读终态且无滚动固定。
- [x] 三条产品入口均有真实 App 静态画面，并形成可直接替换为真实录屏的媒体规格，不以网页伪动画冒充 App 运行。
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

2026-08-26 最终结果：`npm run lint`、`npm run build`、`git diff --check` 与仓库级 `./scripts/check.sh` 全部通过；Vite 生产构建成功打包 React/GSAP、字体和五张真实产品图，npm audit 报告 0 vulnerabilities。

### Manual

- 在真实浏览器分别以 1440px 桌面和 390px 移动端视口检查第一视口、整页布局、导航、CTA、滚动动效、控制台和横向溢出。
- 以 Reduce Motion 检查所有内容保持可见、没有滚动固定或依赖动效才能理解的信息。
- 截图证据存放在 `artifacts/ui-review/task-036/`。
- 后续录屏建议使用无隐私测试页、固定窗口与确定性样本，分别采集划词翻译、截图翻译和 Quick Input / Markdown，每段 8–15 秒，并输出 WebM/MP4 与静态 poster。

2026-08-26 浏览器证据：

- `homepage-desktop-top.png`：1440×1000 第一视口，Paper Lantern、两行 Hero、双 CTA 与真实 App 画面完整可见。
- `homepage-desktop-entry-demo.png`：三入口横向手风琴及真实截图翻译媒体。
- `homepage-desktop-story.png`：GSAP 左侧固定标题与右侧层叠卡片，无交叉遮挡。
- `homepage-mobile-top.png`：390×844 两行 Hero、完整 CTA、真实产品画面提示且无横向溢出。
- `homepage-mobile-experience.png`：移动端三入口纵向结构，无文字越界。
- `homepage-desktop-reduce-motion.png`：Reduce Motion 内容终态截图；动态检查确认无 pin spacer。

Web 五维复审：产品定位 9/10、视觉层级 9/10、响应式 9/10、交互与无障碍 8/10、动效与性能 8/10。所有维度均达到 7/10 以上；真实录屏尚未采集，因此媒体说服力保留为后续项目所有者决策。

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

正式部署、下载入口、开源仓库地址和后续品牌文案需在项目所有者查看原型后另行决定。真实试机录屏还需项目所有者确认测试内容与仓库持久化边界；本原型先使用现有脱敏截图作为真实 fallback。

## Completion record

- Verified commit: None; changes remain uncommitted for project-owner visual review.
- Automated evidence: `npm run lint`, `npm run build`, `git diff --check`, and `./scripts/check.sh` pass.
- Manual evidence: 1440/390px screenshots plus 375/768/1024/1440 breakpoint, GSAP pin/stack, keyboard focus, console, and Reduce Motion checks under `artifacts/ui-review/task-036/`.
- Documentation updated: `website/README.md`, `website/DEMO_ASSETS.md`, this Task, and `STATUS.md`.
- Remaining work promoted to: None. Real recording and public deployment remain explicit owner decisions, not Backlog commitments.
- Scope changes closed: Implementation and verification complete; project-owner visual acceptance pending.
- Parallel contributions integrated: None.
