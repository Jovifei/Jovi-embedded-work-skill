---

name: code_wrt

description: "Use when writing, simplifying, refactoring, or renaming embedded C code where behavior, module boundaries, timing, or hardware safety matter. Triggers: code_wrt, 写代码, 代码简化整理, 简化并注释, 重构并整理, 函数改名, 参数改名, API命名收口."

---

# Code WRT

**Version: V0.4.2**

`code_wrt` 不再只是“ponytail 简化 + code_zl 注释”。它是嵌入式代码的**写入门禁**：先把层级、Owner、调用关系、中断/回调/服务链、API 和参数语义画清楚，再允许写代码；写完还要重新审查一次。

## 本次最小执行与完成门

- **先定写入范围和基线。** 区分方案、只读审核、注释整理和实施。用本次指定的工作树、暂存版本或提交核对真实调用链，保留用户已有的修改。涉及指定位置、位段或字段时，只处理该范围。若需扩大范围或新增拒收、限幅、停机条件，先列出依据、触发场景和影响，请用户定下边界。能从源码查清的事实先自行核实，已授权的工作继续完成。
- **内外合同分别核对。** 用户允许更改内部 API/DTO 时，按消费者迁移。对外接收、转发、界面和遥测继续按约定的位段、编码、单位和值域处理。板卡本地限制在其执行责任方生效。另一 AI 的提议须用真实调用链和证据核对，用户明确采用的内容才计入变更范围。
- **用运行路径证明改动。** 去重或迁移前后核对同一快照、实际决策方、状态更新次数、模式专属分支和硬件复核位置。按第九节和单一真源门禁处理，给每一批独立的验收标准。
- 自有 app_/drv_ 按项目 snake_case。SDK/CMSIS、startup IRQ、外部 callback ABI 和协议名保留合同。改名按第八节核对完整使用链。私有类型和宏归实际责任方，收窄接口时核对参数的单位、生命周期、决策点及覆盖位置。
- 命名合同必须先取当前项目已经拍板的版本；不能把一次报告、旧 ZIP、历史学习快照或自己的偏好当成新规则。改名矩阵必须分成“当前源码”“历史材料”“SDK/协议/ABI”“测试/decoder”，历史命中不能直接当活动残留，活动残留也不能靠历史别名掩盖。
- 当前授权包含结构整理时，struct 成员按相同声明类型集中，同类型保留原相对/用途顺序；float、uint32_t、int32_t、uint16_t、uint8_t、bool 分别成组，bool 与 uint8_t 不因同宽合组。组序优先项目约定，否则通常按目标自然对齐/宽度从大到小。重排前查全部位置式/指定式初始化器、offsetof/sizeof、raw memcpy/序列化、Flash/协议/DMA/寄存器/packed/bitfield/ABI/汇编/回调约束；外部固定布局保留并记录例外。可改内部结构保持字段语义/类型，更新依赖的初始化与检查后验证目标布局；无目标证明不宣称固定 RAM 节省。用户说的是成员，不改函数形参顺序，不为分组新增嵌套 struct 或头文件。
- 字段/状态/getter/诊断先列 producer 和 consumer：控制必需、协议/存储、当前授权遥测、仅测试观察、只写副本。积分/滤波/回算、缓存、seq 去重、故障代次和时序记忆即使不对外导出仍可能必需。删除导出镜像时同步将测试改为实际内部或行为断言，不恢复生产副本迎合旧夹具，也不一概删除诊断。
- wrapper/恒 true prepare 先查所有返回路径和 caller 分支，确认无失败合同才收为 void/直接调用；硬件事务、ABI、IRQ 桥和有真实消费者的 getter 不按行数删除。保留准备零→自然更新/ZeroApplied→允许首脉冲，以及末脉冲、PWM 写前/写后/恢复中断否决和失败撤回；按事件时间点对照，不在等价检查里忽略整段时序函数。
- 除非另有说明，按量产工程审视现行路径。按用途区分正式控制、现场诊断和已退役的开发测试资产。先查生产处、运行/Host 消费者、接收工具和操作文档。未拍板的功能删留请用户确认。减包时保留用户需要的观测与开关，核对实际接收端、字段单位与编解码。配置缺省值以当前源码和实际目标设置为准。
- 用户明确授权取消某项 `#error` 时，不以 assert/typedef 等替身绕回；这不是一般撤销保护许可。仍核对预处理宏真值、直接依赖和实际运行安全门。
- 完成证据绑定最终 SHA 或工作树内容 hash、目标及 define/include、命令/退出码、旧名残留分类、测试/项目/文档合同和未运行项。Host/目标编译/架构审查/实板分开，缺证据写未验证。技能版本只在技能维护时升；固件行为变化按项目约定升固件版本，纯注释/文档不升固件版本。

