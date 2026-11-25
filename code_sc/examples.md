# code_sc examples

适用版本：V0.3.5。以下均为非规范性举例。文件、函数、字段、数值、模块和调度仅属于各段给出的假设输入，用于演示如何从事实推导结论。不得将其复制为其他工程的组织方式、参数或验收条件；实际任务必须重新取得约束和源码证据。

## 目录

- 消费者分类与短接口：内部状态、布局、ABI、时间屏障。
- Example 1–4：Owner、接口、依赖方向、最终安全复核。
- Example 5–9：功率安全、首拍、TOCTOU、snapshot、生命周期。
- Example 10–13：返回合同、参数真值、观测能力、全面复核证据。
- Example 14–18：参考吸收、采样/时间/WDT、配置/协议/首装、分级、已有授权。
- Example 19–20：不同架构和未知实现的审查边界。

## 消费者分类与短接口的反例

假设本例项目已明确采用按声明类型分组的内部结构样式。此时私有结构的 float、uint8_t、bool 交错可建议按该规则整理，同类原顺序不变；uint8_t 与 bool 不能仅因同宽混组。其他项目不继承这个样式要求。若另一个 packed Flash/协议结构由固定 offset、汇编或回调 ABI 消费，保留它并记录例外。审查初始化器、offsetof/sizeof 和 raw 传输路径之后再给整改结论；目标 sizeof/对齐未核实不能保证省多少 RAM，也不因成员分组去改函数形参。

同一算法中，`integral` 参与下一拍回算，`last_seq` 防止重复积分，`cached_duty` 在重复采样时按新 cap 收紧；这些是内部真实消费者，即使没有外部 getter 也保留。`integral_copy` 只有旧 Host 夹具读取时可建议删公开镜像，并将测试改为真实私有状态/输出断言；`limit_mw` 被当前授权的两种路测帧消费时则保留合同，收窄导出面不等于取消帧。只写 `updates` 无消费者要以活动源码/测试/decoder 搜索证据判断，不把 diag 当删除条件。

`prepare_zero()` 所有路径恒 true 可建议 void，但它发出写零请求不代表零已生效；保留后续自然更新确认、首脉冲许可、写前/写后及恢复中断后的否决。`ADC_IRQHandler()` 一行转发属于向量合同，`duty_get()` 为两种模式提供窄只读合同，也不能因短而删除。协议把算法缓存叫实际波形时，报告来源差异；不偷偷增加硬件写入或把遥测改成恒零。

验收要展示真实 final 内容、改名映射与适用检查结果。源码顺序、Host fake 顺序、目标编译和实板更新事件分别提供证据；任一层未执行就明确列出，不用旧 SHA 或只包含断言函数的脚本冒充 HOST_PASS。

## Example 1 — Controller ownership inversion

```text
/code_sc 审查 mppt.c / mppt.h / charge_stage.c / charge.c，重点看模块 Owner、调用关系和接口。
```

期望：先确认它是独立纯算法、charge 编排 Owner 还是厂商固定结构，再回答：

- `mppt_controller` 为什么拥有 `charge_stage_ctx`；
- 哪个状态应由 `charge`、`charge_stage`、`mppt` 分别拥有；
- 是否存在 `Charge Stage -> MPPT internals -> Charge Stage` 双向语义耦合；
- 是否有 Relay/session 同一事实被两个模块用不同规则解释；
- 若确有冲突，最小切口如何改，不一次推倒整个 Application；
- 若本例项目已明确由现有业务模块集中阶段和原库调用，这种归属是否本来就符合合同，不为名称强拆算法层或改库 ABI。

仅有 `mppt_controller` 内含 `charge_stage_ctx` 不能直接判 BUG/P1；多 Owner 或业务事实解释冲突要给调用/写点与影响。

## Example 2 — Fat interface

```text
/code_sc 这个算法接口收 app_sample_t* / battery_profile* / protection*，检查是不是传太多。
```

期望：列出真实消费字段、只读/写入、快照一致性和 ABI；若确有过曝私有状态，再建议窄 DTO，例如：

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

独立算法不应无必要地获得 Charge Stage、Fault、Relay 私有状态。已有完整一致 sample 快照可以合法复用；厂商固定入参/布局须保留，不能强行套此 DTO。

