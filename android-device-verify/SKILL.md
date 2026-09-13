---
name: android-device-verify
description: Use when a built Android APK must be checked against an ADB device, installed with data-preserving signed Release semantics, launched, and sampled for FATAL, ANR, Room, SQLite, and process-liveness evidence. Enforces serial selection, package and certificate checks, manual login or permission gates, and the only physical-device install operation adb install -r.
compatibility: Windows PowerShell 5.1 or PowerShell 7 with Android SDK platform-tools and build-tools.
metadata:
  version: "v0.1.0"
---

# Android Device Verification

**Version: v0.1.0**

Use this after `android-build-release` has produced and verified an APK.

1. Read the project/device SOP and call `scripts/device_preflight.ps1`. Only a clear `device` state is accepted. Multiple devices require an explicit serial; `unauthorized` and `offline` are blockers.
2. Verify the APK package, non-debuggable Release flag, and certificate against the installed package before installation. A mismatch stops before any device mutation.
3. Call `scripts/install_release_safe.ps1`. On a physical device the only mutation is `adb -s SERIAL install -r APK`. Do not uninstall, clear package data, remove databases, clear log buffers, or run instrumentation that can alter app state. Preserve and record `firstInstallTime`.
4. Call `scripts/capture_android_debug.ps1` with a bounded duration. Launch only the declared main activity. Filter evidence for FATAL, ANR, Room/SQLite, and process death without clearing logs.
5. Pause at unlock, login, OTP, Tesla OAuth, virtual-key pairing, or Android permission prompts. List the exact user action and wait. Never type credentials, verification codes, or consent on the user's behalf. After the user resumes, re-check process liveness and the app's displayed state.

Return `DEVICE`, `APK`, `DEBUG`, `MANUAL_GATES`, `SECURITY`, `BLOCKERS`, and `NEXT_STEP`, explicitly distinguishing a local device observation from real provider or production evidence.
