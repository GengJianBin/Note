# DeepSeek Harness 目录结构与各子目录职责

本文按“仓库根目录 → packages 分组 → 关键子模块”三层方式，说明 `deepseek-harness` 各目录的功能和作用，帮助快速建立对代码库整体布局的理解。

## 1. 仓库总体定位

DeepSeek Harness 是一个以 Cordis 为核心的插件式 Agent Harness。它不是传统的单体应用，而是一个由：

- 启动配置层
- Session / Agent / Loop 层
- LLM / Tool / Capability 层
- Web / API / ACP / SDK 层
- 文档 / 测试 / 构建脚本层

共同构成的多包 monorepo。

因此，仓库目录设计的核心思想是：

- `packages/`：放置真正的产品代码和能力插件
- `docs/`：放置架构、教程、规范和系统设计文档
- `apps/`：放置具体可运行应用入口
- `scripts/`：放置构建、校验、静态分析和生成器
- `website/`：放置文档站点
- `vendor/`：存放第三方源码副本（例如 Cordis）

## 2. 根目录各子目录功能

| 目录 | 作用 | 说明 |
|---|---|---|
| `.agents/` | Agent 工作流与 Agent Notes | 记录项目中的自动化工作流、架构决策、已归档笔记等 |
| `.github/` | GitHub 配置 | CI、issue、PR、workflow 等仓库自动化配置 |
| `.claude/` | Claude 相关配置 | 本仓库特定工作流或 Claude agent 配置 |
| `apps/` | 可运行应用入口 | 通常包括 CLI 和 Web 应用启动入口 |
| `docs/` | 设计文档和说明文档 | 架构、教程、subsystems、cookbook、验证规范等 |
| `examples/` | 示例/演示配置和 bundle | 展示如何组合 agent、plugin、配置，以及 demo 用例 |
| `native/` | 原生扩展/本地 addon | 例如 Landlock / PTY 等原生能力依赖 |
| `packages/` | 主要代码目录 | 这是 monorepo 的核心：每个 package 都是独立模块 |
| `python/` | Python SDK / 运行时 | 面向 Python 用户的 SDK 或 runtime 包装 |
| `scripts/` | 构建、验证和生成器脚本 | 代码生成、静态检查、仓库约束、发布脚本等 |
| `vendor/` | vendored 第三方源码 | Cordis 等第三方代码的源码副本与同步规则 |
| `website/` | 文档站点源代码 | VitePress 站点内容、导航、主题等 |
| `patches/` | 本地补丁 | 依赖修补或仓库专用补丁 |

## 3. 根目录中的关键目录说明

### 3.1 `packages/`：核心代码中心

`packages/` 是整个项目最重要的目录，几乎所有功能实现都放在这里。它遵循 `packages/<group>/<pkg>/` 的组织方式，例如：

- `packages/core/...`
- `packages/session/...`
- `packages/llm/...`
- `packages/fs/...`
- `packages/web/...`
- `packages/client/...`
- `packages/host/...`
- `packages/sdk/...`

其设计目标是：每个 package 都负责一个明确的能力或抽象层，并通过 Cordis 的 Service / Context / Event 机制协同。

### 3.2 `apps/`：运行应用入口

`apps/` 下通常放真实可运行的应用程序：

- `cli`：命令行应用入口
- `web`：Web UI 应用入口

这层不一定是核心业务逻辑本身，而更像“装配层”和“启动层”：它负责利用 bundle/profile 把不同插件树组装成一个应用。

### 3.3 `docs/`：知识中心

`docs/` 是项目的文档总入口，包含：

- `architecture.md`：总体架构
- `development.md`：开发指南
- `testing.md`：测试策略
- `subsystems/`：各子系统说明
- `cookbook/`：使用技巧和扩展方法
- `cordis-primer.md`：Cordis 运行模型入门

这里的设计是：用文档解释“系统如何组织、如何扩展、如何运行”。

### 3.4 `scripts/`：工程级脚本中心

`scripts/` 集中放置：

- 构建脚本
- lint / typecheck / doc sync / validation
- 生成 catalog / graph / docs
- CI 类校验脚本
- 发布或补丁相关脚本

例如：

- `gen-module-graph.ts`
- `verify-doc-budgets.ts`
- `verify-package-readme-model-experience.ts`
- `run-gates.ts`

它说明这个仓库不仅是代码库，也有很强的工程门禁逻辑。

### 3.5 `website/`：文档站点源代码

`website/` 使用 VitePress 构建文档站点，通常用于：

- 将 `docs/` 中精选内容投射为网页
- 提供对外文档站点
- 做多语言文档导航和展示

### 3.6 `vendor/`：第三方源码副本

`vendor/` 中放置 Cordis 等被 vendored 的源码与同步规则。此类目录通常用于：

