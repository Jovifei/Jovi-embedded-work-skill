---
name: code_sc
description: "Use when the user invokes /code_sc or asks for a deep embedded-C code review focused on architecture, ownership, layering, call relationships, API/parameter placement, state machines, concurrency, PWM/relay/protection safety, safety-edge timing, ISR/main TOCTOU, snapshot consistency, actuator single-writer ownership, or maintainability defects. Triggers include code_sc, 代码审查, 架构审查, 调用关系审查, 模块边界审查, ownership review, PWM安全审查, 中断竞争审查."
---

# Code SC

**Version: V0.3.0**

`code_sc` 是嵌入式 C 的“结构 + 行为 + 安全时序”代码审查 skill。它不只找空指针、越界和语法问题，而是专门发现“代码能跑、测试能过，但 Owner / 状态机 / 安全提交时序已经写歪”的问题：Owner 不唯一、Controller 越权、Application 内部环依赖、整个上下文对象乱传、算法层知道硬件/充电阶段、同一状态被多个模块解释、硬件多写点、隐藏全局依赖、参数语义重载、死接口、ISR/主循环竞争、首拍保护空窗、TOCTOU、跨代 snapshot、重复 lifecycle reset、API 假成功、产品限制多份真值等。

默认 **只审查、不改代码**。用户明确要求“修复/整改/提交”时，先输出审查结论和整改边界，再改。

## V0.3.0 新增：集成/合并/实时性硬门禁

V0.3.0 专门补足“单个模块看起来正确，但工程一合并就裂脑”的漏洞。以下检查在全面复核时不可跳过：

1. **Exact-baseline gate**：报告必须写 repo/ref/SHA/工作树状态；本地未 push、远端旧 SHA、旧 ZIP 不得混为“当前代码”。
2. **Merge-is-new-code gate**：merge/rebase/conflict resolution 后重新审 API、头文件、ISR、项目文件、CI；父分支各自 PASS 不继承到 merge commit。
3. **Public-contract resurrection gate**：搜索被删 public header、旧 typedef/API/fault bit 是否被 merge 恢复；检查新旧消费者是否同时进入 Keil/CMake target。
4. **Critical-preprocessor gate**：安全开关不得靠传递 include；核对预处理后的实际值。未定义安全宏在 `#if` 中按 0 静默关闭，按 P1 处理。
5. **IRQ completeness gate**：每个 `NVIC_EnableIRQ` 必须追到 startup vector、强 `Xxx_IRQHandler`、driver handler、foreground consumer；落到 weak Default_Handler 视为运行卡死 P1。
6. **Re-arm stale-command gate**：检查临时停波/样本 stale/HOLD 后 `0 -> 旧大 Duty`。物理 OFF→ON 必须有 executor-owned first-duty cap/rebuild/ramp。
7. **Veto reachability gate**：`power_inhibited/maintenance_busy/settings_pending/storage_blocked` 等禁止动作必须在 start/autostart/restart/PWM commit/Relay close 等危险入口有消费者。
8. **Liveness != deadline gate**：看门狗票据只证明还能跑，不能证明 1ms deadline。检查 tick 合并、WCET、float/sqrt、Flash stall、日志和最长临界区。
9. **Header economy + IWYU gate**：公共头数量要克制，但不能靠 main.h 聚合或传递 include。检查符号 Owner、直接 include、private/public 边界和无意义“一文件一 DTO”。
10. **Evidence integrity gate**：CI failure、关键 job skipped、测试路径失效、仅旧 SHA Keil PASS，都不能写成当前 PASS。

### 0.x 当前代码身份必须可复现

最终报告开头必须写 Repository、Target ref、HEAD、Compared base（如有）、Build file、CI run/status、Worktree 状态。用户说“本地已修”但只给远端 URL，而远端 SHA 没变化时，要明确说本地修改未出现在远端。

### 0.y Merge Contract Matrix

Merge 后至少审 public API/typedef、fault schema、safety veto、IRQ、build membership、tests 六类合同。每类都要找到 Producer/Owner、Consumer 和 merge 后证据。任何一条断裂，都不能用“能 merge/能看懂”判通过。

### 关键安全配置的预处理检查

对保护开关检查唯一 Owner、当前 `.c` 是否直接 include、是否依赖多级传递 include、Keil/project define 是否另行覆盖、是否有 `#if !defined(...) #error`。安全开关注释写 1 不算证据，translation unit 实际预处理值才算。

