# Jovi Embedded Work Skills

> 嵌入式工程开发与 Windows 工作环境维护 Claude Code Skills 集合 — 新工程一键初始化、文档自动化、代码注释标准化、日报生成与 C 盘数据整理。

专为嵌入式 C 工程（GD32/STM32/ESP32 + FreeRTOS + Modbus/CAN/UART）设计，开箱即用。

## Skills 总览

```
jovi-embedded-work/
├── project-init/              # 一键初始化工程工具链
├── update-project-docs/       # 文档 bootstrap + 日常维护
├── code_zl/                   # C 代码注释标准化
├── code_wrt/                  # Ponytail 简化 + code_zl 注释整理
├── day_sum/                   # 开发日报生成
├── child-claude/              # 多模型派发编排（父规划+审核，子执行）
├── codex-memory/              # 安全项目永久记忆（Obsidian / staging）
└── c-pan-reorganize/          # C 盘应用数据迁移 + 更新包/缓存安全清理
```

---

### 1. project-init — 工程一键初始化

**触发词：** `/project-init`、`项目初始化`、`初始化工程`、`init project`

**功能：** 自动检测并初始化嵌入式工程所需的全部工具，已初始化的自动跳过。

| 工具 | 命令 | 创建内容 |
|------|------|---------|
| CodeGraph | `codegraph init` | `.codegraph/codegraph.db` — 代码知识图谱 |
| code-review-graph | `code-review-graph init --yes && build` | `.code-review-graph/graph.db` — 代码审查图谱 |
| comet | `comet init --yes` | `.comet/config.yaml` + skills/rules |
| update-project-docs | bootstrap Phase 0 | `docs/README.md` + `CLAUDE.md` + 架构文档 |
| openspec（可选） | `openspec init` | `.openspec/` 目录 |

**示例：**
```
/project-init D:\work\my-new-embedded-project
```

**输出：**
```
## 项目初始化检测

| # | 工具 | 状态 | 将执行 |
|---|------|------|--------|
| 1 | CodeGraph | ❌ 未初始化 | codegraph init |
| 2 | code-review-graph | ❌ 未初始化 | code-review-graph init --yes + build |
| 3 | update-project-docs | ❌ 未初始化 | bootstrap 文档脚手架 |
| 4 | comet | ❌ 未初始化 | comet init --yes |
```

---

### 2. update-project-docs — 文档管理

**版本：** V1.0.0

**触发词：** `/update-project-docs`、`更新文档`、`初始化文档`、`setup docs`

**功能：** 嵌入式工程文档全生命周期管理。首次运行只搭 **5 个默认目录**，禁止生成 11 个空类型文件夹。后续进入 6 阶段文档维护工作流。

**默认目录：**

```text
docs/
├── README.md
├── GUIDE.md
├── 00-REF-参考/     # 手册、原理图、协议表、参数表
├── 01-ARC-架构/     # 当前固件怎么工作
├── 02-SOP-操作/     # 编译、烧录、clangd、台架
├── 03-DBG-问题/     # 一篇一个故障
└── 04-LOG-记录/     # 开发日志、审计、交接
```

不预建：REQ / COM / PLN / WORK / TST / RPT / TOD / STUD。空目录不写 `00-阅读指引.md`。

**Bootstrap（首次运行）：** 扫描工程结构后，用户确认再写盘：

| 文件 | 内容 |
|------|------|
| `docs/GUIDE.md` | 命名 `{NN}-{TYPE}-{title}.md`、5 目录规则、信任标记、质量检查 |
| `docs/README.md` | 文档入口、5 目录索引、信任规则 |
| `docs/01-ARC-架构/01-ARC-系统架构.md` | 模块关系、任务/主循环、数据流、硬件分配 |
| `CLAUDE.md` | 仅当根目录没有 `CLAUDE.md`/`AGENTS.md` 时创建，不覆盖已有 `AGENTS.md` |

**日常维护（6 阶段工作流）：**
1. 读取入口文档 → 2. 提取工程元素 → 3. 收集代码证据 → 4. 设计变更 → 5. 写入文档 → 6. 验证

**示例：**
```
/update-project-docs 初始化文档
/update-project-docs 总结 Modbus 协议变更，更新 docs/00-REF-参考/01-REF-Modbus协议.md
```

---

### 3. code_zl — 代码注释标准化

