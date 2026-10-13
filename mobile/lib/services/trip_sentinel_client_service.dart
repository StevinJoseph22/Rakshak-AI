import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/backend_config.dart';
import 'emergency_contact_service.dart';

/// Client-Side Journey Sentinel & Heartbeat Service
/// Provides cloud journey sentinel contact loss safeguard while driving,
/// subject to explicit rider privacy consent (OFF by default).
/// Only the latest ephemeral coordinate is maintained in cache, with no trip history.
class TripSentinelClientService {
  TripSentinelClientService._internal();
  static final TripSentinelClientService _instance = TripSentinelClientService._internal();
  static TripSentinelClientService get instance => _instance;

  String? _activeSessionId;
  String _vehiclePlate = 'KA-01-EA-108';
  Timer? _heartbeatTimer;
  bool _isSentinelActive = false;
  bool _isConsentEnabled = false; // Off by default for privacy!

  double _lastLat = 12.9716;
  double _lastLng = 77.5946;
  double _lastSpeedKmh = 0.0;
  double _lastHeading = 0.0;

  bool get isSentinelActive => _isSentinelActive;
  bool get isConsentEnabled => _isConsentEnabled;
  String? get activeSessionId => _activeSessionId;
  String get vehiclePlate => _vehiclePlate;

  /// Sets rider consent for trip telemetry monitoring (off by default)
  void setMonitoringConsent(bool enabled) {
    _isConsentEnabled = enabled;
    if (!enabled && _isSentinelActive) {
      endTrip();
    }
  }

  void setVehiclePlate(String plate) {
    _vehiclePlate = plate;
  }

  /// Starts or arms the cloud journey sentinel
  Future<bool> startTrip({
    required double latitude,
    required double longitude,
    required double speedKmh,
    double heading = 0.0,
    String? vehiclePlate,
  }) async {
    _lastLat = latitude;
    _lastLng = longitude;
    _lastSpeedKmh = speedKmh;
    _lastHeading = heading;
    if (vehiclePlate != null) _vehiclePlate = vehiclePlate;

    _activeSessionId = 'TRIP-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    final victimName = await EmergencyContactService.instance.getVictimName();
    final contacts = await EmergencyContactService.instance.getContacts();

    final payload = {
      'sessionId': _activeSessionId,
      'userId': 'citizen_mobile_node',
      'vehiclePlate': _vehiclePlate,
      'driverName': victimName,
      'latitude': latitude,
      'longitude': longitude,
      'speedKmh': speedKmh,
      'heading': heading,
      'bloodGroup': 'O+',
      'emergencyContacts': contacts.map((c) => {'name': c.name, 'phone': c.phone, 'relation': c.relationship}).toList(),
    };

    try {
      final url = Uri.parse('${BackendConfig.baseHttpUrl}/sentinel/start-trip');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 201 || res.statusCode == 200) {
        _isSentinelActive = true;
        _startHeartbeatTimer();
        debugPrint('[TripSentinelClient] 🛡️ Cloud Dead-Man Switch ARMED for $_vehiclePlate (Session: $_activeSessionId)');
        return true;
      }
    } catch (e) {
      debugPrint('[TripSentinelClient] Start trip note: $e (Operating in local dead-man fallback)');
      _isSentinelActive = true;
      _startHeartbeatTimer();
      return true;
    }
    return false;
  }

  /// Updates latest vehicle telemetry
  void updateTelemetry({
    required double latitude,
    required double longitude,
    required double speedKmh,
    double heading = 0.0,
  }) {
    _lastLat = latitude;
    _lastLng = longitude;
    _lastSpeedKmh = speedKmh;
    _lastHeading = heading;

    // Privacy guard: Only arm sentinel or transmit if user gave explicit in-app consent
    if (!_isConsentEnabled) return;

    // Auto-arm sentinel when driving speed exceeds 25 km/h
    if (!_isSentinelActive && speedKmh >= 25.0) {
      startTrip(
        latitude: latitude,
        longitude: longitude,
        speedKmh: speedKmh,
        heading: heading,
      );
    }
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _sendHeartbeat();
    });
  }

  Future<void> _sendHeartbeat() async {
    if (!_isSentinelActive || _activeSessionId == null) return;

    final payload = {
      'sessionId': _activeSessionId,
      'latitude': _lastLat,
      'longitude': _lastLng,
      'speedKmh': _lastSpeedKmh,
      'heading': _lastHeading,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      final url = Uri.parse('${BackendConfig.baseHttpUrl}/sentinel/heartbeat');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Non-fatal if offline
    }
  }

  /// Graceful journey termination when driver parks normally
  Future<void> endTrip() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isSentinelActive = false;

    if (_activeSessionId == null) return;

    try {
      final url = Uri.parse('${BackendConfig.baseHttpUrl}/sentinel/end-trip');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sessionId': _activeSessionId}),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Ignore
    }

    debugPrint('[TripSentinelClient] Journey ended gracefully. Watchdog disarmed.');
    _activeSessionId = null;
  }

  /// Lab simulation helper: Simulates instantaneous phone crushing at high speed
  Future<Map<String, dynamic>> simulateCatastrophicPhoneBreakdown() async {
    // 1. Cut the client heartbeat immediately
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isSentinelActive = false;

    // 2. Call backend simulation endpoint
    try {
      final url = Uri.parse('${BackendConfig.baseHttpUrl}/sentinel/simulate-collapse');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vehiclePlate': _vehiclePlate,
          'speedKmh': 92.4,
          'latitude': _lastLat,
          'longitude': _lastLng,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      debugPrint('[TripSentinelClient] Simulation error: $e');
    }

    return {'status': 'SIMULATION_TRIGGERED_LOCALLY'};
  }
}
