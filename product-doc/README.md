# product-doc 1.0.0

从真实代码制作产品说明和运行参数文档。与`code-study`不同：不是逐函数教材，而是回答“产品怎样启动、怎样工作、限制多少、出错怎样停、什么时候能再试”。

- [主技能](SKILL.md)
- [专题组合](references/document-set.md)
- [参数与证据规则](references/parameter-evidence.md)
- [多格式和验收](references/quality-and-delivery.md)

复制整个目录到客户端支持的skills目录，不能只复制SKILL.md。此skill不依赖相邻的code-study才能工作。Python 3.10+用于标准库台账检查；绘图、HTML及Word由agent结合当前环境的文档工具生成，不静默安装依赖。

```text
$product-doc 基于当前源码生成产品说明与运行逻辑文档。你按实际功能分册，
把启动条件、准备过程、正常工作、保护恢复、参数切换和保存讲清楚，
把参数值和适用条件直接写进正文与图。给参数台账、离线HTML和可编辑Word。
区分代码设定、推导条件和实测指标，不改固件，不默认提交。
```

检查器只核对格式和证据文件；不能替代人工读源与产品验收。通用用法和两技能区别见[文档技能说明](../DOCUMENTATION-SKILLS.md)。