### IRQ/向量闭环审查

每个已启用中断列完整路径：peripheral IT enable -> NVIC enable -> startup vector -> strong handler -> driver handler -> pending/ring/latch -> main/task consumer。启动文件 weak handler 会让缺失实现“链接成功但第一次中断就卡死”，按 P1。

### 重新发波 Safety Edge

除了第一次上电发波，还必须检查第二次发波：ACTIVE 高 Duty -> temporary fault/stale/hold -> MOE=0,Duty=0 -> algorithm memory 保留 -> 条件恢复 -> WAIT_ZERO -> Arm -> first nonzero。若 executor 可直接恢复旧高 Duty，即使算法内存保留合理，也要判定 re-arm 斜坡缺失。修复优先归 Output/Executor 生命周期，不要重新让 MPPT 拥有 Arm 状态。

### Veto 可达性矩阵

对 `power_inhibited/storage_blocked/settings_pending/...` 至少审 Start、AutoStart、Restart、PWM commit、Relay close、Maintenance 六个入口。只有 producer 没 consumer，属于 Zombie Safety Gate。

### 实时性：看门狗不等于周期正确

检查 1ms tick 是 counter 还是 bool、CONTROL ticket 是否只证明函数返回、M0/M0+ 是否无 FPU却在控制路径使用 float/sqrtf、Flash 是否可能 stall/暂停 ADC、printf 是否阻塞、最长关中断区间、missed-tick/max-exec-time 诊断。没有 WCET/示波器/目标测量时必须写“deadline 未验证”。

### 头文件收拢的审查尺度

目标不是越少越好，而是最少且 Owner 清楚。单独 header 的合理理由是打断环、稳定 ABI、独立 Owner、多独立消费者。禁止 main.h 变万能配置桶、安全宏通过多层 include 偶然可见、public 目录残留 private/zombie algorithm header、同名宏多头重复定义、为一行 wrapper 再建一对 `.h/.c`。

## V0.2.0 新增硬门禁

V0.1.0 已覆盖 Owner、边界、依赖环、DTO、隐藏依赖、状态机、PWM/Relay/Protection 和 ISR 并发；V0.2.0 强制补上此前容易漏掉的“边沿/跨代/生命周期”审查：

1. **Safety-edge timeline**：不能只看最终 steady-state；必须检查 PWM `OFF→ARMED→ACTIVE`、Duty `0→非0`、Relay `OFF→ON`、Fault `safe→unsafe` 等关键边沿的逐步顺序。
2. **First/last-cycle protection window**：保护门、比较器 live window、Break/COMP ISR guard 必须在危险能量路径生效前建立；不能下一拍才武装。
3. **ISR/main TOCTOU**：主循环“先读硬件、后置 armed 标志”之间若 ISR 能插入，必须按竞态分析，不可因 `volatile` 就判安全。
4. **Snapshot generation coherence**：`fault_mask / disposition / epoch / pending / hw state` 必须来自同一代；发生二次 protection service/recheck 后必须整体刷新，不得只刷新一个 bool。
5. **Lifecycle single-owner**：`init/reset/start/stop/session invalidation` 同样属于状态，必须有唯一 Owner；“函数幂等，所以重复 reset 没关系”不算通过。
6. **API truthfulness**：`try_start()/enable()/commit()` 返回 success 必须与真实状态转移/硬件提交一致；只通过前置条件但什么都没做，属于逻辑 bug。
7. **Producer-consumer reachability**：每个 fault bit / enum action / recovery path 都要查生产者、消费者、清除者；只有定义和消费者、没有生产者，是 Zombie Contract。
8. **Cross-layer reverse edge**：必须扫 `driver -> app/main`、`sample -> charge/output/protection` 这类反向依赖，不能只看 app 内部。
9. **Product envelope single truth**：Application 已算 `power_limit/duty_limit` 后，下游算法不能再复制 300W/8A/6A 业务公式，除非明确是独立、命名清晰的 safety validator。
10. **Evidence gate**：能编译/能跑静态分析时必须尝试；不得仅凭“测试 PASS”宣称架构/台架 PASS。

## 核心原则

审查时先问 7 个问题：

