import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/formatters.dart';
import 'settings_service.dart';
import 'transaction_service.dart';

enum ExportMode { all, monthRange, debtLoan }

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
    required ExportMode mode,
    DateTime? fromMonth,
    DateTime? toMonth,
  }) async {
    final records = switch (mode) {
      ExportMode.all => await _transactionService.fetchAllRecords(),
      ExportMode.monthRange => await _transactionService.fetchRecordsBetween(
        fromMonth!,
        toMonth!,
      ),
      ExportMode.debtLoan => await _transactionService.fetchDebtLoanRecords(),
    };

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
    final fileName = _fileName(mode, fromMonth: fromMonth, toMonth: toMonth);
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csv);
    return ExportResult(filePath: file.path, recordCount: records.length);
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

  String _fileName(ExportMode mode, {DateTime? fromMonth, DateTime? toMonth}) {
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final label = switch (mode) {
      ExportMode.all => 'all',
      ExportMode.monthRange =>
        '${DateFormat('yyyyMM').format(fromMonth!)}_${DateFormat('yyyyMM').format(toMonth!)}',
      ExportMode.debtLoan => 'debt_loan',
    };
    return 'expense_tracker_${label}_$stamp.csv';
  }

  String _escapeCsv(String value) {
    final needsQuotes =
        value.contains(',') || value.contains('"') || value.contains('\n');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }
}
