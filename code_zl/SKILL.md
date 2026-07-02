---
name: code_zl
description: "Use when adding or fixing code comments in embedded C files, when functions lack standard header comments, when inline comments are missing or inconsistent, or when the user says 代码整理、注释整理、添加注释. Triggers: code_zl, 代码整理, 注释整理, 添加注释, 代码注释, 批量注释."
---

# Code_ZL 代码注释整理技能

为嵌入式C工程添加标准化代码注释，遵循 `docs/代码规范.md` 和 Jovi 实际代码风格。支持单文件处理和多文件并行子Agent批量处理。

## 触发条件

用户说 `/code_zl` 或包含"代码整理"、"注释整理"、"添加注释"、"代码注释"、"批量注释"等关键词时触发。

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
- 说明**做什么**和**为什么这样做**
- 涉及互斥锁时标明：`持 g_app_param_mutex`
- 涉及硬件时标明：`通过 USART0 发送`
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

```c
// 中文注释内容，说明"为什么这样做"或"这个分支代表什么"
```

**规则**：
- 使用 `//` 中文注释，必要时保留英文缩写、寄存器名、协议字段名
- **行内/行尾注释 / 短的单行解释一律用 `//`**，不用 `/* xxx */`。后者只用于：
  - 文件头注释块（多行）
  - 函数头注释块（多行 `/*--- ... ---*/`）
  - 大段说明性的多行注释
  - `/* ==================== xxx ==================== */` 段落分隔器
- **禁止**在 `/* xxx */` 包裹的单行紧贴代码后面（行尾）作为短注释——这种应统一为 `//`
- **禁止**写 `/* ---------- function_name() — 完整实现 ---------- */` 之类**重复函数名**的小标题，函数头注释块本身已经包含了 Name 字段
- 注释解释**意图**、**协议依据**、**硬件事实**、**单位**、**边界**和**异常路径**
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

### 三、文件内分节注释

使用 `/* ==================== 分节标题 ==================== */` 格式对 `.c` 文件内进行逻辑分区：

```c
/* ==================== 环形接收缓冲区 ==================== */
/* ==================== 行解析器 ==================== */
/* ==================== 非阻塞 AT 命令状态机 ==================== */
/* ==================== AT 结果与提示符标志 ==================== */
/* ==================== URC 注册表 ==================== */
/* ==================== 信号量（用于 at_mqtt_publish 事件驱动） ==================== */
/* ==================== AT 会话互斥量 ==================== */
/* ==================== 静态函数声明 ==================== */
```

**分区原则**：
- 按功能语义分区，不按类型机械分区
- 分区标题用中文，必要时保留英文缩写
- 每个分区内变量按逻辑关联排列

### 四、头文件注释规范

**头文件分节**（使用 `//=================== 标题 ===========================`，`=` 填充至行尾）：
```c
//=================== 各维度数据有效标志（1=有效，0=无匹配从机） ===========================
typedef struct { ... } wh_center_valid_t;

//======================= 五恒控制中心全局状态结构体 ============================
typedef struct { ... } wh_center_t;

//======================== 五恒控制中心 API ===============================
void wh_center_init(void);
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
/* ==================== 任务栈大小（words） ==================== */
#define TASK_STACK_ML307R 1024U // 4G 模块联网任务
#define TASK_STACK_4GCTL  256U  // 4G 控制任务（订阅管理 + LED 刷新）
#define TASK_STACK_MB4G   256U  // Modbus 从机任务
#define TASK_STACK_DEBUG  256U  // 调试串口任务

/* ==================== 任务优先级 ==================== */
#define TASK_PRIO_ML307R 5U
#define TASK_PRIO_4GCTL  4U
#define TASK_PRIO_MB4G   3U
#define TASK_PRIO_DEBUG  4U

/* ==================== 任务句柄 ==================== */
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
1. 读取目标文件完整内容
2. 分析当前注释状态（已有哪些注释、格式是否规范）
3. 按 .c 文件组织顺序检查分区：
   - include → 私有宏 → 私有 typedef/enum → static 变量 → static 声明 → 公开函数 → 私有函数
4. 为缺少函数头注释的函数添加标准注释
5. 替换不规范的旧注释格式（如 /** @brief */、旧式 /*---...---*/）
6. 在关键逻辑处添加行内注释
7. 确保分节注释清晰
8. 报告：添加/替换了多少个函数头注释，多少个行内注释
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

**行内注释**：格式为 `//` 开头，中文，注释要详细，说明"为什么这样做"。

## 步骤

1. 先 Read 读取文件完整内容，了解当前状态
2. 检查文件当前有哪些注释格式（可能已有老的注释格式需替换）
3. 移除所有老的 /** @brief */ 格式注释块，替换为标准函数头注释
4. 为所有函数添加标准函数头注释
5. 添加详细的行内注释（// 开头），每段关键逻辑都要有注释说明
6. 保持代码逻辑不变，只添加/替换注释

完成后报告：添加/替换了多少个函数头注释，多少个行内注释。
```

## 汇总报告格式

| 文件 | 函数头注释 | 行内注释 | 分节注释 | 备注 |
|------|-----------|---------|---------|------|
| file1.c | +N / 替换M | +K | +J | 备注 |
| file2.h | +N / 替换M | +K | +J | 备注 |

## 约束

- **禁止 git commit/push**
- **不修改代码逻辑**：只添加/替换注释
- **不重复添加**：先检查现有注释状态，已有的不覆盖（除非格式不规范需替换）
- **最小改动**：只整理本次任务触碰的模块，不为了风格统一重排无关文件
- **注释语言**：中文为主，必要时保留英文缩写、寄存器名、协议字段名

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

## 代码规范速查（来自 docs/代码规范.md）

### 命名规范
- 全局变量：`g_` 前缀（如 `g_system`、`g_hdl_hp_ctrl`）
- 文件内静态变量：`s_` 前缀（如 `s_port`、`s_tick_acc`）
- 公开函数：带模块前缀（如 `hp_set_mode()`、`uart4g_at_lock()`）
- 私有函数：`static`，可使用短名称

### .c 文件组织顺序
1. include
2. 私有宏
3. 私有 typedef / enum
4. 文件级 `static` 变量
5. **必要的 `static` 函数声明（必须集中在文件头部）**
6. 公开函数定义
7. 私有函数定义

**static 函数声明放置规则**（重要，曾被用户专门指出）：
- 所有 static 函数声明必须**集中**到文件头部的"静态函数声明"区
- **禁止**散落在文件中部（例如临时为了引用某个后置函数而在中段插入声明）
- 当 static 函数较多时，按调用层次分组，每组前加一行 `/* —— 分组名 —— */`：

```c
/* ==================== 静态函数声明（按调用层次分组） ==================== */
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
```

### 大括号风格
- 左大括号单独占一行
- `else` 单独占一行
- 简单保护分支允许不加大括号

### 并发规则
- 共享变量通过互斥/队列/临界区保护
- setter 层负责限幅、互斥和持久化触发
- 不在 `taskENTER_CRITICAL()` 内调用阻塞 I/O
