---
name: code_wrt
description: "Use when the user invokes /code_wrt or asks to write, simplify, refactor, organize, or standardize embedded C code while preserving architecture and hardware-safety boundaries. Triggers include code_wrt, 写代码, 代码简化整理, 简化并注释, 重构并整理."
---

# Code WRT

**Version: V0.2.0**

`code_wrt` 不再只是“ponytail 简化 + code_zl 注释”。V0.2.0 增加 **架构写入门禁**，固定执行：

```text
code_sc(pre-write design gate)
        -> ponytail / implementation
        -> code_zl
        -> code_sc(post-write architecture gate)
```

目标：避免写出“单个函数能跑、整个 Application 边界却越来越乱”的代码。

## 版本记录

- **V0.2.0**：新增强制 `code_sc` 前后双门禁；引入唯一 Owner、单向依赖、窄 DTO、公共/私有接口、单硬件写点、参数单语义、candidate/approved/committed 命名、Application 内部分层、peer-to-peer mutation 禁令。修正旧规则中“保护一律用文件级快照、不要 input DTO”的过强约束：跨模块边界允许且鼓励窄 DTO，禁止的是 giant context/fat interface。
- **V0.1.5**：第二阶段对齐 code_zl V0.1.8（白话注释、先定义再使用、`// todo:`）。
- **V0.1.4**：固件 `SOFT_VERSION` 与 `docs/版本更改/` 门禁。
- **V0.1.3**：任务入口归功能 `.c`；`main()` 只排任务；软件保护不进 SysTick。
- **V0.1.2**：一职一函数、调度只排列调用、硬件单写出口。
- **V0.1.1**：保护与节拍按微逆风格整理。
- **V0.1.0**：首次版本化。

## 必需子技能

**REQUIRED SUB-SKILL:** 修改前完整加载并应用 `code_sc`，执行“pre-write design gate”。

**REQUIRED SUB-SKILL:** 完整加载并应用 `ponytail`，默认 `full` 强度。

**REQUIRED SUB-SKILL:** 完整加载并应用 `code_zl`（当前 V0.1.8）。

**REQUIRED SUB-SKILL:** 修改后再次应用 `code_sc`，执行“post-write architecture gate”。

任一必需 skill 不可用时停止结构性修改，不得凭记忆模拟。

## 一、写代码前：先定 Owner，后写函数

每次新增/重构跨模块逻辑，先在 scratch/计划中写 Owner 表。至少回答：

| 问题 | 必须回答 |
|---|---|
| 谁拥有这个状态？ | 唯一 `.c` / module |
| 谁决定策略？ | policy/application/algorithm |
| 谁最终仲裁？ | application/safety |
| 谁写硬件？ | executor/driver 唯一出口 |
| 谁只读诊断？ | debug/telemetry |

### 强制原则：一个事实只有一个 Owner

禁止：

```c
/* 错：算法 controller 拥有充电阶段状态机 */
typedef struct
{
    mppt_ctx_t algorithm;
    charge_stage_ctx_t charge_stage;
} mppt_controller_t;
```

除非模块本身就是更高层 Application Coordinator，而且名字/接口明确表达这一点。`mppt`、`algorithm`、`driver` 之类子域模块禁止偷偷长成 God Controller。

如果两个模块都在解释同一事件，例如：

```text
charge: relay lost 100ms 才判会话失效
mppt: 一帧 relay=false 就 reset tracking
```

必须先修 Owner/会话语义，不能继续堆 if。

## 二、Application / Driver 分离不等于架构完成

`app/` 与 `driver/` 物理目录分离只是第一层。复杂控制固件的 Application 内部至少按责任区分：

```text
Scheduler / Application Service
        |
        +--> Domain Policy       (charge stage / battery)
        +--> Algorithm           (MPPT)
        +--> Safety Policy       (protection)
        +--> Measurement Adapter (sample)
        +--> Output Executor     (PWM / Relay)
        +--> Observability       (debug / telemetry, read-only)
```

依赖应尽量单向：

