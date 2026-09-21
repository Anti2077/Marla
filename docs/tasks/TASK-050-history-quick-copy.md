# TASK-050：最近翻译快速复制

Status: Active

Owner: Project owner + Agent

Created: 2026-09-21

Updated: 2026-09-21

Origin: direct request

Conversation: 2026-09-21，菜单最近翻译右侧快速复制译文和原文

## Execution context

- Worktree: `/Users/anti/.codex/worktrees/a698/Marla`
- Branch: `Anti2077/task-050-history-quick-copy`
- Base commit: `ccc2b3e928623cfef921ad5853386af02d3e79e7`
- Integration target: `main`
- Integration owner: `/Users/anti/Documents/ChatGPT/Marla`
- Integration status: Unmerged
- Depends on: None
- Expected merge order: Independent
- Owned paths: `Sources/MarlaApp/MarlaApp.swift`, new history views under `Sources/MarlaApp/App/`, history copy extension under `Sources/MarlaApp/Sessions/`, `Tests/MarlaAppTests/RecentTranslationCopyTests.swift`, `Marla.xcodeproj/project.pbxproj`, `docs/features/recent-translations.md`, this Task; existing UI automation only as needed for offline real-App verification.
- Known overlaps: None identified; recheck at integration.

## Initial request

从 main 新建分支；在截图所示最近翻译条目右侧增加快速复制译文图标，并在旁边提供可展开的复制原文菜单，遵循 main 更新后的文档系统。

## Outcome

用户不必重新打开结果卡，即可复制对应历史条目的完整译文或原文。

## Why now

当前整行只有恢复结果动作，复制历史结果需要额外打开结果卡。

## In Scope

- 每条最近翻译的独立复制译文按钮、相邻原生下拉菜单内的复制原文动作。
- 保留文字区域的结果恢复入口；复制不恢复或取消当前会话，不启动请求。
- 使用完整规范内容，遵循现有复制的末尾换行策略，提供明确 tooltip、无障碍名称和短暂成功反馈。
- 回归测试、真实 App 截图审查和对应功能规格。

## Out of Scope

- 历史持久化、删除、搜索；新复制格式；Provider/Rust/FFI、产品版本或发布；合并和推送。
- 功能工作树不修改 `STATUS.md` 或文档索引。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-09-21 | Project owner | 初始范围 | 行内译文复制、菜单原文复制、保留恢复 | Active |

## Current evidence

- `RecentTranslationsSection` 使用覆盖整行的 Button，只调用 `onSelect`；摘要为只读纯文本投影。
- `RecentTranslation` 保存完整 sourceContent 和 translation；现有结果卡复制规范 Markdown 并移除末尾换行。
- main 新工作流要求功能分支完成后止于 `Ready for integration`，主线状态留待整合负责人更新。

## Proposed approach

提取最近翻译行到 App 层独立文件。恢复按钮与复制 Button/Menu 为兄弟控件，避免嵌套按钮事件冲突；Session 层按历史 ID 查找并直接写入剪贴板，返回是否成功，UI 独立管理短暂反馈。沿用现有颜色、字体、间距和系统图标。

## Acceptance criteria

- [ ] 每条历史行可一键复制完整译文，菜单可复制对应完整原文。
- [ ] 复制不会打开结果卡、改变当前会话、历史顺序或启动请求；失效 ID/空内容不覆盖剪贴板。
- [ ] Markdown、内部换行、非 ASCII 和长内容保留；仅移除末尾换行。
- [ ] 恢复入口、键盘/无障碍语义和菜单点击保持独立，成功反馈可见。
- [ ] `./scripts/check.sh` 通过，相关规格同步，结构门禁和 `git diff --check` 通过。
- [ ] 真实 App 浅色/深色截图完成五维审查，各维至少 7/10；未验证交互明确记录。
- [ ] 工作树干净、当前 main ancestry、唯一 Task 和分支符合整合门禁。

## Verification

### Automated

`./scripts/check.sh`；历史 ID、规范复制、无副作用、失效/空内容回归。

### Manual

固定 Release App 的合成历史样本验证复制、菜单、恢复；浅色/深色截图只存临时目录。

## Required Reading

- `AGENTS.md`, `docs/development/STATUS.md`, `docs/README.md`
- `docs/product/PRODUCT.md`, `docs/product/UX_PRINCIPLES.md`, `docs/development/VERSIONING.md`, `docs/architecture/ARCHITECTURE.md`
- `docs/development/UI_UX_SKILLS.md`, `docs/tasks/TASK-034-history-plain-text-window-placement.md`
- `docs/architecture/decisions/ADR-0007-app-layer-modularity.md`, `docs/architecture/decisions/ADR-0009-semantic-markdown-translation-contract.md`
- `Sources/MarlaApp/MarlaApp.swift`, `Sources/MarlaApp/Sessions/TranslationSessionStore.swift`
- Existing history tests in `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors

None. 紧密耦合的小型 UI/规格修改，由本 Agent 维护。

## Integration notes

主工作树整合后更新 STATUS/文档索引；用 `./scripts/main-worktree.sh merge Anti2077/task-050-history-quick-copy`，之后 `check` 和最终 `./scripts/check.sh`。当前不授权整合、推送或清理。

## Risks and rollback

紧凑历史行的文本空间和相邻点击区域是主要风险；复制控件独立于恢复按钮。可整体回退本 Task。

## Decisions needed

None.

## Completion record

- Worktree verified commit: Pending
- Integration commit: None
- Automated evidence: Pending
- Manual evidence: Pending
- Documentation updated: This Task
- Remote push state: Not pushed
- Worktree cleanup state: Retained
