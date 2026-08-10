# Task 施工单

Task 是一次开发对话的持续施工记录，也是 Agent 的直接实施依据。对话开始实现时创建一个 Task；对话中追加的相关功能、修复和细节继续加入同一个 Task。讨论未来功能不自动创建实现 Task。

一个共享工作树中通常最多只有一个写入型 `Active` Task。整个仓库可以有多个显式隔离的分支/工作树 Task，但必须分别记录负责人、基线、整合目标、路径所有权和重叠项。`STATUS.md` 不登记这些并行 Task。

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
- `Ready for integration`：功能工作树中的实现、测试和文档已经验证，等待进入目标分支。
- `Done`：已经进入目标分支，并由整合负责人完成目标分支验证和全局文档同步。
- `Cancelled`：明确停止，保留原因。

历史 Task 中的 `Complete`、`Completed` 或旧式 `Done` 不做追溯改写；其 Completion record 继续说明当时的验证边界。新 Task 使用以上状态。

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
- 并行 Task 的编号由主线协调者在创建工作树前集中分配或预留；两个工作树不得各自按目录扫描结果选择同一个“下一个编号”。
- 新 Task 必须记录 worktree、branch、base commit、integration target、owned paths、known overlaps 和 dependencies。
- 功能工作树只维护自己的 Task 和已分配规格；`STATUS.md`、全局 Backlog/Roadmap/索引默认由整合负责人串行更新。
- `.marla/worktree-state.md` 只是本工作树的 ignored 指针。永久范围、决定、证据和交接必须留在 tracked Task 中。

## Parallel contributors

A Task may use multiple sub-Agents without creating additional Tasks. The Task remains the single implementation contract for the conversation.

文档工作进行委派时，主 Agent 应记录或明确告知：

- 每个子 Agent 的边界目标；
- Required Reading；
- 允许写入的文件或章节；
- 只读审查还是可以编辑；
- 交付格式和验证要求。

工作树主 Agent 独占 Task 文件和范围变更记录；整合负责人独占目标分支 `STATUS.md`、全局索引和最终整合记录。子 Agent 的“完成”只表示其分工已交回审查，不表示整个 Task 完成。

## Parallel worktree coordination

独立工作树负责人不是同一 Task 内的普通子 Agent。开始前由协调者明确：

- 唯一 Task ID；
- worktree、branch、base commit 和 integration target；
- owned paths、known overlaps、dependencies 和 merge order；
- 哪个工作树担任 integration owner。

功能工作树完成后先进入 `Ready for integration`。整合负责人检查实时目标分支、处理重叠文件、运行最终验证、同步 `STATUS.md` 和全局索引，再把对应 Task 标记为 `Done`。关闭一个 Task 不会改变其它工作树的本地状态或生命周期。