1. **谁拥有这个状态？** 同一个状态/策略只能有一个 Owner。
2. **谁决定？谁执行？** Policy/Algorithm 产生候选，Application/Safety 仲裁，Executor/Driver 执行；不能互相越权。
3. **谁允许危险动作发生？** PWM 发波、Relay 吸合、功率上升前，哪个 safety gate 必须已经建立？
4. **依赖方向是否单向？** 高层可以依赖低层接口；同层模块不得互相修改内部状态形成环；Driver 不得反向依赖 Application。
5. **接口是否只暴露必要语义？** 跨模块优先窄 DTO/标量；禁止把整个 `sample/profile/protection/controller` 上下文扔给下游让它自己挑字段。
6. **函数签名是否说出真实依赖？** 函数不能表面吃 DTO，内部又偷偷读硬件、全局单例、另一个模块状态。
7. **本拍所有决策是否基于同一代事实？** 二次保护检查、ISR pending、硬件 commit 之后，不能混用旧 mask/旧 disposition/新 fault bool。

## 严重度

| 级别 | 含义 | 典型问题 |
|---|---|---|
| **P0** | 可能直接导致失控/损坏/安全故障 | Break/COMP 已触发但能被错误重新发波；保护窗口在危险输出后才建立；竞态可绕过硬停 |
| **P1** | 行为或架构高风险，已可能造成实际错误 | Owner 倒置、分布式状态机、跨代 safety snapshot、重复 lifecycle owner、算法绕过/重算安全包络、API 假成功 |
| **P2** | 明显技术债，持续增加维护和移植风险 | 环依赖、隐藏依赖、类型放错模块、参数重载、公共头泄漏内部结构、Zombie private contract |
| **P3** | 可读性/一致性问题 | 命名不一致、dead store、重复镜像、注释与实现漂移 |

**不要因为“当前测试能过”把 P1 架构或时序缺陷降成 P3。** 架构/边沿问题常在下一次改需求、换 MCU、换算法、真实 ISR 抢占时触发。

# 审查流程

## Phase 0 — 事实基线与可验证范围

先读取：

- 项目规范：`AGENTS.md` / `CLAUDE.md` / README / 架构文档
- 构建入口：Keil `.uvprojx`、CMake、Makefile、CI
- 用户指定目标文件及其直接调用者/被调用者/公共头
- 关键硬件路径：PWM/Relay/ADC/DMA/COMP/Break/Flash/UART/Watchdog
- Driver ISR、Application task/service、callback/pending 桥接链

有 CodeGraph / code-review-graph / clangd 时可辅助生成调用图，但最终结论必须回到源码证据。

### 0.1 必须先声明验证边界

报告中区分：

- **SOURCE_CONFIRMED**：源码静态证据已证实
- **HOST_PASS**：Host test 已跑
- **STATIC_ANALYZER_PASS**：clang/gcc analyzer 已跑
- **KEIL_BUILD_PASS**：目标工具链编译/链接已跑
- **BOARD_PASS**：真实板卡/示波器/故障注入已验证

缺厂商库、无板卡或无法运行某工具时直接写“未验证”，禁止把静态检查写成 BOARD_PASS。

## Phase 1 — Owner 表：状态、决策、生命周期都要有 Owner

对所有关键事实和状态列唯一 Owner：

| 对象 | 应有 Owner | 其他模块允许做什么 |
|---|---|---|
| Charge session：OFF/WAIT/PRECHARGE/RUN/FAULT | `charge` | 只读状态/提交事件 |
| TC/CC/CV/FC | `charge_stage` / `charge_policy` | 只接收其输出约束 |
| MPPT search/PI/Vref/算法状态 | `mppt` | 只通过公共算法接口调用 |
| Fault active/latched/recovery | `protection` | 消费 safety decision，不直接改内部位图 |
| PWM/Relay 正常硬件提交 | `output executor`/driver 唯一出口 | 其他模块只提交命令 |
| Emergency HardTrip | ISR/Driver safety path | 只做最短硬停 + pending，主循环归档 |
| ADC measurement snapshot | `sample` | 其他模块读批准后的快照/DTO |
| Telemetry/debug | `debug` | 只读 snapshot，不反向控制策略 |
| MPPT session init/reset | `charge session transition owner` 或明确 coordinator | 其他模块只提交 invalidate/exit 事件 |
| COMP live protection window | PWM executor/driver | Application 不得下一拍才补 armed |

如果发现两个模块都在决定同一个状态，标记 **Distributed State Machine / Multiple Owners**。

