---
name: day-sum
description: Use when the user asks to summarize daily work from development records, logs, or notes. Triggers include "daily summary", "work summary", "summarize today/yesterday", or reading development log files.
---

# Day Summary Generator

## Overview

Read development records and generate structured daily work summaries organized by problem discovery, analysis, and resolution.

## When to Use

- User provides a development log file (e.g., `开发记录.md`, `dev_log.md`)
- User asks to summarize work for specific dates
- User requests daily/weekly work reports

## Output Format

```markdown
## [日期编号] [日期]

### [编号] [任务名称]

1. 发现问题：[问题描述，包含现象、影响、相关代码/日志证据]
2. 分析：[根因分析，技术细节，参考来源]
3. 解决：
 - [具体修复项 1，包含文件名、函数名、关键改动]
 - [具体修复项 2]
 - [待修复项标注"待xxx修复"]

### [编号] [任务名称]
...
```

## Numbering Rules

- 日期编号：`X.Y` 格式，X 为文档序号，Y 为日期序号（如 `5.11` 表示第 5 节第 11 项）
- 任务编号：`X.Y.Z` 格式，Z 为任务序号（如 `5.11.1`）
- 修复项：用 `- ` 列表，不加数字编号

## Content Rules

**发现问题**：包含现象描述、影响范围、相关代码/日志证据，尽量具体

**分析**：包含根因、技术细节、参考来源（如"参考 ESP32S3 cloud.c"）

**解决**：
 - 每项修复用 `- ` 开头，包含文件名、函数名、关键改动
 - 已解决项写具体实现
 - 待解决项标注"待xxx修复"并说明原因

## Example

```markdown
## 5.11 5.20

### 5.11.1 IoT 影子变量自动推送 + PIID 类型修复

1. 发现问题：`iot_task()` 只处理被动下发和定时上报，缺少主动检测 `app_param` 本地变化并推送 `properties_changed` 的能力。IoT 后台定义 PIID 2/7/8/9/10/15/22/25 为 `uint8` 类型，代码用 `set_prop_float` 发送，序列化后 value_type=FLOAT 与后台不匹配。

2. 分析：参考 ESP32S3 `cloud.c:cloud_msg_excute()` 的 23 个影子变量模式，移植到 GD32。IoT 后台类型定义是权威来源，`set_prop_*` 必须严格一致。

3. 解决：
 - 实现 `shadow_poll_and_publish()`，10 个影子变量每 100ms 对比变化，带阈值防抖
 - 新增 `set_prop_int()` helper，修正 8 个 PIID 类型
 - 4 个序列化位置添加 `IOT_VALUE_TYPE_INT` 处理
```

## Tips

- 同一日期的多个任务按编号递增
- 保持技术细节具体性：文件名、函数名、宏名、寄存器地址
- commit hash 在任务标题后标注（如 `commit 5821b16`）
- 跨模块影响需说明（如"架构三层：iot_msg.c → 4g_mqtt.c → 4g_ml307r.c"）
