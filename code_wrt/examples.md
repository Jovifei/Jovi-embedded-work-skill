# code_wrt V0.2.2 注释样例

对照 2026-09-02 `mppt-charger-300w` G2 手改。执行时用这些当合格线，不要用「每个 DDL 字段一行中文」当合格线。

## 控制流：写不变量和失败含义

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
        // 跌破 2.8V 不是 Fault：抖动 1ms 也要把已积累的 99ms 清掉，否则会带着半窗放行
        stable_tracking = false;
        stable_start_ms = 0U;
        __WFI();
        continue;
    }
    ...
}
```

PVD Ready 超时要写成「芯片 PVD/时钟异常」，不要写成「弱光」。弱光路径是后面那个无限等待循环。

## 看门狗票：写成故障模式，不要只写「主循环置位」

```c
#define DRV_WATCHDOG_TICKET_MAIN    (1UL << 0) // 缺此票：主循环没转，禁止 feed
#define DRV_WATCHDOG_TICKET_CONTROL (1UL << 2) // 缺此票：1ms ISR 没到，禁止 feed
```

## Init：写算出来的数，不写字段翻译

```c
/* GPIO：5 路模拟输入 PA8/PA9、PB0/PB5/PB12（legacy，无 PB1） */
gpio.Mode = DDL_GPIO_MODE_ANALOG;
gpio.Pull = DDL_GPIO_PULL_NO; // 内部上下拉会并联到 26:1 分压，必须关
gpio.Pin = DDL_GPIO_PIN_8 | DDL_GPIO_PIN_9;

DDL_RCC_SetADCClkDiv(DDL_RCC_ADCCLK_DIVISION_4); // 64MHz/4=16MHz
timer.Prescaler = 63U;  // 64MHz/(63+1)=1MHz
timer.Autoreload = 99U; // 1MHz/(99+1)=10kHz → 100μs 触发一轮扫描
```

不要给 `Mode`/`Drive`/`OutputType`/`InputEnable` 各写一遍中文别名。

## 删除非产品路径时的整链

删 UART 回环：同时删 `drv_debug_uart_poll`、主循环调用、RX 环与 RXNE 入队（若 TX 打印仍需要 RXNE，至少在注释写明「RX 无消费者，满则丢」并评估是否关 RX 中断）。

删 Logo / 复位原因打印：声明、定义、调用使用同一组 `#if DEBUG_ENABLE && DEBUG_XXX_ENABLE`。不要只在头文件加 `DEBUG_ENABLE`。

不要为了读 `DEBUG_RESET_REASON_ENABLE` 在 `driver/src/*.c` 里 `#include "main.h"`。捕获放 Driver 常开，或把开关放到 `drv_device.h`。
