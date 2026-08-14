# TASK-026：API 连接测试与真实翻译凭据一致性

Status: Done; live credential run tracked in RV-004

Owner: Project owner + Agent

Created: 2026-08-14

Updated: 2026-08-14

Origin: direct request / defect

Conversation: 2026-08-14，设置连接测试成功但结果卡提示 API Key 未授权；追加标准设置快捷键

## Initial request

项目所有者反馈：设置中的授权/连接测试正常，但真实翻译结果卡显示“API Key 或端点未授权”，疑似老 bug。

## Outcome

连接测试与真实翻译使用同一份已保存 profile 配置和 Keychain 凭据；测试按钮明确保存当前编辑内容后再测试。真实请求发现 profile 没有已保存凭据时，显示 profile 名称和“保存并测试”的修复提示，不泄露 Key。Marla 激活时，标准 macOS `⌘,` 命令打开或复用现有设置窗口。后续手动 opacity 实验因焦点/失焦状态下透得过头已回退，当前恢复原有系统默认玻璃，不保留自定义玻璃档位。

## Why now

此前连接测试优先使用编辑器内未保存的 Key 草稿，而真实翻译只使用进程内 Keychain 缓存，导致“测试成功、真实请求 401”成为可能。截图中的 `qwen-mt-turbo` 未授权与该分叉一致。

## In Scope

- 连接测试先保存当前 profile 的非敏感字段和非空 API Key 草稿，再从已保存 profile 构造测试 endpoint。
- 保留无鉴权本地/代理端点能力；空 Key 不被强制拒绝。
- 真实翻译在 `unauthorized` 且当前 profile 无已保存凭据时显示可操作的 profile-specific 提示。
- 增加不含明文 Key 的回归测试。
- 增加标准 macOS `⌘,` 设置命令，并复用现有设置窗口协调器。
- 同步 0.1.0 规格、实现说明、验收记录、`STATUS.md`。

## Out of Scope

- 自动替换、轮换或验证 API Key 内容。
- 更改 Provider、Authorization header 格式、Keychain vault schema 或权限策略。
- 把 `⌘,` 注册成跨应用全局快捷键，或加入可录制的三个翻译快捷键集合。
- 用 Slider 或 `.opacity(...)` 模拟连续玻璃强度，或覆盖系统的焦点、背景与无障碍自适应。
- 记录 API Key、Authorization header、源文或译文。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-14 | Project owner | 修复设置测试正常但真实翻译未授权的旧 bug | 新增一致性回归、真实请求缺凭据提示和固定 App 验证 | Verified; live credential run tracked in RV-004 |
| 2026-08-14 | Project owner | 增加 `⌘,` 打开设置 | 新增原生 App Settings 命令、真实按键复验和设置窗口视觉回归检查 | Verified |
| 2026-08-14 | Project owner | 将整体 Liquid Glass 表面调至中间透明度 | 试验发现焦点/失焦状态下透得过头，改为回退至原有系统默认玻璃；统一检查与固定 App 验证 | Rolled back |
| 2026-08-14 | Project owner | 分析焦点/失焦透明度异常，并在设置中提供可调选项 | 评估后确认离散档位仍不符合实际观感，移除设置项并恢复系统默认玻璃 | Rolled back |
| 2026-08-14 | Project owner | 清透仍过透，要求在平衡和清透间增加一档 | “通透”实验效果仍不理想，连同三档持久化、设置项和相关工程引用一并移除 | Rolled back |

## Current evidence

- `SettingsEditor.swift` 的连接测试原先用 `APIKeyDraftResolver`，可读取未保存草稿。
- `TranslationSessionStore.startRequest` 原先用 `settings.endpoint(for:)`，只读取已加载的 Keychain 缓存。
- 用户截图显示 profile `qwen-mt-turbo` 返回“API Key 或端点未授权”。
- 新增回归已证明保存并测试后的 endpoint 与真实 endpoint 字段一致，且 Key 只进入 Fake Keychain vault/请求内存。
- 用户提供的真实桌面截图显示同一设置窗口在焦点与失焦时透出程度明显变化；此前手动 `.opacity` 和离散清透档位都未达到可接受的稳定观感。

