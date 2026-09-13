# Report schema

The orchestrator prints a human-readable report with these keys in order:

```text
BASELINE
SCOPE
FRAMEWORK
ENVIRONMENT
THEME
TESTS
BUILD
APK
DEVICE
DEBUG
MANUAL_GATES
SECURITY
BLOCKERS
NEXT_STEP
```

Each key has `status` in `PASS | PARTIAL | FAIL | NOT_PERFORMED | BLOCKED` and an evidence object. The evidence object may include repository and commit SHA, tool versions, test totals/skips, APK path/package/version/SHA-256/certificate fingerprint, device serial/install method/firstInstallTime, process/log findings, and manual actions. Omit secrets and sensitive vehicle identifiers. JSON from the scripts is evidence input, not a claim of real business readiness.
