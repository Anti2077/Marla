# 本机 GLM-OCR 七类合成表格评测

Date: 2026-09-08

Task: [TASK-045](../tasks/TASK-045-local-ollama-glm-ocr.md)

Status: 本机模型原始输出、受限表格解析、原生组件适配与完整宿主检查已验证；固定 App 的真实 Provider/App 验收仍未完成。

## 目的与素材边界

本轮测试覆盖账单、API 参数文档、套餐对比、中英库存、服务器属性、季度财报和培训排期七种常见表格场景。**所有图片均由合成数据生成，不是真实网站、业务系统或用户桌面的截图。** 金额、日期、主机名和命令仅为 fixture 内容；图片中的文字不构成执行指令。本轮没有读取账号、凭据或用户设置，也没有调用云端翻译服务。

W3C WAI 的 irregular headers 教程作为跨行、跨列表头的结构参考；具体表格文案、数值和图片由本项目生成。GLM-OCR 官方 Ollama 部署指南作为本机原生 `/api/generate` 请求的运行参考。本轮由主 Agent 选定这两份结构与运行参考；它们不是本机模型质量或速度的证据。

参考地址：

```text
https://www.w3.org/WAI/tutorials/tables/irregular/
https://github.com/zai-org/GLM-OCR/blob/main/examples/ollama-deploy/README.md
```

可复现工具位于 `scripts/ocr-table-eval/`：生成 fixture JSON、使用离线 AppKit 绘制 PNG、逐张请求已运行的本机 Ollama。合成图片和原始响应保存在 Git 忽略的 `artifacts/ocr-eval/task-045/`，不改变产品截图默认仅存内存的规则。

本报告的直接证据为该目录中的 `fixtures.json`、`results.json`、`prompt.txt`、各场景 `.png`、`.raw.md` 与 `.response.json`。`results.json` 记录图片 SHA-256，可用于核对同名文件是否仍是本轮输入。重新运行会覆盖该目录文件，因此复跑结果不能与本轮数字混用。

## 请求与测量方式

请求为 `POST http://127.0.0.1:11434/api/generate`，模型字段 `glm-ocr`，逐张发送原尺寸 PNG 的 base64，`stream: false`，`options.temperature: 0`，每张请求超时上限 120 秒。实际固定提示词由测试脚本从 Rust OCR 请求构造中读取，并单独保存为 `prompt.txt`：

```text
Read all visible text in reading order. Return only GitHub-Flavored Markdown. Use pipe tables for every table. Use headings, lists, and fenced code blocks when visible. Do not add commentary or HTML tags.
```

每场景仅一次请求，依次完成；耗时从提交请求前开始，到 HTTP 响应正文读取完毕为止，包含请求与本机排队等开销。没有预先卸载模型、控制模型驻留、记录每次加载状态或重复采样，因此不能把这些数值称为冷启动、热启动基准、平均性能保证或 p95。

七次均为 HTTP 200、非空 `response`，响应中的 `done` 均为 `false`，`done_reason` 均未给出有效值，未取得标准模型计时字段。收到正文说明本轮请求取得了 OCR 结果；**HTTP 成功、`done` 值、标签闭合和单元格数量均不能单独证明整张图识别完整。**

## 七场景结果

“单元格”按物理单元格计数，合并格只计一次，包含表头和空格。HTML 实际数量是评测脚本提取的 `th`/`td` 文本数量，不是 HTML5 合规性或正确坐标的判定。GFM 行数包含分隔行。内容核查基于合成 fixture 与原始正文；HTML 文本比较会折叠空白，因此必须另查格内换行。

| 场景 | 原始图片尺寸 | 耗时（秒） | 实际返回 | 预期 / 实际单元格与关键结果 |
| --- | --- | ---: | --- | --- |
| 账单 `invoice` | 954×620 | 13.756 | 1 张 HTML 表，5 行 | 20 / 20，所有格内文字与空格按序匹配；漏标题；表后正文前多出孤立 `<` |
| API 参数 `api` | 1104×620 | 6.572 | GFM 风格表，6 行 | 预期 20 格；`filter` 行含未转义管道符，按分隔符解析会变成 5 列，无法按正确四列表验收 |
| 套餐对比 `comparison` | 1114×620 | 8.533 | 1 张 HTML 表，5 行 | 20 / 20，空白折叠后文字按序匹配；`Chat` 与 `Email` 两行变为一个空格；漏标题 |
| 中英库存 `bilingual` | 1084×534 | 6.452 | GFM 表，5 行 | 预期 16 格，原始正文逐行保留四列和全部 16 格文字；标题、尾注保留 |
| 服务器属性 `keyvalue` | 1044×620 | 16.499 | 3 张重复 HTML 表，共 15 行 | 预期 10 格，实际 30 格；每一份均重复相同 10 格；漏标题 |
| 季度财报 `finance` | 1164×620 | 10.148 | 1 张 HTML 表，4 个起始 `tr` | 22 / 22；保留 1 个 `rowspan=2` 和 2 个 `colspan=2`，但第二表头缺起始 `tr`；漏标题 |
| 培训排期 `schedule` | 1154×620 | 10.256 | 1 张 HTML 表，5 行 | 18 / 18，文字按序匹配；正确输出两个 `rowspan=2`；漏标题；尾注包在大写 `<B>` 中 |

