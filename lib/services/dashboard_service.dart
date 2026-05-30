import '../core/constants.dart';
import '../core/formatters.dart';
import 'transaction_service.dart';

class DashboardMonthReport {
  DashboardMonthReport({
    required this.month,
    required this.expenseMinor,
    required this.incomeMinor,
  });

  final DateTime month;
  final int expenseMinor;
  final int incomeMinor;
}

class CategorySpendData {
  CategorySpendData({
    required this.name,
    required this.iconName,
    required this.colorHex,
    required this.amountMinor,
  });

  final String name;
  final String iconName;
  final String colorHex;
  final int amountMinor;
}

class DebtLoanTrendPoint {
  DebtLoanTrendPoint({
    required this.month,
    required this.debtMinor,
    required this.loanMinor,
  });

  final DateTime month;
  final int debtMinor;
  final int loanMinor;
}

class DashboardData {
  DashboardData({
    required this.monthReports,
    required this.monthCategorySpend,
    required this.weekCategorySpend,
    required this.recentTransactions,
    required this.debtLoanTrend,
  });

  final List<DashboardMonthReport> monthReports;
  final List<CategorySpendData> monthCategorySpend;
  final List<CategorySpendData> weekCategorySpend;
  final List<TransactionRecord> recentTransactions;
  final List<DebtLoanTrendPoint> debtLoanTrend;
}

class DashboardService {
  final TransactionService _transactionService = TransactionService();

  Future<DashboardData> load() async {
    final records = await _transactionService.fetchAllRecords();
    final recent = records.take(5).toList();
    final monthReports = recentMonths(3)
        .map(
          (month) => DashboardMonthReport(
            month: month,
            expenseMinor: _expenseForMonth(records, month),
            incomeMinor: _incomeForMonth(records, month),
          ),
        )
        .toList();
    final now = DateTime.now();
    final monthCategorySpend = _topCategories(
      records
          .where((item) => isSameMonth(item.transaction.transactionDate, now))
          .toList(),
    );
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekCategorySpend = _topCategories(
      records
          .where(
            (item) => item.transaction.transactionDate.isAfter(
              weekStart.subtract(const Duration(seconds: 1)),
            ),
          )
          .toList(),
    );
    final debtLoanTrend = recentMonths(5).reversed.map((month) {
      return DebtLoanTrendPoint(
        month: month,
        debtMinor: _principalTotal(records, month, DebtLoanKinds.debt),
        loanMinor: _principalTotal(records, month, DebtLoanKinds.loan),
      );
    }).toList();

    return DashboardData(
      monthReports: monthReports,
      monthCategorySpend: monthCategorySpend,
      weekCategorySpend: weekCategorySpend,
      recentTransactions: recent,
      debtLoanTrend: debtLoanTrend,
    );
  }

  int _expenseForMonth(List<TransactionRecord> records, DateTime month) {
    return records
        .where((item) => isSameMonth(item.transaction.transactionDate, month))
        .where((item) => signedAmount(item.transaction) < 0)
        .where((item) => !item.transaction.excludeFromReports)
        .fold<int>(0, (sum, item) => sum + item.transaction.amountMinor);
  }

  int _incomeForMonth(List<TransactionRecord> records, DateTime month) {
    return records
        .where((item) => isSameMonth(item.transaction.transactionDate, month))
        .where((item) => signedAmount(item.transaction) > 0)
        .where((item) => !item.transaction.excludeFromReports)
        .fold<int>(0, (sum, item) => sum + item.transaction.amountMinor);
  }

  int _principalTotal(
    List<TransactionRecord> records,
    DateTime month,
    String kind,
  ) {
    return records
        .where((item) => isSameMonth(item.transaction.transactionDate, month))
        .where((item) => item.transaction.debtLoanKind == kind)
        .fold<int>(0, (sum, item) => sum + item.transaction.amountMinor);
  }

  List<CategorySpendData> _topCategories(List<TransactionRecord> records) {
    final map = <String, CategorySpendData>{};
    for (final item in records) {
      if (signedAmount(item.transaction) >= 0 ||
          item.transaction.excludeFromReports) {
        continue;
      }
      final key = item.category?.name ?? 'Other';
      final current = map[key];
      map[key] = CategorySpendData(
        name: key,
        iconName: item.category?.icon ?? 'category',
        colorHex: item.category?.colorHex ?? '#64748B',
        amountMinor: (current?.amountMinor ?? 0) + item.transaction.amountMinor,
      );
    }
    final values = map.values.toList()
      ..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    return values.take(5).toList();
  }
}
