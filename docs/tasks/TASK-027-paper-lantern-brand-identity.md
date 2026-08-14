# TASK-027：Paper Lantern 品牌标志与产品意象

Status: Done

Owner: Project owner + Agent

Created: 2026-08-14

Updated: 2026-08-14

Origin: direct request / product decision

Conversation: 2026-08-14，Marla Logo 设计与 Paper Lantern 方向确认

## Initial request

项目所有者在三轮 Logo 探索后选择第三轮的 Paper Lantern，并要求把“在阅读旁边提供一点光”写入软件概念，正式使用该方向。

## Outcome

Marla 获得一份可追踪、可缩放的 Paper Lantern 主品牌标志，以及与现有“靠近阅读、不抢焦点”产品定位一致的品牌意象和使用边界。

## Why now

`STATUS.md` 和 0.1.0 UI 规范此前仍把最终 App 图标列为未决事项。项目所有者现在已经明确选择 Paper Lantern；如果不把决定、源文件与 UI 边界同步写入仓库，后续容易继续使用占位资源、误改功能图标，或把品牌标志选择与 AppIcon 打包混为一谈。

## In Scope

- 选择 Paper Lantern 作为 Marla 的正式品牌标志和产品意象。
- 把“在阅读旁边提供一点光”写入产品定义与 UX 原则。
- 新增品牌规范，记录标志结构、颜色、最小尺寸、背景与禁止用法。
- 新增 Accepted ADR，记录这一耐久产品决定。
- 把选中的自包含 SVG 从忽略的探索目录提升为受版本控制的品牌主文件，并生成标准参考 PNG。
- 同步 0.1.0 UI 规范和 `STATUS.md`，准确区分“品牌标志已选定”与“AppIcon 尚未接入”。
- 新建 macOS AppIcon asset catalog，把 Paper Lantern 接入 Xcode Debug、Release 和固定测试 App 的默认构建链路。
- 扩展 App bundle 验证，防止后续构建遗漏或回退到占位图标。

## Out of Scope

- 把品牌色扩散到按钮、焦点环、错误状态或其它功能控件；应用继续尊重系统 `accentColor`。
- 用 Paper Lantern 替换菜单、设置、工具栏或截图入口的 SF Symbols。
- 设计文字标、动画标志、营销页面、DMG 背景或 App Store 截图。
- 公共商标检索、App Store 名称确认、Developer ID 签名、公证与公开发行。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-14 | Project owner | 选择 Paper Lantern，并把“在阅读旁边提供一点光”写入软件概念 | 新增品牌源文件、产品/UX 文档、耐久决策和一致性检查 | Verified |
| 2026-08-14 | Project owner | 要求以后所有 App 构建都使用 Paper Lantern，并在接入后结束本 Task | 新增 AppIcon asset catalog、Xcode Debug/Release 接入、bundle 图标验证和固定 Release App 重建 | Verified |

## Current evidence

- 项目所有者明确选择第三轮的 `concept-3-paper-lantern.svg`。
- 探索稿使用深蓝紫 `#393554`、赭红 `#C86652` 和暖黄 `#E6B86A`，在 16、32、64 和 512px 已完成渲染检查。
- 本轮接入前，Xcode 工程没有 asset catalog、AppIcon 集或 `CFBundleIcon` 配置；品牌标志选择不能被误报为 App bundle 图标接入。
- `Resources/Assets.xcassets/AppIcon.appiconset` 现已覆盖 macOS 16、32、128、256、512pt 的 1x/2x 槽位，Debug 和 Release 均把 `AppIcon` 设为唯一应用图标集。
- 项目所有者随后明确授权把 Paper Lantern 接入所有后续 App 构建；因此本 Task 在品牌阶段完成后重新打开，直到 Debug/Release 和固定 Release App 的图标均验证通过。
- 固定签名 `artifacts/Marla_dev.app` 已重建；`Info.plist` 指向 `AppIcon`，bundle 内含 `AppIcon.icns`、`Assets.car` 和 10 个可由 `assetutil` 识别的 Paper Lantern rendition。

## Proposed approach

以现有 Paper Lantern SVG 作为品牌主文件，不增加渐变、阴影、发光或额外装饰。产品文档把灯的意象限定为“用户邀请时出现、靠近阅读内容、照亮陌生语言、完成后退场”，而不是营销性拟人或持续占据界面的装饰。品牌规范明确主标志与功能图标分离。AppIcon 使用同一主轮廓生成 macOS 标准尺寸，接入唯一 App target 的 Debug/Release 配置，并由 `verify-app.sh` 检查构建产物中的图标声明和资源。

## Acceptance criteria