## Example 3 — Application 内部环依赖与逆向边

```text
/code_sc 本例已要求测量和驱动不依赖业务私有状态。app/driver 已经拆开了，再检查 charge/protection/output/debug/driver 的内部依赖。
```

期望：发现并解释类似：

```text
charge -> protection -> output -> charge
driver -> app 私有充电/保护状态
sample -> charge/output/protection   // 只为 telemetry 也不合理
```

不能因为目录已经分层或 include 图局部无环就宣称架构完成；还要查 call/write edges。驱动通过自身定义的中立事件回调上行可以合法，不把回调调用方向自动当驱动依赖应用私有策略。

## Example 4 — Mixed snapshot / hidden dependency

```text
/code_sc app_output_step() 已经传入 hw snapshot，但内部仍然读 DRV_PWM_IsOutputEnabled()。
```

期望：判断这是无意混代/隐藏输入，还是有意的“最终安全提交复核”。如果是后者，在现有执行 Owner 中明确复核职责和失效规则，避免策略计算混用事实；不为此自动新建 executor 模块。

## Example 5 — Safety review

```text
/code_sc 本例设计由 output 仲裁正常功率输出，比较器 ISR 必须立即关断。重点审 PWM 发波、中断抢占、ADC DMA、COMP Break、Relay、故障恢复。
```

期望按真实可达后果定级，已证实的高风险先报告：

- PWM 是否有多个写点；
- Break 后是否可能被主循环重新使能；
- protection epoch 是否在算法计算后复核；
- ISR/main 对 fault bitmap、sample、duty 是否存在撕裂；
- Relay debounce 与 session reset 是否冲突；
- 至少画一条真正的 PWM/COMP 边沿时间线。

正常功率经 output，驱动 ISR 立即 hard-trip 是必要例外；不能要求 ISR 等前台统一出口，不能因此自动判多 Owner。普通应用→驱动调用不必经过 ISR，LED 等非功率 GPIO 不受功率单一提交规则约束。

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

如果 ISR guard 在第一批危险脉冲后才建立且早退会漏掉必要保护，标记 **Safety-edge Window**，再核实其他硬件保护和实际后果。不能用“稳态有 COMP ISR”判安全，也不能仅凭排列就固定 P0/P1。

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

期望追消费者并判断 **Mixed Snapshot / Generation Mismatch**，要求共同消费的事实同一代，例如：

```c
struct safety_snapshot {
    uint32_t epoch;
    uint32_t fault_mask;
    disposition_t disposition;
    bool unsafe;
    bool stop_pending;
};
```

二次 evaluate 后整体重取或证明等价的原子/版本机制，再给 charge/output 使用；不强制新增此结构。严重度按旧 disposition 等事实会引起的实际行为确定。

## Example 9 — Lifecycle multi-owner

```text
/code_sc STOP 路径外层 reset MPPT，RUN->OFF transition 也 reset，stop wrapper 又 reset。reset 是幂等的，是否可以保留？
```

期望：幂等不能证明归属合理。追三个调用是否分别决定同一会话失效，若是则报告 **Lifecycle Multi-Owner**，归到明确 transition Owner。若是同一 Owner 的不同时间屏障或有界恢复步骤，先证语义再删；不得只按重复次数自动定 P1。

## Example 10 — API truthfulness

```text
/code_sc try_start() 在 RUN 状态时 start() 不做事，但 try_start() 仍 return true。
```

期望：先读返回合同及 caller。若 true 表示“本次新转移完成”，当前实现违约；若合同是“目标状态已满足”，已在 RUN 返回 true 可以正确。缺合同列需补证据，不凭函数名自动判 BUG。

## Example 11 — Multiple sources of truth

```text
/code_sc 本例规定 Application 负责业务限制，MPPT 只消费限制并计算。Application 已经算 power_limit_mw，但 MPPT 内又写 300W / PV×8A / BAT×6A，当前数值相同。
```

期望：不能以“数值相同”通过。必须区分：

```text
Product/Policy Owner -> 唯一业务 envelope
Algorithm            -> 只消费 envelope
Safety Validator     -> 可有独立绝对硬件上限，但名称/来源必须清楚
```

并说明 6A→6.6A 时只改一处可能产生分叉。若数值来自必须保留的厂商库，先确认公共参数与 ABI，不为收口强改私有字段或换掉库；参考工程数值不自动成为当前产品限值。

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

