---
name: code_sc
description: "Use when the user invokes /code_sc or asks for a deep embedded-C code review focused on architecture, ownership, layering, call relationships, API/parameter placement, state machines, concurrency, PWM/relay/protection safety, or maintainability defects. Triggers include code_sc, 代码审查, 架构审查, 调用关系审查, 模块边界审查, ownership review."
---

# Code SC

**Version: V0.1.0**

`code_sc` 是嵌入式 C 的“结构 + 行为”代码审查 skill。它不是只找空指针、越界和语法问题，而是专门发现“代码能跑，但模块边界已经写歪”的问题：Owner 不唯一、Controller 管了不该管的状态、Application 内部环依赖、整个上下文对象乱传、算法层知道硬件/充电阶段、同一状态被多个模块解释、硬件多写点、隐藏全局依赖、参数语义重载、死接口、ISR/主循环竞争等。

默认 **只审查、不改代码**。用户明确要求“修复/整改/提交”时，先输出审查结论和整改边界，再改。

## 核心原则

审查时先问 5 个问题：

1. **谁拥有这个状态？** 同一个状态/策略只能有一个 Owner。
2. **谁决定？谁执行？** Policy/Algorithm 产生候选，Application/Safety 仲裁，Executor/Driver 执行；不能互相越权。
3. **依赖方向是否单向？** 高层可以依赖低层接口；同层模块不得互相修改内部状态形成环。
4. **接口是否只暴露必要语义？** 跨模块优先窄 DTO/标量；禁止把整个 `sample/profile/protection/controller` 上下文扔给下游让它自己挑字段。
5. **函数签名是否说出真实依赖？** 函数不能表面吃 DTO，内部又偷偷读硬件、全局单例、另一个模块状态。

## 严重度

| 级别 | 含义 | 典型问题 |
|---|---|---|
| **P0** | 可能直接导致失控/损坏/安全故障 | PWM 多写点、Break 后重新发波、ISR/主循环竞态导致错误使能 |
| **P1** | 架构或行为高风险，已可能造成实际错误 | Owner 倒置、分布式状态机、保护/Relay 两套判定、算法绕过安全包络 |
| **P2** | 明显技术债，持续增加维护和移植风险 | 环依赖、隐藏依赖、类型放错模块、参数重载、公共头泄漏内部结构 |
| **P3** | 可读性/一致性问题 | 命名不一致、重复镜像、注释与实现漂移 |

**不要因为“当前测试能过”把 P1 架构缺陷降成 P3。** 架构缺陷的风险常在下一次改需求、换 MCU、换算法时触发。

## 审查流程

### Phase 0 — 事实基线

先读取：

- 项目规范：`AGENTS.md` / `CLAUDE.md` / README / 架构文档
- 构建入口：Keil `.uvprojx`、CMake、Makefile
- 用户指定目标文件
- 目标文件的直接调用者、被调用者、公共头文件
- 关键硬件路径：PWM/Relay/ADC/COMP/Break/Flash/UART/Watchdog

有 CodeGraph / code-review-graph / clangd 时可辅助生成调用图，但最终结论必须回到源码证据。

### Phase 1 — 画 Owner 表

对所有关键事实和状态列唯一 Owner：

| 对象 | 应有 Owner | 其他模块允许做什么 |
|---|---|---|
| Charge session：OFF/WAIT/PRECHARGE/RUN/FAULT | `charge` | 只读状态/提交事件 |
| TC/CC/CV/FC | `charge_stage` / `charge_policy` | 只接收其输出约束 |
| MPPT search/PI/Vref/算法状态 | `mppt` | 只通过公共算法接口调用 |
| Fault active/latched/recovery | `protection` | 读 safety decision，不直接改内部位图 |
| PWM/Relay 实际写硬件 | `output`/driver 唯一出口 | 其他模块只提交命令 |
| ADC measurement snapshot | `sample` | 其他模块读批准后的快照/DTO |
| Telemetry/debug | `debug` | 只读 snapshot，不反向控制策略 |

如果发现两个模块都在决定同一个状态，直接标记 **Distributed State Machine / Multiple Owners**。

### Phase 2 — 依赖图与环

至少检查：

- `.c/.h` include 方向
- A 调 B，同时 B 又调 A
- A 通过 getter 读 B，B 又主动修改 A
- Debug/Telemetry 反向被业务模块 include
- Algorithm include Charge/Protection/Driver
- Output/Protection/Charge 同层相互调用

重点找强连通分量（SCC）。目录分成 `app/driver` 不代表真正分层；如果 `charge ↔ protection ↔ output` 形成环，仍然是不合格。

### Phase 3 — Ownership / Boundary 缺陷

必须逐项检查以下反模式。

#### 3.1 Ownership Inversion — 所有权倒置

红旗：

```c
struct mppt_controller {
    mppt_ctx_t algorithm;
    charge_stage_ctx_t charge_stage; // 错：算法控制器拥有充电策略状态
};
```

