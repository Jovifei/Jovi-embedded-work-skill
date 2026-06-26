# Jovi Embedded Work Skills

> 嵌入式工程开发 Claude Code Skills 集合 — 新工程一键初始化、文档自动化、代码注释标准化、日报生成。

专为嵌入式 C 工程（GD32/STM32/ESP32 + FreeRTOS + Modbus/CAN/UART）设计，开箱即用。

## Skills 总览

```
jovi-embedded-work/
├── project-init/              # 一键初始化工程工具链
├── update-project-docs/       # 文档 bootstrap + 日常维护
├── code_zl/                   # C 代码注释标准化
└── day_sum/                   # 开发日报生成
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

**触发词：** `/update-project-docs`、`更新文档`、`初始化文档`、`setup docs`

**功能：** 嵌入式工程文档全生命周期管理。首次运行自动 bootstrap 全套文档脚手架，后续进入 6 阶段文档维护工作流。

**Bootstrap（首次运行）：** 自动扫描工程结构，生成：

| 文件 | 内容 |
|------|------|
| `docs/GUIDE.md` | 命名规范 `{NN}-{TYPE}-{title}.md`、类型码、模板、质量检查 |
| `docs/README.md` | 文档入口、目录索引、信任规则（✅已验证/⚠️待验证/📋参考/🎯目标） |
| `CLAUDE.md` | 项目概述、构建系统、代码架构、FreeRTOS 任务、硬件资源 |
| `docs/01-ARC-系统架构.md` | 模块关系图、任务架构、数据流、CAN/Modbus 协议、硬件分配 |

**日常维护（6 阶段工作流）：**
1. 读取入口文档 → 2. 提取工程元素 → 3. 收集代码证据 → 4. 设计变更 → 5. 写入文档 → 6. 验证

**示例：**
```
/update-project-docs 初始化文档
/update-project-docs 总结 Modbus 协议变更，更新 docs/03-REF-Modbus协议.md
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

### 4. day_sum — 开发日报生成

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
xcopy /E /I day_sum %USERPROFILE%\.claude\skills\day_sum

# macOS / Linux
cp -r project-init ~/.claude/skills/
cp -r update-project-docs ~/.claude/skills/
cp -r code_zl ~/.claude/skills/
cp -r day_sum ~/.claude/skills/
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

> `project-init` 会自动检测未安装的工具并提示。`update-project-docs` 和 `code_zl` 无额外依赖。
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
→ 扫描 src/inc 目录 → 识别 MCU/RTOS/外设 → 生成 4 个文档
```

### 场景 3：代码注释整理

```
你：/code_zl src/modbus.c src/can.c

Claude：读取两个文件 → 添加标准函数头注释 → 添加行内注释
→ 输出汇总报告（+12 函数头, +35 行内注释）
```

### 场景 4：日报生成

```
你：总结今天的开发记录

Claude：读取 git log 或开发记录文件 → 按"发现问题/分析/解决"组织
→ 输出结构化日报
```

## 文档命名规范

所有 skill 生成的文档遵循统一命名：

```
{NN}-{TYPE}-{中文文档名}.md
```

| 代码 | 类型 | 示例 |
|------|------|------|
| ARC | 架构 | `01-ARC-系统架构.md` |
| REF | 参考 | `03-REF-Modbus协议.md` |
| SOP | 流程 | `05-SOP-OTA升级流程.md` |
| DBG | 调试 | `07-DBG-CAN通信排查.md` |
| TST | 测试 | `09-TST-热泵测试报告.md` |

## 规范

所有 skill 遵循 [writing-skills](https://github.com/anthropics/claude-code) 规范：

- frontmatter `description` 以 "Use when..." 开头，只描述触发条件
- 包含 `evals/evals.json` 测试用例
- 支持中英文触发词
- 不在 description 中描述 skill 的工作流程（防止 Claude 走捷径）

## License

MIT
