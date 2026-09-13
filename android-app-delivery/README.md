# Android App Delivery Skill Suite

This suite contains three skills:

- `android-app-delivery` — parent workflow and fixed evidence report.
- `android-build-release` — framework detection, toolchain, tests, APK build and signing checks.
- `android-device-verify` — ADB preflight, data-preserving install, launch and bounded debug capture.

The parent directory owns the canonical scripts. The specialist directories include standalone copies so they can be invoked independently. On Windows, run a script with `pwsh -NoProfile -File` or `powershell -NoProfile -File`; each writes one JSON object and returns a non-zero exit code for `FAIL` or `BLOCKED`.

Example read-only build preparation:

```powershell
pwsh -NoProfile -File .\scripts\detect_android_project.ps1 -ProjectPath E:\project\my-app
pwsh -NoProfile -File .\scripts\check_android_toolchain.ps1 -ProjectPath E:\project\my-app
```

For a physical phone, pass an external signing configuration to the build workflow, verify the certificate, specify the ADB serial, and use the device skill. The device skill never removes the package or clears user data; it pauses for human gates such as unlock, login, OTP, provider consent and system permissions.
