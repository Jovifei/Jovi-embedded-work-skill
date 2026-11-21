# Changelog

版本号写在各 skill 的 `SKILL.md` 文首 `**Version:**` 或对应版本声明，以及本文件。README「当前版本」表应与之一致。

## 2026-11-22

| Skill | 从（维护库） | 到 | 说明 |
|---|---|---|---|
| code_wrt | V0.4.0 | **V0.4.2** | 按实际范围收口接口、同拍状态、显式模式、重复计算与目标镜像验证。吸收安装版 V0.4.1 的命名使用链检查。 |
| code_sc | V0.3.2 | **V0.3.3** | 核查实际写点、预览与缓存、诊断回流、复位与重启时序，按证据逐项验收。 |
| code_zl | V0.2.8 | **V0.2.10** | 纳入安装版 V0.2.9 的有用语义检查，明确函数头与逐行覆盖、暂存范围和模板大括号规则。 |

## 2026-11-04

| Skill | 从 | 到 | 说明 |
|---|---|---|---|
| code_wrt | V0.3.2 | **V0.4.0** | 增加已拍板模块命名合同、搜索/编排/数学 helper 分层、candidate/approved/committed/driver 语义、floor/boundary/max 与控制时基门禁；补命名迁移完成门和 MPPT 压力场景。 |
| code_zl | V0.2.2 | **V0.2.8** | 增加命名与注释真实性联审：floor/boundary/max、候选/提交/驱动设定、last_control_ms/control_dt_ms、Demo/Vref 前缀和历史旧名分类。 |
| clangd_init | V1.1.0 | **V1.1.1** | 同步发布说明：Ctrl+S 必须使用 clangd formatter，`.clang-format` 为唯一格式来源，code_zl 模板和 VS Code 设置作为可复现资源。 |

本次同步只更新 skill 规则、示例、eval 和 clangd/格式化资源，不改固件源码。

## 2026-10-15

| Skill | 从 | 到 | 说明 |
|---|---|---|---|
| code_zl | V0.2.1 | **V0.2.2** | 统一完整真实签名、唯一函数合同头与简单私有函数例外；声明仅在同作用域、同条件守护且可证明等价时前置；检查结构体同类型分组但不重排成员，收紧注释任务及配置同步范围。 |
| code_sc | V0.3.1 | **V0.3.2** | 补真实消费者分类、自有命名迁移、结构体类型分组及固定布局例外；保留必要控制状态、授权遥测与短硬件时序接口，按最终内容和实际验证给结论。 |
| code_wrt | V0.3.1 | **V0.3.2** | 在授权范围内完成命名、Owner、API和成员分组收口；核查初始化及外部布局依赖，同步测试/接收端，保留内部控制状态和安全时间屏障，分离技能与固件版本。 |

依据 MPPT V0.15.28 的实际优化加固通用规则，不固化该项目阈值、帧长或一次性删除选择。成员按相同声明类型分别集中，同类保留原顺序；bool 与 uint8_t 不混组，固定 Flash/协议/DMA/ABI 布局保留，函数形参顺序不变。新增场景与资源/版本检查随发布提供；静态与行为评估不代表固件或实板验证。

## 2026-09-29

| Skill | 从 | 到 | 说明 |
|---|---|---|---|
| code-study | V1.3.0 | **V2.0.0** | 按运行阶段与功能的完整口语图文教程；保留原函数查询层，升级离线阅读器，修复递归索引、摘要和失败退出码，补工具回归与逐章复审。 |
| product-doc | 新增 | **V1.0.0** | 源码驱动的产品说明、运行逻辑与参数台账；定义和使用处溯源，区分推导/实测/未知，提供保护恢复、验收、多格式规范及只读检查器。 |
| README | — | — | 同步两项文档技能版本、入口、安装示例与使用场景。其他skill不变。 |

验证边界和复现命令见`code-study/tests/VALIDATION.md`与`product-doc/tests/VALIDATION.md`；本次不含产品固件。

## 2026-09-23

