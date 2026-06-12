import 'package:isar/isar.dart';

import '../core/constants.dart';
import '../core/formatters.dart';
import '../database/isar_service.dart';
import '../models/category.dart';
import '../models/transaction.dart';

class TransactionRecord {
  TransactionRecord({
    required this.transaction,
    required this.category,
    required this.subCategory,
    required this.parentTransaction,
  });

  final TransactionModel transaction;
  final CategoryModel? category;
  final CategoryModel? subCategory;
  final TransactionModel? parentTransaction;
}

class DayTransactionGroup {
  DayTransactionGroup({
    required this.date,
    required this.records,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final DateTime date;
  final List<TransactionRecord> records;
  final int incomeMinor;
  final int expenseMinor;
}

class CategorySpendingChild {
  CategorySpendingChild({
    required this.category,
    required this.name,
    required this.type,
    required this.amountMinor,
  });

  final CategoryModel? category;
  final String name;
  final String type;
  final int amountMinor;
}

class CategorySpendingGroup {
  CategorySpendingGroup({
    required this.parentCategory,
    required this.name,
    required this.type,
    required this.totalMinor,
    required this.children,
  });

  final CategoryModel? parentCategory;
  final String name;
  final String type;
  final int totalMinor;
  final List<CategorySpendingChild> children;
}

class DebtLoanSummary {
  DebtLoanSummary({
    required this.principal,
    required this.linkedRecords,
    required this.paidMinor,
    required this.balanceMinor,
  });

  final TransactionRecord principal;
  final List<TransactionRecord> linkedRecords;
  final int paidMinor;
  final int balanceMinor;

  bool get isClosed => balanceMinor <= 0;
}

class TransactionService {
  Future<List<TransactionRecord>> fetchAllRecords() async {
    final isar = await IsarService.instance.database;
    final transactions = await isar.transactionModels
        .where()
        .sortByTransactionDateDesc()
        .findAll();
    return _joinTransactions(isar, transactions);
  }

  Future<List<TransactionRecord>> fetchRecent({int limit = 5}) async {
    final records = await fetchAllRecords();
    return records.take(limit).toList();
  }

  Future<List<TransactionRecord>> fetchMonthRecords(DateTime month) async {
    final isar = await IsarService.instance.database;
    final from = startOfMonth(month);
    final to = endOfMonth(month);
    final transactions = await isar.transactionModels
        .filter()
        .transactionDateBetween(from, to)
        .sortByTransactionDateDesc()
        .findAll();
    return _joinTransactions(isar, transactions);
  }

  Future<List<TransactionRecord>> fetchRecordsBetween(
    DateTime fromMonth,
    DateTime toMonth,
  ) async {
    final isar = await IsarService.instance.database;
    final from = startOfMonth(fromMonth);
    final to = endOfMonth(toMonth);
    final transactions = await isar.transactionModels
        .filter()
        .transactionDateBetween(from, to)
        .sortByTransactionDateDesc()
        .findAll();
    return _joinTransactions(isar, transactions);
  }

  Future<List<TransactionRecord>> fetchDebtLoanRecords() async {
    final isar = await IsarService.instance.database;
    final transactions = await isar.transactionModels
        .filter()
        .transactionTypeEqualTo(TransactionTypes.debtLoan)
        .sortByTransactionDateDesc()
        .findAll();
    return _joinTransactions(isar, transactions);
  }

  Future<int> cashBalanceForMonth(DateTime month) async {
    final records = await fetchMonthRecords(month);
    return records.fold<int>(
      0,
      (sum, item) => sum + signedAmount(item.transaction),
    );
  }

  List<DayTransactionGroup> groupByDay(List<TransactionRecord> records) {
    final map = <String, List<TransactionRecord>>{};
    for (final record in records) {
      final key =
          '${record.transaction.transactionDate.year}-${record.transaction.transactionDate.month}-${record.transaction.transactionDate.day}';
      map.putIfAbsent(key, () => []).add(record);
    }
    final groups = map.values.map((items) {
      final date = items.first.transaction.transactionDate;
      int income = 0;
      int expense = 0;
      for (final item in items) {
        final amount = signedAmount(item.transaction);
        if (amount >= 0) {
          income += amount;
        } else {
          expense += amount.abs();
        }
      }
      items.sort(
        (a, b) => b.transaction.transactionDate.compareTo(
          a.transaction.transactionDate,
        ),
      );
      return DayTransactionGroup(
        date: date,
        records: items,
        incomeMinor: income,
        expenseMinor: expense,
      );
    }).toList();
    groups.sort((a, b) => b.date.compareTo(a.date));
    return groups;
  }

  List<CategorySpendingGroup> groupSpendingsByCategory(
    List<TransactionRecord> records, {
    List<CategoryModel> categories = const [],
  }) {
    final categoryById = <int, CategoryModel>{
      for (final category in categories) category.id: category,
    };
    for (final record in records) {
      final category = record.category;
      final subCategory = record.subCategory;
      if (category != null) {
        categoryById[category.id] = category;
      }
      if (subCategory != null) {
        categoryById[subCategory.id] = subCategory;
      }
    }

    final groupMap = <String, _MutableCategorySpendingGroup>{};
    for (final record in records) {
      final transaction = record.transaction;
      if (transaction.excludeFromReports ||
          (transaction.transactionType != TransactionTypes.expense &&
              transaction.transactionType != TransactionTypes.income)) {
        continue;
      }

      final category = record.category;
      final subCategory = record.subCategory;
      final type = transaction.transactionType;
      final childCategory = subCategory ?? _childCategoryFrom(category);
      final resolvedParent = _parentCategoryFor(
        category: category,
        subCategory: subCategory,
        categoryById: categoryById,
      );
      final parentName = resolvedParent?.name ?? 'Other';
      final parentKey = '${resolvedParent?.id ?? 'other'}-$type';
      final group = groupMap.putIfAbsent(
        parentKey,
        () => _MutableCategorySpendingGroup(
          parentCategory: resolvedParent,
          name: parentName,
          type: type,
        ),
      );
      group.totalMinor += transaction.amountMinor;

      if (childCategory == null) {
        continue;
      }
      final childKey = '${childCategory.id}-$type';
      final child = group.children.putIfAbsent(
        childKey,
        () => CategorySpendingChild(
          category: childCategory,
          name: childCategory.name,
          type: type,
          amountMinor: 0,
        ),
      );
      group.children[childKey] = CategorySpendingChild(
        category: child.category,
        name: child.name,
        type: child.type,
        amountMinor: child.amountMinor + transaction.amountMinor,
      );
    }

    final groups = groupMap.values
        .map(
          (group) => CategorySpendingGroup(
            parentCategory: group.parentCategory,
            name: group.name,
            type: group.type,
            totalMinor: group.totalMinor,
            children: group.sortedChildren,
          ),
        )
        .toList();
    groups.sort((a, b) {
      final amountCompare = b.totalMinor.compareTo(a.totalMinor);
      if (amountCompare != 0) {
        return amountCompare;
      }
      return a.name.compareTo(b.name);
    });
    return groups;
  }

  CategoryModel? _childCategoryFrom(CategoryModel? category) {
    if (category?.parentCategoryId == null) {
      return null;
    }
    return category;
  }

  CategoryModel? _parentCategoryFor({
    required CategoryModel? category,
    required CategoryModel? subCategory,
    required Map<int, CategoryModel> categoryById,
  }) {
    final childParentId = subCategory?.parentCategoryId;
    if (childParentId != null) {
      return categoryById[childParentId] ?? category;
    }
    final categoryParentId = category?.parentCategoryId;
    if (categoryParentId != null) {
      return categoryById[categoryParentId] ?? category;
    }
    return category;
  }

  Future<void> save(TransactionModel transaction) async {
    final isar = await IsarService.instance.database;
    if (_isPayback(transaction)) {
      if (transaction.parentTransactionId == null) {
        throw Exception('Select original debt or loan');
      }
      final remaining = await remainingBalance(
        transaction.parentTransactionId!,
        ignoreTransactionId: transaction.id == Isar.autoIncrement
            ? null
            : transaction.id,
      );
      if (transaction.amountMinor > remaining) {
        throw Exception('Payback amount cannot exceed balance');
      }
    }
    transaction.updatedAt = DateTime.now();
    if (transaction.createdAt == DateTime.fromMillisecondsSinceEpoch(0)) {
      transaction.createdAt = DateTime.now();
    }
    await isar.writeTxn(() async {
      await isar.transactionModels.put(transaction);
    });
  }

  Future<void> delete(TransactionModel transaction) async {
    final isar = await IsarService.instance.database;
    final linkedCount = await isar.transactionModels
        .filter()
        .parentTransactionIdEqualTo(transaction.id)
        .count();
    if (linkedCount > 0) {
      throw Exception('Delete payback transactions first');
    }
    await isar.writeTxn(() async {
      await isar.transactionModels.delete(transaction.id);
    });
  }

  Future<List<TransactionRecord>> fetchAvailableParents(
    String debtLoanKind, {
    int? ignoreTransactionId,
  }) async {
    final isar = await IsarService.instance.database;
    final requiredKind = debtLoanKind == DebtLoanKinds.debtCollection
        ? DebtLoanKinds.loan
        : DebtLoanKinds.debt;
    final principals = await isar.transactionModels
        .filter()
        .transactionTypeEqualTo(TransactionTypes.debtLoan)
        .and()
        .debtLoanKindEqualTo(requiredKind)
        .sortByTransactionDateDesc()
        .findAll();
    final records = await _joinTransactions(isar, principals);
    final available = <TransactionRecord>[];
    for (final record in records) {
      final remaining = await remainingBalance(
        record.transaction.id,
        ignoreTransactionId: ignoreTransactionId,
      );
      if (remaining > 0) {
        available.add(record);
      }
    }
    return available;
  }

  Future<List<TransactionRecord>> fetchLinkedRecords(
    int parentTransactionId,
  ) async {
    final isar = await IsarService.instance.database;
    final transactions = await isar.transactionModels
        .filter()
        .parentTransactionIdEqualTo(parentTransactionId)
        .sortByTransactionDateDesc()
        .findAll();
    return _joinTransactions(isar, transactions);
  }

  Future<List<DebtLoanSummary>> fetchDebtLoanSummaries(String kind) async {
    final isar = await IsarService.instance.database;
    final principals = await isar.transactionModels
        .filter()
        .transactionTypeEqualTo(TransactionTypes.debtLoan)
        .and()
        .debtLoanKindEqualTo(kind)
        .sortByTransactionDateDesc()
        .findAll();
    final records = await _joinTransactions(isar, principals);
    final summaries = <DebtLoanSummary>[];
    for (final principal in records) {
      final linked = await fetchLinkedRecords(principal.transaction.id);
      final paidMinor = linked.fold<int>(
        0,
        (sum, item) => sum + item.transaction.amountMinor,
      );
      summaries.add(
        DebtLoanSummary(
          principal: principal,
          linkedRecords: linked,
          paidMinor: paidMinor,
          balanceMinor: principal.transaction.amountMinor - paidMinor,
        ),
      );
    }
    return summaries;
  }

  Future<int> remainingBalance(
    int parentTransactionId, {
    int? ignoreTransactionId,
  }) async {
    final isar = await IsarService.instance.database;
    final parent = await isar.transactionModels.get(parentTransactionId);
    if (parent == null) {
      return 0;
    }
    final linked = await isar.transactionModels
        .filter()
        .parentTransactionIdEqualTo(parentTransactionId)
        .findAll();
    final filtered = linked.where((item) => item.id != ignoreTransactionId);
    final paid = filtered.fold<int>(0, (sum, item) => sum + item.amountMinor);
    return parent.amountMinor - paid;
  }

  Future<List<TransactionRecord>> _joinTransactions(
    Isar isar,
    List<TransactionModel> transactions,
  ) async {
    final categories = await isar.categoryModels.where().findAll();
    final categoryMap = {for (final item in categories) item.id: item};
    final parentIds = transactions
        .map((item) => item.parentTransactionId)
        .whereType<int>()
        .toSet();
    final parentMap = <int, TransactionModel>{
      for (final item in transactions) item.id: item,
    };
    for (final parentId in parentIds) {
      if (!parentMap.containsKey(parentId)) {
        final parent = await isar.transactionModels.get(parentId);
        if (parent != null) {
          parentMap[parentId] = parent;
        }
      }
    }
    return transactions
        .map(
          (transaction) => TransactionRecord(
            transaction: transaction,
            category: categoryMap[transaction.categoryId],
            subCategory: categoryMap[transaction.subCategoryId],
            parentTransaction: transaction.parentTransactionId == null
                ? null
                : parentMap[transaction.parentTransactionId!],
          ),
        )
        .toList();
  }

  bool _isPayback(TransactionModel transaction) {
    return transaction.transactionType == TransactionTypes.debtLoan &&
        (transaction.debtLoanKind == DebtLoanKinds.debtCollection ||
            transaction.debtLoanKind == DebtLoanKinds.loanRepayment);
  }
}

class _MutableCategorySpendingGroup {
  _MutableCategorySpendingGroup({
    required this.parentCategory,
    required this.name,
    required this.type,
  });

  final CategoryModel? parentCategory;
  final String name;
  final String type;
  int totalMinor = 0;
  final Map<String, CategorySpendingChild> children = {};

  List<CategorySpendingChild> get sortedChildren {
    final values = children.values.toList()
      ..sort((a, b) {
        final amountCompare = b.amountMinor.compareTo(a.amountMinor);
        if (amountCompare != 0) {
          return amountCompare;
        }
        return a.name.compareTo(b.name);
      });
    return values;
  }
}
