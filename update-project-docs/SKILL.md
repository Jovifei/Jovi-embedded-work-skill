---
name: update-project-docs
description: "Use when embedded project docs are missing, stale versus firmware, or need reorganization; when docs/README.md does not exist; when Application version, macros, entry points, or charge/protect behavior changed and docs/ file introductions or current-state claims may be wrong. Triggers: /update-project-docs, 更新文档, 初始化文档, setup docs, init docs, 文件介绍, 文档过期."
---

# Update Embedded Project Docs

**Version: V1.1.0**

目录分类以「以后会不会每周往里扔文件」为准，不按文档类型学铺空格子。依据：`4G-module-ml307r`（11 格几乎全空）、`external-4G-module-gd32f303`（5 格持续在用）、`smart-controller-gd32f4`（ARC/REF/DBG/RPT 有货，SOP/TST/PORT/SER 空或错位）。

V1.0.0 的失败模式：agent 把「优先更新现有文档」理解成「只改几篇重要的」，只读 README/GUIDE/用户点名文件，不扫全树，也不根据代码 diff 回写文件介绍。V1.1.0 强制：**代码事实 → 全树清单 → 现网正文/历史横幅 → 入口介绍**。

## Goal

把对话、现有文档、代码、日志、协议抓包和硬件证据，写成可维护的嵌入式工程文档。目标不是多写文件，而是把已核实的知识放到正确位置，并分清：当前实现、目标能力、参考工程行为、未验证假设。

代码一变，`docs/` 里自称「当前 / 现网 / 工作树」的正文，以及 README/GUIDE/`00-阅读指引` 的**文件介绍**，必须一起变。禁止只改算法专题、把索引和介绍留在旧版本。

## When to Use

- 用户说 `/update-project-docs`、更新文档、初始化文档、文档过期、文件介绍。
- `Application/`（或等价固件树）改了版本宏、电流/电压/包络、入口函数、保护/充电行为。
- README 文首「当前固件」或「现有文档」表与源码不一致。

用户只要对话摘要、且未要求写盘时：只输出结构化摘要，但仍要列出建议落点。不要假装已经全树更新。

## Modes

```text
用户点名 1～3 个文件，且未说「全部/逐个/目录」
  → Targeted：只改点名文件 + 仍必须同步被影响的入口介绍
否则（含裸 /update-project-docs、全部、代码刚改完、文件介绍）
  → Full Refresh：每个 docs 下 .md 都要有清单结论
```

默认排除（除非用户点名）：`07-Code-Study/`、厂商 PDF、二进制。排除不等于「其余文件也可以不列」。

## Forbidden Shortcuts

禁止用下面任何一句结束任务：

- 「优先更新现有文档，所以只改了 ARC-04 / README。」
- 「历史 changelog 不能改写成现网，所以整个 `版本更改/` 跳过。」（必须仍核对文首「当前工作树」行）
- 「排除了 07-Code-Study，所以没做全树清单。」
- 「上下文太长，先改重要的 MPPT 几篇，其余以后再说。」（可以分批，但本回合回复必须带未处理表）
- 「Phase 1 只要求读 README 和 GUIDE。」
- 「RIPER 在 RESEARCH，所以不写盘。」用户已经要求更新文档时，写盘是任务本身。
- 把目标行为、参考表、旧版本节写成当前固件。

## Core Principles

### 1. Verify Before Writing Implementation Claims

不要把目标行为写成当前行为。实现声明至少要有一项证据：源码路径/函数/结构体/宏、构建或测试输出、板级日志、协议抓包、示波器/逻辑分析仪、明确的参考工程对照。仅静态阅读代码时写清楚。未上板写「待上板验证」。

### 2. Prefer Updating Existing Docs — 不是少改文件

默认不新建空目录、不发明新类型码。用户只要摘要时不写盘。

「优先更新现有」= 能回写就回写，禁止为格式铺空格子。**不等于**只挑几篇改。Full Refresh 时每个 `.md` 都要有 `UPDATE_CURRENT` / `BANNER_HISTORICAL` / `SYNC_INTRO` / `SKIP` / `NEW` 之一。

