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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlockDevice());
  }

  Future<void> _unlockDevice() async {
    setState(() {
      _unlocking = true;
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
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  Image.asset(
                    'assets/images/app_icon.png',
                    width: 88,
                    height: 88,
                  ),
                  const SizedBox(height: 28),
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
