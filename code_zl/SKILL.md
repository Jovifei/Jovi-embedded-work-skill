---
name: code_zl
description: "Use when adding or fixing code comments in embedded C files, syncing clang-format/clangd save rules, aligning #define and trailing // comments, marking unverified code with // todo: for board test or follow-up confirmation, or when the user says code_zl, 代码整理, 注释整理, 添加注释, 格式化, 对齐, clang-format, todo. Comments must use plain Chinese anyone on the team can understand—no unexplained jargon (Arm, 夹窝, 功率帽, pending, etc.). Triggers: code_zl, 代码整理, 注释整理, 添加注释, 代码注释, 批量注释, 格式化规则, 宏对齐, 待测, 待确认, todo, 故障拆分, 1ms标志, 微逆保护, 任务目录, 函数书写, 白话注释."
---

# Code_ZL 代码注释整理技能

**Version: V0.1.8**

为嵌入式C工程添加标准化代码注释，遵循 `docs/代码规范.md` 和 Jovi 实际代码风格。支持单文件处理和多文件并行子Agent批量处理。

## 版本记录

- **V0.1.8**：强化「注释必须看得懂」：禁止未解释专业名词；执行流程增加白话自检；给出本工程常用替换对照表。结构改写仍由 `/code_wrt`。
- **V0.1.7**：注释用语优先白话：避免未解释的行话（Arm/夹窝/功率帽/pending 等）；首次出现须用中文写清「做什么」，标识符可保留。结构改写仍由 `/code_wrt`。
- **V0.1.6**：**先定义再使用**：文件级 `static` 变量与 `static` 函数声明必须在**任何函数定义之前**的文件头区；禁止夹在公开函数中间。整理时若发现中段 static，**只挪位置**（不改逻辑）并计入报告。含 `#if APP_HOST_TEST` 等条件编译时，受守护对象仍放在该 `#if` 打开后的**文件头侧**，不得跟在可 Host 编译的公开 API 后面。
- **V0.1.5**：任务入口在功能 `.c`（声明在功能 `.h`，助手同文件）；`main()` 只是任务目录。软件保护注释成跟 1ms 标志走，不要写成 SysTick/`app_tick_isr` 直接跑保护。结构改写仍由 `/code_wrt`。
- **V0.1.4**：补充函数书写与调用的注释/命名：一职一函数、调度一行一调且行尾中文、`app_task_*` 任务目录、IRQ 只桥接、硬件单写出口。结构改写仍由 `/code_wrt`。
- **V0.1.3**：补充故障检测/恢复与节拍调度的注释与命名（微逆 `Protect.c` / `GPTMR_CallbackFunction`）。结构改写由 `/code_wrt` 做；本技能只把已有结构注释成该风格。
- **V0.1.2**：`.h` 分节标题下一行必须是声明/定义，禁止标题与代码之间空行；不同分节块之间保留恰好一行空行。
- **V0.1.1**：待测/待确认须用 `// todo:` 标记（冒号后单空格），写清验证项与通过标准；禁止只在函数头写「待上板」而代码行无 todo。
- **V0.1.0**：首次版本化。`.c` 分节用 `/* 标题 */`（禁止 `====`）；`.h` 分节用 `//=================== 标题 ===`；驱动 Init 采用「分节标题 + 少量关键行尾 `//`」粒度；Ctrl+S 格式化与 `clangd_init` 共用 `.clang-format` 模板。

## 触发条件

用户说 `/code_zl` 或包含"代码整理"、"注释整理"、"添加注释"、"代码注释"、"批量注释"、"故障拆分"、"1ms标志"、"微逆保护"、"任务目录"、"函数书写"、"白话注释"等关键词时触发。

## 使用方式

```bash
/code_zl <文件1> [文件2] ... [文件N]
```

示例：
```bash
/code_zl src/4g_crypto.c src/4g_uart.c inc/4g_uart.h
```

## 执行前必读

1. **先读取 `docs/代码规范.md`**（如果项目中存在），了解项目级规范
2. **先读取目标文件**，了解当前注释状态和代码结构
3. **不修改代码逻辑**，只添加/替换注释
4. **禁止 git commit/push**（即使用户说"整理"，整理 ≠ 提交）
5. **注释必须用看得懂的语气**（见下一节）；发现旧注释里的专业行话，整理范围内一并改成白话

## 注释用语（必须看得懂）

**总原则**：注释写给半年后的自己和同事看。读完应知道「这段在干什么、为什么」，而不是只认识一个行业黑话。

| 要求 | 说明 |
|------|------|
| 语气 | 短句、口语化中文；像口头解释，不像论文摘要 |
| 专业名词 | **注释正文禁止单独甩**；必须先用白话写清行为，标识符可放括号 |
| 函数名/宏名 | 代码标识符可保留英文；**句子本身用白话** |
| 单位 | 写清 `ms`、`mV`、`mW`、千分比等，不要只写裸数字 |

**本工程常见替换（写注释时优先用右列）：**

| 避免单独写 | 改写成 |
|------------|--------|
| Arm / 武装 | 打开 PWM 主输出（让功率管可以发波） |
| Disarm / 解武 | 关闭 PWM 主输出并关掉过流检测 |
| MOE | PWM 主输出（已开=正在发波） |
| K1 | 电池侧继电器 |
| 功率帽 / allow / Ppv 帽 | 本拍允许 MPPT 请求的最大光伏功率（mW） |
| 夹窝 / hold / 粘滞零流 | 电压贴到目标后把电流收到接近 0，但仍保持可发波（不整链关断） |
| pending | 中断里先挂着的故障 |
| active | 当前仍成立的故障 |
| latched | 已记下的故障证据（条件没了也不自动消） |
| pending→latched / 归并 | 把中断挂单写入正式故障字（当前故障 + 证据） |
| xfer / 真传能 | 已在 RUN，且 PWM 主输出开、继电器合 |
| 注水 | 按新采样块把经过的时间累加进节拍 |
| 停靠 / park | 回到 OFF（现网充满不断继电器，阶段机一般不请求） |
| 复位（MPPT） | 清掉 MPPT 内部电压/功率记忆（不是单片机复位） |
| HardTrip | 硬件/软件紧急刹停发波 |
| Fail-Closed | 条件不清就不放行（偏安全） |

**正反例：**

```c
// 坏：Arm 失败
// 好：上一拍打开 PWM 主输出失败

// 坏：功率帽
// 好：本拍允许的最大光伏功率（mW）

// 坏：夹窝仍控功率
// 好：贴目标后把电流收到接近 0（只控功率，不参与判满）

// 坏：pending→latched
// 好：把中断挂单写入正式故障字（当前故障+证据）

// 坏：xfer=run&&moe&&relay
// 好：正在传能 = RUN 且主输出开且继电器合
```

**整理旧注释时**：若范围内出现上表左列且未解释，**必须改成右列语气**（只改注释，不改逻辑）。
## 识别"暂存代码"等隐含范围

用户说"整理我暂存的代码 / 我刚改的 / 这次提交"等表述时，先用 `git diff --cached --name-only`（或 `git status --short`）确定文件清单，再用 `git diff --cached <file>` 查看具体改动行，**只整理改动相关的部分**：
- 新增函数 → 加标准函数头
- 新增字段/宏/枚举 → 加行尾注释
- 改动逻辑分支 → 加内联注释解释意图
- 未触碰的旧代码即使风格不一也不动（最小改动原则）

## 协议/数据手册作为权威依据

