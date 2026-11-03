# Third-party notices / 第三方归属与许可

Reviewed: 2026-11-03, TASK-053, baseline `e59142ffdf77a184f57f2fa59e7f8d7a86db3f2c` plus license metadata only.

## Scope / 范围

Marla's original work is GPL-3.0-only; dependencies and embedded third-party material retain their own rights. No third-party license is replaced by the root [`LICENSE`](LICENSE). See [`COPYRIGHT`](COPYRIGHT) and the bilingual [licensing/distribution guide](docs/development/LICENSING.md). This file and the inventories identify notices to preserve; they are not a complete notice bundle or Corresponding Source archive for a released binary.

Marla 原创部分采用 GPL-3.0-only；本文件不重许可依赖或嵌入的第三方内容。下列清单是分发准备时的核对入口，不等于已经完成某个发行二进制的通知包/对应源码包。当前没有发布行为。

## Reproducible inventories / 可复核清单

| Inventory | Coverage | Evidence |
| --- | --- | --- |
| [Rust](docs/legal/dependencies/rust.tsv) | 162 external crates from `Cargo.lock`, all targets/options/build dependencies | `cargo metadata --locked --format-version 1`; package license declarations plus top-level license/NOTICE file names and SHA-256 hashes (manifest fallback if absent) |
| [Website](docs/legal/dependencies/website.tsv) | 321 non-root entries from `website/package-lock.json`, including development and optional platform packages | Exact locked version, declared license, registry tarball, dev/optional markers and installed top-level license evidence hashes |

Rust's `aarch64_macos_resolved_graph=yes` marks 119 resolved third-party nodes from `cargo metadata --locked --format-version 1 --filter-platform aarch64-apple-darwin`, including build dependencies. It is not proof of final binary linkage. Cargo's virtual workspace has no resolve root; traverse its workspace members. Website platform-optional packages not installed on this macOS host are explicitly marked “lock metadata only”; their package contents were not inspected. Package versions, selections and lock entries are unchanged by this task. License evidence hashes refer to upstream package contents, not Marla-owned copies.

Rust 表中 119 个 macOS 解析图节点包括构建依赖，不等于最终链接清单。npm 中未在本机安装的可选平台包明确标注仅核对锁文件元数据。没有变更依赖版本/选择；哈希对应上游包中的原始文件。依赖清单覆盖元数据，不声称对每个包全部源文件及嵌套资产完成法律审计。

Before distribution, retrieve the exact packages, retain their original license/copyright/NOTICE texts and inspect any nested or file-specific notices. A package SPDX expression, author field, hash or this index does not replace those texts. Refresh both inventories whenever dependency versions, features, targets or shipped artifacts change.

## Native application / 原生 App

`Package.swift` declares local Marla targets only; no external Swift package or resolved Swift package lock was found. SwiftUI, AppKit, Vision, ScreenCaptureKit, Natural Language, Keychain, system speech and SF Symbols are Apple platform facilities/resources, not project-owned GPL sources. No Apple SDK/framework or external model runtime is vendored by this task. Assess applicable System Library and platform-resource terms for the actual distribution.

The five direct Rust dependencies are below. Versions and all transitive packages are in the Rust inventory; copyright remains with their upstream rightsholders.

