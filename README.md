# Jovi Embedded Work Skills

嵌入式工程开发 Claude Code Skills 集合，属于 Jovi 工作流体系。

## Skills

| Skill | 触发词 | 说明 |
|-------|--------|------|
| [project-init](project-init/) | `/project-init`, 项目初始化 | 一键初始化嵌入式工程工具（CodeGraph/code-review-graph/comet/文档） |
| [update-project-docs](update-project-docs/) | `/update-project-docs`, 更新文档 | 嵌入式工程文档管理：bootstrap 脚手架 + 日常文档维护 |
| [code_zl](code_zl/) | `/code_zl`, 代码整理 | 嵌入式 C 代码注释整理：标准函数头 + 行内注释 + 分节 |
| [day_sum](day_sum/) | `/day_sum`, 总结日报 | 从开发记录生成结构化日报 |

## 安装

将每个 skill 目录复制到 `~/.claude/skills/` 即可：

```bash
# 克隆到本地
git clone https://github.com/Jovifei/Jovi-embedded-work-skill.git

# 复制 skills 到 Claude Code skills 目录
cp -r Jovi-embedded-work-skill/project-init ~/.claude/skills/
cp -r Jovi-embedded-work-skill/update-project-docs ~/.claude/skills/
cp -r Jovi-embedded-work-skill/code_zl ~/.claude/skills/
cp -r Jovi-embedded-work-skill/day_sum ~/.claude/skills/
```

## 使用方式

在 Claude Code 中直接输入触发词即可：

```
/project-init D:\work\my-new-embedded-project
/update-project-docs 初始化文档
/code_zl src/modbus.c src/can.c
/day_sum 总结今天的开发记录
```

## 规范

所有 skill 遵循 [writing-skills](https://github.com/anthropics/claude-code) 规范：
- frontmatter 以 "Use when..." 描述触发条件
- 包含 evals.json 测试用例
- 支持中英文触发词
