---
name: prj_zl
description: "Reorganize embedded C firmware (Keil MDK / G32F031 / IAP) into app/driver layers with inc/src split. Use when the user says prj_zl, 工程整理, 目录整理, 应用驱动分离, app driver 分层, Config Include Source 重组, or wants Application/Bootloader restructured to app/inc app/src driver/inc driver/src Project/MDK. Also use when renaming IAP_Application1 to IAP_Application or fixing Keil include paths after a folder move."
---

# Prj_ZL 嵌入式工程目录整理

**Version: V0.1.0**

将 **Application / Bootloader**（及同类固件根目录）从厂商默认的 `Config/`、`Include/`、`Source/` 整理为 **应用层 app** 与 **驱动层 driver** 分离的标准结构。`.c` 放 `src/`，`.h` 放 `inc/`。Keil 工程路径同步更新。

## 版本记录

- **V0.1.0**：首次发布。`app/inc`、`app/src`、`driver/inc`、`driver/src`、`Project/MDK` 标准结构；`git mv` 迁移；Keil IncludePath/FilePath/分组同步；`IAP_Application1` → `IAP_Application`；与 `code_zl` 配对（目录 vs 注释）。

与 `code_zl`（注释整理）配对：`prj_zl` 管目录与工程文件，`code_zl` 管注释。

## 触发条件

- `/prj_zl` 或用户说：**工程整理、目录整理、应用驱动分离、app/driver 分层**
- 用户提供 `Application`、`Bootloader` 或类似路径要求重组
- Keil 工程仍指向旧 `Config/Include`、`Source/` 路径

## 使用方式

```bash
/prj_zl                          # 整理当前仓库 Application + Bootloader
/prj_zl Application Bootloader   # 指定根目录
/prj_zl Application             # 只整理 Application
```

## 目标目录结构（标准模板）

每个固件根目录（如 `Application/`、`Bootloader/`）应变为：

```
<FirmwareRoot>/
├─ app/
│  ├─ inc/      业务公共头、应用参数、运行时接口
│  └─ src/      业务模块、main、ISR 桥接、system_*.c
├─ driver/
│  ├─ inc/      BSP/外设驱动头、板级与设备配置头
│  └─ src/      BSP/外设驱动实现、设备配置实现
└─ Project/
   └─ MDK/      startup_*.s、*.uvprojx、*.uvoptx（编译产物不跟踪）
```

### Application 参考实例（mppt-charger-300w）

```
Application/
├─ app/
│  ├─ inc/   main.h, g32f031_int.h, app_hw_config.h
│  └─ src/   main.c, g32f031_int.c, system_g32f031.c
├─ driver/
│  ├─ inc/   bsp_*.h, g32f031_device_cfg.h
│  └─ src/   bsp_*.c, g32f031_device_cfg.c
└─ Project/MDK/
```

### Bootloader 参考实例

```
Bootloader/
├─ app/
│  ├─ inc/   main.h, g32f031_int.h, boot_flash.h
│  └─ src/   main.c, g32f031_int.c, system_g32f031.c, boot_flash.c
├─ driver/
│  ├─ inc/   g32f031_device_cfg.h, g32f031_usart_cfg.h
│  └─ src/   g32f031_device_cfg.c, g32f031_usart_cfg.c
└─ Project/MDK/
```

## 文件归属规则

| 层级 | 放什么 | 识别特征 |
|------|--------|----------|
| **app/inc** | 应用入口头、ISR 头、应用级硬件参数/常量 | `main.h`、`g32f031_int.h`、`app_hw_config.h`、业务模块对外 `.h` |
| **app/src** | 入口、ISR 实现、CMSIS system、Bootloader 业务逻辑 | `main.c`、`g32f031_int.c`、`system_*.c`、`boot_flash.c` |
| **driver/inc** | BSP 驱动头、`*_device_cfg.h`、`*_usart_cfg.h` 等板级契约 | `bsp_*.h`、`g32f031_device_cfg.h` |
| **driver/src** | BSP 驱动 `.c`、设备/外设配置 `.c` | `bsp_*.c`、`g32f031_device_cfg.c` |
| **Project/MDK** | Keil 工程、startup 汇编 | 已在 `Project/MDK/` 的不动；旧路径的 startup 移入此处 |

**归类原则**：能抽象成「换板子还要改」的进 **driver**；产品逻辑、入口、OTA 状态机进 **app**。拿不准时优先 driver（BSP 边界更清晰）。

**旧目录 → 新目录映射**：

| 旧路径 | 新路径 |
|--------|--------|
| `<Root>/Include/*.h` | `app/inc/`（应用头）或 `driver/inc/`（驱动头，按上表） |
| `<Root>/Source/*.c` | `app/src/` 或 `driver/src/` |
| `<Root>/Config/Include/*.h` | 多为 `driver/inc/`；`app_hw_config.h` → `app/inc/` |
| `<Root>/Config/Source/*.c` | 多为 `driver/src/` |

