# 安装与使用

复制完整`code-study/`目录到当前客户端的技能目录，不要只复制`SKILL.md`，也不要只更新`learning`模板。保留`references/`、`assets/`、`scripts/`和`agents/`。技能名保持`code-study`。

Codex项目级可放到`.agents/skills/code-study/`，用户级按客户端支持的skill路径；Claude Code按其项目/用户skill目录安装。已有安装先备份个人修改，不自动覆盖系统或其他项目。若客户端版本未识别skill，核对其当前安装文档，不猜路径或承诺热更新。

Python 3.10+用于辅助脚本；Graphviz用于DOT渲染；Playwright和本机Chromium仅用于浏览器检查。没有依赖就报告未运行，不能静默联网安装。正文的理解和撰写由agent完成，不是运行`init`就完成。

配置从`assets/templates/study-config.json`复制，填写当前项目真实路径范围、版本和基线摘要。输出默认在项目`docs/code-study/<book-id>/`，不在skill安装目录。旧书先备份笔记、记录旧哈希；同一基线更新正文和图以后重新生成整个索引及阅读器资产。

本版本新增阅读器。升级已有书时先复制本skill的`assets/search/index.html`到书的`index.html`，复制`style.css`、`search.js`到书的`assets/`，再运行`index`。不要改C/H副本凑行号。旧的验证记录一律按新内容摘要重新检查；不得拿1.3的搜索测试声称2.0整本已通过。

本地回归：

```bash
python -m unittest discover -s code-study/tests -v
```

真实文档还需另跑`browser_smoke.py`并逐章核对源码。此命令不是目标固件编译或实机测试。
