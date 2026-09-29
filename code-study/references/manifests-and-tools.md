# 工具与完成检查 · 2.0

Python 3.10+标准库用于确定性辅助操作，Graphviz只在render时需要，Playwright/Chromium只在browser_smoke时需要。不自动装依赖，不自动理解代码。已有`init/render/index/check/drift/fingerprint/finalize`命令保留。

`init --repo R --config C`创建`R/docs/code-study/<book_id>/`，拒绝已有书和越界/符号链接。`study-config.json`填写真实源码范围；只读收集并保留原字节，不把SDK/密钥/整仓库无差别复制。先验证全部输入再写目录。需要保留无源码快照模式时用`snapshot_mode=none`并记录固定提交引用，不能声称离线可看不可见代码。

`index --book B`递归索引learning/modules/functions/reference；重新复制本地阅读器资产，适用于旧书升级。`render`只处理书内DOT，不运行项目脚本。`check`核对链接、索引新旧、SVG与快照；不偷偷修复过期索引。索引落后先重建再复审。所有失败返回非零，不能只在JSON写FAIL但命令返回0。

## 清单与统计

`verification/inventory.json`记录发现方法与限制、file_coverage、modules、symbols、edges、articles。字段含稳定id、条件分支、源路径/范围、对应文章/图。函数指针、硬件事件、include和普通调用分别标记；未知边不得画已证实实线。每个选中文件有处理方式，解析失败不从分母消失。

`verification/learning_plan.json`记录阶段、文章、实际功能覆盖、未覆盖及理由，辅助审稿，不用固定篇数充当完成线。`verification/editorial_review.json`含`status`、`content_digest`、`reviewer`、`limitations`、`chapter_reviews`；每章检查动作讲解、真实分支、参数来源、例子、图与自测。初始NOT_RUN，不自动生成语义PASS。

## 摘要和验证分层

`fingerprint`统一覆盖所有正文、图、reader、完整索引、study配置以及baseline/source_manifest/inventory/learning_plan。排除验证报告、进度和截图，避免浏览器报告哈希进入自身。语义复审与browser_smoke调用同一算法。

`check`和`drift`失败返回1；参数/依赖/路径错误返回2。`finalize`必须在准确项目书目录，结构、语义逐章复审、浏览器均通过且摘要一致才返回0及DIRECTORY_READY；否则返回1及DIRECTORY_INCOMPLETE。这个结果仍不是硬件验收。

函数第1节完整原代码、第5节代码解释的样式会检查；逐字节原函数忠实性、因果解释和真实图义仍需按源码复审。不要让工具能力描述超过实现。HTML只渲染受支持的Markdown子集；遇到表格合并/复杂HTML等须明确适配并实际测试，不静默丢内容。

## 浏览器受限时

默认browser_smoke使用file://；检测到管理策略阻断或缺少依赖记NOT_RUN，不改系统策略。可在允许的环境显式使用`--base-url http://127.0.0.1:端口`检查本地HTTP预览，但记录transport=local-http；它不能满足离线file验收。finalize只接受transport=file且摘要一致的真实通过记录。
