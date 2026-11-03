# TASK-055：README 默认英文与多语言切换修复

Status: Active

Owner: Project owner + Agent in the new TASK-055 conversation

Created: 2026-11-03

Updated: 2026-11-03

Origin: direct request / documentation defect

Conversation: 项目所有者在 TASK-054 对话后要求新开对话和 Task，修复 README 默认语言与混排

## Execution context

- Worktree: `/private/tmp/marla-task-055-readme-language-routing`（primary 刻意创建的独立可丢弃工作树；永久记录进入 Git）
- Branch: `Anti2077/task-055-readme-language-routing`
- Base commit: `1d347c0ed6dc05b0060563d9d5f9c7ecd1242ed2`
- Integration target: `main`
- Integration owner: primary `/Users/anti/Documents/ChatGPT/Marla`
- Integration status: Unmerged; implementation and local verification complete
- Depends on: None; TASK-053 license and TASK-054 acknowledgments are already integrated and must be preserved
- Expected merge order: Independent of TASK-051; synchronize current main before integration
- Owned paths: this Task; root `README.md`, `README.en.md`, `README.zh-CN.md` (new Simplified Chinese edition), `README.ja.md`, `README.fr.md`, `README.es.md`, `README.de.md`, `README.ko.md`. No other reference file requires editing: repository-wide reference search found only README navigation and historical Task mentions of `README.en.md`.
- Known overlaps: No active owner identified for root READMEs; preserve integrated TASK-047 links/media, TASK-053 licensing facts and TASK-054 Snow Shot attribution. Other worktrees and Tasks are excluded. STATUS.md and global indexes remain primary-integration-owned.

## Initial request

“README.md 有问题。我记得之前设定的是默认英文版，然后再切换为各种不同语言的版本。现在点默认的，好像也是英文版，而且好几个语言混在一起。你开一个新的对话和 task 修复一下。”

## Outcome

GitHub 默认展示的 README.md 为完整英文；读者可切换到独立、完整的简体中文、日语、法语、西班牙语、德语、韩语版本。语言标签、链接目标和实际正文一致，没有意外的多语正文混排。

## Why now

当前 README.md 在导航中标为简体中文，实际大部分正文为英文，而首屏、入口说明、许可与致谢含中文。English 又指向 README.en.md，造成默认页语言归属混乱。

## In Scope

- 恢复 README.md 为默认完整英文版，全部版本的 English 链接指向默认英文入口。
- 创建独立简体中文版本并完整本地化，全部版本的简体中文链接指向该文件。
- 审查并修复七种语言版本的首屏、导航、正文、致谢、许可证摘要和开发说明；保留合理的产品名、代码、命令、语言自称列表和必要引用。
- README.en.md 若保留，明确其兼容用途并避免与默认英文正文漂移；若移除，先查全引用并修复入口，不能留下断链。
- 保持能力、隐私、未发布状态、链接、许可证和 Snow Shot 参考事实一致；修复语言时以当前代码/STATUS 为依据，不顺手重写产品范围。
- 检查本地链接、锚点、语言标签到正文的对应、版本间事实一致性，以及 Markdown/GitHub 阅读效果；记录可复核证据。

## Out of Scope

- App 源码、SwiftUI、Rust、协议、行为、签名、产品版本或网站设计改动。
- 变更 GPL-3.0-only 授权、第三方许可结论、删减 GSAP 兼容性说明或移除 Snow Shot 致谢。
- 发版、部署、自动推送、清理其它分支/工作树。
- 直接在 main 修改 README；本 Task 在预留工作树实施，完成后等待整合。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-11-03 | Project owner | 新开对话和 Task 修复默认英文、多语言切换和混排 | 默认页英文、独立中文、七语切换与全文语言一致性检查 | Verified |
| 2026-11-03 | Necessary support | 七语统一当前四协议、普通截图三种 OCR 与独立原位实验入口说明；修正开发入口误称 STATUS 登记 Active Task | 对照本分支代码、STATUS 与 ADR，避免语言修复继续传播过期事实；不改行为或扩大能力 | Verified |

## Current evidence

