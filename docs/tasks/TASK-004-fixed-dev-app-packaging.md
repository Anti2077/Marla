# TASK-004: 固定覆盖开发测试 App

Status: Done

Owner: Project owner + Agent

Created: 2026-08-06

Updated: 2026-08-06

Origin: direct request / packaging workflow decision

## Outcome

日常 Release 测试构建默认覆盖固定路径 `artifacts/Marla_dev.app`，并复用稳定本地签名身份，以最大限度保留 macOS TCC 权限；不再默认生成时间戳 App。

## Why now

项目所有者明确选择用 Git 保存源码历史，不保留每次测试二进制。固定路径与稳定代码签名也比时间戳、ad-hoc 构建更适合反复验证辅助功能和屏幕录制权限。

## In Scope

- 修改 `scripts/build-test-app.sh`，默认安全覆盖唯一的 `artifacts/Marla_dev.app`。
- 默认从现有 `Marla_dev.app` 复用稳定签名身份；也允许显式 `MARLA_CODE_SIGN_IDENTITY`。
- 没有可用稳定身份时明确失败，不静默退回 ad-hoc 签名。
- 保留自定义产物路径的显式覆盖保护，避免误删其他 App。
- 同步 `AGENTS.md`、README、架构、0.1.0 中英文规格、验收和 `STATUS.md`。
- 实际覆盖构建并验证 `Marla_dev.app` 的路径、Bundle ID、版本、架构、签名和 designated requirement。

## Out of Scope

- 保留历史测试 App、DMG、Developer ID、公证、自动更新或公开发行。
- 重置、自动授予或绕过 TCC 权限。
- 删除现有时间戳测试 App；它们保留不动，但以后不再默认生成。
- 提交或推送 Git。

## Current evidence

- 当前脚本默认生成 `Marla_test_yyyyMMddHHmm.app`，默认使用 ad-hoc 签名；只有显式传入三个环境变量才覆盖 `Marla_dev.app`。
- 现有 `artifacts/Marla_dev.app` 位于目标固定路径，Bundle ID 为 `com.marla.app`，designated requirement 绑定稳定本地证书。
- TCC 识别代码身份而不只是文件名；固定完整路径、Bundle ID 和稳定签名共同降低重复授权概率。
- 当前工作树已有 TASK-003 及其他未提交更改，本任务必须保留并只修改打包工作流相关位置。

## Proposed approach

把固定开发 App 路径设为脚本默认目标。覆盖前先解析现有目标的签名证书身份；若用户显式提供 `MARLA_CODE_SIGN_IDENTITY` 则优先使用。脚本先完成 Release 构建，再只允许自动替换精确的默认开发 App 路径。自定义目标若已存在，仍要求显式 `MARLA_ALLOW_ARTIFACT_REPLACE=1`。

## Acceptance criteria

- [x] 无参数运行脚本只生成或覆盖 `artifacts/Marla_dev.app`，不新增时间戳 App。
- [x] 覆盖前后 Bundle ID、稳定签名证书和 designated requirement 保持一致。
- [x] 默认路径之外的已有目标仍不能被意外覆盖。
- [x] 缺少稳定签名身份时脚本失败并给出修复说明，不退回 ad-hoc。
- [x] `./scripts/check.sh` 通过。
- [x] 相关中英文规格、项目指南、README 和 `STATUS.md` 同步。

## Verification

### Automated

```sh
./scripts/check.sh
./scripts/build-test-app.sh
```

### Manual

- 记录覆盖前后的 `codesign -d -r- artifacts/Marla_dev.app`。
- 启动固定路径 App，确认 macOS 使用同一应用身份；TCC 是否实际持久仍留在 BL-002 的真实重启验收中。

## Required Reading

- `docs/development/STATUS.md`
- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/architecture/ARCHITECTURE.md`
- `AGENTS.md`
- `README.md`
- `scripts/build-test-app.sh`
- `scripts/verify-app.sh`

## Risks and rollback

- 默认覆盖会丢失上一份二进制；项目所有者已接受，源码由 Git 保留，新二进制可随时重建。
- 路径相同但签名身份变化仍可能触发 TCC 重授权；脚本必须拒绝无稳定身份构建。
- 构建、签名或 staging 验证失败时保留现有 `Marla_dev.app`；已验证临时包替换旧目录时仍有极短的文件系统切换窗口。
- 可通过恢复时间戳命名逻辑回滚；不影响应用代码或用户设置。

## Decisions needed

None. 项目所有者已明确选择只覆盖固定开发 App，并接受不保留旧二进制。

## Completion record

- Verified commit: 未提交工作树；项目所有者未要求 commit 或 push。
- Automated evidence: `zsh -n scripts/build-test-app.sh` 通过；ad-hoc 身份拒绝和自定义已有路径覆盖保护通过；`./scripts/check.sh` 通过（Rust 16、Swift 22、Swift/Xcode Debug、格式/空白/diff）；无参数 `./scripts/build-test-app.sh` 成功。
- Manual evidence: `artifacts/Marla_dev.app` 覆盖前后 Bundle ID 均为 `com.marla.app`，designated requirement 均绑定证书 `6CA76BAE136FC3FD1CCE6FC2DBB08A6C42E5988D`；最终版本 0.1.0、最低 macOS 14、arm64、Authority `API Usage Monitor Dev`。时间戳 App 数量前后均为 17，staging 残留为 0。
- Documentation updated: `AGENTS.md`、`README.md`、`docs/architecture/ARCHITECTURE.md`、0.1.0 `SPEC.md` / `IMPLEMENTATION.md` / `ACCEPTANCE.md`、`docs/development/STATUS.md`。
- Remaining work promoted to: TCC 权限在真实重启后的持久性继续由 `BL-002` 验收；固定路径和稳定签名只降低重复授权概率。
