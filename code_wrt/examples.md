# code_wrt 实施与验证样例（V0.4.3）

这些示例说明合同和判断方法。自有 MPPT 分层示例只适用于已采用该结构的工程；当前 C300 保留原库，按 [C300 实施边界](references/c300-contract.md) 执行，不为示例新建算法层、DTO 或文件。

## 有界收口：生产镜像、恒真准备与命名

当前授权结构整理且无外部布局约束时，按声明类型分组，例如：

```c
/* 整理前 */
typedef struct {
    float gain;
    uint8_t mode;
    bool ready;
    float limit;
    uint8_t retry;
    bool valid;
} control_t;

/* 整理后：同类型内原顺序不变 */
typedef struct {
    float gain;
    float limit;
    uint8_t mode;
    uint8_t retry;
    bool ready;
    bool valid;
} control_t;
```

重排前核查所有初始化器、offsetof/sizeof、raw memcpy/序列化及外部布局消费者；位置式初始化须相应保持原字段值，指定式也要检查依赖。packed Flash/协议/DMA/寄存器、bitfield、ABI/汇编/回调固定布局保持原样并说明例外。优先项目组序，未规定时通常按目标自然对齐/宽度从大到小；bool 不与 uint8_t 混组。不为此改函数形参、另套嵌套结构或新增头，也不在缺目标证据时宣称固定 RAM 收益。

用户授权删除公开 PI 镜像和多余 wrapper 时，先列真实调用：私有积分、采样序号、缓存限幅参与控制应保留；公开 `integral_copy` 仅测试读可删除并调整测试对实际内部状态/行为的断言。当前授权的两种遥测仍读 `limit_mw`，保留输出能力并选择满足观测目的的最少字段，更新实际 receiver 的中文字段、单位及两种解码检查。不能恢复公开镜像迎合旧 fixture，也不能一概删除 diag。

`bool prepare_zero()` 全路径恒真且 caller 只检查假失败，可改 `void` 并更新声明/定义/调用/测试/函数头。其 stop→写零→清旧标志顺序不变，后续 `zero_applied()` 仍等自然更新；arm 写前、写后、恢复中断后否决分开对照。只删无独立合同的 `Disarm→Stop` 别名，保留真正 stop、向量桥和有授权消费者的短 getter。

自有 `DRV_PWM_Stop→drv_pwm_stop` 要检查全部消费者及项目/decoder/docs，保留 `COMP_IRQHandler`、SDK/CMSIS 及外部回调 ABI。私有类型和宏放真实 Owner；同值但不同生命周期的上限不盲合并，同真源别名可保留。最小方案任务只交方案，不声称实际实施、Host、Keil 或实板已经通过；纯注释不升固件版，固件改动也不顺带升技能版。

跨模块实施先写清 **Owner / Caller / Callee / Timing / Data / Side Effect**；Layer 用于描述职责，不规定文件层数。涉及中断时核对 `IRQ -> Driver -> callback/pending -> 前台消费`，并保留硬件/驱动 ISR 的立即关断通道。小范围命名和注释按风险检查，不机械扩展成全工程架构项目。

## 例 1：自有算法不拥有 Charge Stage

错误：

```c
typedef struct
{
    app_mppt_algorithm_ctx_t algorithm;
    app_charge_stage_ctx_t charge_stage;
} app_mppt_controller_t;
```

该自有对象将充电业务状态交给了算法 Owner。应把 TC/CC/CV/FC 放回业务责任方；若是供应商库固定结构，先核对库合同，不能自行重定义其 ABI。

正确方向：

```text
现有 charge 业务实现
    -> 必要输入/约束（标量、既有快照或确需的 DTO）
    -> 自有算法候选
    -> output 最终复核并通过驱动提交
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
      calls: charge policy + app_mppt_duty()
      outputs: candidate charge command

L2 Executor:
  app_task_output()
      reads: candidate command + final safety facts
      owns: final approval and normal power commit
      calls: drv_pwm_* / drv_gpio_*
```

这些是已有函数的职责说明；不要求为 L2/L3 各建文件。普通驱动命令可由对应应用职责直接调用，不强制通过 ISR。

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

