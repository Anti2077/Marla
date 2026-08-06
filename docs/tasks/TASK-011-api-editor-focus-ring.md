# TASK-011：API 编辑器顶部聚焦边框完整显示

Status: Complete

Owner: Project owner + Agent

Created: 2026-08-07

Updated: 2026-08-07

Origin: direct request / live visual defect

## Outcome

API 配置编辑器首行“配置名称”获得键盘焦点时，macOS 蓝色 Focus Ring 的四边都完整可见，不再被滚动内容区域顶部裁切。

## Why now

项目所有者在固定测试 App 的真实深色界面中确认：首个输入框紧贴 `ScrollView` 顶部，Focus Ring 向控件外扩展的上边缘被滚动视口裁掉。该缺陷会让原生键盘焦点状态显得不完整。

## In Scope

- 为 API 编辑器滚动内容增加足够的顶部 Focus Ring 安全边距。
- 保持现有固定标签列、固定输入宽度、URL 模式、模型获取和底部操作区不变。
- 增加可重复的真实 App 聚焦状态截图入口并完成浅色、深色验收。
- 运行完整自动化检查，覆盖构建固定 `artifacts/Marla_dev.app`，同步 Task、Backlog、状态和 UI 验收文档。

## Out of Scope

- 重构 API 编辑器的信息架构或字段顺序。
- 改变系统 Focus Ring 的颜色、粗细或圆角。
- 修改 API 请求、Keychain、模型获取或翻译行为。

## Current evidence

- 用户截图显示“配置名称”输入框的蓝色 Focus Ring 顶边被裁切。
- `APIProfileEditorView` 的首行输入框位于 `ScrollView` 内容首项，滚动内容没有为控件外扩的 Focus Ring 预留顶部空间。
- TASK-010 自动化、模型获取和固定 App 构建均已通过；本任务只修复其编辑器聚焦几何。

## Proposed approach

使用语义化的滚动内容 margin，在首个字段上方预留一个 8pt 设计 Token。为 UI 自动化增加仅由环境变量启用的“聚焦配置名称”路径，真实 Release App 截图直接包含 Focus Ring，避免仅凭未聚焦截图推断修复效果。

## Acceptance criteria

- [x] 配置名称输入框聚焦时，蓝色 Focus Ring 上、下、左、右完整可见。
- [x] 未聚焦布局、字段对齐和滚动行为没有回归。
- [x] 浅色、深色真实 App 聚焦截图均无裁切或遮挡。
- [x] `./scripts/check.sh` 通过。
- [x] `./scripts/build-test-app.sh` 成功覆盖固定 App，Bundle ID、签名和 designated requirement 不变。
- [x] 五维 SwiftUI 评审每项至少 7/10，相关文档和 `STATUS.md` 已同步。

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

从固定 Release App 打开翻译 API 编辑器，在浅色和深色外观中聚焦首行“配置名称”，确认蓝色 Focus Ring 四边完整、与标题和下一行保持舒适间距。证据保存到 `artifacts/ui-review/task-011/`。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/UI_SPEC.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `Sources/MarlaApp/SettingsView.swift`
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Risks and rollback

- 安全边距过大可能让表单显得松散；使用现有 8pt Token，并以真实截图复核。
- UI 自动化聚焦不得影响正常打开编辑器；只在显式测试环境变量存在时启用。
- 回滚只需移除滚动内容 margin 和测试聚焦入口，不影响配置数据。

## Decisions needed

None — 项目所有者已明确要求修复该真实视觉缺陷。

## Completion record

- Verified commit: uncommitted project-owner worktree
- Automated evidence: `./scripts/check.sh` passed with 17 Rust and 41 Swift tests, Swift/Xcode Debug builds, source hygiene, and `git diff --check`. `./scripts/build-test-app.sh` rebuilt and verified the fixed Release artifact without changing its stable identity.
- Manual evidence: frontmost light/dark Release editor windows were captured by verified Core Graphics Window ID under `artifacts/ui-review/task-011/`; the system blue Focus Ring is complete on all four sides and existing field/action geometry remains aligned. Five-dimension scores are 8/8/9/8/7.
- Documentation updated: Task, Backlog, Status, bilingual UI specification, bilingual acceptance record, and visual review.
- Remaining work promoted to: None.