整理 Modbus 寄存器、AT 命令、EEPROM 布局、IoT SIID/PIID 等协议相关代码时，**必须**先在 `docs/` 中找到对应协议文件并把权威信息写入注释：
- 模式/状态枚举的中文含义（"0=制冷, 1=制热"，不是 "0/1"）
- 单位（`0.1℃`、`%RH`、`ppm`、`μg/m³`、`天`、`ms`）
- 取值范围（`17~35℃`、`30~80%`）
- bit 字段每位语义
- magic number 的协议出处
- 文件头加一段 **协议出处** 引用，标明 `docs/...` 路径

**编码注意**：国产协议表常为 GBK 编码，直接 `Read` 会乱码。改用 `node_repl` + `TextDecoder('gbk')` 解码：
```javascript
const buf = fs.readFileSync(path);
nodeRepl.write(new TextDecoder('gbk').decode(buf));
```

## 硬件外设代码必须参考已验证实现

整理 UART ISR、SPI/I2C 驱动、定时器中断、DMA 等**硬件外设代码**时，注释整理过程中如果发现可疑实现，**必须**与本工程已经验证过的同类代码对比，**模式不一致即视为潜在 bug**。

**本工程已验证的参考实现**：
| 场景 | 参考文件 | 关键模式 |
|------|---------|---------|
| UART RBNE+IDLE+TC ISR（双端口） | `src/modbus_master.c::mb_isr_handler` | STAT0+CTL0 双快照、tx_busy 期间丢 RX、缓冲满进 overflow drain、IDLE 时 task notify |
| UART TX 启动 + TC 等待 | `src/modbus_master.c::mb_tx_start / mb_tx_wait` | 临界区设 tx_busy → 首字节直发 → 使能 TBE → TC 信号量 |
| UART 帧读取 | `src/modbus_master.c::mb_read_bytes` | xTaskNotifyWait 端口位 + 临界区拷贝 + 清通知位 |
| UART 单字节 + 环形缓冲（无 IDLE） | `src/4g_uart.c::USART0_IRQHandler` | RBNE only、ISR 中环形入队 |
| RTU 互斥与帧间延时 | `src/modbus_master.c` | `MB_RTU_INTER_FRAME_DELAY_MS=5`、`trx_mutex` 跨 TX/RX |

**整理硬件代码的检查清单**：
1. **越界检查必须在数组访问之前**。例如 `if (port >= PORT_COUNT) return;` 必须在任何 `s_cfg[port]` 之前——否则 `port=COUNT` 时会触发越界读 UB。曾在 `ss_isr_handler` 中踩到此 bug，与 `mb_isr_handler` 对比才发现。
2. **状态/控制寄存器必须先做"双快照" 再读 DR**。直接读 `USART_DATA(uart)` 会同时清 RBNE/IDLE/ORERR，导致丢标志。
3. **RBNE handler 中 `tx_busy=1` 必须丢弃接收字节**（RS-485 自回环或半双工回声）。
4. **缓冲满进 overflow 模式而不是关闭 RBNE**，否则错过的 IDLE 通知会让任务永远等不到下一帧。
5. **IDLE 中读 DR 清 IDLEF 必须无条件**——即使要丢弃整帧也要读，否则 IDLE 标志一直置位 ISR 反复触发。
6. **`xHigherPriorityTaskWoken` 必须经过 `portYIELD_FROM_ISR` 处理**，不要遗漏。
7. **`__DSB()` 在 ISR 末尾**确保内存写入对其他核/DMA 可见（Cortex-M4 单核非必需但稳妥）。
8. **DE/RE 引脚控制**：如果硬件用半自动 RS-485 收发器（带 ADM2483 等），驱动里不需要 GPIO 控制；如果是 MAX485 类需要 GPIO，必须在 TX 前拉高、TC 后拉低。检查同工程其他 RS-485 驱动是否有相关代码。
9. **TX 路径必须先 `tx_busy=1` 再 `usart_data_transmit`**，顺序颠倒会让首字节回声漏入 RX 缓冲。

**整理时**：注释新增的同时如发现实现与参考差异，**先用一段块注释标出"参考 mb_isr_handler 同模式"**，并提示用户对比。但**不能改逻辑**——只在用户明确要求修复 bug 时才动代码。

## 注释格式规范

### 一、函数头注释格式

所有公开函数、任务函数、ISR 入口、复杂 `static` 函数**必须**使用统一函数头注释：

```c
/*---------------------------------------------------------------------------
 Name        : static void dev_dynamic_elec_to_app_param(void)
 Input       : 无
 Output      : 无
 Description : 将 UI 动态电价数据整理到 app_param.dynamic_pricing
---------------------------------------------------------------------------*/
```

**格式要求**：

| 字段 | 规则 |
|------|------|
| `Name` | 写完整函数签名，包括 `static`、返回值类型、函数名和参数列表 |
| `Input` | 写关键入参含义；无入参写 `无`；多参数每行缩进对齐 |
| `Output` | 写返回值含义；无返回值写 `无`；返回枚举/错误码时说明各值含义 |
| `Description` | 写函数意图、调用场景、是否持锁、是否阻塞、是否访问硬件 |

**Description 写法要点**：
- 说明**做什么**和**为什么这样做**（白话短句，半年后还能看懂）
- **禁止**只用 Arm / 夹窝 / 功率帽 / pending 等未解释行话；先写行为，标识符可放括号（见「注释用语」）
- 涉及互斥锁时标明：`持 g_app_param_mutex`
- 涉及硬件时标明：`通过 USART0 发送` / `打开 PWM 主输出`
- 涉及阻塞时标明：`阻塞等待信号量，超时 x ms`
- 涉及协议时标明协议依据

**多参数对齐示例**：
```c
/*---------------------------------------------------------------------------
 Name        : int at_mqtt_publish(const char *topic, int qos, const char *data, int data_len)
 Input       : topic - 消息主题
               qos - 消息QoS(0/1)
               data - 消息数据（字符串）
               data_len - 数据长度（字节）
 Output      : MQTT_PUBLISH_OK / MQTT_PUBLISH_ERR_*
 Description : 发布MQTT消息到指定topic。
               当前实现将 payload 作为字符串拼入AT命令 AT+MQTTPUB=...,"<data>" 发送。
---------------------------------------------------------------------------*/
```

**省略规则**：
- 简单 `static` 小工具函数（如 `net_state_get()`、`mqtt_write_conn_result()`），如果函数名足够清楚，可以不写函数头注释
- 但函数名不能清楚表达意图的，仍需添加

### 二、行内注释格式

**`.c` 与 `.h` 分工**：
- **`.h`**：以 API 行尾 `//` 为主，一般不在函数体外写块内注释
- **`.c`**：**必须**有函数头 + 分节块注释 + 控制流块内 `//`（见下文「.c 源文件注释要求」）

```c
// 中文注释内容，说明"为什么这样做"或"这个分支代表什么"
```

**`/* */` 与 `//` 分工**：

| 形式 | 用途 |
|------|------|
| `/*--- ... ---*/` 函数头 | 函数签名、入参、返回值、意图（`.c`） |
| `/* 分节标题 */` | **`.c` 内**功能分区（初始化、主循环、静态变量区）——**短标题，不加 `=` 装饰** |
| `//=================== 标题 ===...` | **仅 `.h`** 文件级分节（API 区、宏区、结构体区） |
| `//` | **行级/块内**说明：if/while/for/switch 内关键语句、`.h` API 行尾 |

