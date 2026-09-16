# Jovi Embedded Work Skills

> 嵌入式工程开发、Android 交付与 Windows 工作环境维护 Claude Code Skills 集合 — 新工程一键初始化、文档自动化、代码质量、Android 构建安装调试、日报生成与 C 盘数据整理。

专为嵌入式 C 工程（GD32/STM32/ESP32 + FreeRTOS + Modbus/CAN/UART）设计，开箱即用。

## 当前版本（2026-09-16）

本次新增 `code_sc`，并把 `code_wrt` 升级为带架构写入门禁的 V0.2.0。

| Skill | 版本 | 相对 GitHub 上一版 |
|---|---|---|
| `code_sc` | **V0.1.0** | 新增：Owner/边界/依赖环/调用关系/DTO/API/并发/硬件安全深度审查 |
| `code_wrt` | **V0.2.0** | V0.1.5 → 强制 code_sc 前后双门禁，防止写出 Owner 倒置、Fat Interface、peer mutation 等结构缺陷 |
| `update-project-docs` | **V1.1.0** | V1.0.0 → 全树清单、代码 diff 驱动、介绍面完成门 |
| `code_zl` | **V0.1.8** | V0.1.0 → 白话注释、先定义再使用、`// todo:`、任务目录注释 |
| `prj_zl` | **V0.1.0** | 号未升；与本地核对后同步（Keil `app/driver` 四层） |
| `clangd_init` | V1.1.0 | 本次未改 |

明细见仓库根 [`CHANGELOG.md`](CHANGELOG.md)。

## Skills 总览

```text
jovi-embedded-work/
├── project-init/              # 一键初始化工程工具链
├── update-project-docs/       # 文档 bootstrap + 日常维护
├── clangd_init/               # clangd 函数跳转 + 保存格式化
├── code_zl/                   # C 代码注释标准化
├── code_sc/                   # 嵌入式架构/调用/并发/硬件安全深度审查
├── code_wrt/                  # code_sc 门禁 + Ponytail + code_zl + code_sc 复审
├── prj_zl/                    # Keil 工程 app/driver 目录重组
├── day_sum/                   # 开发日报生成
├── child-claude/              # 多模型派发编排（父规划+审核，子执行）
├── codex-memory/              # 安全项目永久记忆（Obsidian / staging）
├── c-pan-reorganize/          # C 盘应用数据迁移 + 更新包/缓存安全清理
├── android-app-delivery/      # Android 制作、构建、安装与调试总控
├── android-build-release/     # Android 测试、构建、签名与 APK 校验
└── android-device-verify/     # ADB 预检、保留数据安装与设备调试
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
```text
/project-init D:\work\my-new-embedded-project
```

---

### 2. update-project-docs — 文档管理

**版本：** V1.1.0

**触发词：** `/update-project-docs`、`更新文档`、`初始化文档`、`setup docs`、`文件介绍`、`文档过期`

**功能：** 嵌入式工程文档全生命周期管理。首次运行只搭 5 个默认目录，后续按代码证据做 Full Refresh。

默认目录：

```text
docs/
├── README.md
├── GUIDE.md
├── 00-REF-参考/
├── 01-ARC-架构/
├── 02-SOP-操作/
├── 03-DBG-问题/
└── 04-LOG-记录/
```

---

### 3. clangd_init — clangd 跳转与保存格式化

**版本：** V1.1.0

**触发词：** `/clangd_init`

**功能：** 为当前嵌入式 C/C++ 工作区配置可验证的 clangd 函数跳转、查找引用和保存格式化。只读探查后按当前工程生成最小配置；不改生产固件逻辑，不全仓格式化。

---

### 4. code_zl — 代码注释标准化

**版本：** V0.1.8

**触发词：** `/code_zl`、`代码整理`、`注释整理`、`添加注释`、`批量注释`、`白话注释`

**功能：** 为嵌入式 C 工程添加标准化注释，遵循 Jovi 代码规范。纯注释/格式整理走本 skill；结构改写走 `/code_wrt`。

函数头格式：

```c
/*---------------------------------------------------------------------------
 Name        : static void modbus_parse_frame(uint8_t *buf, uint16_t len)
 Input       : buf - 接收缓冲区指针
               len - 帧长度（字节）
 Output      : 无
 Description : 解析 Modbus RTU 响应帧，提取寄存器值写入 dev_para。
---------------------------------------------------------------------------*/
```

---

### 5. code_wrt — 代码编写/简化/重构 + 架构门禁

**版本：** V0.2.0

**触发词：** `/code_wrt`、`写代码`、`代码简化整理`、`简化并注释`、`重构并整理`

**固定工作流：**

```text
code_sc(pre-write design gate)
        -> ponytail / implementation
        -> code_zl V0.1.8
        -> code_sc(post-write architecture gate)
