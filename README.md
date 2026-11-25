# Jovi Embedded Work Skills

> 嵌入式工程开发、Android 交付与 Windows 工作环境维护 Claude Code Skills 集合 — 新工程一键初始化、文档自动化、注释整理、架构审查、写代码门禁、源码学习资料、Android 构建安装调试、日报生成与 C 盘数据整理。

专为嵌入式 C 工程（GD32/STM32/ESP32 + FreeRTOS + Modbus/CAN/UART）设计，开箱即用。

## 当前版本（2026-11-25）

版本号以各 skill 目录 `SKILL.md` 文首 `**Version:**`（或 `VERSION` 文件）为准；本表必须与之同步。明细见 [`CHANGELOG.md`](CHANGELOG.md)。

### 重构原则与四项技能更新（2026-11-25）

- [工程与代码重构原则 v1.1](docs/refactoring/Embedded_Refactoring_Principles.md)：团队使用的完整规范，包含通用原则、C300 专属合同、历史待办与每批修改记录模板。
- [AGENTS 重构执行模板 v1.1](docs/refactoring/AGENTS_Refactoring_Template.md)：先填项目约束，再合并到目标工程已有规则；不直接覆盖 AGENTS.md。
- `prj_zl` 管文件和构建引用，`code_wrt` 管已授权的代码变化，`code_sc` 做证据审查，`code_zl` 整理真实注释。逻辑职责不强制变成额外文件，C300 的六任务、原库和阈值不能套用其他项目。
- 正常功率动作统一审核，硬件/驱动 ISR 仍立即关断；区分命令下行和事件上行、真实时间与样本次数、主机与实板证据。沿既有授权推进，不因模板或可选工具缺失重复审批。
- 每个 skill 的核心与 references 都在自身目录，可单独复制使用；详细合同按任务读取，避免每轮加载历史规则全文。保留原 `/code_sc` 等命令名。
- 本轮验证与边界见 [验证记录](tests/EMBEDDED_SKILL_VALIDATION.md)。更新仓库不等于自动更新各电脑已复制的 skill；使用前核对版本。

### 文档技能更新（2026-09-29）

[两种文档技能的分工与验证](DOCUMENTATION-SKILLS.md)。

### 代码技能加固（2026-10-15）

参考 MPPT V0.15.28 的命名、布局与精简经验，强化真实消费者、完整函数签名和改名闭环。结构体相同声明类型分别集中，同类内保留原顺序，bool 与 uint8_t 分组；固定 Flash/协议/DMA/ABI 布局保留。`code_zl` 只检查并报告成员交错，授权结构调整由 `code_wrt` 完成，`code_sc` 检查初始化器及布局依赖。分组不改变函数形参顺序，也不在缺少目标布局证据时承诺 RAM 收益。

| Skill | 版本 | 说明 |
|---|---|---|
| `code_sc` | **V0.3.4** | 按实际后果和证据审查职责、时间、功率及部署；按需加载检查表 |
| `code_wrt` | **V0.4.3** | 区分结构/修复/功能/优化，简洁分层，沿既有授权分阶段执行 |
| `code-study` | **V2.0.0** | 按运行阶段与功能写完整口语图文教程；配模块/原函数、参数、状态机及离线阅读器 |
| `product-doc` | **V1.0.0** | 新增：源码驱动的产品说明、运行逻辑、参数台账、保护恢复与验收清单 |
| `update-project-docs` | **V1.1.0** | Full Refresh 全树清单 + 介绍面完成门（纯文档不升固件版本） |
| `code_zl` | **V0.2.11** | 按源码、上下文和证据解释注释，不套用单工程调度和硬件结论 |
| `prj_zl` | **V0.2.0** | 按范围迁移目录与构建引用，核对路径、依赖及部署消费者 |
| `clangd_init` | **V1.1.1** | clangd 跳转、Ctrl+S 保存格式化和可复现配置资源 |

### 全量版本清单