**规则**：
- 使用 `//` 中文注释，必要时保留英文缩写、寄存器名、协议字段名
- **行内/行尾注释 / 短的单行解释一律用 `//`**，不用 `/* xxx */`。后者只用于：
  - 文件头注释块（多行）
  - 函数头注释块（多行 `/*--- ... ---*/`）
  - 大段说明性的多行注释
  - **`.c` 内分节**：`/* 分节标题 */`（一行短块注释，**禁止** `/* ===...=== */`）
  - **`.h` 内分节**：`//=================== 标题 ===========================`（见第四节）
- **禁止**在 `/* xxx */` 包裹的单行紧贴代码后面（行尾）作为短注释——这种应统一为 `//`
- **禁止**写 `/* ---------- function_name() — 完整实现 ---------- */` 之类**重复函数名**的小标题，函数头注释块本身已经包含了 Name 字段
- 注释解释**意图**、**协议依据**、**硬件事实**、**单位**、**边界**和**异常路径**
- **语气白话**：同事不问「Arm 是啥」就能读懂；见「注释用语」对照表
- **不重复代码本身**（禁止 `i++; // i 加一` 这种注释）
- 注释放在相关代码**上方**；短字段说明可以放在**行尾**
- 不给每一行普通赋值写注释

**反例（必须改写）**：
```c
return; /* 广播帧 */                                  // ← 改为 // 广播帧
return false; /* 地址不存在 */                        // ← 改为 // 地址不存在
case 8: /* PM2.5: <0=不存在 */                        // ← 改为 // PM2.5: <0=不存在
/* ---------- ss_read_single_reg() — 完整实现 ---------- */  // ← 整行删除
```

**正例**：
```c
return; // 广播帧
return false; // 地址不存在
case 8: // PM2.5: <0=不存在
```

**必须写注释的场景**：
- 涉及协议单位、数组下标、时间换算
- 锁生命周期（获取/释放）
- 错误恢复顺序
- 临界区保护原因
- 环形缓冲区读写逻辑
- 信号量语义
- magic number 的含义

**行尾注释示例**：
```c
static volatile uint16_t s_rx_head = 0;       // 环形缓冲区头指针
static volatile uint16_t s_rx_tail = 0;       // 环形缓冲区尾指针
static volatile bool s_rx_data_ready = false; // 环形缓冲区数据是否准备好
```

**逻辑注释示例**：
```c
// 缓存区没有满，则写入数据。空缓冲判断：s_rx_head == s_rx_tail；满缓冲判断：(next_head == s_rx_tail)
if (next != s_rx_tail) // s_rx_head 在中断中修改，s_rx_tail 在主程序中修改
{
    s_rx_buf[s_rx_head] = ch;
    s_rx_head = next;
}
```

```c
// 每处理 16 字节刷新一次 head 快照，兼顾临界区开销与解析实时性
if ((processed & 0x0F) == 0)
{
    taskENTER_CRITICAL();
    local_head = s_rx_head;
    taskEXIT_CRITICAL();
}
```

### 二点五、.c 源文件注释要求（必须）

整理 **`.c`** 时，除函数头外，必须在**必要处**补充块内注释；**不能只改 `.h` 而放过 `.c`**。

**必须写 `//` 的控制流块内**（if / while / for / switch）：
- 每个分支/ case 的**业务意图**（`// 当前 SYSCLK 来自 HSI`）
- **关键赋值**（改 ARR、写 Flash 标志、清 NVIC）
- **关键外设/库调用**（`DDL_*`、`NVIC_*`、跳转 Bootloader）
- **等待类 while**（`// 轮询 HSI 就绪`）
- **switch** 每个 `case` / `default` 一行说明，不要只注释 switch 本身

**必须写 `/* */` 分节块**的场合（**.c 仅用短格式**）：
- 静态变量区、静态函数声明区：`/* 静态函数声明 */`
- 函数体内逻辑段：`/* 板级与外设初始化 */`、`/* 主循环 */`
- 同一 `.c` 内独立模块：`/* Cortex-M 异常 Handler */`、`/* 外设 IRQ 桥接 */`
- **禁止**在 `.c` 使用 `/* ==================== xxx ==================== */`

**可省略块内 `//` 的场合**：
- 空函数体（无 NMI 源、模板 Fault Handler 仅 `while(1)` 空转）
- 函数头已充分说明且函数体仅一行转发（如 `BSP_ADC_IRQHandler()` 包装）
- **Init/配置函数**内已由分节标题说明意图的连续 DDL 赋值（见二点六）

**`.c` 控制流示例**：

```c
switch (sysClock)
{
case 0x00: // HSI 作为 SYSCLK
    SystemCoreClock = HSI_VALUE >> HSIPrescTable[...];
    break;

case 0x01: // LSI 作为 SYSCLK
    SystemCoreClock = LSI_VALUE;
    break;

default: // 未知源，按 HSI 回退
    SystemCoreClock = HSI_VALUE >> HSIPrescTable[...];
    break;
}

if (RCC->CFG & RCC_CFG_SWSTS)
{
    // 当前非 HSI 运行，先切回 HSI 再复位外设
    if (!(RCC->CR & RCC_CR_HSIRDY))
    {
        RegValue = RCC->CR;
        RegValue |= RCC_CR_HSIEN;
        RCC->CR = RegValue;

        while ((RCC->CR & RCC_CR_HSIRDY) != RCC_CR_HSIRDY)
        {
            // 等待 HSI 稳定
        }
    }
}
```

### 二点六、Init / 配置函数注释粒度（驱动层标准）

外设 **Init、SysClk_Config** 等配置型函数，注释目标是「一眼看出配了什么」，**不要逐行解释寄存器**，也**不要大段原理说明**。

**做法**：
1. 函数头 `Description` 写总体能力（互补 PWM、GTMR 触发 ADC 等）
2. 函数体内按配置阶段加 **`/* 分节：一句话 */`**，标题含关键事实（引脚、频率、模式、保护）
3. 分节内代码保持干净；仅在**非显而易见**处加单行 `//`（如 Break 自动恢复、Flash 擦除序列、状态机失配重同步）
4. 控制流（if/while/switch）仍按二点五补 `//`，但 Init 内纯等待 while 可只写一行

**参考实现**：`Application/driver/src/bsp_pwm.c::BSP_PWM_Init`

```c
void BSP_PWM_Init(void)
{
    /* 时钟使能 */
    ...

    /* GPIO：PA15=CH0 / PA14=CH0N 互补输出 */
    ...

    /* 时基：50kHz 载波（APP_PWM_PERIOD_TICKS） */
    ...

    /* 通道：互补 PWM，默认 50% 占空比 */
    ...

    /* 死区 + COMP0 Break 硬件保护 */
    bdt.AutomaticOutput = DDL_ATMR_AUTOMATICOUTPUT_ENABLE; // Break 解除后自动恢复输出
    ...
}
```

**粒度对照**：

| 级别 | 做法 | 适用 |
|------|------|------|
| 过简 | 仅函数头，Init 内无分节 | ❌ 驱动 Init 不够 |
| **标准** | 分节标题 + 少量关键行尾 `//` | ✅ 驱动 Init、SysClk |
| 过详 | 每个字段、每行 DDL 都注释 | ❌ 噪音大，维护成本高 |

### 二点七、待测 / 待确认标记（`// todo:`）

整理注释时，凡**尚无法在静态审查中确认**、需上台架/实板/协议方后续验证的内容，必须在相关代码处加 **`// todo:`**（ASCII 冒号，冒号后**一个空格**）。