业务任务由 main/既有调度者调用，不由 IRQ 嵌套调用。比较器故障的硬件/驱动 ISR 仍立即关断；该路径不等待前台任务，也不调用完整 output 状态机。

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

Application 再在 `app_task_sample()` 中消费。Driver 不依赖 `charge.h`。选择已有简单机制即可，不要求新建回调层；若在 ISR 回调，写明上下文和 payload 生命周期。

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
app_task_uart()/mmi     -> foreground command/protocol semantics
app_task_charge()       -> charge policy
app_task_telemetry()    -> logging/telemetry
```

`service` 表示“服务本 Owner 的 pending/deferred work”，不是“所有事情都塞这里”。

## 例 6：按真实需要选择跨模块输入

错误：

```c
mppt_step(sample, profile, protection, charge_ctx);
```

如果自有算法实际只用 Vpv/Ipv/Ppv/Vbat 和功率/Duty 上限，先看显式参数或既有只读快照是否足够；确需新的稳定 DTO 时可以写：

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

不要把无关 Fault、Relay、Charge Stage、Battery Profile 整体泄漏给算法，也不为形式创建 DTO/header/wrapper。C300 原库的签名与结构布局按原合同保留，调用集中 charge。

## 例 7：函数名要说明“谁 + 做什么 + 对谁做”

差：

```c
process(ctx, data, value, flag, state);
```

好：

```c
mppt_search_result_t mppt_search_step(mppt_search_ctx_t *ctx,
                                      const mppt_measurement_t *meas,
                                      bool demo_freeze_normal_search);

bool mppt_algo_step(mppt_algo_ctx_t *ctx,
                    const mppt_algo_input_t *input,
                    mppt_algo_output_t *output);
```

角色一眼能看懂：

```text
mppt_search_ -> MPPT 搜索层入口
mppt_algo_   -> MPPT 算法编排层入口
_step        -> 单次确定性推进
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

跨模块参数确需 `state/mode/status` 时，补充对象：

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
hardware_duty_permille    # 有硬件证据支持的实际生效值
```

这样出现“算法候选 320‰，示波器观察 304‰”时能沿链排查。CCR、MOE 和物理波形不是同一事实，比较计数与导通比例先核对极性/更新模式。

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

不要继续加第四条互相修改内部状态的 setter。通过既有 main 编排或单向 request/event 合同让各 Owner 更新自身状态；不因此新建 coordinator 文件或消息总线。

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
        app_task_recover(tick_ms); /* 只评估恢复资格，不直接开功率 */
        app_task_protect(tick_ms);
        app_task_charge(tick_ms);
        app_task_output(tick_ms); /* 最终复核后提交正常功率 */
    }
}
```

调度顺序由 main/既有调度者负责。示例任务名不要求新建文件；同轮 STOP、命令、保护和维护请求都须在最终功率提交前生效，output 后的任务不能再绕过审核开功率。

## 例 14：函数签名必须说真话

如果：

```c
void app_output_step(const app_output_hw_t *hw);
```

内部又：

```c
DRV_PWM_IsOutputEnabled();
app_protection_latest();
```

先判断这是隐藏依赖还是有意的最终安全复核；有意的现场复核保留在输出提交职责并写进 API 合同，不额外新建 safety-commit 文件。实际接口改动列完整旧/新签名和所有消费者，不能只给函数名或省略参数。

## 注释示例：写出时间、失败和有效性

```c
/* 超时每次服务按真实时间检查，不等待下一个 ADC 样本。 */
if ((uint32_t)(now_ms - qualification_start_ms) >= qualification_timeout_ms)
{
    qualification_cancel();
    return;
}

/* 前台服务：无效段撤销资格，旧快照不刷新采集时刻或补造新样本。 */
if (!sample->valid)
{
    qualification_cancel(); /* 此示例的批准合同：无效样本中断连续窗口。 */
    return;
}
if (sample->sequence == last_sequence)
{
    return;
}

last_sequence = sample->sequence;
/* 后续仅用本次新样本推进批准的资格判据。 */
```

