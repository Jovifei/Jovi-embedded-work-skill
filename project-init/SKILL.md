---
name: project-init
description: "Use when starting work on a new embedded C project, setting up a fresh repository, or when tools like CodeGraph, code-review-graph, comet, or project docs are missing or uninitialized. Triggers: project-init, 项目初始化, 初始化工程, init project, setup project."
---

# Project Init — 嵌入式工程一键初始化

## 目标

在新工程目录下自动完成所有工具和 skill 的初始化，避免手动逐个执行。自动检测已初始化项并跳过，只执行缺失步骤。

## 触发条件

用户说 `/project-init`、"项目初始化"、"初始化工程"、"init project" 时触发。

## 执行流程

### Step 1: 确认项目目录

如果用户未指定目录，询问项目根目录路径。所有后续操作在该目录下执行。

### Step 2: 检测初始化状态

按以下顺序检测每个工具的状态：

| # | 工具 | 检测条件 | 未初始化时的操作 |
|---|------|---------|----------------|
| 1 | CodeGraph | `.codegraph/codegraph.db` 存在 | `codegraph init`（自动包含 index） |
| 2 | code-review-graph | `.code-review-graph/graph.db` 存在 | `code-review-graph init --yes` + `code-review-graph build` |
| 3 | update-project-docs | `docs/README.md` 存在 | 调用 `/update-project-docs` skill，触发 bootstrap（Phase 0） |
| 4 | comet | `.comet/config.yaml` 存在 | `comet init --yes`（自动选英文+project scope） |
| 5 | openspec | `.openspec/` 目录存在 | `openspec init`（可选，询问用户） |

### Step 3: 展示待执行列表

向用户展示检测结果：

```
## 项目初始化检测

| # | 工具 | 状态 | 将执行 |
|---|------|------|--------|
| 1 | CodeGraph | ❌ 未初始化 | codegraph init |
| 2 | code-review-graph | ❌ 未初始化 | code-review-graph init --yes + build |
| 3 | update-project-docs | ❌ 未初始化 | bootstrap 文档脚手架 |
| 4 | comet | ✅ 已初始化 | 跳过 |
| 5 | openspec | ❓ 可选 | 询问用户 |

确认后开始执行？
```

### Step 4: 按顺序执行

对每个未初始化的工具，按 #1 → #4 顺序执行：

**#1 CodeGraph**
```bash
cd <project-root> && codegraph init
```
`codegraph init` 一步完成初始化 + 索引构建（不需要单独 `codegraph index`）。
等待完成后检查 `.codegraph/codegraph.db` 是否生成。
如果需要静默模式（大工程），可加 `--quiet` 标志。

**#2 code-review-graph**
```bash
cd <project-root> && code-review-graph init --yes && code-review-graph build
```
`--yes` 自动确认注入指令到项目文件（跳过交互提示）。
如果不想注入指令到 CLAUDE.md 等文件，用 `--no-instructions` 替代 `--yes`。
等待完成后检查 `.code-review-graph/graph.db` 是否生成。

**#3 update-project-docs**
调用 `/update-project-docs` skill，传入"初始化文档"指令。skill 会自动进入 bootstrap 模式（Phase 0），扫描工程结构并生成：
- `docs/GUIDE.md`
- `docs/README.md`
- `CLAUDE.md`
- `docs/01-ARC-系统架构.md`

**#4 comet**
```bash
cd <project-root> && comet init --yes
```
`--yes` 自动选择：project scope + 英文语言 + 自动检测平台 + 安装 CodeGraph。
如果需要中文 skill，init 后运行 `comet update --language zh`。
等待完成后检查 `.comet/config.yaml` 是否生成。

**#5 openspec（可选）**
询问用户是否需要。如果需要：
```bash
cd <project-root> && openspec init
```

### Step 5: 输出报告

```
## 项目初始化完成

| # | 工具 | 结果 | 详情 |
|---|------|------|------|
| 1 | CodeGraph | ✅ 完成 | N 文件, M 节点, K 边 |
| 2 | code-review-graph | ✅ 完成 | N 文件, M 节点, K 边 |
| 3 | update-project-docs | ✅ 完成 | 生成 4 个文档 |
| 4 | comet | ✅ 完成 | project scope, 英文 |
| 5 | openspec | ⏭️ 用户跳过 | — |

生成的文件：
- .codegraph/codegraph.db
- .code-review-graph/graph.db
- docs/README.md, docs/GUIDE.md, CLAUDE.md, docs/01-ARC-系统架构.md
- .comet/config.yaml + .claude/skills/ + .claude/rules/
```

## 错误处理

- 如果某个工具的命令不存在（未安装），报告错误并跳过，继续执行下一个
- 如果某个步骤失败，报告错误原因，继续执行下一个
- 最终报告中标注失败项，用户可手动重试

## CLI 参考

### CodeGraph
- 仓库：https://github.com/colbymchenry/codegraph
- 安装：`npm install -g @colbymchenry/codegraph` 或 PowerShell 安装脚本
- `codegraph init` — 初始化 + 索引（一步完成）
- `codegraph init --quiet` — 静默模式
- `codegraph index` — 重建索引
- `codegraph sync` — 增量同步
- `codegraph status` — 查看索引状态

### code-review-graph
- 仓库：https://github.com/tirth8205/code-review-graph
- 安装：`pip install code-review-graph` 或 `uvx code-review-graph`
- `code-review-graph init --yes` — 非交互式初始化（自动注入指令）
- `code-review-graph init --no-instructions` — 初始化但不注入指令
- `code-review-graph build` — 构建知识图谱
- `code-review-graph update` — 增量更新
- `code-review-graph status` — 查看图谱统计

### comet
- 仓库：https://github.com/rpamis/comet
- 安装：`npm install -g @rpamis/comet`
- `comet init --yes` — 非交互式初始化（英文 + project scope）
- `comet init --yes && comet update --language zh` — 初始化后切换中文
- `comet status` — 查看活跃 change
- `comet doctor` — 诊断安装健康状态