**必须加 `// todo:` 的场景**：
- 注释或函数头已出现「待上板」「待实板验证」「待确认」「⚠️ 静态编译已通过」等表述
- 时序、阈值、超时取自估算或类比，未经本工程实测
- 硬件行为（GPIO 极性、死区、PVD 门槛、Relay 吸合）依赖实物但未给出本板证据
- 与已验证参考实现模式不一致、仅提示对比但未修代码的疑点
- 协议字段/寄存器含义来自文档转抄、尚未联调确认

**写法**：

```c
// todo: 上板确认 PA15 关断态为低且 Relay 不吸合
if (!drv_system_wait_for_supply_stable())
```

```c
DDL_FLASH_SetLatency(DDL_FLASH_LATENCY3); // todo: 64MHz 下 Latency3 是否满足数据手册 tWR
```

```c
// todo: 与 mb_isr_handler 对比——此处缺 tx_busy 丢 RX，需实测半双工回声
while (USART_STAT0_RBNE)
```

**规则**：
- 固定前缀 **`// todo:`**（小写 `todo`；不用 `TODO`/`FIXME`/`待办`/`// todo：` 全角冒号）
- 冒号后**一个空格**，写清**要验证什么**和**通过标准**（尽量可量化）
- 优先贴在**待验证语句的上一行**；语义绑定单行且行宽允许时可用行尾 `// todo:`
- 待办一律用 `// todo:`，**禁止** `/* todo ... */`
- 只标记、**不改逻辑**；同一疑点不重复堆多个 todo

**与函数头 Description 的关系**：
- 函数级「整段待验」可在 Description 写 `验证状态：⚠️ …`
- 但**函数内关键待验语句仍须**有具体 `// todo:` 指向行级待办
- **禁止**只在函数头写「待确认」而代码行无任何 `// todo:`

### 二点八、故障检测/恢复与节拍调度（微逆风格）

整理 `protection.c` / `Protect.c` / `main` 主循环 / 定时器 ISR 时按本节注释和命名。权威参考：微逆 `Protect.c::Fault_Detection`、`Fault_PV2DSVoltage`（检测与恢复同函数）。微逆把保护放定时器回调；**本工程软件保护跟主循环 1ms 标志走，SysTick 只 tick，注释不要写成 ISR 直接跑保护。**

**结构谁来改**：`/code_wrt` 的 ponytail 阶段改结构。纯 `/code_zl` **不拆函数、不挪 ISR**；若仍是巨型 `app_protection_step` 或 `if ((now_ms-last)>=1U)` 冒充 1ms，只改注释并在报告写「结构不符合，应交 /code_wrt」。

**故障模块注释**：

- 调度函数名 `Fault_Detection`；每类 `Fault_Xxx(ctx)`。禁止整理成 `prot_*` 或把恢复拆成 `Fault_XxxRecover`。
- 函数头 Description 写清：检测条件、恢复条件；无软件自恢复则写「无软件自恢复，由 STOP/硬恢复」。
- 有恢复的函数体：先 `/* xxx 检测 */`，后 `/* xxx 恢复 */`（短标题，禁止 `/********恢复****/` 星号填充，禁止 `.c` 里 `====`）。
- `Fault_Detection` 每一行调用必须行尾 `// 中文故障名`。
- 保护只置位：注释里不要写「本函数关 PWM」。

**节拍（先问紧急不紧急、要不要精确 1ms）**：`main()` 是任务目录，每个功能一个 `app_task_*`，**实现写在功能 `.c`**。禁止巨型 `app_task_1ms` / `app_task_control`。

| 层 | 注释要点 | 典型内容 |
|---|---|---|
| 外设 ISR | 只搬字节/产数，禁止解析业务 | `UART_IRQHandler`、ADC DMA/EOS |
| 定时器 ISR | 函数头写「只置 1ms 标志；禁止 Fault_Detection/printf/喂狗/LED」 | `drv_time_tick_isr` |
| 主循环见标志 | 分节 `/* 1ms 标志：保护→充电→输出→恢复 */` | `app_task_protect`（protection.c）、`app_task_charge`（charge.c）、`app_task_output`（output.c）、`app_task_recover`（protection.c） |
| 主循环每圈 | 分节 `/* 串口任务 */` / `/* 非精确：LED、遥测、日志 */` | `app_task_uart`（debug.c）、`app_task_sample`（sample.c）、LED、遥测 |

```c
app_task_uart(now_ms);  // debug.c：消费 RX 环；收发在 UART_IRQHandler
app_task_sample();      // sample.c：消费 DMA 半块
if (drv_time_1ms_taken())
{
    app_task_protect(tick_ms); // protection.c：采样之后、充电之前
    app_task_charge(tick_ms);  // charge.c
    app_task_output(tick_ms);  // output.c：PWM/Relay
    app_task_recover(tick_ms); // protection.c
}
app_task_led(now_ms);        // 无 led.c 才留 main
app_task_telemetry(now_ms);  // debug.c
app_task_sample_log(now_ms); // sample.c
```

LED/串口/遥测 **不要**注释成「跟 1ms 标志走」。ISR **不要**写「顺便翻灯/喂狗/解析 s」。禁止用 `if ((now_ms - last) >= 1U)` 冒充 1ms 定时器——那种应报告给 `/code_wrt`。UART 对齐微逆：`uart0_isr` 搬字节，`UART0_DataDeal()` 在主循环。

### 二点九、函数书写与调用（注释与命名）

整理时按下列名字和调用点注释；**不要**为了对齐本节去拆函数（那是 `/code_wrt`）。发现命名/调用点与下表不符，在报告写「应交 /code_wrt」。

**书写（名字即职责）**：

| 角色 | 命名 | 函数头 Description 必须写清 |
|---|---|---|
| 故障调度 | `Fault_Detection` | 只排列 `Fault_*`，不写判据；由 `app_task_protect`（1ms 标志）调用 |
| 一类故障 | `Fault_Xxx` | 检测条件 + 恢复条件；无自恢复写「无软件自恢复」 |
| 主循环任务 | `app_task_*` | 一件事、哪一层调度、写在哪个功能 `.c`；任务入口含该任务近乎全部功能 |
| 1ms 保护 | `app_task_protect` | 跟 1ms 标志走；禁止注释成 SysTick 直接执行 |
| IRQ 桥接 | `UART_IRQHandler` 等 | 谁调用、转发到哪个 `drv_*`；禁止解析业务 |
| 硬件单写出口 | `app_relay_set` / `pwm_apply` | 该执行器唯一主循环写点；在 `output.c` |

**调用（谁决定何时跑）**：

- `static` 声明集中在文件头，按层次分组：`/* —— 保护 ISR —— */`、`/* —— 主循环任务 —— */`。
- 调度处一行一个调用，行尾 `// 中文职责`。
- `main` 是任务目录：按层分节后直接调功能 `.c` 的 `app_task_*`，不要注释成「全部进 app_task_1ms / app_task_control」。
- 任务之间不互相调用（充电里不要调 uart/led/telemetry）；靠 getter / 文件级快照通信。
- 同一业务不要写成「ISR 与主循环各跑一遍判据」。`Fault_Detection` 只在 `app_task_protect`。

```c
Fault_BatOverVoltage(s_ctx);   // BAT 过压
app_task_charge(tick_ms);      // charge.c：阶段机 + MPPT
app_task_uart(now_ms);         // debug.c：消费 RX 环
```

### 三、.c 文件内分节注释

**.c 使用一行短块注释**，不加等号装饰：

```c
/* 时钟常量 */

/* CMSIS 系统变量 */

/* 静态函数声明 */

int main(void)
{
    /* 板级与外设初始化 */
    Device_Config();

    /* 主循环 */
    while (1)
    {
        ...
    }
}
```