这七张中五张返回 HTML 表，另两张返回 GFM 风格表；指定 GFM 的提示词没有约束住所有格式。五个 HTML 场景均未返回图片顶部标题，两张 GFM 场景保留了标题。这是本组单次观测，不能推断所有 HTML 输出都会漏标题。

## 原始输出揭示的适配需求

### 普通表格、空格和表外正文

账单、套餐对比使用 `table class="table table-bordered"`，服务器属性使用 `table border="1"`，包含 `thead`、`tbody`、`tr`、`th`、`td`。这些外观属性不能代替表结构。账单保留四个空单元格和负数折扣，转换时不能删除空格后再向左压缩。标题缺失不能由归一化器从常识补写。

账单表后原文是 `</table><Payment due: ...`，尾注文字存在但多了 `<`。套餐尾注正常保留。服务器属性第一次表后有尾注，随后又重复两个完整表格。不能只截取第一对 `<table>`，也不能把所有重复表格自动删除：本轮是生成重复，其他页面也可能合法包含相同表。

### 合并格与容错解析

财报的 `Region` 横跨两行，`2025`、`2026` 各横跨两列。返回保留三项 span 属性与全部 22 格文字，但第二行四个 `th` 前缺少 `<tr>`，之后仍有 `</tr>`，尾注后还生成了两行 `---`。这要求采用明确的 HTML 表格解析与校验规则，不能只按成对行标签做字符串切分。解析修复之后仍须核查两级表头与 North/South/Total 数字对应，不能只核对格数。

排期的 `Monday`、`Tuesday` 各使用 `<td rowspan="2">`，其余单元格按顺序输出，尾注使用大写 `<B>`。大小写不应影响安全内联标签识别。GFM pipe table 不能直接表达这些跨行/跨列关系；若为了输出 GFM 而删除 span，将改变语义。

### GFM 自身也可能有歧义

API 参数的关键输出为：

```text
| filter | string | A&B | Values: ready | pending |
```

图片实际是四列，末格的 `ready | pending` 是可见内容。模型未转义该管道符，不能把“返回了 pipe table”当作有效四列表。`enabled` 的两行文字通过 `<br>` 保留，范围表达式 `1 < limit < 500`、`${ITEM_ID}` 和 `/v1/items` 也在正文中。后续处理必须保护这些字符，不能把比较符误当标签，或用随意合并溢出列的方式猜测真实单元格归属。

API 尾注在 JSON 中记录 `footer_present=false`，但人工核对原始正文发现 `Example: curl --fail /v1/items?limit=25` 的可见文字完整存在，只是命令新增 inline-code 反引号。该布尔值是精确子串检测结果，**不是尾注遗漏**。中英库存的中文、斜线、数量 `0`、`A&B` 和更新时间均保留。

## 已完成的针对性适配

- **普通表格**：账单、套餐对比和服务器属性的 `table/thead/tbody/tr/th/td` 按实际顺序解析；保留空格、金额与表后段落，规范成 GFM。服务器属性仍保留三份表；没有无依据去重。
- **合并表格**：财报第二表头缺省的 row start 可按明确规则恢复，生成 5 行、22 个物理格及原有三项 span；排期保留 5 行、18 个物理格与两项 rowspan。规范成 XML-compatible 的惰性 HTML 表格子集，原生 `NSTextTableBlock` 直接使用跨度，不将合并关系压成 GFM。
- **内联与语法保护**：实体解码并重新转义、大小写标签、混合 th/td、code/bold/emphasis/br、表格 caption、表外粗斜体兼容；真正的 fenced/inline/indented code 不被当表格。API 样本未转义 pipe 的格归属不明确，拒绝并沿用可见 Vision 回退；不拼接溢出列冒充修复。
- **验证边界**：最多 256 KiB、128 行、32 列；正跨度不得越界或重叠，完整网格不得留下无来源空洞。未知/危险表格标签或属性、嵌套表与截断结构被拒绝。它是受限 OCR 表格方言，不是完整 HTML5 实现。
- **显示与复制**：源文/译文使用同一个原生可选文本组件。合并格的 canonical copy 仍保留 HTML；plain-text projection 生成 TSV，每个合并格正文只出现一次。HTML 投影不加载资源、不执行脚本，也不会成为原位截图几何。
- **翻译边界**：通用翻译提示词增加保持 HTML 标签、行格顺序和 span 值的要求；Qwen-MT 沿用其原生协议。本轮没有真实账号翻译，没有声称逐单元格 ID 或译前/译后结构同构校验已实现。

