# 清单格式与工具边界

## 工具职责

`scripts/code_study.py`负责确定性文件操作和机械检查；Codex负责读源、建立调用证据、撰写文章和语义复审。工具不能自动证明算法、ISR竞态或硬件安全。

常用命令：

```bash
python "$SKILL_DIR/scripts/code_study.py" init --repo "$REPO" --config "$CONFIG"
python "$SKILL_DIR/scripts/code_study.py" render --book "$BOOK"
python "$SKILL_DIR/scripts/code_study.py" index --book "$BOOK"
python "$SKILL_DIR/scripts/code_study.py" check --book "$BOOK" --repo "$REPO"
python "$SKILL_DIR/scripts/code_study.py" drift --book "$BOOK" --repo "$REPO"
python "$SKILL_DIR/scripts/code_study.py" fingerprint --book "$BOOK"
python "$SKILL_DIR/scripts/code_study.py" finalize --book "$BOOK" --repo "$REPO"
```

Graphviz只在render时需要；Playwright+Chromium只在浏览器smoke时需要。脚本不自动下载依赖。

## inventory.json最低字段

- `discovery`：发现方法、工具版本、构建变体、限制。
- `file_coverage`：所有选中文件及其处理方式，不能因解析失败从分母消失。
- `modules`：模块id、源文件、文章与图。
- `symbols`：稳定id、真实签名、guard、源码范围、函数文章与图。
- `edges`：direct/callback_registration/callback_dispatch/hardware_event/macro/dependency/external/unresolved，并给源码证据。
- `articles`：modules/functions/reference/learning下每篇Markdown及关联源码。

自动调用边只有可能性时保留`unresolved`；没有找到caller不等于死代码。

## 机器事实文件

- `study.json`：工具配置。
- `verification/baseline.json`：HEAD、dirty状态、采集时间和源码摘要。
- `verification/source_manifest.json`：原路径、快照路径、SHA、编码、字节和行数。
- `verification/inventory.json`：模块、函数、调用边、文章范围。
- `verification/progress.json`：撰写进度，不是验证通过证据。
- `verification/completion.json`：就地完成记录，不是ZIP收据。

## 函数页检查

函数页必须同时满足：

1. `## 1. 完整函数体与原注释`存在且含真实代码块；第1节不混入“学习注释”等教学标签。
2. `## 5. 代码解释`存在，含真实代码片段和学习解释，不是L行号＋“执行语句/判断条件”的机械转录。
3. `original_function_body_fidelity`、`code_explanation`、`annotated_source_fidelity`在语义复审中重新核对。

结构检查只能发现格式和链接问题，不能证明函数体与源码完全一致；完整忠实性必须对照`source_snapshot`或固定源码引用复审。

## 完成状态

`finalize`只允许`<repo>/docs/code-study/<book-id>/`。它不移动、不归档、不删除文章。结构通过、当前语义复审和真实file浏览器记录均绑定当前摘要时，状态才是`DIRECTORY_READY`；否则为`DIRECTORY_INCOMPLETE`并保留已生成文件。
