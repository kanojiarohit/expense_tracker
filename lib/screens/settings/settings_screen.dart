import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/currencies.dart';
import '../../core/formatters.dart';
import '../../models/app_settings.dart';
import '../../navigation/app_route.dart';
import '../../services/app_lock_service.dart';
import '../../services/export_service.dart';
import '../../services/provisional_notification_service.dart';
import '../../services/settings_service.dart';
import '../../services/sms_transaction_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';
import 'select_currency_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    required this.onOpenDebtLoan,
    required this.onOpenExport,
    required this.onOpenProvisionalTransactions,
  });

  final AppSettingsModel settings;
  final Future<void> Function() onSettingsChanged;
  final VoidCallback onOpenDebtLoan;
  final VoidCallback onOpenExport;
  final VoidCallback onOpenProvisionalTransactions;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppLockService _appLockService = AppLockService();
  final SettingsService _settingsService = SettingsService();
  final SmsTransactionService _smsTransactionService = SmsTransactionService();
  final ProvisionalNotificationService _notificationService =
      ProvisionalNotificationService();
  bool _saving = false;
  late String _themeMode;
  late String _amountFormat;
  late String _dateFormat;
  late String _currency;
  late String _exportPath;
  late bool _smsImportEnabled;
  late bool _appLockEnabled;
  String _defaultExportPath = '';
  bool _deviceLockAvailable = false;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
    _loadDefaultExportPath();
    _loadDeviceLockAvailability();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _syncFromWidget();
    }
  }

  void _syncFromWidget() {
    _themeMode = widget.settings.themeMode;
    _amountFormat = widget.settings.amountFormat;
    _dateFormat = widget.settings.dateFormat;
    _currency = widget.settings.currency;
    _exportPath = widget.settings.exportPath ?? '';
    _smsImportEnabled = widget.settings.smsImportEnabled;
    _appLockEnabled = widget.settings.appLockEnabled;
  }

  Future<void> _loadDefaultExportPath() async {
    final path = await ExportService.defaultExportPath();
    if (!mounted) {
      return;
    }
    setState(() => _defaultExportPath = path);
  }

  Future<void> _loadDeviceLockAvailability() async {
    final available = await _appLockService.canUseDeviceLock();
    if (!mounted) {
      return;
    }
    setState(() => _deviceLockAvailable = available);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final settings = AppSettingsModel()
        ..id = 1
        ..themeMode = _themeMode
        ..amountFormat = _amountFormat
        ..dateFormat = _dateFormat
        ..currency = _currency
        ..exportPath = _exportPath.trim().isEmpty ? null : _exportPath.trim()
        ..smsImportEnabled = _smsImportEnabled
        ..appLockEnabled = _appLockEnabled
        ..createdAt = widget.settings.createdAt;
      await _settingsService.save(settings);
      await widget.onSettingsChanged();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _chooseSetting({
    required String title,
    required String selectedValue,
    required List<_SettingOption> options,
    required ValueChanged<String> onSelected,
  }) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              for (final option in options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(option.label),
                  trailing: option.value == selectedValue
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(option.value),
                ),
            ],
          ),
        ),
      ),
    );
    if (value == null || value == selectedValue || !mounted) {
      return;
    }
    setState(() => onSelected(value));
    await _save();
  }

  Future<void> _editExportPath() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose Export Folder',
        initialDirectory: _exportPath.trim().isEmpty ? null : _exportPath,
      );
      if (path == null || !mounted) {
        return;
      }
      setState(() => _exportPath = path);
      await _save();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file browser: $error')),
      );
    }
  }

  Future<void> _resetExportPath() async {
    if (_exportPath.trim().isEmpty) {
      return;
    }
    setState(() => _exportPath = '');
    await _save();
  }

  Future<void> _chooseCurrency() async {
    final value = await Navigator.of(context).push<String>(
      AppRoute(
        builder: (_) => SelectCurrencyScreen(selectedCurrency: _currency),
      ),
    );
    if (value == null || value == _currency || !mounted) {
      return;
    }
    setState(() => _currency = value);
    await _save();
  }

  Future<void> _toggleSmsImport(bool enabled) async {
    if (!enabled) {
      setState(() => _smsImportEnabled = false);
      await _save();
      return;
    }
    final shouldEnable = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Transactions from SMS'),
        content: const Text(
          'Expense Tracker will detect new bank transaction SMS and keep them as provisional transactions for review. Nothing is added to reports until you save it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    if (shouldEnable != true || !mounted) {
      return;
    }
    var granted = await _smsTransactionService.hasSmsPermission();
    if (!granted) {
      granted = await _smsTransactionService.requestSmsPermission();
    }
    if (!mounted) {
      return;
    }
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transactions from SMS permission was not granted.'),
        ),
      );
      return;
    }
    var notificationGranted = await _notificationService.hasPermission();
    if (!notificationGranted) {
      notificationGranted = await _notificationService.requestPermission();
    }
    if (!mounted) {
      return;
    }
    if (!notificationGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification permission was not granted.'),
        ),
      );
      return;
    }
    setState(() => _smsImportEnabled = true);
    await _save();
  }

  Future<void> _toggleAppLock(bool enabled) async {
    if (!enabled) {
      setState(() => _appLockEnabled = false);
      await _save();
      return;
    }
    final available = await _appLockService.canUseDeviceLock();
    if (!mounted) {
      return;
    }
    if (!available) {
      setState(() => _deviceLockAvailable = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set an Android screen PIN, pattern, or password first.',
          ),
        ),
      );
      return;
    }
    final authenticated = await _appLockService.authenticateDeviceLock();
    if (!mounted || !authenticated) {
      return;
    }
    setState(() {
      _appLockEnabled = true;
      _deviceLockAvailable = true;
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(
            title: 'Tools',
            subtitle: 'Export data and manage balances',
          ),
          const SizedBox(height: 12),
          AppCard(
            borderRadius: 8,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Column(
              children: [
                _SettingTile(
                  icon: Icons.file_download_outlined,
                  title: 'Export',
                  value: 'Save transactions as CSV',
                  saving: false,
                  onTap: widget.onOpenExport,
                ),
                const Divider(height: 1),
                _SettingTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Debt/Loan',
                  value: 'Open debt and loan records',
                  saving: false,
                  onTap: widget.onOpenDebtLoan,
                ),
                const Divider(height: 1),
                _SettingTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Provisional Transactions',
                  value: 'Review bank SMS transactions',
                  saving: false,
                  onTap: widget.onOpenProvisionalTransactions,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(
            title: 'Settings',
            subtitle: 'Formats and appearance',
          ),
          const SizedBox(height: 12),
          AppCard(
            borderRadius: 8,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Column(
              children: [
                _SettingTile(
                  icon: Icons.palette_outlined,
                  title: 'Theme',
                  value: _labelFor(_themeMode, _themeOptions),
                  saving: _saving,
                  onTap: () => _chooseSetting(
                    title: 'Choose Theme',
                    selectedValue: _themeMode,
                    options: _themeOptions,
                    onSelected: (value) => _themeMode = value,
                  ),
                ),
                const Divider(height: 1),
                _SettingTile(
                  icon: Icons.format_list_numbered_outlined,
                  title: 'Amount format',
                  value: _amountFormatExample(_amountFormat, _currency),
                  saving: _saving,
                  onTap: () => _chooseSetting(
                    title: 'Choose Amount Format',
                    selectedValue: _amountFormat,
                    options: _amountFormatOptions(_currency),
                    onSelected: (value) => _amountFormat = value,
                  ),
                ),
                const Divider(height: 1),
                _SettingTile(
                  icon: Icons.calendar_month_outlined,
                  title: 'Date format',
                  value: _dateFormatExample(_dateFormat),
                  saving: _saving,
                  onTap: () => _chooseSetting(
                    title: 'Choose Date Format',
                    selectedValue: _dateFormat,
                    options: _dateFormatOptions(),
                    onSelected: (value) => _dateFormat = value,
                  ),
                ),
                const Divider(height: 1),
                _SettingTile(
                  icon: Icons.payments_outlined,
                  title: 'Currency',
                  value: _currencyLabel(_currency),
                  saving: _saving,
                  onTap: _chooseCurrency,
                ),
                const Divider(height: 1),
                _SettingTile(
                  icon: Icons.folder_outlined,
                  title: 'Export path',
                  value: _exportPath.trim().isEmpty
                      ? (_defaultExportPath.isEmpty
                            ? 'Default export folder'
                            : _defaultExportPath)
                      : _exportPath,
                  saving: _saving,
                  onTap: _editExportPath,
                  onSecondaryTap: _resetExportPath,
                ),
                const Divider(height: 1),
                _SwitchSettingTile(
                  icon: Icons.sms_outlined,
                  title: 'Transactions from SMS',
                  value: _smsImportEnabled,
                  description: _smsImportEnabled
                      ? 'Bank SMS saved for review'
                      : 'Off',
                  saving: _saving,
                  onChanged: _toggleSmsImport,
                ),
                const Divider(height: 1),
                _SwitchSettingTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'App lock',
                  value: _appLockEnabled,
                  description: _appLockEnabled
                      ? 'Android screen lock required'
                      : (_deviceLockAvailable
                            ? 'Off'
                            : 'Set screen lock first'),
                  saving: _saving,
                  onChanged: _toggleAppLock,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.saving,
    required this.onTap,
    this.onSecondaryTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool saving;
  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: saving ? null : onTap,
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: mutedColor),
                  ),
                ],
              ),
            ),
            saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : onSecondaryTap == null
                ? const SizedBox.shrink()
                : IconButton(
                    onPressed: onSecondaryTap,
                    icon: const Icon(Icons.restart_alt_rounded),
                    tooltip: 'Use default',
                  ),
          ],
        ),
      ),
    );
  }
}