**`.c` 分节反例（禁止）**：

```c
/* ==================== 主循环 ==================== */  // ← 等号装饰仅用于 .h
```

**分区原则**：
- 按功能语义分区，不按类型机械分区
- 分区标题用中文，必要时保留英文缩写
- 每个分区内变量按逻辑关联排列

### 四、头文件注释规范

**`.h` 分节**（使用 `//=================== 标题 ===========================`，`=` 填充至行尾）——**仅头文件**。

**空行规则（必须）**：
- 分节行的**下一行就是**该块的首条 `#define` / `typedef` / 函数声明，**禁止**标题与代码之间插空行
- **不同分节块之间**保留恰好一行空行
- 同一分节块内部的连续声明之间不插空行（结构体/条件编译内部按语法需要除外）

```c
//=================== 中断优先级与临界区 ===========================================================
drv_irq_state_t drv_irq_save(void);          // 保存 PRIMASK 并关全局中断（仅用于极短临界区）
void drv_irq_restore(drv_irq_state_t state); // 恢复调用前的 PRIMASK
void drv_irq_configure_priorities(void);     // 按快速故障 > DMA > ADC/SysTick > 串口配置 NVIC 优先级

//=================== 弱光供电资格（PVD 启动资格判定） =============================================
bool drv_mcu_wait_for_supply_stable(void); // 阻塞等到 VDD 连续稳定满窗口
void drv_mcu_supply_qualifier_stop(void);  // 关闭 PVD；运行期不把 PVD 当弱光故障源

//=================== 系统复位 =====================================================================
DRV_MCU_NORETURN void drv_mcu_reset(void); // 请求 Cortex-M 系统复位
```

**反例（必须改）**：
```c
//=================== 系统复位 =====================================================================

DRV_MCU_NORETURN void drv_mcu_reset(void); // ← 删掉标题与声明之间的空行
```

**结构体字段分组**（结构体内部用 `/* 分组标题 */` 块注释）：
```c
typedef struct
{
    /* 全屋环境极值 */
    float whole_temp_min;             // 全屋温度最低值（℃，所有在线温控器）
    float whole_temp_max;             // 全屋温度最高值（℃，所有在线温控器）

    wh_center_valid_t valid; // 各维度数据有效标志

    /* 温控器统计 */
    uint8_t thermostat_online_count;  // 在线温控器数量
    uint8_t thermostat_on_count;      // 开机温控器数量（无需求判据）

    /* 主机选举状态 */
    uint8_t master_addr;              // 当前主机地址（WH_CENTER_MASTER_ADDR_NONE=无）

    /* 防冻结保护状态 */
    uint8_t antifreeze_state;         // 0=正常，1=防冻结激活
    uint32_t antifreeze_started_ms;   // 防冻结触发时刻（ms tick）
} wh_center_t;
```

**结构体字段注释**（行尾，对齐到统一列宽）：
```c
typedef struct
{
  uint32_t state[4];  // MD5 中间状态（A/B/C/D 寄存器）
  uint32_t count[2];  // 已处理的位数（64位计数，低32位在[0]）
  uint8_t buffer[64]; // 未满一个分组的剩余字节缓冲
} md5_context_t;
```

**枚举注释**（每个成员行尾）：
```c
typedef enum
{
  AT_NB_IDLE = 0,    // 空闲状态：无命令正在执行
  AT_NB_WAITING = 1, // 等待状态：命令已发送，正在等待响应
  AT_NB_OK = 2,      // 成功状态：收到 OK 响应
  AT_NB_ERR = -1,    // 错误状态：收到 ERROR 或超时
} at_nb_state_t;     // 非阻塞 AT 命令
```

**错误码宏注释**（行尾对齐）：
```c
#define ML307R_SSL_ERR_PARAM (50)                    // 参数错误
#define ML307R_SSL_ERR_UNKNOWN (750)                 // SSL/TLS/DTLS 未知错误
#define ML307R_SSL_ERR_NEGOTIATE_TIMEOUT (753)       // SSL/TLS/DTLS 协商超时
```

**`.h` 函数声明注释**（行尾注释，不用函数头块注释）：
```c
void wh_center_init(void);            // 初始化五恒控制中心，清零全局状态，设置默认主机模式为制冷。
void wh_center_aggregate(void);       // 聚合全屋数据：遍历总线温控器，计算极值、选举主机、更新防冻结时序
void wh_center_apply_heatpump_control(void); // 热泵控制决策：优先级 防冻结>故障>无需求>气候补偿+蓄能修正
void wh_center_publish_linkage(void); // 广播联动参数：将全屋湿度/PM2.5/CO2写入总线寄存器200~203
```

### 五、宏和常量注释

- 协议寄存器、EEPROM 偏移、时间单位、温度单位**必须**注释
- 单位写在注释里：`ms`、`0.1℃`、`ppm`、`%RH`
- bit 位字段必须说明每一位语义
- 废弃字段标明"已废弃"和替代项

```c
#define HP_MB_ADDR_ACTUATOR 1u // 热泵机组固定地址，勿与 USART1 从机扫描地址混淆
#define LTE_SIGNAL_QUERY_INTERVAL_MS 10000 // LTE 信号查询间隔（毫秒）
#define MQTT_MSG_FAIL_RECONNECT_MS (10UL * 60UL * 1000UL) // 10分钟MQTT重连时间
```

### 六、日志标签规范

日志标签要能区分物理链路和模块：
- `[HP]` — 热泵模块
- `[BUS]` — 总线模块
- `[IOT]` — IoT/云端模块
- `[MQTT]` — MQTT 模块
- `[ML307R]` — 4G 模组模块
- `[MQTT-URC]` — MQTT URC 事件

```c
DEBUG_4G_PRINTF("[MQTT] at_mqtt_publish FAIL TIMEOUT topic=%s\r\n", topic);
DEBUG_4G_PRINTF("[MQTT-URC] +MQTTURC: \"conn\",%d,%d => %s", conn_id, result_code, desc);
```

### 七、main.c 与 FreeRTOS 任务创建结构（F427 风格）

**核心原则**：main.c 是系统入口的"目录"，一眼能看出"初始化了什么、创建了哪些任务、调度器何时启动"。初始化与任务创建严格分离——模块 init 函数只做 init，不创建任务；所有 FreeRTOS 任务集中在 main.c 用 `app_create_task_checked` 创建。

#### 7.1 模块 init 函数禁止创建任务

**反例**（旧 F303 风格，已废弃）：
```c
void f303_4g_init(void)
{
    modem_init();
    if (s_control_task_handle == NULL)
    {
        (void)xTaskCreate(f303_4g_control_task, "4gctl", 256U, NULL, 4U, &s_control_task_handle);
    }
}
```

**正例**（F427 modem_setup 风格）：
```c
void f303_4g_init(void)
{
    modem_product_info_t product_info;

    f303_4g_load_default_product_info(&product_info);
    if ((product_info.product_id[0] != '\0') && (product_info.product_secret[0] != '\0'))
    {
        s_f303_product_info = product_info;
        s_f303_product_valid = true;
        modem_set_product_info(&s_f303_product_info);
    }

    modem_register_event_cb(f303_4g_on_event, NULL);
    modem_init(); // 只初始化，不创建任务
}
```

**为什么**：main.c 是任务清单的"唯一真源"。任务散落在各模块 init 里会让"系统有哪些任务"无法一眼看清，也无法统一做 `configASSERT` 检查。条件创建（`if (handle == NULL)`）更是反模式——凭证动态注入应通过运行时 API（如 `modem_ml307r_set_reg_state`）触发，而不是动态创建任务。

