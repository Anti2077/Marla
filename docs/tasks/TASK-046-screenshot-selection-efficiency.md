# TASK-046：截图翻译提效

Status: Active

Owner: Project owner + Agent

Created: 2026-09-09

Updated: 2026-09-11

Origin: direct request

Conversation: 2026-09-09，优化普通截图翻译的窗口吸附、OCR 临时切换与 Space 平移

## Initial request

项目所有者要求在普通“截图翻译”的截图界面加入 macOS 风格窗口选择、`1/2/3` OCR 服务临时切换，以及框选拖动期间按住 Space 平移区域。

## Outcome

普通截图会话可以在区域和窗口模式间切换，以当前设置默认值启动但在本次会话临时选择 OCR Provider，并在拖动框选时按住 Space 平移矩形。独立原位翻译仍隐藏这些入口并强制云端 GLM-OCR。

## In Scope

- 同一次 `SCShareableContent` 快照提供冻结显示器和可见窗口元数据。
- Space 在无活动框选时切换窗口模式；悬停高亮并单击捕获独立窗口。
- 普通截图右下角显示 `1` Vision、`2` 本机 Ollama GLM-OCR、`3` 云端 GLM-OCR；选择只存活于当前截图会话。
- 活动框选期间按住 Space 平移矩形，限制在显示器联合边界内；释放后继续调整不跳变。
- 保持截图内存生命周期、现有 OCR/翻译协议、GLM-to-Vision 回退和原位翻译云端坐标合同。
- 增加窗口过滤/命中/坐标换算、模式状态、平移、临时 Provider 与原位隔离回归。

## Out of Scope

- 不修改 `OCRProviderKind` raw value 或设置页的持久化默认顺序。
- 不为原位翻译提供窗口模式或 OCR 临时选择。
- 不增加常驻全局鼠标监听，不保存截图、窗口标题或 OCR 会话选择。
- 不关闭 TASK-045 的固定 App owner acceptance 缺口。
- 本轮不推送远端。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-09-09 | Project owner | 明确 Space 无框选时进入窗口模式，OCR 只影响本次截图 | 增加模式状态与非持久化测试 | Implemented |
| 2026-09-09 | Necessary support | 隔离工作树无法写主仓库 `.git` | 在 `/private/tmp/marla-task-046.git/.git` 创建 `Anti2077/task-046` 临时 Git 元数据；不宣称主仓库分支已创建 | Recorded |
| 2026-09-11 | Project owner | 要求合并到 `main` 并提交 | 创建实现提交并以合并提交进入本地 `main`；不推送远端 | Implemented |

## Current evidence

- 新增 `ScreenshotSelectionMode`、`ScreenshotWindowTarget`、`ScreenshotSelectionResult` 与显式 `ScreenshotOCRProviderOption` 映射。
- `SCWindow.frame` 从 ScreenCaptureKit 顶部原点换算为 AppKit 全局底部原点后用于高亮、命中和 `CapturedScreenshot.globalRect`；原始 `SCWindow` 只用于 `desktopIndependentWindow` 捕获。
- 窗口目标排除 Marla 自身进程、非屏幕窗口、非普通窗口层、零尺寸和缺失所属进程的项目。
- 窗口异步捕获绑定当前会话 ID，取消或新会话会终止旧任务。
- 截图定向测试 35 项通过，覆盖负坐标平移、边界夹紧、释放 Space 连续调整、窗口 frame 换算、前后顺序命中、过滤、临时 Provider 非持久化、原位隔离和刘海安全区提示布局。

## Acceptance criteria

- [x] 普通截图无活动框选时按 Space 可在区域/窗口模式间切换。
- [x] 窗口模式使用同次快照过滤和命中窗口，单击通过 ScreenCaptureKit 独立窗口过滤器捕获。
- [x] 窗口 `globalRect` 使用正确 AppKit 全局坐标，继续兼容结果卡定位。
- [x] 普通截图显示 `1/2/3` OCR 控件，点击和键盘选择更新当前态且不写入 `UserDefaults`。
- [x] 原位翻译隐藏并禁用窗口/OCR 临时选择，进入截图层前固定云端 GLM-OCR。
- [x] 活动框选支持按住 Space 平移、显示器联合边界夹紧和释放后连续调整。
- [x] Escape、右键、确认与会话结束保持幂等并清理临时状态/任务。
- [x] 新增源文件进入 Swift Package 与 Xcode 工程，结构门禁通过。
- [ ] 固定 Release App 中完成窗口吸附、Space 平移、三种 OCR、浅色/深色/窄屏/Reduce Motion 人工验收。

## Verification

### Automated

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter Screenshot
./scripts/check.sh
./scripts/build-test-app.sh
git diff --check
```

当前定向结果：35 项截图相关测试通过。完整 `./scripts/check.sh` 和固定 Release App 重建通过；固定 App 已验证 Bundle ID、arm64、最低系统版本、稳定签名和 designated requirement。实际刘海屏读取到 `safeAreaInsets.top = 38pt`，提示已通过固定 App 截图确认位于刘海安全线下方并保留 `12pt` 间距。真实窗口、Space、OCR 与多外观交互仍待项目所有者验收。

### Manual

- 固定 Release App：普通截图中按 Space 悬停并单击不同应用窗口，核对截图内容与结果卡避让位置。
- 从四个方向框选，拖动期间按住/释放 Space，覆盖主屏边缘、负坐标显示器和跨屏区域。
- 使用按钮与 `1/2/3` 分别选择 Vision、本机 Ollama、云端 GLM；关闭会话后确认设置页默认值不变。
- 云端 Key 缺失应进入现有可见错误恢复；原位入口不得显示临时选择或进入窗口模式。
- 覆盖浅色、深色、窄屏和 Reduce Motion，确认控件无裁切、重叠或不可辨识状态。

## Required Reading

- `docs/features/screenshot-translation.md`
- `docs/tasks/TASK-041-in-place-screenshot-translation.md`
- `docs/tasks/TASK-042-automatic-window-placement.md`
- `docs/tasks/TASK-045-local-ollama-glm-ocr.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `docs/architecture/decisions/ADR-0002-ocr-strategy.md`
- `docs/architecture/decisions/ADR-0011-frozen-screenshot-in-place-translation.md`
- `docs/architecture/decisions/ADR-0012-external-local-ollama-ocr.md`
- `Sources/MarlaApp/Screenshot/ScreenshotSelection.swift`
- `Sources/MarlaApp/Screenshot/ScreenshotCapture.swift`
- `Sources/MarlaApp/App/ScreenshotTranslation.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors

None. The current environment did not authorize sub-agent delegation.

## Risks and rollback

- ScreenCaptureKit 窗口列表和窗口层随系统状态变化；回滚可只关闭 `allowsWindowSelection`，区域冻结截图仍保持原路径。
- 全屏覆盖层必须持续拥有键盘焦点；现有窗口级、View 级和会话监控取消路径继续保留。
- 多显示器坐标错误会影响窗口命中和结果卡位置，因此换算与负坐标测试是合入前门禁。

## Decisions needed

None.

## Completion record

保持 Active，等待项目所有者完成固定 Release App 的真实窗口吸附、Space 平移、三种 OCR 和多外观交互验收。实现提交为 `90c37f8`，已由 `ac35e0c` 合入本地 `main`；本地 `main` 尚未推送远端。