细化反例见 [examples.md](examples.md) 和 `evals/evals.json`；本节限定后文固定流程的适用范围。

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

- **V0.4.2**：把实际职责迁移、同拍状态、缓存、适用的协议和 Git 授权、目标镜像减容证据与注释覆盖纳入执行检查。用项目现行合同判断命名，保留 V0.4.1 的按函数体和完整使用链改名要求。

- **V0.3.2**：按实际范围收口消费者、改名和短函数合同；增加结构体同类型分组、初始化与固定布局保护；补路测最小字段、时间点等价证据及授权例外；分离技能与固件版本。
- **V0.3.3**：增加可变 `ctx` 生命周期与真实调用域门禁；增加多布尔参数语义矩阵；增加整数提升、计时上限、饱和与回绕边界检查。
- **V0.3.5**：函数名必须对得上函数体；同一判断只写一次。禁止把不同问题收成同一个 `ok`，禁止 `static` 使用 `app_`，禁止叠模块前缀，禁止为抄一份中间值或永远走不到的编译分支留重复逻辑。
- **V0.4.0**：增加分层命名合同、同后缀不同职责判定、候选/提交/驱动设定语义复核，以及 `floor/boundary/max`、控制时基和 Demo 专属名称门禁。禁止为了“避免两个函数都叫 step”强行改成不完整的职责名。
- **V0.3.4**：同步 `code_zl` 依赖版本，并明确 `todo` 规则只描述原则，不固化某个工程的函数、任务或宏名称。
- **V0.3.0**：加入“工程集成不变量”硬门禁：精确基线/SHA、merge 视为新代码、公共头最小化与 Include-What-You-Use、安全宏显式定义、NVIC→向量→强 handler 完整链、临时停波后的重新发波爬升、授权/禁止功率 veto 可达性、1ms 调度与 WCET/看门狗分离、CI/Keil/Host/Board 分级验收。禁止用“两个分支各自 PASS”“能编译”“看门狗不复位”替代合并后完整验证。
- **V0.3.1**：针对 V0.13.18 代码整理补充最小改动门禁、单一实现/单一参数真源、删除前全工程检索、生产 API 与测试夹具同步删除、重构后强制多入口复核、版本与文档边界、物理行为保护、简明检查表和失败回滚原则。

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

对会改变保护行为的编译期宏，必须防止“未定义按 0”静默关闭；默认采用直接依赖唯一配置 Owner 和必要的显式编译检查，不能仅靠注释说默认开启。用户明确授权移除某项编译检查时按文首边界处理，不强制重新加入 `#error` 或其替身，仍核对每个消费单元的实际宏值与运行安全门。

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

**REQUIRED SUB-SKILL:** 加载并应用当前可用的 `code_zl`。按本次改动检查函数头、关键逻辑行和项目格式。

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

    uint16_t committed_duty_permille;

    uint16_t max_duty_permille;

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

# 八、函数命名要表达职责、对象与产物

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

| Algorithm entry | `mppt_algo_step` / `mppt_search_step` | 示例分别表示算法编排和搜索参考电压，公开门面按项目现行合同命名 |

| Executor | `app_output_apply` / `pwm_apply` | 提交已批准命令 |

| Snapshot getter | `app_charge_snapshot_get` | read-only snapshot |

| Event consume | `xxx_event_take` | 明确“取走/消费”语义 |

| Session reset | `app_mppt_session_reset` | reset 范围写进名字 |

## 8.2 `init/start/stop/reset/service/step/apply/commit` 不能混用

- `init`：对象/硬件初始化，不承担正常运行策略；

- `start/stop`：生命周期切换；

- `reset_xxx`：必须说明 reset 的范围；