**特别检查 lifecycle：** `init/reset/start/stop/restart/park/recover`。这些不是“工具函数”，也是状态转移。重复调用即使幂等，也要追问为什么存在多个 Owner。

## Phase 2 — 依赖图、调用图与反向边

至少检查：

- `.c/.h` include 方向
- A 调 B，同时 B 又调 A
- A 通过 getter 读 B，B 又主动修改 A
- Debug/Telemetry 反向被业务模块 include
- Algorithm include Charge/Protection/Driver
- Output/Protection/Charge 同层相互调用
- **Driver include `main.h` / `app_*.h` / policy header**
- **Measurement/sample 为打印日志反向读取 charge/output/protection/driver**

重点找强连通分量（SCC）。目录分成 `app/driver` 不代表真正分层；如果 `charge ↔ protection ↔ output` 形成环，仍然是不合格。

### 2.1 不只扫 include，还要扫 write/call sites

对以下 API/寄存器必须列所有写点：

```text
PWM Arm/Disarm/SetDuty/HardTrip/MOE/CCR
Relay GPIO write
Fault latch/clear
Charge state transition
Algorithm reset/init
Protection epoch/pending
```

“只有一个 include”不能证明“只有一个 writer”。宏、ISR、helper、callback 都要算。

## Phase 3 — Ownership / Boundary 缺陷

### 3.1 Ownership Inversion — 所有权倒置

红旗：

```c
struct mppt_controller {
    mppt_ctx_t algorithm;
    charge_stage_ctx_t charge_stage; // 错：算法控制器拥有充电策略状态
};
```

如果模块名叫 MPPT/Algorithm，却拥有 Battery Profile、Charge Stage、Relay session、Fault session，它通常已经变成 God Controller。

### 3.2 Bidirectional Semantic Coupling — 双向语义耦合

例如：

- `charge_stage` 命令“清 MPPT integral”
- MPPT 的 `search.state` 又决定 `charge_stage` 是否允许 CV→CC

应改为业务事件/约束，由各自 Owner 解释。

### 3.3 Fat Interface / Overexposed Context

红旗：

```c
foo(const app_sample_t *sample,
    const app_battery_profile_t *profile,
    const app_protection_t *prot,
    const app_charge_ctx_t *charge);
```

审查它实际读取几个字段。若只需 `pv_mv/pv_i_ma/bat_mv/power_limit`，要求改成窄 DTO/标量。**跨模块 DTO 表示批准后的合同，不是把所有状态复制一遍。**

### 3.4 Type Ownership Error — 类型放错位置

例如完整 Charge Session enum 却定义在 `charge_stage.h`，导致别的模块为了 `RUN` 被迫 include Stage。类型应该放在真正 Owner 的公共合同或独立最小 contract header。

### 3.5 Implementation Detail Leakage

红旗字段/接口：

- `clear_power_integral`
- `reset_tracking`
- `search_state` 被业务层直接判断
- Application 直接访问算法 ctx 内部积分器

高层只表达业务语义，例如 `control_session_invalidated`、`mode=HOLD`；算法内部是否 PI/P&O/IncCond 不能泄漏。

## Phase 4 — API、参数、命名与“硬件能力真实性”

逐函数检查：

1. 参数是否都是函数真正需要的？
2. 参数名是否表达单位和语义（`*_mv`, `*_ma`, `*_mw`, `*_permille`, `*_ms`）？
3. 一个值是否被赋予两种语义？例如 `power_allow=0` 有时表示 hard-stop、有时表示 soft-zero。
4. `candidate/approved/committed/hardware` 是否被混叫成 `duty`？
5. `relay_applied/relay_closed` 是否其实只是 GPIO ODR 镜像？如果没有触点反馈，不得命名成物理闭合。
6. init/reset/start/stop 是否存在多套近义 API，调用者不知道层级？
7. 公共头是否暴露私有 ctx、PI integral、search internals？
8. DTO 是否包含不相关 stage/fault/relay/profile 等上层概念？
9. `try_start()/enable()/commit()` 返回 true 时，是否真的发生了状态转移或提交？
10. Fault 名称是否暗示了硬件实际上并不存在的检测能力？

推荐命名流水线：

```text
candidate_duty -> approved_duty -> committed_duty -> hardware_duty
relay_request_on -> relay_odr_on -> relay_contact_closed(只有真实辅助触点反馈时才可用)
```

### 4.1 API truthfulness 规则

```c
bool try_start(void)
```

