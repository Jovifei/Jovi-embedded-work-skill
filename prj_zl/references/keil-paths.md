# Keil MDK 路径更新参考（prj_zl）

## IncludePath 模板

相对 `Application/Project/MDK/` 或 `Bootloader/Project/MDK/`：

```xml
<IncludePath>..\..\app\inc;..\..\driver\inc;..\..\..\Libraries\CMSIS\Include;..\..\..\Libraries\G32F031_DAL_Driver\Include;..\..\..\Libraries\Device\Geehy\G32F031\Include</IncludePath>
```

Bootloader 若库路径层级不同，保持原有 Libraries 段，只替换 app/driver 段。

## uvprojx 源文件条目示例

```xml
<GroupName>CMSIS</GroupName>
  <FilePath>..\..\app\src\system_g32f031.c</FilePath>
  <FilePath>.\startup_g32f031.s</FilePath>

<GroupName>driver</GroupName>
  <FilePath>..\..\driver\src\g32f031_device_cfg.c</FilePath>
  <FilePath>..\..\driver\src\bsp_adc.c</FilePath>

<GroupName>app</GroupName>
  <FilePath>..\..\app\src\main.c</FilePath>
  <FilePath>..\..\app\src\g32f031_int.c</FilePath>
```

## uvoptx 对应字段

```xml
<PathWithFileName>..\..\app\src\main.c</PathWithFileName>
<FilenameWithoutPath>main.c</FilenameWithoutPath>
```

`FilenameWithoutPath` 通常不变，只改 `PathWithFileName`。

## OutputName 与 AfterMake

```xml
<OutputName>IAP_Application</OutputName>
<UserProg1Name>fromelf.exe --bin -o ./@L.bin !L</UserProg1Name>
```

`@L` 展开为 OutputName，重命名 OutputName 后 bin 文件名自动变化。

## 检查命令

```bash
rg "Config\\\\|Include\\\\|Source\\\\" --glob "*.uvprojx" --glob "*.uvoptx"
rg "IAP_Application1" .
```
