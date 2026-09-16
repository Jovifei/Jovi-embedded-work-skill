---
name: code_wrt
description: "Use when the user invokes /code_wrt or asks to simplify embedded C code and then standardize its comments, organization, or formatting. Triggers include code_wrt, 代码简化整理, 简化并注释, 简化并整理."
---

# Code WRT

**Version: V0.1.5**

执行固定组合：`ponytail → code_zl`。前者负责最小化代码，后者负责按 Jovi 规范整理注释和格式。

## 版本记录

- **V0.1.5**：第二阶段对齐 **code_zl V0.1.8**（白话注释、先定义再使用、`// todo:`）。不得再按 V0.1.5 粒度收工。
- **V0.1.4**：收工前强制固件 `SOFT_VERSION`（`Vx.y.z`）与 `docs/版本更改/` 同阶段长文档追加；赶工/「别搞文档」不得跳过行为改。当时第二阶段加载 **code_zl V0.1.5**。
- **V0.1.3**：任务入口必须在功能 `.c`（充电→`charge.c`，保护→`protection.c`，采样→`sample.c`，输出→`output.c`，串口/遥测→`debug.c`）。`main()` 只按层排列 `app_task_*`；没有对应功能文件的才留 `main.c`。一个任务函数包含该任务近乎全部功能。禁止巨型 `app_task_control` 把充电/PWM/Relay 捆在 `main.c`。软件保护跟主循环 1ms 标志走，**不进 SysTick**。第二阶段加载 **code_zl V0.1.5**。
- **V0.1.2**：补充函数书写与调用：一职一函数、调度函数只排列调用、硬件单写出口、谁决定何时跑。第二阶段加载 **code_zl V0.1.4**。
- **V0.1.1**：触碰保护模块或 main 节拍时，必须改成微逆风格：`Fault_Detection` 只调度、一故障一类 `Fault_*`（检测+已有恢复同函数）；`main()` 是任务目录，按紧急程度分 ISR 直接执行 / 主循环见标志 / 主循环每圈。禁止巨型 `app_task_1ms` 把串口/LED/遥测/控制塞一起。UART/ADC：ISR 只搬字节或产数，协议与转换在对应任务。第二阶段加载 **code_zl V0.1.3**。
- **V0.1.0**：首次版本化。第二阶段必须加载 **code_zl**（`.c` 短分节、`.h` 等号分节且标题下一行即代码、Init 注释粒度、clangd 保存格式化）。不得凭记忆模拟旧的 `/* ==================== */` `.c` 分节。

## 必需子技能

**REQUIRED SUB-SKILL:** 修改前完整加载并应用 `ponytail`，默认使用 `full` 强度。

**REQUIRED SUB-SKILL:** 完整加载并应用 `code_zl`（当前 **V0.1.8**）。

任一技能不可用时停止修改并说明原因，不得凭记忆模拟其规则。

## 工作流

1. 确定用户指定的文件范围，读取项目规范、目标文件及必要调用点。
2. 先执行 `ponytail`：删除或内联冗余代码，复用现有能力，做最小的行为保持式简化。
3. **故障、节拍、函数书写与调用门禁**（触碰 `protection.c` / `Protect.c` / `main` 主循环 / 定时器 ISR / 任务拆分时必须执行，见下文专节）：把结构改成微逆风格。这是本技能允许的结构调整，不算改阈值或协议。
4. 检查第一阶段 diff；不得改变公开接口、协议语义、硬件访问顺序、RTOS 时序、并发保护、错误处理或外部可观察行为。第 3 步的 ISR/标志分层和 `Fault_*` 拆分除外，但故障判据、阈值、恢复条件必须保持原样。
5. 再执行 `code_zl`：基于简化后的最终代码整理文件结构、注释、分节和对齐。`code_zl` 的“不修改代码逻辑”约束只作用于本阶段。
6. 注释质量门禁：函数头必须写清数据流、条件、状态/硬件副作用和失败路径；函数体只在关键分支、循环、寄存器顺序、保护与恢复路径写 `//`，禁止把函数头 Description 复制到函数体。
7. **Init 粒度门禁**（code_zl 二点六）：驱动 Init / SysClk 用 `/* 分节：一句话说明配了什么 */`，不要逐行注释 DDL 字段，也不要写大段原理。
8. **分节格式门禁**：`.c` 用 `/* 标题 */`；`.h` 用 `//=================== 标题 ===========================`。禁止在 `.c` 使用 `====` 装饰。
9. 配置门禁：触碰 `config.h` 或 `fun_*Config()` 时，每个有效宏必须写明具体用途、单位/枚举语义和当前值/表达式；配置初始化函数前必须有“分组/字段/当前宏值/单位/下游用途”表格，赋值行逐行标注宏来源。
10. 编码和行为门禁：保持原文件编码，批量注释前建快照，最终用去注释令牌流对比证明代码逻辑、宏值、函数签名和硬件访问顺序未变；再运行最小相关构建或测试。无法验证时明确说明。
11. **固件版本与 `docs/版本更改/` 门禁**（见下文专节）：凡本轮改了会进镜像的行为/宏/结构，收工前必须升 `SOFT_VERSION` 第三位，并在同阶段长文档**追加一节**；禁止只改代码不记文档。

