import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../models/app_settings.dart';
import '../../models/transaction.dart';
import '../../navigation/app_route.dart';
import '../../services/transaction_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../transactions/add_edit_transaction_screen.dart';

class DebtLoanScreen extends StatefulWidget {
  const DebtLoanScreen({
    super.key,
    required this.reloadToken,
    required this.settings,
    this.focusedTransactionId,
    this.onEditTransaction,
    this.onAddPayback,
  });

  final int reloadToken;
  final AppSettingsModel settings;
  final int? focusedTransactionId;
  final ValueChanged<TransactionModel>? onEditTransaction;
  final void Function(String kind, TransactionModel parentTransaction)?
  onAddPayback;

  @override
  State<DebtLoanScreen> createState() => _DebtLoanScreenState();
}

class _DebtLoanScreenState extends State<DebtLoanScreen>
    with SingleTickerProviderStateMixin {
  static const _tabs = [
    (label: 'Debt', kind: DebtLoanKinds.debt),
    (label: 'Loan', kind: DebtLoanKinds.loan),
  ];

  final TransactionService _transactionService = TransactionService();
  late final TabController _tabController;
  final Map<String, List<DebtLoanSummary>> _summariesByKind = {};
  final Set<String> _loadingKinds = {};
  final Map<int, GlobalKey> _cardKeys = {};
  int? _pendingFocusedTransactionId;

  @override
  void initState() {
    super.initState();
    _pendingFocusedTransactionId = widget.focusedTransactionId;
    _tabController = TabController(length: _tabs.length, vsync: this)
      ..addListener(() {
        setState(() {});
        _loadKind(_tabs[_tabController.index].kind);
      });
    _loadAll();
  }

  @override
  void didUpdateWidget(covariant DebtLoanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusedTransactionId != widget.focusedTransactionId) {
      _pendingFocusedTransactionId = widget.focusedTransactionId;
      _focusPendingTransaction();
    }
    if (oldWidget.reloadToken != widget.reloadToken) {
      _loadAll();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([for (final tab in _tabs) _loadKind(tab.kind)]);
    _focusPendingTransaction();
  }

  Future<void> _loadKind(String kind) async {
    if (_loadingKinds.contains(kind)) {
      return;
    }
    setState(() => _loadingKinds.add(kind));
    final summaries = await _transactionService.fetchDebtLoanSummaries(kind);
    if (!mounted) {
      return;
    }
    setState(() {
      _summariesByKind[kind] = summaries;
      _loadingKinds.remove(kind);
    });
    _focusPendingTransaction();
  }

  void _focusPendingTransaction() {
    final transactionId = _pendingFocusedTransactionId;
    if (transactionId == null) {
      return;
    }
    String? targetKind;
    for (final tab in _tabs) {
      final summaries = _summariesByKind[tab.kind];
      if (summaries == null) {
        continue;
      }
      final hasTransaction = summaries.any(
        (summary) => summary.principal.transaction.id == transactionId,
      );
      if (hasTransaction) {
        targetKind = tab.kind;
        break;
      }
    }
    if (targetKind == null) {
      return;
    }
    final targetIndex = _tabs.indexWhere((tab) => tab.kind == targetKind);
    if (targetIndex >= 0 && _tabController.index != targetIndex) {
      _tabController.animateTo(targetIndex);
    }
    _pendingFocusedTransactionId = null;
    _scheduleCardScroll(transactionId);
  }

  void _scheduleCardScroll(int transactionId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _cardKeys[transactionId]?.currentContext;
        if (context == null) {
          return;
        }
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.08,
        );
      });
    });
  }

  Future<void> _openTransaction(
    TransactionModel? transaction, {
    String? forcedKind,
    TransactionModel? parent,
  }) async {
    final changed = await Navigator.of(context).push<bool>(
      AppRoute(
        builder: (_) => AddEditTransactionScreen(
          transaction: transaction,
          forcedDebtLoanKind: forcedKind,
          parentTransaction: parent,
          settings: widget.settings,
        ),
      ),
    );
    if (changed == true) {
      await _loadAll();
      if (mounted) {
        Navigator.of(context).maybePop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debt / Loan'),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          tabs: [for (final tab in _tabs) Tab(text: tab.label)],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            for (final tab in _tabs)
              _DebtLoanTabBody(
                kind: tab.kind,
                loading:
                    _loadingKinds.contains(tab.kind) &&
                    !_summariesByKind.containsKey(tab.kind),
                summaries: _summariesByKind[tab.kind] ?? const [],
                settings: widget.settings,
                cardKeys: _cardKeys,
                onOpenTransaction: _openTransaction,
              ),
          ],
        ),
      ),
    );
  }
}

