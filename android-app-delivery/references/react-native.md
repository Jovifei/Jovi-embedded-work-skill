# React Native

The project root contains `package.json` and `android/`. Detect the package manager from the lockfile (`npm`, `yarn`, or `pnpm`) and run the existing test script when present. Do not invent a test command when none is declared. Use `android/gradlew.bat` for Android lint, JVM tests, and APK assembly. The JavaScript bundle and native APK are separate checks; both must be reported. Keep `node_modules` and build output out of the evidence summary.
