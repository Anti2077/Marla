# TASK-019：可配置语言路由与翻译窗口语言控制

Status: Done

Implementation: Complete

Owner: Project owner + Agent

Created: 2026-08-10

Updated: 2026-08-10

Origin: IDEA-012 / direct project-owner request

Conversation: 2026-08-10 设置翻译语言与结果卡双语言下拉

## Initial request

项目所有者要求创建分支并开发 IDEA-012：先在设置中新增“翻译语言”子页面，配置母语和第二语言；再修改翻译结果窗口，保留顶部 API 配置选择并移除顶部语言选择，在第二行增加源语言和目标语言两个下拉菜单。源语言默认显示例如“自动识别：English”，并允许用户下拉覆盖；当自动识别到 English 等非母语时，目标语言按 IDEA-012 路由到母语。

## Outcome

用户可以全局设置互不相同的母语和第二语言。每次新翻译在本机识别源语言并在结果卡第二行显示实际路由，用户可覆盖源语言或目标语言并仅用已取得的原文重新翻译；简体中文、English 和日本語在设置、识别、UI、通用模型提示词与 Qwen-MT 参数中使用一致语义。

## Why now

当前“中文译 English、非中文译简体中文”的固定模型侧自动规则无法服务日语或不同母语用户，也无法在发起请求前向结果卡解释本次源/目标语言。项目所有者已明确把 IDEA-012 选为当前开发工作，并给出设置位置与结果卡布局。

## In Scope

- 新增设置侧栏“翻译语言”页面，持久化母语和第二语言；首批语言为 `zh-Hans`、`en`、`ja`，两者不得相同，默认分别为简体中文与 English。
- 新翻译使用 macOS `NaturalLanguage` 在本机识别源语言；中文语言代码归一到首期的简体中文产品选项，日文假名与系统识别结果支持日本語，无法可靠判断时显示未知并把自动目标降级为母语。
- 自动路由固定为“源语言等于母语时译到第二语言，否则译到母语”；设置变化只影响之后的新翻译，不静默重译已经打开的卡片。
- 结果卡顶部保留 API profile 选择，移除原有目标语言胶囊；在第二行新增左侧源语言和右侧目标语言下拉，显示自动识别结果与自动路由结果。
- 源语言下拉允许在自动识别与三个首期语言间覆盖；覆盖后重新翻译。目标语言下拉允许恢复自动路由或显式选择首期语言，显式选择优先于自动规则。
- 当源语言被覆盖且目标仍为自动路由时重新计算目标；当目标已经显式覆盖时保留用户选择。
- 快速输入提交前的旧“中文 ↔ English”固定说明必须同步到相同的源/目标策略，避免保留与新设置冲突的入口行为。
- Swift/Rust JSON 请求合同携带本次已解析的源/目标语言。Rust 为通用 OpenAI-compatible 模型构造明确提示词，为 Qwen-MT 发送一致的 `source_lang` / `target_lang`；日语映射为 `ja`/Japanese。
- 增加中英日组合、未知源、设置持久化、不变量、源/目标覆盖、Qwen-MT 与通用提示词测试，并同步双语版本规格、实现、验收、数据合同、架构、IDEAS/BACKLOG 与 STATUS。
- 构建固定签名 Release App，采集真实浅色、深色和 Reduce Motion 的设置与结果卡截图，执行五维 SwiftUI 设计审查且每项至少 7/10。
- 按项目所有者真实试用结论，完整移除 IDEA-002 单行原位译文实验和另一个表现不理想的 Force Touch 实验：删除设置、持久化状态、运行路径、专用 UI/面板逻辑、自动化夹具与专用测试；划词翻译始终使用既有附近结果卡和键盘快捷键。

## Out of Scope

- 繁体中文作为独立母语/第二语言选项；首期只把系统识别到的中文家族归一为简体中文产品选项。
- 下载、捆绑或常驻新的语言识别模型，以及把原文发送到额外的语言识别服务。
- 按 API profile、入口、应用或网站保存独立语言偏好；自动 fallback、多模型并行或持久化最近手动选择。
- 日语敬体/简体、姓名顺序、术语表和质量风格控制。
- 设置变化后自动重译已经打开的卡片。
- 扩大 0.1.0 的应用界面国际化范围；界面仍使用简体中文。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-10 | Project owner | 提升 IDEA-012，先做设置语言子页面，再做结果卡第二行双下拉 | 创建 TASK-019；增加设置、路由、请求合同、UI 与真实截图验收 | Implemented |
| 2026-08-10 | Necessary support | 同步快速输入的旧固定中英说明，并让 Rust Provider 接收同一解析结果 | 防止入口间语义冲突；增加 Swift/Rust 合同与回归测试 | Implemented |
| 2026-08-10 | Visual verification | 修正 macOS Menu 把复合 label 压平后只显示“源语言/目标语言”的真实 Release 缺陷，并让截图夹具跳过 Keychain 与全局快捷键系统集成 | 重新构建并采集最终浅色、深色、Reduce Motion 与快速输入证据 | Complete |
| 2026-08-10 | Project owner | 真实试用后删除 IDEA-002 单行原位译文与 Force Touch 两个实验功能 | 重新激活 TASK-019；删除两项实验的代码、设置、测试与当前产品文档，划词固定回到附近结果卡；重跑完整检查、固定 App 和设置真实截图五维复审 | Complete |

