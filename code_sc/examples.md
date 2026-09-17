# code_sc examples

## Example 1 — Controller ownership inversion

```text
/code_sc 审查 mppt.c / mppt.h / charge_stage.c / charge.c，重点看模块 Owner、调用关系和接口。
```

期望：不仅找逻辑 bug，还要回答：

- `mppt_controller` 为什么拥有 `charge_stage_ctx`；
- 哪个状态应由 `charge`、`charge_stage`、`mppt` 分别拥有；
- 是否存在 `Charge Stage -> MPPT internals -> Charge Stage` 双向语义耦合；
- 是否有 Relay/session 同一事实被两个模块用不同规则解释；
- 最小切口如何改，不一次推倒整个 Application。

## Example 2 — Fat interface

```text
/code_sc 这个算法接口收 app_sample_t* / battery_profile* / protection*，检查是不是传太多。
```

期望：列出算法实际使用字段，建议窄 DTO，例如：

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

不要把 Charge Stage、Fault、Relay、Battery Profile 整体泄漏给算法。

## Example 3 — Application 内部环依赖与逆向边

```text
/code_sc app/driver 已经拆开了，再检查 charge/protection/output/debug/driver 的内部依赖。
```

期望：发现并解释类似：

```text
charge -> protection -> output -> charge
driver -> main/app
sample -> charge/output/protection   // 只为 telemetry 也不合理
```

不能因为目录已经分层或 include 图局部无环就宣称架构完成；还要查 call/write edges。

## Example 4 — Mixed snapshot / hidden dependency

```text
/code_sc app_output_step() 已经传入 hw snapshot，但内部仍然读 DRV_PWM_IsOutputEnabled()。
```

期望：判断这是无意隐藏依赖，还是有意的“最终安全提交复核”。如果是后者，建议把二次硬件确认放到 executor/safety-commit 层，并让策略函数保持纯输入。

## Example 5 — Safety review

```text
/code_sc 重点审 PWM 发波、中断抢占、ADC DMA、COMP Break、Relay、故障恢复。
```

期望优先输出 P0/P1：

- PWM 是否有多个写点；
- Break 后是否可能被主循环重新使能；
- protection epoch 是否在算法计算后复核；
- ISR/main 对 fault bitmap、sample、duty 是否存在撕裂；
- Relay debounce 与 session reset 是否冲突；
- 至少画一条真正的 PWM/COMP 边沿时间线。

## Example 6 — First-cycle protection window

```text
/code_sc 这段顺序是 supervise_comp2() -> pwm_apply()；supervise 时 MOE=0 会清 seen_high，pwm_apply 随后 Arm 并写非零 Duty，下一拍 supervise 才 MarkOutputHigh。检查第一拍是否漏保护。
```

期望必须画：

```text
Tick N:
  supervise: MOE=0 -> seen_high=0
  pwm_apply: Arm -> non-zero duty
  [first physical PWM pulses]
  COMP falling edge -> ISR sees seen_high==0 ?
Tick N+1:
  supervise -> MarkOutputHigh
```

如果 ISR guard 在第一批危险脉冲后才建立，标记 **Safety-edge Window**，不能用“稳态有 COMP ISR”判安全。

## Example 7 — ISR/main TOCTOU

```text
/code_sc 主循环先 COMP_IsHigh()，再 edge_armed=true；ISR 会先判断 edge_armed。分析是否会丢下降沿。
```

期望展开抢占：

```text
Main: read HIGH
        |
        +-- IRQ: falling edge, armed==0 -> return
        |
Main: armed=1
```

不能建议“把变量改 volatile 就好”。应考虑 driver-owned atomic handshake、硬件 latch 或受控临界区。

## Example 8 — Protection generation coherence

```text
/code_sc 本拍 protection 跑两次，第二次只更新 protection_fault/epoch，mask 和 disposition 没刷新。
```

期望判为 **Mixed Snapshot / Generation Mismatch**，要求同一代：

```c
struct safety_snapshot {
    uint32_t epoch;
    uint32_t fault_mask;
    disposition_t disposition;
    bool unsafe;
    bool stop_pending;
};
```

二次 evaluate 后必须整体重取再给 charge/output 使用。

## Example 9 — Lifecycle multi-owner

```text
/code_sc STOP 路径外层 reset MPPT，RUN->OFF transition 也 reset，stop wrapper 又 reset。reset 是幂等的，是否可以保留？
```

期望：仍然报告 **Lifecycle Multi-Owner**。推荐让 `RUN -> non-RUN` transition 成为唯一 session reset owner，其它模块只提出退出 RUN/invalid session 事件。

## Example 10 — API truthfulness

```text
/code_sc try_start() 在 RUN 状态时 start() 不做事，但 try_start() 仍 return true。
```

期望：报告真实逻辑 bug，明确 `true` 是“发生新状态转移”“命令已接受”还是“已经处于目标状态”，不能混用。

## Example 11 — Multiple sources of truth

```text
/code_sc Application 已经算 power_limit_mw，但 MPPT 内又写 300W / PV×8A / BAT×6A，当前数值相同。
```

期望：不能以“数值相同”通过。必须区分：

```text
Product/Policy Owner -> 唯一业务 envelope
Algorithm            -> 只消费 envelope
Safety Validator     -> 可有独立绝对硬件上限，但名称/来源必须清楚
```

并说明 6A→6.6A 时只改一处可能产生分叉。

## Example 12 — Zombie fault + hardware capability mismatch

```text
/code_sc APP_FAULT_RELAY_FAULT 说“吸合反馈异常”，但板子没有继电器辅助触点，代码也找不到 producer。
```

期望同时指出：

- **Zombie Contract**：有定义/consumer、无 producer；
- **Hardware Capability Mismatch**：GPIO ODR 不是触点反馈；
- 命名应区分 `relay_request_on / relay_odr_on / relay_contact_closed`。

## Example 13 — Completion gate

```text
/code_sc 全面复核。Host tests 都 PASS，给我最终是否没问题。
```

不能只依据测试。完整审查至少要覆盖：

```text
Owner table
SCC/reverse edges
PWM/Relay writer table
Safety-edge timeline
ISR guard + TOCTOU
Snapshot generation
Lifecycle reset/start/stop owner
Fault/action producer-consumer reachability
Product limit duplicate search
```

最终要分开写 `SOURCE/STATIC/KEIL/BOARD` 验证等级。