| Skill | 版本 | 一句话 |
|---|---|---|
| `project-init` | 未编号 | 工程工具链一键 init |
| `update-project-docs` | **V1.1.0** | 文档 bootstrap + Full Refresh |
| `clangd_init` | **V1.1.1** | clangd 跳转与 Ctrl+S 格式化 |
| `code_zl` | **V0.2.11** | 注释、签名、声明布局和命名语义检查 |
| `code_sc` | **V0.3.4** | 架构、状态、消费者与安全时序审查 |
| `code_wrt` | **V0.4.3** | 按范围完成编码、等价重构与验证 |
| `code-study` | **V2.0.0** | 分阶段口语图文源码学习书 |
| `product-doc` | **V1.0.0** | 产品说明、运行逻辑与可追溯参数 |
| `prj_zl` | **V0.2.0** | Keil 路径、成员与工程合同迁移 |
| `day_sum` | 未编号 | 开发日报 |
| `child-claude` | 未编号 | 多模型派发编排 |
| `codex-memory` | 未编号 | 项目永久记忆 |
| `c-pan-reorganize` | 未编号 | C 盘迁移与安全清理 |
| `android-app-delivery` | **v0.1.0** | Android 交付总控 |
| `android-build-release` | **v0.1.0** | Android 构建与签名校验 |
| `android-device-verify` | **v0.1.0** | ADB 安装与设备调试 |

## Skills 总览

```
jovi-embedded-work/
├── project-init/              # 一键初始化工程工具链
├── update-project-docs/       # 文档 bootstrap + 日常维护（V1.1.0）
├── clangd_init/               # clangd 函数跳转 + 保存格式化（V1.1.1）
├── code_zl/                   # C 代码注释标准化（V0.2.11）
├── code_sc/                   # 架构 / Owner / 安全时序审查（V0.3.4）
├── code_wrt/                  # 分阶段编码与复核，按需使用配套技能（V0.4.3）
├── code-study/                # 分阶段口语图文学习书（V2.0.0）
├── product-doc/               # 产品说明与运行参数（V1.0.0）
├── prj_zl/                    # Keil 工程目录与构建引用整理（V0.2.0）
├── day_sum/                   # 开发日报生成
├── child-claude/              # 多模型派发编排（父规划+审核，子执行）
├── codex-memory/              # 安全项目永久记忆（Obsidian / staging）
├── c-pan-reorganize/          # C 盘应用数据迁移 + 更新包/缓存安全清理
├── android-app-delivery/      # Android 制作、构建、安装与调试总控（v0.1.0）
├── android-build-release/     # Android 测试、构建、签名与 APK 校验（v0.1.0）
└── android-device-verify/     # ADB 预检、保留数据安装与设备调试（v0.1.0）
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

**版本：** V1.1.0

**触发词：** `/update-project-docs`、`更新文档`、`初始化文档`、`setup docs`、`文件介绍`、`文档过期`

**功能：** 嵌入式工程文档全生命周期管理。首次运行只搭 **5 个默认目录**，禁止生成 11 个空类型文件夹。后续进入 6 阶段文档维护工作流。

V1.1.0：裸 `/update-project-docs` 或代码刚改完走 **Full Refresh**——`docs/` 下每个 `.md` 都要有结论；先读 `SOFT_VERSION` 和关键宏，再回写 README/GUIDE/`00-阅读指引` 的文件介绍。禁止只改几篇专题就声称全部完成。

**默认目录：**

```text
docs/
├── README.md
├── GUIDE.md
├── 00-REF-参考/     # 手册、原理图、协议表、参数表
├── 01-ARC-架构/     # 当前固件怎么工作
├── 02-SOP-操作/     # 编译、烧录、台架；IDE 跳转见 /clangd_init
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

### 3. clangd_init — clangd 跳转与保存格式化

**版本：** V1.1.1

**触发词：** `/clangd_init`

**功能：** 为当前嵌入式 C/C++ 工作区配置可验证的 clangd 函数跳转、查找引用和保存格式化。只读探查后按当前工程生成最小配置；不改生产固件逻辑，不全仓格式化。无 `.clang-format` 且确认 Jovi 规范时，使用当前 `code_zl` 模板（`ColumnLimit: 0`、宏对齐、控制语句 `{` 换行）；格式化器必须是 clangd。

**验收：**