## 固件版本与版本更改文档（收工前必须）

**适用工程**：`mppt-charger-300w`（及同约定的 Jovi 嵌入式仓）。**违反字面即违反精神。**

### 版本号 `Vx.y.z`（两个点、三位数字）

| 位 | 含义 | 例子 |
|---|---|---|
| `x` | 大系列；`0`=测试/未量产 | `V0.…` |
| `y` | **阶段**：同一阶段共用一份 `docs/版本更改/` 长文档 | `V0.12.…` → 文件 `V0.12.0….md` |
| `z` | **每次进镜像的改动 +1**（相对上一烧录语义） | `V0.12.44` → `V0.12.45` |

- 读 `Application/app/inc/main.h` 的 `SOFT_VERSION`，只递增 **z**；`y` 不变则**禁止**新建平行「更新记录」文件。
- `y` 升级（如 `V0.12`→`V0.13`）时才新建 `docs/版本更改/V0.13.0….md`（用户要求或明确开新阶段时）。
- 现网阶段：`V0.12.x` → 追加 [`docs/版本更改/V0.12.0应用层收敛-修改更新.md`](../../docs/版本更改/V0.12.0应用层收敛-修改更新.md)。
- 同步 `docs/README.md` 文首「当前固件」到新 `SOFT_VERSION`。

### 何时必须升版本并写文档

改了会进固件镜像的内容即必须做（含 `/code_wrt` 合入的结构调整、阈值/宏、保护/充电/驱动行为）：

1. `SOFT_VERSION`：`z + 1`
2. 同阶段长文档**文末追加一节**（格式见下）
3. 需要时改 `docs/README.md` 当前固件行

### 一节写法（相对上一版，禁止空话）

```markdown
## V0.12.xx — 一行标题（现象或目标）

日期：YYYY-MM-DD。相对 V0.12.yy。默认宏状态（如 STAGE/TEL/NTC）。

### 目的 / 目标
- 现象 / 根因 / 期望现场行为（可用产品口述）

### 改了什么
- **文件或模块**：具体差分（函数名、宏名、阈值）

### 明确不做
- 本版边界

### 验证
- ⚠️ 未上板：… 或 ✅ 用户确认台架结果
```

### 例外（唯一）

仅当用户**明确**说「先别升版本 / 只改注释不记版本」：可跳过，但回复必须点明未升版本。  
**下列借口一律无效**：赶工、用户说「别搞文档」、纯整理/注释但实际改了宏或行为、`code_zl` 阶段「不改逻辑」所以不记、改天补文档。

### 红旗 — 停下补文档

- 行为/宏已改，回复里没有新 `SOFT_VERSION`
- 新建了与当前 `y` 平行的「更新记录」而不是追加同阶段长文档
- 节里只有「优化结构」没有目的/函数/宏
- 把未上板目标写成 BOARD_PASS

## 故障检测/恢复与节拍调度（微逆风格，必须改结构）

权威参考：微逆 `Protect.c`（`Fault_Detection` + `Fault_PV2DSVoltage`）和 `main.c`（任务目录）。微逆把保护放定时器回调；**本工程经安全复审后软件保护跟主循环 1ms 标志走，SysTick 只 `drv_time_tick_isr()`，禁止把 `Fault_*` 塞回 SysTick。** 本工程对应 `protection.c` / `main`。

触碰这些文件时，**ponytail 阶段就必须改成下面结构**，不要留给 code_zl。阈值、确认窗、有无软件自恢复不得发明或删改。

### 故障模块

- `Fault_Detection()` **只调度**：按固定顺序调用 `Fault_*`，不写具体判据。
- 一故障类一个 `Fault_Xxx(ctx)`。**检测和已有软件自恢复写在同一函数**（先检测，后 `/* xxx 恢复 */`）。
- 没有软件自恢复的不要发明恢复；锁存故障走 STOP / 硬恢复窗口。
- 保护函数只置故障位，不关 PWM / 不 HardTrip（由 ISR 或输出层做）。
- 命名 `Fault_*`，不是 `prot_*`。不要 `prot_step_in_t` 入参包；用 ctx + 文件级采样快照。
- `Fault_Detection` 每行调用尾注 `// 中文故障名`。