## Proposed approach

编辑器的“保存并测试”调用一个集中 helper：保存 profile 字段、保存非空 Key 草稿，然后从保存后的 profile 和缓存凭据构造 endpoint。翻译失败事件若为 `unauthorized` 且该 profile 没有已保存凭据，则替换为不含敏感信息的引导文案；存在凭据时保留 Provider 原始授权错误。

## Acceptance criteria

- [x] 连接测试后，测试 endpoint 与同一 profile 的真实 endpoint 使用相同 URL 模式、地址、模型和已保存凭据。
- [x] 空 Key 的本地/代理 endpoint 仍可测试，不被错误提示阻断。
- [x] 未保存凭据导致 401 时，结果卡指出具体 profile 并引导“保存并测试”，不显示 Key。
- [x] 自动化回归测试通过，且未新增 Key 明文日志/持久化。
- [x] `./scripts/check.sh`、固定 Release 构建与 App 验证通过。
- [x] 相关规格和 `STATUS.md` 已同步。
- [x] Marla 激活时按 `⌘,` 打开设置；重复触发复用现有窗口而不是创建重复设置窗口。
- [x] 新命令不改变三个可配置全局翻译快捷键，也不新增自定义设置视觉层。
- [x] 透明度实验已回退；当前恢复原有系统默认玻璃与单层材质回退，不增加第二层材质。

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

固定 `/Users/anti/Documents/ChatGPT/Marla/artifacts/Marla_dev.app` 的 settings-editor 自动化场景已捕获真实编辑器表面；由于输入 API Key 属于敏感凭据，未代用户在 Computer Use 中键入。项目所有者仍需在本机自行输入现有 Key，点击“保存并测试”后执行一次真实划词/快速输入翻译；该项作为 [`RV-004`](../development/VERIFICATION.md) 保留，不以模拟结果替代，也不阻止本实现 Task 关闭。

重新构建固定 Release 后，Computer Use 先关闭设置，再向 Marla 发送真实 `⌘,`，设置窗口成功恢复；重复发送后 Accessibility 树仍只有一个 `Marla设置` 标准窗口。应用菜单同时出现“设置…”命令。临时截图 `/private/tmp/marla-task-026-command-settings.png` 按项目默认规则不提交。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `docs/versions/0.1.0/UI_SPEC.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/architecture/ARCHITECTURE.md`
- `Sources/MarlaApp/Settings/SettingsEditor.swift`
- `Sources/MarlaApp/MarlaApp.swift`
- `Sources/MarlaApp/Settings/SettingsWindow.swift`
- `Sources/MarlaApp/Persistence/MarlaSettingsStore.swift`
- `Sources/MarlaApp/Sessions/TranslationSessionStore.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors (optional)

None

## Risks and rollback

- 测试按钮现在会持久化配置，用户可通过取消编辑避免保存；失败时不会写入日志或错误文本中的 Key。
- 如需回退，只需恢复 helper 与按钮文案，错误提示仍可独立保留。

## Decisions needed

None

## Completion record

- Verified commits: `37cc7b4`, `9b41fbd`
- Automated evidence: 两项新增凭据一致性测试通过；玻璃外观实验回滚后重新运行的 `./scripts/check.sh` 和 `./scripts/build-test-app.sh` 通过，固定 Release 包/签名验证保持有效。
- Manual evidence: `/private/tmp/marla-task-026-settings-editor.png` 为固定 Release settings-editor 截图；`/private/tmp/marla-task-026-command-settings.png` 记录 `⌘,` 打开后的设置窗口，重复触发只保留一个窗口，五维复核为 8/8/8/8/7。手动玻璃 opacity 与离散外观档位均因焦点/失焦截图中的过透观感被项目所有者否定并回滚。真实凭据输入与网络翻译保留为项目所有者 live credential gap。
- Documentation updated: 本 Task、0.1.0 规格/实现/UI/验收、`STATUS.md`。
- Remaining work promoted to: `RV-004` live credential consistency verification
- Scope changes closed: yes; live credential run remains explicitly unverified
- Parallel contributions integrated: None
