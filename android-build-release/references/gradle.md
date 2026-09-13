# Gradle and Compose

Use the repository wrapper (`gradlew.bat`) from the Android root. First inspect available tasks with `tasks --all` only when needed; never use `clean` to solve an unknown failure. Typical checks are:

```text
gradlew.bat :app:testDebugUnitTest :app:testReleaseUnitTest
gradlew.bat :app:lintDebug :app:lintRelease
gradlew.bat :app:assembleDebug :app:assembleDebugAndroidTest
gradlew.bat :app:assembleRelease
```

The real project may require API URL or signing properties. Pass non-secret build properties from the caller and keep keystore/signing property files outside Git. Do not print command lines containing secrets. Discover APKs under `app/build/outputs/apk` and verify them with `aapt2` and `apksigner`.