- 开工时 live Git：工作树与指定路径一致，分支 `Anti2077/task-055-readme-language-routing`，HEAD `1b3f9f35c96964847960afd383030e9e2f66d34d`，无未提交修改；没有本地身份文件。预留记录中的 main/origin 状态是当时快照，本轮不写 primary。
- 原始缺陷：README.md 大部英文，首屏、入口、许可及致谢夹中文，简体中文标签指向该混排页。现已改为默认完整英文，新增完整 `README.zh-CN.md`，另外五语保持各自正文语言。
- 八个文件共用同一七语映射；七个完整版本均为 10 个二级章节、2 个三级章节，四张表的数据行数依次为 3/5/7/7。语言表和可见徽章采用本版语言，语言栏保留语言自称，API/产品名和代码保持技术原名。
- `README.en.md` 仅作兼容入口，保留旧英文的 12 个二/三级章节锚点，再指向默认全文；不维护第二份英文产品正文。默认页另外保留原中文致谢与混合许可标题的不可见锚点别名。西语 `por-qué-marla` 与德语 `datenschutz-ohne-ausflüchte` 导航已按 GitHub slug 规则修复。
- 当前源码与 STATUS 支持四个翻译协议、Vision 默认及云端/本机 GLM-OCR、默认关闭的独立原位实验入口、Keychain 凭据及仅内存截图/最近翻译。原 README 未区分本机 OCR、只写 OpenAI 兼容配置；本轮已七语同步这些现有事实，不增加功能或关闭任何实机验收缺口。
- TASK-053 许可摘要和 GSAP 兼容性限制、TASK-054 的具体借鉴/独立实现边界及固定源码版本、所有既有入口均保留；TASK-053/054 生命周期及全局文档未修改。

## Proposed approach

以原完整英文版作为默认正文基线，完成简体中文翻译并逐段核对另外五语。七语同步导航、能力/隐私/未发布事实与开发入口，英文旧文件只保留兼容路由。使用 GFM 渲染、GitHub 标题 slug、真实浏览器交互、语言检测和逐段人工阅读共同审查，未用 App 构建代替文档正确性证据。

## Acceptance criteria

- [x] README.md 全文使用英文，保留必要语言自称、产品名和代码等例外。
- [x] 独立简体中文文件存在且全文完整，不再把混排默认页标为中文。
- [x] 全部 README 的七语链接标签、文件目标和实际语言一一对应，能来回切换。
- [x] 其它语言版本没有意外的英文/中文整段混排，主要内容和顺序对应。
- [x] 内部路径和锚点可解析，官网/下载/仓库/视频等既有入口有效。
- [x] GPL 摘要、第三方限制、Snow Shot 致谢与当前事实一致，没有因为翻译改变含义。
- [x] git diff --check、文档检查及可用的渲染/人工阅读通过，证据记录完整。
- [ ] 功能工作树提交干净，达到 Ready for integration；未经主线整合与验证不标 Done。

## Verification

### Automated

- 验证每个语言栏的标签→目标映射、文件存在性、正文语言及相同事实/外链集合。
- 验证相对链接、页内锚点及必要的跨文档引用。
- git diff --check；如修改脚本或其它内容，再运行适用门禁。
- 本任务为文档修复，完整 App 构建不提供语言正确性证据；不重复无关构建。最终遵循 primary 的集成验证要求。

2026-11-03 本地结果：

- GFM 解析使用 `marked 18.1.3`，标题 ID 使用 `github-slugger 2.0.0`：8 文件的 56 个语言标签→目标、223 个本地链接/图片路径、40 个片段引用全部通过；原英文 12 个章节锚点全部保留；七个完整版本的章节、表格结构、语言代码、四协议、OCR/实验入口、版本哨兵、GPL/GSAP 与固定 Snow Shot 链接集合一致。徽章 URL 只本地化状态/平台标签，产品入口外链集合相同。
- `Playwright 1.64.1` + 现有 Chromium 153.0.8010.12，在 `github-markdown-css 5.9.0` 的本地 GFM 预览中检查 1280×1000 与 390×1000：8 文件共 16 个视口，无整页横向溢出、无损坏图片；56 次语言切换并返回、所有页内导航及七个完整版本的折叠签名说明通过。西/德/韩最后措辞修正后又针对 6 个视口、21 次语言切换重验通过。
- `franc-min 6.2.0` 检查 71 段超过 150 字符的正文，全部对应 eng/cmn/jpn/fra/spa/deu/kor；最后西/德/韩的 36 个样本重验通过。此检测只作补充，不替代许可/隐私逐段审读。默认英文去除语言栏与不可见 HTML 标签后，不含中日韩字符段。
- 未认证 HTTP GET：Marla 仓库、`releases/latest`、Snow Shot 仓库、固定源码 revision 均为 200。`releases/latest` 实际重定向至 Releases 列表，未据此声称有发行资产。`website/` 与真实 MP4 均为现存仓库路径；没有编造已部署官网域名。
- `git diff --check` 通过；最终 staged diff 再检查。没有修改代码、依赖清单或运行构建/签名/发布。

临时复核工具与输出位于 `/private/tmp/marla-task-055-review/`：`review.mjs` / `link-report.json`、`browser.mjs` / `browser-report.json` / `browser-final-report.json`、`http-report.json`、本地 `rendered/` 与截图。依赖仅装在该临时目录，npm 缓存使用 `/private/tmp/marla-task-055-npm-cache`；未改变项目或系统配置。临时文件不构成持久交付，以上范围、工具版本、数量、结果和限制保存在本 Task，内容本身由 Git 审查。