### 3. Search Reference Projects Broadly

用户说「参考某工程」时，按符号和调用链搜全。覆盖：初始化入口、主循环/任务、ISR、参数保存、UI/业务触发、测试与脚本。

### 4. Preserve Embedded Context Boundaries

ISR / RTOS 任务 / Driver / 应用 / UI 分开写。驱动细节不要写进业务策略文档，除非二者必须连在一起。

### 5. Follow Naming Convention

```text
{NN}-{TYPE}-{中文文档名}.md
```

- `NN`：该目录内序号，从 `01` 起。`00` 仅用于该目录**已有正文之后**的阅读指引或模板。
- `TYPE` 必须与所在目录一致。
- 禁止为了格式先建空目录，再只放一份讲目录格式的 `00-阅读指引.md`。

默认类型码：`REF` `ARC` `SOP` `DBG` `LOG`。可选（有连续正文再创建）：`PLN` `EXP`。过期进 `archive/`，不要预建。

旧 11 格归并：REQ→ARC 文首或 LOG 待办；COM 寄存器/帧格式→REF、时序/状态机→ARC；PLN/TOD/WORK 短清单→README 或 LOG 末尾；TST/RPT→SOP 步骤或 LOG 流水账；STUD/SER/PORT 满 3 篇再开子目录。

### 6. Use Mermaid `flowchart TB`

流程、状态机、模块关系、验证路径用 `flowchart TB`。能用表就不要长文。

### 7. Coverage, Not Cherry-Picking

Full Refresh 的完成条件是清单覆盖，不是「改过的文件看起来很多」。未改的文件必须写明为何是历史快照或排除项。

### 8. Code Diff Drives File Introductions

入口介绍（下面「介绍面」）描述的是**今天怎么读这些文件**，必须跟 `SOFT_VERSION` 和当前宏一致。只改正文、不改介绍 = 任务未完成。

## Code Facts First

在改任何「现网」句子之前，从源码提取事实，不要从旧文档抄：

1. `git status` / `git diff`（至少 `Application/` 或项目等价固件树）。
2. `SOFT_VERSION`（或等价版本宏）。
3. 本次改动的宏、阈值、入口函数、状态机、包络/限流。
4. 默认编译开关（充电阶段、遥测、NTC 等）。

然后在 `docs/` 全树（排除项除外）搜索这些**旧值**被写成「当前/现网/工作树」的句子。Windows 下中文路径用 Python `pathlib` 列文件，不要只靠 Glob。

代码 → 文档最小映射：

| 代码变化 | 至少同步 |
|---|---|
| `SOFT_VERSION` | README 文首；阶段 changelog 追加一节（仓库若有版本规则则遵守）；所有自称当前版本的介绍 |
| 电流/电压/功率/包络宏 | 所有无日期地写成现网的表；README/GUIDE/`00-阅读指引` 说明列 |
| 入口函数改名/所有权变化 | 现网 ARC 调用链；ALG2/接口文；SOP 若自称当前操作 |
| 保护/充电行为 | 现网 ARC + 相关 DBG 口径；历史 DBG 只加横幅 |
| 新增/重命名 md | README「现有文档」+「文档入口」+ 目录 `00-阅读指引` |

## File Introductions（介绍面）

这些不是可选项。Full Refresh 或代码驱动更新时必须核对：

- `docs/README.md` 文首「当前固件」
- `docs/README.md`「文档入口」
- `docs/README.md`「目录结构」
- `docs/README.md`「现有文档」表：每一行说明 = 该文件今天该怎么用，不是创建时的口号
- `docs/GUIDE.md`「本工程的补充目录」（若有）
- 各目录 `00-阅读指引.md`
- 专题 `README.md`（如 `MPPT算法/`、`06-BRINGUP/`）

「现有文档」表允许不枚举每一个历史 RESULT，但**现网入口文件**和本回合新建/改口径的文件必须有行。缺行要在回复里标明「索引仍缺」。

