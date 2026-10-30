import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service responsible for triggering high-priority emergency sirens and heavy vibration.
/// Leverages native Android `STREAM_ALARM` with `AudioAttributes.FLAG_AUDIBILITY_ENFORCED`
/// and `USAGE_ALARM` vibration effects to pierce through Silent Mode, Vibrate Mode,
/// and Android Do Not Disturb (DND) restrictions during life-critical events.
class EmergencySirenService {
  EmergencySirenService._internal();
  static final EmergencySirenService _instance = EmergencySirenService._internal();
  static EmergencySirenService get instance => _instance;

  static const MethodChannel _channel = MethodChannel('com.rakshak.mobile/emergency_siren');

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  /// Starts the 10-second crash alarm siren and heavy haptic vibration.
  /// Bypasses Do Not Disturb, Silent, and Vibrate modes.
  Future<void> startCrashAlarmSiren({int durationSeconds = 10}) async {
    _isPlaying = true;
    try {
      debugPrint('[EmergencySirenService] 🚨 Triggering $durationSeconds-second crash siren (DND/Silent override)...');
      await _channel.invokeMethod('startEmergencySiren', {
        'durationSeconds': durationSeconds,
        'isAmbulance': false,
      });
    } catch (e) {
      debugPrint('[EmergencySirenService] Failed to start crash siren: $e');
    }
  }

  /// Starts the continuous 45-second ambulance pilot dispatch siren and heavy haptic alarm.
  /// Rings continuously until an ambulance accepts the dispatch or the 45s timer completes.
  Future<void> startAmbulanceDispatchSiren({int durationSeconds = 45}) async {
    _isPlaying = true;
    try {
      debugPrint('[EmergencySirenService] 🚑 Triggering $durationSeconds-second ambulance dispatch siren...');
      await _channel.invokeMethod('startEmergencySiren', {
        'durationSeconds': durationSeconds,
        'isAmbulance': true,
      });
    } catch (e) {
      debugPrint('[EmergencySirenService] Failed to start ambulance siren: $e');
    }
  }

  /// Immediately silences any active emergency siren and stops heavy haptic vibration.
  Future<void> stopSiren() async {
    if (!_isPlaying) return;
    _isPlaying = false;
    try {
      debugPrint('[EmergencySirenService] 🔇 Silencing emergency siren & vibration.');
      await _channel.invokeMethod('stopEmergencySiren');
    } catch (e) {
      debugPrint('[EmergencySirenService] Failed to stop siren: $e');
    }
  }
}
