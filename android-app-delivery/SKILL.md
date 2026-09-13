---
name: android-app-delivery
description: Use when Jovi asks to make, adapt, compile, sign, install, or debug an Android app from a theme and project path. Orchestrates safe Windows delivery for Gradle or Compose, Flutter, and React Native projects, including toolchain checks, tests, APK verification, data-preserving device installation, bounded log capture, manual login and permission gates, and a structured evidence report. Never treats a build, mock, HTTP 200, or emulator result as real business acceptance.
compatibility: Windows PowerShell 5.1 or PowerShell 7, Git, Android SDK platform-tools and build-tools when Android delivery is requested. JDK 17 is the supported baseline; Flutter and Node/npm are required only for those frameworks.
metadata:
  version: "v0.1.0"
  supported_frameworks: "Gradle/Compose, Flutter, React Native"
  platform: "Windows"
---

# Android App Delivery

**Version: v0.1.0**

首次发布：跨框架 Android 构建、签名、保留数据安装、设备调试与人工门禁总控。

Use this as the parent workflow. The input is a real project directory and a short theme brief. A theme brief changes an existing project only after the user has authorized code edits; it does not authorize guessing a package name, framework, signing identity, or credentials.

## Run order

1. Resolve the project path and read its `AGENTS.md` files from the project root upward. Record repository, branch, commit SHA, and `git status --short`. Do not reset, clean, stash, or overwrite user changes. If the worktree is dirty, prefer an isolated worktree for edits and builds, while preserving the original path.
2. Run `scripts/detect_android_project.ps1`. If it returns `UNSUPPORTED`, `AMBIGUOUS`, or an empty project, stop with `BLOCKED` and request the missing framework/package/signing inputs. The detector supports Gradle/Compose, Flutter, and React Native; it does not infer a new app from a theme alone.
3. Run `scripts/check_android_toolchain.ps1`. Reuse installed tools. A user-space installation may be proposed or performed only when it is safe and does not require administrator access; system-level or administrator installation is a manual gate. Never print secrets, keystore passwords, tokens, or private keys.
4. Apply the theme to the existing project with the smallest authorized code change. Keep the package `com.matelink` and existing signing/data contracts when they are part of the project. If the user asked only for delivery, do not invent a product change.
5. Run the framework checks described in the relevant reference and call `scripts/build_android.ps1`. Test and lint failures are blockers. Do not call `clean` as a workaround. For a physical device build a signed `Release`; for an emulator build `Debug` unless the user explicitly requests otherwise. A signing properties file must be outside the repository and is passed by path only.
6. Call `scripts/verify_apk.ps1`. Check package name, version code/name, `debuggable`, certificate fingerprint, and SHA-256. A physical-device release is blocked if the package or certificate cannot be matched.
7. Call `scripts/device_preflight.ps1`. Require a single explicit `device` state, or require `-Serial` when more than one device is present. Reject `unauthorized`, `offline`, or unknown states. Check the installed package metadata before changing anything.
8. For a physical device call `scripts/install_release_safe.ps1`. The only install operation is `adb -s SERIAL install -r APK`; never use `uninstall`, `pm clear`, data deletion, or destructive instrumentation. Preserve `firstInstallTime`, Room, DataStore, and other app data. For an emulator, use the same preflight and an explicit Debug policy.
9. Call `scripts/capture_android_debug.ps1` for a bounded launch/log sample. Do not clear the log buffer. Capture only process liveness and FATAL, ANR, Room, and SQLite signals. If the app reaches unlock, login, OTP, Tesla authorization, virtual-key pairing, or a system permission, pause and print a `MANUAL_GATES` checklist. Do not enter credentials or codes.
10. Resume only after the user reports that each manual gate is complete. Verify the app state and record what is actually observed. Separate source, JVM, emulator, physical-device, provider, and production evidence.

## Fixed report

Return these sections in this order, each with `PASS`, `PARTIAL`, `FAIL`, `NOT_PERFORMED`, or `BLOCKED`: `BASELINE`, `SCOPE`, `FRAMEWORK`, `ENVIRONMENT`, `THEME`, `TESTS`, `BUILD`, `APK`, `DEVICE`, `DEBUG`, `MANUAL_GATES`, `SECURITY`, `BLOCKERS`, `NEXT_STEP`.

Include repository/commit SHA, tool versions, test totals and skips, APK path/package/version/SHA-256/certificate fingerprint, device serial/install method/`firstInstallTime`, FATAL/ANR result, and remaining manual actions. Never include VINs, exact locations, tokens, passwords, AppSecrets, private keys, or keystore passwords.

## Script entry points

All scripts emit one JSON object to stdout and use a non-zero exit code for a failed or blocked check:

- `scripts/detect_android_project.ps1`
- `scripts/check_android_toolchain.ps1`
- `scripts/build_android.ps1`
- `scripts/verify_apk.ps1`
- `scripts/device_preflight.ps1`
- `scripts/install_release_safe.ps1`
- `scripts/capture_android_debug.ps1`

The build and device specialist skills below use these same entry points. Read only the reference needed for the detected framework or device policy.

## Safety boundary

This skill delivers a local APK. It does not deploy production services, apply for platform accounts, complete Tesla OAuth, accept Tesla permissions, pair a virtual key, or claim that telemetry/history is real. Those are explicit user/provider gates. It also does not silently change a dirty worktree or replace a user-owned app installation.
