# TASK-018：冻结全屏截图框选

Status: Done

Implementation: Complete

Owner: Project owner + Agent

Created: 2026-08-10

Updated: 2026-08-10

Origin: Direct request after live-cursor feasibility review

Conversation: 2026-08-10 截图翻译悬停界面保留

## Initial request

项目所有者指出当前截图框选层会接管真实指针并使依赖悬停的界面消失。在对系统式虚拟指针和触发瞬间冻结全屏两种路线完成调查后，项目所有者选择冻结方案并要求开始实现。

## Outcome

截图快捷键触发后，Marla 在任何框选窗口出现前把所有活动显示器捕获为会话内存帧，再在这些静态帧上显示跨屏框选层。悬停弹层保留触发瞬间状态，视频与动画在框选阶段显示为静止画面；确认后直接从同一冻结帧裁剪并交给 Vision，不重新捕获实时桌面，也不写入文件。

## Why now

当前实现先显示可接收鼠标的全屏覆盖窗并激活 Marla，确认区域后才通过 ScreenCaptureKit 抓取实时桌面。真实指针离开原位置或源应用失焦会关闭依赖悬停的临时界面；截图时覆盖窗仍在屏幕上且过滤器没有明确排除 Marla 窗口。冻结方案以更简单、确定且不依赖私有光标锁定的行为解决这两个问题。

## In Scope

- 在显示任何框选窗口之前，用 ScreenCaptureKit 捕获每个活动显示器的完整静态帧。
- 框选层、未调暗选区和像素放大镜只显示同一组冻结帧；框选期间源视频和动画在视觉上保持静止。
- 确认选区后直接从冻结帧按跨屏坐标和显示器缩放合成裁剪，不再次捕获实时桌面。
- 全屏冻结帧和裁剪只存在于内存；取消、失败或 Vision 接管后释放不再需要的全屏帧。
- 保留现有 Esc、右键、无效区域、设置窗口暂停/恢复、结果卡锚定与 Vision/翻译管线。
- 为冻结合成、跨屏裁剪、窗口呈现顺序和生命周期增加自动化覆盖。
- 同步截图规格、实现说明、验收清单、架构事实和 STATUS。

## Out of Scope

- 系统式虚拟指针、主动鼠标事件 Tap、私有 SkyLight 光标锁定或调用系统 `screencapture` 工具。
- 实时视频/动画预览、窗口级智能选择、滚动截图和截图标注。
- 把全屏帧、裁剪或 OCR 内容写入磁盘、剪贴板或上传到云端。
- 修改 Vision、Rust FFI、Provider、翻译请求或结果卡产品行为。
- 改动 TASK-017 的原位翻译实现或完成其待复验验收项。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-10 | Project owner | 放弃系统式虚拟指针，选择静态截图覆盖并开始实现 | 新建 TASK-018；要求触发前冻结、静态框选和同帧裁剪 | Implemented |
| 2026-08-10 | Project owner | 结束 TASK-018 并合并到 `main` | 以现有自动化、Release 视觉证据结束实现 Task；未完成的真实环境证据转回 BL-002/BL-003，不把它们误记为已验证 | Complete |

## Current evidence

- `ScreenshotCaptureCoordinator.present` 先通过 ScreenCaptureKit 捕获每个活动显示器并排除 Marla 自身应用，成功取得全部帧后才创建 `.screenSaver` 级框选窗口。
- `ScreenshotSelectionView` 的背景、未调暗选区和放大镜共同使用会话内的 `ScreenshotMagnifierSource`；鼠标松开后由 `ScreenshotFrozenCapture` 直接合成选区，不再执行第二次实时捕获。
- 新增自动化覆盖验证混合 2×/1× 缩放的跨屏合成、输出尺寸及显示器外区域拒绝；完整 `./scripts/check.sh` 通过 17 项 Rust 和 83 项 Swift 测试及 Swift/Xcode Debug 构建。
- 固定签名 Release App 已生成 3420×2224 的浅色、深色和 Reduce Motion 冻结框选证据，位于 `artifacts/ui-review/task-018/`，五维评分为 8/8/8/7/7。
- 真实悬停弹层、播放中视频、物理多显示器、真实 `Esc` 和内存峰值/回落仍需项目所有者验收，未由静态夹具代替。

## Implemented approach

