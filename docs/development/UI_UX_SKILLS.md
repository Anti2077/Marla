# Marla UI/UX Skill 使用指南

Last updated: 2026-08-14

这份指南只描述 Agent 如何使用 UI/UX 相关 skill，不改变 Marla 的产品行为、架构或验收标准。

## 优先级

UI/UX 建议按以下顺序解释和落地：

1. 当前实时代码、自动化测试和真实 App 验收证据；
2. 活跃 Task 的范围、排除项和验收条件；
3. `docs/product/UX_PRINCIPLES.md`、版本 UI 规格和相关 ADR；
4. 本指南规定的 skill 路由；
5. skill 自带的通用建议。

skill 是辅助工具，不得覆盖项目规范，也不能授权新增产品范围。没有 Active Task 时，UI skill 只能用于评估、审查或规划；要改产品行为，必须先由项目所有者确认一个 Task。

## 当前视觉基线

Marla 当前的 Paper Lantern 意象是行为约束，不是装饰主题：界面像阅读旁的一点暖光，靠近原文、保持安静、只在用户明确触发后出现，并让功能控件保持原生 macOS 语义。品牌细节见 [`docs/product/BRAND.md`](../product/BRAND.md)，交互底线见 [`docs/product/UX_PRINCIPLES.md`](../product/UX_PRINCIPLES.md)。任何 skill 提议都不能把 Marla 改成营销 landing page、全屏品牌入口或覆盖原文的装饰层。

## 已安装 skill

### 1. `swiftui-design-skill`：主视觉设计 skill

位置：`/Users/anti/.codex/skills/swiftui-design-skill/SKILL.md`

用于：

- 新 SwiftUI 页面或现有页面的视觉方向；
- 颜色、字体、间距、层级和设计 Token；
- 反模板化检查、品牌整合和签名细节；
- 五维视觉审查：哲学一致性、视觉层级、工艺质量、功能性、原创性。

Marla 的任何 SwiftUI 界面新增或重大修改都优先使用它。它不能替代 AppKit 窗口、焦点、菜单栏或辅助技术审查。

### 2. `ui-ux-pro-max`：规则和数据检索 skill

位置：`/Users/anti/.codex/skills/ui-ux-pro-max/SKILL.md`

用于：

- 针对一个具体 UX 结果查询可访问性、状态、动效、颜色或图标规则；
- 查询 SwiftUI 栈的通用实现建议；
- 对组件做第二轮一致性和反模式检查。

优先使用明确的栈或领域，不要把 Web、触控和移动端规则直接套到 macOS：

```sh
python3 /Users/anti/.codex/skills/ui-ux-pro-max/scripts/search.py \
  "focus ring settings error state" --stack swiftui -n 8

python3 /Users/anti/.codex/skills/ui-ux-pro-max/scripts/search.py \
  "keyboard focus modal" --domain ux -n 8
```

`--stack swiftui` 限制到 SwiftUI 数据，`--domain ux` 限制到 UX 规则，`-n 8` 限制返回数量。查询脚本读取 skill 自带的本地数据，不会修改项目。

只有项目所有者明确授权时，才使用 `--design-system --persist`；它会在项目中生成 `design-system/` 文件，不能静默替换 Marla 已有的视觉体系。

### 3. `axiom-macos`：原生 macOS 交互和承载 skill

位置：`/Users/anti/.codex/skills/axiom-macos/SKILL.md`

用于 macOS 专属问题：

- `MenuBarExtra`、菜单命令、`⌘,` 和快捷键；
- `Window`、`NSPanel`、非激活窗口、窗口焦点和状态恢复；
- SwiftUI/AppKit 桥接、`NSViewRepresentable`、`NSHostingController`；
- ScreenCaptureKit、截图选择和权限边界；
- macOS SwiftUI 与 iOS SwiftUI 的差异。

相关参考文件位于 skill 的 `skills/` 子目录，例如：

- `skills/menus-and-commands.md`
- `skills/windows.md`
- `skills/appkit-interop.md`
- `skills/swiftui-differences.md`
- `skills/screencapturekit.md`

