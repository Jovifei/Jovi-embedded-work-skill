---
name: clangd_init
description: >-
  Use when explicitly invoked as /clangd_init to configure or repair clangd
  definition/reference navigation and clangd format-on-save in an embedded C/C++ workspace.
disable-model-invocation: true
---

# clangd_init

**Version: V1.0.0**

为当前工作区建立可验证的 clangd 函数跳转、查找引用和保存格式化。配置必须来自当前工程；不改生产固件逻辑，不全仓格式化。

完成条件：一个跨文件调用点的 `F12` 返回实际定义位置；保存一个手工维护的源文件时，格式遵循已有 `.clang-format`，且没有无关文件被改写。

模板见 [templates.md](templates.md)。

## 原则

- F12 依赖的是该源文件的真实编译参数（`-I`、`-D`、target），不是仅靠文件名索引。
- `compile_commands.json`、`compile_flags.txt` 都可用；前者适合逐文件或多 Target 参数，后者适合单 Target 的统一兜底。两者可以共存，但不得无条件生成两份。
- `clangd --check` 证明解析；真实 `textDocument/definition` 或 Cursor 在**调用点**的 F12 返回 Location，才证明跳转。
- `.clang-format` 是格式规则的唯一来源；没有它时先问用户风格，不要把 Allman、缩进宽度或 Tab 策略强加给已有工程。

## 执行流程

### 1. 只读探查

1. 保留脏工作区，查找 `*.uvprojx`、`.clangd`、`compile_flags.txt`、`compile_commands.json`、`.clang-format`、`.vscode/settings.json` 与已有生成脚本。
2. 找一个跨文件调用点和定义点，作为最终 F12 验收样例。
3. 解析 clangd：先 PATH，再查 Cursor 的 `User/globalStorage/llvm-vs-code-extensions.vscode-clangd/install/*/clangd_*/bin/clangd.exe`。两者都没有时，提示用户在 Cursor 执行 `clangd: Download language server`；不得自动下载。
4. 检查 Cursor 已启用 `llvm-vs-code-extensions.vscode-clangd`。Microsoft C/C++ 的 IntelliSense 必须关闭或禁用，避免双语言服务竞争。

### 2. 选择最小编译配置

| 当前状态 | 操作 |
|---|---|
| 已有可用 `compile_commands.json` | 先用 clangd 检查它；不重写。 |
| 单 Target、所有源文件共享参数 | 使用或补全根目录 `compile_flags.txt`。 |
| 多 Target、文件级参数不同，或统一 flags 解析失败 | 从**用户指定的一个 Target**生成本地 `compile_commands.json`。 |

- 不清楚活动 Target 时先询问；禁止把 AP、IAP 或不同芯片 Target 的宏、源文件、include 混进同一数据库。
- 新生成的数据库使用 `arguments` 数组，首项写 `clang`，不要把 `armclang.exe` 伪装成 clangd 的 compiler。
- `compile_commands.json` 只作本地生成物并精确写入 `.gitignore`；不得把用户目录、Keil 安装目录等绝对路径写入受版本控制的 `compile_flags.txt`。
- `.clangd` 保持最小：只配置 `Index.Background: Build`。不要用关闭诊断来伪造“解析成功”。
- `--check` 明确报缺裸机标准头时，才在 `.clangd-support/include/` 新增**该头文件的最小解析 shim**，并加入仓库内 `-I` 路径。shim 只能服务 clangd；不得删改生产源中的 include、保护或驱动逻辑。

### 3. 配置保存格式化

1. 已有 `.clang-format` 时保留并使用；仅当用户要求且文件不存在时才新建。
2. 在 `.vscode/settings.json` 启用 `editor.formatOnSave`，并只为工程实际使用的 `[c]`、`[cpp]` 设置 `llvm-vs-code-extensions.vscode-clangd` 为默认 formatter。
3. 若 `*.h` 关联为 `c`，格式化器配置应落在 `[c]`；单独的 `[h]` 块不会生效。
4. 不执行 `clang-format -i` 全仓库；vendor、生成文件和构建输出不参与格式化。先在一个手工维护文件上保存验证并查看 diff。

### 4. 验证

1. 用实际 clangd 执行 `--check=<手工维护的 .c>`；日志必须显示加载了 `compile_commands.json` **或** `compile_flags.txt`。若缺头文件，先修复该解析 shim，再复查。
2. 重启 Cursor：`Clangd: Restart language server`，等待后台索引完成。
3. 在第 1 步记录的跨文件**调用点**按 F12。实际 Location 才通过；C 调用点首次到 `driver/inc/*.h` 的公开声明是正常结果，等后台索引后在该声明再次 F12 可定位 `.c` 实现。点在定义行、本文件 `static` 定义行或收到空结果都不算；C 自由函数的 `textDocument/implementation` 可能为空，不能单独判失败。
4. 保存一份有微小空白调整的手工维护 `.c/.cpp/.h`，确认只产生预期格式 diff，并遵循 `.clang-format`。

## 禁止事项

- 不提交 `compile_commands.json`、clangd 缓存或用户机器绝对路径。
- 不为消除诊断而修改 PWM、看门狗、保护、驱动或其他生产逻辑。
- 不覆盖用户已有 `.clang-format`、`.vscode/settings.json`、生成器或未提交配置；在最小范围内合并。
- 不以 `--check` 成功、扩展已安装或索引进度完成替代真实 F12/LSP 验收。

## 回复用户时必须说明

1. clangd 实际读取的是哪个编译配置文件；
2. 跨文件 F12 的调用点与返回位置；
3. 保存格式化使用的 `.clang-format`，以及本次格式化的文件；
4. 仍未解析的头文件或需要用户选择的 Target；
5. `compile_commands.json` 未提交、未推送。
