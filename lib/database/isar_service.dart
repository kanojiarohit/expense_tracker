import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../models/app_settings.dart';
import '../models/category.dart';
import '../models/provisional_transaction.dart';
import '../models/transaction.dart';

class IsarService {
  IsarService._();

  static final instance = IsarService._();
  Isar? _isar;

  Future<void> initialize() async {
    if (_isar != null) {
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [
        TransactionModelSchema,
        ProvisionalTransactionSchema,
        CategoryModelSchema,
        AppSettingsModelSchema,
      ],
      directory: directory.path,
      inspector: kDebugMode,
    );
    await _seedDefaults();
  }

  Future<Isar> get database async {
    await initialize();
    return _isar!;
  }

  Future<void> _seedDefaults() async {
    final isar = _isar!;
    final hasSettings = await isar.appSettingsModels.get(1);
    if (hasSettings == null) {
      await isar.writeTxn(() async {
        await isar.appSettingsModels.put(AppSettingsModel.defaults());
      });
    }

    final categoryCount = await isar.categoryModels.count();
    if (categoryCount > 0) {
      await _backfillSystemCategories(isar);
      return;
    }

    final parentIds = <String, int>{};
    await isar.writeTxn(() async {
      for (final seed in seededCategories) {
        final category = CategoryModel()
          ..name = seed.name
          ..type = seed.type
          ..parentCategoryId = seed.parentName == null
              ? null
              : parentIds[seed.parentName]
          ..icon = seed.icon
          ..colorHex = seed.colorHex
          ..isSystem = seed.isSystem
          ..createdAt = DateTime.now();
        final id = await isar.categoryModels.put(category);
        if (seed.parentName == null) {
          parentIds[seed.name] = id;
        }
      }
    });
  }

  Future<void> _backfillSystemCategories(Isar isar) async {
    final existing = await isar.categoryModels.where().findAll();
    final existingKeys = existing
        .map((item) => _categoryKey(name: item.name, type: item.type))
        .toSet();
    final missingSeeds = seededCategories.where(
      (seed) =>
          seed.isSystem &&
          seed.parentName == null &&
          !existingKeys.contains(
            _categoryKey(name: seed.name, type: seed.type),
          ),
    );
    if (missingSeeds.isEmpty) {
      return;
    }
    await isar.writeTxn(() async {
      for (final seed in missingSeeds) {
        final category = CategoryModel()
          ..name = seed.name
          ..type = seed.type
          ..parentCategoryId = null
          ..icon = seed.icon
          ..colorHex = seed.colorHex
          ..isSystem = seed.isSystem
          ..createdAt = DateTime.now();
        await isar.categoryModels.put(category);
      }
    });
  }

  String _categoryKey({required String name, required String type}) {
    return '${type.trim().toLowerCase()}|${name.trim().toLowerCase()}';
  }
}