## Verdicts

| 结论 | 何时 | 做什么 |
|---|---|---|
| `UPDATE_CURRENT` | 文自称当前/现网/工作树，或读者会当成今天的代码 | 按源码改正文 |
| `BANNER_HISTORICAL` | 标明日期/旧版本的快照、旧 DBG、旧 changelog 节 | 不改历史数字；文首补一行「非现网，现网见 … / SOFT_VERSION=…」 |
| `SYNC_INTRO` | README/GUIDE/`00-阅读指引`/专题 README | 只更新介绍、链接、版本口径 |
| `SKIP` | 用户排除、PDF/二进制、空 | 清单里写原因 |
| `NEW` | 现有文档无法承载，且用户要求覆盖该主题 | 落到 5 默认目录或已有内容的可选目录 |

changelog 旧节里的 TC=1A、BAT×8A 等是历史，不要全局替换。只改文首「当前工作树」和读者会误当成现网的未注明句子。

## Default Directories (V1.0.0)

Bootstrap **只创建这 5 个目录**（可空目录本身，但不要放空阅读指引）：

```text
docs/
├── README.md              # 入口
├── GUIDE.md               # 命名、模板、质量检查
├── 00-REF-参考/           # 长期查阅，很少改正文逻辑
├── 01-ARC-架构/           # 当前固件怎么工作（随代码改）
├── 02-SOP-操作/           # 照着做：编译、烧录、clangd、台架
├── 03-DBG-问题/           # 一篇一个故障；没有故障可以一直空
└── 04-LOG-记录/           # 按时间的开发日志、审计、交接
```

| 目录 | 放 | 不放 |
|------|----|------|
| REF | 数据手册、原理图、PinMap、协议表、参数表、错误码 | 当前状态机解释 |
| ARC | 分层、主循环/ISR、外设用法、充电/保护/OTA 等现在代码在干什么 | 厂商 PDF、按日期流水账 |
| SOP | Keil 编译、烧录、clangd、台架步骤、验收清单 | 「为什么这样设计」 |
| DBG | 现象 → 证据 → 根因 → 修复 → 回归 | 普通功能说明 |
| LOG | 开发日志、提交审计、周报、版本交接 | 仍有效的架构正文（应回写 ARC） |

可选：`05-EXP-经验/`（能带到下一工程的避坑/复用）；`archive/`（过期文档）。有内容再建。

## Phase 0: Bootstrap

`docs/README.md` 不存在，或用户明确要求初始化文档时触发。

### Step 0.1: Scan Project Structure

1. Glob `**/*.c` / `**/*.h`，按目录前缀分组。排除 `Library/`、`Firmware/`、`HAL/`、`CMSIS/`、`freertos/`、`lvgl/`、`vendor/`、`thirdparty/`。
2. 构建系统：Keil `.uvprojx`、IAR `.ewp`、CMake/Makefile → target、器件、宏、include、链接脚本。
3. 从代码提取：MCU、外设 init、RTOS 任务、IRQHandler、核心 struct、协议、同步原语。

### Step 0.2: Generate `docs/GUIDE.md`

填入项目名。模板：

