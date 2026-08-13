# Marla Backlog

Backlog 只收录已经确认需要完成、但尚未成为当前 Task 的未来产品工作。它不是想法清单，也不是当前执行队列，更不代表已经承诺某个发布日期。当前版本的实机验收和性能测量见 [`VERIFICATION.md`](../development/VERIFICATION.md)。

## 状态定义

- `Ready`：范围足够明确，可以创建独立 Task。
- `Needs evidence`：方向已确认，但需要验证数据才能拆成实现任务。
- `Needs decision`：工作有必要，但关键产品选择仍需项目所有者确认。
- `Blocked`：存在明确外部阻塞。
- `Deferred`：已确认，但明确不在当前发布范围。

## 当前排序

| ID | 工作 | 状态 | 发布关系 | 提升为 Task 的条件 |
| --- | --- | --- | --- | --- |
| BL-005 | 按需语境增强引擎 | Deferred | 0.1.0 之后 | 完成隐私边界和发送内容的产品决策 |
| BL-006 | GLM-OCR 云端结构化识别 | Deferred | 0.1.0 之后 | 完成图片上传披露、Provider 契约和成本验证 |
| BL-007 | 多翻译 API 配置与窗口内手动切换 | Complete: TASK-005 | 0.1.0 之后的已确认增强 | 后续可另建 Task 做入口级默认或对比模式 |
| BL-008 | 设置侧栏与 API 配置编辑器重构 | Complete: TASK-005（detail: TASK-006） | 0.1.0 Alpha UX 修复 | None |
| BL-009 | 设置与浮层交互细节修正 | Complete: TASK-005（detail: TASK-007） | 0.1.0 Alpha UX 修复 | None |
| BL-010 | 设置窗口一体化与截图焦点修正 | Complete: TASK-005（detail: TASK-008） | 0.1.0 Alpha UX 修复 | None |
| BL-011 | 可靠取消截图框选 | Complete: TASK-005（detail: TASK-009） | 0.1.0 Alpha 真实缺陷 | None |
| BL-012 | API Base URL、完整 URL 与模型获取 | Complete: TASK-005（detail: TASK-010） | 0.1.0 Alpha 兼容性修复 | None |
| BL-013 | API 编辑器顶部聚焦边框完整显示 | Complete: TASK-005（detail: TASK-011） | 0.1.0 Alpha 视觉缺陷 | None |
| BL-014 | API 配置启用、排序与编辑器操作收敛 | [Blocked task: TASK-013](../tasks/TASK-013-api-profile-activation-and-editor-actions.md) | 0.1.0 Alpha 逻辑与 UX 修复 | 项目所有者确认拖拽动态中间态 |
| BL-015 | 母语/第二语言自动路由与结果卡语言控制 | Complete: [TASK-019](../tasks/TASK-019-configurable-language-routing.md) | 0.1.0 Alpha 语言能力增强 | None |

## 历史迁移条目

`BL-001` 已按项目所有者确认关闭并迁移为 `RV-001`；原先的 `BL-002`、`BL-003` 已迁移为 `RV-002`、`RV-003`。它们保留在 Git 历史和下方记录中，不能当作当前 Backlog 条目。

## 条目详情

### BL-001：跨应用划词翻译真实验证（已关闭）

- **目标**：证明 `⌃⌥D` 能在 Terminal、Safari、TextEdit 和至少一种 Electron 代码编辑器中取得真实选区，并在正确位置显示不抢焦点的卡片。
- **已具备**：标准 AX Range、Web Text Marker、边界降级、指针回退和自动化单元测试。
- **历史未决项**：这些是关闭前的验收记录；项目所有者已接受当前固定 App 的整体结果，后续具体回归另建 Task。
- **建议拆分**：先做兼容矩阵验证；只有出现可复现失败时，另建一个修复 Task。
- **相关文档**：`features/inline-translation.md`、`versions/0.1.0/ACCEPTANCE.md`。
- **已完成实现**：`TASK-015` 已完成 AX 深化与受保护的 Copy fallback；项目所有者在 Codex/微信真实场景中确认成功率显著提升并接受该目标完成。
- **关闭记录**：项目所有者确认当前固定 App 的整体成功率很高，剩余发布矩阵不再作为独立 Backlog 阻塞项；历史验证上下文保留在 [RV-001](../development/VERIFICATION.md)。

### BL-002：截图裁剪与权限持久化真实验证（已迁移）

当前内容已迁移到 [RV-002](../development/VERIFICATION.md)。

<!--

- **目标**：验证单屏、Retina、多屏、负坐标和混合缩放下，框选区域与 Vision 实际输入一致；验证冻结帧保留真实 Tooltip/悬停菜单并让播放中视频在框选阶段保持静止；复验真实 `Esc`、右键、无效区域和捕获失败路径；确认稳定签名 App 的 Screen Recording 授权行为。
- **已具备**：TASK-018 的触发前全显示器冻结、同帧框选/放大镜/裁剪、坐标与混合缩放合成单元测试、内存 Vision OCR、固定路径签名测试 App，以及浅色/深色/Reduce Motion Release 视觉证据。
- **仍需证据**：真实悬停弹层和播放中视频、物理多显示器与混合缩放裁剪对比、取消/失败路径、空 OCR、TCC 重启后的权限状态。
- **边界**：验证期间不得将用户截图写入仓库；如需临时诊断产物，必须显式启用并清理。
- **相关文档**：`features/screenshot-translation.md`、ADR-0005、0.1.0 验收清单。
-->

