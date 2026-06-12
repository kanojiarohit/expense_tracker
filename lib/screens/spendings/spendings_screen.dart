import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../models/app_settings.dart';
import '../../models/category.dart';
import '../../services/category_service.dart';
import '../../services/transaction_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/category_avatar.dart';
import '../../widgets/empty_state.dart';

class SpendingsScreen extends StatefulWidget {
  const SpendingsScreen({
    super.key,
    required this.settings,
    required this.initialMonth,
  });

  final AppSettingsModel settings;
  final DateTime initialMonth;

  @override
  State<SpendingsScreen> createState() => _SpendingsScreenState();
}

class _SpendingsScreenState extends State<SpendingsScreen>
    with TickerProviderStateMixin {
  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService();

  late TabController _tabController;
  bool _hasTabController = false;
  DateTime _selectedMonth = DateTime.now();
  String _selectedType = TransactionTypes.expense;
  List<DateTime> _months = [];
  List<CategoryModel> _categories = [];
  final Map<String, List<TransactionRecord>> _recordsByMonth = {};
  final Set<String> _loadingMonths = {};

  @override
  void initState() {
    super.initState();
    _configureTabs(widget.initialMonth);
    _loadCategories();
    _loadMonth(_selectedMonth);
  }

  @override
  void dispose() {
    if (_hasTabController) {
      _tabController.dispose();
    }
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
    if (!mounted) {
      return;
    }
    setState(() {
      _recordsByMonth[key] = records;
      _loadingMonths.remove(key);
    });
  }

  Future<void> _loadCategories() async {
    final categories = await _categoryService.fetchAll();
    if (!mounted) {
      return;
    }
    setState(() {
      _categories = categories;
    });
  }

  List<TransactionRecord> _filteredRecords(DateTime month) {
    final records =
        _recordsByMonth[_monthKey(month)] ?? const <TransactionRecord>[];
    return records.where((record) {
      final transaction = record.transaction;
      if (transaction.excludeFromReports ||
          transaction.transactionType != _selectedType) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Category transactions'),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  _TypePills(
                    selectedType: _selectedType,
                    onChanged: (value) => setState(() => _selectedType = value),
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
                    _MonthSpendingsBody(
                      groups: _transactionService.groupSpendingsByCategory(
                        _filteredRecords(month),
                        categories: _categories,
                      ),
                      loading:
                          _loadingMonths.contains(_monthKey(month)) &&
                          !_recordsByMonth.containsKey(_monthKey(month)),
                      settings: widget.settings,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypePills extends StatelessWidget {
  const _TypePills({required this.selectedType, required this.onChanged});

  final String selectedType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TypePill(
            label: 'Expense',
            type: TransactionTypes.expense,
            selectedType: selectedType,
            color: AppColors.danger,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TypePill(
            label: 'Income',
            type: TransactionTypes.income,
            selectedType: selectedType,
            color: AppColors.success,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({
    required this.label,
    required this.type,
    required this.selectedType,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final String type;
  final String selectedType;
  final Color color;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = selectedType == type;
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onChanged(type),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : theme.dividerColor.withValues(alpha: 0.8),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: selected ? color : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _MonthSpendingsBody extends StatelessWidget {
  const _MonthSpendingsBody({
    required this.groups,
    required this.loading,
    required this.settings,
  });

  final List<CategorySpendingGroup> groups;
  final bool loading;
  final AppSettingsModel settings;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        if (groups.isEmpty)
          const AppCard(
            borderRadius: 8,
            child: EmptyState(
              title: 'No category transactions this month',
              description: 'Category totals will appear here.',
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
                  _SpendingParentHeader(
                    group: group,
                    settings: settings,
                    hasChildren: group.children.isNotEmpty,
                  ),
                  if (group.children.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    for (final child in group.children)
                      _SpendingChildRow(child: child, settings: settings),
                  ],
                ],
              ),
            ),
      ],
    );
  }
}

class _SpendingParentHeader extends StatelessWidget {
  const _SpendingParentHeader({
    required this.group,
    required this.settings,
    required this.hasChildren,
  });

  final CategorySpendingGroup group;
  final AppSettingsModel settings;
  final bool hasChildren;

  @override
  Widget build(BuildContext context) {
    final color = _amountColor(group.type);
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CategoryAvatar(
              category: group.parentCategory,
              name: group.name,
              type: group.type,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                group.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: mutedColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 112,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  formatMinorAmount(
                    group.totalMinor,
                    currency: settings.currency,
                    amountFormat: settings.amountFormat,
                  ),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (hasChildren) ...[
          const SizedBox(height: 8),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

class _SpendingChildRow extends StatelessWidget {
  const _SpendingChildRow({required this.child, required this.settings});

  final CategorySpendingChild child;
  final AppSettingsModel settings;

  @override
  Widget build(BuildContext context) {
    final color = _amountColor(child.type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CategoryAvatar(
            category: child.category,
            name: child.name,
            type: child.type,
            radius: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              child.name,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 112,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                formatMinorAmount(
                  child.amountMinor,
                  currency: settings.currency,
                  amountFormat: settings.amountFormat,
                ),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _amountColor(String type) {
  return type == TransactionTypes.income ? AppColors.success : AppColors.danger;
}