## 执行流程

### 1. 调研（必做）

1. `Glob` / `git ls-files` 列出目标根目录下所有 `.c/.h/.s` 及 Keil 工程
2. 按「文件归属规则」列清单：**旧路径 → 新路径**
3. 确认 Keil 工程文件路径（常见 `Project/MDK/*.uvprojx`）
4. **禁止**未读清单就批量移动

### 2. 创建目录并 git mv

```bash
# 对每个 <Root>（Application、Bootloader）
mkdir -p <Root>/app/inc <Root>/app/src <Root>/driver/inc <Root>/driver/src
git mv <old> <new>   # 逐个移动，保留历史
```

- 用 **`git mv`**，不要裸 `mv`
- **不修改** `#include "xxx.h"` 内容（裸文件名 + Keil IncludePath 即可）
- 移动后删除空的 `Config/`、`Include/`、`Source/`

### 3. 更新 Keil 工程（每个 .uvprojx + .uvoptx）

**Include 路径**（相对 `Project/MDK/`）：

```
..\..\app\inc;..\..\driver\inc;..\..\..\Libraries\CMSIS\Include;...
```

移除旧项：`..\..\Include`、`..\..\Config\Include`

**源文件 FilePath**：

| 旧 | 新 |
|----|-----|
| `..\..\Source\main.c` | `..\..\app\src\main.c` |
| `..\..\Source\system_*.c` | `..\..\app\src\system_*.c` |
| `..\..\Config\Source\bsp_*.c` | `..\..\driver\src\bsp_*.c` |
| `..\..\Config\Source\g32f031_device_cfg.c` | `..\..\driver\src\g32f031_device_cfg.c` |

**分组 GroupName**：`Config` → `driver`，`Application` → `app`

**`.uvoptx`** 中 `PathWithFileName` 与 `.uvprojx` 保持一致。

### 4. Keil 工程命名规范

| 问题 | 处理 |
|------|------|
| `IAP_Application1` | 改为 **`IAP_Application`**（与 `IAP_Bootloader` 对称；`1` 多为 Keil 重名后缀） |
| 重命名 | `git mv IAP_Application1.uvprojx IAP_Application.uvprojx`，同步 `.uvoptx` |
| OutputName | `<OutputName>IAP_Application</OutputName>` |
| 编译产物 | `IAP_Application.axf` / `.bin`（AfterMake `@L.bin` 自动跟随） |

### 5. .gitignore（若仓库尚未配置）

```
<FirmwareRoot>/Project/MDK/Objects/
<FirmwareRoot>/Project/MDK/Listings/
<FirmwareRoot>/Project/MDK/*.bin
<FirmwareRoot>/Project/MDK/*.hex
<FirmwareRoot>/Project/MDK/*.axf
*.uvguix*
```

Keil **配置**仍跟踪：`*.uvprojx`、`*.uvoptx`、`startup_*.s`

**保存格式（Ctrl+S）**：与 `code_zl` 共用根目录 `.clang-format`，见 `code_zl` 技能 `references/clang-format`。

### 6. 验证

```bash
git status --short
git ls-files <Root>          # 确认新路径已跟踪
git check-ignore -v <Root>/Project/MDK/Objects/...   # 编译产物已忽略
```

在 Keil 中 Rebuild。Grep 确认无残留：`Config/Include`、`Config/Source`、`/Include/`、`/Source/`（工程 XML 与源码路径）

## 约束

- **不修改代码逻辑**，仅移动文件 + 更新工程路径/分组/命名
- **禁止**擅自 `git commit/push`（除非用户明确要求）
- **Libraries/** 厂商库：通常整目录 `.gitignore`，不在 `prj_zl` 移动范围内
- 多 Target / 多工程时，**每个** `.uvprojx`/`.uvoptx` 都要改
- Windows 路径在 Git/Keil XML 中用 `\` 或 `/` 均可，与工程内现有风格一致

## 完成后报告

```markdown
## prj_zl 整理报告

| 根目录 | app/inc | app/src | driver/inc | driver/src |
|--------|---------|---------|------------|------------|
| Application | N | N | N | N |

- Keil 工程：<路径列表>
- 工程重命名：<有/无>
- 待用户在 Keil Rebuild 确认
```

## 常见问题

**Q: 移动后编译找不到头文件？**  
A: 检查 `IncludePath` 是否含 `..\..\app\inc;..\..\driver\inc`，且顺序在 Libraries 之前无硬性要求但路径必须存在。

**Q: 需要改 #include 路径吗？**  
A: 一般不需要。保持 `#include "bsp_adc.h"`，靠 Keil IncludePath 解析。

**Q: startup_*.s 放哪？**  
A: 保持在 `Project/MDK/`，已在工程中引用 `./startup_*.s` 的不移动。

## 延伸阅读

- 详细 Keil XML 字段说明见 [references/keil-paths.md](references/keil-paths.md)
