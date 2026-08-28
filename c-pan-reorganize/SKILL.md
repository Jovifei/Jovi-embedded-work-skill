---
name: c-pan-reorganize
description: "Audit and safely reorganize C drive app data by moving eligible user data to D drive, cleaning exact update packages and safe caches, without uninstalling software or deleting protected state."
---

# C Pan Reorganize

Use this skill for C drive space audits, application-data migration to D drive, update-package cleanup, or safe cache cleanup on this Windows machine.

## Outcome and permission boundary

- Keep application executables and user data on the intended drive without breaking applications.
- Treat **deleting update packages or caches** as distinct from **uninstalling software**. Never uninstall, reinstall, or remove an uninstall entry unless the user gives fresh, explicit authorization for that software.
- Start with a read-only audit. Do not delete, move, or junction broad paths such as a whole user profile, all of AppData, `C:\Windows`, or a whole vendor directory.
- Preserve current conversations, credentials, settings, project/workspace data, and source files unless the user names the exact retention/deletion policy.

## D drive data location

Before migrating, resolve the established D drive document root:

1. Inspect `D:\Document` and `D:\Documents`.
2. Use an existing root. If both exist, prefer the one already holding the application's data; on this machine, `D:\Document` is the established root.
3. Create one application-specific child directory only when the user authorized that application's migration and the intended target is absent or empty. Do not overwrite a non-empty target.

Use a direct child per application, for example:

```text
D:\Document\WeChatData
D:\Document\Feishu
D:\Document\DingTalk
D:\Document\TencentMeeting
D:\Document\QQ
```

## Safe migration workflow

For an eligible application-data directory:

1. Identify the application's main processes and exact data paths. Do not infer from an install directory.
2. Ask the user to save and exit an application if it is running; do not force-close it merely to move data unless the user explicitly authorizes the closure.
3. Measure the source file count and bytes; reject sources or targets that are reparse points. Inspect any existing target before doing anything.
4. Move the exact source directory to its dedicated D drive target, then create a Windows junction at the original C drive path pointing to that target.
5. Verify the junction target, destination file count/bytes, app process state, and C/D free space. Report that the C path remains visible as a junction, not as a duplicate copy.

Do not use a junction for a product's known in-app storage relocation feature when the product can move its own files safely.

## Established mappings on this machine

These are current, useful mappings. Re-audit before changing them because products may update their storage layout.

| Product | Program/data result | Boundary |
|---|---|---|
| WeChat | Program: `D:\Program Files\Tencent\Weixin`; active files: `D:\Document\WeChatData\xwechat_files` | Use WeChat's own File Management path change. Do not manually move `C:\Users\zhuxi\AppData\Roaming\Tencent\xwechat` while WeChat runs. |
| Cursor | Program: `D:\Programs\cursor`; extensions: `D:\Programs\cursor-data\extensions` through `C:\Users\zhuxi\.cursor\extensions` junction | Preserve `%APPDATA%\Cursor\User\globalStorage\state.vscdb`, `settings.json`, `keybindings.json`, and user projects/plans unless explicitly scoped. |
| Feishu | `%APPDATA%\LarkShell` -> `D:\Document\Feishu` | Junction migration verified. |
| DingTalk | `%APPDATA%\DingTalk` -> `D:\Document\DingTalk` | Junction migration verified. |
| Tencent Meeting residuals | `%APPDATA%\Tencent\WeMeet` -> `D:\Document\TencentMeeting` | Junction migration verified; application may be uninstalled. |
| QQ | `%APPDATA%\Tencent\QQ` -> `D:\Document\QQ\RoamingQQ`; `%LOCALAPPDATA%\Tencent\QQGuild` -> `D:\Document\QQ\QQGuild`; `Documents\Tencent Files` -> `D:\Document\QQ\Tencent Files` | Program is already on D. Keep existing `D:\Document\QQ\<account>` data intact. |

## Update packages: delete only exact packages

- Re-audit process ownership and package filenames before deletion.
- Typical Cursor update packages are `%LOCALAPPDATA%\Temp\vscode-stable-user-x64-*` containing `CodeSetup-stable-3.*.exe`.
- A package containing a VS Code build hash, such as `CodeSetup-stable-<hash>.exe`, may belong to VS Code. Delete it only after confirming VS Code is not active and the user authorized update-package cleanup.
- WorkBuddy update packages may be under `%LOCALAPPDATA%\Temp\workbuddy-update-x64`; remove only the exact updater directory after WorkBuddy exits.
- Never interpret an update package request as permission to uninstall the associated program.

## Safe cache cleanup

Audit the exact directory, active owner, size, and retention requirement first.

- **uv:** only run the official `uv cache clean` after all `uv.exe`, `uvx.exe`, and Python `code-review-graph serve` processes are gone. Never delete `archive-v0` or `.lock` manually while active.
- **npm:** use `npm cache clean --force` only when no npm operation is running; preferably close Node-based editors/tools first.
- **Cursor:** after Cursor exits, rebuildable `Cache`, `CachedData`, `CachedExtensionVSIXs`, GPU/Dawn caches, and `logs` may be removed. Do not remove `state.vscdb`, its current WAL, `conversation-search.db`, or workspace/project state unless the user explicitly scopes chat retention.
- **WorkBuddy:** after exit, `logs` and `traces` are candidates. Preserve `workspace`, `projects`, sessions, data, and user artifacts.
- **Claude:** after exit, delete only files older than the user-specified retention period from `projects` and `file-history`. Preserve config, skills, authentication, and recent history.
- **WeChat/Feishu/DingTalk:** do not clear active runtime directories. Application logs or old update files require separate, exact review after the application exits.

## Protected system and application state

Never manually delete `pagefile.sys`, `hiberfil.sys`, `C:\$WinREAgent`, Windows recovery/update state, or live browser/editor databases. Pagefile/hibernation changes are system-setting decisions and require explicit authorization.

## Reporting

For every audit or change, report:

- C and D free space before/after when a move or deletion occurred.
- Exact source, target, bytes, file count, and junction target for a migration.
- Exact deleted package/cache paths and whether data is recoverable.
- Protected items and the remaining blocker when a process owns a cache.
