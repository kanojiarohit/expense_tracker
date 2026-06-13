import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/app_settings.dart';
import '../../models/transaction.dart';
import '../../services/transaction_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/category_avatar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({
    super.key,
    required this.reloadToken,
    required this.settings,
    required this.initialMonth,
    required this.onEditTransaction,
  });

  final int reloadToken;
  final AppSettingsModel settings;
  final DateTime initialMonth;
  final ValueChanged<TransactionModel> onEditTransaction;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with TickerProviderStateMixin {
  final TransactionService _transactionService = TransactionService();
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;
  bool _hasTabController = false;
  DateTime _selectedMonth = DateTime.now();
  List<DateTime> _months = [];
  final Map<String, List<TransactionRecord>> _recordsByMonth = {};
  final Map<String, int> _cashBalanceByMonth = {};
  final Set<String> _loadingMonths = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _configureTabs(widget.initialMonth);
    _loadMonth(_selectedMonth);
  }

  @override
  void didUpdateWidget(covariant TransactionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken ||
        !isSameMonth(oldWidget.initialMonth, widget.initialMonth)) {
      _configureTabs(widget.initialMonth);
      _recordsByMonth.clear();
      _cashBalanceByMonth.clear();
      _loadingMonths.clear();
      _loadMonth(_selectedMonth);
    }
  }

  @override
  void dispose() {
    if (_hasTabController) {
      _tabController.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  void _configureTabs(DateTime month) {
    _selectedMonth = DateTime(month.year, month.month);
    _months = List.generate(
      18,
      (index) =>
          DateTime(_selectedMonth.year, _selectedMonth.month + index - 11, 1),
    );
    if (_hasTabController) {
      _tabController.dispose();
    }
    _tabController = TabController(
      length: _months.length,
      vsync: this,
      initialIndex: 11,
    )..addListener(_handleTabChange);
    _hasTabController = true;
  }

  void _handleTabChange() {
    final month = _months[_tabController.index];
    if (isSameMonth(month, _selectedMonth) && !_tabController.indexIsChanging) {
      return;
    }
    setState(() {
      _selectedMonth = month;
    });
    _loadMonth(month);
  }

  String _monthKey(DateTime month) => '${month.year}-${month.month}';

  Future<void> _loadMonth(DateTime month) async {
    final key = _monthKey(month);
    if (_loadingMonths.contains(key)) {
      return;
    }
    setState(() => _loadingMonths.add(key));
    final records = await _transactionService.fetchMonthRecords(month);
    final balance = await _transactionService.cashBalanceForMonth(month);
    if (!mounted) {
      return;
    }
    setState(() {
      _recordsByMonth[key] = records;
      _cashBalanceByMonth[key] = balance;
      _loadingMonths.remove(key);
    });
  }

  List<TransactionRecord> _filteredRecords(DateTime month) {
    final term = _searchController.text.trim().toLowerCase();
    final records =
        _recordsByMonth[_monthKey(month)] ?? const <TransactionRecord>[];
    return records.where((record) {
      final transaction = record.transaction;
      if (term.isEmpty) {
        return true;
      }
      final haystack = [
        transaction.title,
        transaction.note,
        record.category?.name ?? '',
        record.subCategory?.name ?? '',
        transaction.partyCsv ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(term);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cashBalance = _cashBalanceByMonth[_monthKey(_selectedMonth)] ?? 0;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                SectionHeader(
                  title: 'Transactions',
                  subtitle:
                      'Cash Balance ${formatMinorAmount(cashBalance, currency: widget.settings.currency, amountFormat: widget.settings.amountFormat)}',
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _searchController,
                  label: 'Search note or person',
                  hintText: 'Lunch, Rahul, Salary',
                ),
                const SizedBox(height: 12),
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    for (final month in _months) Tab(text: monthLabel(month)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (final month in _months)
                  _MonthTransactionBody(
                    records: _filteredRecords(month),
                    loading:
                        _loadingMonths.contains(_monthKey(month)) &&
                        !_recordsByMonth.containsKey(_monthKey(month)),
                    settings: widget.settings,
                    transactionService: _transactionService,
                    onEditTransaction: widget.onEditTransaction,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthTransactionBody extends StatelessWidget {
  const _MonthTransactionBody({
    required this.records,
    required this.loading,
    required this.settings,
    required this.transactionService,
    required this.onEditTransaction,
  });

  final List<TransactionRecord> records;
  final bool loading;
  final AppSettingsModel settings;
  final TransactionService transactionService;
  final ValueChanged<TransactionModel> onEditTransaction;

  int get _incomeMinor => records.fold<int>(0, (sum, item) {
    final amount = signedAmount(item.transaction);
    return amount > 0 ? sum + amount : sum;
  });

  int get _expenseMinor => records.fold<int>(0, (sum, item) {
    final amount = signedAmount(item.transaction);
    return amount < 0 ? sum + amount.abs() : sum;
  });

  int get _balanceMinor => _incomeMinor - _expenseMinor;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final groups = transactionService.groupByDay(records);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        _MonthTotals(
          incomeMinor: _incomeMinor,
          expenseMinor: _expenseMinor,
          balanceMinor: _balanceMinor,
          settings: settings,
        ),
        const SizedBox(height: 12),
        if (records.isEmpty)
          const AppCard(
            child: EmptyState(
              title: 'No transactions this month',
              description: 'Try a different month or add a new transaction.',
            ),
          )
        else
          for (final group in groups)
            AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              borderRadius: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DayHeader(group: group, settings: settings),
                  const SizedBox(height: 8),
                  for (final record in group.records)
                    _TransactionTile(
                      record: record,
                      settings: settings,
                      onTap: () => onEditTransaction(record.transaction),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}

class _MonthTotals extends StatelessWidget {
  const _MonthTotals({
    required this.incomeMinor,
    required this.expenseMinor,
    required this.balanceMinor,
    required this.settings,
  });

  final int incomeMinor;
  final int expenseMinor;
  final int balanceMinor;
  final AppSettingsModel settings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TotalPill(
            label: 'Income',
            amountMinor: incomeMinor,
            color: AppColors.success,
            settings: settings,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TotalPill(
            label: 'Expense',
            amountMinor: expenseMinor,
            color: AppColors.danger,
            settings: settings,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TotalPill(
            label: 'Balance',
            amountMinor: balanceMinor,
            color: balanceMinor >= 0 ? AppColors.success : AppColors.danger,
            settings: settings,
          ),
        ),
      ],
    );
  }
}

class _TotalPill extends StatelessWidget {
  const _TotalPill({
    required this.label,
    required this.amountMinor,
    required this.color,
    required this.settings,
  });

  final String label;
  final int amountMinor;
  final Color color;
  final AppSettingsModel settings;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: mutedColor),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMinorAmount(
                  amountMinor.abs(),
                  currency: settings.currency,
                  amountFormat: settings.amountFormat,
                ),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.group, required this.settings});

  final DayTransactionGroup group;
  final AppSettingsModel settings;

  @override
  Widget build(BuildContext context) {
    final balance = group.incomeMinor - group.expenseMinor;
    final balanceColor = balance >= 0 ? AppColors.success : AppColors.danger;
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        Row(
          children: [
            Text(
              dateDayNumber(group.date),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateWeekday(group.date),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: mutedColor,
                  ),
                ),
                Text(
                  dateMonthYear(group.date),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: mutedColor),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${balance >= 0 ? '+' : '-'}${formatMinorAmount(balance.abs(), currency: settings.currency, amountFormat: settings.amountFormat)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: balanceColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
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
    final color = signed >= 0 ? AppColors.success : AppColors.danger;
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final subtitle = [
      if (record.transaction.partyCsv?.isNotEmpty == true)
        record.transaction.partyCsv!,
      if (record.transaction.note.isNotEmpty) record.transaction.note,
      if (record.transaction.excludeFromReports) 'Excluded from reports',
    ].join(' • ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CategoryAvatar(
              category: record.category,
              type: record.transaction.transactionType,
              debtLoanKind: record.transaction.debtLoanKind,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    transactionDisplayTitle(
                      record.transaction,
                      categoryName: record.category?.name,
                      subCategoryName: record.subCategory?.name,
                    ),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: mutedColor),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${signed >= 0 ? '+' : '-'}${formatMinorAmount(signed.abs(), currency: settings.currency, amountFormat: settings.amountFormat)}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