- [x] `PRODUCT.md` 和 `UX_PRINCIPLES.md` 明确记录 Paper Lantern 产品意象及其行为含义。
- [x] 新增品牌规范和 Accepted ADR，术语、颜色与边界一致。
- [x] 受版本控制的品牌 SVG 与项目所有者选中的概念形状一致，自包含且可解析。
- [x] 标志在 16、32、64、512、1024 和 2048px 可渲染，主轮廓在小尺寸仍可辨识。
- [x] `UI_SPEC.md` 中英文同步，准确区分品牌标志、功能 SF Symbols 和已完成的 AppIcon 接入。
- [x] `STATUS.md` 不再把最终品牌标志或 AppIcon 接入列为待决。
- [x] `git diff --check` 和相关文档/资产检查通过，现有用户改动完整保留。
- [x] `Resources/Assets.xcassets/AppIcon.appiconset` 覆盖 macOS 16、32、128、256、512pt 的 1x/2x 槽位，并全部源自 Paper Lantern 主文件。
- [x] Xcode Debug 和 Release 都把 `AppIcon` 设为唯一应用图标集，后续构建无需手工复制图标。
- [x] `verify-app.sh` 验证 App bundle 的 Paper Lantern 图标声明和编译资源，防止构建静默退回占位图标。
- [x] `./scripts/check.sh` 与 `./scripts/build-test-app.sh` 通过，固定 `artifacts/Marla_dev.app` 已携带 Paper Lantern 图标。
- [x] 真实构建产物中的图标完成视觉检查，`STATUS.md`、品牌规范、ADR 与中英文 UI 规范不再把 AppIcon 接入列为待办。

## Verification

### Automated

```sh
xmllint --noout Resources/Brand/PaperLantern/logo.svg
for size in 16 32 64 512 1024 2048; do
  rsvg-convert -w "$size" -h "$size" Resources/Brand/PaperLantern/logo.svg -o "/private/tmp/marla-paper-lantern-${size}.png"
done
./scripts/check.sh
./scripts/build-test-app.sh
```

### Manual

在浅色、深色与透明背景上查看 512px 标志，并检查 16/32px 轮廓。构建固定 Release App 后，从 bundle 的 `AppIcon.icns` 提取系统编译后的 256px 图标并与 Paper Lantern 主标志比较，确认没有回退到占位图标。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/UI_SPEC.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/decisions/ADR-0001-native-macos.md`
- `artifacts/logo-design/round-3/logos/concepts/concept-3-paper-lantern.svg`
- `Marla.xcodeproj/project.pbxproj`
- `scripts/verify-app.sh`
- `scripts/build-test-app.sh`

## Parallel contributors (optional)

None for documentation. The three Round 3 SVG explorations were generated as bounded concept contributions before this Task became an authorized project change; the main Agent owns the selected asset, final wording, documentation synchronization, and verification.

## Risks and rollback

- Paper Lantern 可能被误当作所有功能图标；品牌规范明确禁止这种替换。
- AppIcon 尺寸或 Xcode 编译配置遗漏会导致系统回退到通用图标；asset catalog 和 bundle 验证必须共同覆盖。
- 回滚时删除品牌源文件与规范，并撤销产品/UX/ADR/UI/Status 记录；不得保留部分“已选定”声明。

## Decisions needed

None. 项目所有者已选择 Paper Lantern。

## Completion record

- Verified commit: pending commit; working-tree verification completed 2026-08-14
- Automated evidence: `xmllint` passed for the canonical SVG; all standard logo exports and the 10-slot macOS AppIcon set render successfully; `./scripts/check.sh` passed 20 Rust tests, Swift tests/build, Xcode Debug, structure, shell, whitespace and diff checks; `./scripts/build-test-app.sh` rebuilt and twice verified the stable-signed fixed Release App, including `AppIcon.icns`, `Assets.car`, `CFBundleIconName`, `CFBundleIconFile` and all 10 Paper Lantern renditions.
- Manual evidence: the source mark was inspected from 16 through 2048px; the system-compiled 256px icon extracted from fixed Release `AppIcon.icns` retains the selected Paper Lantern silhouette and three-color structure without placeholder fallback.
- Documentation updated: `PRODUCT.md`, `UX_PRINCIPLES.md`, `BRAND.md`, `ADR-0008-paper-lantern-brand-identity.md`, `IMPLEMENTATION.md`, `UI_SPEC.md`, `STATUS.md`, `VERIFICATION.md`, and this Task.
- Remaining work promoted to: none; public signing, notarization and distribution remain outside this Task.
- Scope changes closed: yes
- Parallel contributions integrated: the selected Round 3 Paper Lantern concept was promoted to the version-controlled master SVG and reference PNG set.
