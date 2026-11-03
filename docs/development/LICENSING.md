# Marla 许可与分发 / Licensing and distribution

## 中文

### 项目许可及边界

Marla 项目所有者于 2026-11-03 明确授权将其有权授权的原创代码、构建脚本、文档及原创项目资产按 **GNU GPL 第 3 版，仅此版本（SPDX: `GPL-3.0-only`）** 提供。根目录 [`LICENSE`](../../LICENSE) 是从 [GNU 官方全文](https://www.gnu.org/licenses/gpl-3.0.txt) 获取的未修改英文原文；[`COPYRIGHT`](../../COPYRIGHT) 指明版权署名和项目授权范围。全文末尾的应用示例包含 “or later” 模板，不能据此将 Marla 的明确选择解释成 `GPL-3.0-or-later`。本说明不替代许可证正文。

GPL 允许使用、修改、再分发和商用，但分发须遵守其条件；Marla 没有增加“禁止商用”、禁止竞争、禁止修改或其他附加限制。软件不提供 GPL 正文所述的保证。普通内部使用/修改不等于对外分发；GPLv3 也不包含 AGPL 的网络交互源码条款。

本轮可达 `main` 历史仅发现 `Anti2077` 一个作者身份（首条记录 2026-08-05），没有发现独立的外部贡献者声明或既有根许可证。作者身份和仓库内容检索不构成完整权利链证明，也不代表发生过版权转让。所有者本次授权仅覆盖其有权授权的内容；今后外部贡献者保有自身版权，贡献时须确认有权按本项目 GPL-3.0-only 条款提交，并保留第三方来源、许可和修改说明。本项目未在此建立 CLA 或声称历史贡献者已签署协议。

Paper Lantern 的项目原创 SVG、衍生 PNG 和 AppIcon 属于项目资产（来源记录见 TASK-027、ADR-0008）；这不将 Apple 的 SF Symbols、系统字体、系统 UI 或演示视频中出现的外部内容变成 Marla 的作品。视频外壳/项目原创部分的授权不授予其中第三方网页、文字、商标等内容的权利。公开再分发这些内容前仍应核对来源或使用可明确授权的示例。此处没有对 GPL 已授予的项目原创内容追加限制，也未完成公共商标清查。

### 依赖兼容性结果

完整版本和许可证声明见 [`THIRD_PARTY_NOTICES.md`](../../THIRD_PARTY_NOTICES.md) 及其链接的锁文件清单。第三方组件保留原版权和原许可，根许可证与 Cargo/npm 的项目许可字段不重许可它们。`OR` 可以选择获准的分支，`AND` 的各项要求须同时满足；Apache-2.0 的 NOTICE、MIT/ISC/BSD 的版权与许可文本等仍须保留。

- 原生 App：Swift Package 只有本地 target，没有外部 Swift 包；Rust 锁文件中的 162 个外部 crate（含所有平台、可选及构建依赖）均有许可声明。当前 aarch64 macOS 解析图包含其中 119 个，含构建依赖，不能把它们全部写成最终二进制已链接内容。所检查声明中没有发现阻碍 GPLv3 组合分发的许可证；这不是二进制级法律审计或未来发布合规验收。
- 官网：321 个 npm 锁条目（含平台可选和开发工具）均有许可声明。**`gsap 3.15.0` 与 `@gsap/react 2.1.2` 的 Standard License 含竞争用途限制，与 GPL 的自由再分发条件不兼容。官网原创源码的 GPL 授权不覆盖它们；当前含 GSAP 的组合构建不能宣称是全部 GPL 兼容的发行物。** 它们不属于原生 App 依赖。将来若要以 GPL 兼容条件分发官网组合产物，须先取得权利方明确的兼容许可，或经另行授权移除/替换相关实现；仅放入例外清单、免费商用、购买普通许可或更新项目元数据都不能自行消除冲突。本任务没有移除或更换依赖，也没有授予额外链接例外。
- Geist 字体继续按 OFL-1.1 单独提供；保留字体版权和许可，不重许可为 GPL。Lucide/Feather 图标保留各自 ISC/MIT 归属。未随 Marla 打包的 Apple 系统库/资源、外部 Ollama/模型和云服务不因调用而被本项目重新授权；将来捆绑它们必须重新评估，不能直接沿用本轮结论。

本次没有引入 Snow Shot 代码，也没有实现元素吸附。若后续引入标为 `GPL-3.0-or-later` 的来源，在许可允许时可选择 GPLv3 与 Marla 组合，但来源文件的原始 `or-later` 授权、版权及通知必须保留，不能改写成 `only`。后续还须核对具体文件、依赖及修改范围，当前不声称已经完成该来源的合规审查。

### 分发时的对应源码与通知

本任务只改变仓库许可与文档，不发布 App 或网站。未来分发者须针对实际交付物和 GPLv3 第 4–6 节选择适用的合规方式。对通过下载提供目标代码的常见情形，第 6(d) 节要求在同一指定地点以等价方式提供对应源码访问，并清楚说明其位置；不能仅链接一个可能继续变化的分支，也不能把本说明当成已履行的源码要约。

对应源码必须与交付二进制的精确版本和修改相对应，采用便于修改的形式，包含生成、安装、运行和修改该作品所需的源码、接口定义、构建/安装控制脚本及相关依赖源码（依法适用的系统库/一般工具例外除外）。仅提供 Marla 仓库地址、Cargo.lock 或包管理器下载链接不能自动证明对应源码完整。通常应随每个交付物固定：

1. 精确提交/修改记录、Swift/Rust/C 桥接源码、资源源文件；`Package.swift`、Cargo manifests、`Cargo.lock`、`.cargo/` 配置、Xcode 工程及共享 scheme、`Resources/Info.plist` 和 `scripts/` 中适用的构建/验证脚本。若分发官网，另包含其源码、`package.json`、锁文件和 Vite 配置，并先解决 GSAP 冲突。
2. 可重建该交付物的工具链、目标平台、依赖版本及获取/构建/安装说明；依法需要的依赖对应源码和原始许可/版权/NOTICE，不以本轮清单代替实际收集。GPL 第 6 节在适用的 User Product 情形下还要求必要的 Installation Information，须针对实际交付方式核对。
3. GPLv3 全文、版权和第三方通知、显著的修改及日期说明，并满足适用的交互式法律通知要求。保留原有法律通知；`THIRD_PARTY_NOTICES.md` 是审查入口，不是已完成的最终二进制通知包。

当前开发构建入口是 `./scripts/check.sh`（编译/测试及未签名 Xcode Debug 验证），固定路径的本机签名 Release 入口是 `./scripts/build-test-app.sh`，详见根 README 和脚本。签名证书、API Key、个人数据不应随源码归档公开；不要把所有者的本机签名身份当成接收者修改/构建源码的前提。实际发行的安装信息义务须单独确认。当前不存在公开发行验收、Developer ID/公证或已验证对应源码包的结论。

## English

### License and scope

On 2026-11-03 the project owner authorized the original Marla code, build scripts, documentation and original project assets they can license under **GNU GPL version 3 only (`GPL-3.0-only`)**. The root [`LICENSE`](../../LICENSE) is the unmodified [official GNU text](https://www.gnu.org/licenses/gpl-3.0.txt); [`COPYRIGHT`](../../COPYRIGHT) states attribution and scope. The “or later” wording in the license's application example does not change Marla's explicit version-only choice. This guide does not replace the license.

The GPL permits use, modification, redistribution and commercial use subject to its conditions. Marla adds no noncommercial, competition, modification or other restriction. The GPL warranty disclaimer applies. Private internal use/modification does not by itself mean conveyance, and GPLv3 does not impose AGPL's network-interaction source clause.

Reachable `main` history reviewed for this task contains one author identity, `Anti2077`, with the first record on 2026-08-05. No separate external-contributor declaration or prior root license was found. Git identity and repository searches do not establish a complete chain of title or a copyright assignment. This grant covers only rights the owner can grant. Future contributors retain their copyright and must have the right to submit under GPL-3.0-only while preserving third-party origins, licenses and change notices. This task creates no CLA and claims no historical contributor agreement.

The original Paper Lantern SVG and derived PNG/AppIcon assets are project assets documented in TASK-027 and ADR-0008. Apple SF Symbols, system fonts/UI, and third-party material visible in demonstrations remain outside the owner's grant. Licensing the original recording/project portions does not grant rights to captured third-party pages, text or marks. Verify such content before public redistribution or use clearly licensed examples. This adds no restriction to GPL-covered original material and does not claim trademark clearance.

### Dependency findings

See [`THIRD_PARTY_NOTICES.md`](../../THIRD_PARTY_NOTICES.md) and its locked inventories. Dependencies retain their original copyrights and licenses; project Cargo/npm fields do not relicense them. Choose an available `OR` branch and satisfy every `AND` condition, preserving required license/copyright texts and Apache NOTICE files.

- Native App: SwiftPM uses local targets only. All 162 external locked Rust crates, including optional, build and other-platform packages, declare licenses. The current aarch64 macOS graph contains 119 of them, including build dependencies; that count is not a binary linkage inventory. No GPLv3-incompatible declared license was identified in that review. This is neither a binary-level legal audit nor release compliance acceptance.
- Website: all 321 npm lock entries, including optional-platform and development tools, declare licenses. **`gsap 3.15.0` and `@gsap/react 2.1.2` use a Standard License with competitive-use restrictions incompatible with GPL freedoms. The original website source's GPL grant does not cover them; the current combined GSAP website build must not be described as wholly GPL compatible.** They are absent from the native App's dependencies. GPL-compatible conveyance of that combined website requires explicit compatible rights from the relevant rightsholders or separately authorized removal/replacement. An exception list, free commercial use, ordinary license purchase or metadata change does not itself resolve this conflict. This task replaces no dependency and grants no linking exception.
- Geist remains separately OFL-1.1 with its copyright and license. Lucide/Feather retains ISC/MIT attribution. Unbundled Apple system libraries/resources, external Ollama/models and cloud services are not relicensed by calling them; reassess before any future bundling.

This task imports no Snow Shot code and implements no element snapping. A future `GPL-3.0-or-later` source may permit selecting GPLv3 for a combined work, but its original `or-later` grant, copyright and notices must remain. Check the exact files, dependencies and modifications in that future task; no completed Snow Shot compliance review is claimed here.

### Corresponding Source and notices when conveying

This task changes repository licensing/documentation only and publishes no App or website. A future distributor must select an applicable method under GPLv3 sections 4–6 for the actual delivery. For typical downloadable object code, section 6(d) requires equivalent access to Corresponding Source from the same designated place and clear directions to it. A moving branch URL alone is insufficient; this guide is not a fulfilled source offer.

Corresponding Source must match the actual delivered binary and modifications, in the preferred form for modification, including source, interfaces, build/install control scripts and dependency source needed to generate, install, run and modify it, subject to applicable System Library/general-tool exceptions. A repository URL, lockfile or package-manager download links alone do not establish completeness. Normally fix with each artifact:

1. Exact revision and changes; Swift/Rust/C bridge code and resource sources; `Package.swift`, Cargo manifests/lockfile, `.cargo/` configuration, Xcode project/shared scheme, `Resources/Info.plist`, and applicable `scripts/` build/verification scripts. A website delivery also needs its source, package/lockfiles and Vite configuration after resolving GSAP.
2. Reproduction instructions, toolchain, platform and dependency versions; required dependency source plus original license/copyright/NOTICE texts. The inventories do not replace collection. Assess necessary Installation Information for applicable User Products under section 6 against the actual distribution.
3. GPLv3 text, copyright and third-party notices, prominent modification/date notices, and applicable interactive legal notices. Preserve existing legal notices. The notice index is an evidence entry point, not a completed final binary notice bundle.

`./scripts/check.sh` builds/tests and verifies unsigned Xcode Debug; `./scripts/build-test-app.sh` builds the fixed locally signed Release development App. See the root README and scripts. Do not publish signing certificates, API keys or personal data in source archives, or make the owner's local signing identity a prerequisite for recipients to modify/build source. Separately assess actual installation-information obligations. No public release acceptance, Developer ID/notarization or verified Corresponding Source archive is claimed.
