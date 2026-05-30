import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../models/app_settings.dart';
import '../../models/provisional_transaction.dart';
import '../../navigation/app_route.dart';
import '../../services/provisional_transaction_repository.dart';
import '../../services/sms_transaction_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../transactions/add_edit_transaction_screen.dart';

class ProvisionalTransactionsScreen extends StatefulWidget {
  const ProvisionalTransactionsScreen({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final AppSettingsModel settings;
  final Future<void> Function() onChanged;

  @override
  State<ProvisionalTransactionsScreen> createState() =>
      _ProvisionalTransactionsScreenState();
}

class _ProvisionalTransactionsScreenState
    extends State<ProvisionalTransactionsScreen> {
  final ProvisionalTransactionRepository _repository =
      ProvisionalTransactionRepository();
  bool _loading = true;
  List<ProvisionalTransaction> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading || _items.isEmpty) {
      setState(() => _loading = true);
    }
    final items = await _repository.fetchPending();
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _delete(ProvisionalTransaction item) async {
    setState(() {
      _items = _items.where((current) => current.id != item.id).toList();
    });
    await _repository.delete(item.id);
    await widget.onChanged();
  }

  Future<void> _save(ProvisionalTransaction item) async {
    final changed = await Navigator.of(context).push<bool>(
      AppRoute(
        builder: (_) => AddEditTransactionScreen(
          initialDraft: SmsTransactionDraft(
            amountText: (item.amountMinor / 100).toStringAsFixed(2),
            transactionType: item.transactionType,
            note: item.smsBody,
            paymentMethod: item.paymentMethod ?? PaymentMethods.values.first,
            transactionDate: item.smsReceivedAt,
          ),
          settings: widget.settings,
        ),
      ),
    );
    if (changed == true) {
      setState(() {
        _items = _items.where((current) => current.id != item.id).toList();
      });
      await _repository.removeSaved(item.id);
      await widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provisional Transactions'),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_items.isEmpty)
                      const AppCard(
                        borderRadius: 8,
                        child: EmptyState(
                          title: 'No provisional transactions',
                          description:
                              'Bank SMS transactions appear here for review.',
                        ),
                      )
                    else
                      for (final item in _items)
                        _ProvisionalTransactionCard(
                          key: ValueKey(item.id),
                          item: item,
                          settings: widget.settings,
                          onDelete: () => _delete(item),
                          onSave: () => _save(item),
                        ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProvisionalTransactionCard extends StatelessWidget {
  const _ProvisionalTransactionCard({
    super.key,
    required this.item,
    required this.settings,
    required this.onDelete,
    required this.onSave,
  });

  final ProvisionalTransaction item;
  final AppSettingsModel settings;
  final VoidCallback onDelete;
  final VoidCallback onSave;

  bool get _isIncome => item.transactionType == TransactionTypes.income;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
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
                  _isIncome
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatMinorAmount(
                        item.amountMinor,
                        currency: settings.currency,
                        amountFormat: settings.amountFormat,
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isIncome ? 'Credit' : 'Debit',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: mutedColor),
                    ),
                  ],
                ),
              ),
              Text(
                formatDate(item.smsReceivedAt, settings.dateFormat),
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: mutedColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.smsBody,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (item.sender.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.sender,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: mutedColor),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Delete',
                  icon: Icons.delete_outline,
                  variant: AppButtonVariant.secondary,
                  onPressed: onDelete,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Save',
                  icon: Icons.check_rounded,
                  onPressed: onSave,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
