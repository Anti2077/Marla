# TASK-032：改为无发布版本的持续孵化流程

Status: Done

Owner: Project owner + Agent

Created: 2026-08-18

Updated: 2026-08-19

Origin: direct request

Conversation: 2026-08-18 版本运作方式调整

## Initial request

项目所有者说明，当初使用 `0.1.0` 只是表达“做完后开始发布”，并不表示当前产品已经达到满意的首发范围；现阶段不想发布，而是希望继续集中增加功能，等首次公开发布以后才按实际发布与新增功能管理版本号。

## Outcome

Marla 进入不绑定公开版本号的持续孵化阶段。日常功能通过明确 Task 继续演进，不再由旧 `0.1.0` 发布合同冻结；只有项目所有者明确启动发布准备时才选择版本号、创建发布合同并开始发布验收。

## Why now

当前 `STATUS.md`、Roadmap、版本合同、Release Record、构建元数据和部分产品文案仍把仓库描述为 `0.1.0 Alpha` 收尾。这与项目所有者“尚未满意、暂不发布、继续发展产品”的真实意图冲突，也把产品规格与发布合同错误地耦合在一起。

## In Scope

- 定义孵化期、发布准备期和发布后 `Unreleased` 累积方式。
- 明确版本号只在准备真实发布时分配；功能合入本身不触发版本号变化。
- 把旧 `0.1.0` 合同和 Release Record 标为未发布的撤回草案，保留历史证据但取消当前约束力。
- 同步 `AGENTS.md`、文档入口、工作流、Roadmap、当前状态、验证队列、产品/架构当前事实和相关 ADR 的版本时序表述。
- 将开发 App 的技术占位 Marketing Version 改为 `0.0.0`，并同步打包验证脚本和设置页中的版本绑定文案。
- 保持固定 Bundle ID、固定测试 App 路径、稳定本地签名、最低系统和架构不变。
- 增加或更新必要的自动化检查与文档验证。

## Out of Scope

- 发布 Marla、选择首次公开版本号或宣称 `0.1.0` 已经发布。
- DMG、Developer ID、公证、自动更新、App Store 或公开分发。
- 因取消旧发布范围而自动实现云 OCR、上下文、历史、账号或其它功能。
- 取消 Task 授权、架构 ADR、隐私、安全、测试或实机验收要求。
- 改变 Rust crate/API schema 的技术版本；这些兼容性版本与产品发布版本独立。
- 提交、合并或推送。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-18 | Project owner | 取消当前 `0.1.0` 发布约束，满意前持续增加功能，首次发布后再按发布管理版本号 | 新增版本状态机、旧合同归档、开发占位版本和工作流一致性验收 | Verified |
| 2026-08-18 | necessary support | 一致性扫描发现 Backlog 的 TASK-013 状态、划词 Feature 的 TASK-029 状态和 Comparison 计划状态落后于 `STATUS.md`/真实完成记录 | 在不改变产品行为的前提下同步当前事实，避免孵化工作流继续读取陈旧发布阶段状态 | Verified |

## Current evidence

- 立项时 `STATUS.md` 写有 `Release target: 0.1.0 Alpha`，并把旧验收表未勾选项定义为权威发布缺口。
- 立项时 `docs/versions/0.1.0/` 同时混合当前产品行为、实现说明和发布验收，导致版本范围反向约束日常产品演进。
- 立项时 `README.md`、Roadmap、Product、Architecture、相关 ADR 和设置页仍含当前 `0.1.0` 时序表述。
- 立项时 Xcode Debug/Release `MARKETING_VERSION` 与 `scripts/verify-app.sh` 固定为 `0.1.0`；macOS App 仍需要合法的数字 Bundle 版本字段。
- 分支创建前工作树干净，基线分支为 `main`。
- `TASK-032` 实施后，Xcode Debug/Release 已使用 `0.0.0`，固定 App 通过同一稳定签名、Bundle ID、最低系统、arm64、资源和 designated requirement 验证；旧 `0.1.0` 草案已撤回但正文证据保留。

## Proposed approach

1. 新增耐久版本策略和 ADR：当前状态为 `Incubation / Unreleased`，没有活动发布合同；`0.0.0` 仅是不可公开发布的开发包技术占位。
2. 只有项目所有者明确启动发布准备 Task 时，才选择 SemVer、创建 `docs/versions/<version>/` 合同、把 App Marketing Version 设为该版本并建立 Release Record。
3. 首次发布后，日常功能仍先累计在 `Unreleased`；版本号只在下一次真实发布准备时提升，而不是每做一个功能就提升。
4. 旧 `0.1.0` 文档保留为撤回草案和历史证据，不再作为当前规格、排期或发布阻塞来源。
5. 当前产品/架构/功能文档描述实时基线；Task 授权具体改动；ADR 继续约束耐久隐私和架构决定。取消版本冻结不等于自动授权旧范围外功能。

## Acceptance criteria

