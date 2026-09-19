---
name: code_wrt
description: "Use when the user invokes /code_wrt or asks to write, simplify, refactor, organize, or standardize embedded C code while preserving architecture, layer boundaries, call relationships, interrupt/service bridges, naming rules, and hardware-safety constraints. Triggers include code_wrt, 写代码, 代码简化整理, 简化并注释, 重构并整理."
---

# Code WRT

**Version: V0.3.0**

`code_wrt` 不再只是“ponytail 简化 + code_zl 注释”。它是嵌入式代码的**写入门禁**：先把层级、Owner、调用关系、中断/回调/服务链、API 和参数语义画清楚，再允许写代码；写完还要重新审查一次。

固定流程：

```text
code_sc(pre-write design gate)
        -> layer/owner/call-contract freeze
        -> ponytail / implementation
        -> code_zl
        -> code_sc(post-write architecture gate)
```

目标：避免“每个函数单看都能跑，但整个 Application 越写越乱”。

## 版本记录

- **V0.3.0**：加入“工程集成不变量”硬门禁：精确基线/SHA、merge 视为新代码、公共头最小化与 Include-What-You-Use、安全宏显式定义、NVIC→向量→强 handler 完整链、临时停波后的重新发波爬升、授权/禁止功率 veto 可达性、1ms 调度与 WCET/看门狗分离、CI/Keil/Host/Board 分级验收。禁止用“两个分支各自 PASS”“能编译”“看门狗不复位”替代合并后完整验证。
- **V0.2.1**：新增强制层级合同、Driver/Application 双向调用规则、ISR→Driver→callback/pending→Application service 链、Application 模块关系表、函数角色命名和参数命名/放置规则。写代码前必须给出 `Layer / Owner / Caller / Callee / Timing / Data / Side Effect`，不能只凭目录名判断分层。
- **V0.2.0**：新增强制 `code_sc` 前后双门禁；引入唯一 Owner、单向依赖、窄 DTO、公共/私有接口、单硬件写点、参数单语义、candidate/approved/committed 命名、Application 内部分层、peer-to-peer mutation 禁令。
- **V0.1.5**：第二阶段对齐 code_zl V0.1.8。
- **V0.1.4**：固件 `SOFT_VERSION` 与 `docs/版本更改/` 门禁。
- **V0.1.3**：任务入口归功能 `.c`；`main()` 只排任务；软件保护不进 SysTick。
- **V0.1.2**：一职一函数、调度只排列调用、硬件单写出口。
- **V0.1.1**：保护与节拍按微逆风格整理。
- **V0.1.0**：首次版本化。

## V0.3.0 — 工程集成不变量（写代码时必须满足）

下面这些不是“建议风格”，而是写入前后都要守住的工程不变量。任何一条没有证据时，不得把任务写成“已经完成”。

### A. 精确基线：先确认你到底在改哪一棵树

写代码前必须记录 repo/worktree、branch/ref、HEAD SHA、dirty files、目标构建入口和当前 CI。用户说“远端最新”“本地刚改”“merge 后 main”时，必须重新读取目标 ref；不能拿旧 ZIP、旧 SHA、旧分支的结论套到新工作树。

**Merge commit 视为全新的代码版本。** 两个父分支分别 PASS，不代表 merge 结果 PASS。冲突解决后必须重新做 API、头文件、ISR、构建工程和安全路径审查。禁止盲选 ours/theirs 后直接宣布完成，也禁止把未 push 的本地改动当成远端事实。

### B. 文件/头文件要少，但不能靠隐藏依赖“省文件”

默认优先复用真实 Owner 的已有头文件，不为一个 DTO、一个宏、一个一行 wrapper 新建独立头。只有在打断真实依赖环、形成独立稳定 ABI/Owner、被多个互不隶属模块直接共享、或属于生成/外部协议合同时，才新建公共头。

放置默认规则：

- 跨 Application 产品参数 -> `app_config.h`
- 模块公共 API/DTO -> 该模块已有 `.h`
- 仅本 `.c` 使用的参数 -> `.c` 顶部
- Driver 参数 -> `drv_xxx.h` / `drv_xxx.c`
- 算法私有结构 -> `src` 私有头，不进入 `app/inc`

