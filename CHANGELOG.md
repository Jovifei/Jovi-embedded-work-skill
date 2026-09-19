# Changelog

版本号写在各 skill 的 `SKILL.md` 文首 `**Version:**` 或对应版本声明，以及本文件。README「当前版本」表应与之一致。

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

未改：`clangd_init` V1.1.0、`project-init`、`day_sum`、`child-claude`、`codex-memory`、`c-pan-reorganize`、Android 三件套 v0.1.0。
