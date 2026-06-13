import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import '../../services/app_lock_service.dart';
import '../../widgets/app_button.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({
    super.key,
    required this.settings,
    required this.onUnlocked,
    required this.onSystemUnlockStarted,
  });

  final AppSettingsModel settings;
  final VoidCallback onUnlocked;
  final VoidCallback onSystemUnlockStarted;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final AppLockService _appLockService = AppLockService();
  bool _unlocking = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlockDevice());
  }

  Future<void> _unlockDevice() async {
    setState(() {
      _unlocking = true;
      _error = null;
    });
    widget.onSystemUnlockStarted();
    final unlocked = await _appLockService.authenticateDeviceLock();
    if (!mounted) {
      return;
    }
    if (unlocked) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _unlocking = false;
      _error = 'Device PIN was not confirmed.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.12,
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: theme.colorScheme.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Expense Tracker locked',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Use your Android screen lock to continue.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  AppButton(
                    label: 'Unlock',
                    icon: Icons.lock_open_rounded,
                    isLoading: _unlocking,
                    onPressed: _unlocking ? null : _unlockDevice,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
