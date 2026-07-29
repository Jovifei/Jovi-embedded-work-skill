---
name: code_wrt
description: "Use when the user invokes /code_wrt or asks to simplify embedded C code and then standardize its comments, organization, or formatting. Triggers include code_wrt, 代码简化整理, 简化并注释, 简化并整理."
---

# Code WRT

执行固定组合：`ponytail → code_zl`。前者负责最小化代码，后者负责按 Jovi 规范整理注释和格式。

## 必需子技能

**REQUIRED SUB-SKILL:** 修改前完整加载并应用 `ponytail`，默认使用 `full` 强度。

**REQUIRED SUB-SKILL:** 完整加载并应用 `code_zl`。

任一技能不可用时停止修改并说明原因，不得凭记忆模拟其规则。

## 工作流

1. 确定用户指定的文件范围，读取项目规范、目标文件及必要调用点。
2. 先执行 `ponytail`：删除或内联冗余代码，复用现有能力，做最小的行为保持式简化。
3. 检查第一阶段 diff；不得改变公开接口、协议语义、硬件访问顺序、RTOS 时序、并发保护、错误处理或外部可观察行为。
4. 再执行 `code_zl`：基于简化后的最终代码整理文件结构、注释、分节和对齐。`code_zl` 的“不修改代码逻辑”约束只作用于本阶段。
5. 复核最终 diff，并运行最小相关构建或测试。无法验证时明确说明。

## 边界

- 顺序不可交换，也不可只执行其中一个阶段。
- 用户只要求纯注释整理时使用 `/code_zl`，不要触发本技能。
- 不确定简化是否等价时保留原代码，并继续执行 `code_zl`。
- 发现疑似 bug 时先报告；只有用户明确要求修复时才改变行为。
- 不扩大文件范围，不执行 git commit 或 push。

## 报告

简要列出：

- Ponytail：删除、内联、复用或明确保留的内容
- Code_ZL：注释、分节、声明顺序和对齐调整
- Verification：实际运行的检查及结果