- 复现特定版本的第三方依赖
- 保证仓库可独立构建
- 让某些核心能力在仓库中可审计、可改造

### 3.7 `native/`：本地扩展代码

`native/` 说明项目对底层操作系统能力有直接依赖，例如：

- PTY / sandbox / Landlock 等更底层的能力
- 扩展了 Node runtime 运行时能力

它往往比纯 TypeScript 代码更接近系统级能力。

### 3.8 `python/`：Python SDK 与运行时

这是对 Python 开发者开放的 SDK / runtime 入口，说明项目不仅提供 TypeScript 生态，也考虑了 Python 场景和互操作性。

### 3.9 `examples/`：示例与 demo

`examples/` 展示如何：

- 组装 Cordis 配置
- 使用 agent spine
- 运行 CLI、ACP、JSON-RPC demo
- 编写特定场景下的 plugin bundle

### 3.10 `.agents/`：项目内部知识和操作脚本

这个目录通常用于：

- Agent note
- 归档设计记录
- 工作流定义
- 决策的历史存档

这部分并不直接生产业务代码，但对架构演进和团队协作非常重要。

## 4. `packages/` 目录分组总览

`packages/` 是本仓库的中枢。按照系统设计，按“能力分组”组织：

| 分组/目录 | 主要职责 |
|---|---|
| `core/` | Core API spine：session、system prompt、tools、agent、agent loop |
| `api/` | Remote API / BFF / Typert gateway |
| `typert/` | 类型图 / typet runtime registry |
| `llm/` | LLM 定义、provider / adapter 适配 |
| `subprocess/` | subprocess 能力与 provider |
| `shell/` | shell 执行能力 |
| `terminal/` | 终端 / PTY 能力 |
| `fs/` | 文件系统能力与权限模型 |
| `lsp/` | Language Server 能力 |
| `skill/` | skill registry / catalog / loader |
| `web/` | web fetch / search 等能力 |
| `compaction/` | 压缩 / compact 能力 |
| `context/` | request context |
| `subagent/` | 子代理能力 |
| `workflow/` | workflow / worker-thread engine |
| `todo/` | todo 写入工具 |
| `plan/` | plan 模式状态 |
| `preset/` | preset 组合和 per-session composition |
| `guard/` | loop hygiene / timeout / 防误触 |
| `bundle/` | profile bundle / patch layer |
| `hooks/` | Claude Code / Codex hook bridges |
| `session/` | durable session 持久化与 projection |
| `settings/` | user settings |
| `credentials/` | 凭据、认证和 env provider |
| `sdk/` | JSON-RPC / TypeScript / server side SDK |
| `acp/` | ACP automation server |
| `interaction/` | approval / permission / user ask |
| `boot/` | shared app boot glue |
| `client/` | browser client runtime / UI |
| `host/` | host side of web GUI |
| `examples/` | demo bundles |
| `support/` | test support infra |
| `util/` | 通用低依赖 utility |

## 5. 关键分层关系：核心模块不是平铺，而是分层的

这是 DeepSeek Harness 最关键的目录理解方式：

1. `boot/`：把环境 + profile + bundle 组装为运行时
2. `core/`：提供最核心的 session / agent / prompt / tools / loop 抽象
3. `llm/`、`fs/`、`shell/`、`subagent/` 等：提供能力 seam
4. `session/`：提供持久化与 session projection
5. `api/`、`host/`、`client/`：暴露远程或 UI 接口
6. `examples/`、`python/`、`native/`：补充运行时和生态入口

这样结构的好处是：

- 能力实现可替换
- 运行时可组合
- UI 层和业务 runtime 层解耦
- package 粒度允许按需扩展

## 6. 目录使用建议

如果你正在阅读源码，推荐按这个顺序：

1. `README.md`：先理解项目定位
2. `docs/architecture.md`：再理解系统架构
3. `packages/README.md`：看 package 分层
4. `packages/core/*`：读核心 session / agent / tools / loop
5. `packages/llm/*`：读模型能力提供者
6. `packages/session/*`：读持久化和投影
7. `packages/client/` 和 `packages/host/`：看客户端和 host 层
8. `scripts/`：看工程门禁和检查流程

## 7. 一句话总结

DeepSeek Harness 的目录结构本质上是一套“插件式 Agent Runtime 的 monorepo 组织方式”：

- `core/` 是执行中枢
- `session/` 是事实源
- `llm/` 与 `tools/` 是推理和动作入口
- `bundle/` 与 `boot/` 是装配系统
- `client/`、`host/`、`api/`、`sdk/` 是外部接入层
- `scripts/`、`docs/`、`website/`、`vendor/` 是工程和文档支撑层

这也是它区别于传统应用的关键：不是一个固定的单应用，而是一组可组合、可替换、可扩展的能力和运行时组件。