**触发词：** `/code_zl`、`代码整理`、`注释整理`、`添加注释`、`批量注释`

**功能：** 为嵌入式 C 工程添加标准化注释，遵循 Jovi 代码规范。支持单文件和多文件并行处理。

**注释格式：**

```c
/*---------------------------------------------------------------------------
 Name        : static void modbus_parse_frame(uint8_t *buf, uint16_t len)
 Input       : buf - 接收缓冲区指针
               len - 帧长度（字节）
 Output      : 无
 Description : 解析 Modbus RTU 响应帧，提取寄存器值写入 dev_para。
               持 eeprom_mutex，阻塞等待信号量。
---------------------------------------------------------------------------*/
```

**处理范围：**
- 函数头注释：标准 Name/Input/Output/Description 格式
- 行内注释：`//` 中文，说明"为什么这样做"
- 分节注释：`// ==================== 标题 ====================`
- `.h` 文件：每个宏/枚举/结构体字段必须有 `//` 注释

**示例：**
```
/code_zl src/modbus.c src/can.c inc/main.h
代码整理（自动检测 git diff 暂存区文件）
```

---

### 4. code_wrt — 代码简化与注释整理

**触发词：** `/code_wrt`、`代码简化整理`、`简化并注释`、`简化并整理`

**功能：** 固定按 `ponytail → code_zl` 执行。先做最小的行为保持式简化，再使用 `code_zl` 整理嵌入式 C 的注释、分节和格式。两阶段不可交换，也不可只执行其中一个阶段。

**边界：** 保留公开接口、协议语义、硬件访问顺序、RTOS 时序、并发保护和错误处理；不确定简化是否等价时保留原代码并继续整理注释。

**示例：**
```
/code_wrt src/modbus.c src/can.c
```

---

### 5. day_sum — 开发日报生成

**触发词：** `/day_sum`、`总结日报`、`daily summary`、`work summary`

**功能：** 从开发记录文件或 git log 生成结构化日报，按"发现问题 → 分析 → 解决"组织。

**输出格式：**
```markdown
## 5.11 5.20

### 5.11.1 IoT 影子变量自动推送 + PIID 类型修复

1. 发现问题：`iot_task()` 只处理被动下发和定时上报，缺少主动检测本地变化的能力。
2. 分析：参考 ESP32S3 `cloud.c` 的 23 个影子变量模式，移植到 GD32。
3. 解决：
 - 实现 `shadow_poll_and_publish()`，10 个影子变量每 100ms 对比变化
 - 新增 `set_prop_int()` helper，修正 8 个 PIID 类型
```

**示例：**
```
/day_sum 总结 docs/开发记录.md
总结今天的工作
总结 5.20 和 5.21 的工作
```

---

### 6. child-claude — 多模型派发编排

**触发词：** `/child-claude`、`派给子claude`、`用mimo干`、`换便宜模型`、`delegate to child claude`

**功能：** 父 claude（规划+审核）把执行工作派发给子 claude（走便宜模型如 MiMo/DeepSeek），省 token。通过 `--settings` 覆盖切换模型，每次独立会话 + prompt caching 走缓存价。

**核心特性：**
- `-Profile` 切换模型（mimo / mimo-official / 自定义 profile）
- `-WorkingDirectory` 硬失败防误改别的工作区
- `-ResumeId` 复用会话（仅依赖任务）
- `Stderr`（清洗）+ `RawStderr`（原始）双字段捕获错误
- profile token 用 `$VAR_NAME` 环境变量引用，无明文泄露

**示例：**
```
/child-claude 用 mimo 在 E:\repo 写个加法函数+测试

# 脚本调用
Invoke-ChildClaude -Task "写 add(a,b)" -Profile mimo -WorkingDirectory "E:\repo"
```

**派发单模板：**
```
Task: <具体描述>
Path: <文件路径>
Path boundary: only touch files under <dir>
Acceptance: <验收标准，如 test.py 跑通>
Constraint: <约束，如只创建文件不跑命令>
```

**省 token 策略：**
- 独立任务 → 新会话（默认，前缀走缓存价）
- 依赖任务 → `-ResumeId` 复用
- 失败重做 → 通常新会话（避免继承错误上下文）


---

### 7. codex-memory — 安全项目永久记忆

**触发词：** `/codex-memory`、`加载项目记忆`、`归档项目记忆`、`Obsidian memory`、`project memory`

