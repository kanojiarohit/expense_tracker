import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import 'constants.dart';
import 'currencies.dart';

Color colorFromHex(String hex) {
  final clean = hex.replaceFirst('#', '');
  return Color(int.parse('FF$clean', radix: 16));
}

int parseMinorAmount(String value) {
  final sanitized = value.replaceAll(',', '').trim();
  if (sanitized.isEmpty) {
    return 0;
  }
  final parsed = double.tryParse(sanitized);
  if (parsed == null || parsed <= 0) {
    return 0;
  }
  return (parsed * 100).round();
}

String formatMinorAmount(
  int amountMinor, {
  required String currency,
  required String amountFormat,
}) {
  final locale = amountFormat == SettingValues.indianAmountFormat
      ? 'en_IN'
      : 'en_US';
  final formatter = NumberFormat.currency(
    locale: locale,
    symbol: '${currencyInfoFor(currency).symbol} ',
  );
  return formatter.format(amountMinor / 100);
}

String formatDate(DateTime date, String pattern) {
  switch (pattern) {
    case SettingValues.dateMmDdYyyy:
      return DateFormat('MM/dd/yyyy').format(date);
    case SettingValues.dateIso:
      return DateFormat('yyyy-MM-dd').format(date);
    case SettingValues.dateLong:
      return DateFormat('d MMM yyyy').format(date);
    case SettingValues.dateDdMmYyyy:
    default:
      return DateFormat('dd/MM/yyyy').format(date);
  }
}

String dayLabel(DateTime date) => DateFormat('dd EEE').format(date);

String dateDayNumber(DateTime date) => DateFormat('dd').format(date);

String dateWeekday(DateTime date) => DateFormat('EEE').format(date);

String dateMonthYear(DateTime date) => DateFormat('MMM yyyy').format(date);

String monthLabel(DateTime date) =>
    DateFormat('MMM yyyy').format(DateTime(date.year, date.month));

List<DateTime> recentMonths(int count) {
  final now = DateTime.now();
  return List.generate(
    count,
    (index) => DateTime(now.year, now.month - index, 1),
  );
}

DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month, 1);

DateTime endOfMonth(DateTime date) =>
    DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);

bool isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

int signedAmount(TransactionModel transaction) {
  if (transaction.transactionType == TransactionTypes.expense) {
    return -transaction.amountMinor;
  }
  if (transaction.transactionType == TransactionTypes.income) {
    return transaction.amountMinor;
  }
  return debtLoanKindIsInflow(transaction.debtLoanKind)
      ? transaction.amountMinor
      : -transaction.amountMinor;
}

String transactionDisplayTitle(
  TransactionModel transaction, {
  String? categoryName,
  String? subCategoryName,
}) {
  if (transaction.transactionType == TransactionTypes.debtLoan) {
    return debtLoanLabel(transaction.debtLoanKind);
  }
  if (subCategoryName != null && subCategoryName.isNotEmpty) {
    return '$categoryName / $subCategoryName';
  }
  return categoryName ?? transaction.title;
}
