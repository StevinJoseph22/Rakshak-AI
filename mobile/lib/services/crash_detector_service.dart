import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'crash_event_service.dart';
import 'tflite_classifier_stub.dart';

// ==============================================================================
// CONFIGURABLE CRASH DETECTION CONSTANTS (TUNABLE FOR REAL-PHONE TESTING)
// ------------------------------------------------------------------------------
/// Deceleration spike threshold in Gs required to flag an impact signature (6.0G - 8.0G)
const double kImpactDecelerationThresholdG = 6.5;

/// Minimum GPS-reported speed drop in km/h toward 0 km/h indicating sudden stop
const double kImpactSpeedDropThresholdKmh = 25.0;

/// Correlation time window (in ms) within which speed drop must follow deceleration
const int kSpeedDropWindowMs = 500;

/// Baseline gravity constant in m/s^2
const double kEarthGravity = 9.80665;

/// Pothole filter: lower G-force bound for high-frequency road vibrations
const double kPotholeMinG = 1.5;

/// Pothole filter: upper G-force bound (road anomalies rarely exceed 4G)
const double kPotholeMaxG = 4.0;

/// Pothole filter: minimum direction reversals within window to identify oscillatory burst
const int kPotholeOscillationThreshold = 3;

/// Pothole filter: rolling observation window in milliseconds
const int kPotholeWindowMs = 300;
// ==============================================================================

class _AccelSample {
  final DateTime timestamp;
  final double netG;
  final double x;
  final double y;
  final double z;

  const _AccelSample({
    required this.timestamp,
    required this.netG,
    required this.x,
    required this.y,
    required this.z,
  });
}

class _SpeedSample {
  final DateTime timestamp;
  final double speedKmh;

  const _SpeedSample({
    required this.timestamp,
    required this.speedKmh,
  });
}

/// Service implementing real-time IMU and GPS crash-detection logic.
/// Reuses sensor streams from main.dart and publishes confirmed events
/// into CrashEventService with source: "sensor".
class CrashDetectorService {
  CrashDetectorService._internal();
  static final CrashDetectorService _instance = CrashDetectorService._internal();
  static CrashDetectorService get instance => _instance;

  // Tunable runtime thresholds (initialized to default named constants)
  double impactDecelerationThresholdG = kImpactDecelerationThresholdG;
  double impactSpeedDropThresholdKmh = kImpactSpeedDropThresholdKmh;
  int speedDropWindowMs = kSpeedDropWindowMs;
  double potholeMinG = kPotholeMinG;
  double potholeMaxG = kPotholeMaxG;
  int potholeOscillationThreshold = kPotholeOscillationThreshold;
  int potholeWindowMs = kPotholeWindowMs;

  final TfLiteClassifierStub _tfliteStub = const TfLiteClassifierStub();

  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  StreamSubscription<Position>? _gpsSubscription;
  double _currentSpeedKmh = 0.0;
  double _lastKnownLatitude = 12.9716; // Default: Bengaluru
  double _lastKnownLongitude = 77.5946;
  bool _hasLiveGpsFix = false;

  double get lastKnownLatitude => _lastKnownLatitude;
  double get lastKnownLongitude => _lastKnownLongitude;
  bool get hasLiveGpsFix => _hasLiveGpsFix;

  final List<_AccelSample> _accelHistory = [];
  final List<double> _gyroMagnitudes = [];
  final List<_SpeedSample> _speedHistory = [];

  DateTime? _lastCrashTriggeredTime;

