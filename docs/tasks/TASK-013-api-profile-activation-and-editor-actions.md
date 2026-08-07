# TASK-013：API 配置启用、排序与编辑器操作收敛

Status: Blocked

Owner: Project owner + Agent

Created: 2026-08-07

Updated: 2026-08-07

Origin: direct request / defect

Conversation: 2026-08-07，API 配置逻辑与交互细节继续修正

## Initial request

项目所有者要求先修复 API 编辑器测试连接没有使用当前 Key 草稿的逻辑问题，并收敛编辑器与配置列表交互：编辑器底部只保留取消和保存，测试连接移到模型附近并同行显示结果；配置列表用开关控制配置是否可调用，菜单只保留设为默认和删除，最右侧以三横杠手柄直接拖拽排序。

## Outcome

用户可以明确启用或停用每个 API 配置，翻译窗口只提供已启用的配置；API 编辑器使用当前尚未保存的 Key 测试连接，并用紧凑、可预期的操作层级完成测试、取消和保存。

## Why now

当前模型获取会使用 Key 草稿，但测试连接只读取 Keychain，造成同一编辑器内行为不一致；配置列表的圆形勾选与完整性状态语义混淆，排序操作也同时占用菜单，增加了不必要的交互层级。

## In Scope

- 测试连接优先使用当前非空 API Key 草稿，草稿为空时回退对应 profile 的 Keychain。
- API 编辑器底部只保留取消和保存；保存继续写入配置和非空 Key 草稿。
- 测试连接移动到模型区域附近，并在按钮旁显示测试中、成功或具体失败结果；字段变化使旧结果失效。
- `TranslationAPIProfile` 新增持久化启用状态，旧配置兼容迁移为启用。
- 设置列表使用原生 Switch 控制“启用配置”；配置完整性仍以独立摘要状态表达。
- 只有启用配置可成为默认配置、出现在翻译结果窗口中并发起新请求。
- 禁用默认配置时选择下一个可用启用配置；全部禁用时允许默认配置为空；首次启用且没有默认时自动成为默认。
- 菜单只保留设为默认和删除；最右侧三横杠手柄支持真实拖拽排序并持久化。
- 同步自动化测试、0.1.0 中英文规格、验收文档和当前状态。
- 构建并覆盖稳定签名的 `artifacts/Marla_dev.app`，完成真实浅色/深色截图与五维 SwiftUI 评审。

## Out of Scope

- 自动 fallback、健康检查调度或按失败类型自动启停配置。
- Provider 专属能力、每入口独立配置集合或多模型并行对比。
- API Key 明文回显或把测试凭证写入仓库和日志。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-07 | Project owner | 初始请求即为当前范围 | 新增草稿 Key、启用过滤、默认迁移、拖拽排序与真实 UI 验收 | Verified |
| 2026-08-07 | Project owner | 真实拖动手柄时整扇设置窗口同时移动，要求修复 | 设置窗口背景不得抢占控件拖动；重新执行真实手柄拖放并确认顶部标题栏仍可移动窗口 | Verified by owner: “能拽得动了” |
| 2026-08-07 | Project owner | 拖动时只看到三横杠跟随，要求整行预览跟随鼠标，并在经过目标行时用过渡动画挤开其它配置 | 拖拽预览必须表达完整配置行；悬停重排而不是松手后突变；真实 App 录入拖动前后截图与交互证据 | Implemented; owner confirmation pending |
| 2026-08-07 | Project owner | 整行预览默认以中心吸附鼠标，要求鼠标继续位于实际抓取的尾部三横杠位置 | 使用可指定 `NSDraggingItem.draggingFrame` 的 AppKit 拖动源；单测验证预览内抓取点与指针重合，真实 App 验证拖动过程中整行向左展开 | Pending |
| 2026-08-07 | Project owner | 浮动预览仍被系统缩得过小，要求抓起时只轻微缩小；原行变为空槽，空槽随目标位置挤压移动，松手后再动画释放 | 曾实现 96% 预览与等高空槽；缩放部分已被下一条要求取代，空槽行为继续保留 | Superseded in part |
| 2026-08-07 | Project owner | 轻微缩放的质感仍不理想，要求取消浮动行缩放动画 | 浮动预览始终保持原行尺寸；只保留等高空槽的位移让位与松手内容恢复，不再改变浮动行几何 | Implemented; owner confirmation pending |
| 2026-08-07 | Project owner | 删除应用层缩放后实机仍看到缩放 | 确认缩放来自系统 `NSDraggingSession` 图像管线；原生拖拽项改为透明 1×1pt，只负责命中与 drop，用户可见预览改由固定 580×76pt 的非激活无边框 `NSPanel` 跟随鼠标 | Implemented; owner confirmation pending |

## Current evidence