如果模块名叫 MPPT/Algorithm，却拥有 Battery Profile、Charge Stage、Relay session、Fault session，这通常已经变成 God Controller。

#### 3.2 Bidirectional Semantic Coupling — 双向语义耦合

例如：

- `charge_stage` 命令“清 MPPT integral”
- MPPT 的 `search.state` 又决定 `charge_stage` 是否允许 CV→CC

这意味着两个模块都知道对方实现细节。应改为业务事件/约束，由各自 Owner 解释。

#### 3.3 Fat Interface / Overexposed Context

红旗：

```c
foo(const app_sample_t *sample,
    const app_battery_profile_t *profile,
    const app_protection_t *prot,
    const app_charge_ctx_t *charge);
```

审查它实际读取几个字段。若只需 `pv_mv/pv_i_ma/bat_mv/power_limit`，要求改成窄 DTO/标量。**跨模块 DTO 表示批准后的合同，不是把所有状态复制一遍。**

#### 3.4 Type Ownership Error — 类型放错位置

例如完整 Charge Session enum 却定义在 `charge_stage.h`，导致别的模块为了 `RUN` 被迫 include Stage。类型应该放在真正 Owner 的公共合同。

#### 3.5 Implementation Detail Leakage

红旗字段/接口：

- `clear_power_integral`
- `reset_tracking`
- `search_state` 被业务层直接判断
- Application 直接访问算法 ctx 内部积分器

高层只表达业务语义，例如 `control_session_invalidated`、`mode=HOLD`；算法内部是否 PI/P&O/IncCond 不能泄漏。

### Phase 4 — API、参数和命名

逐函数检查：

1. 参数是否都是函数真正需要的？
2. 参数名是否表达单位和语义（`*_mv`, `*_ma`, `*_mw`, `*_permille`, `*_ms`）？
3. 一个值是否被赋予两种语义？例如 `power_allow=0` 有时表示硬停、有时表示 soft-zero。
4. `candidate/approved/committed/hardware` 是否被混叫成 `duty`？
5. `relay_applied` 是否其实只是 GPIO ODR 镜像，却被命名成触点反馈？
6. init/reset/start/stop 是否存在多套近义 API，调用者不知道层级？
7. 公共头是否暴露私有 ctx、PI integral、search internals？
8. DTO 是否包含不相关 stage/fault/relay/profile 等上层概念？

推荐命名流水线：

```text
candidate_duty -> approved_duty -> committed_duty -> hardware_duty
relay_request_on -> relay_odr_on -> relay_contact_closed(有真实反馈时才可用)
```

### Phase 5 — 函数真实副作用与隐藏依赖

函数签名和注释必须与实现一致。重点抓：

- 注释写“本函数不访问硬件”，内部却 `DRV_*()`
- 已传 `hw_snapshot`，内部又重新读硬件，形成 mixed snapshot
- 已传 protection decision，内部又 `app_protection_latest()`
- helper 无参数，却依赖一堆文件 static `s_sample/s_run_mode/s_duty`
- getter 名义只读，实际触发状态更新

对每个核心函数记录：

```text
Inputs / Hidden Inputs / Outputs / State Mutation / HW Side Effects / Caller / Timing
```

隐藏输入若会影响控制结果，通常至少 P2；涉及 PWM/保护时提高到 P1。

### Phase 6 — 状态机、时序与会话边界

检查是否存在多个模块对同一事件给出不同生命周期解释。

典型例子：

- Charge FSM 对 Relay Lost 做 100ms debounce
- MPPT wrapper 一帧 `relay=false` 就 `reset_tracking()`

这属于实际行为冲突，不只是“代码风格”。

必须区分：

```text
本拍必须 Duty=0 / 停能
vs
整个 control session 已失效，需要 reset algorithm state
```

ADC 单帧坏、临时 UV、temporary hold 不应自动等价于“清整个算法会话”，除非产品定义明确如此。

### Phase 7 — 嵌入式并发与硬件安全

必须检查：

- ISR 是否只做必要搬运/快故障；业务解析是否跑进 ISR
- `volatile` 是否被错误当作原子性/互斥
- ISR 与 main 对多字节/结构体/位图是否有撕裂风险
- DMA buffer 双缓冲 ownership
- ADC sample sequence / captured time / freshness
- PWM shadow/preload 与“当前 Duty”到底指 candidate 还是已生效值
- COMP/Break 后 Application 是否可能重新 enable PWM
- fault epoch 在算法计算前后是否复核
- Relay/PWM 是否存在多个写硬件出口
- 故障检测、恢复、STOP 是否可能在同拍互相覆盖
- Watchdog 是否掩盖死循环或长临界区

### Phase 8 — Multiple Sources of Truth

搜索同一个约束是否被多处重算：

```text
300W limit
PV × 8A
BAT × 6A
Duty max
Battery OV threshold
Relay state
```

Defence-in-depth 可以存在，但必须区分：