- `step`：单次推进，调用时机由上层决定，名字要能看出推进什么。

- `dispatch`：只选路径。`evaluate`：应能说明求值产物，包括本次会写的内部状态。

- `calculate`、`select`、`clamp` 用于对应的计算、选择或限幅。会更新时基、状态或诊断的函数应把实际动作写进名字，单纯判断使用 `is_*`、`*_ok` 或 `*_valid`。

- `service`：消费 pending/deferred work，不等于万能业务函数；

- `apply`：应用限制、扰动或命令，按参数、模块和注释交代实际改的是内部状态还是执行器。

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

## 8.3 从实际函数体、使用处和作用域确定命名

写或改名前先读函数体、返回值、输出参数和副作用。只在授权范围处理命名与重复判断。名称太窄时按实际主要产物调整，或把需要另做的职责拆分作为独立变更。

名字按实际动作取：

- 按当前项目区分公共接口、模块编排、内部工具和私有类型。预留给公开接口的前缀留给公开接口。语义清楚的内部短名和纯数学函数可省模块前缀。
- 已有模块词的名字只替换前缀，不要叠成 `charge_stage_stage_*`。硬件动作留在名字里，例如 `output_pwm_apply`，不要收成看不出写什么的 `output_apply`。
- 纯判断才用 `ok` 或 `valid`。问的不是同一件事，就不能收成同一个尾词。采样够不够格、电池在不在窗口、温度允不允许启动、输出是不是空闲，各自保留对象词。
- 会改状态的用 `update`、`step`、`enter`、`reset`、`latch`。这种函数不要叫 `ok`。
- 返回功率、电压、占空比的名字带单位。不要把返回数值的函数改成判断名。

重复逻辑按下面收：

- 合并资格检查前确认检查对象、数据身份、读取时点和副作用一致。等价整理保留短路顺序和不同时间读取现场的保护检查。只决定是否调用子算法的判断，继续让上层完成清理、事件和保护工作。
- 可证明没有跨拍消费者的中间值留在当前求值范围。历史状态、限制来源和诊断先按消费者核实，再按授权删减。
- 抽函数应解决真实职责或复用，调用者仍能看清提交、保护和诊断的先后顺序。小型纯换算先找职责合适的现有文件，新增文件需要独立归属或其他具体理由。
- 数值相同的门槛不是同一个参数。预充压差、健康窗摆动、源塌陷各自保留。

## 8.4 已拍板模块的分层命名合同

先写旧名、新名、所属层级、责任方、输入单位、实际产物与副作用。核对所有声明、定义、调用、回调、测试夹具、解码工具和当前文档。入口、DTO、辅助函数及 init/reset 等关联命名一起复核，只有确属同一个合同才成套改名。

按该项目确认过的命名规则执行。下表是 MPPT 的例子，字段与函数须以目标工作树的实际合同为准。

| 对象 | 当前合同 | 不能用的替代理由 |
|---|---|---|
| 公开 Application 门面 | 使用项目的公开前缀，名称体现求值产物，如 `app_mppt_evaluate_candidate_duty()` | 公开门面和私有类型各按其合同命名 |
| 搜索入口 | `mppt_search_*`，例如 `mppt_search_step()` | 不用泛称 `*_step()` 混淆完整算法 |
| 算法编排 | `mppt_algo_*`，例如 `mppt_algo_control_step()` | 不要因为名称含 `step` 就强行改成不完整的“limits_to_duty” |
| 功率到 Duty 控制器 | `mppt_algo_duty_controller_step()` | 它包含前馈、功率 PI、候选 Duty 约束；不能只写成预算转换 |
| 搜索内部 `static` helper | 用短的语义名，例如 `update_vref_step()`、`process_search_average_window()`、`demo_update_search_resume_permission()` | 不再叠加 `mppt_search_mppt_*` 或为了层级前缀破坏内部可读性 |
| 纯数学 helper | 不加模块前缀，例如 `clamp_float_range()`、`calculate_power_mw()` | 不要给每个数学函数再套一层 `mppt_algo_` |
| 私有类型 | 使用真实 Owner 前缀，例如 `mppt_search_ctx_t`、`mppt_algo_input_t` | 不用 `app_` 假装是公开接口 |
| Demo 专属状态/参数 | 带 `demo_`，例如 `demo_startup_duty_floor_permille`、`demo_freeze_normal_search` | `startup_*`、`passive_start` 等没有 Demo 语义时容易被 Battery 路径误用 |
| Vref | 保留 `vref`，例如 `vref_mv`、`vref_upper_mv`、`update_vref_step()` | 不把参考电压改成泛称 `target_voltage` |

