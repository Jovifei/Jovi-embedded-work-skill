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

## Example 3 — Application 内部环依赖

```text
/code_sc app/driver 已经拆开了，再检查 charge/protection/output/debug 的内部依赖。
```

期望：发现并解释类似：

```text
charge -> protection -> output -> charge
charge -> debug -> charge
```

不能因为目录已经分层就宣称架构完成。

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
- Relay debounce 与 session reset 是否冲突。
