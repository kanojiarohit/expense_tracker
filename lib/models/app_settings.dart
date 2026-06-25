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
  String? transactionsFromSmsMode;
  String? appLockTimeoutMode;

  static AppSettingsModel defaults() {
    return AppSettingsModel()
      ..currency = 'INR'
      ..themeMode = SettingValues.themeSystem
      ..amountFormat = SettingValues.indianAmountFormat
      ..dateFormat = SettingValues.dateDdMmYyyy
      ..exportPath = null
      ..smsImportEnabled = false
      ..appLockEnabled = false
      ..createdAt = DateTime.now()
      ..transactionsFromSmsMode = SettingValues.smsImportProvisional
      ..appLockTimeoutMode = SettingValues.appLockImmediate;
  }
}

extension AppSettingsModelX on AppSettingsModel {
  String get appLockTimeoutModeValue {
    switch (appLockTimeoutMode) {
      case SettingValues.appLockAfter1Minute:
        return SettingValues.appLockAfter1Minute;
      case SettingValues.appLockAfter30Minutes:
        return SettingValues.appLockAfter30Minutes;
      case SettingValues.appLockImmediate:
      default:
        return SettingValues.appLockImmediate;
    }
  }

  Duration get appLockTimeout {
    switch (appLockTimeoutModeValue) {
      case SettingValues.appLockAfter1Minute:
        return const Duration(minutes: 1);
      case SettingValues.appLockAfter30Minutes:
        return const Duration(minutes: 30);
      case SettingValues.appLockImmediate:
      default:
        return Duration.zero;
    }
  }

  String get smsImportModeValue {
    switch (transactionsFromSmsMode) {
      case SettingValues.smsImportMainTransaction:
        return SettingValues.smsImportMainTransaction;
      case SettingValues.smsImportProvisional:
      default:
        return SettingValues.smsImportProvisional;
    }
  }

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