```markdown
# 文档编写指南 — {项目名}

## 版本
文档体系 V1.0.0。默认 5 目录，禁止预建空类型目录。

## 目录结构
docs/
├── README.md
├── GUIDE.md
├── 00-REF-参考/
├── 01-ARC-架构/
├── 02-SOP-操作/
├── 03-DBG-问题/
└── 04-LOG-记录/

`00-阅读指引.md` 仅在该目录已有至少一篇正文后才写。

## 命名
`{NN}-{TYPE}-{中文文档名}.md`。TYPE 与目录一致：REF / ARC / SOP / DBG / LOG。

## 信任规则
| 标记 | 含义 |
|------|------|
| ✅ 已验证 | 板级测试/日志/示波器 |
| ⚠️ 待上板验证 | 仅静态代码分析 |
| 📋 参考工程 | 来自参考项目，未在本工程验证 |
| 🎯 目标能力 | 尚未实现 |

## DBG 模板要点
现象、证据、假设、验证、根因、修复、回归。

## LOG 模板要点
日期、改了什么、证据（构建/测试/上板）、未完成项、回写 ARC/SOP 的入口。

## 质量检查
- [ ] 落在 5 个默认目录之一（或已证实需要的可选目录）
- [ ] 实现声明有代码/日志/测试证据
- [ ] 区分当前实现、目标能力、参考行为、待验证
- [ ] 优先更新现有文档（不是少改文件）
- [ ] `{NN}-{TYPE}-{title}.md` 且 TYPE 匹配目录
- [ ] 流程图 `flowchart TB`
- [ ] Full Refresh 时每个 .md 都有清单结论
- [ ] README/GUIDE/阅读指引的文件介绍已跟 SOFT_VERSION 对齐
```

不要在 GUIDE 里再列出 REQ/COM/PLN/WORK/TST/RPT/TOD/STUD 为默认目录。

### Step 0.2b: Create Default Directories

只 mkdir 这 5 个：`00-REF-参考` `01-ARC-架构` `02-SOP-操作` `03-DBG-问题` `04-LOG-记录`。

不要创建：`02-REQ-需求` `03-COM-协议` `04-PLN-计划` `05-WORK-执行` `06-TST-测试` `08-RPT-报告` `09-TOD-待完成` `10-STUD-学习`。

不要在空目录里写 `00-阅读指引.md` 或空模板文件。DBG/LOG 写作要点放在 `GUIDE.md`。

### Step 0.3: Generate `docs/README.md`

```markdown
# {项目名} 文档索引

文档体系 V1.0.0。

> **当前固件：{SOFT_VERSION}** —— 用源码宏填写，不要抄旧 README。

## 文档入口
- [编写指南](GUIDE.md)

## 目录结构
| 目录 | 类型 | 说明 |
|------|------|------|
| [00-REF-参考](00-REF-参考/) | 参考 | 手册、原理图、协议表、参数表 |
| [01-ARC-架构](01-ARC-架构/) | 架构 | 当前固件如何工作 |
| [02-SOP-操作](02-SOP-操作/) | 操作 | 编译、烧录、台架步骤 |
| [03-DBG-问题](03-DBG-问题/) | 问题 | 一篇一个故障 |
| [04-LOG-记录](04-LOG-记录/) | 记录 | 开发日志、审计、交接 |

## 现有文档
{扫描已有正文列出；没有则写「尚无，见 GUIDE」}

## 信任规则
- ✅ 已验证
- ⚠️ 待上板验证
- 📋 参考工程
- 🎯 目标能力
```

### Step 0.4: Generate `CLAUDE.md`

仅当仓库根还没有面向 Agent 的约束文件（`CLAUDE.md` / `AGENTS.md`）时创建，不要覆盖已有 `AGENTS.md`。内容用扫描结果：项目概述、构建系统、include、模块表、任务、同步原语、核心 struct、引脚、第三方库。

### Step 0.5: Generate `docs/01-ARC-架构/01-ARC-系统架构.md`

这是 Bootstrap 唯一必须生成的正文（有扫描结果）。含：概述、模块关系 `flowchart TB`、任务/主循环、数据流、同步、硬件资源。未上板的结论标 ⚠️。

### Step 0.6: Confirm with User

先列出将创建的文件、MCU/RTOS/外设/协议要点、待核实假设，用户确认后再写盘，然后进入 Phase 1。

## Standard Workflow

文档根默认是 `docs/`。用户指定了别的文档根，先读那个根的 README/GUIDE。

### Phase 1: Inventory and Scope

读 README、GUIDE。列出 `docs/` 下全部 `.md`（排除项单独成表）。给每个文件一个 Verdict。从对话提取目标、已确认事实、改动、证据、待办。大范围改目录先征得同意。