把生产 ScreenCaptureKit 调用前移到框选窗口创建之前，并将每个显示器帧连同全局 frame 和像素缩放封装为会话源。`ScreenshotSelectionView` 先绘制对应冻结帧，再绘制遮罩，并在选区内重新绘制未调暗帧。确认时通过纯合成器把所有与全局选区相交的显示器帧绘制到目标位图；`ScreenshotCaptureCoordinator` 随后立即释放会话和全屏源，仅把合成裁剪交给现有 Vision 管线。

## Acceptance criteria

- [x] 框选窗口只在所有活动显示器冻结帧成功取得后出现。
- [ ] 依赖悬停的弹层保留触发瞬间画面；视频和动画在框选阶段显示为静态帧。
- [x] 选区内部、遮罩背景和放大镜来自同一组冻结帧，不露出实时桌面。
- [x] 确认后裁剪来自冻结帧，不执行第二次实时屏幕捕获。
- [x] 单屏 Retina 实际渲染以及负坐标、跨屏和混合缩放合成尺寸通过自动化覆盖。
- [ ] 在真实副屏和混合缩放多显示器布局复验跨屏画面与裁剪。
- [ ] `Esc`、右键、无效区域和捕获失败不触发 OCR、翻译或文件写入。
- [x] 会话结束的源码生命周期释放全屏帧；只有选区裁剪进入 Vision，像素不进入 Rust 或云端。
- [x] 设置窗口暂停/非 Key 恢复、结果卡锚定和重新框选回归测试继续通过。
- [x] `./scripts/check.sh`、固定签名 Release 打包和 `git diff --check` 通过。
- [x] 固定 Release App 的浅色、深色、Reduce Motion 截图完成五维审查，每项至少 7/10。
- [x] 规格、实现说明、验收清单、架构、Task 和 STATUS 与验证事实同步。

## Remaining release verification

以下项目未在 TASK-018 中伪造完成状态；项目所有者已决定结束实现 Task，并将它们作为发布验收继续保留：

- 浏览器 Tooltip/悬停菜单与播放中视频的真实冻结效果、物理副屏/混合缩放裁剪、真实 `Esc`/右键/无效区域/捕获失败路径，以及 Screen Recording 权限持久性由 `BL-002` 跟踪。
- 全显示器冻结期间的内存峰值和会话结束后的回落由 `BL-003` 跟踪。

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

使用固定签名 `artifacts/Marla_dev.app`，在浏览器 Tooltip/悬停菜单和播放中的视频上触发截图，确认弹层保留且视频冻结；验证浅色、深色、Reduce Motion、单屏/副屏、跨屏、Retina、Esc、右键、无效区域、设置已打开和空 OCR。截图与五维审查证据保存到 `artifacts/ui-review/task-018/`。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors (optional)

None. The implementation and tests are tightly coupled in one Swift source/test pair, and STATUS/Task/spec ownership remains with the main Agent.

## Risks and rollback

- 全显示器冻结会短暂增加内存；必须在裁剪完成或取消后释放，并在真实多屏环境观察峰值与回落。
- 多显示器由多个单帧顺序捕获，极短时间内可能不是严格同一显示刷新周期；框选呈现后仍保持完全静态。
- ScreenCaptureKit 捕获延迟可能让框选层晚于快捷键出现；失败时显示现有可操作权限错误，不回退到实时覆盖。
- 删除冻结帧绘制/合成并恢复确认后实时捕获即可回滚，不改变 Rust 或数据合同。

## Decisions needed

- 无。项目所有者已选择静态冻结方案。

## Completion record

- Verified implementation commit: `27203b5`
- Automated evidence: `./scripts/check.sh` passed 17 Rust and 83 Swift tests plus Swift/Xcode Debug; frozen cross-display composition tests passed
- Manual evidence: stable-signed Release light/dark/Reduce Motion captures reviewed at 8/8/8/7/7 under `artifacts/ui-review/task-018/`; task closure accepted by project owner without claiming the remaining real-environment checks
- Documentation updated: SPEC/IMPLEMENTATION/ACCEPTANCE/ARCHITECTURE/Task/STATUS synchronized
- Remaining work promoted to: `BL-002` for real hover/video, display, cancellation/capture-failure, crop, and TCC evidence; `BL-003` for memory peak/recovery
- Scope changes closed: Yes
- Parallel contributions integrated: None