职责清楚的函数可以共享 `step` 后缀。核对词义所指是一次状态推进还是数值步长。分发、窗口统计、计算和应用等行为各自按实命名。只分发的入口不能称为直接计算或提交，既处理暂停又推进窗口的函数也不能只按一个中间结果命名。

参数和字段继续遵守控制流水线：

```text
candidate_duty_permille  -> 算法/策略提出的候选
approved_duty_permille   -> Application/Safety 批准后允许的值
committed_duty_permille  -> 已交给 Output/Driver 的设定
hardware_duty_permille   -> 定时器/硬件实际生效值（需硬件证据）
```

`drv_pwm_get_duty()` 返回的已提交设定不能命名为 `candidate_*`；理论 CCM 边界不能叫最终 `max_*`；`demo_startup_duty_floor_permille` 是启动地板值，不能在注释里写成永久上限；`last_control_ms` 是控制时基处理点，是否真的积分必须结合 `control_dt_ms` 判断。发现这些语义冲突时，优先修正命名或交给 `code_zl` 修正注释，不能用注释掩盖错误命名。

## 8.5 命名迁移完成门

命名改动完成前必须逐项检查：

1. 活动源码中旧名的定义、声明、调用、回调、初始化器、测试和 decoder 已迁移；历史文档命中单列。
2. 新名没有把函数层级、Owner、动作、对象或单位说错；返回数值的函数带单位或明确的结果角色。
3. `static` helper 没有不必要的叠层前缀；公开 API、模块编排和纯数学 helper 的前缀边界清楚。
4. 候选、批准、提交和硬件生效的数据来源保持一致。按受影响范围做目标编译或静态检查，复用相关 Host/行为对照并注明未运行项。
5. 当前文档、学习索引和活动测试使用新名；旧名只在明确标注的历史基线、SDK/协议 ABI 或兼容适配层保留。

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

max_duty_permille

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

## 9.5 可变 ctx 的生命周期与并发合同

凡函数接收 `module_ctx_t *ctx`，写入前必须查清并记录：

- Owner 是谁；初始化/重置入口是什么；首次合法调用和失效条件是什么；
- ctx 在哪个会话或任务周期内保持有效；函数会改写哪些字段；
- 实际调用域是主循环、任务、ISR、回调还是多线程；谁是唯一写者，谁只读。

初始化、重置和状态切换还要列出“清零/保留字段矩阵”：局部去抖、采样端点、尾流计时、会话累计、故障代次分别在哪个入口清除，哪些跨阶段保留。不能只写一个笼统的 `reset`。

不能仅凭“可能多线程”就要求加锁。若源码证明是单一主循环/任务单写者，应保留单写模型并在函数合同中写明；若 ISR 只产生事件，使用 pending、快照或队列桥接到前台。确有共享读写时才选最短临界区、互斥或原子快照；ISR 不取阻塞锁，临界区内不做阻塞 I/O。`ctx` 不得保存调用者栈上或短生命周期对象的裸指针。

## 9.6 多布尔参数必须有语义矩阵

多个 `bool` 涉及业务、安全或时序时，核对各自的真/假含义、来源和时点、何处消费，以及它是事实、资格、命令、事件还是否决。说明影响的状态迁移、计时或安全复核。互斥模式由明确的模式字段表达，避免用启动下限、目标为零等别的数值推断。彼此独立的事实仍可保留各自的布尔量。

## 9.7 整数提升与计时上界门禁

计数乘周期、窄化或删溢出检查前，按受支持的输入范围核算中间值、符号和 C 整数提升。需要加宽时在运算前转换。等价换算还要核对乘除顺序、截断、饱和和允许的无符号计时回绕。宏或类型变化后重新推导上界，并验证边界值。

连续时间必须绑定正确的端点身份：样本有效时间、真实传能时间和尾流资格时间各自记录 sequence/时间戳，首帧只立端点，重复样本和坏间隔不能拼接连续资格；不能用主循环调用次数代替生产者时间。