**头文件少不等于 main.h 大杂烩。** 禁止把 debug、output、protection、driver、version 等无关配置全部塞进一个“万能 main.h”。

### C. Include What You Use：安全配置不能靠传递包含

某个 `.c` 使用跨模块类型/宏，就必须能明确指出该符号 Owner，并直接 include 对应 Owner 头。禁止依赖 `protection.c -> protection.h -> sample.h -> main.h -> SAFETY_MACRO` 这种“碰巧可见”的链。

对会改变保护行为的编译期宏，必须防止“未定义按 0”静默关闭；要么放进双方都直接依赖的唯一共享配置 Owner，要么使用 `#if !defined(...) #error` 明确失败。不能仅靠注释说默认开启。

### D. 接口变更必须做 Consumer Matrix

新增、删除、重命名 API/typedef/fault bit/header 后，必须搜索 definition、all callers、include sites、test mocks、Keil/CMake project membership、docs/telemetry/protocol decoder。Merge 时特别检查：删除的旧 public header 是否复活、新模块是否仍调用旧 API、声明存在但实现丢失、实现变 `static` 但外部还在调用、互斥的新旧模块是否同时进目标。

### E. 每个已 Enable 的 IRQ 必须闭环到强实现

异步路径必须逐条验证：peripheral IT enable -> `NVIC_EnableIRQ()` -> startup vector -> strong `Xxx_IRQHandler()` -> `drv_xxx_irq_handler()` -> pending/ring/latch -> foreground consumer。只要 NVIC 已开，却只剩 startup weak `Default_Handler`，按运行卡死 P1 处理；不能因为“能链接”就通过。

### F. 物理停波后的重新发波必须有独立安全合同

任何 `MOE=1 -> 0 -> 1`、Duty `nonzero -> 0 -> nonzero` 都是新的 Safety Edge。如果 MPPT/PI 保留旧内部 Duty，Output Executor 不能在重新 Arm 后直接把旧的大 Duty 一拍恢复。

要求顺序：physical OFF -> zero applied -> protection live window -> safe first-duty cap/probe -> bounded rebuild/ramp -> follow candidate duty。重新发波斜坡属于 Output/Executor 生命周期，不能为了方便重新塞回 MPPT 算法 Owner。

### G. “禁止动作”也必须有可达性

任何新增 `power_inhibited`、`maintenance_busy`、`settings_pending`、`storage_blocked`、`safe_to_start` 都必须列 Consumer Matrix，至少检查 start、autostart、restart/recovery、PWM commit、Relay close、Flash/maintenance entry。定义了 veto 但危险路径没消费，等同安全门不存在。

### H. 看门狗证明活着，不证明 1ms 实时性

对 1ms 控制任务必须区分 liveness、deadline、tick accounting。Cortex-M0/M0+ 上新增 float、sqrtf、Flash erase/program、大量日志或长循环时，必须评估 WCET/栈/RAM。至少记录 max control execution time、missed/coalesced tick counter、stack/map 使用和 Flash maintenance worst-case。没有目标证据时写“未验证”，不能用“IWDT 没复位”代替实时性证明。

### I. 一行 helper / wrapper 不默认算“更清晰”

只执行一行的函数只有在建立明确语义/事务边界、唯一硬件写点、多调用者复用、测试 seam、平台抽象或集中审计副作用时才保留。否则优先直接写清楚调用，不为了形式分层制造大量跳转函数。

### J. 提交前完成门

写后 `code_sc` 必须重新基于最终 diff/最终 merge SHA 检查。至少区分 SOURCE contract、architecture/ownership、critical preprocess/config、IRQ-vector-handler、Host/static、Keil/CMake clean build、CI required jobs、Board/Scope。CI 红、关键 job SKIPPED、测试脚本路径失效，都不能写成“验证通过”。

## 必需子技能

**REQUIRED SUB-SKILL:** 修改前完整加载并应用 `code_sc`，执行 pre-write design gate。

**REQUIRED SUB-SKILL:** 完整加载并应用 `ponytail`，默认 `full` 强度。

