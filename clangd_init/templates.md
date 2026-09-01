# clangd_init 模板

按探查结果选取最小片段。占位符必须替换成当前工程的 target、宏、include 和源文件；不要复制其他工程的芯片名或路径。

## `.clangd`

```yaml
Index:
  Background: Build
```

不要在这里重复整套 `-I`/`-D`，也不要关闭诊断。编译参数放在编译数据库或 `compile_flags.txt`。

## `compile_flags.txt`

仅用于单 Target、统一参数的工程，或作为没有数据库时的兜底。每行一个参数，路径必须相对仓库根目录。

```text
--target=arm-none-eabi
-mcpu=<cortex-mX>
-mthumb
-std=c99
-D<CHIP_MACRO>
-I.clangd-support/include
-I<app_inc>
-I<driver_inc>
-I<cmsis_inc>
```

不要提交 Keil 安装目录、用户主目录等本机绝对路径。

## `compile_commands.json`

仅在需要逐文件或多 Target 参数时生成，并且一个数据库只对应一个已选 Target。新生成的条目优先使用 `arguments`：

```json
[
  {
    "directory": "<repo-root>",
    "arguments": ["clang", "--target=arm-none-eabi", "-mcpu=<cortex-mX>", "-mthumb", "-I<inc>", "-c", "<src>/main.c"],
    "file": "<src>/main.c"
  }
]
```

本地数据库必须在 `.gitignore` 中精确忽略：

```gitignore
compile_commands.json
```

## 裸机标准头解析 shim

只在 `clangd --check` 报出特定头文件缺失，且该头不可从当前 ARM 工具链解析时新增。文件放在 `.clangd-support/include/<header>.h`，只声明本工程实际用到的类型、宏和函数。例如厂商头仅需要 `FILE`、`printf`、`fputc` 时：

```c
#ifndef CLANGD_SUPPORT_STDIO_H
#define CLANGD_SUPPORT_STDIO_H

typedef struct clangd_support_file { int handle; } FILE;
int printf(const char *format, ...);
int fputc(int character, FILE *stream);

#endif
```

不要预先堆叠空的 `stdio.h`、`math.h`、`string.h`、`stdlib.h`；每个 shim 都应由实际诊断和实际使用点证明。

## `.vscode/settings.json` 合并片段

对存在的语言块合并，不覆盖其他用户设置。头文件关联为 `c` 时，`[c]` 同时负责 `.c` 与 `.h` 的格式化。

```json
{
  "editor.formatOnSave": true,
  "C_Cpp.intelliSenseEngine": "disabled",
  "[c]": {
    "editor.defaultFormatter": "llvm-vs-code-extensions.vscode-clangd"
  },
  "[cpp]": {
    "editor.defaultFormatter": "llvm-vs-code-extensions.vscode-clangd"
  },
  "files.associations": {
    "*.h": "c"
  }
}
```

不要默认加入 `clangd.arguments`、`--compile-commands-dir`、`--query-driver` 或 `--background-index`；只有 clangd 日志证明自动发现失败时，才针对该问题增加参数。

## `.clang-format`

已有文件即为准，不覆盖。

**文件不存在且用户确认 Jovi / code_zl 规范**时，复制 `code_zl/references/clang-format` 全文（不要用下面的精简片段代替）。要点：

| 规则 | 作用 |
|------|------|
| `ColumnLimit: 0` | `.h` 函数声明 + 行尾 `//` 保持单行，不拆参数 |
| `AlignConsecutiveMacros` + `AlignTrailingComments` | 连续 `#define` 数值列与 `//` 对齐 |
| `BraceWrapping.AfterControlStatement: Always` | `if`/`while`/`for`/`else` 的 `{` 单独换行 |
| `SortIncludes: false` | 不重排 include |

仅当用户明确选择「最小 Allman、不要 Jovi 模板」时，才可用：

```yaml
BasedOnStyle: LLVM
IndentWidth: 4
UseTab: Never
BreakBeforeBraces: Allman
SortIncludes: false
```

先保存一个手工维护 `.c` 和 `.h` 并检查 diff：`.h` 声明不得被拆行；禁止以格式化为目的批量改写仓库。配置后提示 **Reload Window**。

## 诊断对照

| 证据 | 结论 / 动作 |
|---|---|
| `Loaded compilation database from ...compile_commands.json` | 数据库已被 clangd 读取。 |
| `Loaded compilation database from ...compile_flags.txt` | 统一 flags 已被 clangd 读取。 |
| `pp_file_not_found` | 补充实际缺失头的最小 shim 或正确工具链 include。 |
| F12 没有 Location | 先确认点在调用点、当前文件解析无 fatal error，再查编译参数。 |
| F12 首次到公开 `.h` 声明 | C 调用点的正常跳转；等待后台索引后在该声明再次 F12，可到 `.c` 实现。 |
| `textDocument/implementation` 为空 | C 自由函数的正常限制；以 definition 的有效 Location 为准。 |
| 保存产生大面积 diff | 立即停止，不全仓格式化；恢复到只验证单个手工维护文件。 |
