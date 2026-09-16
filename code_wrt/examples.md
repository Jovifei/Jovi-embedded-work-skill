# code_wrt 架构写入门禁样例

V0.2.1 起，`code_wrt` 不能只把代码“写得更整齐”。写之前必须先把 **Layer / Owner / Caller / Callee / Timing / Data / Side Effect** 说明白；涉及中断时，还必须画完整 `IRQ -> Driver -> callback/pending -> Application service/task` 链。

## 例 1：不要让算法 Controller 拥有 Charge Stage

错误：

```c
typedef struct
{
    app_mppt_algorithm_ctx_t algorithm;
    app_charge_stage_ctx_t charge_stage;
} app_mppt_controller_t;
```

问题不是命名难看，而是 Ownership Inversion。MPPT 算法不应该拥有 TC/CC/CV/FC 业务状态。

正确方向：

```text
charge.c / charge_stage.c
    -> power_limit / duty_limit / algorithm mode
    -> mppt DTO
    -> mppt candidate duty
    -> application validation
    -> output executor
```

## 例 2：先写层级和调用合同

例如 ADC + 充电控制：

```text
L1 Driver:
  drv_adc_irq_handler()
      owns: DMA/ADC IRQ flags, raw block, sequence
      caller: ADC/DMA IRQ wrapper
      callee: none / neutral callback only

L2 Adapter:
  app_task_sample()
      owns: engineering-value sample snapshot
      caller: main/coordinator
      callee: drv_adc_block_take(), sample_convert()

L3 Domain:
  app_task_protect()
      reads: sample snapshot
      outputs: safety decision

  app_task_charge()
      reads: sample + safety snapshot
      calls: charge policy + app_mppt_duty_step()
      outputs: approved charge command

L2 Executor:
  app_task_output()
      reads: approved command + final safety facts
      calls: drv_pwm_* / drv_gpio_*
```

这比只写 `app/driver` 两个目录更重要。

## 例 3：中断不能直接进业务任务

错误：

```c
void ADC_IRQHandler(void)
{
    app_task_charge(drv_time_now_ms());
}
```

正确：

```c
void ADC_IRQHandler(void)
{
    drv_adc_irq_handler();
}
```

然后：

```text
ADC IRQ
 -> drv_adc_irq_handler
 -> raw block / pending
 -> app_task_sample
 -> sample snapshot
 -> app_task_protect
 -> app_task_charge
 -> app_task_output
```

业务任务由 main/coordinator 调度，不由 IRQ 嵌套调用。

## 例 4：Driver callback 必须是“中性的”

错误：

```c
/* driver/src/adc.c */
#include "charge.h"

static void adc_eos_isr(void)
{
    app_charge_on_sample(&g_charge, &raw_adc);
}
```

Driver 已经反向依赖 Application。

正确可以是 callback：

```c
typedef void (*drv_adc_block_cb_t)(const drv_adc_block_t *block,
                                   void *user_ctx);
```

或者 pending/take：

```c
bool drv_adc_block_take(drv_adc_block_t *out_block);
```

Application 再在 `app_task_sample()` 中消费。Driver 永远不认识 `charge.h`。

## 例 5：`service()` 不能变成垃圾桶

错误：

```c
void drv_uart_service(void)
{
    modbus_parse();
    app_charge_select_mode();
    telemetry_print();
}
```

正确拆分：

```text
drv_uart_service()      -> driver-owned deferred RX/TX only
app_task_uart()         -> frame/protocol parsing
app_task_charge()       -> charge policy
app_task_telemetry()    -> logging/telemetry
```

`service` 表示“服务本 Owner 的 pending/deferred work”，不是“所有事情都塞这里”。

## 例 6：跨模块只传窄 DTO

错误：

```c
mppt_step(sample, profile, protection, charge_ctx);
```

如果算法实际只用 Vpv/Ipv/Ppv/Vbat 和功率/Duty 上限，应写：

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

不要把 Fault、Relay、Charge Stage、Battery Profile 整体泄漏给算法。

## 例 7：函数名要说明“谁 + 做什么 + 对谁做”

差：

```c
process(ctx, data, value, flag, state);
```

