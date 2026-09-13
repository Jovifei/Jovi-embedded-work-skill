# Flutter

The project root contains `pubspec.yaml`; the Android package is in `android/`. Check `flutter --version` and `flutter doctor -v`, then run:

```text
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Use `--debug` only for an emulator or an explicit caller request. Do not overwrite Android signing configuration. Read the final package and certificate from the APK; a Flutter build without a matching signing certificate is not safe for a physical data-preserving upgrade.
