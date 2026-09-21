# TASK-050：最近翻译快速复制

Status: Ready for integration

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
- Integration status: Ready for integration
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
| 2026-09-21 | Project owner | 初始范围 | 行内译文复制、菜单原文复制、保留恢复 | Implemented; automated and screenshot verified |

## Current evidence

- `RecentTranslationsSection` 使用覆盖整行的 Button，只调用 `onSelect`；摘要为只读纯文本投影。
- `RecentTranslation` 保存完整 sourceContent 和 translation；现有结果卡复制规范 Markdown 并移除末尾换行。
- main 新工作流要求功能分支完成后止于 `Ready for integration`，主线状态留待整合负责人更新。

## Proposed approach

提取最近翻译行到 App 层独立文件。恢复按钮与复制 Button/Menu 为兄弟控件，避免嵌套按钮事件冲突；Session 层按历史 ID 查找并直接写入剪贴板，返回是否成功，UI 独立管理短暂反馈。沿用现有颜色、字体、间距和系统图标。

## Acceptance criteria

- [x] 每条历史行可一键复制完整译文，菜单可复制对应完整原文。
- [x] 复制不会打开结果卡、改变当前会话、历史顺序或启动请求；失效 ID/空内容不覆盖剪贴板。
- [x] Markdown、内部换行、非 ASCII 和长内容保留；仅移除末尾换行。
- [x] 恢复、复制和菜单为独立原生控件；AX 树确认各动作名称。成功反馈已实现，实际点击和键盘遍历留在下述人工验收缺口。
- [x] `./scripts/check.sh` 通过，相关规格同步，结构门禁和 `git diff --check` 通过。
- [x] 真实 App 浅色/深色截图完成五维审查，各维至少 7/10；未验证交互明确记录。
- [x] 工作树干净、当前 main ancestry、唯一 Task 和分支符合整合门禁。

## Verification

### Automated

- `./scripts/check.sh` 在完整 macOS 会话通过：52 Rust / 272 Swift tests、strict Clippy、SwiftPM build/test、Xcode Debug、结构/脚本语法/空白检查和 `git diff --check`。
- 三个新增测试验证历史 ID 隔离、完整 Markdown/长内容/非 ASCII/内部换行、末尾换行裁剪、过期 ID 不修改剪贴板、无活动会话时复制，以及活动流式会话/历史快照不变。使用独立测试 Pasteboard，不覆盖用户剪贴板。
- 空原文不会进入历史（既有约束）；最初测试错误地假设可进入，已改为验证既有约束。
- 沙箱初跑在既有 AppKit 测试中因 NSScreen 不可用崩溃；完整桌面会话重跑通过。
- 日志：`/private/tmp/marla-task-050-check-full.log`。

### Manual

- `./scripts/build-test-app.sh` 通过；本工作树 `artifacts/Marla_dev.app` 为稳定身份 `API Usage Monitor Dev` 签名，Bundle ID `com.marla.app`、版本 `0.0.0`、arm64、最低 macOS 14 和 designated requirement 已验证。
- 使用现有 `menu-recents` 离线合成样本，未访问 Provider，未修改生产历史。浅色：`/private/tmp/marla-task-050-light.png`；深色 + Reduce Motion：`/private/tmp/marla-task-050-dark.png`。
- 两种外观中三条历史的恢复箭头、复制图标、下拉箭头均完整显示，长摘要按预期省略；行高维持 44pt，复制命中区域 28×32pt、菜单 24×32pt，遵循项目原生桌面紧凑控件规则。
- 真实 App AX 树读出各行独立恢复按钮、复制译文按钮、更多复制选项菜单及“复制原文”项。之后 Computer Use 多次返回 `timeoutReached`，未取得实际点击、成功对勾、菜单展开/选择及键盘遍历的端到端证据。未将尝试记为成功。
- 进程采样显示本轮离线 App 主线程正常等待事件；不足以证明工具超时的根因。主线 App 另有运行实例，未关闭或修改。
- 五维截图审查（浅色/深色）：哲学一致性 8、视觉层级 8、工艺质量 8、功能性 7、原创性 8。功能分因完整鼠标/键盘验收缺失保守记 7；本评分仅是截图设计审查，不代替交互验收。
- Owner follow-up：在本分支 App 完成任意翻译后，点历史行复制并粘贴核对译文；打开相邻菜单复制原文并粘贴核对；点文字恢复结果；用键盘遍历动作。此项为尚未完成的人工交互证据，整合审查时保留。

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

- Worktree verified commit: 本 Task 最终实现提交（见 Git）
- Integration commit: None
- Automated evidence: 52 Rust / 272 Swift tests and Xcode Debug passed
- Manual evidence: Signed Release light/dark screenshots and AX labels verified; pointer/keyboard end-to-end pending due to Computer Use timeout
- Documentation updated: This Task and `docs/features/recent-translations.md`; `STATUS.md` unchanged
- Remote push state: Not pushed
- Worktree cleanup state: Retained