### Manual

逐语种阅读首屏、各章节、许可和致谢；检查 GitHub 风格渲染及语言切换。语言名列表、代码命令等例外应人工确认，不能简单用非拉丁字符检测代替全文审查。

已逐段审读七语正文并对照相同事实顺序；人工查看全部八个入口的窄屏首屏、七语致谢/许可截图、默认英文桌面与中文折叠开发说明。徽章文字、语言栏换行、入口链接、GPL/GSAP 限制、Snow Shot 参考与原名例外均可读，未发现整段混排。此处是本地 GitHub 风格预览，不声称修改已经推送或在 GitHub 上发布。

## Required Reading

- AGENTS.md；docs/development/STATUS.md 及其 universal Required Reading。
- docs/development/WORKFLOW.md；docs/tasks/README.md。
- 所有根 README 变体；docs/tasks/TASK-047-release-homepage-links.md。
- docs/tasks/TASK-053-gpl3-license.md；docs/development/LICENSING.md；THIRD_PARTY_NOTICES.md。
- docs/tasks/TASK-054-element-selection-motion.md 中 README 致谢范围与固定参考。
- 必要时查 Git 历史核对用户提到的默认英文约定；用户本轮明确指令本身即当前要求，不因历史缺失阻塞。
- 事实复核：`Sources/MarlaCore/TranslationModels.swift` 的语言/协议枚举；`OCRModels.swift`；`Sources/MarlaApp/Shortcuts/GlobalShortcuts.swift`；`Persistence/MarlaSettingsStore.swift`、`KeychainCredentialStore.swift`；`Sessions/TranslationSessionStore.swift`；`App/ScreenshotTranslation.swift`；`Settings/ExperimentalSettingsSection.swift`；`Tests/MarlaAppTests/MarlaAppTests.swift` 的实验开关测试和 `RecentTranslationCopyTests.swift`；`rust/marla-core/src/glm_ocr.rs`、`lib.rs` 的适配及测试；`scripts/check.sh`。
- 相关已接受决定：ADR-0003、ADR-0004、ADR-0010、ADR-0011、ADR-0012；ADR-0001 中仍有效的原生呈现边界。

## Parallel contributors

None. 已评估：七语版本共享同一事实、路由及兼容策略，逐段同步与整体验证紧密耦合；本轮由单一写入者完成，避免许可/隐私语义在并行翻译中漂移。

## Integration notes

- primary 仅预留 ID、分支和工作树；新对话直接在该工作树开始，首轮核对 live Git 后将 Ready 改为 Active，无需重复征求实施许可。
- 完成后保留清晰 diff、证据和干净提交，标记 Ready for integration。
- primary 使用 ./scripts/main-worktree.sh merge Anti2077/task-055-readme-language-routing；先 check 再做最终文档、验证和 Done。
- 用户此轮只授权新对话实施修复，没有延续 TASK-054 的 push 授权到本 Task。
- 只需在整合时按事实记录默认英文/独立中文与兼容策略；不改 TASK-047/053/054 的历史记录或生命周期。STATUS/索引同步由 primary 判断，功能工作树未越权写入。

## Risks and rollback

- 路由调整可能破坏旧 README.en.md 或简体中文链接；查引用并明确兼容策略。
- 翻译可能无意改变许可或隐私边界；对照现有事实并逐段复核。
- 通过聚焦文档提交回滚，不改 App 行为。

## Decisions needed

None. 默认英文由用户明确要求。中文采用 `README.zh-CN.md`（文件名表示文档地区，产品语言代码仍为 `zh-Hans`）；`README.en.md` 保留为英文兼容入口，只链接默认全文及原有章节锚点，不复制正文。全部语言栏 English 指向 `README.md`。

## Completion record

- Worktree verified commit: Implementation complete; commit recorded in the final readiness update (reservation `1b3f9f3`)
- Integration commit: Not integrated
- Integration verification: Pending
- Automated evidence: 56 language routes, 223 local links/images, 40 fragments, 12 old English anchors, seven-edition structure/facts, 71 language samples, 16 browser viewports, 4 external HTTP targets and whitespace checks passed; final wording rechecked in 6 viewports / 21 switches
- Manual evidence: Seven editions read against common facts; all entry/acknowledgment/license renderings plus desktop English and Chinese build details reviewed; full results and limits above
- Documentation updated: Eight root README files including the new Simplified Chinese edition and English compatibility entry; this Task
- Mainline documentation updated by: Not applicable before integration
- Remaining work promoted to: None
- Scope changes closed: Requested routing/localization and necessary current-fact corrections verified; final clean commit/readiness transition pending
- Parallel contributions integrated: None
- Remote push state: Not authorized; not performed
- Worktree cleanup state: Not authorized; retained
