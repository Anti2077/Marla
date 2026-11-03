# TASK-053：落实 GPL-3.0-only 项目许可

Status: Active

Owner: Project owner + Agent

Created: 2026-11-03

Updated: 2026-11-03

Origin: direct request

Conversation: 2026-11-03 项目所有者授权 GPLv3 许可落地（来源对话 01a19f33-64bb-77a2-92b9-3a723b5f407d）

## Execution context

- Worktree: `/private/tmp/marla-task-053-gpl3-license`（本轮可丢弃工作树；持久证据保存在 Git）
- Branch: `Anti2077/task-053-gpl3-license`
- Base commit: `e59142ffdf77a184f57f2fa59e7f8d7a86db3f2c`
- Integration target: `main`
- Integration owner: primary worktree `/Users/anti/Documents/ChatGPT/Marla`
- Integration status: Unmerged
- Depends on: None
- Expected merge order: Independent; recheck current main and license/dependency changes before merge
- Owned paths: `LICENSE`, `COPYRIGHT`, `THIRD_PARTY_NOTICES.md`, `docs/development/LICENSING.md`, `README*.md`, `rust/marla-core/Cargo.toml`, `website/package.json`, `website/package-lock.json`, this Task; `docs/README.md`, `docs/tasks/README.md`, `docs/development/STATUS.md` only during primary integration
- Known overlaps: other live worktrees remain untouched; primary owner exclusively owns final global indexes and STATUS

## Initial request

项目所有者明确授权采用 GPLv3，按 GPL-3.0-only 落地；保留第三方原始许可。检查归属、贡献者及直接/传递依赖兼容性，使用官方未修改全文，补齐项目声明、归属与对应源码/构建脚本分发说明。不得实现元素吸附、引入 Snow Shot 代码或新依赖、添加禁止商用条款、发布 App/发行版或推送远端。无需重复询问采用 GPL 的意愿；真正缺失的第三方权利需具体列明。

## Outcome

仓库有明确且范围准确的 GPL-3.0-only 声明、可复核的依赖许可记录和分发说明；未知权利或不兼容项不得被伪装成合规完成。

## In Scope

- 核对本仓库已跟踪的许可、版权、作者、资产来源和锁定依赖。
- 官方 GPLv3 全文；Marla 原创内容授权、第三方例外、现有多语言声明同步。
- 记录依赖许可选择、分发责任、源码与构建脚本要求、证据限制。
- 许可元数据和必要文档检查；按实际变更选择验证。

## Out of Scope

- Snow Shot 或元素吸附实现、新依赖、功能/UI/打包机制修改。
- App 构建/发布、发行版、版本变更、远端推送、其他工作树清理。
- 重许可第三方内容、杜撰权利转让或法律审查结论。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-11-03 | Project owner | Initial explicit GPL-3.0-only authorization | License, provenance, dependency and documentation checks | Pending |

## Current evidence

- Primary checkout clean at base commit; no existing root LICENSE/NOTICE found.
- Reachable main author identity: Anti2077; Git identity alone does not prove ownership of third-party material.
- README variants still say no public license selected; this Task deliberately updates that statement.
- Swift Package has only local targets; Rust and website dependencies require separate review.

## Proposed approach

保持依赖及第三方来源原许可，用单独双语许可指南和第三方清单解释边界；不将根 GPL 声明解释成对所有外部内容的重许可。采用 GPL-3.0-only 是本任务明确的产品决定，无需新增架构 ADR。

## Acceptance criteria

- [ ] Root LICENSE matches official unmodified GNU GPLv3 text; only-version selection is explicit outside that text.
- [ ] Project-owned content, copyright attribution and third-party exclusions are accurate without unsupported ownership claims.
- [ ] Locked direct/transitive Rust and website dependencies reviewed; conflicts and unknowns explicitly recorded.
- [ ] Existing multilingual README license claims synchronized; bilingual licensing/distribution guidance complete.
- [ ] No Snow Shot code, new dependency, noncommercial restriction, version/publication/push introduced.
- [ ] Applicable manifest/document/link/license checks and `git diff --check` pass.
- [ ] Feature branch committed clean at Ready for integration; target documentation and verification recorded only after guarded integration.

## Verification

Documentation/license-only work: official-text byte comparison, dependency lock/manifest inventory, notice/license-source review, relative-link and multilingual consistency checks, manifest parsing, scoped diff review and `git diff --check`. No runtime behavior changes are planned; full build is not a substitute for license checks. Integration checks follow repository workflow.

## Required Reading

- `AGENTS.md`; universal STATUS Required Reading
- `docs/development/WORKFLOW.md`, `docs/tasks/TASK_TEMPLATE.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`, `ADR-0004-swiftui-rust-core.md`, `ADR-0008-paper-lantern-brand-identity.md`, `ADR-0010-unversioned-incubation.md`
- `Package.swift`, `Cargo.toml`, `rust/marla-core/Cargo.toml`, `Cargo.lock`
- `website/package.json`, `website/package-lock.json`, `website/public/media/README.md`
- root README variants; `docs/tasks/TASK-027-paper-lantern-brand-identity.md`, `docs/tasks/TASK-036-product-homepage-prototype.md`, `docs/tasks/TASK-047-release-homepage-links.md`

## Parallel contributors

None. Evaluated parallel review: license scope, exception wording and evidence inventory are tightly coupled; one writer keeps this bounded change consistent.

## Integration notes

Primary owner synchronizes current license baseline and documentation entry links after guarded merge. Do not change product/release readiness claims or other Task lifecycle labels. No push or cleanup authorized.

## Risks and rollback

License metadata does not prove ownership or distribution compliance. Preserve all external notices; any actual incompatible license or missing permission must remain visible. Reverting repository text cannot retract rights already validly granted to recipients.

## Decisions needed

None for GPL-3.0-only adoption. Specific third-party rights blockers, if found, will be identified separately.

## Completion record

- Worktree verified commit: Pending
- Integration commit: Pending
- Integration verification: Pending
- Automated evidence: Pending
- Manual evidence: License/provenance review pending; no legal audit claimed
- Documentation updated: Pending
- Mainline documentation updated by: Pending primary integration
- Remaining work promoted to: None
- Scope changes closed: Pending
- Parallel contributions integrated: None
- Remote push state: Not authorized; not performed
- Worktree cleanup state: Not authorized; retained