## 9.8 候选、最终复核与提交必须分层

完成、判满、故障恢复等会改变阶段或执行意图的结果，先写候选状态，再由安全 Owner 在同一采样、命令代次、保护代次和硬件回执仍有效时最终复核并提交。复核失败只撤销候选，不复制整份 ctx 做猜测回滚，也不能把 `pending` 注释成“已经完成”。

## 9.9 预览、正式状态与缓存

- 用预览帮助阶段决策时，沿调用和指针确认实际读写。副本不可通过共享指针回写正式滤波、锁存、积分、计时或其他状态，也不可写硬件。按状态合同在正式更新点提交该事件一次。阶段切换时明确哪些证据用于推进，哪些正式结果用于本拍资格、批准和诊断。
- 若现有预览已经改了正式状态，移除该写入可能改变控制结果。只授权等价整理时，记录影响、保留首个差异，并将行为修复单独确认，继续能独立证明等价的部分。
- 缓存命中依据实际输入合同。对影响输出、状态或原因的采样序号/采集时刻、有效性、模式、目标和限制来源分别核对，按同一输入的保留、收紧或失效规则处理。不凭序号相同或最终限值相等就沿用旧候选。
- 对照、追踪日志和 Host 新旧双算留在观察或验证路径。生产批准只用正式计算和已有安全依据，不为迁移对照新设关波条件。

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

先按实际生产者和消费者分别解释合法零、约束未启用、输入无效和明确要求停机。对外接口有既定编码时保留其定义，内部可用有效位或独立原因表达差异。最终限值和生效原因分别保留，诊断按相应时点的请求和来源生成。

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

# V0.3.1 — V0.13.18 代码整理补充门禁

本节只补充 V0.3.0 未明确覆盖的整理风险；与既有 Owner、参数单语义、单写点和双阶段 `code_sc` 规则叠加执行。

## 1. 写入前最小改动门禁

在任何写入前，先用本次改动范围写一张最小表，不能只凭口头判断：

| Owner | Caller | Callee | Timing | Data | Side effect |
|---|---|---|---|---|---|
| 谁拥有状态/决策 | 谁实际调用 | 允许调用谁 | ISR/任务/主循环/事件 | 输入、单位、输出 | 状态修改、硬件、协议影响 |

同时列出**不改清单**：本次明确不改变的阈值、保护判据、状态迁移、调用时序、硬件写点、协议字段和物理启动行为。表和不改清单未完成，禁止开始结构性写入。

## 2. 单一实现、单一真源、单点清洗

- 一项功能只能保留一套真实实现；不要把同一规则复制到多个 task、helper 或模块。
- 一个参数/事实只能有一个真源；上层只提交候选值或请求，不能复制一份“当前状态”再自行修正。
- 同一采样快照的即时派生由事实生产者发布，消费者读取值和必要的身份、时刻、有效性。按算法接收样本、推进平均窗的历史留在该算法。输入、单位、时点、有效性、计算规则一致的纯计算才可共用，限幅结果单独保存。
- 策略归有权决定约束的一层，协调层传已决定的预算和必要来源，算法按合同求值，执行器再核验当前安全条件。模式入口各自推进专属状态与编排，共用函数只接收真正通用的计算输入或已经选定的通用策略参数。两个只转发给公共模式分支的入口，不能证明专属状态和流程已经分开。
- 上层只提候选，底层在唯一 Owner 的单点完成必要的范围清洗/钳位；**安全时间门、等待时间和重新发波条件必须留在安全/时序 Owner，不能揉进清洗函数**。
- 没有明确语义、事务边界、测试 seam 或唯一硬件出口时，禁止新增 wrapper、转发接口或一行代理函数；禁止复制状态字段来“同步”两个 Owner。

## 3. 删除前检索与生产 API 收口

删除函数、字段、枚举、宏或生产 API 前，必须执行全树检索，并保留结果作为证据：

```text
rg --no-ignore -n "<symbol>" .
```

检索范围必须覆盖源码、`tests`/测试夹具、Keil 工程、CMake 工程、project/membership 文件和 `docs`；不能只搜当前 `.c/.h` 或只搜构建成功的目录。生产 API 删除时，同步删除或更新 mock、stub、fake、fixture 和测试调用；**不得为了让旧测试通过而恢复旧兼容层**。

