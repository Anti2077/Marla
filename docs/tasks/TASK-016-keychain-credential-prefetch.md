# TASK-016：单一 Keychain vault 与启动授权

Status: Blocked

Implementation: Launch lifecycle repaired; blocked on owner clean-authorization confirmation

Owner: Project owner + Agent

Created: 2026-08-09

Updated: 2026-08-10

Origin: direct request / usability defect

Conversation: 2026-08-09 启动时一次性申请全部 API Keychain 凭据

## Initial request

项目所有者要求优化从 Keychain 获取 API Key 的过程：应用启动时申请全部 API Key，用户只需要一次性全部允许；当前首次翻译才触发 Keychain 授权并打断首次翻译。

## Outcome

Marla 使用一个 Keychain vault item 持久化全部 profile API Key，并在应用完成启动后只授权、读取这个 vault 一次。旧的逐 profile item 在迁移阶段集中读取并写入 vault；迁移读取复用同一个 `LAContext`，让系统认证结果可被同一启动流程中的所有旧 item 复用。迁移完成后翻译和切换配置不再触发其它 Keychain item 授权。

## Why now

当前 `MarlaSettingsStore` 和翻译 endpoint 构造按 profile 懒读取 Keychain；macOS 授权提示因此出现在首次需要翻译时，直接打断用户操作。

## In Scope

- 用一个版本化 Keychain vault item 保存全部 profile API Key，并使用进程内缓存。
- 在 App 完成启动且系统允许交互后读取 vault；不在模型构造期请求授权。
- 迁移旧的根 account 与逐 profile account，成功写入 vault 后删除对应旧 item。
- 保存、删除和 profile 派生逻辑只更新 vault 与缓存。
- 增加自动化回归测试，并同步实现、验收和状态文档。

## Out of Scope

- 将 API Key 写入 UserDefaults、日志、Rust 持久化存储或截图。
- 新增凭据管理 UI、自动 fallback 或后台网络请求。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-09 | Project owner | 初始范围：启动时批量申请全部 API Key，并避免首次翻译被授权打断 | 启动阶段单次批量查询；翻译前读取不再触发逐 profile Keychain 查询；完整自动化验证 | Implementation verified; live authorization pending |
| 2026-08-09 | Project owner live test | `kSecMatchLimitAll` 版本没有改变真实行为：首次翻译才提示，切换 profile 又再次提示 | 推翻多 item 批量预热方案；改为单一 vault item，并在 App 启动完成后加载 | In progress |
| 2026-08-09 | Project owner live test | 迁移旧 item 时实际输入了两次系统密码 | 启动迁移统一复用一个 `LAContext`；新增认证上下文复用和失败后不重试回归测试 | Automated verified; clean live authorization pending |
| 2026-08-09 | Project owner live test | 新固定 App 启动即退出 | 崩溃报告定位为 App 构造期 `NSApp` 尚为 nil；改用安全的 `NSApplication.shared.isRunning`，并要求真实 Release 进程常驻验证 | Fixed and launch-verified |
| 2026-08-10 | Project owner live test | 输入密码后进程仍在，但菜单栏主表面无法打开 | 移除构造期的自定义 App Delegate 和 `NSApplication.shared` 访问，只保留 `NSApplication.didFinishLaunchingNotification`；要求真实 Release 菜单表面截图验证 | Fixed and UI-verified |

## Current evidence

- 变更前 `KeychainCredentialStore.read()` 每次都调用 `SecItemCopyMatching`，没有缓存或批量路径。
- 变更前 `MarlaSettingsStore.init` 在 legacy migration 分支会读取旧 account；`apiKey(for:)`、`hasCredential(for:)` 和 `endpoint(for:)` 会继续按 profile 读取。
- 真实固定 App 证明：模型初始化期的 `kSecMatchLimitAll` 没有弹出授权，失败后逐 profile fallback 仍在首次翻译和切换配置时分别提示。
- Security API 只把 `kSecMatchLimitAll` 定义为返回全部匹配结果，不承诺把多个 item 的独立访问控制合并成一次授权。
- 启动迁移现在创建一个 `LAContext` 并传给 vault、根 account 和所有 profile account 查询；当前进程的 vault load 结果为终态，失败后保存和翻译不会再次触发 Keychain 查询。
- `Marla-2026-08-09-233323.ips` 证明首个失败包在 `installCredentialVaultLaunchLoad()` 中解包 nil `NSApp`，不是 Keychain 数据损坏。随后以 `NSApplication.shared.isRunning` 和自定义 App Delegate 规避崩溃的包虽然进程常驻，但项目所有者确认菜单主表面无法打开；最终修复恢复标准 SwiftUI `@StateObject` 启动入口，构造期不再访问 AppKit 单例，仅监听 `NSApplication.didFinishLaunchingNotification`。
- 最终固定 Release App 主线程处于正常 AppKit 事件循环、没有新增崩溃报告；内置 `menu-recents` UI 验收场景成功创建并截图完整菜单表面后正常退出。

