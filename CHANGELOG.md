# Changelog

版本号写在各 skill 的 `SKILL.md` 文首 `**Version:**` 或对应版本声明，以及本文件。README「当前版本」表应与之一致。

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