- **Policy owner**：计算业务限制
- **Safety validator**：只验证结果未越界

不要三层各自复制一套业务公式。

### Phase 9 — Dead Contract / Zombie Interface / Semantic Drift

检查：

- enum 定义但永远不会产生
- flag 永远 false，但调用链还判断
- `request_restart/request_park` 等迁移残留
- 注释/文档说 ZERO_HOLD，代码却永远 reject
- getter、result snapshot 有多份镜像却只更新部分
- 旧 API 声明留在 header 但已经不应由外部调用

这些问题会让新工程师追一圈空路径，必须报告。

### Phase 10 — Config Ownership

不允许一个 `app_config.h` 成为所有层的参数垃圾桶。

审查每个配置项属于：

- Product/Safety
- Charge policy
- Algorithm tuning
- Driver/HW
- Debug/Telemetry

如果算法工程师为了调 Kp/Ki 必须打开充电/Relay/Protection 全部宏，说明配置边界失败。建议按 Owner 拆文件，例如 `app_config.h` + `mppt_config.h`。

## Application 内部分层基准

`app/` 和 `driver/` 分开只是第一层。对复杂控制固件，还应至少区分逻辑责任：

```text
Scheduler / Application Service
        |
        +--> Domain Policy (charge stage / battery)
        +--> Algorithm (MPPT)
        +--> Safety Policy (protection)
        +--> Measurement Adapter (sample)
        +--> Output Executor (PWM/Relay)
        +--> Observability (debug/telemetry, read-only)
```

禁止的依赖方向：

```text
Algorithm -> Charge Stage / Protection / Driver
Debug -> 反向控制 Charge/Protection
Output policy -> 偷偷重跑 Charge/Protection 业务判据
Peer module <-> peer module 双向修改状态
```

## 审查输出格式

先给结论，再给证据。不得只说“建议重构”。

### 1. 总结

```text
当前最大风险：Owner 不唯一 / 依赖成环 / 算法边界泄漏 / PWM安全...
```

### 2. 问题表

| ID | 严重度 | 类型 | 文件/函数 | 证据 | 风险 | 建议 Owner/修复方向 |
|---|---|---|---|---|---|---|

类型统一使用：

- Architecture Defect
- Ownership Inversion
- Boundary Violation
- Distributed State Machine
- Bidirectional Semantic Coupling
- Dependency Cycle
- Fat Interface
- Type Ownership Error
- Hidden Dependency
- Mixed Snapshot
- Multiple Sources of Truth
- Peer-to-Peer Mutation
- Temporal Coupling
- Semantic Overloading
- Dead Contract / Zombie Interface
- Concurrency / ISR Race
- Hardware Single-Writer Violation

### 3. Owner 表

列出“当前 Owner / 应有 Owner / 冲突模块”。

### 4. 依赖/调用图

至少给关键链：

```text
sample -> protection -> charge -> algorithm -> application validation -> output -> driver
```

指出环和逆向边。

### 5. 整改顺序

按 **P0/P1 先行为安全，再边界，再命名/清理**。大型工程禁止一次推倒重写；优先切清边界并保持行为，再做下一刀。

### 6. 验证缺口

区分：

- 静态源码已证实
- Host test 已验证
- Keil build 已验证
- 台架/示波器未验证

禁止把“代码看起来正确”写成 BOARD_PASS。

## 审查红旗清单

看到以下任一情况必须停下来深挖，而不是继续表面整理：

- `xxx_controller_t` 内嵌另一个上层业务状态机 ctx
- 算法模块 include `charge_stage.h` / `protection.h` / `drv_pwm.h`
- 跨模块接口直接收整个 `app_sample_t *`，实际只用 3~5 个字段
- `charge_stage` 输出 `clear_xxx_integral`
- Protection disposition 出现算法内部术语 `reset_tracking`
- 同一硬件被多个 `.c` 写
- 同一个 fault/session 在两个模块分别 debounce/reset
- `step()` 已传 snapshot，内部又读硬件/全局 latest
- 业务模块 include `debug.h` 只为 telemetry bit
- 公共 header 暴露私有算法 ctx
- 同一参数 `0` 同时表示 hard-stop 和 soft-zero
- enum/action 在消费者里有分支，但生产者永远不产生
- 文件夹看起来分层，但 include/call graph 存在 SCC

## 边界

- 默认只读审查；没有用户明确授权，不改代码、不提交。
- 不为了“架构漂亮”改变保护阈值、硬件时序、协议或产品行为。
- 无法确认业务语义时标记“需要产品确认”，不得自行发明。
- 发现 P0/P1 时优先报告，不能被注释/格式问题淹没。

## 报告结尾

必须回答：

1. 这是功能 bug、并发 bug，还是架构/设计 bug？
2. 哪个状态/决策的 Owner 错了？
3. 现在是否存在两个模块同时解释同一事实？
4. 换 MCU / 换算法 / 加新充电阶段时，哪里最容易再次出错？
5. 最小安全整改切口是什么？
