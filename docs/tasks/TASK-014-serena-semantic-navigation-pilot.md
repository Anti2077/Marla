# TASK-014：Serena 只读语义导航试点

Status: Done

Owner: Project owner + Agent

Created: 2026-08-07

Updated: 2026-08-07

Origin: direct request

Conversation: 2026-08-07，Headroom + Serena 长线开发工作流评估后的第一阶段

## Initial request

项目所有者确认先实施第一阶段：只为 Marla 接入 Serena，验证 Swift/Rust 项目级只读语义导航，暂不接入 Headroom。

## Outcome

在 Marla 的受信任 Codex 项目中，Agent 可以通过 Serena 快速查找 Swift 与 Rust 符号、概览和引用关系，同时保持源码只读、索引边界明确，并且不占用 Serena memory/onboarding 上下文。

## Why now

Marla 将长期开发，Swift/AppKit/Rust 代码和项目文档会继续增长。先以可移除、只读的 Serena 试点验证语义索引的准确性、上下文节省和维护成本，再决定是否进入 Headroom 或更强的自动化阶段。

## In Scope

- 安装 Serena 所需的受支持 Python 工具运行环境与 `serena-agent` CLI。
- 为 Marla 生成并审查 `.serena/project.yml`，仅启用 Swift/Rust，遵守 Git 忽略边界，并设置为只读与 `no-memories` 模式。
- 用项目级 `.codex/config.toml` 接入 Serena MCP，不修改用户级 `~/.codex/config.toml`。
- 完成 Swift、Rust 索引与代表性符号/引用查询，验证源码目录可见而 `.build/`、`target/`、`DerivedData/`、`artifacts/` 不进入索引范围。
- 验证 Serena 写工具、memory 和 onboarding 能力不对本试点开放。
- 同步 Task、`STATUS.md` 和必要的项目使用说明，运行现有完整检查。

## Out of Scope

- 安装、启用或评测 Headroom。
- Serena hooks、自动 onboarding、Serena memories 或任何跨对话知识写入。
- 允许 Serena 修改、创建或删除源码和项目文档。
- 修改 Marla 产品行为、SwiftUI/AppKit 界面、Rust 业务逻辑或发布产物。
- 修改用户级 Codex 配置，或让 Serena 自动作用于其它仓库。

## Scope changes during the conversation

| Date | Requested by | Change | Acceptance / verification impact | Status |
| --- | --- | --- | --- | --- |
| 2026-08-07 | Project owner | 批准实施评估方案的第一阶段，仅接入 Serena | 新增项目级只读配置、双语言索引和真实 MCP 查询验证 | Verified |
| 2026-08-07 | Project owner | Serena 真实调用正常后正式落地，并同步长期规则到根 `AGENTS.md` | 独立 Codex 必须实际调用代表性 Serena 符号工具；成功后记录使用时机、只读边界与降级路径 | Verified |
| 2026-08-07 | Project owner | 当 Headroom 进入合适安装时机时，由 Agent 主动提醒 | 根 `AGENTS.md` 记录可观察的触发条件；提醒只启动独立评估，不自动安装或 wrap Codex | Verified |

## Current evidence

- `uv 0.12.2`、Python 3.13 下的 `serena-agent 1.6.1` 和 rustup `rust-analyzer 1.96.0` 已安装；完整 Xcode 的 `sourcekit-lsp` 由项目 MCP 环境显式选择。
- `.serena/project.yml` 使用 Swift/Rust、LSP、Git ignore、`read_only`、`no-memories` 与 9 项 `fixed_tools` 白名单；cache、logs、memories 和本机 override 均由 `.serena/.gitignore` 排除。
- `.serena/codex-readonly-context.yml` 在 MCP 注册前排除文件写入、符号修改、memory、onboarding、shell 和跨项目切换工具；真实 MCP `tools/list` 只返回 9 个语义读取工具。
- `.codex/config.toml` 只在 Marla 项目中启用 Serena，并关闭 Dashboard；用户级 `~/.codex/config.toml` 未被修改。
- 健康检查通过；索引缓存包含 15 个 Swift 文件和 1 个 Rust 文件。构建产物仍由 Git ignore 与 Serena ignore 双重排除。
- Swift 查询定位了 `TranslationAPIProfile` 及其设置、会话、拖拽 View 和测试引用，`RustTranslationClient/start` 返回请求入口；Rust 查询定位 `marla_translation_start` 并返回 4 处测试引用。
- 独立 `codex exec` 真实调用 `serena.get_current_config`，返回 `ACTIVE_PROJECT=Marla CONTEXT=codex-readonly-context ACTIVE_TOOLS=9`。
- 第二个独立只读 `codex exec` 真实发出 `server=serena tool=find_symbol`，准确定位 `TranslationAPIProfile` 到 `Sources/MarlaApp/MarlaApplicationModel.swift:81-138`；根 `AGENTS.md` 已据此固化优先使用时机、`initial_instructions`、只读限制、忽略目录与 `rg`/普通读取降级路径。
- 根 `AGENTS.md` 还规定：当长测试/构建输出、全仓或多文件调查、反复上下文压缩开始实质拖慢日常工作时，Agent 主动提醒项目所有者单独评估 Headroom；任何安装、MCP 接入、Codex wrapping 或配置修改仍需重新核对官方资料并获得明确授权。
- TASK-013 的实现已提交，但动态拖拽中间态等待项目所有者确认，因此保持 `Blocked`。

