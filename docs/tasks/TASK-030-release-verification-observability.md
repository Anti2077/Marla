# TASK-030：发布性能验证与本地可观测性

Status: Done

Owner: Project owner + Agent

Created: 2026-08-18

Updated: 2026-08-18

Origin: direct request / RV-003

Conversation: 2026-08-18，清点并推进长期遗留的 RV 与 Blocked 项

## Initial request

项目所有者要求列出项目过去遗留、尚未完成的 RV 或 Blocked 工作，并实际推进长期拖延的任务；必须由项目所有者亲自完成的测试应给出明确操作与回报边界。

## Outcome

Marla 0.1.0 获得可重复、脱敏且不混入网络时间的本地 UI 延迟与内存证据。能够由 Agent 完成的 RV-003 项闭环；只能由项目所有者完成的 TASK-013、TASK-016、RV-004 与多屏 RV-002 项形成短而明确的手工清单，并已由项目所有者全部确认通过。

## Why now

当前没有 Active Task，但 RV-003 的两个 P95 指标和内存预算一直没有测量。外部截图轮询无法区分快捷键、网络、Rust 回调与 Swift 可见更新，现有固定 App 也没有验收专用时间点，因此需要一个只在显式验收环境启用的本地观测切片。

## In Scope

- 审计 `STATUS.md`、`VERIFICATION.md`、0.1.0 `ACCEPTANCE.md` 和历史 Task，区分真实遗留、用户专属验证与陈旧未勾选文档。
- 为本地入口壳层与 Rust 回调到 Swift 可见 delta 增加显式验收环境下的脱敏时间点。
- 增加可重复测量脚本，记录样本数、冷/热边界、P50/P95/最大值和内存口径；不记录原文、译文、Key、Header 或 Pasteboard 内容。
- 使用固定签名 Release App 测量空闲、常规结果卡、全显示器冻结/框选与 Vision 实图路径的峰值和必要的释放证据。
- 同步 `VERIFICATION.md`、0.1.0 中英文验收、Task 与 `STATUS.md`。

## Out of Scope

- 代替项目所有者输入、读取或记录 API Key，或重置 Keychain/TCC 权限。
- 替项目所有者接受 TASK-013 的拖拽主观动态效果。
- 在没有对应硬件时宣称多屏、负坐标或混合缩放已经真实验收。
- 将真实 Provider 网络 TTFT、总响应时间或吞吐混写成本地 UI 延迟。
- 修复验证中新发现的产品缺陷；可复现缺陷必须进入独立后续 Task。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-18 | Project owner | 要求列出并推进长期遗留 RV/Blocked；用户专属测试直接说明 | 建立完整遗留分类和用户手工清单，并先执行无需凭据的 RV-003/RV-002 子集 | Closed |
| 2026-08-18 | Necessary support | 现有固定 App 缺少两个 P95 的可观测时间点 | 增加仅验收环境启用的脱敏计时探针与重复测量脚本 | Closed |
| 2026-08-18 | Verification finding | 长样本中客户端在首个可见 delta 后按设计退出，SSE 完成帧偶发 `Broken pipe` | 服务端只把首个 delta 写入失败视为失败，允许完成帧遇到已关闭客户端；30 组长样本完整通过 | Closed |

## Current evidence

- 固定 `artifacts/Marla_dev.app` 已通过 Bundle、arm64、Paper Lantern 资源、稳定签名和 designated requirement 验证。
- 2026-08-18 当前长期运行固定 App 的空闲 RSS 为 129,120 KiB，约 126.1 MiB，低于 150 MiB 预算。
- `markdown-completed` 固定 Release fixture 的冷进程最大 RSS 为 135,168,000 bytes，约 128.9 MiB，低于 300 MiB 常规预算。
- 真实 ScreenCaptureKit 全显示器冻结与框选 fixture 的最大 RSS 为 341,147,648 bytes，约 325.3 MiB，低于 500 MiB Vision/截图预算。
- XCTest 内 Vision 实图会受 `OSStatus -6662` 限制；同一算法的沙盒外 2400×1600 本地生成图探针完成 accurate OCR，用时约 0.337s，最大 RSS 154,451,968 bytes，约 147.3 MiB。
- Computer Use 不能枚举无主窗口的 LSUIElement 菜单栏 App；该超时不是产品失败，也不能作为真实交互证据。
- 固定签名 Release App 的 30 组独立本地样本中，入口到壳层可见 P50/P95/max 为 131.869/145.947/149.332ms，Rust callback 到 Swift 可见 delta 为 35.068/43.957/44.074ms；均达到约 150ms/50ms 预算。
- `/private/tmp/marla-rv003-latency.jsonl` 共 60 行，字段严格限于 `schemaVersion`、`metric`、`durationNanoseconds`。delta 只使用 `127.0.0.1` SSE，不包含 Provider 网络时间。
- 2026-08-18，项目所有者随后明确回报 `RV-002`、`RV-004`、`TASK-013` 与 `TASK-016` 全部通过。闭环只记录通过结论，不补写显示器型号、凭据、认证方式或用户内容。

## Closure classification