#### 7.2 任务栈大小、优先级、句柄集中在 main.h

```c
//=================== 任务栈大小（words） ===========================
#define TASK_STACK_ML307R 1024U // 4G 模块联网任务
#define TASK_STACK_4GCTL  256U  // 4G 控制任务（订阅管理 + LED 刷新）
#define TASK_STACK_MB4G   256U  // Modbus 从机任务
#define TASK_STACK_DEBUG  256U  // 调试串口任务

//=================== 任务优先级 ===========================
#define TASK_PRIO_ML307R 5U
#define TASK_PRIO_4GCTL  4U
#define TASK_PRIO_MB4G   3U
#define TASK_PRIO_DEBUG  4U

//=================== 任务句柄 ===========================
extern TaskHandle_t g_hdl_ml307r; // 4G 模块联网任务句柄
extern TaskHandle_t g_hdl_4gctl;  // 4G 控制任务句柄
extern TaskHandle_t g_hdl_mb4g;   // Modbus 从机任务句柄
extern TaskHandle_t g_hdl_debug;  // 调试串口打印任务句柄
```

**规则**：
- 栈大小/优先级**必须用宏**，禁止 `xTaskCreate(..., 256, ...)` 魔法数字
- 句柄**必须 `extern` 声明在 main.h**，定义在 main.c 文件头
- 宏命名 `TASK_STACK_<模块>` / `TASK_PRIO_<模块>`，句柄 `g_hdl_<模块>`
- main.h 必须 include `FreeRTOS.h` + `task.h`（让 `TaskHandle_t` 可用）

#### 7.3 main.c 标准模板

```c
#include "main.h"
#include "modbus_slave_4g.h"
#include "4g_product.h"
#include "4g_api.h"
#include "debug.h"
#include "watchdog.h"

TaskHandle_t g_hdl_ml307r = NULL; // 4G 模块联网任务句柄
TaskHandle_t g_hdl_4gctl  = NULL; // 4G 控制任务句柄
TaskHandle_t g_hdl_mb4g   = NULL; // Modbus 从机任务句柄
TaskHandle_t g_hdl_debug  = NULL; // 调试串口打印任务句柄

/*---------------------------------------------------------------------------
 Name        : static void app_create_task_checked(TaskFunction_t task_code,
                                                    const char *name,
                                                    uint16_t stack_words,
                                                    UBaseType_t priority,
                                                    TaskHandle_t *handle)
 Input       : task_code   - 任务函数指针
               name        - 任务名（调试用）
               stack_words - 栈大小（字）
               priority    - 任务优先级
               handle      - 任务句柄输出（可为 NULL）
 Output      : 无
 Description : 创建任务并断言成功。调度器启动前调用，失败即停机。
---------------------------------------------------------------------------*/
static void app_create_task_checked(TaskFunction_t task_code,
                                    const char *name,
                                    uint16_t stack_words,
                                    UBaseType_t priority,
                                    TaskHandle_t *handle)
{
    BaseType_t ok = xTaskCreate(task_code, name, stack_words, NULL, priority, handle);
    configASSERT(ok == pdPASS);
    configASSERT(handle == NULL || *handle != NULL);
}

/*---------------------------------------------------------------------------
 Name        : int main(void)
 Input       : 无
 Output      : 无（正常不返回）
 Description : 系统入口。按顺序完成：
               1. NVIC 优先级分组（Pre4/Sub0，全部抢占优先级）
               2. 调试串口初始化（含开机 LOGO 打印）
               3. 打印上次复位原因
               4. 板级 IO 初始化
               5. 4G 网关初始化（凭证 + 产品信息 + 事件回调 + modem_init）
               6. 创建所有 FreeRTOS 任务
               7. 启动调度器（vTaskStartScheduler 后不再返回）
---------------------------------------------------------------------------*/
int main(void)
{
    // NVIC 4 位全部用于抢占优先级，无子优先级，适合 FreeRTOS
    nvic_priority_group_set(NVIC_PRIGROUP_PRE4_SUB0);

    uart_debug_init();                 // 调试串口
    app_watchdog_print_reset_reason(); // 打印上次复位原因（须在 debug 串口初始化后）

    f303_board_io_init(); // 板级 IO（LED PB3/PB4/PB5）
    f303_4g_init();       // 4G 网关初始化（modem_init，任务在下面集中创建）

    /* 创建任务 */
    app_create_task_checked(modem_ml307r_task,  "modem4g", TASK_STACK_ML307R, TASK_PRIO_ML307R, &g_hdl_ml307r); // 4G 模块联网任务
    app_create_task_checked(f303_4g_control_task, "4gctl",  TASK_STACK_4GCTL,  TASK_PRIO_4GCTL,  &g_hdl_4gctl);  // 4G 控制任务（订阅管理 + LED 刷新）
    app_create_task_checked(modbus_slave4g_task, "mb4g",   TASK_STACK_MB4G,   TASK_PRIO_MB4G,   &g_hdl_mb4g);   // Modbus 从机任务
    app_create_task_checked(debug_task,         "debug",  TASK_STACK_DEBUG,  TASK_PRIO_DEBUG,  &g_hdl_debug);  // 调试串口打印任务

    vTaskStartScheduler();

    // 正常情况下不应到达此处
    while (1)
    {
    }
}
```

**结构要点**：
1. **全局句柄定义在文件头**（include 之后），每个句柄行尾注释说明用途
2. **`app_create_task_checked` 是 static 包装函数**，每个工程固定一份，签名照搬
3. **main 函数体严格分两段**：上半段初始化调用（每行带 `// 说明` 行尾注释），下半段 `/* 创建任务 */` 分节
4. **每个 `app_create_task_checked` 调用行尾必须注释任务用途**
5. **`vTaskStartScheduler()` 之后跟 `while (1) {}` 兜底**，注释"正常情况下不应到达此处"

#### 7.4 任务函数对 main 可见

需要在 main.c 创建的任务函数**必须**：
- 改为非 `static`（去掉 `static` 前缀）
- 在对应模块的 `.h` 中声明，行尾注释"main 创建，内部自初始化硬件"

```c
// modbus_slave_4g.h
void modbus_slave4g_task(void *arg); // Modbus 从机任务（main 创建，内部自初始化硬件）
```

任务函数内部第一件事是调本模块的 init（硬件初始化在任务上下文，不在 main）：
```c
void modbus_slave4g_task(void *arg)
{
    (void)arg;
    modbus_slave4g_init();    // 硬件初始化（USART1、GPIO、NVIC）
    f303_4g_gateway_init();   // 依赖的网关初始化

    for (;;)
    {
        // ...
    }
}
```

#### 7.5 FreeRTOSConfig.h 必须定义 configASSERT

`app_create_task_checked` 依赖 `configASSERT`。若 FreeRTOSConfig.h 未定义，必须补上：

```c
#ifndef configASSERT
#define configASSERT(x) do { if ((x) == 0) { __disable_irq(); for (;;) { } } } while (0)
#endif
```

放在 `xPortSysTickHandler` 等中断别名定义之后、`#endif /* FREERTOS_CONFIG_H */` 之前。

#### 7.6 常见违规与修复