- 跨文件**调用点** F12 返回实际 Location（C 可能先到 `.h` 声明，索引后再到 `.c` 实现）
- 保存一个手工维护的 `.c` / `.h` 时，格式遵循 `.clang-format`，`.h` 声明+行尾 `//` 保持单行，且没有无关文件被改写
- `clangd --check` 只证明解析，不能单独当作跳转成功

**规则摘要：**

- `compile_commands.json` 与 `compile_flags.txt` 二选一或共存，不无条件生成两份
- 多 Target 必须先选定一个，禁止混合 AP/IAP 的宏和源文件
- 已有 `.clang-format` 不覆盖；新建时优先 code_zl 模板，不把精简 Allman 强加给已有工程
- `*.h` 关联为 `c`，`[c]` 使用 clangd 作为默认 formatter；配置后 Reload Window
- `compile_commands.json` 本地生成并 gitignore；受版本控制的 flags 不得含本机绝对路径

**示例：**
```
/clangd_init
```

完成后执行 `Clangd: Restart language server`，再在调用点按 F12。

---

### 4. code_zl — 代码注释标准化

**版本：** V0.2.11

**触发词：** `/code_zl`、`代码整理`、`注释整理`、`添加注释`、`批量注释`、`白话注释`

**功能：** 为嵌入式 C 工程添加标准化注释，遵循 Jovi 代码规范。支持单文件和多文件并行处理。V0.2.1 起除 Comment-to-Code 真值核对外，增加注释经济性：函数头只写接口合同，行内只写非显然原因，同一事实只保留一个注释 Owner；候选值、已批准值、驱动设定值、物理已生效值必须分开表述，结构改写仍走 `/code_wrt`。

按实际差异补齐合同头和关键逻辑行。详细样式、运行合同与格式流程按需读取本目录 references；不把固定 1ms、某种恢复拆法或特定芯片效果写成通用事实。明确指定逐行时按给定粒度处理。暂存版与工作区分别核对。用实际条件、读写和消费者解释有效位、零值、预览、缓存与候选结果。声明和大括号的等价整理适用于明确允许格式或布局调整的范围。

**Ctrl+S 格式化：** 配合 `clangd_init` 和 `llvm-vs-code-extensions.vscode-clangd` 使用。工程已有 `.clang-format` 时保留并直接作为唯一格式来源；`code_zl/references/clang-format` 与 `vscode-settings.json` 作为可复现模板。启用 `editor.formatOnSave`、C/C++ 默认 formatter 为 clangd，并关闭 Microsoft C/C++ IntelliSense formatter；修改后 Reload Window，再用一份手工维护的 `.c/.h` 文件验证保存格式化。

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
- **`.c` 分节**：`/* 主循环 */`（短标题，禁止 `====` 装饰）
- **`.h` 分节**：`//=================== 标题 ===========================`
- 驱动 Init：分节标题说明「配了什么」+ 少量关键行尾 `//`，不逐行注释寄存器
- 授权整理范围内的 `.h`：按项目样式为宏、枚举、结构体字段和 API 保留简短行尾说明，不扩展到无关文件

**示例：**
```
/code_zl src/modbus.c src/can.c inc/main.h
代码整理（自动检测 git diff 暂存区文件）
```

---

### 5. code_sc — 架构、行为与安全证据审查

**版本：** V0.3.4

**触发词：** `/code_sc`、代码审查、调用关系审查、模块边界审查、PWM 安全、中断竞争。

核对本次实际基线、状态所有权、调用/写入链、候选与实际输出、安全时间点、采样/时间、持久化、升级和部署。纯审核默认只读；已经授权修复的范围可承接 `code_wrt`，无需重复请示。

核心流程保持简短，按需读本目录 references。严重性依据可达后果，不能凭架构形状、没有直接 include 或缺少板测自动判 P0/P1。保留预处理、向量、ABI、合并后复审、缓存/预览、复位与生命周期检查。

输出事实、触发条件、因果链、影响、最小修复与验证，区分遗留/新增/批准变化/未完成要求。SOURCE、HOST、目标构建和 BOARD 各自报告，不继承旧版本 PASS。

```text
/code_sc Application/app/src/charge.c Application/app/src/output.c
```

---

### 6. code_wrt — 分阶段代码实施与复核

