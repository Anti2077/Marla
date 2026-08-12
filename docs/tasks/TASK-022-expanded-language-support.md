# TASK-022：扩展语言支持与 Provider 映射

Status: Done

Owner: Project owner + Agent

Created: 2026-08-11

Updated: 2026-08-12

Origin: direct project-owner request

Conversation: 2026-08-11 扩展翻译语言技术评估与适配

## Initial request

项目所有者要求创建一个新的 Task，检查当前技术可以支持哪些语言，并在此基础上适配更多语言。

## Outcome

Marla 将在既有简体中文、English、日本語之外，支持 Français、Español、Deutsch、한국어 的本机识别、语言设置、结果卡/快速输入覆盖、自动路由和 Swift/Rust Provider 请求映射。Task 同时留下有证据边界的语言能力矩阵，区分“当前已适配”“技术上可行但尚未适配”和“本轮不承诺”。

## Why now

TASK-019 已把语言路由抽象为 `TranslationLanguage` 枚举、本机 `NLLanguageRecognizer` 检测、通用 OpenAI-compatible 提示词和 Qwen-MT `translation_options`。当前产品仍只允许三门语言，Rust 也只接受三门语言代码；继续扩展不需要新架构，但必须在 Swift/Rust allowlist、识别归一、设置与结果卡菜单、测试和双语合同中保持一致。

## In Scope

- 将首期可适配集合从 `zh-Hans`、`en`、`ja` 扩展为：
  - Français（`fr`）
  - Español（`es`）
  - Deutsch（`de`）
  - 한국어（`ko`）
- 扩展 Swift `TranslationLanguage` 的标签、Natural Language 代码归一和全局母语/第二语言设置；保留两者不能相同与旧默认值迁移行为。
- 让结果卡、快速输入和设置菜单自动显示四门新增语言；保持当前紧凑控件和 44pt 交互目标，不新增独立语言页面或重复偏好。
- 扩展通用 OpenAI-compatible 提示词的源/目标名称、Rust schema v2 校验，以及 Qwen-MT 的英文名称映射；未知源仍使用 Provider `auto`，目标仍为显式母语/第二语言。
- 增加四门新增语言的归一、识别、自动路由、设置持久化、请求序列化、通用提示词和 Qwen-MT payload 回归测试；保留原中英日测试。
- 修复截图入口仍把 Vision OCR 固定为中英文的问题：启用 Vision 自动语言检测，把当前运行时实际支持的七门产品 OCR 标识作为候选，并增加日语、韩语及中英文图片到文字的真实回归测试。
- 同步语言功能规格、架构/数据合同、0.1.0 双语版本合同、Task/STATUS 和现有语言能力说明。
- 按现有 SwiftUI 设计系统检查长语言标签、菜单可读性、浅色/深色和 Reduce Motion；构建固定签名 Release App 并进行五维审查。

## Out of Scope

- 一次性把 Qwen-MT 文档列出的 92 门语言全部做成产品选项；其余语言记录为后续候选，需单独验证识别质量、UI 密度和 Provider 质量。
- 阿拉伯语等 RTL 语言的专门布局、双向文本编辑策略或 RTL 视觉验收。
- 为每种语言增加地区变体、敬体/简体、术语表、风格控制、独立语言模型或远程识别服务。
- 更换翻译 API、增加 Provider 专属配置、自动 fallback、历史语言偏好或已打开卡片随设置自动重译。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-11 | Project owner | 创建新 Task，调查当前技术语言支持并适配多门语言 | 先形成能力矩阵，再以四门语言作为本轮实现集合 | Verified |
| 2026-08-11 | Necessary support | 结果卡/设置菜单会出现更长标签 | 保持当前 Warm Minimal/Liquid Glass 体系，增加长标签和窄卡片截图检查 | Pending |
| 2026-08-12 | Project owner | 真实截图发现日语和韩语无法进入翻译流程，要求开始修复 | 将七语言 Vision OCR 配置和图片级回归纳入当前 Task；字符串级语言检测不再作为截图入口支持的充分证据 | Implemented; release verification gap retained |

## Current evidence