## Current evidence

- 实现前 `MarlaSettingsStore.defaultTarget` 只持久化一个 automatic/explicit 目标，没有母语、第二语言或源语言设置。
- 实现前结果卡顶部把 API profile 与“自动/简体中文/English”目标菜单放在同一行；`CardSession` 不保存解析后的源语言。
- 实现前 JSON schema v1 只携带目标策略。Rust 通用提示词保留固定中英规则；Qwen-MT 始终发送 `source_lang: auto`，并用字符范围决定自动目标。
- 2026-08-10 本机 `NLLanguageRecognizer` 样本能识别常见英文、中文、日文假名和日文汉字词，但短文本置信度低，且 `你好` 返回 `zh-Hant`、`OK` 与代码样本可能返回其它拉丁语言。因此首期不能用单一置信度阈值拒绝所有短句；需要把中文家族归一、保留未知降级，并允许用户覆盖。
- 当前工作区在创建分支前干净，本地 `main` 比 `origin/main` 领先 2 个既有提交；开发分支从该本地状态创建。
- Swift 设置持久化、路由器、会话快照、源/目标覆盖和本地 `NLLanguageRecognizer` 已实现；Rust JSON schema v2、通用提示词和 Qwen-MT `zh-Hans`/`en`/`ja` 映射使用同一显式目标语义。
- `./scripts/check.sh` 通过 17 项 Rust 和 87 项 Swift 测试及 Swift/Xcode Debug 构建；固定 Release App 通过 Bundle ID、版本、最低系统、arm64、稳定签名和 designated requirement 校验。
- 固定 Release 的设置、结果卡和快速输入浅色/深色/Reduce Motion 证据位于 `artifacts/ui-review/task-019/`；五维评分为 8/8/8/8/7。当前 Keychain 会对新的验收进程弹出系统授权，因此本轮没有把现场日语 Qwen 请求伪装成已验证，Provider `ja` 映射由 mock payload 测试覆盖。
- 最终移除阶段删除了两个实验设置字段与 UserDefaults 读取、原位专用 View、布局/转换/面板分支、运行时选择路径、两个 UI 自动化场景及 6 项专用测试；仓库源码/测试引用扫描为空，划词现在无条件调用完整附近结果卡。
- 移除后的 `./scripts/check.sh` 通过 17 项 Rust 和 81 项 Swift 测试及 Swift/Xcode Debug、格式、空白与 diff 检查；固定签名 Release 再次通过全部产物验证。最终“通用”页浅色/深色截图位于 `artifacts/ui-review/task-019-removal/`，确认实验区消失，五维复审为 8/8/8/9/7。

## Proposed approach

在 Swift 模型层建立有限的三语言产品枚举、源语言选择策略和纯路由器；App 层用 `NLLanguageRecognizer` 只处理当前源文本并把结果写进 `CardSession`。每次请求在 Swift 中解析出可展示的源语言与明确目标语言，再通过新版 JSON schema 交给 Rust。未知源语言仍由 Provider 自动识别源语言，但目标明确为母语。UI 延续当前 Functional/Warm Minimal 视觉体系：第一行只承担入口、profile、固定与关闭，第二行用两个紧凑的边框菜单和方向箭头解释语言流向，不增加装饰性卡片。

## Acceptance criteria

