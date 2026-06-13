import 'package:flutter/services.dart';

class AppLockService {
  static const MethodChannel _channel = MethodChannel(
    'expense_tracker/app_lock',
  );

  Future<bool> canUseDeviceLock() async {
    try {
      return await _channel.invokeMethod<bool>('isDeviceLockSupported') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateDeviceLock() async {
    try {
      return await _channel.invokeMethod<bool>('authenticateDeviceLock') ??
          false;
    } catch (_) {
      return false;
    }
  }
}