```text
sample -> safety/policy -> application arbitration -> output -> driver
                         -> algorithm -> candidate result -> application validation
```

禁止出现：

- Algorithm -> Charge Stage / Protection / Driver
- Debug/Telemetry -> 反向控制 Charge/Protection
- `charge <-> protection <-> output` 互相修改内部状态
- 一个 peer module 调另一个 peer 的 task 入口
- 为了拿一个 enum/宏，被迫 include 不属于自己的业务 header

## 三、跨模块接口：只传必要 DTO，不传整个世界

### 3.1 禁止 giant context / fat interface

默认禁止把这些整对象直接交给算法/子模块：

```c
app_sample_t *
app_charge_stage_ctx_t *
app_battery_profile_t *
app_protection_t *
app_charge_ctx_t *
```

如果调用方只需几个工程量，创建窄 DTO/标量合同：

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
} mppt_input_t;
```

DTO 规则：

- 字段必须是下游真正需要的语义；
- 单位写进名字：`_mv/_ma/_mw/_ms/_permille`；
- 上游先完成 validity/stale/safety qualification；
- 不把 fault/session/stage/profile 等无关上层概念塞进去；
- 不为了“以后可能用”预埋十几个字段。

### 3.2 修正旧规则：DTO 与文件 static 如何选

旧版曾写“不要 `prot_step_in_t`，用文件级采样快照”。V0.2.0 改为：

- **跨模块边界**：优先窄 DTO/显式参数，让依赖可见、可测试；
- **模块内部 helper**：在单线程、Owner 清晰、生命周期明确时，可读模块私有 static snapshot；
- 禁止 helper 表面无参数，实际依赖大量跨域 `s_sample/s_relay/s_charge/s_duty`；
- 禁止 giant DTO 只是把整个 Application context 换了个名字。

## 四、公共头只暴露合同，内部实现必须私有

公共 `app/inc/*.h` 只允许暴露：

- 稳定业务 DTO
- 稳定 enum（属于该模块）
- public API
- debug snapshot（明确 read-only）

禁止公共头暴露：

- PI integral
- search internals
- private state machine ctx
- 只被本模块 `.c` 使用的 helper
- `clear_power_integral`、`reset_tracking` 这类实现细节命令

算法内部头优先放 `app/src/*_priv.h` 或私有目录，并通过 grep/CI 确保只有算法实现 include。

## 五、类型放在真正 Owner 所在模块

不要因为“这里刚好也会用”就把 enum/struct 放错 header。

错误例：完整 Charge Session enum（WAIT/PRECHARGE/RUN/FAULT）定义在 `charge_stage.h`，导致 MPPT 为了判断 `RUN` include Stage。

正确：

- Session 类型 -> `charge.h` / charge contract
- TC/CC/CV/FC -> charge policy
- MPPT mode/search internals -> mppt
- fault bits/disposition -> protection
- hardware command/snapshot -> output/driver contract

## 六、参数一个值只表达一个语义

禁止 Semantic Overloading：

```text
power_allow_mw == 0
有时 = HARD STOP
有时 = SOFT ZERO
```

应拆成明确控制语义：

```text
mode = TRACK / HOLD / SOFT_ZERO
hard stop -> 根本不调用算法或显式 session invalid
```

同样禁止：

- `relay_applied` 实际只是 GPIO ODR 镜像却被当触点反馈；
- `pwm_active` 同时表示 request、MOE、实际 compare 生效；
- 一个 `reset` 同时清 session、PI、search、duty。

## 七、命名必须表达控制流水线

Duty/PWM 控制至少区分：

```text
candidate_duty   # 算法候选
approved_duty    # Application/Safety 批准
committed_duty   # 已提交 executor/driver
hardware_duty    # 寄存器/生效值
```

Relay 至少区分：

```text
relay_request_on
relay_odr_on
relay_contact_closed  # 只有真实触点反馈才能这样叫
```

init/reset/start/stop 不允许出现 3~4 套近义 API 让调用者猜层级。

## 八、谁决定、谁执行、谁验证

推荐控制链：

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

算法只能产候选，不得：

- 直接 `DRV_PWM_*`
- 直接 Relay GPIO
- 清 protection fault
- 绕过 Duty/Power cap
- 决定 STOP 是否结束会话

Application/Safety 必须对外部算法结果再验证，不能因为“算法工程师会遵守”就省掉 envelope。

## 九、硬件单写出口

PWM、Relay、Flash commit、关键 EN 脚必须有唯一写点。

例如：

```text
charge/mppt/protection -> command only
output.c               -> app_relay_set / pwm_apply
bsp/driver              -> register write
```

禁止多个 `.c` 都写同一寄存器/GPIO。

如果 ISR Break 能异步关 PWM，主循环恢复前必须有明确 epoch/session gate，防止同拍重新发波。

## 十、函数真实依赖必须出现在签名或模块合同里

如果 `app_output_step(in, hw_snapshot)` 已传快照，函数内部又：

```c
DRV_PWM_IsOutputEnabled();
app_protection_latest();
```

必须说明这是：

- 无意隐藏依赖（应删除），还是
- 有意的最终硬件安全复核（应移动到 executor/safety-commit 层）。

禁止注释写“本函数不访问硬件”而实现直接读 driver。

## 十一、避免 peer-to-peer mutation

同层模块默认只返回结果/事件，不直接修改另一个 peer 的内部状态。

危险关系：

```text
charge -> protection_latch()
protection -> charge_lock_startup()
output -> protection_latch() + charge_lock_startup()
```

遇到这类结构先让 Application Coordinator 统一仲裁，或者通过事件/command 归并；不要继续增加交叉 setter。

## 十二、Multiple Sources of Truth

同一个业务约束只能有一个 Policy Owner，例如：

```text
300W limit
PV * 8A
BAT * 6A
battery target
charge stage power allowance
```

允许 defence-in-depth，但第二层只能验证/钳位，不要复制一套完整业务公式。

## 十三、Config 按 Owner 拆，不做参数垃圾桶

触碰大 `app_config.h` 时审查配置归属：

```text
Product/Safety
Charge Policy
Algorithm Tuning
Driver/HW
Debug/Telemetry
```

如果算法工程师为了调 Kp/Ki 必须阅读 Relay/Protection/Battery 所有宏，应拆 `mppt_config.h` 等专属配置。

`STAGE_ETA` 一类 Charge 估算参数不能因为 MPPT 也用到功率就被丢进算法配置。

## 十四、Dead Contract / Zombie Interface 不允许新增

写完必须搜索：

- enum/action 是否有 producer；
- flag 是否永远常量；
- request/restart/park 是否已经没人设置；
- 注释说支持某路径，代码是否实际 reject；
- result/diag 是否重复镜像同一事实。

新增 API 必须有真实 caller；删功能时同步删消费分支和注释。

## 十五、故障检测与节拍调度

保留既有微逆风格约束：

- `Fault_Detection()` 只调度；一故障类一个 `Fault_Xxx()`；检测与已有软件恢复同函数；
- 不发明不存在的恢复；保护判据保持原阈值；
- SysTick 只 `drv_time_tick_isr()` / 置标志，不跑软件保护、printf、LED、协议解析；
- `main()` 是任务目录；保护 -> 充电 -> 输出 -> 恢复顺序显式；
- UART ISR 搬字节，ADC/DMA ISR 产数/置 pending，业务转换在主循环；
- 一个业务不要 ISR 和 main 各跑一套判据。

但必须服从 V0.2.0 Owner 门禁：`Fault_*` 不得直接关 PWM；PWM 最终写由 output/driver 单出口。

## 十六、任务归属与函数书写

`app_task_*` 声明在功能 `.h`，实现和同域 helper 在功能 `.c`。`main()` 只调用任务入口。

典型：

| 功能 | 任务入口 | Owner 文件 |
|---|---|---|
| 采样 | `app_task_sample` | `sample.c` |
| 保护/恢复 | `app_task_protect/recover` | `protection.c` |
| 充电 | `app_task_charge` | `charge.c` |
| 输出 | `app_task_output` | `output.c` |
| UART/遥测 | `app_task_uart/telemetry` | `debug.c` |

一职一函数。写函数前明确：

```text
Purpose / Caller / Timing / Inputs / Outputs / State Mutation / HW Side Effects
```

调度函数只排列调用，不塞业务判据。

## 十七、code_wrt 固定工作流

### Phase A — pre-write code_sc

1. 读取目标模块及直接调用链；
2. 给关键状态做 Owner 表；
3. 检查 include/call graph 是否已有环；
4. 确定本次 API/DTO；
5. 确定硬件写点和 safety envelope；
6. 若设计会制造新 Ownership Inversion / Fat Interface / peer mutation，**停止写代码，先修设计**。

### Phase B — ponytail / implementation

- 删除/内联冗余；
- 复用现有能力；
- 结构性修改必须遵守前述 Owner/DTO/单写点规则；
- 不确定行为等价时保留原逻辑并明确 TODO/风险。

### Phase C — code_zl

按 code_zl V0.1.8 做函数头、白话注释、分节、格式、先定义再使用和 `// todo:`。

### Phase D — post-write code_sc

重新审查 diff，至少验证：

- 没有新 dependency cycle/SCC；
- 没有新增 cross-domain context pointer；
- 没有新增硬件第二写点；
- 公共头没有泄漏 private ctx；
- 参数没有一值多义；
- Owner 表仍唯一；
- debug/telemetry 没有反向进入控制；
- 算法结果仍经过 Application/Safety 验证；
- ISR/main ownership 没被破坏；
- 没有 dead enum/flag/API。

## 十八、配置与注释门禁

- `.c` 分节：`/* 标题 */`，禁止 `====` 装饰；
- `.h` 分节：`//=================== 标题 ===========================`；
- Init/SysClk：按“配置了什么”分节，不逐行解释寄存器；
- `config.h` 有效宏写用途、单位/枚举、当前值；
- 注释不能掩盖坏架构：发现 Owner 错误时先整改，不准只是给错误结构加漂亮注释。