| 违规 | 修复 |
|------|------|
| 模块 init 里 `xTaskCreate` | 移到 main.c 的 `/* 创建任务 */` 段，init 函数只做 `modem_init()` 等纯初始化 |
| `xTaskCreate(..., 256, 3, ...)` 魔法数字 | 抽成 `TASK_STACK_XXX` / `TASK_PRIO_XXX` 宏放 main.h |
| 任务句柄散落在模块 .c 的 static 变量 | 改为 `g_hdl_xxx` 全局变量，extern 在 main.h |
| 任务函数是 `static`，main.c 无法引用 | 去掉 static，在模块 .h 声明 |
| `(void)xTaskCreate(...)` 忽略返回值 | 改用 `app_create_task_checked`，`configASSERT` 兜底 |
| `if (handle == NULL) xTaskCreate(...)` 条件创建 | 删除条件——任务无条件创建，运行时状态用 `set_reg_state` 等 API 控制 |
| `configASSERT` 未定义导致编译错误 | 在 FreeRTOSConfig.h 末尾补 `#define configASSERT(x) ...` |

## 执行流程

### 单文件处理

```
0. 若工程无 .clang-format → 同步 references/clang-format（见「工程格式化规则」）
1. 读取目标文件完整内容
2. 分析当前注释状态（已有哪些注释、格式是否规范）
3. .c 文件：检查分节块、函数头、if/while/for/switch 块内 // 是否齐全
4. 按 .c 文件组织顺序检查分区（**布局硬门，先于加注释**）：
   - include → 私有宏 → 私有 typedef/enum → **static 变量** → **static 声明** → 公开函数 → 私有函数
   - 自检：第一个函数定义之后，文件作用域不得再出现 `static ...;`（变量或原型）
   - 若违规：把 static 变量/声明挪回文件头（条件编译块跟到文件头侧），**只重排、不改逻辑**，再继续注释
5. 为缺少函数头注释的函数添加标准注释（Description 用白话）
6. 替换不规范的旧注释格式（如 /** @brief */、旧式 /*---...---*/）
7. 在控制流块内关键赋值/调用处添加 // 注释（白话，见「注释用语」对照表）
8. 发现待测/待确认项 → 在相关代码行加 `// todo:`（见二点七）
9. **白话自检**：整理范围内注释是否仍有未解释的 Arm/夹窝/功率帽/pending/xfer/注水/K1/MOE 等；有则改成对照表右列语气
10. 确保分节注释清晰；`.h` 分节标题下一行即代码，块与块之间一行空行
11. 报告：添加/替换了多少个函数头注释、行内/块内注释、`// todo:` 标记；若改了行话→白话，在备注写「白话化」
```

### 多文件并行处理

```
1. 分析任务：确定要处理的文件列表
2. 每个文件分配一个子Agent并行处理
3. 收集结果：等待所有Agent完成后汇总报告
```

### 子Agent任务模板

每个子Agent接收以下 prompt（将 `[文件路径]` 替换为实际路径）：

```
修改文件 [文件路径] 的注释。

**重要约束：不要执行 git commit，不要 push，只修改文件。**

## 注释格式

**函数头注释**（每个函数添加）：
/*---------------------------------------------------------------------------
 Name        : 完整函数签名（含 static/返回值/参数）
 Input       : 参数说明（多参数每行缩进对齐）
 Output      : 返回值说明
 Description : 功能描述（可多行，缩进对齐）
---------------------------------------------------------------------------*/

**行内注释**：格式为 `//` 开头，中文白话，说明「为什么这样做」。禁止只写 Arm/夹窝/功率帽/pending 等未解释行话（见技能「注释用语」对照表）。

## 步骤

1. 先 Read 读取文件完整内容，了解当前状态
2. 检查文件当前有哪些注释格式（可能已有老的注释格式需替换）
3. 移除所有老的 /** @brief */ 格式注释块，替换为标准函数头注释
4. 为所有函数添加标准函数头注释（Description 白话）
5. 添加详细的行内注释（// 开头），每段关键逻辑都要有注释说明
6. 白话自检：把未解释的专业行话改成「做什么」的中文
7. 发现待测/待确认（待上板、阈值未实测、与参考实现不一致等）→ 加 `// todo:`，写清验证项
8. 保持代码逻辑不变，只添加/替换注释

完成后报告：添加/替换了多少个函数头注释、行内注释、`// todo:` 标记；是否做了白话化。
```

## 汇总报告格式

| 文件 | 函数头注释 | 行内注释 | 分节注释 | todo | 备注 |
|------|-----------|---------|---------|------|------|
| file1.c | +N / 替换M | +K | +J | +T | 备注 |
| file2.h | +N / 替换M | +K | +J | +T | 备注 |

## 约束

- **禁止 git commit/push**
- **不修改代码逻辑**：只添加/替换注释；**例外**：为满足「先定义再使用」而把中段文件级 `static` 变量/声明挪回文件头（仅重排位置）。故障拆分与 ISR/主循环挪位交给 `/code_wrt`，其它结构不符只在报告指出。
- **不重复添加**：先检查现有注释状态，已有的不覆盖（除非格式不规范需替换）
- **最小改动**：只整理本次任务触碰的模块，不为了风格统一重排无关文件
- **注释语言**：中文白话为主，语气要看得懂；禁止未解释的专业行话（见「注释用语」）。函数名/宏名/寄存器名可保留英文。

## 常见陷阱（本技能历次实战教训）

### 1. 函数头注释错位（双注释贴一起）

合并/拷贝过程会产生 `Header A + Header B + function B {}` 三件套，其中 Header A 实际属于上方某个已经"裸露"的函数。整理时识别并把 Header A 移回它真正描述的函数，把 Header B 留在 function B 上方。

### 2. 旧风格文件头需要替换

仓库里历史代码常见 `/** @file ... @brief ... */` Doxygen 风格头部，应替换为 Jovi 标准文件头注释（多行 `/*--- ... ---*/`），并补充：模块概览、关键约束（线程/中断/锁/单位）、协议出处引用。

### 3. ISR / IRQ wrapper 也是"公开函数"

`UART3_IRQHandler` 之类被 NVIC 直接调用的入口函数，即使函数体只有一行 `ss_isr_handler(...)`，也要加标准函数头注释（说明谁调用、转发到哪）。

### 4. 多个紧邻的小工具函数仍各自需要函数头

例如 `ss_line_fault_word` / `ss_host_fault_word` / `ss_one_word_detail_fault` 三个相关 helper，即使前面有一段共享的"fault_bits 布局"叙述，每个 helper **仍需独立的标准函数头**。否则读者跳到中间一个函数会找不到上下文。

### 5. 写属性/写寄存器分支必须区分错误码语义

校验失败时不同原因要返回不同 code（"越界"≠"类型错误"≠"地址不存在"≠"只读"），注释里把每个 `code = -4005` 的具体原因写出来，便于平台排障。

### 6. 行尾注释字段对齐到统一列宽

视觉上对齐显著提升可读性，整理时用空格补齐：

```c
SemaphoreHandle_t tx_done_sem;   // TC 完成信号量（ISR 释放，任务等待）
uint8_t           slave_addr;    // 从机地址：0=禁用（不响应），1~247 合法
bool              uart_ready;    // 端口已初始化标志，幂等保护
```

### 7. 整理时同步同步影子层（影子结构体写读侧）

新增了 `app_param.sys.uart3_slave_addr`，则注释要在以下位置都说明 0=禁用语义：
- 真源结构体定义（`hp.h`）
- EEPROM 加载/保存（`hp_eep.c` 的 load/save/restore_defaults/快照比较）
- IoT 属性读写（`iot_msg.c` 的 fill 与 set 分支）
- Setter 层（`hp_setter.c`）
- 消费方（`third_screen_slave.c` 的 `ss_set_slave_addr` 入参校验）

只在 1 处加注释会让其他 5 处显得"无依据"。

### 8. `.h` 分节标题后禁止空行

整理头文件时，`//=================== 标题 ===` 与首条声明之间若有空行必须删掉；块与块之间那一行空行必须保留。