class _DebtLoanTabBody extends StatelessWidget {
  const _DebtLoanTabBody({
    required this.kind,
    required this.loading,
    required this.summaries,
    required this.settings,
    required this.cardKeys,
    required this.onOpenTransaction,
  });

  final String kind;
  final bool loading;
  final List<DebtLoanSummary> summaries;
  final AppSettingsModel settings;
  final Map<int, GlobalKey> cardKeys;
  final Future<void> Function(
    TransactionModel? transaction, {
    String? forcedKind,
    TransactionModel? parent,
  })
  onOpenTransaction;

  bool get _isDebt => kind == DebtLoanKinds.debt;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        if (summaries.isEmpty)
          AppCard(
            borderRadius: 8,
            child: EmptyState(
              title: _isDebt ? 'No debt records' : 'No loan records',
              description:
                  'Create a debt or loan transaction to start tracking balances.',
            ),
          )
        else
          for (final summary in summaries)
            _DebtLoanCard(
              key: cardKeys.putIfAbsent(
                summary.principal.transaction.id,
                GlobalKey.new,
              ),
              summary: summary,
              kind: kind,
              settings: settings,
              onOpenTransaction: onOpenTransaction,
            ),
      ],
    );
  }
}

class _DebtLoanCard extends StatelessWidget {
  const _DebtLoanCard({
    super.key,
    required this.summary,
    required this.kind,
    required this.settings,
    required this.onOpenTransaction,
  });

  final DebtLoanSummary summary;
  final String kind;
  final AppSettingsModel settings;
  final Future<void> Function(
    TransactionModel? transaction, {
    String? forcedKind,
    TransactionModel? parent,
  })
  onOpenTransaction;

  bool get _isDebt => kind == DebtLoanKinds.debt;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final transaction = summary.principal.transaction;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(
                  _isDebt ? Icons.south_west : Icons.north_east,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.partyCsv ??
                          debtLoanLabel(transaction.debtLoanKind),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDate(
                        transaction.transactionDate,
                        settings.dateFormat,
                      ),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: mutedColor),
                    ),
                  ],
                ),
              ),
              Chip(label: Text(summary.isClosed ? 'Closed' : 'Open')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricPill(
                  label: _isDebt ? 'Taken' : 'Given',
                  value: formatMinorAmount(
                    transaction.amountMinor,
                    currency: settings.currency,
                    amountFormat: settings.amountFormat,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricPill(
                  label: _isDebt ? 'Repaid' : 'Collected',
                  value: formatMinorAmount(
                    summary.paidMinor,
                    currency: settings.currency,
                    amountFormat: settings.amountFormat,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricPill(
                  label: 'Balance',
                  value: formatMinorAmount(
                    summary.balanceMinor,
                    currency: settings.currency,
                    amountFormat: settings.amountFormat,
                  ),
                ),
              ),
            ],
          ),
          if (!summary.isClosed) ...[
            const SizedBox(height: 12),
            AppButton(
              label: _isDebt ? 'Add repayment' : 'Add collection',
              onPressed: () => onOpenTransaction(
                null,
                forcedKind: _isDebt
                    ? DebtLoanKinds.loanRepayment
                    : DebtLoanKinds.debtCollection,
                parent: transaction,
              ),
              variant: AppButtonVariant.secondary,
              icon: Icons.add_rounded,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Payback transactions',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (summary.linkedRecords.isEmpty)
            const EmptyState(
              title: 'No payback transactions',
              description: 'Linked collections and repayments appear here.',
            )
          else
            for (final record in summary.linkedRecords)
              _PaybackRow(
                record: record,
                settings: settings,
                onTap: () => onOpenTransaction(record.transaction),
              ),
        ],
      ),
    );
  }
}

class _PaybackRow extends StatelessWidget {
  const _PaybackRow({
    required this.record,
    required this.settings,
    required this.onTap,
  });

  final TransactionRecord record;
  final AppSettingsModel settings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.edit_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDate(
                      record.transaction.transactionDate,
                      settings.dateFormat,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (record.transaction.note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      record.transaction.note,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: mutedColor),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              formatMinorAmount(
                record.transaction.amountMinor,
                currency: settings.currency,
                amountFormat: settings.amountFormat,
              ),
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                value,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