```

V0.2.0 新增的核心限制：

- 一个状态/决策只有一个 Owner；
- `app/driver` 分层后还要检查 Application 内部 orchestration/policy/algorithm/safety/executor/observability；
- 跨模块只传必要 DTO/标量，不把 `sample/profile/protection/controller` 整体扔给算法；
- 公共头只暴露稳定合同，PI/search/private ctx 放私有头；
- 禁止 Algorithm -> Charge Stage/Protection/Driver 逆向依赖；
- 禁止 `charge/protection/output` peer-to-peer mutation 继续扩散；
- PWM/Relay 等关键硬件只有一个主循环写出口；
- 参数不能一值多义，例如 `0` 不能同时代表 hard-stop 和 soft-zero；
- 控制量区分 `candidate -> approved -> committed -> hardware`；
- 写完必须再用 `code_sc` 检查依赖环、Fat Interface、隐藏依赖、多写点、死接口。

**示例：**
```text
/code_wrt Application/app/src/mppt.c Application/app/src/charge.c
```

---

### 6. code_sc — 嵌入式深度代码审查

**版本：** V0.1.0

**触发词：** `/code_sc`、`代码审查`、`架构审查`、`调用关系审查`、`模块边界审查`、`ownership review`

**功能：** 找“代码能跑，但架构已经写歪”的问题。默认只读，不直接改代码。

重点审查：

- Ownership Inversion：子模块/controller 拥有不属于自己的业务状态机；
- Boundary Violation：算法知道 Charge Stage、Protection、Driver；
- Distributed State Machine：同一 Relay/Fault/Session 被两个模块用不同规则解释；
- Bidirectional Semantic Coupling：Stage 命令清算法 integral，算法状态又决定 Stage 是否恢复；
- Dependency Cycle/SCC：目录分层但 include/call graph 仍成环；
- Fat Interface：整个 `app_sample_t*` / profile / protection context 跨模块乱传；
- Type Ownership Error：类型定义在错误 header，逼出逆向 include；
- Hidden Dependency / Mixed Snapshot：函数已传 snapshot，内部又读 driver/latest；
- Multiple Sources of Truth：300W/PV×I/BAT×I 等限制多处重复重算；
- Peer-to-Peer Mutation：同层模块互相 setter；
- Semantic Overloading：同一值/flag 多种含义；
- Dead Contract / Zombie Interface：永远不产生的 action、永远 false 的 flag、迁移残留；
- PWM/Relay/COMP Break/ADC DMA/ISR/main 并发和恢复安全。

**典型输出：**

```text
P1 Ownership Inversion:
mppt_controller -> owns charge_stage_ctx
应有 Owner: charge_stage.c / charge.c
风险: MPPT 与 Charge FSM 会分别解释 Relay/session 生命周期，产生不同 reset 时机
整改: Stage 留 Application；算法只吃窄 DTO，返回 candidate Duty；Application 再审核
```

**示例：**
```text
/code_sc 审查 charge/mppt/protection/output 的 Owner、依赖和 PWM 安全
```

---

### 7. prj_zl — Keil 工程 app/driver 目录重组

**版本：** V0.1.0

**触发词：** `/prj_zl`、`工程整理`、`目录整理`、`应用驱动分离`、`app/driver 分层`

**功能：** 将 `Application` / `Bootloader` 整理为 `app/inc`、`app/src`、`driver/inc`、`driver/src`、`Project/MDK` 标准结构。注意：`prj_zl` 只解决物理目录分层；Application 内部责任边界由 `code_sc/code_wrt` 继续约束。

---

### 8. day_sum — 开发日报生成

**触发词：** `/day_sum`、`总结日报`、`daily summary`、`work summary`

**功能：** 从开发记录文件或 git log 生成结构化日报，按“发现问题 -> 分析 -> 解决”组织。

---

### 9. child-claude — 多模型派发编排

**触发词：** `/child-claude`、`派给子claude`、`用mimo干`、`换便宜模型`、`delegate to child claude`

**功能：** 父 Claude 规划/审核，把执行工作派发给子 Claude。

---

### 10. codex-memory — 安全项目永久记忆

**触发词：** `/codex-memory`、`加载项目记忆`、`归档项目记忆`、`Obsidian memory`、`project memory`

**功能：** 提供读取 -> 工作 -> 归档 -> 复盘的项目记忆闭环。

---

### 11. c-pan-reorganize — C 盘数据整理

**触发词：** `C盘清理`、`C盘空间不足`、`迁移应用数据到D盘`、`清理更新包`、`清理安全缓存`

**功能：** 审核 C 盘应用数据并做经授权的安全迁移/清理。

---

### 12. Android App Skill Suite — Android 制作、安装与调试

**版本：** v0.1.0

| Skill | 用途 |
|---|---|
| `android-app-delivery` | 协调识别、环境、构建、签名、安装、调试和报告 |
| `android-build-release` | 工具链、测试、lint、APK 构建及签名校验 |
| `android-device-verify` | ADB serial 预检、保留数据覆盖安装和限定日志采集 |

---

## 安装

### 方式一：git clone（推荐）

```bash
git clone https://github.com/Jovifei/Jovi-embedded-work-skill.git
cd Jovi-embedded-work-skill

