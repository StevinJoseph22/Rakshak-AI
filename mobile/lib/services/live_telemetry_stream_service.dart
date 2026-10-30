import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/backend_config.dart';
import 'crash_detector_service.dart';

/// Recorded action item capturing an on-device movement or event since app startup
class RecordedActionItem {
  final String id;
  final DateTime timestamp;
  final String actionType;
  final String label;
  final double peakG;
  final double speedKmh;
  final String details;
  final double? pitch;
  final double? roll;

  RecordedActionItem({
    required this.id,
    required this.timestamp,
    required this.actionType,
    required this.label,
    required this.peakG,
    required this.speedKmh,
    required this.details,
    this.pitch,
    this.roll,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'action_type': actionType,
    'label': label,
    'peak_g': peakG,
    'speed_kmh': speedKmh,
    'details': details,
    'pitch': pitch,
    'roll': roll,
  };
}

/// Instantaneous snapshot of live mobile hardware telemetry
class LiveTelemetrySnapshot {
  final DateTime timestamp;
  final double netG;
  final double ax;
  final double ay;
  final double az;
  final double gx;
  final double gy;
  final double gz;
  final double speedKmh;
  final double pitch;
  final double roll;
  final String activeAction;
  final bool isShaking;

  LiveTelemetrySnapshot({
    required this.timestamp,
    required this.netG,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    required this.speedKmh,
    required this.pitch,
    required this.roll,
    required this.activeAction,
    required this.isShaking,
  });
}

/// 24/7 Live Edge Telemetry Blackbox Service for Rakshak-AI.
/// Streams 50Hz IMU accelerations, gyros, speed, and classifies actions
/// (e.g., Phone Shake, Harsh Brake, Drop, Pothole, Impact) in real-time
/// to both the local Detection Lab and the centralized Web Dashboard!
class LiveTelemetryStreamService {
  LiveTelemetryStreamService._internal();
  static final LiveTelemetryStreamService _instance = LiveTelemetryStreamService._internal();
  static LiveTelemetryStreamService get instance => _instance;

  static const double _earthG = 9.80665;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  Timer? _streamTimer;
  io.Socket? _telemetrySocket;

  final ValueNotifier<LiveTelemetrySnapshot?> currentSnapshot = ValueNotifier(null);
  final ValueNotifier<RecordedActionItem?> lastRecordedAction = ValueNotifier(null);

  final List<RecordedActionItem> _actionHistory = [];
  List<RecordedActionItem> get actionHistory => List.unmodifiable(_actionHistory);

  // Latest raw values
  double _lastAx = 0.0;
  double _lastAy = 0.0;
  double _lastAz = 1.0;
  double _lastGx = 0.0;
  double _lastGy = 0.0;
  double _lastGz = 0.0;
  double _lastNetG = 1.0;

  // Shake detection rolling window
  final List<double> _recentNetG = [];
  DateTime _lastShakeRecordedAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastActionRecordedAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _currentClassifiedAction = 'Stationary / Idle';
  bool _isShaking = false;

  bool _isStarted = false;