### 9. 待测/待确认必须写 `// todo:`

整理时若写出「待上板」「待确认」「⚠️ 静态已通过」等表述，**代码行必须有 `// todo:`**，不能只留在函数头 Description 或版本文档里。格式：`// todo: ` + 验证项 + 通过标准。整理结束在汇总报告单独统计 todo 数量。

### 10. 保护与节拍不要写成「主循环 1ms 轮询保护」

整理 `protection.c` / `main` 时：`Fault_Detection` 只调度；检测+恢复同函数；软件保护跟 1ms 标志走（不要注释成 ISR 直接跑保护）；`main` 是 `app_task_*` 目录，任务实现在功能 `.c`。不要把 LED/串口/遥测注释成跟 1ms 标志走，也不要把恢复拆成 `Fault_XxxRecover`，IRQ 不要写成解析业务。结构/命名/调用点不对时报告应交 `/code_wrt`。

### 11. 中段 `static` 变量/声明（先定义再使用）

`sample.c` 曾把运行时 `static` 与 `adc_log_*` 声明夹在 `app_sample_convert` 等公开函数之后、板级 `#if !APP_HOST_TEST` 段中间。整理前**必须**扫描：第一个函数定义之后若仍有文件作用域 `static ...;`，先挪回文件头再加注释。条件编译不能当借口把 static 留在文件中部。

### 12. 注释必须看得懂，禁止甩未解释专业名词

整理时若写出 Arm / Disarm / 夹窝 / 功率帽 / pending→latched / xfer / 注水 / 停靠 / K1 / MOE 等，**必须改成白话行为描述**（见文首「注释用语」对照表）。标识符可放在括号里。自检口令：同事不问「这词啥意思」也能读懂这段注释。

## 工程格式化规则（clang-format，所有工程统一）

注释整理与 **Ctrl+S 保存格式** 共用同一套规则。技能内置模板，执行 `/code_zl` 时**先同步到当前工程**，再改注释。

### 同步步骤（每个工程首次或用户要求「同步格式化规则」时必做）

1. 读取工程根目录是否已有 `.clang-format`、`.vscode/settings.json`
2. 若**不存在**或与技能模板不一致 → 从本技能复制：
   - `references/clang-format` → `<工程根>/.clang-format`
   - `references/vscode-settings.json` → `<工程根>/.vscode/settings.json`（与已有 settings **合并**，勿覆盖无关项）
3. 告知用户：**Reload Window** 后 Ctrl+S 生效；格式化器须为 **clangd**（不是 Microsoft C/C++）。F12 跳转与保存格式化的工程级配置见 `/clangd_init`。

### 规则要点（与注释风格一致）

| 场景 | 规则 |
|------|------|
| `.h` 函数声明 + 行尾 `//` | **单行**，禁止把参数拆到下一行（`ColumnLimit: 0`） |
| 连续 `#define` | 宏名后**数值列对齐**，`//` **列对齐**（`AlignConsecutiveMacros` + `AlignTrailingComments`） |
| `.h` API 声明 | 行尾 `//` 中文说明，不用函数头块注释 |
| `if` / `while` / `for` / `else` | 条件行结尾，`{` **单独下一行**；`else` 单独一行 |
| 简单保护分支 | 允许 `if (x) return;` 单行无大括号 |

**`.h` 函数声明示例**：

```c
void BSP_PWM_SetDuty(uint16_t permille);            // 设置 CH0 占空比（0~1000 千分比）
void BSP_PWM_SetFrequency(uint32_t frequency_hz);   // 改载波频率并保持当前占空比例
```

**`#define` 对齐示例**：

```c
#define APP_PWM_FREQUENCY_HZ       50000U                               // PWM 载波频率（Hz）
#define APP_PWM_PERIOD_TICKS       (64000000U / APP_PWM_FREQUENCY_HZ)   // ATMR 计数周期（tick）
#define APP_ADC_CHANNEL_COUNT      5U                                   // 规则组扫描通道数
```

**`.c` 大括号示例**：

```c
if (permille > 1000U)
{
    permille = 1000U;
}
```

### 整理注释时的格式配合

- 宏块、结构体字段、`.h` API：按上表**手动对齐**列宽，保存后 clang-format 会维持
- **禁止**为对齐去改逻辑；仅空格与注释
- 完整模板见 [references/clang-format](references/clang-format)

## 代码规范速查（来自 docs/代码规范.md）

### 命名规范
- 全局变量：`g_` 前缀（如 `g_system`、`g_hdl_hp_ctrl`）
- 文件内静态变量：`s_` 前缀（如 `s_port`、`s_tick_acc`）
- 公开函数：带模块前缀（如 `hp_set_mode()`、`uart4g_at_lock()`）
- 私有函数：`static`，可使用短名称

### .c 文件组织顺序（先定义再使用）
1. include
2. 私有宏
3. 私有 typedef / enum
4. 文件级 `static` 变量（全部）
5. **必要的 `static` 函数声明（全部集中在文件头部）**
6. 公开函数定义
7. 私有函数定义（`static` 函数体放文件后部；**原型仍只在第 5 步的文件头**）

**硬规则：先定义 / 先声明，再使用**
- 文件级 `static` **变量**与 `static` **函数声明**必须出现在**该翻译单元内第一个函数定义之前**
- **禁止**在两个公开函数之间、或「前半段 Host 可编 API + 后半段板级实现」的夹缝里再塞 `static` 区
- 条件编译（如 `#if !defined(APP_HOST_TEST)`）：板级 static 放在该 `#if` 打开后的**文件头侧**（include/typedef 之后立刻），不要等 Host 纯函数写完再开第二块 static
- `/code_zl` 发现中段 static：**必须挪回文件头**（仅位置重排，语义不变），并在汇总报告备注「布局修正」

**static 函数声明放置规则**（重要，曾被用户专门指出）：
- 所有 static 函数声明必须**集中**到文件头部的"静态函数声明"区
- **禁止**散落在文件中部（例如临时为了引用某个后置函数而在中段插入声明；或 `#if !HOST` 板级段开头才声明）
- 当 static 函数较多时，按调用层次分组，每组前加一行 `/* —— 分组名 —— */`：

```c
/* 静态变量 */
static app_sample_t s_sample;

/* 静态函数声明 */
/* —— UART ISR 与底层收发 —— */
static void ss_isr_handler(ss_port_t port);
static bool ss_tx_start(ss_port_t port, const uint8_t *data, size_t len);

/* —— 寄存器读取分层（地址 → 设备 → 子类） —— */
static bool ss_read_single_reg(...);
static bool ss_read_thermo_reg(...);

/* —— Modbus 帧 CRC / 异常响应 —— */
static uint16_t ss_crc16(...);

/* —— 帧解析与功能码分发 —— */
static void ss_parse_and_respond(ss_port_t port);

/* 以下才是函数定义 */
```

**反例（禁止）**：
```c
void app_foo(void) { ... }

/* 运行时静态 —— 错误：已在函数定义之后 */
static uint16_t s_x;
static void helper(void);

void app_bar(void) { ... }
```

### 大括号风格
- 左大括号单独占一行
- `else` 单独占一行
- 简单保护分支允许不加大括号

### 并发规则
- 共享变量通过互斥/队列/临界区保护
- setter 层负责限幅、互斥和持久化触发
- 不在 `taskENTER_CRITICAL()` 内调用阻塞 I/O