```c
static void Fault_Detection(void)
{
    Fault_BatOverVoltage(s_ctx);   // BAT 过压
    Fault_PvUnderVoltage(s_ctx);   // PV 欠压
}

static void Fault_PvUnderVoltage(app_protection_ctx_t *ctx)
{
    /* PV 欠压检测 */
    if (s_run_mode && (s_sample->pv_mv < APP_PV_UNDERVOLT_MV))
    {
        set_fault(ctx, APP_FAULT_PV_UNDERVOLT, false);
    }
    else if ((ctx->active.data & APP_FAULT_PV_UNDERVOLT) != 0U)
    {
        /* PV 欠压恢复 */
        ...
    }
}
```

禁止：巨型 `app_protection_step` 内联全部判据；`Fault_Xxx` + `Fault_XxxRecover` 拆成两个函数；ISR 与主循环各跑一遍 `Fault_Detection`（只在 `app_task_protect`）。

### 节拍：先问紧急不紧急、要不要精确 1ms

`main()` 是任务目录：每个功能一个 `app_task_*`，在 `while (1)` 里按层调用。禁止再做一个巨型 `app_task_1ms` 或 `app_task_control` 把串口/LED/遥测/充电/PWM 捆在 `main.c`。

| 层 | 何时跑 | 放什么 | 禁止 |
|---|---|---|---|
| 外设 ISR | RXNE/TXE、DMA/EOS | UART 搬字节入/出环；ADC 产半块；EOS 只写 pending | 解析 s/a、`app_sample_convert`、printf |
| 定时器 ISR | SysTick **只** `drv_time_tick_isr()` | 置 1ms 标志 | `Fault_Detection`、软件 HardTrip、printf、喂狗、LED |
| 主循环见标志 | ISR 只置 `flag=1`，主循环 `if (taken)` | 保护→充电→输出→恢复（顺序固定） | `if ((now_ms-last)>=1U)` 充当 1ms 门；保护进 SysTick |
| 主循环每圈 | 不绑精确 1ms | UART、采样消费、LED、遥测、文本日志 | 塞进 ISR，或硬绑 1ms 标志 |

```c
while (1)
{
    app_task_uart(now_ms);  // debug.c：消费 RX 环；收发在 UART_IRQHandler
    app_task_sample();      // sample.c：消费 DMA 半块并换算
    if (drv_time_1ms_taken())
    {
        app_task_protect(tick_ms); // protection.c：须在采样之后、充电之前
        app_task_charge(tick_ms);  // charge.c：阶段机 + MPPT
        app_task_output(tick_ms);  // output.c：PWM/Relay 单写出口
        app_task_recover(tick_ms); // protection.c：STOP + 30s 硬恢复
    }
    app_task_led(now_ms);        // 无 led.c 才留 main
    app_task_telemetry(now_ms);  // debug.c
    app_task_sample_log(now_ms); // sample.c
}
```

禁止：把 LED/串口命令/遥测放进 ISR 或捆进充电/输出任务；用毫秒差冒充 1ms 定时器；ISR 里 printf / 喂狗 / 重计算。UART 必须「中断搬字节 + 主循环任务解析」，对齐微逆 `uart0_isr` + `UART0_DataDeal()`。

### 任务归属（功能文件）

`app_task_*` **声明在功能 `.h`，实现和该任务的助手都在对应功能 `.c`**。`main()` 只调用任务入口。没有对应功能文件的才留 `main.c`。

一个任务函数要包含该任务近乎全部功能：主循环调任务入口；任务入口在功能 `.c` 里再调**同文件**助手。不要把半截逻辑留在 `main.c`。

| 功能 | 任务入口 | 文件 |
|---|---|---|
| 采样 | `app_task_sample` / `app_task_sample_log` | `sample.c` |
| 保护 / 恢复 | `app_task_protect` / `app_task_recover` | `protection.c` |
| 充电 / MPPT | `app_task_charge` | `charge.c` |
| PWM / Relay | `app_task_output`（含 `pwm_apply` / `app_relay_set`） | `output.c` |
| 串口 / 遥测 | `app_task_uart` / `app_task_telemetry` | `debug.c` |
| LED 等无模块 | `app_task_led` | `main.c`（仅此例外） |

禁止：在 `main.c` 堆 `static` 充电/保护/采样上下文；再造 `app_runtime.c` 当中转层。模块用文件级 static ctx + getter。

### 函数书写

一职一函数。写之前先定「这个函数只做什么、谁调用、何时跑」。不要按类型堆巨型函数。

