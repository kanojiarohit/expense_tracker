import 'package:isar/isar.dart';

part 'transaction.g.dart';

@collection
class TransactionModel {
  Id id = Isar.autoIncrement;

  late String title;
  late int amountMinor;
  late String note;

  @Index()
  late DateTime transactionDate;

  @Index()
  late int categoryId;

  int? subCategoryId;
  late String paymentMethod;
  late DateTime createdAt;
  late DateTime updatedAt;
  late String transactionType;
  String? debtLoanKind;
  int? parentTransactionId;
  String? partyCsv;
  late bool excludeFromReports;
}
