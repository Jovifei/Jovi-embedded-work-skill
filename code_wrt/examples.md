# code_wrt 架构写入门禁样例

V0.2.0 起，`code_wrt` 不能只把代码“写得更整齐”。写之前先过 `code_sc` Owner/边界门，写完再复审依赖和副作用。

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

## 例 2：跨模块只传窄 DTO

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
} mppt_input_t;
```

不要把上层 Fault、Relay、Charge Stage、Battery Profile 整体泄漏给算法。

## 例 3：参数不能一值多义

错误：

```text
power_allow_mw == 0
  有时表示 Fault hard-stop
  有时表示 CV soft-zero
```

改成：

```text
numeric power_limit + explicit mode/session semantics
TRACK / HOLD / SOFT_ZERO
hard-stop -> 不调用算法或明确 session invalid
```

## 例 4：函数签名必须说真话

如果：

```c
app_output_step(const app_output_hw_t *hw);
```

内部又：

```c
DRV_PWM_IsOutputEnabled();
app_protection_latest();
```

不能只加注释。先判断这是隐藏依赖还是最终安全复核；若是安全复核，应把它放进 executor/safety-commit 层，让 policy step 只依赖传入 snapshot。

## 例 5：控制 Duty 命名分层

不要所有地方都叫 `duty`：

```text
candidate_duty   # 算法候选
approved_duty    # Application/Safety 批准
committed_duty   # 交给 output/driver
hardware_duty    # 寄存器/已生效
```

这样出现“算法算 320‰，示波器看到 304‰”时才有可追踪路径。

## 例 6：保护、充电、输出不要 peer-to-peer mutation

危险：

```text
charge -> protection_latch()
protection -> charge_lock_startup()
output -> protection_latch() + charge_lock_startup()
```

不要继续加第四条 setter。让 Application Coordinator 汇总 event/decision，再统一提交状态和输出。

## 控制流注释仍按 code_zl V0.1.8

```c
/* 3. 连续稳定窗口：弱光下可无限等待，掉门限必须整窗重开 */
last_check_ms = drv_time_now_ms();
for (;;)
{
    uint32_t now_ms = drv_time_now_ms();

    // 1ms 核对一次，其余时间 WFI；避免在资格阶段空转烧电流
    if ((now_ms - last_check_ms) < DRV_SYSTEM_SUPPLY_CHECK_PERIOD_MS)
    {
        __WFI();
        continue;
    }
    last_check_ms = now_ms;

    if (!drv_system_supply_is_good())
    {
        // 跌破 2.8V 要清掉已积累稳定窗，不能带着半窗放行
        stable_tracking = false;
        stable_start_ms = 0U;
        __WFI();
        continue;
    }
}
```

## Init 注释仍只写关键硬件事实

```c
/* GPIO：5 路模拟输入，关闭上下拉避免并联采样分压 */
gpio.Mode = DDL_GPIO_MODE_ANALOG;
gpio.Pull = DDL_GPIO_PULL_NO;

DDL_RCC_SetADCClkDiv(DDL_RCC_ADCCLK_DIVISION_4); // 64MHz/4=16MHz
timer.Prescaler = 63U;  // 64MHz/(63+1)=1MHz
timer.Autoreload = 99U; // 10kHz -> 100us 触发一轮扫描
```

不要用漂亮注释掩盖 Owner/依赖错误；先修结构，再整理注释。
