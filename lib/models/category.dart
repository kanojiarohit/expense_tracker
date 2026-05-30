import 'package:isar/isar.dart';

part 'category.g.dart';

@collection
class CategoryModel {
  Id id = Isar.autoIncrement;

  @Index(caseSensitive: false)
  late String name;

  @Index()
  late String type;

  @Index()
  int? parentCategoryId;

  late String icon;
  late String colorHex;
  late bool isSystem;
  late DateTime createdAt;
}