## Proposed approach

使用 Serena 官方 CLI 生成项目配置，再做最小必要调整；通过受信任项目内的 `.codex/config.toml` 启动 `serena start-mcp-server --project-from-cwd`，并加载仓库内的 `codex-readonly-context.yml`。自定义 Context 在 MCP 注册层收窄工具，`fixed_tools`、`read_only` 和 `no-memories` 再提供三层防护。先完成索引健康检查，再用 Marla 的已知 Swift/Rust 符号和跨边界调用作为烟雾测试。

这是一项可逆的本地开发工具配置，不改变产品架构或运行时数据流，因此不新增 ADR。

## Acceptance criteria

- [x] 初始请求和 Scope changes 中所有仍有效的要求都有对应验收项。
- [x] `serena` CLI 使用受支持的 Python 版本安装成功，Codex 可通过确定的可执行路径启动它。
- [x] `.serena/project.yml` 同时启用 Swift/Rust、遵守 Git 忽略规则、设置 `read_only` 并增加 `no-memories` 模式。
- [x] `.codex/config.toml` 只对 Marla 项目接入 Serena，且不修改用户级 Codex 配置。
- [x] Serena 成功索引并查询至少一组代表性 Swift 符号、Rust 符号和引用关系。
- [x] 构建产物目录未进入索引，写工具、memory 和 onboarding 工具不向 Codex 暴露。
- [x] 独立 Codex 进程实际调用代表性 Serena 符号工具；根 `AGENTS.md` 同步长期使用边界与降级路径。
- [x] 根 `AGENTS.md` 记录 Headroom 的可观察提醒条件，并明确提醒不等于安装授权。
- [x] `./scripts/check.sh`、`git diff --check` 和项目级 MCP 配置检查通过。
- [x] `STATUS.md` 与实际验证状态同步；本阶段无需真实 App/UI 验收。

## Verification

### Automated

```sh
./scripts/check.sh
git diff --check
codex mcp list
```

并执行 Serena 索引健康检查与可重复的 Swift/Rust 符号、引用烟雾查询。

验证结果：Serena health check 通过；索引为 Swift 15、Rust 1；真实 stdio MCP 工具清单为 9 项且禁止项为空；`./scripts/check.sh` 通过，Rust 17 项、Swift 48 项测试和 Xcode Debug 构建均成功。

### Manual

已在 Marla 根目录启动独立的临时只读 `codex exec` 会话；Codex 实际调用 Serena 并确认 Active project 为 Marla、Context 为 `codex-readonly-context`、Active tools 为 9。随后第二个独立会话实际调用 `serena.find_symbol`，准确返回 `TranslationAPIProfile` 的定义文件和第 81–138 行。无需启动或截图 Marla App。

## Required Reading

- `docs/README.md`
- `docs/product/PRODUCT.md`
- `docs/product/UX_PRINCIPLES.md`
- `docs/versions/0.1.0/SPEC.md`
- `docs/architecture/ARCHITECTURE.md`
- `docs/architecture/decisions/ADR-0004-swiftui-rust-core.md`
- `Package.swift`
- `Cargo.toml`
- `scripts/check.sh`
- `Sources/MarlaCore/TranslationModels.swift`
- `Sources/MarlaCore/RustCoreBridge.swift`
- `Sources/MarlaApp/MarlaApplicationModel.swift`
- `Sources/MarlaApp/SettingsView.swift`
- `rust/marla-core/src/lib.rs`
- `Tests/MarlaCoreTests/MarlaCoreTests.swift`
- `Tests/MarlaAppTests/MarlaAppTests.swift`

## Risks and rollback

- 首次索引可能较慢或占用本地磁盘；通过 Git 忽略规则和 Serena 自身 cache 忽略限制范围。
- `sourcekit-lsp` 对混合 Package/Xcode 工作区的符号覆盖可能不完整；以真实查询结果记录限制，不把文本命中误报为语义成功。
- 项目级 MCP 配置只有在 Codex 信任该仓库时加载；未信任时应明确提示而不是回退为用户级安装。
- 回滚只需移除项目级 `.codex/config.toml` 和 `.serena/` 项目元数据；已安装的通用 CLI 可保留供其它明确授权的项目使用。

## Decisions needed

None — 第一阶段边界、只读策略和 Headroom 延后均已由项目所有者确认。

## Completion record

- Verified commit: 未提交；在 `5b8766c` 基础工作树完成并验证，项目所有者未要求提交。
- Automated evidence: Serena health check；Swift 15 / Rust 1 索引；stdio MCP 工具清单与符号/引用烟雾查询；`codex mcp list`；`./scripts/check.sh`；`git diff --check`。
- Manual evidence: 独立 `codex exec` 返回 `ACTIVE_PROJECT=Marla CONTEXT=codex-readonly-context ACTIVE_TOOLS=9`；第二个独立会话实际调用 `serena.find_symbol` 并返回 `Sources/MarlaApp/MarlaApplicationModel.swift:81-138`。
- Documentation updated: `.serena/project.yml`、`.serena/codex-readonly-context.yml`、`.serena/.gitignore`、`.codex/config.toml`、根 `AGENTS.md`（含 Headroom 后续提醒门槛）、本 Task与 `STATUS.md`。
- Remaining work promoted to: None；Headroom、hooks、memories 和更强自动化仍未授权，继续留在后续评估阶段。
- Scope changes closed: Yes。