| Skill | 从 | 到 | 说明 |
|---|---|---|---|
| code_sc | V0.3.0 | **V0.3.1** | 增加冗余审计矩阵、数值清洗与安全时间屏障分层、candidate/approved/driver_setting/physically_effective 四层语义、证据分桶与重构合同收口。 |
| code_wrt | V0.3.0 | **V0.3.1** | 增加最小改动门禁、单一真源与单点清洗边界、删除前全量检索、物理行为冻结、重构后 API/工程/测试/文档闭环和失败回滚原则。 |
| code_zl | V0.2.0 | **V0.2.1** | 增加注释经济性、事实单一 Owner、函数头/行内注释分工、异步状态白话术语和注释残留/不变性检查。 |
| README | — | — | 同步三项 skill 版本和本次工程反馈门禁。 |

## 2026-09-19

| Skill | 从 | 到 | 说明 |
|---|---|---|---|
| code_wrt | V0.2.1 | **V0.3.0** | 从“写前/写后架构门禁”升级为工程集成门禁：精确 SHA、merge-as-new-code、公共头最小化/IWYU、安全宏 definedness、API Consumer Matrix、IRQ 向量强实现、临时停波 re-arm ramp、veto 可达性、WCET/tick/CI 分级；eval 14→25。 |
| code_sc | V0.2.0 | **V0.3.0** | 新增 merge 合同矩阵、public contract resurrection、关键预处理值、NVIC→vector→strong handler、re-arm stale Duty、orphan veto、liveness≠deadline、header economy、CI/旧 SHA 证据隔离；eval 15→26。 |
| code_zl | V0.1.8 | **V0.2.0** | 注释从“白话”提升到“白话且真实”：数字/单位/硬件能力/时序/验证等级必须与源码一致；发现传递 include 安全宏、75%/80%、ODR/触点、bool tick/精确 1ms 等矛盾必须报警；eval 6→13。 |
| README | — | — | 同步三项 skill 新版本、触发能力与工程防错原则。 |

## 2026-09-17

| 项 | 说明 |
|---|---|
| code_sc | **V0.1.0 → V0.2.0**：补齐 safety-edge 第一拍/最后一拍、COMP/Break live window、ISR/main TOCTOU、same-generation safety snapshot、lifecycle single-owner、API truthfulness、producer-consumer reachability、driver→app 逆向依赖、产品 envelope 单一真值与完整审查完成门；eval 从 6 条扩展到 15 条。 |
| README | 对齐 `SKILL.md`：补 `code_sc` V0.1.0、`code-study` V1.3.0；`code_wrt` 纠正为 **V0.2.1**（旧 README 误写 V0.1.5）；增加全量版本清单、安装命令与使用场景 |

## 2026-09-16

| Skill | 从 | 到 | 说明 |
|---|---|---|---|
| code_sc | 新增 | **V0.1.0** | 深度嵌入式代码审查：Owner/边界/依赖环/调用关系/DTO/API/隐藏依赖/状态机/PWM-Relay-Protection/ISR 并发/死接口 |
| code_wrt | V0.2.0 | **V0.2.1** | 明确 Driver/Application 层级合同、ISR→Driver→callback/pending→Application service 全链、Application 模块关系、task 调度边界、函数角色命名、参数命名/单位/位置规则 |
| code-study | 新增 | **V1.3.0** | 项目 `docs/code-study/<基线>/` 直接生成逐模块/逐函数 Markdown、SVG、阶段学习与唯一搜索HTML；函数页先看完整原函数，再做代码解释 |
| update-project-docs | V1.0.0 | **V1.1.0** | Full Refresh 全树清单；代码 diff 驱动现网口径；README/GUIDE/`00-阅读指引` 介绍面是完成条件；禁止只改几篇专题 |
| code_zl | V0.1.0 | **V0.1.8** | 白话注释、先定义再使用、`// todo:`、任务目录/1ms 标志注释口径 |
| prj_zl | V0.1.0 | V0.1.0 | 号未升；与本地 Keil `app/driver` 规则核对后同步 |

未改：`clangd_init` V1.1.0、`project-init`、`day_sum`、`child-claude`、`codex-memory`、`c-pan-reorganize`、Android 三件套 v0.1.0。\n