原始与规范合成样本已加入 `rust/marla-core/tests/fixtures/ocr-tables/`；Rust regression 对比实际规范输出与这些文件，Swift regression 再投影同一规范文件。7 个模型结果中 6 个被转换或保留成可展示结构，API 的歧义表被拒绝；这不是“6/7 OCR 完全正确”。

## 本轮验证状态

- Rust formatting、严格 Clippy 与 **52 项 Rust 测试通过**。覆盖已观测样本，以及补充的带引号属性、entity、混合表头、caption、代码保护、危险元素和越界/不完整结构。
- **8 项新增 Swift 表格测试通过**：财报/排期的行列跨度、全部格文字、内联样式、代码字面量、plain projection、invalid structure 和 380/760pt 布局。
- 历史记录：受限环境的早期定向执行曾有 2 项剪贴板测试失败、3 处断言得到 nil；2026-09-09 完整宿主执行已覆盖 249 项 Swift 且 0 失败，早期结果不再代表最新状态。
- 历史记录：2026-09-08 受限环境曾在 `FloatingPanel.swift:342` 的 `NSScreen.screens.first!` 中止，并报告沙箱下 `nice(5)` 不允许。2026-09-09 后续完整宿主 `./scripts/check.sh` 已通过，窗口与剪贴板测试成功；早期受限失败保留为历史记录，不再作为最新结果。
- 固定 Release App 已重建并通过 `com.marla.app`、`0.0.0`、macOS 14+、arm64、稳定签名和 designated requirement 校验。结构、工程 plist 与 diff 检查通过。
- 曾申请下载成熟 HTML5 parser，但自动审批拒绝向 Cargo 缓存安装新依赖。依赖修改和 lockfile 已恢复，最终无新增第三方依赖，也没有绕过审批。

## 原生组件视觉证据

合成财务、排期和账单通过实际生产 `MarkdownResultDocument` / TextKit 组件，生成 380/760pt、浅/深色快照，位于 `artifacts/ocr-eval/task-045/{finance,schedule,invoice}-{light,dark}-{380,760}.png`。这些是原生组件快照，**不是固定 App 的系统玻璃窗口或真实 Provider 译文截图**。

已目视检查合并列财报与合并行排期：年/季度标题、行组和表后正文可见；380pt 下未发生行列覆盖。尾注受模型额外 `---` 影响成为 Markdown heading 的情况忠实保留，没有伪称格式归一能恢复原图全部排版。

针对已查看组件的五维复审：Philosophy 8、Hierarchy 8、Craft 7、Functionality 7、Originality 7。分数只适用于该原生表格组件与合成布局；剪贴板、固定 App 窗口、辅助技术、真实翻译和系统材质尚需补验，不据此关闭整个 Task。

## 剩余问题与后续顺序

1. **完成 owner acceptance**：在固定 App 中验证实际 OCR→翻译→原生合并表格、取消和回退，并复查选择复制、深浅色窗口与真实 Provider 结构保真。
2. **OCR 内容完整性**：本组五个 HTML 场景漏标题，配置表重复三次，套餐换行被压平，财报多出装饰线。解析不能补回未输出内容；后续用人工期望覆盖这些缺陷，验证具体重试或 prompt 方案，而不是立即加入自动重试。
3. **译文结构可靠性**：当前要求翻译模型保留结构，后续若实际 Provider 会改动跨度/格次序，应评估保留本地表格结构、按稳定 cell ID 翻译文字；不能把这项尚未实现的保证写进当前合同。
4. **扩充难例**：真实网站截图片段、无边框密集表、低清扫描、旋转/长表、公式、图标/颜色和嵌套表仍未验证；7 张合成图片不能代表普遍准确率。

冷启动、峰值内存、长期模型驻留与官方 HTML5 全量兼容都不在本轮通过项内。Task 状态与最终验收由 TASK-045/STATUS 跟踪；实现已在 `Anti2077/task-045-local-ollama-glm-ocr` 的 `ee8d526` 提交，文档修复另行提交，不合并到 `main` 或推送。
