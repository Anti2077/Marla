# TASK-XXX：简短、结果导向的标题

Status: Draft

Owner: Project owner + Agent

Created: YYYY-MM-DD

Updated: YYYY-MM-DD

Origin: BL-XXX / direct request / defect

Conversation: 当前开发对话的标题、日期或可识别说明

## Execution context

- Worktree: `/absolute/path/to/worktree`
- Branch: `Anti2077/task-NNN-short-name`（三位编号与本 Task 一致）
- Base commit: `40-character commit`
- Integration target: `main`
- Integration owner: primary worktree path or named owner
- Integration status: Not started / Unmerged / Ready for integration / Integrated
- Depends on: None / TASK-XXX
- Expected merge order: Independent / before or after TASK-XXX
- Owned paths: 明确的文件或目录
- Known overlaps: None / 与其它 Task 重叠的路径和协调方式

## Initial request

记录项目所有者开启本次开发对话时的原始目标。后续追加内容不改写这里，而是进入 Scope changes。

## Outcome

用一两句话描述任务完成后用户能够做什么，或我们将获得什么确定证据。

## Why now

说明为什么现在做，以及它与当前产品状态的关系。

## In Scope

- 当前对话累计要求完成的行为或修改，包括后续明确追加的内容。
- 必须同步的测试和文档。

## Out of Scope

- 容易被顺手加入、但本任务明确不做的内容。
- 已记录到 Ideas 或 Backlog 的后续工作。

## Scope changes during the conversation

每次追加、移除或改变需求时增加一行；不要只修改 In Scope 而丢失变化来源。

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| YYYY-MM-DD | Project owner / necessary support | 增加、调整或移除的内容 | 新增或修改哪些验收与验证 | Pending / Verified / Removed |

## Current evidence

- 当前代码和测试已经证明什么。
- 已知失败、日志、截图或复现条件是什么。
- 文档与代码是否存在差异。

## Proposed approach

描述边界、主要数据流和预计修改位置。只有真正耐久的新决策才另建 ADR。

## Acceptance criteria

- [ ] 初始请求和 Scope changes 中所有仍有效的要求都有对应验收项。
- [ ] 用户可观察的完成条件。
- [ ] 关键错误或降级路径。
- [ ] 相关自动化测试通过。
- [ ] 新增代码未使任何源文件超过结构门禁。
- [ ] 需要的真实 App 验证完成。
- [ ] 相关规格已同步；未整合时已记录建议的全局文档变化，整合后由主工作树同步 `STATUS.md` 和索引。
- [ ] 功能分支名、唯一匹配的 `TASK-NNN-*.md`、`Ready for integration` 状态、干净工作树和 current `main` ancestry 满足 `scripts/main-worktree.sh merge` 的门禁。

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

列出设备、应用、输入样本、预期结果和证据位置。

## Required Reading

- `docs/...`
- `Sources/...`
- `Tests/...`
- 相关 Accepted ADR。

## Parallel contributors (optional)

如果本 Task 使用了文档子 Agent，记录其边界和写入所有权；没有则写 `None`。

| Contributor | Objective | Required Reading | Write ownership | Permission | Output / status |
| --- | --- | --- | --- | --- | --- |
| Agent name | 独立目标 | 文件列表 | 文件或章节 | Read-only / Edit | 交付结果 |

## Integration notes

- 需要主工作树写入 `STATUS.md`、Backlog、Roadmap 或索引的内容。
- 目标分支前进后需要重新核对的代码、规格和测试。
- 与依赖 Task 的路径重叠、冲突策略和建议合并顺序。
- 主工作树运行 `./scripts/main-worktree.sh merge <feature-branch>`；合并后先运行 `check`，再完成 Task/`STATUS.md` 语义同步和最终 `./scripts/check.sh`。

## Risks and rollback

- 可能破坏的现有行为。
- 可恢复或关闭方案。

## Decisions needed

- 没有则写 `None`。
- 有则写清必须由项目所有者选择的内容，不由 Agent 猜测。

## Completion record

功能工作树验证完成时先标记 `Ready for integration`；进入目标分支并完成目标分支验证后才标记 `Done`。

- Worktree verified commit:
- Integration commit:
- Integration verification:
- Automated evidence:
- Manual evidence:
- Documentation updated:
- Mainline documentation updated by:
- Remaining work promoted to:
- Scope changes closed:
- Parallel contributions integrated:
- Remote push state:
- Worktree cleanup state:
