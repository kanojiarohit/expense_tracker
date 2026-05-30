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
}
