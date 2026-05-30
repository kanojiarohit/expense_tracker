# Setup

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run
```

## Release build

Do not judge install size from `app-debug.apk`. Debug APKs include debug runtime
assets and are large by design.

For personal Android install, build ABI-split release APKs:

```bash
flutter build apk --release --split-per-abi
du -h build/app/outputs/flutter-apk/*.apk
```

Use `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` for modern
Android phones.

If release build fails with `android:attr/lStar not found`, update Android
`compileSdk` to a modern installed SDK first.

## Notes

- Uses Isar v3 stable.
- Android and iOS only.
- No backend, no auth, no notifications.
- If schema changes, rerun build_runner.
