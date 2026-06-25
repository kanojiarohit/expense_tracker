import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/app_settings.dart';
import '../../services/app_lock_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';

class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  final AppSettingsModel settings;
  final Future<void> Function() onSettingsChanged;

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  final AppLockService _appLockService = AppLockService();
  final SettingsService _settingsService = SettingsService();
  late bool _appLockEnabled;
  late String _appLockTimeoutMode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _appLockEnabled = widget.settings.appLockEnabled;
    _appLockTimeoutMode = widget.settings.appLockTimeoutModeValue;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final settings = await _settingsService.load();
      settings
        ..appLockEnabled = _appLockEnabled
        ..appLockTimeoutMode = _appLockTimeoutMode;
      await _settingsService.save(settings);
      await widget.onSettingsChanged();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set a phone PIN, pattern, password, or biometric unlock first.',
          ),
        ),
      );
      return;
    }
    final authenticated = await _appLockService.authenticateDeviceLock();
    if (!mounted || !authenticated) {
      return;
    }
    setState(() => _appLockEnabled = true);
    await _save();
  }

  Future<void> _selectTimeout(String value) async {
    if (value == _appLockTimeoutMode) {
      return;
    }
    setState(() => _appLockTimeoutMode = value);
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App lock'),
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(
              title: 'Lock the app on close',
              subtitle: 'Protect Expense Tracker with your device unlock.',
            ),
            const SizedBox(height: 12),
            AppCard(
              borderRadius: 8,
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: _DeviceUnlockSwitch(
                value: _appLockEnabled,
                saving: _saving,
                onChanged: _toggleAppLock,
              ),
            ),
            if (_appLockEnabled) ...[
              const SectionHeader(title: 'Automatically lock'),
              const SizedBox(height: 12),
              AppCard(
                borderRadius: 8,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    for (final option in _timeoutOptions) ...[
                      if (option != _timeoutOptions.first)
                        const Divider(height: 1),
                      _TimeoutOptionTile(
                        option: option,
                        selectedValue: _appLockTimeoutMode,
                        saving: _saving,
                        onSelected: _selectTimeout,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeviceUnlockSwitch extends StatelessWidget {
  const _DeviceUnlockSwitch({
    required this.value,
    required this.saving,
    required this.onChanged,
  });

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
            child: Icon(
              Icons.lock_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unlock with device lock',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Use phone PIN, pattern, password, or biometrics.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: mutedColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
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

class _TimeoutOptionTile extends StatelessWidget {
  const _TimeoutOptionTile({
    required this.option,
    required this.selectedValue,
    required this.saving,
    required this.onSelected,
  });

  final _TimeoutOption option;
  final String selectedValue;
  final bool saving;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = option.value == selectedValue;
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: saving ? null : () => onSelected(option.value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : mutedColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.label,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              )
            else
              const SizedBox.square(dimension: 24),
          ],
        ),
      ),
    );
  }
}

class _TimeoutOption {
  const _TimeoutOption({required this.value, required this.label});

  final String value;
  final String label;
}

const _timeoutOptions = [
  _TimeoutOption(value: SettingValues.appLockImmediate, label: 'Immediately'),
  _TimeoutOption(
    value: SettingValues.appLockAfter1Minute,
    label: 'After 1 minute',
  ),
  _TimeoutOption(
    value: SettingValues.appLockAfter30Minutes,
    label: 'After 30 minutes',
  ),
];
