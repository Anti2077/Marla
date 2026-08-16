# 发布前检查

请在 **星期五下午三点** 前完成以下检查，并让所有命令和占位符保持原样。

## 基础流程

1. 启动 `Marla_dev.app`。
2. 打开设置窗口，确认 API Profile 名称为 **Staging**。
3. 翻译一段包含 *强调文本*、链接和代码的内容。

> 如果状态不是 `ready`，请停止发布并记录 `{{STATUS}}`。

### 验收项目

- [ ] 标题与列表层级正确
- [ ] 链接目标没有变化
- [ ] 行内代码 `MARLA_API_KEY` 没有被翻译
- [ ] 复制结果仍是完整 Markdown

| 项目 | 期望值 | 实际值 |
| --- | --- | --- |
| 构建编号 | `${BUILD_ID}` | `{{BUILD_ID}}` |
| 最低系统 | macOS 14 | `{{MIN_OS}}` |
| 状态 | ready | `{{STATUS}}` |

详细步骤见 [发布文档](https://example.com/docs?lang=zh-CN&section=release)。

```sh
export MARLA_API_KEY="${MARLA_API_KEY}"
launchctl kickstart -k gui/501/com.example.marla
```

最后输出一句结论：**可以发布**或**需要回滚**。