- [x] 设置侧栏存在“翻译语言”子页面，母语/第二语言支持简体中文、English、日本語，不能选成相同值并正确持久化。
- [x] 默认母语为简体中文、第二语言为 English；旧用户无需迁移操作即可得到与原固定规则相容的默认值。
- [x] 常见中/英/日文本在网络请求前得到本机识别结果；无法判断时 UI 明确显示未知且自动目标为母语，不把不确定性伪装成已确认语言。
- [x] 自动路由覆盖所有三语言母语/第二语言组合，以及非母语/未知源到母语的分支。
- [x] 结果卡顶部不再显示语言菜单；第二行左源右目标，能够显示例如“自动识别：English → 简体中文”。
- [x] 源语言覆盖会取消旧请求并复用原文重新翻译；自动目标随源覆盖重新路由，显式目标覆盖保持最高优先级。
- [x] 目标语言覆盖和恢复自动路由不重新执行 Accessibility、Copy fallback 或 Vision OCR。
- [x] 快速输入不再显示固定“中文 ↔ English”规则，提交时使用同一语言设置和覆盖策略。
- [x] 通用模型提示词和 Qwen-MT 请求对 `zh-Hans`、`en`、`ja` 使用一致源/目标语义，并继续保留换行、标点、专有名词、代码标识符和终端参数要求。
- [x] 语言识别不持久化原文、检测结果或置信度，不引入额外网络请求或常驻模型。
- [x] `./scripts/check.sh`、固定签名 Release 打包和 `git diff --check` 通过。
- [x] 固定 Release App 的设置语言页和结果卡完成浅色、深色、Reduce Motion 真实截图审查，五个维度均至少 7/10。
- [x] 双语规格、实现、验收、数据合同、架构、Task 与 STATUS 和验证事实同步。
- [x] 设置中不再出现“实验功能”区、Force Touch 或单行原位译文开关，两项旧 UserDefaults 状态不再参与运行行为。
- [x] 划词翻译无条件使用完整附近结果卡；代码中不存在原位译文专用 View、布局计算器、面板样式、状态转换或 UI 自动化场景。
- [x] 当前产品规格、架构、Backlog/Ideas、TASK-017 与 STATUS 明确记录两项实验因试用表现不理想而退出当前产品计划。
- [x] 移除后 `./scripts/check.sh`、固定签名 Release 打包和真实设置截图五维复审通过。

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

使用固定签名 `artifacts/Marla_dev.app`：在设置中验证全部合法母语/第二语言组合与重复项禁用；用 `Hello`、中文句子、日文假名/汉字混排和无语言内容分别从快速输入与至少一个既有入口发起翻译；观察第二行源/目标标签，覆盖源语言、覆盖/恢复自动目标并确认只重跑翻译。采集设置语言页和结果卡的浅色、深色、Reduce Motion 证据到 `artifacts/ui-review/task-019/`。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/UI_SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/DATA_CONTRACTS.md`
- `docs/features/language-routing.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `Sources/MarlaCore/TranslationModels.swift`
- `Sources/MarlaCore/RustCoreBridge.swift`
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Sources/MarlaApp/SettingsView.swift`
- `Sources/MarlaApp/MarlaApp.swift`
- `Sources/MarlaApp/MarlaPreviews.swift`
- `rust/marla-core/src/lib.rs`
- `Tests/MarlaCoreTests/MarlaCoreTests.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors (optional)

None. The language model, session state, UI controls and shared request contract are tightly coupled; Task/STATUS and bilingual contract ownership remain with the main Agent.

## Risks and rollback

- 系统语言识别对极短、纯汉字和代码混排输入不稳定；UI 必须允许覆盖，未知结果必须使用可解释降级。
- JSON schema 与 Rust Provider 映射不一致会导致请求被拒绝或翻错方向；Swift/Rust 必须在同一变更中更新并以序列化和 Provider payload 测试锁定。
- 第二行会压缩结果卡可用高度；保持紧凑控件并用真实截图检查 380pt 现有宽度、长语言标签和辅助功能。
- 可通过移除语言页面和第二行控件、恢复 schema v1 固定自动目标来回滚；该回滚不触碰 API profile、Keychain 凭据或输入获取链。

## Decisions needed

None. 对尚未可靠识别的文本，本 Task 采用“显示未知、自动目标为母语、Provider 自动识别源语言、允许用户覆盖”的可逆降级；若项目所有者在后续真实试用中选择其它策略，作为新的授权工作记录。

## Completion record

- Verified commit: 当前分支未提交；项目所有者只要求创建分支并开发，未要求 commit/push
- Automated evidence: 最终 `./scripts/check.sh` 通过 17 Rust、81 Swift、Swift/Xcode Debug、格式、空白与 `git diff --check`；移除前语言路由版本曾通过 87 Swift，其中 6 项原位实验专用测试随功能删除
- Manual evidence: 语言设置、结果卡、快速输入证据位于 `artifacts/ui-review/task-019/`；移除实验区后的“通用”页浅色/深色证据位于 `artifacts/ui-review/task-019-removal/`，五维评分 8/8/8/9/7
- Documentation updated: SPEC/UI_SPEC/IMPLEMENTATION/ACCEPTANCE/ARCHITECTURE/DATA_CONTRACTS/feature/IDEAS/BACKLOG/Task/STATUS 已同步
- Remaining work promoted to: None；现场日语 Provider 质量不作为本 Task 的伪完成证据
- Scope changes closed: Yes
- Parallel contributions integrated: None
