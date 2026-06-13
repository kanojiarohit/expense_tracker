import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/app_settings.dart';
import '../../models/transaction.dart';
import '../../services/dashboard_service.dart';
import '../../services/transaction_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/category_avatar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.reloadToken,
    required this.settings,
    required this.onOpenMonth,
    required this.onOpenDebtLoan,
    required this.onOpenDebtLoanTransaction,
    required this.onOpenSpendings,
    required this.onOpenProvisionalTransactions,
    required this.onEditTransaction,
    required this.provisionalCount,
  });

  final int reloadToken;
  final AppSettingsModel settings;
  final ValueChanged<DateTime> onOpenMonth;
  final VoidCallback onOpenDebtLoan;
  final ValueChanged<int> onOpenDebtLoanTransaction;
  final VoidCallback onOpenSpendings;
  final VoidCallback onOpenProvisionalTransactions;
  final ValueChanged<TransactionModel> onEditTransaction;
  final int provisionalCount;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DashboardService _dashboardService = DashboardService();
  bool _loading = true;
  DashboardData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await _dashboardService.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : data == null
            ? const SizedBox.shrink()
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 940;
                  final cardWidth = wide
                      ? (constraints.maxWidth - 44) / 2
                      : constraints.maxWidth;
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SectionHeader(
                        title: 'Expense Tracker',
                        subtitle:
                            'Track spending, income, and balances with clarity',
                        actionIcon: Icons.receipt_long_outlined,
                        actionBadge: widget.provisionalCount,
                        onActionTap: widget.onOpenProvisionalTransactions,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: _ReportCard(
                              data: data,
                              settings: widget.settings,
                              onOpenMonth: widget.onOpenMonth,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _SpendingCard(
                              spendData: data.monthCategorySpend,
                              settings: widget.settings,
                              onViewAll: widget.onOpenSpendings,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _RecentTransactionsCard(
                              records: data.recentTransactions,
                              settings: widget.settings,
                              onEditTransaction: widget.onEditTransaction,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _DebtLoanCard(
                              data: data,
                              settings: widget.settings,
                              onOpenDebtLoan: widget.onOpenDebtLoan,
                              onOpenDebtLoanTransaction:
                                  widget.onOpenDebtLoanTransaction,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.data,
    required this.settings,
    required this.onOpenMonth,
  });

  final DashboardData data;
  final AppSettingsModel settings;
  final ValueChanged<DateTime> onOpenMonth;

  @override
  Widget build(BuildContext context) {
    final maxAmount = data.monthReports.fold<int>(1, (max, item) {
      final itemMax = item.expenseMinor > item.incomeMinor
          ? item.expenseMinor
          : item.incomeMinor;
      return itemMax > max ? itemMax : max;
    });
    return AppCard(
      borderRadius: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Expenses',
            subtitle: 'Last 3 months. Tap a month to view transactions.',
          ),
          const SizedBox(height: 12),
          for (final item in data.monthReports)
            InkWell(
              onTap: () => onOpenMonth(item.month),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthLabel(item.month),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _AmountBar(
                      label: 'Expense',
                      amountMinor: item.expenseMinor,
                      maxAmountMinor: maxAmount,
                      color: AppColors.danger,
                      settings: settings,
                    ),
                    const SizedBox(height: 6),
                    _AmountBar(
                      label: 'Income',
                      amountMinor: item.incomeMinor,
                      maxAmountMinor: maxAmount,
                      color: AppColors.success,
                      settings: settings,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AmountBar extends StatelessWidget {
  const _AmountBar({
    required this.label,
    required this.amountMinor,
    required this.maxAmountMinor,
    required this.color,
    required this.settings,
  });

  final String label;
  final int amountMinor;
  final int maxAmountMinor;
  final Color color;
  final AppSettingsModel settings;

  @override
  Widget build(BuildContext context) {
    final value = maxAmountMinor == 0 ? 0.0 : amountMinor / maxAmountMinor;
    return Row(
      children: [
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1),
              minHeight: 8,
              backgroundColor: Theme.of(
                context,
              ).dividerColor.withValues(alpha: 0.45),
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 86,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              formatMinorAmount(
                amountMinor,
                currency: settings.currency,
                amountFormat: settings.amountFormat,
              ),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpendingCard extends StatelessWidget {
  const _SpendingCard({
    required this.spendData,
    required this.settings,
    required this.onViewAll,
  });

  final List<CategorySpendData> spendData;
  final AppSettingsModel settings;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Top Spending',
            subtitle: 'Top 5 categories',
            actionLabel: 'View all',
            onActionTap: onViewAll,
          ),
          const SizedBox(height: 12),
          if (spendData.isEmpty) ...[
            const Center(
              child: EmptyState(
                title: 'No spending yet',
                description: 'Your top categories will appear here.',
              ),
            ),
          ],
          if (spendData.isNotEmpty) ...[
            for (final item in spendData)
              _CategorySpendRow(item: item, settings: settings),
          ],
        ],
      ),
    );
  }
}

class _CategorySpendRow extends StatelessWidget {
  const _CategorySpendRow({required this.item, required this.settings});

  final CategorySpendData item;
  final AppSettingsModel settings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          CategoryAvatar(name: item.name, type: item.type, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.name,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            formatMinorAmount(
              item.amountMinor,
              currency: settings.currency,
              amountFormat: settings.amountFormat,
            ),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  const _RecentTransactionsCard({
    required this.records,
    required this.settings,
    required this.onEditTransaction,
  });

  final List<TransactionRecord> records;
  final AppSettingsModel settings;
  final ValueChanged<TransactionModel> onEditTransaction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Recent Transactions',
            subtitle: 'Last 5 records',
          ),
          const SizedBox(height: 12),
          if (records.isEmpty)
            const EmptyState(
              title: 'No transactions yet',
              description:
                  'Add your first transaction from the center plus button.',
            )
          else
            for (final record in records)
              ListTile(
                onTap: () => onEditTransaction(record.transaction),
                contentPadding: EdgeInsets.zero,
                leading: CategoryAvatar(
                  category: record.category,
                  type: record.transaction.transactionType,
                  debtLoanKind: record.transaction.debtLoanKind,
                ),
                title: Text(
                  transactionDisplayTitle(
                    record.transaction,
                    categoryName: record.category?.name,
                    subCategoryName: record.subCategory?.name,
                  ),
                ),
                subtitle: Text(
                  _homeTransactionSubtitle(record),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  '${signedAmount(record.transaction) >= 0 ? '+' : '-'}${formatMinorAmount(signedAmount(record.transaction).abs(), currency: settings.currency, amountFormat: settings.amountFormat)}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: signedAmount(record.transaction) >= 0
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _DebtLoanCard extends StatelessWidget {
  const _DebtLoanCard({
    required this.data,
    required this.settings,
    required this.onOpenDebtLoan,
    required this.onOpenDebtLoanTransaction,
  });

  final DashboardData data;
  final AppSettingsModel settings;
  final VoidCallback onOpenDebtLoan;
  final ValueChanged<int> onOpenDebtLoanTransaction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      borderRadius: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Debt/Loan',
            subtitle: 'Latest 5 open debt and loan records',
            actionLabel: 'Show All',
            onActionTap: onOpenDebtLoan,
          ),
          const SizedBox(height: 12),
          if (data.recentDebtLoanTransactions.isEmpty)
            const EmptyState(
              title: 'No debt or loan yet',
              description: 'Debt and loan transactions will appear here.',
            )
          else
            for (final record in data.recentDebtLoanTransactions)
              _DebtLoanTransactionRow(
                record: record,
                settings: settings,
                onTap: () => onOpenDebtLoanTransaction(record.transaction.id),
              ),
        ],
      ),
    );
  }
}

class _DebtLoanTransactionRow extends StatelessWidget {
  const _DebtLoanTransactionRow({
    required this.record,
    required this.settings,
    required this.onTap,
  });

  final TransactionRecord record;
  final AppSettingsModel settings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final signed = signedAmount(record.transaction);
    final color = signed >= 0 ? AppColors.success : AppColors.accent;
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: CategoryAvatar(
        category: record.category,
        type: record.transaction.transactionType,
        debtLoanKind: record.transaction.debtLoanKind,
      ),
      title: Text(
        transactionDisplayTitle(
          record.transaction,
          categoryName: record.category?.name,
          subCategoryName: record.subCategory?.name,
        ),
      ),
      subtitle: Text(
        _homeTransactionSubtitle(record),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${signed >= 0 ? '+' : '-'}${formatMinorAmount(signed.abs(), currency: settings.currency, amountFormat: settings.amountFormat)}',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _homeTransactionSubtitle(TransactionRecord record) {
  if (record.transaction.note.isNotEmpty) {
    return record.transaction.note;
  }
  return record.transaction.partyCsv ?? '';
}