这只是函数内片段，实际函数头需给完整签名、上下文和失败合同。若窗口规则已有缺陷，注释整理应记录问题，修复按已授权 BUG 范围实施。使用当前项目样式和可用的 code_zl，不硬编码其他技能版本。

## 例 15：C300 吸收参考实现不吸收产品参数

用户已授权把 B 的职责组织和有证据的缺陷修复移入 C300。先分别记录原 C300、B/165W 和当前工作树；保留 C300 的 300 W、10 A、6 A/2 A、13–55 V、原库比较范围与普通 12 档。B 的 165 W、7 A、5 A、8–90% 和独立 90 V/95 V 门不跟随代码迁入。

搬函数登记为结构整理，修 CBC 旧候选重启登记为 BUG，批准的 Demo 目标登记为功能，实测热点预计算登记为优化。直接保留 `HT32_Mppt_Solar.h` 对应原库，调用/复位集中 charge；不重写库结构、不写私有 Duty、不加转发层。原库未换仍需验证候选和实际 CCR 的闭环动态。

## 例 16：紧急关断与最后正常提交可以同时成立

比较器在 charge 已生成候选、output 尚未写入时触发。驱动 ISR 立即关断并发布故障事实/代次；output 最终检查发现旧候选代次不再合格，保持关闭。禁止把紧急关断排队等下轮，禁止 ISR 调完整 output，也不能在 ISR 改库 Duty 或恢复 MOE。

普通请求如设置候选、读取供电或请求复位用清晰的驱动/应用普通接口。LED 写入不强塞进功率 output。恢复资格先更新，最终功率在 output 审核提交；同轮后续 debug/mmi 不可重放旧合闸请求。

## 例 17：数据同源、服务延迟和 WDT

序号 100 的快照包含 I、P、极值与有效计数。复采只替换 I 却保留旧 P/极值，必须重算相关量、失效原窗口或另建明确身份，不能继续称同一窗口。平台切换/重新校准使哪些历史和候选失效要列清，不在每次普通采样重新校准。

一次服务延迟 8 ms 不能虚构 8 个有效样本；超时采用真实 elapsed，连续证据采用新有效样本数，积分按批准缺样策略处理。若 ADC 或 tick 停止但 main 仍转，不能无条件喂狗；健康检查观察关键进展，维护例外有总预算，不用停走的 tick 自证健康。

## 例 18：配置、UART 与首装是一条失败恢复链

旧的 48 V 配置完整有效，请求切到 60 V，持久化在 commit 前失败：当前有效配置不得成为“60 V 平台配 48 V 阈值”。按合同保留旧配置或禁止功率，不清空用户设置掩盖写失败。

协议定义固定头 4 字节、CRC 2 字节。`frame_len=20`、`payload_len=12` 各自低于缓冲上限，但 `4+12+2 != 20`，仍须拒绝；完整帧发布后不能被后续半帧覆盖。ACK 入队不是 TX complete。

新 BL 要求有效完成记录：只有 APP 镜像的空白新板首装也要有合法记录与校验工具。状态保存失败不能继续擦除依赖恢复信息的旧镜像；覆盖该失败点、掉电、有限重试、同镜像重入及实际新旧 APP/BL 组合。

## 例 19：预计算与缓存必须有失效依据

某系数只依赖已提交配置，可在完整提交后预计算。输出候选还依赖样本有效性、温度、目标、模式和限制来源，不能仅用相同 sequence 或最终 min 值复用。换平台、校准和保护代次变化应重算或撤销；没有热点/收益证据则优先保持简单计算。

优化收益用本版同条件 map/耗时测量；不因减少几行删除边界、保护或现场诊断。

## 例 20：已有授权与缺少硬件条件

用户已授权按阶段整理并修已确认缺陷，当前只改本模块私有函数名；环境缺少 ponytail 和目标板。读取完整使用链，按本技能完成范围相称的源码/必要编译检查，记录实际完成与未执行项，继续可做阶段。不得要求重新批准相同步骤，不为缺工具新造包装，也不填写实板 PASS。