| Component | License choice / declaration | Upstream attribution |
| --- | --- | --- |
| futures-util | MIT OR Apache-2.0; MIT may be selected | [rust-lang/futures-rs](https://github.com/rust-lang/futures-rs), futures-rs contributors |
| reqwest | MIT OR Apache-2.0; MIT may be selected | [seanmonstar/reqwest](https://github.com/seanmonstar/reqwest), reqwest contributors |
| serde | MIT OR Apache-2.0; MIT may be selected | [serde-rs/serde](https://github.com/serde-rs/serde), Serde contributors |
| serde_json | MIT OR Apache-2.0; MIT may be selected | [serde-rs/json](https://github.com/serde-rs/json), serde_json contributors |
| tokio | MIT | [tokio-rs/tokio](https://github.com/tokio-rs/tokio), Tokio contributors |

No incompatible declared license was identified for the native dependency graph under GPLv3. That conclusion requires retaining applicable permissive notices and does not mean the dependencies themselves become GPL-only. Important transitive cases:

| Family / locked component | Treatment |
| --- | --- |
| MIT / ISC / BSD-3-Clause / Apache-2.0 crates | Preserve copyright, license, disclaimer and applicable Apache NOTICE/patent terms; Apache-2.0 is compatible with GPLv3. |
| `aws-lc-rs 1.17.3`, `aws-lc-sys 0.43.0` | Preserve their composite `AND` conditions, not just a single ISC label. `aws-lc-sys/LICENSE` attributes Amazon/AWS-LC, Google/BoringSSL, OpenSSL and Eric Young, mlkem-native/mldsa-native, fiat-crypto, s2n-bignum and Jitter Entropy, among others. The included Jitter Entropy branch is expressly BSD-3-Clause, not GPLv2-only. Retain component-specific notices and the license distinctions for libraries vs test/build sources. |
| `ring 0.17.14` | Apache-2.0 AND ISC. Its `LICENSE` points to `LICENSE-other-bits`, `LICENSE-BoringSSL`, and once_cell notices in `src/polyfill/once_cell/`; inspect/preserve them when conveying this component. |
| ICU4X / Unicode crates and `unicode-ident 1.0.24` | Unicode-3.0 permissive notices remain; `unicode-ident` combines `(MIT OR Apache-2.0) AND Unicode-3.0`, not just the chosen MIT branch. |
| `webpki-root-certs 1.0.9` | CDLA-Permissive-2.0 root-certificate data, with original attribution/license; it occurs in the all-target lock inventory, not this macOS filtered graph. |
| `r-efi 6.0.0`, `wasi 0.11.1+wasi-snapshot-preview1`, Unlicense/MIT and Zlib alternatives | Select an available MIT branch where appropriate; this does not remove other files' applicable notices. No need to select the optional LGPL branch of r-efi. |

原生依赖声明未发现 GPLv3 组合许可冲突；AWS-LC/ring 的复合通知和 Unicode 数据许可仍须保留，不能将其统一改写成 GPL。清单含其他平台/可选项，不代表 Marla 打包了那些实现。

## Website / 官网

Original website source follows Marla's GPL-3.0-only grant. The following external runtime dependencies keep separate terms:

| Locked component | Attribution / original license | Compatibility treatment |
| --- | --- | --- |
| `react 19.2.8`, `react-dom 19.2.8` | Meta Platforms, Inc. and affiliates; MIT, original `LICENSE` in each package | Preserve MIT notice. |
| `lucide-react 0.468.0` | Lucide Contributors 2022; portions by Cole Bemis 2013–2022 from Feather (MIT); package `LICENSE` is ISC and records the Feather attribution | Preserve the complete package notice, including Feather attribution. |
| `@fontsource-variable/geist 5.3.0` | Copyright 2024 The Geist Project Authors, [vercel/geist-font](https://github.com/vercel/geist-font); SIL OFL-1.1, package `LICENSE` | Font remains OFL; preserve font license/copyright and applicable reserved-name rules. GPL of surrounding source does not relicense the font. |
| `gsap 3.15.0` | Copyright (c) 2008–2026 GreenSock, per package README; [GSAP Standard License](https://gsap.com/standard-license) | **Incompatible with GPL's unrestricted downstream uses; unresolved for a GPL-compatible combined website build.** |
| `@gsap/react 2.1.2` | Copyright (c) 2008–2025 GreenSock, per package README; same Standard License | Same unresolved restriction; no GPL linking exception is granted here. |

On 2026-11-03 the [official GSAP Standard License](https://gsap.com/standard-license) restricted uses that build visual animation tools competing with Webflow and reverse engineering for Competitive Products. The packages' `package.json` and README point to that license. “No charge” and permission for ordinary commercial websites are not GPL compatibility. Their code is not relicensed here. This finding does not assert that merely running the present marketing page violates GSAP's permitted-use terms; it prevents claiming that the combined work gives every recipient GPL freedoms. Removal/replacement or explicit compatible permission must be resolved in separately authorized work before claiming GPL-compatible distribution of that build. No incompatible dependency was introduced by TASK-053.

官网的 GSAP 限制不属于原生 App 依赖，也不否认当前营销页可能符合 GSAP 的 Permitted Uses；它意味着不能宣称组合产物向所有接收者提供完整 GPL 自由。保留原许可或写例外清单本身不能解决该冲突。未来替换/移除或取得明确兼容授权须另行处理，本任务没有改变官网实现。

Other locked website/build dependencies declare MIT, Apache-2.0, ISC, BSD-2-Clause or BSD-3-Clause, plus these cases:

- `argparse 2.0.1`: Python-2.0 declaration; installed `LICENSE` contains the PSF, BeOpen, CNRI Python 1.6.1 GPL-compatible carve-out, and CWI notices. Preserve the actual composite text rather than treating every historical Python-2.0-era license as identical. This is a development-tool dependency, not Python bundled in the App.
- `caniuse-lite 1.0.30001810`: CC-BY-4.0 compatibility data; preserve attribution/license and identify modifications if redistributed. Its data is part of the website toolchain; CC-BY-4.0 is GPL compatible while its original attribution/license obligations remain; it does not make unmodified data GPL-only. Inspect the shipped output before deciding whether tool data is conveyed.

The 321 entries have no missing license field. Review of noninstalled platform-optional packages is limited to lock metadata. This is not a certification of every upstream file, nor a clearance of the GSAP combination.

## Assets and external services / 资产与外部服务

- Paper Lantern SVG and derived PNG/AppIcon assets are the project's selected original design (TASK-027 / ADR-0008), covered by the owner's grant to the extent of the owner's rights.
- Five desktop MP4s are owner-provided Marla demonstrations documented in TASK-036 and `website/public/media/README.md`. Captured third-party text, pages, system UI and marks retain their rights; this task does not claim permission to relicense those contents. Source synthetic multilingual fixtures are project test material; no separate third-party notice was found in them.
- Cloud providers and optional user-installed Ollama/GLM-OCR are external services/software/models, not vendored dependencies. No model weights, service entitlement, credentials or Apple resource license is conveyed by GPL of Marla.
- No Snow Shot code was added or identified as an existing dependency. A future GPL-3.0-or-later import must retain that source's version grant and attribution; this task does not review or approve such an import.

## Reference texts / 参考

- [GNU GPLv3](https://www.gnu.org/licenses/gpl-3.0.html), especially sections 1 and 4–7
- [GNU license compatibility list](https://www.gnu.org/licenses/license-list.html), including Apache-2.0, Unicode License v3, Python and SIL OFL
- [GPL FAQ](https://www.gnu.org/licenses/gpl-faq.html)
- [CC BY 4.0 legal code](https://creativecommons.org/licenses/by/4.0/legalcode)
- [CDLA-Permissive-2.0](https://cdla.dev/permissive-2-0/)

These references explain the review; they are not evidence of an external legal opinion or publication approval.
