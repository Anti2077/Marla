# TASK-046：发布前官网入口与 GitHub README

Status: Active

Owner: Project owner + Agent

Created: 2026-09-09

Updated: 2026-09-11

Origin: direct request

Conversation: 2026-09-09，准备发布 Marla，完善官网首页和 GitHub README

## Initial request

项目所有者准备发布 Marla，要求在官网首页右上角增加下载与 GitHub 图标，完善根 README，并让 README 可以跳回 Marla 的介绍主页。

## Outcome

官网首页提供清晰、可访问的 GitHub Releases 下载入口和仓库入口；根 README 以当前代码和验证事实为依据组织产品介绍，并提供回到官网介绍页的入口。

## Why now

Marla 已经有独立的 React/Vite 产品介绍页和真实 App 演示素材，现在需要把发布相关入口放到用户最容易发现的位置，并让 GitHub 仓库首页承担稳定的产品说明与导航职责。

## In Scope

- 在 `website/` 首页导航右上角加入下载图标，指向 `Anti2077/Marla` 的 GitHub Releases 最新页面。
- 在同一位置加入 GitHub 图标，指向项目所有者的 `Anti2077` GitHub 个人主页。
- 为图标提供键盘可访问名称、悬停提示、清晰焦点样式和移动端可用尺寸。
- 重组根 `README.md` 的首屏导航、产品能力、数据边界、项目状态、开发入口和官网回链。
- 为当前产品支持的简体中文、英语、日语、法语、西班牙语、德语和韩语提供 README 版本，并在各版本之间提供语言切换。
- 保留当前尚未公开发布、尚未指定产品版本和未声明公共许可证等事实，不虚构已发布版本或已公证下载包。
- 更新本 Task 与 `STATUS.md`，记录链接边界和验证结果。

## Out of Scope

- 不选择产品 SemVer，不创建新的 release contract，也不修改 Xcode 的 `0.0.0` 开发版本。
- 不创建 GitHub Release、上传安装包、修改仓库 About/Topics/Pages 设置或部署外部域名。
- 不修改 Swift、Rust、原生 App 行为或官网现有产品叙事和视频素材。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-09-09 | Project owner | 首页右上角增加下载和 GitHub 图标 | 下载指向仓库 Releases；GitHub 图标指向 `Anti2077` 个人主页；新增无障碍名称、焦点与响应式验收 | Verified |
| 2026-09-09 | Project owner | 完善根 README，并提供回到 Marla 介绍页的入口 | README 需要与代码事实一致，内部链接可解析；实际部署 URL 待项目所有者提供或授权配置 | Pending owner input |
| 2026-09-11 | Project owner | 为当前支持的 7 种语言制作 README 版本 | 所有版本提供语言切换；链接、产品能力、隐私边界、发布状态和支持语言集合保持一致 | In progress |

## Current evidence

- `website/` 已有 React + Vite 首页、Lucide 图标、真实桌面 MP4 和响应式导航。
- Git remote 已确认仓库为 `https://github.com/Anti2077/Marla`。
- GitHub 仓库当前没有配置可验证的 `homepage` URL，因此 README 回链使用仓库内稳定存在的 `website/` 介绍页目录；本 Task 不假定外部部署已完成。
- 根 README 及各语言版本均使用“正在准备公共入口，但尚未形成公共 Release”的精确状态。
- 官网桌面浏览器回归确认两个图标均位于右上导航、命中区为 `44×44px`、链接目标和辅助名称正确，页面无横向溢出。

## Proposed approach

在 `website/src/App.jsx` 集中定义 GitHub 个人主页、仓库和 Releases URL，在现有右侧导航动作区域加入 Lucide `Download` 与 `Github` 图标链接；在 `website/src/styles.css` 复用现有焦点环和 44px 命中区规则，兼容桌面与窄屏。根 README 保留真实能力和隐私边界，新增产品主页、下载、GitHub 和视频入口，并把状态表述改成发布准备中的事实。

## Acceptance criteria

