# Task 施工单

Task 是一次开发对话的持续施工记录，也是 Agent 的直接实施依据。对话开始实现时创建一个 Task；对话中追加的相关功能、修复和细节继续加入同一个 Task。讨论未来功能不自动创建实现 Task。

共享工作树中通常最多只有一个 `Active` Task。只有明确使用独立分支或工作树并约定归属时，才允许并行的开发对话分别拥有 Active Task。

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
- `Done`：代码、测试和文档均已验证。
- `Cancelled`：明确停止，保留原因。

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

## Parallel contributors

A Task may use multiple sub-Agents without creating additional Tasks. The Task remains the single implementation contract for the conversation.

文档工作进行委派时，主 Agent 应记录或明确告知：

- 每个子 Agent 的边界目标；
- Required Reading；
- 允许写入的文件或章节；
- 只读审查还是可以编辑；
- 交付格式和验证要求。

主 Agent 独占 Task 文件、范围变更记录、`STATUS.md`、最终整合和完成记录。子 Agent 的“完成”只表示其分工已交回审查，不表示整个 Task 完成。
