# Task 施工单

Task 是一次开发对话的持续施工记录，也是 Agent 的直接实施依据。对话开始实现时创建一个 Task；对话中追加的相关功能、修复和细节继续加入同一个 Task。讨论未来功能不自动创建实现 Task。

一个工作树中通常最多只有一个写入型 `Active` Task。整个仓库可以有多个显式隔离的功能工作树 Task，但必须分别记录分支、基线、整合目标、负责人、路径所有权、依赖、重叠项和合并顺序。`STATUS.md` 不登记这些并行 Task 的瞬时活动状态。

## 文件命名

```text
TASK-001-short-name.md
```

编号一经使用不回收。标题使用可读短语，不使用版本号代替工作内容。

## 生命周期

- `Draft`：正在补齐范围，禁止实现。
- `Ready`：范围和验收明确，等待项目所有者启动。
- `Active`：对应开发对话正在进行；范围可随项目所有者在对话中的要求继续更新。
- `Blocked`：存在具体外部阻塞，记录恢复条件。
- `Ready for integration`：功能工作树的实现、测试、文档和分支审查已经完成，等待进入目标分支。
- `Done`：已经进入目标分支，并由整合负责人完成目标分支验证和全局文档同步。
- `Cancelled`：明确停止，保留原因。

历史 Task 中使用的 `Complete`、`Completed` 或旧式 `Done` 不做追溯改写；其 Completion record 继续说明当时的证据边界。新 Task 使用以上状态。

## 使用规则

- 一个 Task 对应一次开发对话，可以包含对话过程中逐步增加的多个相关结果。
- 初始 `In Scope`、`Out of Scope` 是起点。项目所有者追加要求后，移动或补充相关条目，并在 Scope changes 中记录来源和影响。
- `Required Reading` 只列真正相关文档，避免每次吞下整个项目历史。
- 验收必须可观察；“体验更好”“代码更优雅”不能单独作为标准。
- 项目所有者在当前对话中明确要求的附加功能，直接扩展当前 Task，同时增加对应验收和测试。
- Agent 发现为完成已有要求所必需的支撑工作时，可以补入当前 Task，但必须说明原因。
- Agent 自己想到的便利功能仍写入 `backlog/IDEAS.md`，不能借“顺便”之名实现。
- 明显无关、需要新权限、破坏性迁移、独立架构决策或并行隔离的新增内容，先说明影响，由项目所有者决定并入当前 Task 还是另开后续 Task。
- Task 完成后不因新的开发对话而重新打开；新对话创建新 Task，并通过 Related/Origin 链接旧 Task。
- Task ID 由主工作树的整合负责人分配。创建命名分支/工作树并提交初始 Task 后，该编号才完成仓库内预留；其它工作树不得独立猜测下一个编号。
- 新 Task 必须记录 worktree、branch、base commit、integration target、integration owner、owned paths、known overlaps、dependencies 和 expected merge order。
- 功能工作树只维护自己的 Task、实现、测试和已分配规格；`STATUS.md`、全局 Backlog/Roadmap/索引默认由主工作树在整合阶段串行更新。
- `.marla/worktree-state.md` 是可选的 ignored 本地指针。永久范围、决定、证据、验收和交接必须进入 tracked Task 或规格。
- 本地验证、合入目标分支、目标分支验证、推送远端和工作树清理是五个不同状态，不得互相冒充。

## Parallel contributors

A Task may use multiple sub-Agents without creating additional Tasks. The Task remains the single implementation contract for the conversation.

文档工作进行委派时，主 Agent 应记录或明确告知：

- 每个子 Agent 的边界目标；
- Required Reading；
- 允许写入的文件或章节；
- 只读审查还是可以编辑；
- 交付格式和验证要求。

工作树主 Agent 独占 Task 文件和范围变更记录；主工作树的整合负责人独占目标分支 `STATUS.md`、全局索引、最终整合记录和授权推送。子 Agent 的“完成”只表示其分工已交回审查，不表示整个 Task 完成。

## 主工作树与功能工作树

主工作树独占本地 `main`，负责 Task-ID 分配、工作树创建、依赖与合并顺序、整合审查、冲突处理、目标分支验证、全局文档和授权推送。普通功能不直接在主工作树施工。

功能工作树负责人不是同一 Task 内的普通子 Agent。开始前由整合负责人明确：

- 唯一 Task ID；
- worktree、branch、base commit 和 integration target；
- owned paths、known overlaps、dependencies 和 expected merge order；
- 哪个工作树担任 integration owner。

功能工作树完成后进入 `Ready for integration`。整合负责人检查实时目标分支、处理重叠文件、运行最终验证、同步 `STATUS.md` 和全局索引，再把 Task 标记为 `Done`。关闭一个 Task 不会改变其它工作树的 Task、分支或本地状态。