- [x] `STATUS.md` 显示 `Incubation / Unreleased`，没有活动发布目标或发布合同。
- [x] 文档明确：首次发布版本在发布准备时选择；发布后功能先累计在 `Unreleased`，只在真实发布时升版本。
- [x] 旧 `0.1.0` 合同与 Release Record 明确标为从未发布的撤回草案，不再产生当前发布缺口。
- [x] 当前工作流允许项目所有者从直接请求、Ideas 或 Backlog 选择新功能 Task，不受旧 `0.1.0` Out of Scope 限制，同时不自动授权任何功能。
- [x] Accepted ADR 的隐私/架构边界继续有效；原来的 `post-0.1.0` 只作为已被新版本策略取代的时序表述。
- [x] Debug/Release App 的 `CFBundleShortVersionString` 为开发占位 `0.0.0`，验证脚本检查该占位值；Bundle ID、路径、最低系统、架构和签名规则不变。
- [x] 设置页不再把 OCR 当前能力描述为 `0.1.0` 固定范围，且没有布局或交互变化。
- [x] 相关自动化、文档链接/术语检查和 `git diff --check` 通过。
- [x] 相关规格和 `STATUS.md` 已同步。

## Verification

### Automated

```sh
./scripts/check.sh
./scripts/build-test-app.sh
rg -n "0\\.1\\.0|Release target|release contract|发布合同" AGENTS.md README.md docs Sources scripts Marla.xcodeproj
git diff --check
```

历史 Task、撤回的 `docs/versions/0.1.0/` 草案和历史验收证据允许继续出现 `0.1.0`；检查结果必须逐项区分历史记录与当前约束。

### Manual

- 检查固定 `artifacts/Marla_dev.app` 的 Info.plist，确认版本为 `0.0.0`，Bundle ID、最低系统、arm64、稳定签名与 designated requirement 保持有效。
- 设置页只做文案去版本绑定，不需要新的交互或视觉验收；若构建或截图显示布局变化，再升级为 UI 复审。

## Required Reading

- `AGENTS.md`
- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/development/WORKFLOW.md`
- `docs/development/VERIFICATION.md`
- `docs/development/ROADMAP.md`
- `docs/releases/README.md`
- `docs/releases/0.1.0.md`
- `docs/architecture/decisions/ADR-0002-ocr-strategy.md`
- `docs/architecture/decisions/ADR-0003-context-engine.md`
- `docs/architecture/decisions/ADR-0005-vision-only-ocr-for-0.1.0.md`
- `Marla.xcodeproj/project.pbxproj`
- `Resources/Info.plist`
- `Resources/Info-Debug.plist`
- `scripts/verify-app.sh`
- `Sources/MarlaApp/SettingsView.swift`

## Parallel contributors (optional)

None. 版本策略、状态、ADR 时序、旧合同归档和构建占位值必须使用同一套术语，文件之间强耦合；本次由主 Agent 串行维护，避免并行写入造成两套规则。

## Risks and rollback

- `0.0.0` 仍是 macOS Bundle 所需的技术数字，不代表公开版本；如果工具链拒绝该值，回退为不对外解释为发布版本的合法数字占位，并记录证据。
- 修改开发 App 的 Marketing Version 会改变代码签名内容，但固定路径、Bundle ID 和签名身份保持不变；通过现有打包脚本重新签名和验证。
- 旧版本合同包含大量有用行为说明；不删除正文，只撤销其当前发布约束，当前事实继续由 Product、Feature、Architecture、代码和测试承接。

## Decisions needed

None. 项目所有者已经明确选择“满意前持续孵化，实际发布时才开始版本管理”；首次发布的具体版本号留到未来发布准备 Task 决定。

## Completion record

- Integration: 本 Task 最初没有提交、合并或推送授权；项目所有者于 2026-08-20 在 TASK-033 收尾时授权把 TASK-032/TASK-033 的累积改动一并提交、合并到 `main` 并推送，准确提交标识由 Git 历史保存。
- Automated evidence: 受限沙箱首次 `./scripts/check.sh` 只因 3 个系统 Pasteboard/XPC 复制断言失败；授权环境重跑全绿，20 项 Rust 与 157 项 Swift 通过（3 项既有 Vision 宿主限制 skip），并通过 Swift Package、Xcode Debug、结构、shell、空白与 `git diff --check`。`./scripts/build-test-app.sh` 随后完成 Release 构建、稳定签名、固定路径替换和双重产物验证。
- Manual evidence: `artifacts/Marla_dev.app` 为 `com.marla.app`、Marketing Version `0.0.0`、macOS 14.0、arm64；Paper Lantern 10 个 AppIcon、2 个状态栏和 2 个菜单品牌 rendition 完整，签名 Authority 仍为 `API Usage Monitor Dev`，designated requirement 仍绑定原证书。设置页只替换两处版本绑定文案，无布局或交互修改。
- Documentation updated: `AGENTS.md`、根/文档入口、`VERSIONING.md`、ADR-0010 与相关 ADR、Product、Architecture、Data Contracts、Workflow、Roadmap、Verification、Backlog/Ideas、相关 Feature、撤回的 0.1.0 合同/Release Record、Task 与 `STATUS.md`。
- Remaining work promoted to: None. 首次发布版本与合同留给未来项目所有者明确启动的发布准备 Task；下一项产品工作可由项目所有者直接选择或从 Ideas/Backlog 选择。
- Scope changes closed: 2/2 Verified.
- Parallel contributions integrated: None; main Agent retained sole write ownership because the policy migration was tightly coupled.