若当前已经 RUN，内部 `start()` 什么都没做，但仍返回 true，属于**逻辑 bug**，不是命名问题。返回值必须说明：

- transition happened
- command accepted and queued
- already in requested state

三者不能混成一个 `true`。

## Phase 5 — 函数真实副作用与隐藏依赖

函数签名和注释必须与实现一致。重点抓：

- 注释写“本函数不访问硬件”，内部却 `DRV_*()`
- 已传 `hw_snapshot`，内部又重新读硬件，形成 mixed snapshot
- 已传 protection decision，内部又 `app_protection_latest()`
- helper 无参数，却依赖一堆 file-static `s_sample/s_run_mode/s_duty`
- getter 名义只读，实际触发状态更新
- policy 函数内部直接 latch fault / arm PWM / write relay

对每个核心函数记录：

```text
Inputs / Hidden Inputs / Outputs / State Mutation / HW Side Effects / Caller / Timing
```

隐藏输入若会影响控制结果，通常至少 P2；涉及 PWM/保护时提高到 P1。

## Phase 6 — 状态机、会话边界与重复生命周期动作

检查是否存在多个模块对同一事件给出不同生命周期解释。

典型例子：

- Charge FSM 对 Relay Lost 做 100ms debounce
- MPPT wrapper 一帧 `relay=false` 就 `reset_tracking()`

这属于实际行为冲突，不只是代码风格。

必须区分：

```text
本拍必须 Duty=0 / 停能
vs
整个 control session 已失效，需要 reset algorithm state
```

### 6.1 每个 transition 必须列 Side Effect

至少列：

```text
OFF -> PRECHARGE
PRECHARGE -> RELAY_SETTLE
RELAY_SETTLE -> RUN
RUN -> WAIT/OFF/FAULT
FAULT -> RECOVERY/WAIT
```

每条边检查：

- 谁触发？
- 谁修改 state？
- 谁 reset/init algorithm？
- 谁控制 relay？
- 谁 arm/disarm PWM？
- 同一 side effect 是否在 transition 前、transition helper、外层 wrapper 重复执行？

**幂等不等于架构正确。** `reset()` 被连续调用三次虽然当前无功能差异，仍说明 lifecycle Owner 不唯一。

## Phase 7 — Safety-edge Timeline：必须审“第一拍/最后一拍”

这是 V0.2.0 的核心门禁。对所有危险动作画有序时间线，而不是只看稳态。

### 7.1 PWM 上电/发波边沿

至少追踪：

```text
Duty shadow = 0 ?
Clear pending fault ?
Comparator/Break live window ready ?
ISR guard/seen_high/armed ready ?
MOE/Timer Arm ?
First non-zero Duty commit ?
Shadow/preload takes effect on which update event ?
```

必须回答：

> **从哪一条语句开始，功率级第一次可能真的输出能量？在它之前，所有必须的快速保护是否已经生效？**

如果 Protection/COMP live window 要等下一次 1ms task 才武装，而 PWM 已经开始非零发波，按 P1 起报；若可导致硬件失控，提升 P0。

### 7.2 PWM 收波/故障边沿

检查顺序：

```text
禁止继续增功率
-> Duty 归零/HardTrip
-> MOE OFF
-> 关闭/重置 live window
-> Relay policy
-> 清 pending/允许恢复
```

不能在还可能有脉冲时先关闭唯一快速保护。

### 7.3 Relay 上下电边沿

检查：

- precharge 条件和时间
- ODR request 与真实触点反馈是否混淆
- relay settle/debounce 与 MPPT session reset 是否一致
- fault 时先 PWM 还是先 relay，是否符合硬件安全顺序

## Phase 8 — ISR / Main 并发、TOCTOU 与原子握手

必须检查：

- ISR 是否只做必要搬运/快故障；业务解析是否跑进 ISR
- `volatile` 是否被错误当作原子性/互斥
- ISR 与 main 对多字节/结构体/位图是否有撕裂风险
- DMA buffer 双缓冲 ownership
- ADC sample sequence / captured time / freshness
- PWM shadow/preload 与“当前 Duty”的语义
- Break/COMP 后 Application 是否可能重新 enable PWM
- fault epoch 在算法计算前后是否复核
- Relay/PWM 是否存在多个写硬件出口
- STOP/recovery 是否同拍互相覆盖
- Watchdog 是否掩盖死循环或长临界区

### 8.1 强制 TOCTOU 检查

