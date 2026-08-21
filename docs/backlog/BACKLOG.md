# Marla Backlog

Backlog 只收录项目所有者已经确认需要完成、但尚未成为当前 Task 的未来产品工作。已完成、拒绝或被后续实现取代的条目不继续占据当前 Backlog；它们由对应 Task、Git 历史、`STATUS.md` 和 `VERIFICATION.md` 保存。

Backlog 不是当前执行队列，也不代表发布日期。开始实现仍需项目所有者明确选择，并创建一个范围、排除项、验收和验证完整的 Task。

## 状态定义

- `Ready`：范围足够明确，可以创建独立 Task。
- `Needs evidence`：方向已确认，但需要验证数据才能拆成实现任务。
- `Needs decision`：工作有必要，但关键产品选择仍需项目所有者确认。
- `Blocked`：存在明确外部阻塞。
- `Deferred`：已确认，但项目所有者明确暂不选择为孵化期 Task。

## 当前 Backlog

| ID | 工作 | 状态 | 提升为 Task 的条件 |
| --- | --- | --- | --- |
| BL-005 | 按需语境增强引擎 | Needs decision | 完成发送内容、默认开关、清洗规则和质量基准的产品决策 |

历史编号保持不复用。BL-001～003、BL-006～015 已完成、迁移或关闭，不再保留在当前 Backlog；需要追溯时查看对应 Task、`VERIFICATION.md` 与 Git 历史。

## BL-005：按需语境增强引擎

- **目标**：在用户触发翻译时，以有限、可解释、可关闭的语境提升术语与语气判断。
- **已接受方向**：ADR-0003 规定按需采集、有界、短时缓存，不持续截屏或监控窗口。
- **当前未进入 Task 原因**：允许发送的字段、默认开关、清洗规则、字符/TTL 上限和质量基准仍需产品决策。
- **首个 Task 边界**：只验证一种证据源；不同时实现附近文本、窗口分类、短时缓存和持久术语表。
- **相关想法**：`IDEAS.md` 的 IDEA-001；用户可控术语表仍单独保留为 IDEA-005。

## 提升规则

将 Backlog 条目提升为 Task 时：

1. 复制 `tasks/TASK_TEMPLATE.md`，分配下一个连续编号。
2. 用本次开发对话的目标定义明确范围、排除项、验收、验证与 Required Reading。
3. 在本文件链接当前 Task，并在 `development/STATUS.md` 设置同一个 Active Task。
4. 对话中项目所有者追加的强相关要求继续更新同一 Task 的范围变化记录。
5. Task 完成后从当前 Backlog 移除；历史由 Task、Git、Status 和 Verification 保存。
