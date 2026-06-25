import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../models/app_settings.dart';
import '../../navigation/app_route.dart';
import '../../services/sms_transaction_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/category_avatar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../transactions/add_edit_transaction_screen.dart';

class SmsCompatibilityScreen extends StatefulWidget {
  const SmsCompatibilityScreen({super.key, required this.settings});

  final AppSettingsModel settings;

  @override
  State<SmsCompatibilityScreen> createState() => _SmsCompatibilityScreenState();
}

class _SmsCompatibilityScreenState extends State<SmsCompatibilityScreen> {
  final _smsController = TextEditingController();
  final _parser = const SmsTransactionParser();
  ParsedSmsTransaction? _parsed;
  String? _error;

  @override
  void dispose() {
    _smsController.dispose();
    super.dispose();
  }

  void _checkSms() {
    final sms = _smsController.text.trim();
    if (sms.isEmpty) {
      setState(() {
        _parsed = null;
        _error = 'Paste SMS text first.';
      });
      return;
    }
    final parsed = _parser.parse(
      smsBody: sms,
      sender: 'manual-check',
      fallbackReceivedAt: DateTime.now(),
    );
    setState(() {
      _parsed = parsed;
      _error = parsed == null ? 'Could not detect transaction details.' : null;
    });
  }

  void _clear() {
    _smsController.clear();
    setState(() {
      _parsed = null;
      _error = null;
    });
  }

  Future<void> _openTransactionForm(ParsedSmsTransaction parsed) async {
    final changed = await Navigator.of(context).push<bool>(
      AppRoute(
        builder: (_) => AddEditTransactionScreen(
          settings: widget.settings,
          initialDraft: SmsTransactionDraft(
            amountText: (parsed.amountMinor / 100).toStringAsFixed(2),
            transactionType: parsed.transactionType,
            note: parsed.note,
            paymentMethod: parsed.paymentMethod,
            transactionDate: parsed.smsReceivedAt,
          ),
        ),
      ),
    );
    if (changed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Compatibility'),
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(
              title: 'Check SMS',
              subtitle: 'Paste bank SMS to preview parsed transaction.',
            ),
            const SizedBox(height: 12),
            AppCard(
              borderRadius: 8,
              margin: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _smsController,
                    label: 'Bank SMS',
                    hintText: 'Paste transaction SMS here',
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Check',
                          icon: Icons.fact_check_outlined,
                          onPressed: _checkSms,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          label: 'Clear',
                          icon: Icons.clear_rounded,
                          variant: AppButtonVariant.secondary,
                          onPressed: _clear,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SectionHeader(title: 'Result'),
            const SizedBox(height: 12),
            if (_parsed != null)
              AppCard(
                borderRadius: 8,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                child: _ParsedSmsTile(
                  parsed: _parsed!,
                  settings: widget.settings,
                  onTap: () => _openTransactionForm(_parsed!),
                ),
              )
            else
              AppCard(
                borderRadius: 8,
                child: EmptyState(
                  title: _error == null ? 'No result' : 'Not compatible',
                  description:
                      _error ?? 'Paste an SMS and tap Check to preview.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ParsedSmsTile extends StatelessWidget {
  const _ParsedSmsTile({
    required this.parsed,
    required this.settings,
    required this.onTap,
  });

  final ParsedSmsTransaction parsed;
  final AppSettingsModel settings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isIncome = parsed.transactionType == TransactionTypes.income;
    final categoryName = isIncome ? 'Credit' : 'Debit';
    final color = isIncome ? AppColors.success : AppColors.danger;
    final signedPrefix = isIncome ? '+' : '-';
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                CategoryAvatar(
                  name: categoryName,
                  type: parsed.transactionType,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryName,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        parsed.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: mutedColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$signedPrefix${formatMinorAmount(parsed.amountMinor, currency: settings.currency, amountFormat: settings.amountFormat)}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            _DetailRow(
              label: 'Date',
              value: formatDate(parsed.smsReceivedAt, settings.dateFormat),
            ),
            const Divider(height: 1),
            _DetailRow(label: 'Payment method', value: parsed.paymentMethod),
            const Divider(height: 1),
            _DetailRow(label: 'Category', value: categoryName),
            const Divider(height: 1),
            _DetailRow(label: 'Type', value: isIncome ? 'Income' : 'Expense'),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: mutedColor),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
