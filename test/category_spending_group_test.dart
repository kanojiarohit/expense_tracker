import 'package:expense_tracker/core/constants.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/transaction.dart';
import 'package:expense_tracker/services/transaction_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groups parent-only expense total', () {
    final food = _category(id: 1, name: 'Food', type: CategoryTypes.expense);
    final groups = TransactionService().groupSpendingsByCategory([
      _record(category: food, amountMinor: 1200),
      _record(category: food, amountMinor: 300),
    ]);

    expect(groups, hasLength(1));
    expect(groups.first.name, 'Food');
    expect(groups.first.totalMinor, 1500);
    expect(groups.first.children, isEmpty);
  });

  test('parent total includes parent and child transactions', () {
    final food = _category(id: 1, name: 'Food', type: CategoryTypes.expense);
    final groceries = _category(
      id: 2,
      name: 'Groceries',
      type: CategoryTypes.expense,
      parentCategoryId: food.id,
    );
    final groups = TransactionService().groupSpendingsByCategory([
      _record(category: food, amountMinor: 1000),
      _record(category: food, subCategory: groceries, amountMinor: 2500),
    ]);

    expect(groups, hasLength(1));
    expect(groups.first.totalMinor, 3500);
    expect(groups.first.children, hasLength(1));
    expect(groups.first.children.first.name, 'Groceries');
    expect(groups.first.children.first.amountMinor, 2500);
  });

  test('resolves parent when child is stored as main category', () {
    final food = _category(id: 1, name: 'Food', type: CategoryTypes.expense);
    final restaurant = _category(
      id: 2,
      name: 'Restaurant',
      type: CategoryTypes.expense,
      parentCategoryId: food.id,
    );
    final groups = TransactionService().groupSpendingsByCategory(
      [
        _record(category: food, amountMinor: 1000),
        _record(category: restaurant, amountMinor: 2300),
      ],
      categories: [food, restaurant],
    );

    expect(groups, hasLength(1));
    expect(groups.first.name, 'Food');
    expect(groups.first.totalMinor, 3300);
    expect(groups.first.children, hasLength(1));
    expect(groups.first.children.first.name, 'Restaurant');
    expect(groups.first.children.first.amountMinor, 2300);
  });

  test('child rows appear only for child transactions', () {
    final food = _category(id: 1, name: 'Food', type: CategoryTypes.expense);
    final groceries = _category(
      id: 2,
      name: 'Groceries',
      type: CategoryTypes.expense,
      parentCategoryId: food.id,
    );
    final restaurants = _category(
      id: 3,
      name: 'Restaurants',
      type: CategoryTypes.expense,
      parentCategoryId: food.id,
    );
    final groups = TransactionService().groupSpendingsByCategory([
      _record(category: food, amountMinor: 1000),
      _record(category: food, subCategory: groceries, amountMinor: 2500),
    ]);

    expect(groups.first.children.map((item) => item.name), ['Groceries']);
    expect(
      groups.first.children.any((item) => item.name == restaurants.name),
      isFalse,
    );
  });

  test('includes expense and income groups in mixed result', () {
    final food = _category(id: 1, name: 'Food', type: CategoryTypes.expense);
    final salary = _category(id: 4, name: 'Salary', type: CategoryTypes.income);
    final groups = TransactionService().groupSpendingsByCategory([
      _record(category: food, amountMinor: 900),
      _record(
        category: salary,
        amountMinor: 5000,
        transactionType: TransactionTypes.income,
      ),
    ]);

    expect(groups.map((item) => item.type), contains(TransactionTypes.expense));
    expect(groups.map((item) => item.type), contains(TransactionTypes.income));
  });

  test('ignores excluded and debt loan records', () {
    final food = _category(id: 1, name: 'Food', type: CategoryTypes.expense);
    final debt = _category(id: 5, name: 'Debt', type: CategoryTypes.debtLoan);
    final groups = TransactionService().groupSpendingsByCategory([
      _record(category: food, amountMinor: 900),
      _record(category: food, amountMinor: 700, excludeFromReports: true),
      _record(
        category: debt,
        amountMinor: 3000,
        transactionType: TransactionTypes.debtLoan,
        debtLoanKind: DebtLoanKinds.debt,
      ),
    ]);

    expect(groups, hasLength(1));
    expect(groups.first.name, 'Food');
    expect(groups.first.totalMinor, 900);
  });
}

CategoryModel _category({
  required int id,
  required String name,
  required String type,
  int? parentCategoryId,
}) {
  return CategoryModel()
    ..id = id
    ..name = name
    ..type = type
    ..parentCategoryId = parentCategoryId
    ..icon = 'category'
    ..colorHex = '#64748B'
    ..isSystem = false
    ..createdAt = DateTime(2026);
}

TransactionRecord _record({
  required CategoryModel category,
  CategoryModel? subCategory,
  required int amountMinor,
  String transactionType = TransactionTypes.expense,
  bool excludeFromReports = false,
  String? debtLoanKind,
}) {
  final transaction = TransactionModel()
    ..id = amountMinor
    ..title = category.name
    ..amountMinor = amountMinor
    ..note = ''
    ..transactionDate = DateTime(2026, 6, 1)
    ..categoryId = category.id
    ..subCategoryId = subCategory?.id
    ..paymentMethod = 'Cash'
    ..createdAt = DateTime(2026)
    ..updatedAt = DateTime(2026)
    ..transactionType = transactionType
    ..debtLoanKind = debtLoanKind
    ..parentTransactionId = null
    ..partyCsv = null
    ..excludeFromReports = excludeFromReports;
  return TransactionRecord(
    transaction: transaction,
    category: category,
    subCategory: subCategory,
    parentTransaction: null,
  );
}
