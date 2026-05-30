import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../services/export_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_button.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final ExportService _exportService = ExportService();
  DateTime _fromMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _toMonth = DateTime(DateTime.now().year, DateTime.now().month);
  ExportMode? _exportingMode;

  Future<void> _pickMonth({required bool isFrom}) async {
    final current = isFrom ? _fromMonth : _toMonth;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isFrom ? 'Choose From Month' : 'Choose To Month',
    );
    if (picked == null || !mounted) {
      return;
    }
    final month = DateTime(picked.year, picked.month);
    setState(() {
      if (isFrom) {
        _fromMonth = month;
        if (_toMonth.isBefore(_fromMonth)) {
          _toMonth = _fromMonth;
        }
      } else {
        _toMonth = month;
        if (_fromMonth.isAfter(_toMonth)) {
          _fromMonth = _toMonth;
        }
      }
    });
  }

  Future<void> _export(ExportMode mode) async {
    setState(() => _exportingMode = mode);
    try {
      final result = await _exportService.exportCsv(
        mode: mode,
        fromMonth: _fromMonth,
        toMonth: _toMonth,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported ${result.recordCount} records to ${result.filePath}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _exportingMode = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export'),
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              borderRadius: 8,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Column(
                children: [
                  _ExportTile(
                    icon: Icons.file_download_outlined,
                    title: 'Export all',
                    value: 'All transactions in one CSV',
                    loading: _exportingMode == ExportMode.all,
                    onTap: () => _export(ExportMode.all),
                  ),
                  const Divider(height: 1),
                  _MonthTile(
                    title: 'From month',
                    value: monthLabel(_fromMonth),
                    onTap: () => _pickMonth(isFrom: true),
                  ),
                  const Divider(height: 1),
                  _MonthTile(
                    title: 'To month',
                    value: monthLabel(_toMonth),
                    onTap: () => _pickMonth(isFrom: false),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Export selected months',
                      icon: Icons.date_range_outlined,
                      isLoading: _exportingMode == ExportMode.monthRange,
                      onPressed: () => _export(ExportMode.monthRange),
                    ),
                  ),
                ],
              ),
            ),
            AppCard(
              borderRadius: 8,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: _ExportTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Export Debt/Loan',
                value: 'Debt, loan, repayment, and collection records',
                loading: _exportingMode == ExportMode.debtLoan,
                onTap: () => _export(ExportMode.debtLoan),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  const _ExportTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: mutedColor),
                  ),
                ],
              ),
            ),
            loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  const _MonthTile({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(
                Icons.calendar_month_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: mutedColor),
            ),
          ],
        ),
      ),
    );
  }
}