| Category | Items | Boundary |
| --- | --- | --- |
| Agent-completable in this Task | RV-003 | 已完成本地 UI 延迟、RSS、Vision 探针、脱敏报告和固定 App 验证。 |
| Project-owner-only | TASK-013, TASK-016, RV-004 | 项目所有者已于 2026-08-18 确认三项全部通过；凭据和认证细节未进入记录。 |
| Hardware/permission dependent | RV-002 | 项目所有者已于 2026-08-18 确认完整 RV-002 通过；未补写其未提供的硬件参数或截图。 |
| Stale or unsynchronized release documentation | `ACCEPTANCE.md` 中若干与已完成 Task 行为重叠的未勾选项 | 未勾选 release contract 不自动等于未实现或 Blocked Task；必须逐项对照代码、自动化和真实 App 证据后才能同步，禁止本 Task 批量推断通过。 |

## Proposed approach

新增一个独立的验收观测类型和脚本。正常启动不设置验收环境时不创建记录、不写文件、不改变窗口或请求时序；验收进程通过显式环境变量把单调时钟时间点写到临时文件。入口场景由无网络 fixture 触发并在首个已布局窗口时完成；delta 场景在 Swift 复制 Rust 回调后开始，在主线程会话状态与结果视图完成一次布局后结束。脚本重复运行固定 Release App，校验样本完整性并计算分位数。耐久产品架构不变，因此不新增 ADR。

## Acceptance criteria

- [x] 遗留项按“Agent 可完成 / 项目所有者专属 / 外部硬件或权限阻塞 / 陈旧文档”分类，且不把已完成历史误报为当前 Blocked。
- [x] 正常产品进程不设置验收环境时不产生性能文件或额外内容日志。
- [x] UI 壳层与 Rust 回调到 Swift 可见 delta 的样本使用单调时钟，定义、起止点、样本数和网络排除边界明确。
- [x] 固定 Release App 的有效样本足以计算 P50/P95/最大值；达到预算才更新对应验收项。
- [x] 空闲、常规、全显示器冻结/框选与 Vision 实图路径有明确 RSS 口径，任何未覆盖的组合峰值保持证据边界。
- [x] 计时与报告不包含 API Key、Authorization Header、原文、译文、Pasteboard representation 或截图像素。
- [x] `./scripts/check.sh`、固定签名 Release 打包和 `git diff --check` 通过。
- [x] 新增代码未使任何源文件超过结构门禁。
- [x] `VERIFICATION.md`、0.1.0 中英文验收、Task 与 `STATUS.md` 同步。

## Verification

### Automated

```sh
./scripts/check.sh
./scripts/build-test-app.sh
```

### Manual

- 在 Apple M4、macOS 26.6.1 的固定签名 `artifacts/Marla_dev.app` 上重复运行无网络入口与 delta fixture。
- 用 `/usr/bin/time -l` 和长期进程 RSS 采样分别记录冷进程最大 RSS 与空闲 RSS；Vision 探针必须在 XCTest 沙盒外运行。
- 临时报告与截图只放在 `/private/tmp`，不提交截图或用户内容。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/versions/0.1.0/IMPLEMENTATION.md`
- `docs/versions/0.1.0/ACCEPTANCE.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/development/VERIFICATION.md`
- `Sources/MarlaApp/App/MarlaApplicationModel.swift`
- `Sources/MarlaApp/Panel/FloatingPanel.swift`
- `Sources/MarlaApp/Sessions/TranslationSessionStore.swift`
- `Sources/MarlaCore/RustCoreBridge.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Parallel contributors (optional)

None. 观测点、脚本和双语验收高度耦合，本轮由主 Agent 单一写入。

## Risks and rollback

- 观测本身可能扰动被测路径；必须只在显式验收环境启用，并保持记录工作最小化。
- “Swift 状态已更新”不等于“像素已提交到显示器”；时间点必须落在结果视图完成布局之后，并在报告中保留这一语义边界。
- 若环境变量或报告路径无效，验收运行应明确失败或不记录，不能影响正常产品行为。
- 回滚时移除独立观测文件、脚本和验收 fixture；产品数据合同与用户设置不需要迁移。

## Decisions needed

None. 项目所有者已选择推进长期 RV/Blocked；本 Task 只处理无需凭据、无需硬件变更的 RV-003 支撑工作。

## Completion record

- Verified commit: current `Anti2077/task-030-release-verification-observability` worktree; commit pending project-owner integration.
- Automated evidence: `./scripts/check.sh`, `./scripts/build-test-app.sh`, `git diff --check`, 30-pair `./scripts/measure-rv003.sh 30`, and 60-row privacy/schema audit passed.
- Manual evidence: Apple M4/macOS 26.6.1 fixed Release latency and RSS measurements；sandbox-external 2400×1600 Vision accurate OCR probe；项目所有者于 2026-08-18 确认 RV-002、RV-004、TASK-013、TASK-016 全部通过。精确性能值记录于上文和 `VERIFICATION.md`，用户专属验证只记录脱敏通过结论。
- Documentation updated: `VERIFICATION.md`, bilingual 0.1.0 `ACCEPTANCE.md`, TASK-013, TASK-016, this Task, and `STATUS.md`.
- Remaining work promoted to: none; RV-001 至 RV-004 均为 Complete，TASK-013 与 TASK-016 均为 Done。
- Scope changes closed: all three scope-change rows are closed by the completed harness, measurements, and documentation sync.
- Parallel contributions integrated: None