**版本：** V0.4.3

**触发词：** `/code_wrt`、写代码、代码简化整理、重构并整理、函数或接口改名。

先固定当前基线、保留项和本批验证，再区分结构整理、BUG 修复、批准功能变化及性能优化，分批实现、复核和同步文档。保留可靠路径，按实际职责分层，不强制为每层增加文件、DTO 或 MPPT 包装。

正常功率提交集中审核，驱动 ISR 的紧急关断保持立即执行；按合同处理库/ABI、采样失效、计时与 WDT、配置事务、首装和升级。项目数值和库选择由项目给定。

可用时复用 `code_sc`、`code_zl` 或其他辅助工具；本 skill 提供独立执行所需合同。可选工具缺失时使用等效源码/构建/验证方法并说明边界，继续完成已授权且可完成的工作。验证深度与改动风险相称。

```text
/code_wrt src/modbus.c src/can.c
```

---

### 7. code-study — 分阶段口语图文学习书

**版本：** V2.0.0

**触发词：** `/code-study`、`$code-study`、`源码学习`、`重做learning`、`图文并茂`、`看不懂术语`

**功能：** 在当前项目 `docs/code-study/<源码基线>/` 先写按实际运行阶段与功能组织的完整教程：动作、原因、参数与条件、具体例子、失败去向、状态机和答案。模块与函数页是查询层，不用阅读清单代替正文。函数页仍先展示完整原函数体与原注释，再解释。

**配套：** Markdown、SVG/DOT、递归全文索引、唯一离线阅读入口`index.html`，支持图放大和源码行定位。提供机械校验、逐章复审模板、浏览器检查和合成测试；检查通过不等于讲解全对或固件安全。

**边界：** 默认项目目录交付，不改业务源码、不自动归档或提交。仅本次明确授权才交附件/ZIP或推送；不把前一项目的参数和章数写成通用规定。安装须复制完整目录，见[安装说明](code-study/INSTALL.md)。

```text
$code-study 基于当前源码重做learning，按运行阶段和功能讲，使用口语、实际参数、例子和流程图，不改固件。
```

---

### 8. prj_zl — 工程目录与构建引用整理

**版本：** V0.2.0

**触发词：** `/prj_zl`、工程整理、目录迁移、app/driver 文件归属、Keil 路径修正。

按实际职责和现有布局建立旧→新→目标→引用映射，更新受影响的 XML、include、链接和部署消费者。保留目标设置、用户改动、SDK/闭源库可复现依赖。目录移动与真正 MCU 解耦分别验收。

不默认重命名 IAP 工程，不默认忽略整个 Libraries；相对 include 失效时允许最小等价修正。system/startup 按供应商/链接合同保留位置；混合职责文件需要结构改动时转 `code_wrt`。

附只读 [Keil 路径检查器](prj_zl/scripts/check_keil_paths.py)，区分字面路径问题与需要人工解析的动态/跨主机引用；它不代替 Keil 构建或板测。

```text
/prj_zl Application Bootloader
/prj_zl Application
```

---

### 9. day_sum — 开发日报生成

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

### 10. child-claude — 多模型派发编排

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

### 11. codex-memory — 安全项目永久记忆

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

### 12. c-pan-reorganize — C 盘数据迁移与安全清理

**触发词：** `C盘清理`、`C盘空间不足`、`迁移应用数据到D盘`、`清理更新包`、`清理安全缓存`

**功能：** 审核 C 盘应用数据，将已授权且不在运行的数据迁移到 `D:\Document` 或 `D:\Documents` 的独立目录，并保留原路径 junction；同时区分可清理更新包、可重建缓存和必须保护的聊天数据库、项目数据、凭据及系统文件。

**安全边界：**

- 清理更新包或缓存不等于卸载软件；卸载/重装必须单独明确授权。
- 迁移前确认应用已退出、目标目录不冲突，迁移后核对 junction、文件数、字节数与 C/D 盘空间。
- 不手动删除 `pagefile.sys`、`hiberfil.sys`、`$WinREAgent`、活动数据库或当前聊天记录。

**示例：**
```
/c-pan-reorganize 审核 C 盘可清理缓存，并将已关闭的飞书和钉钉数据迁移到 D:\Document
```

