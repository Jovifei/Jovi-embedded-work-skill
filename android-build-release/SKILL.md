---
name: android-build-release
description: Use when an Android project must be identified, checked, tested, linted, built, signed, and verified as an APK. Supports Gradle/Compose, Flutter, and React Native on Windows and returns structured evidence without modifying app data or exposing signing secrets.
compatibility: Windows PowerShell 5.1 or PowerShell 7 with Git and the framework toolchain available or explicitly gated.
metadata:
  version: "v0.1.0"
---

# Android Build and Release

**Version: v0.1.0**

This is the build specialist for `android-app-delivery`. It may also be used alone when no device installation is needed.

1. Read project `AGENTS.md`, Git status, branch, and commit SHA. Preserve uncommitted work; do not `reset`, `clean`, or stash over it.
2. Run `scripts/detect_android_project.ps1 -ProjectPath PATH` and `scripts/check_android_toolchain.ps1`. Stop on `UNSUPPORTED`, `AMBIGUOUS`, or a missing required tool. A system/admin installation is a manual gate; a bounded user-space install may be used only when the environment permits it.
3. Use the detected framework reference:
   - Gradle/Compose: wrapper tasks for unit tests, lint, and assemble; keep project properties and external signing files supplied by the caller.
   - Flutter: `flutter analyze`, `flutter test`, and `flutter build apk`; the Android module supplies the final package and signing.
   - React Native: run the existing package-manager test script when present, then use the `android/gradlew` wrapper for Android tests/lint/assemble.
4. Invoke `scripts/build_android.ps1` with `-Variant Release` for a physical device and `-Variant Debug` for an emulator. Do not add `clean` or destructive flags. A release signing file is accepted only as an external path and is never read into output.
5. Invoke `scripts/verify_apk.ps1` and reject package, certificate, version, debug flag, unsigned, or missing-tool mismatches. Keep APKs and logs in the caller's chosen evidence directory, outside source when possible.

Return `BASELINE`, `FRAMEWORK`, `ENVIRONMENT`, `TESTS`, `BUILD`, `APK`, `SECURITY`, `BLOCKERS`, and `NEXT_STEP`. A successful compile proves build integrity only; it does not prove login, telemetry, provider data, or production readiness.