文件很多时：用子代理做清单与过期句搜索，父代理写盘。不要因为上下文不够就只改 3 个文件还不列其余。

### Phase 2: Extract Engineering Elements

动态发现源码路径。元素：硬件、固件、协议、持久化、验证、文档落点。

### Phase 3: Gather Evidence

先解析构建系统，再读相关源码。代码与旧文档冲突时，以当前代码为准，除非用户明确要写目标设计。

### Phase 4: Design the Doc Change

列出目标文件与 add/update/merge/split/archive。新文件必须落在 5 默认目录（或已有内容的可选目录）。介绍面始终在计划里。

### Phase 5: Write or Update Docs

结论先行；表优先；`flowchart TB`；写清路径/函数/宏/寄存器。区分当前实现与目标能力。

发现未覆盖的功能点：追加到 `04-LOG-记录` 最近一篇或 README 待办表。不要为一条待办去创建 `04-PLN-计划/` 或 `02-REQ-需求/`。同一计划连续多篇时再开 PLN。

若本回合改了会进固件镜像的代码，遵守该仓库的版本号规则（升 `z`、追加阶段 changelog）。本 skill 不代替版本规则。

### Phase 6: Verify

- 新 Markdown 符合 `{NN}-{TYPE}-{title}.md`，TYPE 匹配目录。
- 没有新建空的 11 格类型目录或空阅读指引。
- README 链接有效；介绍面与 `SOFT_VERSION` 一致。
- 实现有证据；目标能力未写成当前能力。
- Full Refresh：清单覆盖每个 `.md`；未处理项公开列出。
- 有 CodeGraph 且本次改了较多源码时：`codegraph index`。

## Completion Gate

Full Refresh 未完成，禁止说「文档已更新完毕」，除非：

1. 清单覆盖 `docs/` 下每个 `.md`（排除项有原因）。
2. 每个 `UPDATE_CURRENT` 已改，或出现在「未处理」表（路径 + 原因 + 建议下一刀）。
3. 介绍面已按本回合代码事实更新。
4. 回复含下方「更新结果」，且含清单摘要。

Targeted 模式：点名文件已改，且被影响的介绍面已改。

## Output Formats

用户要求总结对话、总结指定文档、或更新项目文档时，分别使用：

```markdown
## 对话总结
### 1. 用户目标
### 2. 已确认事实
### 3. 已完成文档/代码改动
### 4. 用户明确纠正和偏好
### 5. 待办事项
### 6. 建议写入的文档位置
```

```markdown
## 文档总结
### 1. 文档主题和受众
### 2. 核心工程元素
### 3. 主要结论
### 4. 与当前代码/文档体系的关系
### 5. 可保留内容
### 6. 应删除、合并或重写内容
### 7. 建议落点
```

```markdown
## 更新结果
- 模式：Targeted | Full Refresh
- 代码事实：SOFT_VERSION / 关键宏（来源路径）
- 修改文件：
- 新增文件：
- 介绍面：README 文首 / 现有文档 / GUIDE / 00-阅读指引
- 清单：UPDATE_CURRENT n / BANNER_HISTORICAL n / SYNC_INTRO n / SKIP n / NEW n
- 未处理：路径 + 原因（没有则写「无」）
- 合并/删除建议：
- 核心调整：
- 验证证据：
- 需要用户确认的缺口：
```

## Quality Checklist

- [ ] 读过 README 和 GUIDE
- [ ] 已从源码提取版本和关键宏，不是从旧文档抄
- [ ] Full Refresh 时每个 `.md` 都有 Verdict
- [ ] 介绍面已同步
- [ ] 新内容落在 REF/ARC/SOP/DBG/LOG（或已证实需要的可选目录）
- [ ] 未创建空类型目录、空 `00-阅读指引.md`
- [ ] 实现声明有证据；目标能力未写成当前能力
- [ ] `{NN}-{TYPE}-{title}.md` 且 TYPE 匹配目录
- [ ] 流程图 `flowchart TB`
- [ ] 回复里报告了证据、清单计数与剩余缺口
