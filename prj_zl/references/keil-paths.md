# Keil 路径与构建核对

## 目录

1. 路径基准与关键字段
2. 更新前后的合同
3. 条件引用与命名
4. 只读检查器边界

## 1. 路径基准与关键字段

先读取原工程再改。以下仅是项目位于 `Application/Project/MDK/` 时的例子，不复制它的 SDK 层级或器件到其他工程：

```xml
<IncludePath>..\..\app\inc;..\..\driver\inc;原有且已核对的SDK路径</IncludePath>
<FilePath>..\..\app\src\main.c</FilePath>
<PathWithFileName>..\..\app\src\main.c</PathWithFileName>
```

FilePath 与 IncludePath 通常相对于各项目文件所在目录。宏、设备包路径、外部绝对路径及前后构建命令按当前 Keil/项目约定解析；不能用当前主机查不到就判目标固件逻辑错误。

| 字段/对象 | 核对内容 |
|---|---|
| 每个 Target/Group/File | 移动后仍编译原有正确文件；文件类型、排除选项、单文件选项保持 |
| IncludePath | 字面路径存在、大小写正确，顺序改变不引入同名头遮蔽；不要误替换 SDK 的 Include |
| FilePath | 规范化后无遗漏或单 target 重复源码；SDK 和测试替身分别归类 |
| ScatterFile/链接选项 | APP/BL 地址、大小、RAM/SRAM 分区与原合同一致；仅修路径 |
| PathWithFileName | 已有 uvoptx 的相应视图引用同步，其他调试/下载设置保留 |
| TargetName/OutputName | 不与工程文件名混为同一操作，明确本轮实际允许变化 |
| BeforeMake/AfterMake | 工具、工作目录、引号、输入输出、硬编码文件名及实际消费者 |
| 下载/工厂/OTA脚本 | 是否依赖旧路径、名字、镜像范围或升级凭据 |

## 2. 更新前后的合同

保存本次允许的旧→新路径映射，再比较各 target 的原始成员与配置。用 XML 解析器或精确局部编辑保留未涉及的节点；不要因重排 XML 丢掉单文件宏、排除开关或调试器配置。

移动含相对 include 的文件时，以源文件的新位置重新核对。例如 `#include "../Include/board.h"` 可能需最小路径更新；检查目标仍为同一声明，而不是只保证存在一个同名文件。

比较结果至少列出：源文件集合、关键宏、设备、库、startup、scatter、前后构建和输出消费者。合法历史路径/SDK 路径可以保留，零旧名命中不是验收目标。

## 3. 条件引用与命名

`IAP_Application1` 的 1 是否只是临时后缀，由现有调用方和用户范围决定。重命名仅执行已批准部分；若用户仅改项目文件名，不擅自改变 OutputName 或固件协议版本。

`@L/!L` 等工具占位符仅按实际 Keil 命令解释；有些命令会引用 OutputName，有些直接写死名字，不能假定都会自动跟随。需要运行或核对每条受影响命令。

SDK、闭源库、烧录脚本和受跟踪发布镜像不是可任意忽略的垃圾。若依赖通过外部安装获得，记录精确版本、获取方式和当前缺失情况，保留可复现路径配置。

## 4. 只读检查器边界

`scripts/check_keil_paths.py` 使用 Python 标准库解析给定 `.uvprojx/.uvoptx`，检查 FilePath、IncludePath、ScatterFile、PathWithFileName 的字面路径，以及同 target 的重复源码 FilePath。其作用是减少搬目录后的漏改、大小写和重复成员问题。

- 反斜杠按路径分隔符处理；相对路径以 XML 文件目录为基准。
- 宏、Windows 盘符/UNC 在不适配的主机上列为 `manual`，不会伪称已解析。
- 不要求输出目录、map 或新生成的镜像预先存在。
- 不执行命令、不修改项目，也不模拟 Keil 预处理、文件排除条件、链接器、向量表或硬件。
- 同 target 重复源码需结合排除选项核查。检查器保守报告，不能直接据此删文件。
- 文件实际已匹配但大小写不同会报告；Windows 能解析不代表未来环境也能解析。

```bash
python3 <skill-dir>/scripts/check_keil_paths.py path/to/app.uvprojx path/to/app.uvoptx
```

退出码：0 为所检查字面路径通过；2 为发现缺失、大小写、解析或重复成员问题；3 为无上述问题但存在待人工解析的引用。任何输出都不等同于 KEIL_BUILD_PASS 或 BOARD_PASS。