### BL-003：UI 延迟与内存预算测量（已迁移）

当前内容已迁移到 [RV-003](../development/VERIFICATION.md)。

<!--

- **目标**：以可重复方法测得入口到壳层、Rust delta 到可见 UI、空闲/翻译/Vision 峰值内存，并验证 TASK-018 全显示器冻结帧的内存峰值与会话结束回落。
- **验收预算**：UI 壳层 P95 约 150ms 内；Rust 回调到 Swift 可见 delta P95 低于 50ms；空闲低于 150MB、常规低于 300MB、Vision 期间低于 500MB、任何验收场景低于 1GB。
- **需要定义**：样本数量、短/长文本、冷/热启动、显示器环境、测量工具和结果保存位置。
- **结果用途**：决定 0.1.0 是否可接受；不为了通过指标而隐藏网络 TTFT。
- **相关文档**：`versions/0.1.0/ACCEPTANCE.md`。
-->

### BL-005：按需语境增强引擎

- **目标**：在用户触发翻译时，以有限、可解释、可关闭的语境提升术语与语气判断。
- **已接受方向**：ADR-0003 规定按需采集、有界、短时缓存，不持续截屏或监控窗口。
- **未进入 Task 原因**：发送字段、默认开关、清洗规则和质量基准仍需产品决策。
- **相关想法**：`IDEAS.md` 的 IDEA-001。

### BL-006：GLM-OCR 云端结构化识别

- **目标**：在表格、代码块或复杂布局截图中提供比 Vision 纯文本更好的结构恢复。
- **已接受方向**：ADR-0002 规划云端 GLM-OCR，Vision 保留为本地回退；ADR-0005 明确 0.1.0 不实现图片上传路径。
- **未进入 Task 原因**：需要明确隐私披露、成本/延迟阈值、图片生命周期和结构化数据契约。
- **相关想法**：`IDEAS.md` 的 IDEA-003。

### BL-007：多翻译 API 配置与窗口内手动切换

- **目标**：保存多个具名 OpenAI-compatible 端点，并在当前结果卡片中显式切换后使用同一源文本重跑翻译。
- **首期范围**：配置 ID、显示名称、Base URL、模型名和独立 Keychain 凭证；创建、编辑、测试、排序、删除、设为默认；卡片显示配置名并支持取消旧请求后重跑。
- **明确不做**：自动 fallback、静默路由、Provider 专属参数、按入口记忆默认值、持久化译文历史和图片重新 OCR。
- **迁移要求**：现有单配置字段和 `translation-api-key` 在首次启动时生成一个默认配置并迁移，重命名不得丢 Key，删除配置必须删除对应 Keychain 项。
- **相关想法**：`IDEAS.md` 的 IDEA-010。

### BL-014：API 配置启用、排序与编辑器操作收敛

- **目标**：统一编辑器内当前 Key 草稿的测试行为，以显式启用状态控制哪些 profile 可调用，并用直接拖拽替代菜单中的上下移动。
- **范围**：测试连接状态行、底部取消/保存、profile 启用迁移、默认配置不变量、结果卡过滤、三横杠拖拽排序及相关测试与真实 App 验收。
- **明确不做**：自动 fallback、后台健康检查、Provider 专属参数和多模型并行翻译。
- **当前 Task**：`TASK-013`。

### BL-015：母语/第二语言自动路由与结果卡语言控制

- **目标**：用全局母语和第二语言取代固定中英自动方向，在本机识别源语言，并让结果卡显示且可覆盖本次源/目标语言。
- **首期范围**：简体中文、English、日本語；设置语言子页面；新会话自动路由；结果卡第二行双下拉；通用模型与 Qwen-MT 一致参数；未知源语言降级。后续扩展 Français、Español、Deutsch、한국어 由 [TASK-022](../tasks/TASK-022-expanded-language-support.md) 管理。
- **明确不做**：繁体中文独立偏好、按 profile/入口偏好、额外识别服务、语言质量风格与已打开卡片随设置自动重译。
- **完成 Task**：[TASK-019](../tasks/TASK-019-configurable-language-routing.md)。

## 提升规则

将 Backlog 条目提升为 Task 时：

1. 复制 `tasks/TASK_TEMPLATE.md`，分配下一个连续编号。
2. 用本次开发对话的初始目标创建 Task，不必把整个 Backlog 条目原样搬过去；对话中项目所有者追加的内容继续更新同一个 Task。
3. 在本文件把状态改成 `Active task: TASK-xxx` 并链接施工单。
4. 在 `development/STATUS.md` 中设置同一个活动 Task。
5. 任务完成后根据剩余工作关闭、拆分或保留 Backlog 条目。
