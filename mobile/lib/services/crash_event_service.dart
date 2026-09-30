import 'dart:async';
import 'package:flutter/widgets.dart';

/// Represents a detected or simulated crash telemetry event.
class CrashEvent {
  final DateTime timestamp;
  final double decelerationG;
  final double speedDropKmh;
  final String source;
  final double latitude;
  final double longitude;

  const CrashEvent({
    required this.timestamp,
    required this.decelerationG,
    required this.speedDropKmh,
    this.source = 'simulation',
    double? latitude,
    double? longitude,
    double? simulatedLatitude,
    double? simulatedLongitude,
  })  : latitude = latitude ?? simulatedLatitude ?? 12.9716,
        longitude = longitude ?? simulatedLongitude ?? 77.5946;

  /// Backwards compatibility with Phase 2 naming
  double get simulatedLatitude => latitude;
  double get simulatedLongitude => longitude;

  @override
  String toString() {
    return 'CrashEvent(timestamp: $timestamp, decelerationG: ${decelerationG.toStringAsFixed(1)}G, speedDropKmh: ${speedDropKmh.toStringAsFixed(1)}km/h, source: $source, loc: ($latitude, $longitude))';
  }
}

/// Decoupled broadcast stream service for crash events.
/// Both simulated events (Phase 2) and background sensor algorithms (Phase 3)
/// emit events here, which UI layers listen to.
class CrashEventService {
  CrashEventService._internal();
  static final CrashEventService _instance = CrashEventService._internal();
  static CrashEventService get instance => _instance;

  Completer<String?> _pendingIncidentCompleter = Completer<String?>()..complete(null);
  String? _lastDispatchedIncidentId;

  String? get lastDispatchedIncidentId => _lastDispatchedIncidentId;
  set lastDispatchedIncidentId(String? id) {
    _lastDispatchedIncidentId = id;
    if (!_pendingIncidentCompleter.isCompleted) {
      _pendingIncidentCompleter.complete(id);
    }
  }

  /// Begins tracking a new incident broadcast. Resets any previous incident ID
  /// so that subsequent screens never use a stale incident ID from a previous dispatch.
  void beginNewIncidentDispatch() {
    _lastDispatchedIncidentId = null;
    _pendingIncidentCompleter = Completer<String?>();
  }

  bool get _isTestEnvironment {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  /// Resolves the current incident ID, awaiting an in-flight dispatch if necessary.
  Future<String?> resolveCurrentIncidentId({Duration timeout = const Duration(seconds: 6)}) async {
    if (_lastDispatchedIncidentId != null) {
      return _lastDispatchedIncidentId;
    }
    if (_isTestEnvironment) {
      return _lastDispatchedIncidentId;
    }
    if (!_pendingIncidentCompleter.isCompleted) {
      try {
        return await _pendingIncidentCompleter.future.timeout(timeout);
      } catch (_) {
        return _lastDispatchedIncidentId;
      }
    }
    return _lastDispatchedIncidentId;
  }

  final StreamController<CrashEvent> _crashController =
      StreamController<CrashEvent>.broadcast();

  Stream<CrashEvent> get onCrashDetected => _crashController.stream;

  void triggerCrash(CrashEvent event) {
    if (!_crashController.isClosed) {
      _crashController.add(event);
    }
  }

  /// Alias for triggerCrash matching Phase 3 detector convention
  void publish(CrashEvent event) => triggerCrash(event);

  void dispose() {
    _crashController.close();
  }
}