**REQUIRED SUB-SKILL:** 完整加载并应用 `code_zl`（当前 V0.2.0）。

**REQUIRED SUB-SKILL:** 修改后再次应用 `code_sc`，执行 post-write architecture gate。

任一必需 skill 不可用时停止结构性修改，不得凭记忆模拟。

# 一、写代码前必须先冻结“层级 + Owner + 调用链”

新增或重构跨模块逻辑时，不能先写函数再解释结构。先写以下表，至少覆盖本次触碰的模块：

| 字段 | 必须说明 |
|---|---|
| Layer | ISR / Driver / Adapter-Service / Application Domain / Coordinator / Executor / Observability |
| Owner | 哪个 `.c` 唯一拥有状态或决策 |
| Public API | 对外允许调用的函数 |
| Caller | 谁可以调用 |
| Callee | 它允许再调用谁 |
| Timing | ISR / 1ms task / main-loop every-pass / event driven |
| Input | 数据来自哪里、单位是什么 |
| Output | 返回值/DTO/事件/命令是什么 |
| State Mutation | 修改哪个 Owner 的状态 |
| HW Side Effect | 是否读写硬件；写哪个外设 |

没有这张表，禁止开始跨模块结构性修改。

## 强制原则：一个事实/状态/决策只有一个 Owner

错误：

```c
typedef struct
{
    app_mppt_algorithm_ctx_t algorithm;
    app_charge_stage_ctx_t charge_stage;
} app_mppt_controller_t;
```

这里不是“结构体有点大”，而是 Ownership Inversion：MPPT 算法模块拥有了充电阶段业务状态。

如果两个模块都解释同一个事件，例如：

```text
charge: relay lost 100ms 才判会话失效
mppt: 一帧 relay=false 就 reset tracking
```

必须先统一 Owner 和事件语义，禁止继续堆 if。

# 二、代码层级必须明确，不允许只靠目录名分层

`app/` 和 `driver/` 物理分目录只完成第一层。实际代码至少区分以下角色：

```text
L0 Hardware / Register
        ^
L1 Driver / BSP
        ^
L2 Application Adapter / Service bridge
        ^
L3 Application Domain / Policy / Algorithm
        ^
L4 Application Coordinator / Scheduler

Observability(debug/telemetry) 只旁路读取，不反向控制
Output Executor 是 Application 到 Driver 的唯一执行桥
ISR 是异步入口，不等于业务层
```

推荐理解：

| 层 | 典型内容 | 可以知道什么 | 不能知道什么 |
|---|---|---|---|
| ISR bridge | `USART_IRQHandler`, DMA/ADC IRQ wrapper | IRQ flag / peripheral instance | Charge/MPPT/协议业务 |
| Driver/BSP | GPIO/PWM/ADC/UART/COMP/Flash | 寄存器、DMA、ring buffer、raw event | TC/CC/CV/FC、Battery policy、MPPT strategy |
| Adapter/Service | sample convert、UART frame ingress、output executor | Driver contract + Application DTO | 不应复制产品策略 |
| Domain/Policy | charge stage、battery、protection policy | 工程量、业务状态 | Driver register |
| Algorithm | MPPT/control algorithm | 窄 DTO、限制、算法模式 | Charge Stage ctx、Protection ctx、Relay GPIO |
| Coordinator | main/application service | 各模块 public contract | 不进入算法内部 ctx |
| Observability | debug/telemetry | read-only snapshot | 不允许 setter 改控制状态 |

## 允许的依赖方向

正常下行：

```text
Coordinator
   -> Application task/domain
   -> Adapter/Executor
   -> Driver API
   -> Hardware
```

正常控制算法：

```text
Measurement snapshot
   -> Policy
   -> Algorithm DTO
   -> candidate result
   -> Application/Safety validation
   -> approved command
   -> Output Executor
   -> Driver
```

正常异步上行：

```text
Hardware IRQ
   -> IRQ wrapper
   -> drv_xxx_irq_handler()
   -> driver-owned buffer / pending / neutral callback
   -> Application service/task later consumes
```

禁止：