看到这种模式必须展开时序：

```c
if (COMP_IsHigh()) {
    edge_armed = true;
}
```

若 ISR 可能发生在“读到 HIGH”和“写 `edge_armed=true`”之间，检查 ISR 的 guard：

```text
Main: read HIGH
          |
          +---- ISR falling edge ----> sees armed==false -> return
          |
Main: armed=true
```

这就是可能丢事件的 TOCTOU。修复应考虑由 Driver/Executor 原子建立窗口、临界区、硬件 latch 或单向握手，而不是只加 `volatile`。

### 8.2 扫 ISR early-return guard

对每个 COMP/ADC/Break ISR，列出所有早退条件：

```text
initialized?
window_open?
seen_high?
armed?
pwm_active?
```

然后反向追踪每个 guard **何时由谁置位/清零**，并与 PWM/Relay 真正生效时间对齐。

## Phase 9 — Safety Snapshot / Generation Coherence

当一拍里 protection 会运行两次或发生 epoch recheck 时，不能只更新一个 bool。

### 9.1 统一 safety snapshot

推荐把同一代事实打包：

```c
typedef struct {
    uint32_t epoch;
    uint32_t fault_mask;
    app_fault_disposition_t disposition;
    bool unsafe;
    bool stop_pending;
} app_safety_snapshot_t;
```

如果执行：

```text
protection_service_runtime()
-> algorithm step
-> protection_service_runtime() again
```

第二次之后必须重新获取**完整** snapshot。以下情况必须报 Mixed Snapshot：

```text
protection_fault = 新一代
fault_mask       = 旧一代
disposition      = 旧一代
```

### 9.2 Commit barrier

最终硬件提交前至少确认：

```text
measurement generation valid
safety epoch unchanged / refreshed
command still allowed
executor has final hard-safety gate
```

Policy 层可以保持纯；最终瞬时硬件复核应集中在 executor/safety-commit，不要散在多个 policy。

## Phase 10 — Multiple Sources of Truth / Product Envelope

搜索同一个约束是否被多处重算：

```text
300W limit
PV × 8A
BAT × 6A / 6.6A
Duty max/min
Battery OV threshold
Relay state
```

Defence-in-depth 可以存在，但必须区分：

- **Policy owner**：计算业务限制
- **Safety validator**：只验证结果未越硬件绝对边界

### 10.1 强制数值/公式重复搜索

若 Application 已产生：

```c
power_limit_mw
duty_limit_permille
```

则搜索算法/driver 中是否又硬编码：

```text
300000
8000
6000
pv_mv * 8000
bat_mv * 6000
```

“数值目前相同”不是通过理由；将来 6A→6.6A 只改一处就会分叉。

## Phase 11 — Producer / Consumer / Recovery Reachability

对每个 safety-relevant enum、fault bit、action、event 建表：

| Symbol | Producer | Consumer | Clear/Recovery | Reachable? |
|---|---|---|---|---|
| `APP_FAULT_RELAY_FAULT` | ? | disposition | ? | 若无 producer = zombie |
| `APP_MPPT_ACTION_ZERO_HOLD` | ? | charge/output | reset path | 若无 producer = zombie |

必须同时查：

- public header 定义
- private header 定义
- switch case 消费
- 实际赋值/return producer
- recovery/clear producer

不能因为 Zombie 已经移到 private header 就忽略；private dead contract 仍会误导维护者。

### 11.1 Hardware-capability audit

Fault 名称与硬件实际观测能力必须一致：

- 只有 GPIO ODR：只能证明 MCU 请求/寄存器状态
- 有 IDR：也未必证明继电器触点物理闭合
- 有辅助触点/电压反馈：才可命名 `relay_contact_closed`

如果 `RELAY_FAULT` 描述“吸合反馈异常”但硬件没有反馈且代码无 producer，应明确报告。

## Phase 12 — Config Ownership 与 Layer Contract

不允许一个 `app_config.h` 成为所有层的参数垃圾桶。

审查每个配置项属于：

- Product/Safety
- Charge policy
- Algorithm tuning
- Driver/HW
- Debug/Telemetry

如果算法工程师为了调 Kp/Ki 必须打开充电/Relay/Protection 全部宏，说明配置边界失败。建议按 Owner 拆文件，例如 `app_config.h` + `mppt_config.h`。

同时检查：

