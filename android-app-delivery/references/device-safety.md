# Device safety

- Physical devices require a signed, non-debuggable Release whose package and certificate match the installed app.
- Use an explicit serial when more than one ADB target exists.
- The only physical install operation is `adb -s SERIAL install -r APK`.
- Never run `adb uninstall`, `pm clear`, database deletion, DataStore deletion, `logcat -c`, or destructive instrumentation.
- Record installed version, `firstInstallTime`, package data directory, process ID, and bounded log findings before and after install.
- Unlocking, logging in, OTP, Tesla consent, virtual-key pairing, and system permission prompts are human gates. Stop and state the action; do not enter secrets.
- Debug, emulator, mock, and local-provider evidence must not be reported as physical production or real-vehicle acceptance.