```text
Driver -> include charge.h/mppt.h/protection.h
Algorithm -> Driver
Algorithm -> Charge Stage / Protection
Debug -> 控制 setter
peer task -> 调另一个 peer task
Application module A <-> module B 双向 mutation
```

# 三、Driver 与 Application 之间的“中断 / 回调 / Service”必须画完整链

这是 V0.2.1 的硬门禁。触碰 UART/ADC/DMA/COMP/PWM/Timer/EXTI 等异步路径时，必须明确完整路径，不能只写一个 callback 名字。

## 3.1 ISR wrapper

芯片中断入口只做桥接：

```c
void USART1_IRQHandler(void)
{
    drv_uart_irq_handler();
}
```

IRQ wrapper 不允许：

- 解析协议；
- 改 Charge/MPPT stage；
- printf；
- 阻塞等待；
- 调 `app_task_*`；
- 直接写 Flash；
- 在 UART/ADC ISR 中执行复杂控制算法。

## 3.2 Driver IRQ handler

`drv_xxx_irq_handler()` 只处理 Driver 自己拥有的硬件事实：

```text
读/清 IRQ flag
搬字节
更新 DMA/ring buffer
保存 timestamp/sequence
置 pending/event
触发“中性回调”
```

Driver 不得 include Application 业务头文件。

## 3.3 Callback 规则

如果使用 callback，上层注册接口可以是：

```c
typedef void (*drv_adc_block_cb_t)(const drv_adc_block_t *block,
                                   void *user_ctx);

void drv_adc_set_block_callback(drv_adc_block_cb_t cb,
                                void *user_ctx);
```

规则：

- callback type 定义在 Driver contract；
- Driver 只认识函数指针和中性 payload，不认识 `app_sample_t`/`charge_ctx_t`；
- callback 如果在 ISR context 执行，必须在 API 注释明确写“ISR context”；
- ISR callback 只允许复制最小 metadata / 置 pending / 入队；
- callback 里禁止跑完整业务状态机和输出执行；
- `user_ctx` 是 opaque 指针，Driver 不解析其 Application 类型。

如果 callback 没有必要，优先 Driver 提供 `read/take/pending` API，由 Application service 主动消费。

## 3.4 Service / Task 规则

`service` 不是“什么都塞进去”的万能函数。

命名语义：

```text
drv_xxx_service()   -> Driver 自己的 deferred work
app_task_xxx()      -> Scheduler 调用的 Application 顶层任务
app_xxx_service()   -> Application 模块自己的事件/队列服务
xxx_step()          -> 一次确定性的状态/控制推进
xxx_apply()/commit()-> 执行/提交 side effect
```

典型链：

```text
ADC DMA IRQ
 -> drv_adc_irq_handler()
 -> publish block/pending
 -> app_task_sample()
 -> sample_convert()
 -> publish app_sample_snapshot
 -> app_task_protect()
 -> app_task_charge()
 -> app_task_output()
```

不允许：

```text
DRV ADC callback -> app_task_charge()
app_task_charge() -> app_task_output()
app_task_output() -> app_task_protect()
```

顶层 task 的调度顺序由 Coordinator/main 决定，不允许 peer task 互相嵌套调用。

# 四、Application 内部模块关系必须明确

对于控制类固件，推荐关系如下。工程可换模块名，但责任和方向要保持清楚：

```text
sample
  -> measurement snapshot
       |
       +-> protection -> safety decision/event
       |
       +-> charge policy/session
               |
               +-> mppt narrow DTO -> candidate duty
               |
               +-> approved charge command
                            |
                            v
                         output
                            |
                            v
                          driver

debug/telemetry <- read-only snapshots from sample/protection/charge/mppt/output
```

参考 Owner：