## Proposed approach

`KeychainCredentialStore` 将 profile account 视为 vault JSON 内的逻辑 key，而不是独立 Keychain item。生产环境只读取/写入版本化 vault account；`MarlaApplicationModel` 在 App 完成启动后显式加载。迁移器按当前 profiles 定位旧 item，将成功读取的值合并写入 vault 后再删除旧 item，并把同一个 `LAContext` 传给整段迁移读取，使一次系统认证可被后续旧 item 查询复用。macOS 仍可能依据旧 item 自身的独立 ACL 做额外确认；迁移完成后只剩一个 vault item，后续版本和切换 profile 只会涉及一次 vault 授权。

## Acceptance criteria

- [ ] 应用完成启动后、首次翻译前只读取一个版本化 Keychain vault item。
- [ ] 全部 profile API Key 作为 vault 内逻辑条目存储，切换 profile 不触发第二个 Keychain item 授权。
- [ ] 旧根 account 与逐 profile account 可迁移；只有成功写入 vault 后才删除旧 item。
- [ ] 首次翻译不再因为逐 profile Keychain 读取弹出授权或被打断；预热失败时仍能安全降级并显示原有配置错误。
- [ ] 保存、删除、重命名、profile 删除和 legacy migration 的 Keychain 行为保持正确且缓存不返回旧值。
- [ ] API Key 仍只存在 Keychain/请求内存，不出现在 UserDefaults、日志、错误或诊断输出。
- [x] `./scripts/check.sh` 通过，包含新增回归测试、Swift/Xcode Debug 构建、格式/空白和 `git diff --check`。
- [x] 相关实现、验收和 `STATUS.md` 中英文说明同步更新。

## Verification

### Automated

```sh
./scripts/check.sh
```

### Manual

固定签名 Release `artifacts/Marla_dev.app` 已覆盖构建并通过独立验证。待项目所有者在干净授权状态启动该 App 一次：确认 Keychain 授权提示出现在启动阶段且一次允许后进入菜单；随后首次使用快速输入和划词翻译，确认不再出现逐 profile 授权打断。当前机器未重置既有 Keychain 授权，因此本项未宣称已验证。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/DATA_CONTRACTS.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors (optional)

None

## Risks and rollback

- 批量查询结果格式或权限状态异常时，回退到原有单项查询，不丢失凭据。
- 进程内缓存只存 Swift 运行期；退出即释放，不改变持久化隐私边界。

## Decisions needed

None

## Completion record

- Verified commit: Pending
- Automated evidence: `./scripts/check.sh` passed on 2026-08-10 after the final lifecycle repair: 17 Rust tests, 74 Swift tests, Swift/Xcode Debug build, formatting, whitespace, and `git diff --check`. `./scripts/build-test-app.sh` then built, stable-signed, replaced, and independently verified `artifacts/Marla_dev.app` as Bundle ID `com.marla.app`, version `0.1.0`, macOS 14+, arm64, Authority `API Usage Monitor Dev`, with the existing designated requirement. New tests cover one shared `LAContext` across startup migration and no retry after a denied vault load. The fixed Release executable remained alive in the normal AppKit event loop, produced no new crash report, and its built-in `menu-recents` acceptance scenario captured the complete menu surface before exiting normally. Executable SHA-256: `6ce3f0be4f77ef0b1b8a78976268eb56b9a4c2a6a3870f2b977a5096fe973234`.
- Manual evidence: Pending owner run from a clean Keychain authorization state.
- Documentation updated: `STATUS.md`, bilingual 0.1.0 SPEC/IMPLEMENTATION/UI_SPEC/ACCEPTANCE, and this Task.
- Remaining work promoted to: None
- Scope changes closed: Pending
- Parallel contributions integrated: None