# Windows
xcopy /E /I project-init %USERPROFILE%\.claude\skills\project-init
xcopy /E /I update-project-docs %USERPROFILE%\.claude\skills\update-project-docs
xcopy /E /I clangd_init %USERPROFILE%\.claude\skills\clangd_init
xcopy /E /I code_zl %USERPROFILE%\.claude\skills\code_zl
xcopy /E /I code_sc %USERPROFILE%\.claude\skills\code_sc
xcopy /E /I code_wrt %USERPROFILE%\.claude\skills\code_wrt
xcopy /E /I prj_zl %USERPROFILE%\.claude\skills\prj_zl
xcopy /E /I day_sum %USERPROFILE%\.claude\skills\day_sum
xcopy /E /I child-claude %USERPROFILE%\.claude\skills\child-claude
xcopy /E /I codex-memory %USERPROFILE%\.claude\skills\codex-memory
xcopy /E /I c-pan-reorganize %USERPROFILE%\.claude\skills\c-pan-reorganize
xcopy /E /I android-app-delivery %USERPROFILE%\.claude\skills\android-app-delivery
xcopy /E /I android-build-release %USERPROFILE%\.claude\skills\android-build-release
xcopy /E /I android-device-verify %USERPROFILE%\.claude\skills\android-device-verify

# macOS / Linux
cp -r project-init ~/.claude/skills/
cp -r update-project-docs ~/.claude/skills/
cp -r clangd_init ~/.claude/skills/
cp -r code_zl ~/.claude/skills/
cp -r code_sc ~/.claude/skills/
cp -r code_wrt ~/.claude/skills/
cp -r prj_zl ~/.claude/skills/
cp -r day_sum ~/.claude/skills/
cp -r child-claude ~/.claude/skills/
cp -r codex-memory ~/.claude/skills/
cp -r c-pan-reorganize ~/.claude/skills/
cp -r android-app-delivery ~/.claude/skills/
cp -r android-build-release ~/.claude/skills/
cp -r android-device-verify ~/.claude/skills/
```

### 方式二：直接下载

下载 ZIP 解压后，将每个 skill 目录复制到 `~/.claude/skills/`。

## 前置依赖

| 工具 | GitHub | 安装方式 | 用途 |
|---|---|---|---|
| CodeGraph | [colbymchenry/codegraph](https://github.com/colbymchenry/codegraph) | `npm install -g @colbymchenry/codegraph` | 代码知识图谱，MCP 提供代码探索能力 |
| code-review-graph | [tirth8205/code-review-graph](https://github.com/tirth8205/code-review-graph) | `pip install code-review-graph` | 代码审查图谱，变更影响分析 |
| comet | [rpamis/comet](https://github.com/rpamis/comet) | `npm install -g @rpamis/comet` | OpenSpec + Superpowers 五阶段工作流 |
| OpenSpec | [Fission-AI/OpenSpec](https://github.com/Fission-AI/OpenSpec) | `openspec init` | 需求/设计/任务结构化管理 |
| Superpowers | [obra/superpowers](https://github.com/obra/superpowers) | 随 comet 安装 | TDD、brainstorming、计划执行等 skill 体系 |

`code_sc` 可利用 CodeGraph/code-review-graph/clangd 辅助建立调用图，但没有这些工具时仍必须基于源码完成 Owner、边界和并发审查。

## 使用场景

### 场景 1：新工程初始化

```text
/project-init D:\work\stm32-sensor-hub
```

### 场景 2：代码注释整理

```text
/code_zl src/modbus.c src/can.c
```

### 场景 3：代码写入/重构

```text
/code_wrt Application/app/src/charge.c Application/app/src/mppt.c

Claude：先 code_sc 做 Owner/边界门 -> 实现/简化 -> code_zl -> code_sc 复审
```

### 场景 4：深度架构审查

```text
/code_sc 审查 Application 内部 charge/mppt/protection/output/debug 的调用关系

Claude：Owner 表 -> include/call graph -> 状态机/会话 -> API/DTO -> 硬件单写点 -> ISR/主循环并发 -> P0/P1/P2 问题表
```

### 场景 5：Keil 工程目录重组

```text
/prj_zl Application Bootloader
```

## 文档命名规范

所有 skill 生成的文档遵循统一命名：

```text
{NN}-{TYPE}-{中文文档名}.md
```

| 代码 | 类型 | 目录 | 示例 |
|---|---|---|---|
| REF | 参考 | `00-REF-参考/` | `01-REF-Modbus协议.md` |
| ARC | 架构 | `01-ARC-架构/` | `01-ARC-系统架构.md` |
| SOP | 操作 | `02-SOP-操作/` | `01-SOP-固件烧录.md` |
| DBG | 问题 | `03-DBG-问题/` | `01-DBG-CAN通信排查.md` |
| LOG | 记录 | `04-LOG-记录/` | `01-LOG-开发记录202608.md` |

## 规范

所有 skill 遵循 writing-skills 约定：

- frontmatter `description` 以 `Use when...` 开头，只描述触发条件；
- 包含 `evals/evals.json`；
- 支持中英文触发词；
- 不在 description 中泄漏完整工作流。

## License

MIT
