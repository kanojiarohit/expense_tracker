# Expense Tracker

Offline Flutter expense tracker MVP for Android and iOS.

## Stack

- Flutter SDK `3.38.4` (from lockfile constraint)
- Dart SDK `>=3.10.9 <4.0.0`
- Isar `3.1.0+1` (`isar`, `isar_flutter_libs`, `isar_generator`)
- fl_chart `1.2.0`
- file_picker `10.3.7`
- intl `0.20.2`
- path_provider `2.1.5`
- build_runner `2.4.13`
- Android Gradle `8.14` (wrapper)
- Java target `17` (Android compile options / Kotlin jvmTarget)
- Android NDK `30.0.14904198`

## Features

- Add, edit, delete transactions
- Parent and child categories
- Monthly overview and previous month comparison
- Recent transaction history
- Debt and loan tracking with linked payback transactions
- Theme, currency, amount format, and date format settings

## Run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run
```
