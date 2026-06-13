import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import '../core/constants.dart';

part 'app_settings.g.dart';

@collection
class AppSettingsModel {
  Id id = 1;
  late String currency;
  late String themeMode;
  late String amountFormat;
  late String dateFormat;
  String? exportPath;
  late bool smsImportEnabled;
  late bool appLockEnabled;
  late DateTime createdAt;

  static AppSettingsModel defaults() {
    return AppSettingsModel()
      ..currency = 'INR'
      ..themeMode = SettingValues.themeSystem
      ..amountFormat = SettingValues.indianAmountFormat
      ..dateFormat = SettingValues.dateDdMmYyyy
      ..exportPath = null
      ..smsImportEnabled = false
      ..appLockEnabled = false
      ..createdAt = DateTime.now();
  }
}

extension AppSettingsModelX on AppSettingsModel {
  ThemeMode get themeModeValue {
    switch (themeMode) {
      case SettingValues.themeLight:
        return ThemeMode.light;
      case SettingValues.themeDark:
        return ThemeMode.dark;
      case SettingValues.themeSystem:
      default:
        return ThemeMode.system;
    }
  }
}