好：

```c
uint16_t app_mppt_duty_step(app_mppt_ctx_t *ctx,
                            const app_mppt_duty_in_t *in,
                            uint32_t now_ms,
                            app_mppt_diag_t *out_diag);
```

角色一眼能看懂：

```text
app_       -> Application owner
mppt_      -> MPPT domain
_duty_     -> 对象
a_step     -> 单次推进
ctx        -> Owner state
in         -> 只读 DTO
now_ms     -> 时间单位明确
out_diag   -> 输出方向明确
```

## 例 8：参数必须带角色和单位

不要：

```c
set_limit(uint32_t value, uint32_t time, bool flag);
```

应该类似：

```c
void app_charge_power_limit_set(uint32_t power_limit_mw,
                                uint32_t timeout_ms,
                                bool limit_enable);
```

如果 `state/mode/status`  unavoidable，也写 Owner：

```text
charge_state
mppt_mode
protection_status
```

## 例 9：command / mirror / real feedback 必须区分

错误：

```c
bool relay_applied;
```

但实际只是读 GPIO ODR。

应该：

```text
relay_request_on     # Application command
relay_odr_on         # GPIO register mirror
relay_contact_closed # 只有真实触点反馈才这样叫
```

PWM 同理：

```text
pwm_request_enable
pwm_moe_on
hardware_duty_permille
```

## 例 10：Duty 控制流水线名字不要都叫 `duty`

```text
candidate_duty_permille   # 算法候选
approved_duty_permille    # Application/Safety 批准
committed_duty_permille   # 提交 output/driver
hardware_duty_permille    # 寄存器/实际生效
```

这样出现“算法算 320‰，示波器只有 304‰”时能沿链排查。

## 例 11：参数不能一值多义

错误：

```text
power_allow_mw == 0
  有时表示 Fault hard-stop
  有时表示 CV soft-zero
```

正确：

```text
numeric power_limit + explicit mode/session semantics
TRACK / HOLD / SOFT_ZERO
hard-stop -> 不调用算法或明确 session invalid
```

## 例 12：保护、充电、输出不要 peer-to-peer mutation

危险：

```text
charge -> protection_latch()
protection -> charge_lock_startup()
output -> protection_latch() + charge_lock_startup()
```

不要继续加第四条 setter。让 Application Coordinator 汇总 event/decision，再统一提交状态和输出。

## 例 13：顶层 task 不互相调用

错误：

```c
void app_task_charge(uint32_t now_ms)
{
    ...
    app_task_output(now_ms);
}
```

正确：

```c
while (1)
{
    if (drv_time_1ms_taken())
    {
        app_task_protect(tick_ms);
        app_task_charge(tick_ms);
        app_task_output(tick_ms);
        app_task_recover(tick_ms);
    }
}
```

调度顺序是 Coordinator/main 的 Owner。

## 例 14：函数签名必须说真话

如果：

```c
app_output_step(const app_output_hw_t *hw);
```

内部又：

```c
DRV_PWM_IsOutputEnabled();
app_protection_latest();
```

不能只加注释。先判断这是 hidden dependency 还是 final safety recheck；如果是安全复核，就把它放到 executor/safety-commit 层，并在 API contract 明确。

## 控制流注释仍按 code_zl V0.1.8

```c
/* 3. 连续稳定窗口：弱光下可无限等待，掉门限必须整窗重开 */
last_check_ms = drv_time_now_ms();
for (;;)
{
    uint32_t now_ms = drv_time_now_ms();

    // 1ms 核对一次，其余时间 WFI；避免资格阶段空转
    if ((now_ms - last_check_ms) < DRV_SYSTEM_SUPPLY_CHECK_PERIOD_MS)
    {
        __WFI();
        continue;
    }

    last_check_ms = now_ms;

    if (!drv_system_supply_is_good())
    {
        // 跌破门限要清掉已积累稳定窗，不能带着半窗放行
        stable_tracking = false;
        stable_start_ms = 0U;
        __WFI();
        continue;
    }
}
```

不要用漂亮注释掩盖 Layer/Owner/Caller/Callee 错误；先修结构，再整理注释。