它的原生 macOS 建议仍须与 Marla 的 `UI_SPEC.md`、AppKit 代码和现有回归测试对照；不得因为 skill 建议而引入 Tauri、localhost sidecar 或改变 Swift/Rust 边界。

### 4. `ios-accessibility`：SwiftUI/AppKit 无障碍和适配 skill

位置：`/Users/anti/.codex/skills/ios-accessibility/SKILL.md`

用于：

- VoiceOver、Voice Control、Switch Control 和 Full Keyboard Access；
- `accessibilityLabel`、role、value、trait、custom action 和 traversal order；
- 弹层关闭后的焦点恢复、模态语义和 Escape 路径；
- Reduce Motion、Reduce Transparency、Increase Contrast、Bold Text 和 Dynamic Type；
- SwiftUI/AppKit 无障碍自动化与人工验收矩阵。

详细代码示例按需读取：

`/Users/anti/.codex/skills/ios-accessibility/references/a11y-patterns.md`

App Store accessibility 声明只有在完成真实常见任务证据矩阵后才能填写，不能把局部控件测试当成产品声明。

## 按任务路由

| UI/UX 工作 | 首选 skill | 配套证据 |
| --- | --- | --- |
| 新设置页、结果卡、快速输入界面 | `swiftui-design-skill` | `ui-ux-pro-max --stack swiftui`、`UI_SPEC.md` |
| 菜单栏、`⌘,`、快捷键、非激活面板、窗口焦点 | `axiom-macos` | AppKit 代码、固定 App、真实窗口验收 |
| VoiceOver、键盘遍历、焦点恢复、Reduce Motion | `ios-accessibility` | Accessibility Inspector、XCTest、真实 App |
| 颜色、字体、间距、图标、错误/空状态 | `swiftui-design-skill` | `ui-ux-pro-max` 针对性查询、浅色/深色截图 |
| 动画和流式布局 | `swiftui-design-skill` + `ui-ux-pro-max` | Reduce Motion、流式竞态测试、五维审查 |
| ScreenCaptureKit 和截图选择 | `axiom-macos` | 隐私边界、权限、跨显示实机证据 |
| Rust、HTTP/SSE、Keychain、性能和内存 | 不调用 UI skill | Rust 测试、`./scripts/check.sh`、`VERIFICATION.md`、性能测量 |

## Marla UI/UX 审查流程

1. 读取 `STATUS.md`、当前 Task、Required Reading 和相关 UI/架构文档。
2. 判断请求是否真的改变 UI、交互、可访问性或视觉质量；纯 Rust/API/Keychain 工作不调用 UI skill。
3. 新视觉方向先使用 `swiftui-design-skill`，不要先生成 Web landing page 或独立设计系统。
4. macOS 承载和交互使用 `axiom-macos`；辅助技术和适配使用 `ios-accessibility`。
5. 需要具体规则时，再用 `ui-ux-pro-max` 做小范围查询；查询结果必须核对平台、优先级和项目现有行为。
6. 实现后检查浅色、深色、Reduce Motion、键盘焦点、无障碍标签、错误/加载/流式/完成/空状态。
7. 运行 `./scripts/check.sh`；需要稳定 Release 证据时运行 `./scripts/build-test-app.sh`。
8. 使用真实固定 App 截图完成五维审查，每一维至少 7/10；截图默认只保存在临时目录，不提交到仓库。
9. 将已验证事实同步到当前 Task、相关规格和 `STATUS.md`；不要把 skill 建议写成已验证事实。

## 不应直接采用的建议

以下内容通常属于 Web 或移动端语境，除非项目所有者明确要求，否则不直接用于 Marla：

- hero、landing page、营销 CTA、滚动触发叙事；
- CSS selector、Tailwind、GSAP、viewport 和移动端 breakpoint；
- 只针对触控的 44pt/48dp 规则；
- 用卡片网格、装饰性渐变或品牌色覆盖原文阅读环境；
- 让结果窗口激活并抢走源应用焦点；
- 以截图文件、源文、译文或 Keychain 内容作为持久化设计素材。