不能只依据测试。根据当前工程具备的功能选择适用关系；下面是一个含功率控制工程的示意清单，不要求其他产品补建这些功能：

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

若范围涉及采样/时基、配置/Flash、协议或 APP/BL，还要覆盖其实际合同；不以只审架构和功率替代整机复核。每项列通过、失败、未执行、受阻或已知限制。

## Example 14 — 参考吸收与产品基线

```text
/code_sc 原工程 A 已发布，需求明确保留其参数表和供应商库；参考 B 使用不同硬件。当前合入结果替换了 A 的库和参数，还增加多层只转发的包装，报告只写结构整理。
```

期望：分别记录原、参考和当前身份，依据输入中的保留要求检查真实变化。参数/库替换不能藏在结构整理中；额外包装须有职责或兼容理由。检查两侧硬件假设与调用时序是否相容，不把 B 当产品基线，也不从本例推导必须使用哪种库、哪些参数或固定文件数量。

## Example 15 — 同源采样、漏服务与 WDT

```text
/code_sc 复采替换了电流但 power/max 未动；重复 seq 重新写 captured_at。漏 20ms 服务只给 charge_time 加 1，WDT 看到 main 转圈就喂；暂停 ADC 做 Flash 没有预算。
```

期望：分别追采样窗口/校准/派生量、样本身份、真实时长、连续新样本计数、积分缺样策略和健康进展。定义维护预算与恢复的新鲜数据条件；不补造 ADC 样本、不无限用旧功率积分，不要求每圈所有任务都产生新样本。没有目标测量不能宣称 1ms deadline 已满足。

## Example 16 — 配置事务、UART 关系与 BL 首装

```text
/code_sc 新平台先写入运行态，Flash 失败仍回成功；APP 只查总长上限，BL 信内层 block_len。新 BL 要有效 DONE，工厂烧录只烧 APP/BL，OTA 测试成功。
```

期望：核对完整配置版本和失败后行为、外长/内长/偏移与实际数据的关系、DONE 来源和工厂首装路径。OTA 通过不证明首装能启动；APP OTA 不自动更新 BL。缺记录是否必然影响实际部署需源码/工具证据，不照搬其他工程的 DONE 格式。

## Example 17 — 宏、IRQ 和证据分级

```text
/code_sc protection.c 没直接 include config，但当前 target 明确 -DPROTECT=1；startup 有 weak IRQ，链接 map 显示强 handler；只有上一版板测记录。审核说三个 P1。
```

期望：按本版 translation unit 和 map 核实，不能仅凭缺直接 include 或 weak 声明固定 P1。旧板测不能验收当前差异，应列当前证据缺口；确有可达保护关闭/中断挂死才按真实后果定级。维护建议与 BUG 分开。

## Example 18 — 授权继续与范围

```text
/code_sc 前面已授权修复命名和确认的 BUG，继续查并修。无授权的 Demo 新交互先不要加。
```

期望：核实后承接已授权修复，不每阶段重新询问。遵守供应商/IRQ/ABI 例外并同步 caller/工程/文档；未定 Demo 交互列范围外，继续其余工作。单纯“只出审查结论”则不编辑生产源码、提交或部署。

## Example 19 — 不同调度和模块数量

```text
/code_sc 这是 RTOS 温湿度记录器，既有采集、存储和通信三个任务，无功率输出。要求保留调度与公开接口，只审查这次采样缓冲交接的合并。
```

期望：审当前任务、ISR 和消费者之间的缓冲寿命、一致性、丢弃策略及合并后的接口/构建成员，不套充电阶段、继电器或固定任务表，不要求改成前台串行。若缺实际同步实现，指出具体证据缺口，不因不是某个参考工程的组织方式判错。

## Example 20 — 没有提供实现时

```text
/code_sc 我只有需求：把两个来源的功能整合并保持外部行为。请给通用审查原则，还没确定文件、函数和硬件。
```

期望：给出基线、变更分类、责任和接口、冲突处理、行为对照、配置依赖、失败恢复和验证证据原则。明确具体对象由实施阶段填写；不能编造文件表、函数名、阈值、硬件流程或历史 BUG，也不把示例命名转成要求。
