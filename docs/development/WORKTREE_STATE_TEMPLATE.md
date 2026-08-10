# Worktree State Template

复制本模板到仓库根目录的 `.marla/worktree-state.md`，填写当前工作树的本地协调状态。该目标文件被 Git 精确忽略；本模板本身进入 Git。

这份本地状态只回答“这个工作树当前由谁、为哪个 Task 工作”。范围、验收、架构决定、测试证据和永久交接信息必须写入受 Git 管理的 Task 或规格，不能只留在本文件中。

```md
---
schema_version: 1
worktree_root: "/absolute/path/to/worktree"
branch: "codex/task-name"
state: "active"
task_id: "TASK-XXX"
task_path: "docs/tasks/TASK-XXX-task-name.md"
conversation: "YYYY-MM-DD 可识别的开发对话说明"
owner: "主 Agent 或任务标识"
started_from: "40-character Git commit"
updated_at: "YYYY-MM-DDTHH:MM:SS+08:00"
---

## Write ownership

- `Sources/...`
- `docs/features/...`

## Handoff notes

- Durable scope, decisions, evidence, and acceptance live in the tracked Task.
```

## 字段规则

- `state` 只允许 `idle`、`active`、`blocked`、`handoff` 或 `recovery-required`。
- `idle` 时 `task_id`、`task_path`、`conversation` 和 `owner` 写 `null`；其它 YAML 字符串统一加双引号。
- `started_from` 记录任务开始时的基线提交，不随每个工作提交更新。
- `updated_at` 只是协调提示，不能据此自动判定状态过期或抢占工作树。
- `Write ownership` 记录当前工作树预留的写入路径；全局热点文件仍按 Task 的协调规则分配。
- 不得写入 API Key、剪贴板正文、用户截图、翻译正文或其它敏感数据。

## 初始化与恢复

1. 先运行 `git status --short --branch`、`git rev-parse --show-toplevel` 和 `git rev-parse HEAD`。
2. 新的干净工作树从本模板创建状态，默认可写 `idle`，选定 Task 后再改为 `active`。
3. 如果本地状态缺失且工作树有不明未提交修改，必须创建 `recovery-required` 状态并核对代码、Task 和 Git 历史；不得从聊天记录猜测归属。
4. 如果文件中的 `worktree_root` 或 `branch` 与实时 Git 不符，停止写入并重建状态；分支切换不会自动清除被忽略的本地文件。
5. 完成、阻塞、交接或删除工作树前，先把所有永久信息写入受 Git 管理的 Task，再更新或删除本地状态。

## 验证

```sh
git check-ignore -v .marla/worktree-state.md
git ls-files .marla/worktree-state.md
```

第一条必须显示匹配本地状态的忽略规则；第二条必须没有输出。`./scripts/check.sh` 也会检查这两个不变量。