| 角色 | 命名 | 写什么 | 不写什么 |
|---|---|---|---|
| 故障调度 | `Fault_Detection` | 只按固定顺序调用 `Fault_*` | 具体阈值、置位、恢复 |
| 一类故障 | `Fault_Xxx(ctx)` | 检测 + 已有软件自恢复（同函数） | 关 PWM、HardTrip、发明恢复 |
| 主循环任务 | `app_task_*`（写在功能 `.c`） | 该任务近乎全部功能；同文件助手 | 半截留在 `main.c`；再调另一件不相关任务 |
| 1ms 保护 | `app_task_protect` | `Fault_Detection`、95V HardTrip | 放进 SysTick；printf、LED、UART 解析 |
| IRQ 桥接 | `UART_IRQHandler` / `ADC_IRQHandler` | 一行转到 `drv_*_irq_handler` | 业务解析、改充电态 |
| 硬件单写出口 | `app_relay_set` / `pwm_apply` | 该执行器唯一主循环写点 | 别处再直接改同一硬件 |

规则：

- `static` 声明集中在文件头「静态函数声明」区，按调用层次分组（`/* —— 保护 ISR —— */` / `/* —— 主循环任务 —— */`），禁止在文件中部临时插声明。
- 不要 `prot_step_in_t` 一类入参包；保护用 `ctx` + 文件级采样快照（`s_ctx` / `s_sample`）。控制拍结果给遥测读，用文件级快照（`s_hw` / `s_charge_cmd` / `s_out_cmd`），不要把遥测塞进控制函数。
- 有软件自恢复的 `Fault_*`：先 `/* xxx 检测 */`，后 `/* xxx 恢复 */`。无自恢复则函数头写清「无软件自恢复」，不要空 `Fault_XxxRecover`。
- IRQ 包装即使只有一行转发，也是公开函数，单独函数头。

### 函数调用

**谁决定何时跑**：被调函数不自己轮询 1ms。由 ISR、`Fault_Detection` 或 `main` 任务目录调用。

调用图（只允许这样连）：

```
SysTick → drv_time_tick_isr（只置 1ms 标志）
UART_IRQHandler → drv_uart_irq_handler（只搬字节）
ADC/DMA ISR → 产数 / 快故障 pending
main while → app_task_uart(debug.c) / app_task_sample(sample.c)
           →（见标志）app_task_protect(protection.c) → Fault_Detection → Fault_*
           → app_task_charge(charge.c) → app_task_output(output.c) → app_task_recover(protection.c)
           → app_task_led(main) / app_task_telemetry(debug.c) / app_task_sample_log(sample.c)
```

调用点写法：

- 调度处一行一个调用，行尾 `// 中文职责`（`Fault_BatOverVoltage(s_ctx); // BAT 过压`）。
- `main` 按层分节后直接调各功能 `.c` 的 `app_task_*`，不要包进 `app_task_1ms` / `app_task_control`。
- 同一业务不要 ISR 与主循环各跑一遍（`Fault_Detection` 只在 `app_task_protect`）。控制拍可再 `service_fast_faults` 取走 ISR pending，这是归并不是重跑判据。
- 任务之间靠 getter / 文件级快照通信，不互相调用另一件任务（充电任务不要调 uart/led/telemetry）。
- 硬件写走单出口：合闸只 `app_relay_set`，发波只 `pwm_apply`（都在 `output.c`）。

```c
/* 对：调度只排列 */
Fault_PvUnderVoltage(s_ctx); // PV 欠压

/* 错：充电任务里翻灯、解析串口；或把充电/PWM 写回 main.c */
void app_task_charge(uint32_t now_ms)
{
    app_task_uart(now_ms); // 禁止
    app_task_led(now_ms);  // 禁止
}
```

## 边界

- 顺序不可交换，也不可只执行其中一个阶段。
- 用户只要求纯注释整理时使用 `/code_zl`，不要触发本技能。
- 不确定简化是否等价时保留原代码，并继续执行 `code_zl`。
- 发现疑似 bug 时先报告；只有用户明确要求修复时才改变行为。
- 禁止用“MPPT/PWM 控制参数”、“电压阈值”、“模块功能接口”等泛化文字作为最终注释；必须写出参数/状态的实际作用。
- 不扩大文件范围，不执行 git commit 或 push。

## 报告

简要列出：

- Ponytail：删除、内联、复用或明确保留的内容；故障/节拍/函数书写与调用是否已按门禁改
- Code_ZL：注释、分节、声明顺序和对齐调整（须符合 V0.1.8 粒度）
- Verification：实际运行的检查及结果
- 版本：新 `SOFT_VERSION`、追加的 `docs/版本更改/` 节标题；若按用户例外跳过则写明
