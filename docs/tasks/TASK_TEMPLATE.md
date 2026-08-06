# TASK-XXX：简短、结果导向的标题

Status: Draft

Owner: Project owner + Agent

Created: YYYY-MM-DD

Updated: YYYY-MM-DD

Origin: BL-XXX / direct request / defect

## Outcome

用一两句话描述任务完成后用户能够做什么，或我们将获得什么确定证据。

## Why now

说明为什么现在做，以及它与当前产品状态的关系。

## In Scope

- 本任务必须完成的行为或修改。
- 必须同步的测试和文档。

## Out of Scope

- 容易被顺手加入、但本任务明确不做的内容。
- 已记录到 Ideas 或 Backlog 的后续工作。

## Current evidence

- 当前代码和测试已经证明什么。
- 已知失败、日志、截图或复现条件是什么。
- 文档与代码是否存在差异。

## Proposed approach

描述边界、主要数据流和预计修改位置。只有真正耐久的新决策才另建 ADR。

## Acceptance criteria

- [ ] 用户可观察的完成条件。
- [ ] 关键错误或降级路径。
- [ ] 相关自动化测试通过。
- [ ] 需要的真实 App 验证完成。
- [ ] 相关规格和 `STATUS.md` 已同步。

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

## Risks and rollback

- 可能破坏的现有行为。
- 可恢复或关闭方案。

## Decisions needed

- 没有则写 `None`。
- 有则写清必须由项目所有者选择的内容，不由 Agent 猜测。

## Completion record

任务完成时填写：

- Verified commit:
- Automated evidence:
- Manual evidence:
- Documentation updated:
- Remaining work promoted to:
