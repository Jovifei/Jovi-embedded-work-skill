---
name: update-project-docs
description: "Use when project documentation is missing, outdated, or needs reorganization for an embedded C project. Also use when docs/README.md does not exist and scaffolding is needed. Triggers: update-project-docs, 更新文档, 初始化文档, setup docs, init docs, README/GUIDE updates."
---

# Update Embedded Project Docs

**Version: V1.0.0**

目录分类以「以后会不会每周往里扔文件」为准，不按文档类型学铺空格子。依据：`4G-module-ml307r`（11 格几乎全空）、`external-4G-module-gd32f303`（5 格持续在用）、`smart-controller-gd32f4`（ARC/REF/DBG/RPT 有货，SOP/TST/PORT/SER 空或错位）。

## Goal

把对话、现有文档、代码、日志、协议抓包和硬件证据，写成可维护的嵌入式工程文档。目标不是多写文件，而是把已核实的知识放到正确位置，并分清：当前实现、目标能力、参考工程行为、未验证假设。

## Default Entry Points

文档根默认是 `docs/`。先读该目录。

### Bootstrap Detection

Phase 1 之前检查 `docs/README.md`：

- **不存在：** 进入 Phase 0。只搭 5 个默认目录，禁止生成 11 个空类型目录。
- **已存在：** 跳过 Bootstrap，直接 Phase 1。若现有结构仍是 11 格空目录或根目录平铺编号，更新文档时应逐步迁到 5 目录，不要再补空文件夹。

用户说「初始化文档」「setup docs」「init docs」时也可触发 Bootstrap。

必读：

1. `docs/README.md`：入口、类型、信任规则。
2. `docs/GUIDE.md`：`{NN}-{TYPE}-{title}.md` 命名与质量检查。
3. 用户指定的目标文档。
4. 涉及实现时：源码、日志、测试、抓包或参考工程。

用户指定了别的文档根，先读那个根的 README/GUIDE，再按本 skill 流程做。

## Core Principles

### 1. Verify Before Writing Implementation Claims

不要把目标行为写成当前行为。实现声明至少要有一项证据：源码路径/函数/结构体/宏、构建或测试输出、板级日志、协议抓包、示波器/逻辑分析仪、明确的参考工程对照。

仅静态阅读代码时写清楚。未上板写「待上板验证」。

### 2. Prefer Updating Existing Docs

默认不新建文档。用户只要摘要时只给结构化摘要，除非要求写文件。

### 3. Search Reference Projects Broadly

用户说「参考某工程」时，按符号和调用链搜全，不要只看同名文件。覆盖：初始化入口、主循环/任务、ISR、参数保存、UI/业务触发、测试与脚本。

### 4. Preserve Embedded Context Boundaries

ISR / RTOS 任务 / Driver / 应用 / UI 分开写。驱动细节不要写进业务策略文档，除非二者必须连在一起。

### 5. Follow Naming Convention

```text
{NN}-{TYPE}-{中文文档名}.md
```

- `NN`：该目录内序号，从 `01` 起。`00` 仅用于该目录**已有正文之后**的阅读指引或模板。
- `TYPE` 必须与所在目录一致（`ARC` 目录里不要出现 `01-REQ-...`）。
- 禁止为了格式先建空目录，再只放一份讲目录格式的 `00-阅读指引.md`。

默认类型码只有：`REF` `ARC` `SOP` `DBG` `LOG`。

可选（有连续正文再创建目录）：`PLN` `EXP`。过期文档进 `archive/`，不要预建。

旧 11 格类型码不再作为默认结构。归并：

| 旧类型 | 落到 |
|--------|------|
| REQ | ARC 文首或 LOG 待办；没有正式需求就不建 |
| COM | 寄存器/帧格式表 → REF；时序/状态机 → ARC |
| PLN / TOD / WORK | 短清单 → README 或 LOG 末尾；多份计划才建 PLN |
| TST / RPT | 操作步骤 → SOP；流水账 → LOG |
| STUD / SER / PORT | 不预建；同一专题满 3 篇再开子目录 |

### 6. Use Mermaid `flowchart TB`

流程、状态机、模块关系、验证路径用 `flowchart TB`。能用表就不要长文。

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
- [ ] 优先更新现有文档
- [ ] `{NN}-{TYPE}-{title}.md` 且 TYPE 匹配目录
- [ ] 流程图 `flowchart TB`
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

### Phase 1: Read Entries and Scope

读 README、GUIDE、用户指定文档。从对话提取目标、已确认事实、改动、证据、待办。大范围改目录先征得同意。

### Phase 2: Extract Engineering Elements

动态发现源码路径，不要假设固定目录。元素：硬件、固件、协议、持久化、验证、文档落点。

### Phase 3: Gather Evidence

先解析构建系统，再读相关源码。代码与旧文档冲突时，以当前代码为准，除非用户明确要写目标设计。

### Phase 4: Design the Doc Change

列出目标文件与 add/update/merge/split/archive。新文件必须落在 5 默认目录（或已有内容的可选目录）。

### Phase 5: Write or Update Docs

结论先行；表优先；`flowchart TB`；写清路径/函数/宏/寄存器。区分当前实现与目标能力。

发现未覆盖的功能点：追加到 `04-LOG-记录` 最近一篇或 README 待办表。不要为一条待办去创建 `04-PLN-计划/` 或 `02-REQ-需求/`。同一计划连续多篇时再开 PLN。

### Phase 6: Verify

- 新 Markdown 符合 `{NN}-{TYPE}-{title}.md`，TYPE 匹配目录。
- 没有新建空的 11 格类型目录或空阅读指引。
- README 链接有效。
- 实现有证据；目标能力未写成当前能力。
- 有 CodeGraph 且本次改了较多源码时：`codegraph index`。

报告：修改/新增文件、核心调整、证据、仍需上板的缺口。

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
- 修改文件：
- 新增文件：
- 合并/删除建议：
- 核心调整：
- 验证证据：
- 需要用户确认的缺口：
```

## Quality Checklist

- [ ] 读过 README 和 GUIDE
- [ ] 新内容落在 REF/ARC/SOP/DBG/LOG（或已证实需要的可选目录）
- [ ] 未创建空类型目录、空 `00-阅读指引.md`
- [ ] 实现声明有证据；目标能力未写成当前能力
- [ ] `{NN}-{TYPE}-{title}.md` 且 TYPE 匹配目录
- [ ] 流程图 `flowchart TB`
- [ ] 回复里报告了证据与剩余缺口