---

### 13. Android App Skill Suite — Android 制作、安装与调试

**版本：** v0.1.0（首次发布）

这组三层 skill 面向 Windows PowerShell，支持 Gradle/Compose、Flutter、React Native：

| Skill | 用途 |
|------|------|
| `android-app-delivery` | 接收项目路径和主题，协调识别、环境、构建、签名、安装、调试和结构化报告 |
| `android-build-release` | 独立完成工具链、测试、lint、APK 构建及 `aapt2`/`apksigner` 校验 |
| `android-device-verify` | 独立完成 ADB serial 预检、同签名 `adb install -r` 覆盖安装和限定日志采集 |

实体设备只允许保留数据的同签名 Release 覆盖安装；解锁、登录、验证码、Tesla 授权、虚拟钥匙和系统权限由用户人工完成。缺少系统级工具、包名或签名证据时，skill 会暂停并报告阻断原因。

---

### 14. product-doc — 产品说明与运行参数

**版本：** V1.0.0

**触发词：** `/product-doc`、`$product-doc`、`产品说明文档`、`运行逻辑参数写进去`、`启动电压/满功率/限流`

**功能：** 基于当前源码与有效配置，按真实功能组合产品说明、启动和执行、业务档案、功率调节、保护恢复、通信设置保存升级及验收专题。参数既查定义，也追实际使用处，记录条件、单位、比较符和时间。软件默认、活动逻辑、推导、实测与未知分别标明。

**交付：** Markdown、参数/保护/验收CSV、SVG/DOT和离线HTML；需要正式评审或可编辑合订本时再导出Word并逐页检查。默认不改固件、不提交、不把软件预算写成产品实测保证。与code-study独立使用，详见[product-doc](product-doc/SKILL.md)。

```text
$product-doc 基于当前代码做详细产品说明，把运行参数、预备条件、失败和恢复写进正文与图，附参数台账；不改代码。
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
xcopy /E /I clangd_init %USERPROFILE%\.claude\skills\clangd_init
xcopy /E /I code_zl %USERPROFILE%\.claude\skills\code_zl
xcopy /E /I code_sc %USERPROFILE%\.claude\skills\code_sc
xcopy /E /I code_wrt %USERPROFILE%\.claude\skills\code_wrt
xcopy /E /I code-study %USERPROFILE%\.claude\skills\code-study
xcopy /E /I product-doc %USERPROFILE%\.claude\skills\product-doc
xcopy /E /I prj_zl %USERPROFILE%\.claude\skills\prj_zl
xcopy /E /I day_sum %USERPROFILE%\.claude\skills\day_sum
xcopy /E /I child-claude %USERPROFILE%\.claude\skills\child-claude
xcopy /E /I codex-memory %USERPROFILE%\.claude\skills\codex-memory
xcopy /E /I c-pan-reorganize %USERPROFILE%\.claude\skills\c-pan-reorganize
xcopy /E /I android-app-delivery %USERPROFILE%\.claude\skills\android-app-delivery
xcopy /E /I android-build-release %USERPROFILE%\.claude\skills\android-build-release
xcopy /E /I android-device-verify %USERPROFILE%\.claude\skills\android-device-verify

# Codex / agents 的文档技能（安装前备份个人修改）
xcopy /E /I code-study %USERPROFILE%\.agents\skills\code-study
xcopy /E /I product-doc %USERPROFILE%\.agents\skills\product-doc

# macOS / Linux
cp -r project-init ~/.claude/skills/
cp -r update-project-docs ~/.claude/skills/
cp -r clangd_init ~/.claude/skills/
cp -r code_zl ~/.claude/skills/
cp -r code_sc ~/.claude/skills/
cp -r code_wrt ~/.claude/skills/
cp -r code-study ~/.claude/skills/
cp -r product-doc ~/.claude/skills/
cp -r prj_zl ~/.claude/skills/
cp -r day_sum ~/.claude/skills/
cp -r child-claude ~/.claude/skills/
cp -r codex-memory ~/.claude/skills/
cp -r c-pan-reorganize ~/.claude/skills/
cp -r android-app-delivery ~/.claude/skills/
cp -r android-build-release ~/.claude/skills/
cp -r android-device-verify ~/.claude/skills/
mkdir -p ~/.agents/skills && cp -r code-study product-doc ~/.agents/skills/
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

> `project-init` 会自动检测未安装的工具并提示。`update-project-docs`、`clangd_init` 和 `code_zl` 无额外依赖（`clangd_init` 需要 Cursor/VS Code 的 clangd 扩展）。
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

### 场景 3：clangd 跳转与保存格式化

```
你：/clangd_init