- Driver 不得 include `main.h` 只为了一个配置宏
- Driver-specific compile option 应在 driver contract/config
- Product config 不应复制到 algorithm config 形成第二真值

## Phase 13 — Static Tooling / Tests：PASS 不能只靠眼睛

在环境可用时，至少尝试：

1. **严格编译**：GCC/Clang `-Wall -Wextra -Werror` 或项目等价设置
2. **静态分析**：`gcc -fanalyzer` / `clang --analyze` / 已配置 analyzer
3. **include/call SCC**：脚本、CodeGraph 或 code-review-graph
4. **全局 symbol/write-site 搜索**：PWM/Relay/fault/reset/start/stop
5. **现有 host tests**：尤其算法合同、policy、replacement tests

工具不可用时记录缺口，不得虚报。

### 13.1 安全负向测试清单

若有 Host/HIL 能力，优先增加这些回归：

- PWM 第一个非零周期立即触发 COMP fault，必须 HardTrip
- `read comparator high` 与 `mark armed` 之间注入下降沿，不得丢 fault
- algorithm step 与 final commit 之间注入新 fault，旧 disposition 不得继续生效
- RUN→STOP 只发生一次 session reset
- `try_start()` 在非 OFF 状态不能报告“新启动成功”
- relay 只有 ODR、无触点反馈时，不得伪造 contact-closed fault/pass
- Product current limit 修改后，不得存在 algorithm 内旧常量悄悄限幅

## Application 内部分层基准

`app/` 和 `driver/` 分开只是第一层。复杂控制固件至少区分：

```text
Scheduler / Application Coordinator
        |
        +--> Measurement Adapter (sample snapshot)
        +--> Safety Policy (protection)
        +--> Domain Policy (charge stage / battery)
        +--> Algorithm (MPPT)
        +--> Output Policy
        +--> Output Executor / Safety Commit
        +--> Driver

Observability (debug/telemetry)
        ^
        |
   read-only snapshots
```

推荐主链：

```text
ADC Driver
   -> Sample Snapshot
   -> Protection Evaluate
   -> Charge/Stage Policy
   -> Algorithm Candidate
   -> Safety Recheck (same-generation snapshot)
   -> Application Approval
   -> Output Policy
   -> Executor Final Gate
   -> PWM/Relay Driver
```

快速故障例外链：

```text
COMP/ADC/Break ISR
   -> HardTrip immediately
   -> latch/pending minimal evidence
   -> main-loop protection archives/recovery policy
```

禁止的依赖方向：

```text
Algorithm -> Charge Stage / Protection / Driver
Driver -> main/app policy
Debug -> 反向控制 Charge/Protection
Sample -> 为 telemetry 反向拉取 Charge/Output/Protection
Output policy -> 偷偷重跑 Charge/Protection 业务判据
Peer module <-> peer module 双向修改状态
```

# 审查完成门：没有完成这些，不得下“没问题”结论

至少输出或内部完成以下 9 项：

1. **Owner 表**：包含 session、stage、algorithm、fault、PWM/Relay、lifecycle reset、COMP live window
2. **依赖图 + SCC**：同时检查 `app↔app` 和 `driver→app` 逆向边
3. **Actuator writer 表**：PWM/Relay/HardTrip 所有写点
4. **Safety-edge timeline**：至少审一次 PWM `0→非0` 和 fault `safe→unsafe→HardTrip`
5. **ISR guard/TOCTOU 表**：谁置 armed/window/seen，何时相对 PWM 生效
6. **Snapshot generation 检查**：二次 protection/epoch recheck 是否整体刷新
7. **Lifecycle side-effect 表**：init/reset/start/stop 是否多 Owner/重复调用
8. **Producer-consumer reachability 表**：fault/action/event 是否有真实 producer
9. **Multiple Sources of Truth 搜索**：产品功率/电流/Duty/OV 等关键约束

如果用户要求“全面复核”，**只跑单元测试或只看几个头文件不足以判 PASS**。

# 审查输出格式

先给结论，再给证据。不得只说“建议重构”。

## 1. 总结

```text
当前最大风险：Safety-edge 空窗 / Owner 不唯一 / Mixed Snapshot / 依赖成环 / 算法边界泄漏 / PWM安全...
```

并明确：

```text
ARCHITECTURE_PASS / PARTIAL / FAIL
SAFETY_TIMING_PASS / PARTIAL / FAIL
STATIC_VALIDATION_PASS / PARTIAL / NOT_RUN
BOARD_VALIDATION_PASS / NOT_RUN
```

