import 'package:expense_tracker/core/constants.dart';
import 'package:expense_tracker/models/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults SMS import mode to provisional transactions', () {
    final settings = AppSettingsModel.defaults();

    expect(settings.smsImportModeValue, SettingValues.smsImportProvisional);
  });

  test('falls back to provisional for old or unknown SMS import mode', () {
    final settings = AppSettingsModel.defaults()
      ..transactionsFromSmsMode = 'old-value';

    expect(settings.smsImportModeValue, SettingValues.smsImportProvisional);
  });

  test('defaults app lock timeout to immediate', () {
    final settings = AppSettingsModel.defaults();

    expect(settings.appLockTimeoutModeValue, SettingValues.appLockImmediate);
    expect(settings.appLockTimeout, Duration.zero);
  });

  test('falls back to immediate for old or unknown app lock timeout', () {
    final settings = AppSettingsModel.defaults()..appLockTimeoutMode = 'old';

    expect(settings.appLockTimeoutModeValue, SettingValues.appLockImmediate);
    expect(settings.appLockTimeout, Duration.zero);
  });

  test('maps app lock timeout values to durations', () {
    final oneMinute = AppSettingsModel.defaults()
      ..appLockTimeoutMode = SettingValues.appLockAfter1Minute;
    final thirtyMinutes = AppSettingsModel.defaults()
      ..appLockTimeoutMode = SettingValues.appLockAfter30Minutes;

    expect(oneMinute.appLockTimeout, const Duration(minutes: 1));
    expect(thirtyMinutes.appLockTimeout, const Duration(minutes: 30));
  });

  test('seeds Debit and Credit SMS categories', () {
    expect(
      seededCategories,
      contains(
        isA<SeedCategory>()
            .having((item) => item.name, 'name', 'Debit')
            .having((item) => item.type, 'type', CategoryTypes.expense)
            .having((item) => item.isSystem, 'isSystem', isTrue),
      ),
    );
    expect(
      seededCategories,
      contains(
        isA<SeedCategory>()
            .having((item) => item.name, 'name', 'Credit')
            .having((item) => item.type, 'type', CategoryTypes.income)
            .having((item) => item.isSystem, 'isSystem', isTrue),
      ),
    );
  });
}
