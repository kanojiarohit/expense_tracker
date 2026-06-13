import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/formatters.dart';
import 'settings_service.dart';
import 'transaction_service.dart';

class ExportResult {
  const ExportResult({required this.filePath, required this.recordCount});

  final String filePath;
  final int recordCount;
}

class ExportService {
  final SettingsService _settingsService = SettingsService();
  final TransactionService _transactionService = TransactionService();

  static Future<String> defaultExportPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/exports';
  }

  Future<ExportResult> exportCsv({
    DateTime? fromMonth,
    DateTime? toMonth,
    Set<int> categoryIds = const {},
  }) async {
    final records = await _filteredRecords(
      fromMonth: fromMonth,
      toMonth: toMonth,
      categoryIds: categoryIds,
    );

    final settings = await _settingsService.load();
    final savedPath = settings.exportPath?.trim() ?? '';
    final exportPath = savedPath.isEmpty
        ? await defaultExportPath()
        : savedPath;
    final directory = Directory(exportPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final csv = _buildCsv(records);
    final fileName = _fileName(
      fromMonth: fromMonth,
      toMonth: toMonth,
      categoryCount: categoryIds.length,
    );
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csv);
    return ExportResult(filePath: file.path, recordCount: records.length);
  }

  Future<List<TransactionRecord>> _filteredRecords({
    DateTime? fromMonth,
    DateTime? toMonth,
    Set<int> categoryIds = const {},
  }) async {
    final records = await _transactionService.fetchAllRecords();
    final fromDate = fromMonth == null ? null : startOfMonth(fromMonth);
    final toDate = toMonth == null ? null : endOfMonth(toMonth);
    return records.where((record) {
      final date = record.transaction.transactionDate;
      if (fromDate != null && date.isBefore(fromDate)) {
        return false;
      }
      if (toDate != null && date.isAfter(toDate)) {
        return false;
      }
      if (categoryIds.isEmpty) {
        return true;
      }
      final category = record.category;
      final subCategory = record.subCategory;
      return categoryIds.contains(record.transaction.categoryId) ||
          categoryIds.contains(record.transaction.subCategoryId) ||
          categoryIds.contains(category?.parentCategoryId) ||
          categoryIds.contains(subCategory?.parentCategoryId);
    }).toList();
  }

  String _buildCsv(List<TransactionRecord> records) {
    final rows = <List<String>>[
      [
        'Date',
        'Category',
        'Amount',
        'Payment Method',
        'Note',
        'Lender/Borrower',
        'Debt/Loan Type',
        'Linked Debt/Loan',
      ],
      for (final record in records) _rowFor(record),
    ];
    return rows.map((row) => row.map(_escapeCsv).join(',')).join('\n');
  }

  List<String> _rowFor(TransactionRecord record) {
    final transaction = record.transaction;
    final category = transactionDisplayTitle(
      transaction,
      categoryName: record.category?.name,
      subCategoryName: record.subCategory?.name,
    );
    final parent = record.parentTransaction;
    return [
      DateFormat('yyyy-MM-dd').format(transaction.transactionDate),
      category,
      (signedAmount(transaction) / 100).toStringAsFixed(2),
      transaction.paymentMethod,
      transaction.note,
      transaction.partyCsv ?? '',
      transaction.transactionType == TransactionTypes.debtLoan
          ? debtLoanLabel(transaction.debtLoanKind)
          : '',
      parent == null
          ? ''
          : '${debtLoanLabel(parent.debtLoanKind)} #${parent.id}',
    ];
  }

  String _fileName({
    DateTime? fromMonth,
    DateTime? toMonth,
    required int categoryCount,
  }) {
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final labels = <String>[];
    if (fromMonth != null) {
      labels.add('from_${DateFormat('yyyyMM').format(fromMonth)}');
    }
    if (toMonth != null) {
      labels.add('to_${DateFormat('yyyyMM').format(toMonth)}');
    }
    if (categoryCount > 0) {
      labels.add('categories_$categoryCount');
    }
    final label = labels.isEmpty ? 'all' : labels.join('_');
    return 'expense_tracker_${label}_$stamp.csv';
  }

  String _escapeCsv(String value) {
    final needsQuotes =
        value.contains(',') || value.contains('"') || value.contains('\n');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }
}
