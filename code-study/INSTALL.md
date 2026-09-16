# code-study 安装与使用

版本：V1.3.0

## Codex 用户级安装

此仓库用于统一管理 Skill 源文件。推荐将仓库中的 `code-study/` 复制或软链接到当前 Codex 环境：

```text
~/.agents/skills/code-study/
```

Windows 与 WSL 的 `~` 不同；在哪个环境运行 Codex，就安装到那个环境的用户目录。

也可以只给一个项目使用：

```text
<project>/.agents/skills/code-study/
```

安装后重新启动 Codex；显式使用：

```text
$code-study 为当前项目制作完整代码学习资料。
```

## 默认行为

- 直接生成/维护 `<project>/docs/code-study/<源码基线>/`。
- 正文全部 Markdown，只有 `index.html` 用于离线全文搜索。
- 逐模块、逐函数、SVG/DOT、核心专题、分阶段学习、source_snapshot 与 verification 都留在项目 docs 内。
- 每个函数页第1节先完整展示原函数体与原注释；第5节再做注释式代码解释。
- 不生成学习资料 ZIP，不修改业务源码，不自动提交/推送远端。

## 生成工具

```bash
python ~/.agents/skills/code-study/scripts/code_study.py init --repo <repo> --config <config.json>
python ~/.agents/skills/code-study/scripts/code_study.py render --book <book>
python ~/.agents/skills/code-study/scripts/code_study.py index --book <book>
python ~/.agents/skills/code-study/scripts/code_study.py check --book <book> --repo <repo>
python ~/.agents/skills/code-study/scripts/code_study.py finalize --book <book> --repo <repo>
```

工具只负责确定性文件、快照、搜索与机械检查；文章解释、调用证据与语义复审仍由 Codex 读源码完成。
