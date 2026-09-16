# 语义复审清单

机械检查不能判定“文章讲对了”。正式完成需当前内容摘要绑定的复审记录。

| id | 复审要求 |
|---|---|
| scope | 范围分母、实现/接口边界、构建条件、解析失败均公开 |
| original_function_body_fidelity | 函数页第1节完整、原样覆盖真实函数体与原注释，没有把学习注释混进原码 |
| code_explanation | 第5节真实解释用途、机制、顺序和影响，不是语句清单或API名翻译 |
| annotated_source_fidelity | 第5节注释版只加解释，不改表达式、分支、顺序；理由区分事实/推断/未知 |
| control_flow | 实质分支、早退、循环、fallthrough和同调用续执行与代码相符 |
| calls_and_events | caller/callee、注册/分发、硬件事件和include没有混淆 |
| parameters_units | 参数单位、符号、0值、边界、时间和整数舍入正确 |
| source_fidelity | 同一基线，不把旧计划、注释和推断写成活动实现 |
| learning_and_deep_dive | 有可完成的学习阶段与核心联合专题，不只是目录 |
| visual_and_readability | 代表性SVG可读、中文无乱码、段落非模板套话 |
| evidence_limits | 文档、Host、目标链接、实板结论分开；无未授权源码修改 |

每项notes写具体复核范围，不写“已全部确认”却不给依据。同一agent复核不得冒充独立第三方审核。

### 不合格样式

第1节缺完整函数体；第1节被插入学习注释；第5节只换标题仍列“Lxx执行语句”；注释仅翻译API名；编造芯片等待时间或写锁防抢占保证；讲解悄悄添加源码没有的超时/故障处理；每函数只有签名＋“先检查再处理”；调用未知回调画实线；宏0值被统一解释；源码hash变化后旧复审仍写PASS。