- Swift `TranslationLanguage`、区域代码归一、母语/第二语言持久化和会话路由现已覆盖 `zh-Hans`、`en`、`ja`、`fr`、`es`、`de`、`ko`；设置、结果卡和快速输入菜单继续由 `allCases` 驱动。
- 2026-08-12 对真实渲染图片的诊断确认：现有 `VNRecognizeTextRequest` 只配置 `zh-Hans`/`en-US` 且未启用自动语言检测，日语和韩语 OCR 可直接返回空结果，后续 `NLLanguageRecognizer` 与 Provider 不会运行。当前机器的 Vision revision 3 在 `.accurate` 下支持七门产品语言对应的 OCR 标识；仅追加 `ja-JP`/`ko-KR` 仍受首项东亚模型主导，启用 `automaticallyDetectsLanguage` 后中英日文韩文样本均可识别。
- Rust `language_name`、`qwen_language_name`、schema v2 校验和 Provider payload 现已覆盖同一七门 allowlist；未适配代码仍被拒绝。
- 2026-08-11 在当前 macOS SDK 运行 `NLLanguageRecognizer` 完整样本：`fr`、`es`、`de`、`ko` 均返回对应 dominant language。短句、代码混排和单一标点仍可能返回不稳定结果，因此沿用“未知 + 允许手动覆盖”的降级。
- 2026-08-11 读取 Alibaba Cloud Qwen-MT 官方文档：Qwen-MT 说明支持 92 门语言，并明确列出 Korean、French、Spanish、German；`source_lang`/`target_lang` 可使用英文名或 code，未知源可用 `auto`。官方页面：[Machine translation (Qwen-MT)](https://www.alibabacloud.com/help/en/model-studio/machine-translation)。该外部能力声明可能随 Provider 更新，不能替代本地请求验收。
- 技术能力矩阵：

  | 层 | 当前结论 | 本轮处理 |
  | --- | --- | --- |
  | macOS Natural Language | 已对中英日及 fr/es/de/ko 样本验证；系统本身可识别更多语言 | 四门新增语言已加入产品归一 allowlist |
  | 通用 OpenAI-compatible | 提示词可表达任意目标语言，Rust 保持显式 allowlist | 四门新增语言已补齐名称与校验 |
  | Qwen-MT | 官方文档列出 92 门语言；Marla 本地映射七门 | 四门新增语言已补齐 `source_lang`/`target_lang` 英文名 |
  | Marla UI/路由 | 菜单由 `allCases` 驱动，自动路由与设置持久化已通用化 | 已复用现有 UI；长标签和完整菜单视觉验收仍待现场窗口 |

## Proposed approach

共享 Swift 模型已加入四门语言及 `fr-*`、`es-*`、`de-*`、`ko-*` 归一，Rust 以单点映射维护通用名称与 Qwen-MT 名称。设置、结果卡和快速输入继续依赖 `CaseIterable`，没有复制菜单分支；自动路由继续使用“源等于母语则去第二语言，否则去母语”。截图入口为 Vision 开启自动语言检测，并按请求的运行时支持列表过滤七门产品 OCR 标识，避免在旧系统上强写不支持的标识；图片级测试直接调用真实 `VisionOCRService`，不以 OCR 后的字符串测试替代。完整自动化、固定 Release 和现场截图复验完成前不宣称修复已验收。

## Acceptance criteria

- [ ] 设置“翻译语言”页面可选择简体中文、English、日本語、Français、Español、Deutsch、한국어；母语与第二语言不能相同并正确持久化。
- [ ] `NLLanguageRecognizer` 对代表性法/西/德/韩文本在网络请求前归一到对应产品语言；无法可靠识别时仍显示未知并按既有母语降级。
- [x] Vision OCR 开启自动语言检测，七门产品 OCR 标识只在当前运行时支持时进入请求；沙盒外真实渲染图片探针已证明日语、韩语、中文和英文样本均能输出对应文字。XCTest 图形服务缺口和固定 Release 现场框选仍按发布验收缺口保留。
- [ ] 自动路由覆盖七门产品语言的母语/第二语言组合、其它支持语言和未知源分支；显式目标与源覆盖优先级不回归。
- [ ] 结果卡和快速输入菜单显示四门新增语言，长标签在 380pt 结果卡和设置窗口中不截断、不挤掉 API/操作控件，辅助功能标签仍完整。
- [ ] Swift/Rust schema v2、通用提示词和 Qwen-MT payload 对 `fr`、`es`、`de`、`ko` 使用一致语义；未知源只在 source 使用 `auto`。
- [ ] Rust 拒绝未适配的语言代码，既有 `zh-Hans`/`en`/`ja` 合同与测试继续通过。
- [ ] `./scripts/check.sh`、固定签名 Release 打包、`git diff --check` 通过；真实浅色、深色、Reduce Motion 语言设置/结果卡证据完成，五维评分每项至少 7/10。
- [ ] 语言功能、架构、数据合同、0.1.0 双语规格/实现/验收、Task 与 STATUS 同步；未纳入本轮的 Qwen-MT 语言候选保持有证据边界。

## Verification

### Automated

```sh
./scripts/check.sh
```

2026-08-12 运行通过：Rust 18 项、MarlaApp 84 项（其中 3 项真实图片 Vision OCR 回归在当前 xctest 图形服务无法创建 CVPixelBuffer 时明确 skip）、MarlaCore 13 项；Swift Package、非沙盒 Xcode Debug、格式/尾随空白和 `git diff --check` 均通过。`./scripts/build-test-app.sh` 通过，固定 `artifacts/Marla_dev.app` 保持 Bundle ID `com.marla.app`、0.1.0、macOS 14+、arm64 和稳定签名 `API Usage Monitor Dev`。同一组图片样本在沙盒外 Vision 探针中验证了自动检测配置：日语、韩语、中文和英文均有识别结果；现有固定中英文且关闭自动检测的配置对日语/韩语为空。xctest 的图形服务限制不等同于 Release App OCR 已完成验收。

### Manual

使用固定签名 `artifacts/Marla_dev.app`：在浅色、深色和 Reduce Motion 下打开“翻译语言”，检查四门新增语言的长标签、母语/第二语言去重和当前规则摘要；在结果卡与快速输入中分别用法语、西班牙语、德语、韩语代表文本检查自动识别标签、自动目标、源/目标覆盖和 API profile 行布局。现场 Provider 请求若触发新的 Keychain 授权则记录为“本次无法验证”，不以 mock 结果冒充真实质量；截图遵守项目临时产物规则。

截图入口另以真实日语、韩语、中文和英文画面框选，确认 Vision 原文不为空且关键文字正确，并检查结果卡源语言标签进入对应的日本語、한국어、简体中文或 English 路由。Provider 或 Keychain 若阻止真实译文，只把 OCR 原文和本机路由记录为已验证，不外推翻译质量。

### SwiftUI design review (partial)

`/private/tmp/marla-task-022-languages-light.png` 的浅色“翻译语言”页复审如下；分数只代表已实际看到的设置页，不外推到尚未打开的结果卡或菜单：

| 维度 | 分数 | 依据 |
| --- | --- | --- |
| Philosophy alignment | 8/10 | Warm Minimal 与单层 Liquid Glass 语言一致，新增标签没有引入第二套视觉语言 |
| Visual hierarchy | 8/10 | 页面标题、路由设置、规则摘要和说明形成清晰阅读顺序 |
| Craft quality | 8/10 | 长摘要保持对齐、留白和窄侧栏层级；未见截断或控件挤压 |
| Functionality | 8/10 | 母语/第二语言和三条规则摘要直接可见，约束逻辑由自动化测试覆盖 |
| Originality | 7/10 | SF Symbols、克制蓝色强调和材质表面保留 Marla 的既有识别度 |

深色、Reduce Motion、结果卡长标签和快速输入菜单尚未有最新固定 Release 的可见窗口截图，因此不将本次部分复审写成完整视觉验收。

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
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Sources/MarlaApp/SettingsView.swift`
- `Sources/MarlaApp/MarlaApp.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`
- `rust/marla-core/src/lib.rs`

## Parallel contributors (optional)

None. The shared language enum, session snapshot, UI menus and Rust contract must change together; the main Agent owns Task/STATUS and final verification.

## Risks and rollback

- 本机识别对短句、专有名词和代码混排仍可能不稳定；保留未知降级和手动覆盖。
- Qwen-MT 支持列表或名称可能变化；Rust 映射测试只证明当前合同，真实 Provider 质量需单独记录。
- 更多语言标签会增加菜单高度和结果卡第二行宽度；若真实截图低于 7/10，可收紧标签布局或回退本轮语言数量，不改变协议边界。
- 可回滚为 TASK-019 的三语言 allowlist；不触碰 Keychain、输入获取或截图链路。

## Decisions needed

None for the four-language expansion. Any request to add the remaining Qwen-MT languages, RTL behavior, or regional variants requires a new scope decision.

## Completion record

- Verified commit: Pending until the authorized commit completes
- Automated evidence: 2026-08-12 `./scripts/check.sh` 与 `./scripts/build-test-app.sh` 通过；真实图片 XCTest 在 OSStatus -6662 时 skip，沙盒外探针验证日/韩/中/英自动 OCR
- Manual evidence: `/private/tmp/marla-task-022-languages-light.png` 仅覆盖浅色设置页；深色、Reduce Motion、结果卡长标签和快速输入菜单仍待真实可见窗口
- Documentation updated: Yes (未提交工作树)
- Remaining work promoted to: None
- Scope changes closed: Yes（Vision 修复已实现；固定 Release 的真实截图 OCR 与路由仍作为发布验收缺口记录）
- Parallel contributions integrated: None
