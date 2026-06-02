import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ProvisionalNotificationService {
  static const _channel = MethodChannel('expense_tracker/provisional_notify');

  Future<void> syncPendingCount(int count) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    if (count <= 0) {
      await _channel.invokeMethod<void>('clearPendingNotification');
      return;
    }
    await _channel.invokeMethod<void>('showPendingNotification', {
      'count': count,
    });
  }

  Future<bool> consumeLaunchRequest() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    return await _channel.invokeMethod<bool>('consumeLaunchRequest') ?? false;
  }

  Future<bool> hasPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    return await _channel.invokeMethod<bool>('hasNotificationPermission') ??
        false;
  }

  Future<bool> requestPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    return await _channel.invokeMethod<bool>('requestNotificationPermission') ??
        false;
  }
}