  void start() {
    if (_isStarted) return;
    _isStarted = true;

    // Record initial action: App Opened
    recordAction(
      actionType: 'APP_LAUNCH',
      label: '🚀 App Launched & Telemetry Initialized',
      peakG: 1.0,
      details: 'On-device blackbox active. 50Hz sensor capture running.',
    );

    _initSocket();

    // 1. Ingest Accelerometer
    _accelSub = accelerometerEventStream().listen((event) {
      final axG = event.x / _earthG;
      final ayG = event.y / _earthG;
      final azG = event.z / _earthG;
      final netG = sqrt(axG * axG + ayG * ayG + azG * azG);

      _lastAx = axG;
      _lastAy = ayG;
      _lastAz = azG;
      _lastNetG = netG;

      _processKinematics(axG, ayG, azG, netG);
    });

    // 2. Ingest Gyroscope
    _gyroSub = gyroscopeEventStream().listen((event) {
      _lastGx = event.x;
      _lastGy = event.y;
      _lastGz = event.z;
    });

    // 3. Periodic broadcast to dashboard (5Hz = 200ms interval for optimal network smoothness)
    _streamTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _broadcastTelemetry();
    });
  }

  void stop() {
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _streamTimer?.cancel();
    _telemetrySocket?.disconnect();
    _telemetrySocket?.dispose();
    _isStarted = false;
  }

  void _initSocket() {
    try {
      final baseUrl = getBackendCandidates().first;
      _telemetrySocket = io.io(
        baseUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .build(),
      );

      _telemetrySocket?.onConnect((_) {
        debugPrint('[LiveTelemetry] Connected to backend telemetry socket at $baseUrl');
      });
    } catch (e) {
      debugPrint('[LiveTelemetry] Socket init note: $e');
    }
  }

  void _processKinematics(double ax, double ay, double az, double netG) {
    final now = DateTime.now();

    // Maintain 15-sample window (~300ms)
    _recentNetG.add(netG);
    if (_recentNetG.length > 15) {
      _recentNetG.removeAt(0);
    }

    final speedKmh = CrashDetectorService.instance.currentSpeedKmh;

    // Pitch and roll calculations in degrees
    final pitch = atan2(ay, sqrt(ax * ax + az * az)) * (180 / pi);
    final roll = atan2(-ax, az) * (180 / pi);

    // Calculate variance in current window
    double minG = _recentNetG.reduce(min);
    double maxG = _recentNetG.reduce(max);
    double rangeG = maxG - minG;

    // -------------------------------------------------------------------------
    // REAL-TIME ACTION CLASSIFICATION
    // -------------------------------------------------------------------------
    String actionLabel = 'Normal Motion';
    bool shaking = false;

    if (netG >= 4.8) {
      actionLabel = '🚨 CRASH IMPACT SPIKE (${netG.toStringAsFixed(2)}G)';
      if (now.difference(_lastActionRecordedAt).inMilliseconds > 2000) {
        _lastActionRecordedAt = now;
        recordAction(
          actionType: 'CRASH_IMPACT',
          label: '🚨 High-G Impact Detected (${netG.toStringAsFixed(2)}G)',
          peakG: netG,
          details: 'Deceleration spike breached 4.8G safety threshold!',
          pitch: pitch,
          roll: roll,
        );
      }
    } else if (rangeG >= 1.6 && speedKmh < 15.0) {
      // Vigorous phone shaking detected!
      actionLabel = '👋 PHONE SHAKE DETECTED (${maxG.toStringAsFixed(2)}G)';
      shaking = true;
      if (now.difference(_lastShakeRecordedAt).inMilliseconds > 1500) {
        _lastShakeRecordedAt = now;
        _lastActionRecordedAt = now;
        recordAction(
          actionType: 'PHONE_SHAKE',
          label: '👋 Phone Shaken by User (${maxG.toStringAsFixed(2)}G)',
          peakG: maxG,
          details: 'High-frequency manual agitation (peak-to-trough: ${rangeG.toStringAsFixed(2)}G).',
          pitch: pitch,
          roll: roll,
        );
      }
    } else if (netG < 0.25) {
      actionLabel = '🪂 FREE-FALL / DROP DETECTED';
      if (now.difference(_lastActionRecordedAt).inMilliseconds > 2000) {
        _lastActionRecordedAt = now;
        recordAction(
          actionType: 'FREE_FALL',
          label: '🪂 Phone Dropped / Near-0G (${netG.toStringAsFixed(2)}G)',
          peakG: netG,
          details: 'Sub-0.25G free-fall detected. Drop filter active.',
          pitch: pitch,
          roll: roll,
        );
      }
    } else if (speedKmh > 20.0 && rangeG > 1.2 && az.abs() > 1.5) {
      actionLabel = '⚠️ POTHOLE / ROAD BUMP';
      if (now.difference(_lastActionRecordedAt).inMilliseconds > 2000) {
        _lastActionRecordedAt = now;
        recordAction(
          actionType: 'POTHOLE',
          label: '⚠️ Pothole / Speed Bump Impulse (${maxG.toStringAsFixed(2)}G)',
          peakG: maxG,
          details: 'Transient vertical impulse while cruising at ${speedKmh.toStringAsFixed(1)} km/h.',
          pitch: pitch,
          roll: roll,
        );
      }
    } else if (rangeG < 0.08) {
      actionLabel = '🛑 Stationary / At Rest';
    } else if (speedKmh > 10.0) {
      actionLabel = '🚗 Smooth Vehicle Travel';
    } else {
      actionLabel = '📱 Gentle Handling';
    }

    _currentClassifiedAction = actionLabel;
    _isShaking = shaking;

    currentSnapshot.value = LiveTelemetrySnapshot(
      timestamp: now,
      netG: netG,
      ax: ax,
      ay: ay,
      az: az,
      gx: _lastGx,
      gy: _lastGy,
      gz: _lastGz,
      speedKmh: speedKmh,
      pitch: pitch,
      roll: roll,
      activeAction: actionLabel,
      isShaking: shaking,
    );
  }

  void recordAction({
    required String actionType,
    required String label,
    required double peakG,
    required String details,
    double? pitch,
    double? roll,
  }) {
    final speed = CrashDetectorService.instance.currentSpeedKmh;
    final item = RecordedActionItem(
      id: 'ACT-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      actionType: actionType,
      label: label,
      peakG: peakG,
      speedKmh: speed,
      details: details,
      pitch: pitch,
      roll: roll,
    );

    _actionHistory.insert(0, item);
    if (_actionHistory.length > 50) {
      _actionHistory.removeLast();
    }
    lastRecordedAction.value = item;

    // Immediately push action event to backend socket for zero-latency dashboard display
    _sendTelemetryPacket(item.label, isInstantAction: true);
  }

  void _broadcastTelemetry() {
    _sendTelemetryPacket(_currentClassifiedAction, isInstantAction: false);
  }

  void _sendTelemetryPacket(String actionLabel, {bool isInstantAction = false}) {
    if (_telemetrySocket == null || !_telemetrySocket!.connected) {
      // Re-attempt lazy socket reconnection
      final active = getBackendCandidates().first;
      if (_telemetrySocket == null) {
        _initSocket();
      }
      return;
    }

    final payload = {
      'device_id': 'CPH2573-MOBILE',
      'timestamp': DateTime.now().toIso8601String(),
      'net_g': double.parse(_lastNetG.toStringAsFixed(2)),
      'ax': double.parse(_lastAx.toStringAsFixed(2)),
      'ay': double.parse(_lastAy.toStringAsFixed(2)),
      'az': double.parse(_lastAz.toStringAsFixed(2)),
      'gx': double.parse(_lastGx.toStringAsFixed(2)),
      'gy': double.parse(_lastGy.toStringAsFixed(2)),
      'gz': double.parse(_lastGz.toStringAsFixed(2)),
      'speed_kmh': double.parse(CrashDetectorService.instance.currentSpeedKmh.toStringAsFixed(1)),
      'action_label': actionLabel,
      'is_shake': _isShaking,
      'is_instant_action': isInstantAction,
      'total_actions_recorded': _actionHistory.length,
    };

    _telemetrySocket?.emit('device_telemetry_live', payload);
  }
}