**功能：** 提供“读取 → 工作 → 归档 → 复盘”的项目记忆闭环：任务前加载受限的项目上下文；任务后把已验证的计划、进度、决策与工作流投影到受管 Obsidian 笔记；每日复盘仅聚合脱敏的成功归档事件。

**安全边界：**

- 项目与验证证据是事实源；Obsidian 只接收投影，绝不反向改写项目。
- 首次 `home` setup 必须显式提供 Vault 根目录，仓库不携带、推断或读取个人路径。
- `company` profile 默认 fail-closed：没有获批准的 memory root 时，仅允许策略许可的本地 staging。
- 写入先 `--dry-run`，使用哈希与受管区块保留手写内容；双侧变更时报告 `CONFLICT`，不覆盖。
- Obsidian MCP 是可选增强，文件系统路径不可用时也不会绕过策略。

**快速开始：**

```
/codex-memory setup --profile home（同时提供你的 Obsidian Vault 根目录）
/codex-memory load
/codex-memory --dry-run
/codex-memory review
```

> 当前自动化脚本面向 Windows PowerShell 5.1+；Hook 与每日计划任务安装器默认只预览，必须完成对应人工验证后再显式启用。

---

### 8. c-pan-reorganize — C 盘数据整理

**触发词：** `C盘清理`、`C盘空间不足`、`迁移应用数据到D盘`、`清理更新包`、`清理安全缓存`

**功能：** 审核 C 盘应用数据，将已授权且不在运行的数据迁移到 `D:\Document` 或 `D:\Documents` 的独立目录，并保留原路径 junction；同时区分可清理更新包、可重建缓存和必须保护的聊天数据库、项目数据、凭据及系统文件。

**安全边界：**

- 清理更新包或缓存不等于卸载软件；卸载/重装必须单独明确授权。
- 迁移前确认应用已退出、目标目录不冲突，迁移后核对 junction、文件数、字节数与 C/D 盘空间。
- 不手动删除 `pagefile.sys`、`hiberfil.sys`、`$WinREAgent`、活动数据库或当前聊天记录。

**示例：**
```
/c-pan-reorganize 审核 C 盘可清理缓存，并将飞书和钉钉数据迁移到 D:\Document
```

---

## 安装

### 方式一：git clone（推荐）

```bash
git clone https://github.com/Jovifei/Jovi-embedded-work-skill.git
cd Jovi-embedded-work-skill

# 复制到 Claude Code skills 目录
# Windows
xcopy /E /I project-init %USERPROFILE%\.claude\skills\project-init
xcopy /E /I update-project-docs %USERPROFILE%\.claude\skills\update-project-docs
xcopy /E /I code_zl %USERPROFILE%\.claude\skills\code_zl
xcopy /E /I code_wrt %USERPROFILE%\.claude\skills\code_wrt
xcopy /E /I day_sum %USERPROFILE%\.claude\skills\day_sum
xcopy /E /I child-claude %USERPROFILE%\.claude\skills\child-claude
xcopy /E /I codex-memory %USERPROFILE%\.claude\skills\codex-memory
xcopy /E /I c-pan-reorganize %USERPROFILE%\.claude\skills\c-pan-reorganize

# macOS / Linux
cp -r project-init ~/.claude/skills/
cp -r update-project-docs ~/.claude/skills/
cp -r code_zl ~/.claude/skills/
cp -r code_wrt ~/.claude/skills/
cp -r day_sum ~/.claude/skills/
cp -r child-claude ~/.claude/skills/
cp -r codex-memory ~/.claude/skills/
cp -r c-pan-reorganize ~/.claude/skills/
```

### 方式二：直接下载

下载 ZIP 解压后，将每个 skill 目录复制到 `~/.claude/skills/`。

## 前置依赖

