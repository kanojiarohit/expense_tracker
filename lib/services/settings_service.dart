import '../database/isar_service.dart';
import '../models/app_settings.dart';

class SettingsService {
  Future<AppSettingsModel> load() async {
    final isar = await IsarService.instance.database;
    return await isar.appSettingsModels.get(1) ?? AppSettingsModel.defaults();
  }

  Future<void> save(AppSettingsModel settings) async {
    final isar = await IsarService.instance.database;
    await isar.writeTxn(() async {
      await isar.appSettingsModels.put(settings);
    });
  }
}
