# 本轮工具验证记录

日期：2026-09-29。对象为本目录提交的skill辅助工具，输入全部是虚构测试样例，不是产品固件。

## 实际执行

`python -m unittest discover -s code-study/tests -v`：**17项通过**。

另执行`node --check code-study/assets/search/search.js`与Python编译检查，均通过。

`python code-study/tests/reader_memory_test.py`：**18项Chromium内存页面检查通过**，覆盖正文搜索、嵌套章节、表格、展开答案、前后章、函数/源码跳转、源码转义、图放大和窄屏布局。桌面和手机截图已查看。图像由虚构测试数据注入，不证明本地文件资源加载。

真正的`browser_smoke.py` file://及本地HTTP访问均被当前浏览器管理策略阻断，记录**NOT_RUN**，未改变或绕过策略。内存页面测试不产生file://通过记录，也不能让finalize满足离线验收。

覆盖的代码回归包括：递归索引/链接，零层和多层**目录匹配，原字节保留，旧索引不被check掩盖，源漂移，失败退出码，报告摘要不自引用，旧复审失效，HTTP不能充当file验收，路径穿越/符号链接，脚本转义和SVG主动内容。

## 不包含的结论

`evals/evals.json`是6条后续教学/生成效果评估提示，当前状态NOT_RUN；没有声称完成不同模型的端到端教学效果评测。每次用于真实项目，仍须核对源码、讲解、图、参数和真实输出；文档验证不代替固件编译或板级测试。