| 工具 | GitHub | 安装方式 | 用途 |
|------|--------|---------|------|
| CodeGraph | [colbymchenry/codegraph](https://github.com/colbymchenry/codegraph) | `npm install -g @colbymchenry/codegraph` | 代码知识图谱，MCP 提供代码探索能力 |
| code-review-graph | [tirth8205/code-review-graph](https://github.com/tirth8205/code-review-graph) | `pip install code-review-graph` | 代码审查图谱，变更影响分析 |
| comet | [rpamis/comet](https://github.com/rpamis/comet) | `npm install -g @rpamis/comet` | OpenSpec + Superpowers 五阶段工作流 |
| OpenSpec | [Fission-AI/OpenSpec](https://github.com/Fission-AI/OpenSpec) | `openspec init`（comet 已包含） | 需求/设计/任务结构化管理 |
| Superpowers | [obra/superpowers](https://github.com/obra/superpowers) | 随 comet 安装 | TDD、brainstorming、计划执行等 skill 体系 |
| codex-memory | — | Windows PowerShell 5.1+、Python 3、PyYAML、Claude CLI | 安全 setup / preflight；Obsidian MCP 可选 |

> `project-init` 会自动检测未安装的工具并提示。`update-project-docs` 和 `code_zl` 无额外依赖。
>
> `codex-memory` 的核心路径不依赖 Obsidian MCP；MCP 只是可选增强。
>
> **推荐安装顺序：** Superpowers → comet（含 OpenSpec）→ CodeGraph → code-review-graph

## 使用场景

### 场景 1：新工程初始化

```
你：/project-init D:\work\stm32-sensor-hub

Claude：自动检测 → CodeGraph/cr/comet 未初始化 → 依次执行 init
→ 生成 CLAUDE.md + docs/README.md + 架构文档 → 输出初始化报告
```

### 场景 2：新工程文档脚手架

```
你：/update-project-docs 初始化文档

Claude：检测 docs/README.md 不存在 → 进入 Bootstrap 模式
→ 扫描源码与构建文件 → 识别 MCU/RTOS/外设
→ 只建 5 目录（REF/ARC/SOP/DBG/LOG），生成 README + GUIDE + 01-ARC-系统架构.md
→ 有 AGENTS.md 时不覆盖写 CLAUDE.md
```

### 场景 3：代码注释整理

```
你：/code_zl src/modbus.c src/can.c

Claude：读取两个文件 → 添加标准函数头注释 → 添加行内注释
→ 输出汇总报告（+12 函数头, +35 行内注释）
```

### 场景 4：代码简化与注释整理

```
你：/code_wrt src/modbus.c src/can.c

Claude：先用 ponytail 删除或内联行为等价的冗余代码
→ 再用 code_zl 整理最终代码的函数头、行内注释和分节格式
→ 输出两个阶段的变更与验证结果
```

### 场景 5：日报生成

```
你：总结今天的开发记录

Claude：读取 git log 或开发记录文件 → 按"发现问题/分析/解决"组织
→ 输出结构化日报
```

### 场景 6：跨会话项目记忆

```
你：/codex-memory load

Claude：解析 profile 与项目 ID → 读取最小全局偏好及当前项目概览/计划/进度
→ 输出带来源、长度受限且已脱敏的上下文摘要

你：完成任务后 /codex-memory --dry-run

Claude：优先审计 docs/README.md、docs/GUIDE.md、Git 与验证证据
→ 预览受管区块更新；确认后才归档并写入成功事件
```

### 场景 7：C 盘数据迁移与安全清理

```
你：/c-pan-reorganize 审核 C 盘空间，将已关闭的飞书和钉钉数据迁移到 D:\Document

Claude：先只读统计 C 盘数据和进程 → 确认目标目录与用户授权
→ 移动精确数据目录并建立 junction → 核对文件数、字节数和 C/D 盘空间
```

## 文档命名规范

所有 skill 生成的文档遵循统一命名：

```
{NN}-{TYPE}-{中文文档名}.md
```

| 代码 | 类型 | 目录 | 示例 |
|------|------|------|------|
| REF | 参考 | `00-REF-参考/` | `01-REF-Modbus协议.md` |
| ARC | 架构 | `01-ARC-架构/` | `01-ARC-系统架构.md` |
| SOP | 操作 | `02-SOP-操作/` | `01-SOP-固件烧录.md` |
| DBG | 问题 | `03-DBG-问题/` | `01-DBG-CAN通信排查.md` |
| LOG | 记录 | `04-LOG-记录/` | `01-LOG-开发记录202608.md` |

## 规范

所有 skill 遵循 [writing-skills](https://github.com/anthropics/claude-code) 规范：

- frontmatter `description` 以 "Use when..." 开头，只描述触发条件
- 包含 `evals/evals.json` 测试用例
- 支持中英文触发词
- 不在 description 中描述 skill 的工作流程（防止 Claude 走捷径）

## License

MIT