| 模块 | Owner 内容 | 允许直接调用 | 禁止 |
|---|---|---|---|
| `sample.c` | ADC 工程量快照、sequence、validity | Driver read/take | 改 charge/protection |
| `protection.c` | fault state、恢复资格、安全 decision | sample/read-only HW facts | 直接写 PWM/Relay；直接改 charge internals |
| `charge.c` | OFF/WAIT/PRECHARGE/RELAY/RUN/FAULT session、业务编排 | charge policy、MPPT public API、read-only safety snapshot | 直接改 MPPT private ctx；直接寄存器写 |
| `charge_stage.c` | TC/CC/CV/FC、battery charge policy | battery/profile inputs | `clear_power_integral` 等算法内部命令 |
| `mppt.c` | MPPT public algorithm package、candidate Duty | private algorithm implementation | charge stage ctx、protection ctx、driver |
| `output.c` | approved command -> PWM/Relay executor | Driver API、final safety check | 反向制定 charge policy |
| `debug.c` | UART/debug/telemetry/read-only diag | getters/snapshots | 调 control setters |

如果项目需要 Application Coordinator，可单独存在；但不能再造一个无边界的 `app_runtime.c` 把所有逻辑搬进去。

## Peer 模块调用规则

- peer module 可以调用对方**稳定、只读或窄语义 public API**，前提是依赖单向且无环；
- peer module 不允许调用对方 `app_task_*`；
- peer module 默认不允许直接 setter 修改对方内部状态；
- 跨 Owner 的“请求”优先变成 event/command/decision，由 Coordinator 归并；
- 如果 A 必须调 B，B 又必须调 A，先认定为架构风险，不能用 callback 掩盖环依赖。

# 五、跨模块接口只传必要 DTO，不传整个世界

默认禁止把这些整对象直接交给算法/子模块：

```c
app_sample_t *
app_charge_stage_ctx_t *
app_battery_profile_t *
app_protection_t *
app_charge_ctx_t *
```

如果算法只需 Vpv/Ipv/Ppv/Vbat 和限制，应使用窄 DTO：

```c
typedef struct
{
    int32_t pv_mv;
    int32_t pv_i_ma;
    int32_t pv_power_mw;
    int32_t bat_mv;
    uint32_t power_limit_mw;
    uint16_t applied_duty_permille;
    uint16_t duty_limit_permille;
} app_mppt_duty_in_t;
```

DTO 规则：

- 字段必须是下游真实需要；
- 单位进入名字；
- 上游先完成 validity/stale/safety qualification；
- 不把 fault/session/stage/profile 等无关上层概念塞进去；
- 不为了“以后可能用”预埋字段；
- giant DTO 只是 giant context 换名字，同样禁止。

跨模块边界优先窄 DTO/显式参数；模块内部 helper 在 Owner 清楚、生命周期明确时可以读本模块 private static snapshot。

# 六、公共头只暴露合同，内部实现必须私有

公共 `app/inc/*.h` 只允许暴露：

- 稳定业务 DTO；
- 属于本模块的稳定 enum；
- public API；
- 明确 read-only 的 diagnostic snapshot。

禁止公共头暴露：

- PI integral；
- search internals；
- private state-machine ctx；
- 仅本模块使用的 helper；
- `clear_power_integral`、`reset_tracking` 这类实现细节命令。

算法内部头优先放 `app/src/*_priv.h` 或私有目录，并 grep 确保只有所属实现 include。

# 七、类型必须放在真正 Owner 的模块

错误：完整 Charge Session enum（WAIT/PRECHARGE/RUN/FAULT）定义在 `charge_stage.h`，导致 MPPT 为了判断 RUN include Stage。

正确归属：

```text
Session enum          -> charge contract
TC/CC/CV/FC           -> charge policy
MPPT internal mode    -> mppt private/public contract as appropriate
Fault bits/decision   -> protection
HW command/snapshot   -> output/driver contract
```

不要因为“这里刚好也会用”就把 enum/struct 放错 header。

# 八、函数命名必须表达“层级 + Owner + 动作 + 对象”

禁止仅靠 `process() / handle() / do_work() / run()` 让调用者猜用途。

## 8.1 推荐函数角色