## 2. 问题表

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
- Mixed Snapshot / Generation Mismatch
- Multiple Sources of Truth
- Peer-to-Peer Mutation
- Temporal Coupling
- Safety-edge Window
- TOCTOU / ISR Race
- Semantic Overloading
- Dead Contract / Zombie Interface
- Lifecycle Multi-Owner
- API Truthfulness Bug
- Hardware Capability Mismatch
- Hardware Single-Writer Violation

## 3. Owner 表

列出“当前 Owner / 应有 Owner / 冲突模块”。

## 4. 依赖/调用图

至少给关键链：

```text
sample -> protection -> charge -> algorithm -> application validation
       -> safety recheck -> output policy -> executor -> driver
```

指出环、逆向边和 driver→app 违规。

## 5. Safety-edge Timeline

至少画一个真正的边沿：

```text
Task tick N:
  comparator window ?
  -> Arm PWM
  -> non-zero duty
  -> first physical pulse
  -> ISR guard state ?
Task tick N+1:
  ...
```

不能只说“COMP 有 ISR，所以有保护”。

## 6. 整改顺序

按 **P0/P1 行为安全 → snapshot/并发 → ownership/boundary → SCC/config → naming/dead code**。大型工程禁止一次推倒重写；优先切清边界并保持行为，再做下一刀。

## 7. 验证缺口

明确哪些是：源码证实 / host test / static analyzer / Keil build / 台架示波器。

# 审查红旗清单

看到以下任一情况必须停下来深挖，而不是继续表面整理：

- `xxx_controller_t` 内嵌另一个上层业务状态机 ctx
- 算法模块 include `charge_stage.h` / `protection.h` / `drv_pwm.h`
- 跨模块接口直接收整个 `app_sample_t *`，实际只用 3~5 个字段
- `charge_stage` 输出 `clear_xxx_integral`
- Protection disposition 出现算法内部术语 `reset_tracking`
- 同一硬件被多个 `.c` 写
- 同一个 fault/session 在两个模块分别 debounce/reset
- `step()` 已传 snapshot，内部又读硬件/全局 latest
- 发生二次 protection service 后只刷新 `fault=true`，但 mask/disposition 仍旧
- PWM `Arm/SetDuty` 先发生，COMP/Break live window 下一拍才建立
- ISR 用 `armed/seen_high/window_open` 早退，但置位发生在 PWM 生效之后
- main 先读硬件再置 ISR guard，中间允许 ISR 抢占
- RUN→OFF 的 reset 在外层、transition helper、stop wrapper 重复调用
- `try_start()` 在状态没变化时返回 true
- 业务模块 include `debug.h` 只为 telemetry bit
- sample/measurement 模块为日志反向读取 charge/output/protection
- Driver include `main.h` 或 app policy header
- 公共 header 暴露私有算法 ctx
- 同一参数 `0` 同时表示 hard-stop 和 soft-zero
- enum/action 在消费者里有分支，但生产者永远不产生
- fault 名称声称“触点反馈异常”，实际只有 GPIO ODR 且无 producer
- Application 已传 power_limit，Algorithm 又硬编码 300W/8A/6A
- 文件夹看起来分层，但 include/call graph 存在 SCC

# 边界

- 默认只读审查；没有用户明确授权，不改代码、不提交。
- 不为了“架构漂亮”改变保护阈值、硬件时序、协议或产品行为。
- 无法确认业务语义时标记“需要产品确认”，不得自行发明。
- 发现 P0/P1 时优先报告，不能被注释/格式问题淹没。
- 对安全时序没有证据时，不得用“应该没问题”“看起来没问题”收尾。

# 报告结尾必须回答

1. 这是功能 bug、并发 bug、时序 bug，还是架构/设计 bug？
2. 哪个状态/决策/lifecycle 的 Owner 错了？
3. 现在是否存在两个模块同时解释同一事实？
4. PWM/Relay 的**第一拍和最后一拍**保护是否完整？
5. ISR guard 是否可能被 TOCTOU 绕过？
6. Protection recheck 后是否混用了不同 generation 的事实？
7. 换 MCU / 换算法 / 加新充电阶段 / 修改 6A→6.6A 时，哪里最容易再次出错？
8. 最小安全整改切口是什么？
9. 哪些结论尚未通过 Keil/板卡/示波器验证？