  /// Starts listening to device GPS and activates sensor evaluation.
  void start() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    _clearBuffers();
    _initGps();
  }

  /// Stops monitoring and cancels GPS listeners.
  void stop() {
    _isMonitoring = false;
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    _clearBuffers();
  }

  void _clearBuffers() {
    _accelHistory.clear();
    _gyroMagnitudes.clear();
    _speedHistory.clear();
  }

  Future<void> _initGps() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      // 1. Immediately read cached last known position for instant real coordinates
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        _lastKnownLatitude = lastPos.latitude;
        _lastKnownLongitude = lastPos.longitude;
        _hasLiveGpsFix = true;
      }

      // 2. Fetch fresh high-accuracy position asynchronously
      Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      ).then((Position pos) {
        _lastKnownLatitude = pos.latitude;
        _lastKnownLongitude = pos.longitude;
        _hasLiveGpsFix = true;
      }).catchError((_) {});

      // 3. Continuous stream for dynamic movement updates
      _gpsSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 1,
        ),
      ).listen(
        (Position pos) {
          final speed = pos.speed >= 0 ? pos.speed * 3.6 : 0.0;
          _lastKnownLatitude = pos.latitude;
          _lastKnownLongitude = pos.longitude;
          _hasLiveGpsFix = true;
          recordSpeedSample(speed, latitude: pos.latitude, longitude: pos.longitude);
        },
        onError: (_) {
          // Gracefully continue without hardware GPS
        },
      );
    } catch (_) {
      // Ignored if location unavailable
    }
  }

  /// Manually refresh the physical position on demand
  Future<Position?> refreshLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );
      _lastKnownLatitude = pos.latitude;
      _lastKnownLongitude = pos.longitude;
      _hasLiveGpsFix = true;
      return pos;
    } catch (_) {
      return null;
    }
  }

  /// Records a GPS speed sample (can also be called by tests/simulations).
  void recordSpeedSample(double speedKmh, {double? latitude, double? longitude, DateTime? timestamp}) {
    final now = timestamp ?? DateTime.now();
    _currentSpeedKmh = speedKmh;
    if (latitude != null) _lastKnownLatitude = latitude;
    if (longitude != null) _lastKnownLongitude = longitude;

    _speedHistory.add(_SpeedSample(timestamp: now, speedKmh: speedKmh));

    // Keep speed samples for last 2 seconds
    _speedHistory.removeWhere(
      (s) => now.difference(s.timestamp).inMilliseconds > 2000,
    );
  }

  /// Processes live Accelerometer samples from main.dart stream subscription.
  void processAccelerometer(AccelerometerEvent event, {DateTime? timestamp}) {
    if (!_isMonitoring) return;
    final now = timestamp ?? DateTime.now();

    // Calculate total G-force and dynamic deviation from 1G gravity
    final totalAccel = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    final totalG = totalAccel / kEarthGravity;
    final netG = (totalG - 1.0).abs();

    final sample = _AccelSample(
      timestamp: now,
      netG: netG,
      x: event.x,
      y: event.y,
      z: event.z,
    );

    _accelHistory.add(sample);

    // Maintain sliding window for pothole and impact detection
    _accelHistory.removeWhere(
      (s) => now.difference(s.timestamp).inMilliseconds > max(potholeWindowMs, speedDropWindowMs),
    );

    _evaluateTelemetries(sample, now);
  }

  /// Processes live Gyroscope samples from main.dart stream subscription.
  void processGyroscope(GyroscopeEvent event) {
    if (!_isMonitoring) return;
    final gyroMagnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    _gyroMagnitudes.add(gyroMagnitude);
    if (_gyroMagnitudes.length > 50) {
      _gyroMagnitudes.removeAt(0);
    }
  }

  void _evaluateTelemetries(_AccelSample currentSample, DateTime now) {
    // Prevent duplicate triggers within 5 seconds of an impact
    if (_lastCrashTriggeredTime != null &&
        now.difference(_lastCrashTriggeredTime!).inSeconds < 5) {
      return;
    }

    // Step 1: Query TFLite stub classification point
    final accelWindow = _accelHistory.map((s) => s.netG).toList();
    final classification = _tfliteStub.classify(accelWindow, _gyroMagnitudes);

    // If TFLite model is not available, execute rule-based kinematic filters
    if (_tfliteStub.shouldFallbackToRuleBased || classification.label == 'not_available') {
      _executeRuleBasedDetection(currentSample, now);
    }
  }

  void _executeRuleBasedDetection(_AccelSample currentSample, DateTime now) {
    // -------------------------------------------------------------------------
    // PASS 1: POTHOLE / SPEED-BUMP FALSE-POSITIVE FILTER
    // Detect high-frequency, low-amplitude vibration bursts (many small closely-spaced spikes)
    // -------------------------------------------------------------------------
    final recentWindow = _accelHistory.where(
      (s) => now.difference(s.timestamp).inMilliseconds <= potholeWindowMs,
    ).toList();

    if (recentWindow.length >= 4) {
      double windowPeakG = 0.0;
      for (final s in recentWindow) {
        if (s.netG > windowPeakG) windowPeakG = s.netG;
      }

      // Check if peak is within typical pothole vibration range (1.5G - 4.0G)
      if (windowPeakG >= potholeMinG && windowPeakG <= potholeMaxG) {
        // Count directional oscillations (reversals)
        int reversals = 0;
        for (int i = 1; i < recentWindow.length - 1; i++) {
          final prevDelta = recentWindow[i].netG - recentWindow[i - 1].netG;
          final nextDelta = recentWindow[i + 1].netG - recentWindow[i].netG;
          if ((prevDelta > 0 && nextDelta < 0) || (prevDelta < 0 && nextDelta > 0)) {
            reversals++;
          }
        }

        if (reversals >= potholeOscillationThreshold) {
          // Log filtered pothole burst at debug level as required
          debugPrint('Filtered: pothole-pattern, peak ${windowPeakG.toStringAsFixed(2)}g');
          return; // Suppress false-positive!
        }
      }
    }

    // -------------------------------------------------------------------------
    // PASS 2: IMPACT SIGNATURE CHECK
    // Deceleration crosses threshold (6.0 - 8.0G) AND GPS speed drops toward 0 km/h within 500ms
    // -------------------------------------------------------------------------
    if (currentSample.netG >= impactDecelerationThresholdG) {
      // Find peak pre-impact speed in recent window
      double preImpactSpeedKmh = _currentSpeedKmh;
      for (final s in _speedHistory) {
        if (now.difference(s.timestamp).inMilliseconds <= speedDropWindowMs &&
            s.speedKmh > preImpactSpeedKmh) {
          preImpactSpeedKmh = s.speedKmh;
        }
      }

      final speedDelta = preImpactSpeedKmh - _currentSpeedKmh;
      final bool speedDroppedTowardZero =
          speedDelta >= impactSpeedDropThresholdKmh ||
          (preImpactSpeedKmh >= impactSpeedDropThresholdKmh && _currentSpeedKmh <= 5.0);

      if (speedDroppedTowardZero) {
        _lastCrashTriggeredTime = now;

        final event = CrashEvent(
          timestamp: now,
          decelerationG: currentSample.netG,
          speedDropKmh: speedDelta > 0 ? speedDelta : preImpactSpeedKmh,
          source: 'sensor',
          latitude: _lastKnownLatitude,
          longitude: _lastKnownLongitude,
        );

        debugPrint('CRASH DETECTED by Sensor Rule Engine: $event');
        CrashEventService.instance.publish(event);
      }
    }
  }

  void dispose() {
    stop();
  }
}