class _SwitchSettingTile extends StatelessWidget {
  const _SwitchSettingTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.saving,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final bool saving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: mutedColor),
                ),
              ],
            ),
          ),
          saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SettingOption {
  const _SettingOption(this.value, this.label);

  final String value;
  final String label;
}

const _themeOptions = [
  _SettingOption(SettingValues.themeSystem, 'System'),
  _SettingOption(SettingValues.themeLight, 'Light'),
  _SettingOption(SettingValues.themeDark, 'Dark'),
];

List<_SettingOption> _amountFormatOptions(String currency) => [
  _SettingOption(
    SettingValues.indianAmountFormat,
    formatMinorAmount(
      123456789,
      currency: currency,
      amountFormat: SettingValues.indianAmountFormat,
    ),
  ),
  _SettingOption(
    SettingValues.internationalAmountFormat,
    formatMinorAmount(
      123456789,
      currency: currency,
      amountFormat: SettingValues.internationalAmountFormat,
    ),
  ),
];

List<_SettingOption> _dateFormatOptions() => [
  _SettingOption(
    SettingValues.dateDdMmYyyy,
    _dateFormatExample(SettingValues.dateDdMmYyyy),
  ),
  _SettingOption(
    SettingValues.dateMmDdYyyy,
    _dateFormatExample(SettingValues.dateMmDdYyyy),
  ),
  _SettingOption(
    SettingValues.dateIso,
    _dateFormatExample(SettingValues.dateIso),
  ),
  _SettingOption(
    SettingValues.dateLong,
    _dateFormatExample(SettingValues.dateLong),
  ),
];

String _labelFor(String value, List<_SettingOption> options) {
  return options
      .where((option) => option.value == value)
      .map((option) => option.label)
      .firstWhere((_) => true, orElse: () => value);
}

String _currencyLabel(String currencyCode) {
  final currency = currencyInfoFor(currencyCode);
  return '${currency.flag} ${currency.name} • ${currency.symbol}';
}

String _amountFormatExample(String amountFormat, String currency) {
  return formatMinorAmount(
    123456789,
    currency: currency,
    amountFormat: amountFormat,
  );
}

String _dateFormatExample(String dateFormat) {
  return formatDate(DateTime.now(), dateFormat);
}