| 角色 | 推荐命名 | 语义 |
|---|---|---|
| IRQ wrapper | `USARTx_IRQHandler` | 芯片向量入口，只桥接 Driver |
| Driver IRQ | `drv_uart_irq_handler` | Driver ISR 处理 |
| Driver init | `drv_pwm_init` | 只初始化 Driver/HW |
| Driver get/read | `drv_adc_read_raw` | 获取 Driver 拥有数据 |
| Driver write | `drv_pwm_set_duty` | 直接影响硬件，必须是明确 Driver API |
| App scheduler entry | `app_task_charge` | main/coordinator 调用的顶层任务 |
| State update | `app_charge_step` | 单次状态推进，不自己决定调度时机 |
| Service | `app_uart_service` | 消费本模块 pending/queue |
| Algorithm step | `app_mppt_duty_step` | 输入 DTO，输出候选控制量 |
| Executor | `app_output_apply` / `pwm_apply` | 提交已批准命令 |
| Snapshot getter | `app_charge_snapshot_get` | read-only snapshot |
| Event consume | `xxx_event_take` | 明确“取走/消费”语义 |
| Session reset | `app_mppt_session_reset` | reset 范围写进名字 |

## 8.2 `init/start/stop/reset/service/step/apply/commit` 不能混用

- `init`：对象/硬件初始化，不承担正常运行策略；
- `start/stop`：生命周期切换；
- `reset_xxx`：必须说明 reset 的范围；
- `step`：单次推进，调用时机由上层决定；
- `service`：消费 pending/deferred work，不等于万能业务函数；
- `apply`：把已决定的命令写到执行层；
- `commit`：强调不可逆/原子提交，例如 Flash/配置提交；
- `get/read` 默认不修改业务状态；若寄存器 read-clear，必须写在 API contract；
- `set/write` 必须由真实 Owner 提供，不能成为 peer mutation 逃生口。

同一模块不能同时出现三四套近义生命周期函数让调用者猜：

```text
app_mppt_init
app_mppt_controller_init
app_mppt_algorithm_init
app_mppt_restart
```

先收敛层级，再命名。

# 九、函数参数命名与放置必须符合语义

## 9.1 参数顺序

推荐顺序：

```c
return_type module_func(module_ctx_t *ctx,
                        const module_input_t *in,
                        uint32_t now_ms,
                        module_output_t *out);
```

原则：

1. Owner ctx（若需要）放最前；
2. 只读输入用 `const`；
3. 时间/limit 等少量标量放中间；
4. 输出指针放最后；
5. 不能同时用返回值和 `out` 表示同一个结果；
6. 不允许未说明 alias 的 input/output 指向同一对象。

## 9.2 参数名必须带角色和单位

推荐：

```text
now_ms
timeout_ms
pv_mv
pv_i_ma
pv_power_mw
power_limit_mw
duty_limit_permille
candidate_duty_permille
approved_duty_permille
committed_duty_permille
sample_sequence
frame_len
channel_count
profile_id
```

禁止含糊：

```text
value
data
para
flag
state
status
temp
num
len        # 不知道是什么长度
mode       # 不知道谁的 mode
reset      # 不知道清什么
```

如果确实使用 `state/status/mode`，必须带 Owner：

```text
charge_state
mppt_mode
protection_status
relay_state
```

## 9.3 bool 用正向语义

推荐：

```text
enable
valid
ready
pwm_active
relay_request_on
fault_active
sample_fresh
```

避免：

```text
flag1
not_disable
no_error
is_ok2
```

如果 bool 代表命令和事实，必须分开：

```text
relay_request_on     # command
relay_odr_on         # GPIO mirror
relay_contact_closed # 真实反馈
```

## 9.4 ctx / in / out 的含义固定

- `ctx`：本模块拥有的可变上下文；
- `in`：本次调用只读输入；
- `out`：本次输出；
- `snapshot`：某一时刻只读事实快照；
- `cmd`：已形成的命令；
- `event`：离散事件；
- `pending`：尚未消费的异步事实。

Driver API 不得拿 `app_*_ctx_t *`；Algorithm API 不得拿 Driver ctx。

# 十、参数一个值只表达一个语义

禁止 Semantic Overloading：

```text
power_allow_mw == 0
有时 = HARD STOP
有时 = SOFT ZERO
```

应该拆成：

```text
numeric power_limit + explicit control mode/session semantics
```

同样禁止：