## 4. 物理行为与重构后复核

未经用户确认，不得改变既有物理行为，包括但不限于低 Duty 抬升、预充起步、继电器时序、停波/重新发波条件和保护阈值。若整理过程中无法证明行为等价，保留原行为并标记未验证边界，不得顺手“优化”。

按本次重构触及的范围完成并记录适用项。缺失的必要验证写明原因，保留相应验收缺口：

- preprocessor 结果/宏分支；
- API、caller/callee 与参数真源；
- IRQ/vector/handler/service 链；
- project membership（Keil/CMake/源文件归属）；
- Host 测试与夹具；
- Keil 构建/工程检查；
- 最终 diff review（含不改清单和物理行为对照）。

## 5. 文件、文档与未验证边界

完成整理时按实际范围确认固件版本及对应文档；不要顺带修改本技能版本。技能维护与固件维护分别验收，纯注释/文档不升固件版本。仍未执行的 Host、Keil、上板、示波器及边界检查明确写“未验证”，不得用“能编译”或“看门狗未复位”替代证据。

## V0.3.1 简明检查表

```text
[ ] 已列 Owner / Caller / Callee / Timing / Data / Side effect
[ ] 已列不改清单，并确认没有未经确认的物理行为变化
[ ] 一项功能一套实现；参数/事实只有一个真源
[ ] 上层只提候选；底层单点清洗；安全时间门独立
[ ] 未新增无必要 wrapper/转发接口/复制状态字段
[ ] 删除前已 rg --no-ignore 覆盖源码、tests、Keil/CMake/project/docs
[ ] 生产 API 删除已同步测试夹具，没有恢复旧兼容层
[ ] 已完成 preprocessor/API/IRQ/project membership/Host/Keil/diff review
[ ] 已按实际行为变更及项目约定处理固件版本/文档；未验证边界已标明
```

## 失败回滚原则

本批对照失败时保留首次差异和冻结基线，先修正当前批，再进入下一批。需要撤销时只处理本次的工作区修改，保留用户已有的修改和暂存内容。版本、期望轨迹和测试夹具不能用来掩盖失败。

# 十九、code_wrt 固定工作流

## Phase A — pre-write code_sc + layer contract

修改前确认本次改动涉及的合同。对小范围修正记录必要证据，结构性变更按实际范围完成下列检查：

1. 读取目标模块和必要调用链。参考其他工程时，按功能找相关实现、全部调用入口和执行路径后再比较；

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

按当前 `code_zl` 对照本批实际差异，为新增或改动的公开入口、复杂私有函数及有状态或安全副作用的函数补真实合同头，逐项核对受影响的逻辑行。用户指定逐行时按指定粒度完成。采用项目现行样式和大括号规则。仅需注释时保持代码行为，函数头和行内说明分别解释接口合同与关键条件的用途。

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

- 职责、入口和调用变化时核对受影响的当前架构、接口及阅读入口。同步范围服从用户的明确边界。固件行为与结构改动按项目和当次版本规则收口，纯注释/文档无需自行升固件版本。技能版本单独维护。

# 二十一、验证

等价整理时先冻结当前指定源码、配置、输入和参考输出。保持采样、计算与控制的触发时机和频率，核对实际积分间隔、窗口推进及暂停/停止/复位各自保留和清除的状态。接口或策略迁移与纯算术、命名整理分批，按受影响路径比较限制来源、状态、时序及候选到提交的结果。涉及复位时核对全部相关入口、复位前执行器状态、复位默认态和重启准入，区分可受控的软件路径与不能执行软件清理的硬件复位。

声称减少 Flash 时，以相同目标、工具链、优化级别、宏和链接设置比较前后镜像或 MAP，逐项说明可归因的净收益和未测项。算术优化先证明等价。浮点改定点、改公式或重新编码参数表按独立范围处理，Flash 目标以实际约定为准。

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

- 暂存、取消暂存、停止跟踪、提交、改提交说明、切换或创建分支、合并、变基、推送及等效操作，须有用户当次对仓库、操作和范围的明确授权。仅授权代码实施或继续任务时，Git 检查保持只读。

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