Claude：探查 uvprojx 与现有 compile_flags/compile_commands
→ 单 Target 生成或复用编译配置，不全仓格式化
→ 无 .clang-format 且确认 Jovi 时复制 code_zl 模板；formatter 必须是 clangd
→ clangd --check 证明解析；调用点 F12 返回 Location 才算跳转成功
→ 提示 Reload Window + Restart language server
```

### 场景 4：代码注释整理

```
你：/code_zl src/modbus.c src/can.c

Claude：读取两个文件 → 添加标准函数头注释 → `.c` 用 `/* 分节 */`、`.h` 用 `//=======` 分节
→ Init 只写「配了什么」分节，不逐行注释寄存器
→ 输出汇总报告（+12 函数头, +35 行内注释）
```

### 场景 5：架构审查（code_sc）

```
你：/code_sc Application/app/src/charge.c Application/app/src/mppt.c

Claude：读本轮合同与调用链 → 按实际范围记录 Owner、依赖与写点
→ 审 PWM 第一拍/最后一拍、COMP/Break ISR guard、TOCTOU、snapshot generation、lifecycle owner
→ 按已证明后果分级，区分 BUG、结构问题、证据缺口及 SOURCE/HOST/TARGET/BOARD 证据
→ 纯审查保持只读；已有整改授权则继续完成范围内修复
```

### 场景 6：写代码门禁（code_wrt）

```
你：/code_wrt Application/app/src/mppt.c

Claude：确认保留合同与四类变化 → 按风险做写前检查
→ 分批实现与针对性验证 → 注释、完整签名与真实消费者检查
→ 写后复核和交付；按需复用 code_sc/code_zl，辅助技能缺失不阻断可做工作
```

### 场景 7：源码学习资料（code-study）

```
你：/code-study 为当前项目制作完整代码学习资料

Claude：在项目 docs/code-study/<基线>/ 先写分阶段教程，再链接模块/完整函数
→ 条件、参数、例子、失败流程和答案写进正文；生成唯一 index.html 阅读搜索页
→ 递归检查目录和索引；默认不打包、不改业务源码
```

### 场景 8：Keil 工程目录重组

```
你：/prj_zl Application Bootloader

Claude：按实际职责列旧→新映射，沿用可工作的现有布局
→ 迁移授权范围内的文件，同步全部 target、include 与部署消费者
→ 检查成员、路径和保留选项，执行可用的本版构建
→ 记录文件迁移、硬件隔离、目标构建和实板验证各自状态
```

### 场景 9：日报生成

```
你：总结今天的工作

Claude：读取 git log 或开发记录文件 → 按"发现问题/分析/解决"组织
→ 输出结构化日报
```

### 场景 10：跨会话项目记忆

```
你：/codex-memory load

Claude：解析 profile 与项目 ID → 读取最小全局偏好及当前项目概览/计划/进度
→ 输出带来源、长度受限且已脱敏的上下文摘要

你：完成任务后 /codex-memory --dry-run

Claude：优先审计 docs/README.md、docs/GUIDE.md、Git 与验证证据
→ 预览受管区块更新；确认后才归档并写入成功事件
```

### 场景 11：C 盘数据迁移与安全清理

```
你：/c-pan-reorganize 审核 C 盘空间，将已关闭的飞书和钉钉数据迁移到 D:\Document

Claude：先只读统计 C 盘数据和进程 → 确认目标目录与用户授权
→ 移动精确数据目录并建立 junction → 核对文件数、字节数和 C/D 盘空间
```

## 文档命名规范

通用项目文档遵循下列命名；`code-study`和`product-doc`分别使用其基线目录及章节/参数文件约定：

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