- [x] 首页右上角可见下载与 GitHub 两个图标，分别进入仓库 Releases 和 `Anti2077` GitHub 个人主页。
- [x] 两个图标在键盘下可聚焦，有 `aria-label`、`title` 和清晰焦点环，触控命中区不小于 44px。
- [x] 桌面导航无文字/图标溢出，不遮挡 Hero 内容；窄屏规则保留两个图标并隐藏长文本 CTA，未进行独立窄屏浏览器截图验证。
- [ ] 根 README 首屏提供已部署的官网介绍页、下载、GitHub 和真实演示入口；当前暂以仓库内 `website/` 源码目录作为临时可验证入口。
- [x] README 的产品能力、平台、版本、隐私、发布与许可证表述与当前代码和 `STATUS.md` 一致。
- [x] README 的官网回链不依赖尚未配置的外部域名，仓库内目标存在。
- [x] 7 个 README 版本均存在，语言切换链接可解析，支持语言、产品能力、隐私边界、发布状态和主要外链保持一致。
- [x] `website` 的 lint/build、`git diff --check` 和仓库级 `./scripts/check.sh` 通过。
- [ ] 本 Task 与 `STATUS.md` 记录已同步并在获得实际官网 URL 后收束。

## Verification

### Automated

```sh
cd website
npm run lint
npm run build
```

```sh
git diff --check
```

2026-09-11：`npm run lint`、`npm run build`、`git diff --check` 和完整 `./scripts/check.sh` 通过。桌面浏览器检查确认下载链接为 `https://github.com/Anti2077/Marla/releases/latest`，GitHub 图标链接为 `https://github.com/Anti2077`，两个入口均为 `44×44px` 并带可访问名称；当前浏览器连接未提供独立视口覆盖，因此未将窄屏截图写成已完成证据。

2026-09-11：补充 `README.en.md`、`README.ja.md`、`README.fr.md`、`README.es.md`、`README.de.md` 和 `README.ko.md`，并在全部版本加入 7 语种切换栏与支持语言表。通过脚本检查文件存在、语言切换目标存在、GitHub/Releases/`website/`/真实 MP4 入口一致，以及 `git diff --check`；网站代码未发生变化。

### Manual

- 在桌面与窄屏浏览器检查右上角两个图标、悬停提示、键盘焦点和外链目标。
- 检查 README 内部链接目标、视频入口和文案事实。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/product/BRAND.md`
- `docs/development/VERSIONING.md`
- `docs/development/WORKFLOW.md`
- `docs/development/STATUS.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/tasks/TASK-036-product-homepage-prototype.md`
- `website/src/App.jsx`
- `website/src/styles.css`
- `README.md`

## Parallel contributors (optional)

None.

## Risks and rollback

- Releases 页面在真正创建首个 GitHub Release 前可能没有可下载资产；链接仍稳定指向未来的最新 Release 页面，不把页面存在误写成已发布事实。
- 外部官网 URL 尚未配置；README 使用仓库内 `website/` 路径，避免写入未经验证的域名。后续部署只需替换回链目标。
- 删除本 Task 修改即可回退，不影响原生 App 和 Rust 核心。

## Decisions needed

- 外部官网部署域名和 GitHub Pages/其他托管方式不在本 Task 内选择。

## Completion record

任务完成时填写：

- Verified commit: 当前提交待项目所有者决定是否合并或推送。
- Automated evidence: `npm run lint`、`npm run build`、`./scripts/check.sh`、`git diff --check` 通过。
- Manual evidence: 桌面浏览器链接、ARIA、44px 命中区和无横向溢出通过；独立窄屏截图验证受当前浏览器接口限制未完成。
- Documentation updated: `README.md`、6 个语言版 README、`docs/development/STATUS.md`、本 Task。
- Remaining work promoted to: None. 外部官网部署、GitHub Release 创建和窄屏现场截图仍需后续发布操作或环境验证；README 的实际官网回链等待项目所有者提供 URL 或授权配置 GitHub Pages。
- Scope changes closed: 首页入口已完成；README 内容和 7 种语言版本已完善，实际官网 URL 仍待输入。
- Parallel contributions integrated: None.