- `APIKeyDraftResolver` 已被模型获取和连接测试共同使用；保存操作也会写入非空 Key 草稿。
- API 编辑器底部只保留取消和保存，测试按钮及其加载、成功、失败状态位于模型区域下方同一行。
- profile 已持久化向后兼容的 `isEnabled`；设置 Store 维护启用集合与默认配置不变量，结果卡和请求入口拒绝停用项。
- 配置列表使用 Switch、精简菜单和尾部三横杠；顺序可持久化并提供上下移动无障碍操作。
- 设置内容背景不再拖动窗口，项目所有者已确认手柄可以拖动且窗口不再跟随。
- 系统 `NSDraggingItem` 现在只显示透明 1×1pt 图像并负责原生 drop 命中；用户可见预览由不激活、不接收鼠标事件的无边框 `NSPanel` 绘制，固定为与原行相同的 580×76pt。Panel 根据系统提供的屏幕指针坐标和最初手柄抓取点直接移动，不经过系统拖拽图缩放管线。`APIProfileDropDelegate.dropEntered` 在 220ms `snappy` 动画事务中移动被拖 profile 的等高空槽，结束时原行内容以短促淡入恢复。
- 最新稳定签名 Release App 中，Computer Use 从三横杠完成了跨行拖放，AX 顺序随即变化；反向拖放也成功，并恢复了操作前的实际顺序。该接口以一次调用完成整个手势，无法截取按住期间的原尺寸浮动行和移动空槽，因此动态中间态仍等待项目所有者肉眼确认。

## Proposed approach

把 Key 草稿解析收敛为编辑器内单一方法，测试和模型发现共同使用。profile 模型增加向后兼容的 `isEnabled` 解码；设置 Store 统一维护“默认值必须属于启用集合”的不变量，并公开启用配置集合供会话和结果卡使用。列表行使用原生 Toggle 和 SwiftUI 拖拽排序，编辑器只保留一个主保存路径。

## Acceptance criteria

- [x] 初始请求和 Scope changes 中所有仍有效的要求都有对应验收项。
- [x] 新输入但未保存的 Key 可以直接用于测试连接；空草稿仍可使用已保存 Key。
- [x] 编辑器底部只显示取消和保存，连接状态在测试按钮旁即时显示且不会过期残留。
- [x] 旧 profile 解码后默认启用，新 profile 默认启用，启用状态和排序在重启后保持。
- [x] 禁用配置不会出现在结果卡选择器中，也不会被默认新会话调用。
- [x] 禁用默认、全部禁用、重新启用和设为默认的行为保持一致且有自动化覆盖。
- [ ] 配置菜单只保留设为默认和删除；最右侧三横杠支持拖拽排序和辅助功能操作。抓起时固定 580×76pt 的独立浮层整行向指针左侧展开，原始抓取点保持在三横杠内；系统拖拽图必须透明且不可见，避免系统缩放。列表原行变成等高空槽，空槽经过其它配置时以短促过渡实时移动和让位；松手后内容以短促动画恢复到空槽，用户可见浮动行全程不得缩放。
- [x] `./scripts/check.sh` 通过，相关规格和 `STATUS.md` 同步。
- [x] 固定签名 App 被安全覆盖；真实浅色/深色截图的五维评审每项至少 7/10。

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

在真实 Release App 中用至少两个配置检查启用/禁用、默认迁移、拖拽排序、当前 Key 草稿测试、测试结果同行展示，以及编辑器底部取消/保存；分别保存浅色和深色截图到 `artifacts/ui-review/task-013/`。

当前固定 App 的静态列表、编辑器、辅助功能排序和真实三横杠跨行拖放已验收，原配置顺序也已恢复。项目所有者已确认窗口不再跟随手柄移动；绕过系统拖拽图缩放的固定尺寸 Panel、精确手柄锚点、移动空槽和松手恢复动画等待其在最新覆盖构建上确认。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `docs/versions/0.1.0/UI_SPEC.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `Sources/MarlaCore/TranslationModels.swift`
- `Sources/MarlaApp/SettingsView.swift`
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Sources/MarlaApp/MarlaApp.swift`
- `Tests/MarlaCoreTests/MarlaCoreTests.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Risks and rollback

- 禁用状态会改变默认 profile 选择，必须集中维护不变量，避免设置列表、结果卡和请求层分别推断。
- 原生拖放在 `ScrollView` 中可能与点击编辑冲突；手柄限定拖拽区域并保留辅助功能移动操作。
- 旧 JSON 必须缺字段可解码；若迁移失败可回退为始终启用，但不得损坏 UUID、顺序或 Keychain account。

## Decisions needed

恢复条件：项目所有者在最新固定 App 中确认固定 580×76pt Panel、精确手柄锚点、移动空槽和松手恢复动画符合预期；确认后继续完成本 Task。

## Completion record

任务完成时填写。