- `pwm_active` 同时表示 request、MOE、compare 已生效；
- `relay_applied` 实际只是 GPIO ODR 镜像；
- 一个 `reset` 同时清 session、PI、search、duty。

# 十一、控制流水线命名必须可追踪

Duty/PWM 至少区分：

```text
candidate_duty_permille   # 算法候选
approved_duty_permille    # Application/Safety 批准
committed_duty_permille   # 已交给 executor/driver
hardware_duty_permille    # HW/寄存器实际值
```

控制链：

```text
Measurement
   -> Policy / Algorithm
   -> Candidate
   -> Application Safety Envelope
   -> Approved Command
   -> protection epoch recheck
   -> Output Executor
   -> Driver / HW
```

算法只能产候选，不得直接写 PWM/Relay、清 protection fault、绕过 cap 或决定 STOP 会话生命周期。

# 十二、硬件必须单写出口

PWM、Relay、Flash commit、关键 EN 脚必须有唯一主写点。

推荐：

```text
charge/mppt/protection -> command/event only
output.c               -> app_output_apply / app_relay_set / pwm_apply
Driver                  -> register write
```

禁止多个 `.c` 写同一 GPIO/CCR/MOE。

若 COMP/Break/ISR 能异步关 PWM，主循环恢复前必须有 epoch/session gate，防止同拍重新发波。

# 十三、函数真实依赖必须出现在签名或模块合同里

如果函数已经传 `hw_snapshot`，内部又偷偷：

```c
DRV_PWM_IsOutputEnabled();
app_protection_latest();
```

必须判断：

- 无意 hidden dependency -> 删除；
- 有意 final safety recheck -> 移到 executor/safety-commit，并在 API contract 明写。

禁止注释说“不访问硬件”而实现直接读 Driver。

# 十四、避免 peer-to-peer mutation

危险：

```text
charge -> protection_latch()
protection -> charge_lock_startup()
output -> protection_latch() + charge_lock_startup()
```

不要继续加 setter。让 Coordinator 汇总 event/decision，或者使用单向 command/event contract。

# 十五、一个业务约束只允许一个 Policy Owner

例如：

```text
300W limit
PV * 8A
BAT * 6A
battery target
charge-stage power allowance
```

可以 defence-in-depth，但第二层只能验证/钳位，不应复制整套业务公式。

# 十六、Config 按 Owner 拆

大 `app_config.h` 要审查归属：

```text
Product/Safety
Charge Policy
Algorithm Tuning
Driver/HW
Debug/Telemetry
```

算法工程师为了调 Kp/Ki 不应该被迫读 Relay/Protection/Battery 全部宏。应拆 `mppt_config.h` 等专属配置。

# 十七、Dead Contract / Zombie Interface 不允许新增

写完搜索：

- enum/action 是否有 producer；
- flag 是否永远常量；
- request/restart/park 是否没人设置；
- 注释说支持的路径是否实际被 reject；
- result/diag 是否重复镜像同一事实；
- 新增 API 是否有真实 caller。

# 十八、故障检测、主循环与节拍

保留既有约束：

- `Fault_Detection()` 只调度；一类故障一个 `Fault_Xxx()`；检测与已有恢复同函数；
- 不发明恢复；保护阈值不擅改；
- SysTick 只 `drv_time_tick_isr()` / 置标志；
- `main()` 是任务目录；
- UART ISR 搬字节，ADC/DMA ISR 产数/置 pending；
- 一个业务不要 ISR 和 main 各跑一套判据；
- `Fault_*` 不直接关 PWM，硬件写走 executor/driver 唯一出口。

典型主循环：

```c
while (1)
{
    app_task_uart(now_ms);
    app_task_sample();

    if (drv_time_1ms_taken())
    {
        app_task_protect(tick_ms);
        app_task_charge(tick_ms);
        app_task_output(tick_ms);
        app_task_recover(tick_ms);
    }

    app_task_telemetry(now_ms);
}
```

`app_task_charge()` 不得自己调用 `app_task_output()`；调度顺序属于 main/Coordinator。

# 十九、code_wrt 固定工作流

