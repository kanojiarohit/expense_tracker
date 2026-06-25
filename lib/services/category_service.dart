import 'package:isar/isar.dart';

import '../database/isar_service.dart';
import '../models/category.dart';
import '../models/transaction.dart';

class CategoryService {
  Future<List<CategoryModel>> fetchByType(String type) async {
    final isar = await IsarService.instance.database;
    final items = await isar.categoryModels
        .filter()
        .typeEqualTo(type)
        .findAll();
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  Future<List<CategoryModel>> fetchAll() async {
    final isar = await IsarService.instance.database;
    final items = await isar.categoryModels.where().anyId().findAll();
    items.sort((a, b) {
      final typeCompare = a.type.compareTo(b.type);
      if (typeCompare != 0) {
        return typeCompare;
      }
      return a.name.compareTo(b.name);
    });
    return items;
  }

  Future<void> save(CategoryModel category) async {
    final isar = await IsarService.instance.database;
    await isar.writeTxn(() async {
      await isar.categoryModels.put(category);
    });
  }

  Future<CategoryModel> findOrCreateSystemCategory({
    required String name,
    required String type,
    required String icon,
    required String colorHex,
  }) async {
    final isar = await IsarService.instance.database;
    final existing = await isar.categoryModels
        .filter()
        .nameEqualTo(name, caseSensitive: false)
        .and()
        .typeEqualTo(type)
        .findFirst();
    if (existing != null) {
      return existing;
    }
    final category = CategoryModel()
      ..name = name
      ..type = type
      ..parentCategoryId = null
      ..icon = icon
      ..colorHex = colorHex
      ..isSystem = true
      ..createdAt = DateTime.now();
    await isar.writeTxn(() async {
      await isar.categoryModels.put(category);
    });
    return category;
  }

  Future<void> delete(CategoryModel category) async {
    final isar = await IsarService.instance.database;
    final categoryUsage = await isar.transactionModels
        .filter()
        .categoryIdEqualTo(category.id)
        .count();
    final subCategoryUsage = await isar.transactionModels
        .filter()
        .subCategoryIdEqualTo(category.id)
        .count();
    final usage = categoryUsage + subCategoryUsage;
    if (usage > 0) {
      throw Exception('Used categories cannot be deleted');
    }
    await isar.writeTxn(() async {
      await isar.categoryModels.delete(category.id);
    });
  }

  Future<CategoryModel?> byId(int? id) async {
    if (id == null) {
      return null;
    }
    final isar = await IsarService.instance.database;
    return isar.categoryModels.get(id);
  }
}