## 十九、固件版本与版本更改文档

适用 mppt-charger-300w 及同约定仓：只要本轮改了会进镜像的行为/宏/结构：

1. 读取 `SOFT_VERSION=Vx.y.z`，同阶段只 `z + 1`；
2. 在现有 `docs/版本更改/Vx.y.0....md` 文末追加一节；
3. 同步 `docs/README.md` 当前固件；
4. 未上板写 `⚠️ 未上板`，禁止伪造 BOARD_PASS。

一节至少包含：目的/根因、具体文件/函数/宏差分、明确不做、验证。

只有用户明确说“先别升版本/只改注释不记版本”才能跳过，并在回复说明。

## 二十、验证

结构性改动至少做：

- build/compile；
- 相关 host tests；
- grep include boundary；
- 搜索硬件写点；
- 对关键控制链给出调用图；
- 对 ISR/main/shared state 做并发检查；
- 对算法/策略接口做 fake/stub 越界测试（适用时）。

例如可替换算法至少测试：

```text
fake return normal duty -> Application 正常运行
fake return over-limit duty -> Application 必须阻断
```

## 边界

- 用户只要纯注释 -> `/code_zl`。
- 用户只要只读深度审查 -> `/code_sc`。
- `/code_wrt` 可以结构整改，但不能擅自改保护阈值、协议、硬件时序或产品策略。
- 不确定业务语义时先报告并保留行为。
- 默认不扩大用户指定文件范围；为了确认调用/Owner 可以只读必要调用链。
- 不自动 commit/push，除非用户明确要求。

## 报告

完成后必须报告：

- **Pre-write Code_SC**：Owner/依赖/API 设计结论；
- **Implementation/Ponytail**：改了什么、保留什么；
- **Code_ZL**：注释/分节/格式；
- **Post-write Code_SC**：是否新增环依赖、Fat Interface、Owner 冲突、隐藏依赖、多写点、死接口；
- **Verification**：build/tests/grep/并发与安全检查；
- **Version**：新 `SOFT_VERSION` 和追加文档；若跳过则写明原因。
