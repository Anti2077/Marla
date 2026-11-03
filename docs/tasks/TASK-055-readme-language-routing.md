# TASK-055：README 默认英文与多语言切换修复

Status: Ready

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
- Integration status: Unmerged; reservation only
- Depends on: None; TASK-053 license and TASK-054 acknowledgments are already integrated and must be preserved
- Expected merge order: Independent of TASK-051; synchronize current main before integration
- Owned paths: this Task; root `README.md`, `README.en.md`, `README.ja.md`, `README.fr.md`, `README.es.md`, `README.de.md`, `README.ko.md`; a dedicated Simplified Chinese root README to be added using a consistent filename; directly affected references to these README files only when needed to repair language routing, with exact paths recorded before editing
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
| 2026-11-03 | Project owner | 新开对话和 Task 修复默认英文、多语言切换和混排 | 默认页英文、独立中文、七语切换与全文语言一致性检查 | Authorized |

## Current evidence

- primary main 与 origin/main 在预留时均为 1d347c0，primary 干净。
- README.md 首屏存在中文 tagline，简体中文标签指向 README.md、English 指向 README.en.md；正文多数英文，入口、许可、Snow Shot 致谢含中文。
- 现有独立变体为 en/ja/fr/es/de/ko；尚无独立简体中文文件。
- TASK-055 ID 已核对当前分支/所有 refs 的 tracked Task 历史，无占用；本初始提交为 durable reservation。
- 本阶段只创建任务及工作树，不声明 README 已修复。

## Proposed approach

先核对七个现有 README 与当前事实，再确定默认英文和独立中文的文件映射。逐项同步语言栏、正文和锚点，保持各语言语义一致。使用适合文档的链接/结构检查和人工阅读，避免无关的运行时测试。

## Acceptance criteria

- [ ] README.md 全文使用英文，保留必要语言自称、产品名和代码等例外。
- [ ] 独立简体中文文件存在且全文完整，不再把混排默认页标为中文。
- [ ] 全部 README 的七语链接标签、文件目标和实际语言一一对应，能来回切换。
- [ ] 其它语言版本没有意外的英文/中文整段混排，主要内容和顺序对应。
- [ ] 内部路径和锚点可解析，官网/下载/仓库/视频等既有入口有效。
- [ ] GPL 摘要、第三方限制、Snow Shot 致谢与当前事实一致，没有因为翻译改变含义。
- [ ] git diff --check、文档检查及可用的渲染/人工阅读通过，证据记录完整。
- [ ] 功能工作树提交干净，达到 Ready for integration；未经主线整合与验证不标 Done。

## Verification

### Automated

- 验证每个语言栏的标签→目标映射、文件存在性、正文语言及相同事实/外链集合。
- 验证相对链接、页内锚点及必要的跨文档引用。
- git diff --check；如修改脚本或其它内容，再运行适用门禁。
- 本任务为文档修复，完整 App 构建不提供语言正确性证据；不重复无关构建。最终遵循 primary 的集成验证要求。

### Manual

逐语种阅读首屏、各章节、许可和致谢；检查 GitHub 风格渲染及语言切换。语言名列表、代码命令等例外应人工确认，不能简单用非拉丁字符检测代替全文审查。

## Required Reading

- AGENTS.md；docs/development/STATUS.md 及其 universal Required Reading。
- docs/development/WORKFLOW.md；docs/tasks/README.md。
- 所有根 README 变体；docs/tasks/TASK-047-release-homepage-links.md。
- docs/tasks/TASK-053-gpl3-license.md；docs/development/LICENSING.md；THIRD_PARTY_NOTICES.md。
- docs/tasks/TASK-054-element-selection-motion.md 中 README 致谢范围与固定参考。
- 必要时查 Git 历史核对用户提到的默认英文约定；用户本轮明确指令本身即当前要求，不因历史缺失阻塞。

## Parallel contributors

None at reservation. 新对话 Agent 评估文档工作是否适合有界并行；若委派，先按 AGENTS.md 记录文件所有权和只读/写入边界。

## Integration notes

- primary 仅预留 ID、分支和工作树；新对话直接在该工作树开始，首轮核对 live Git 后将 Ready 改为 Active，无需重复征求实施许可。
- 完成后保留清晰 diff、证据和干净提交，标记 Ready for integration。
- primary 使用 ./scripts/main-worktree.sh merge Anti2077/task-055-readme-language-routing；先 check 再做最终文档、验证和 Done。
- 用户此轮只授权新对话实施修复，没有延续 TASK-054 的 push 授权到本 Task。

## Risks and rollback

- 路由调整可能破坏旧 README.en.md 或简体中文链接；查引用并明确兼容策略。
- 翻译可能无意改变许可或隐私边界；对照现有事实并逐段复核。
- 通过聚焦文档提交回滚，不改 App 行为。

## Decisions needed

None. 默认英文由用户明确要求；独立中文文件名和兼容入口属于实现选择。

## Completion record

- Worktree verified commit: Reservation only
- Integration commit: Not integrated
- Integration verification: Pending
- Automated evidence: Task identity/branch/base reviewed; implementation checks pending
- Manual evidence: Initial mixed-language defect confirmed from live README
- Documentation updated: Task reservation only
- Mainline documentation updated by: Not applicable before integration
- Remaining work promoted to: None
- Scope changes closed: Pending implementation
- Parallel contributions integrated: None
- Remote push state: Not authorized; not performed
- Worktree cleanup state: Not authorized; retained