## Phase A — pre-write code_sc + layer contract

修改前必须：

1. 读取目标模块和必要调用链；
2. 写 Layer/Owner 表；
3. 写 caller -> callee 边表；
4. 若涉及中断，写 IRQ -> driver -> pending/callback -> service/task 全链；
5. 给 Application peer modules 写允许/禁止直接关系；
6. 确定 API/DTO、类型归属和参数名字；
7. 确定硬件单写点和 safety envelope；
8. 检查 include/call graph 是否已有环；
9. 如果设计会制造 Ownership Inversion / Fat Interface / peer mutation / reverse dependency，停止写代码，先修设计。

## Phase B — ponytail / implementation

- 删除/内联冗余；
- 复用已有能力；
- 函数名必须体现 layer/owner/action/object；
- 参数遵守 ctx/in/out、单位、正向 bool、单语义规则；
- 不确定行为等价时保留原逻辑并明确风险。

## Phase C — code_zl

按 code_zl V0.1.8 做函数头、白话注释、分节、格式、先定义再使用和 `// todo:`。

函数头 Description 至少能回答：

```text
谁调用 / 什么时候调用 / 数据从哪里来 / 改什么状态 / 是否有硬件副作用 / 失败如何处理
```

## Phase D — post-write code_sc

至少验证：

- Layer 方向未反转；
- Owner 表仍唯一；
- caller/callee 图无新 SCC/环；
- ISR callback 没跑业务；
- peer task 没互相调用；
- 没新增 cross-domain giant context；
- 公共头没泄漏 private ctx；
- 参数名/单位/command-vs-fact 语义正确；
- 没新增硬件第二写点；
- debug/telemetry 没反向控制；
- 算法结果仍过 Application/Safety；
- ISR/main shared state 有并发保护；
- 没 dead enum/flag/API。

# 二十、配置、注释与版本门禁

- `.c` 分节：`/* 标题 */`；
- `.h` 分节：`//=================== 标题 ===========================`；
- Init/SysClk：按“配置了什么”分节，不逐行翻译寄存器；
- `config.h` 宏写用途、单位/枚举、当前值；
- 注释不能掩盖坏架构，Owner 错误先整改；
- 凡进入固件镜像的结构/行为变更，按项目约定升 `SOFT_VERSION`、追加同阶段版本文档、同步 docs README；未上板不得写 BOARD_PASS。

# 二十一、验证

结构性修改至少做：

- build/compile；
- 相关 host tests；
- include boundary grep；
- caller/callee 搜索；
- IRQ/callback/service 链审查；
- Application module relation 审查；
- 硬件写点搜索；
- ISR/main/shared-state 并发审查；
- fake/stub 越界测试（算法/策略可替换时）。

可替换算法至少测试：

```text
fake normal output -> Application 正常运行
fake over-limit output -> Application/Safety 必须阻断
```

# 边界

- 纯注释 -> `/code_zl`；
- 只读深度审查 -> `/code_sc`；
- `/code_wrt` 可做结构整改，但不得擅改保护阈值、协议、硬件时序或产品策略；
- 不确定业务语义时先报告并保留行为；
- 默认不扩大用户指定写范围；为了确认层级/调用/Owner 可只读必要调用链；
- 不自动 commit/push，除非用户明确要求。

# 报告

完成后必须报告：

1. **Layer Contract**：Driver/Application/ISR/Service/Executor/Observability 层级；
2. **Owner Matrix**：每个关键状态/决策归谁；
3. **Call Graph**：关键 caller -> callee；
4. **IRQ/Callback/Service Chain**：涉及异步路径时必须给出；
5. **API/Parameter Contract**：函数名、参数名、单位、DTO、类型归属；
6. **Pre-write Code_SC**：已有风险；
7. **Implementation/Ponytail**：改了什么；
8. **Code_ZL**：注释/分节/格式；
9. **Post-write Code_SC**：环依赖、Fat Interface、Owner 冲突、隐藏依赖、多写点、死接口结果；
10. **Verification**：build/tests/grep/并发与安全检查；
11. **Version**：新 SOFT_VERSION 和文档，或明确为何未升。
