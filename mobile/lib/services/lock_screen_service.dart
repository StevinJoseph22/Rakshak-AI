import 'package:flutter/services.dart';
import '../config/lock_screen_config.dart';
import 'crash_event_service.dart';

/// Platform bridge service for Android lock screen bypass and full-screen intent alerts.
class LockScreenService {
  LockScreenService._internal();
  static final LockScreenService _instance = LockScreenService._internal();
  static LockScreenService get instance => _instance;

  static const MethodChannel _channel = MethodChannel(kLockScreenMethodChannel);

  /// Configures window flags on MainActivity to render over keyguard when active.
  Future<bool> enableLockScreenDisplay() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('enableLockScreenDisplay');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if the app currently holds Android 14+ USE_FULL_SCREEN_INTENT permission.
  Future<bool> canUseFullScreenIntent() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('canUseFullScreenIntent');
      return result ?? true;
    } catch (_) {
      return true; // Non-Android or older OS defaults to true
    }
  }

  /// Opens the exact Android system settings page for full screen intent special access.
  Future<bool> openFullScreenIntentSettings() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('openFullScreenIntentSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Triggers a native Android full-screen wake-up intent notification.
  Future<bool> triggerRealFullScreenAlert(CrashEvent event) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'triggerFullScreenAlert',
        {
          'title': 'CRASH DETECTED — EMERGENCY SOS',
          'body': 'Impact force: ${event.decelerationG.toStringAsFixed(1)}G. Tap to alert ambulance and police.',
        },
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Starts the indestructible 24/7 foreground crash guard service.
  Future<bool> startBackgroundCrashGuard() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('startBackgroundCrashGuard');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Stops the background crash guard service.
  Future<bool> stopBackgroundCrashGuard() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('stopBackgroundCrashGuard');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if the 24/7 background service is actively running.
  Future<bool> isBackgroundCrashGuardRunning() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('isBackgroundCrashGuardRunning');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests OEM battery optimization exemption (Samsung, Xiaomi, Vivo, Oppo).
  Future<bool> requestBatteryOptimizationExemption() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('requestBatteryOptimizationExemption');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if battery optimization has been exempted.
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Checks if MainActivity was launched due to a crash detected while app was swiped away/killed.
  Future<Map<String, dynamic>?> getPendingCrashEvent() async {
    try {
      final dynamic result = await _channel.invokeMethod('getPendingCrashEvent');
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
