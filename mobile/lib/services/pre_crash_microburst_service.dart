import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'emergency_contact_service.dart';
import 'emergency_sms_service.dart';
import 'vehicle_obu_service.dart';
import 'api_client.dart';

/// Phone MEMS Accelerometer typical saturation threshold (~16.0 G).
/// Never claim measurements beyond this range as precise physical numbers;
/// flag them honestly as 'saturated'.
const double kAccelerometerSaturationLimitG = 16.0;

/// Phase 17: Pre-Alert & Suspected Impact Lifecycle Service
/// Repurposed from micro-burst: When an impact signature is flagged, IMMEDIATELY
/// dispatches a lightweight "impact_suspected" pre-alert (using a client-generated UUID
/// as an idempotency key) before the cancel countdown begins.
///
/// Visible ONLY to the police control room as a soft marker (does not alarm hospitals).
/// Promoted to full triage on countdown expiry/confirm; cancelled cleanly if rider taps OK.
class PreCrashMicroBurstService {
  PreCrashMicroBurstService._internal();
  static final PreCrashMicroBurstService _instance = PreCrashMicroBurstService._internal();
  static PreCrashMicroBurstService get instance => _instance;

  DateTime? _lastBurstFiredTime;
  bool _isBurstArmed = true;
  String? _currentSuspectedIncidentId;
  String? _currentIdempotencyKey;

  bool get isArmed => _isBurstArmed;
  String? get currentSuspectedIncidentId => _currentSuspectedIncidentId;
  String? get currentIdempotencyKey => _currentIdempotencyKey;

  void setArmed(bool armed) {
    _isBurstArmed = armed;
  }

  /// Generates a RFC-4122 compliant version 4 UUID without third-party dependencies.
  static String generateClientUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant 10xx
    final hexDigits = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hexDigits.sublist(0, 4).join()}-${hexDigits.sublist(4, 6).join()}-${hexDigits.sublist(6, 8).join()}-${hexDigits.sublist(8, 10).join()}-${hexDigits.sublist(10, 16).join()}';
  }

  /// Checks if a measured G-force reading reached or exceeded sensor saturation.
  static bool isGForceSaturated(double g) => g >= kAccelerometerSaturationLimitG;

  /// Sends immediate lightweight pre-alert before the cancel countdown starts.
  /// Deduplicated by client-generated UUID as idempotency key.
  Future<String> sendSuspectedImpact({
    required double latitude,
    required double longitude,
    required double speedKmh,
    required double netG,
    String? explicitId,
  }) async {
    final now = DateTime.now();

    // Prevent duplicate triggers within 8 seconds
    if (_lastBurstFiredTime != null &&
        now.difference(_lastBurstFiredTime!).inSeconds < 8) {
      return _currentSuspectedIncidentId ?? generateClientUuid();
    }
    _lastBurstFiredTime = now;

    final clientUuid = explicitId ?? generateClientUuid();
    _currentSuspectedIncidentId = clientUuid;
    _currentIdempotencyKey = clientUuid;

    final bool isSaturated = isGForceSaturated(netG);
    final clampedG = isSaturated ? kAccelerometerSaturationLimitG : netG;

    debugPrint(
      '[PreAlertService] ⚠️ SUSPECTED IMPACT DETECTED (${clampedG.toStringAsFixed(1)}G${isSaturated ? " [SATURATED]" : ""} @ ${speedKmh.toStringAsFixed(0)} km/h)\n'
      '[PreAlertService] Dispatching immediate soft pre-alert to Police radar (Client UUID: $clientUuid)...',
    );

    // 1. Local Flash Snapshot (Non-volatile crash freeze)
    _persistBlackboxSnapshot(latitude, longitude, speedKmh, clampedG, isSaturated, now, clientUuid);

    // 2. Local Direct Sidelink Beacon (Zero-internet direct broadcast)
    try {
      VehicleObuService.instance.transmitEmergencyDistressBeacon(
        latitude: latitude,
        longitude: longitude,
        speedKmh: speedKmh,
        gForce: clampedG,
      );
    } catch (e) {
      debugPrint('[PreAlertService] Sidelink note: $e');
    }

    // 3. Telephony Signaling SMS fallback for dead-zone penetration
    _dispatchSignalingSms(latitude, longitude, speedKmh, clampedG);

    // 4. Fast-Path Pre-Alert HTTP to Backend with status = 'suspected'
    _dispatchSuspectedPreAlert(
      id: clientUuid,
      lat: latitude,
      lng: longitude,
      speed: speedKmh,
      g: clampedG,
      isSaturated: isSaturated,
      timestamp: now,
    );

    return clientUuid;
  }

  /// Backwards-compatible alias for existing tests and call-sites
  Future<void> fireMicroBurst({
    required double latitude,
    required double longitude,
    required double speedKmh,
    required double netG,
  }) async {
    await sendSuspectedImpact(
      latitude: latitude,
      longitude: longitude,
      speedKmh: speedKmh,
      netG: netG,
    );
  }

  /// Confirms suspected incident when countdown expires or user taps confirm
  Future<bool> confirmSuspectedImpact() async {
    final incidentId = _currentSuspectedIncidentId;
    if (incidentId == null) return false;

    debugPrint('[PreAlertService] Promoting suspected incident $incidentId to full trauma triage...');
    try {
      final res = await ApiClient().confirmIncident(incidentId);
      return res.isSuccess;
    } catch (e) {
      debugPrint('[PreAlertService] Error confirming suspected incident: $e');
      return false;
    }
  }

  /// Cancels suspected incident when rider taps "I'm OK"
  Future<bool> cancelSuspectedImpact() async {
    final incidentId = _currentSuspectedIncidentId;
    if (incidentId == null) return false;

    debugPrint('[PreAlertService] User cancelled suspected incident $incidentId. Disarming...');
    _currentSuspectedIncidentId = null;
    _currentIdempotencyKey = null;

    try {
      final res = await ApiClient().cancelIncident(incidentId);
      return res.isSuccess;
    } catch (e) {
      debugPrint('[PreAlertService] Error cancelling suspected incident: $e');
      return false;
    }
  }

  /// Writes crash metadata to local non-volatile flash storage
  Future<void> _persistBlackboxSnapshot(
    double lat,
    double lng,
    double speed,
    double g,
    bool isSaturated,
    DateTime time,
    String id,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snapshot = 'SUSPECTED_IMPACT|$id|${time.toIso8601String()}|$lat|$lng|$speed|$g|saturated:$isSaturated';
      await prefs.setString('rakshak_blackbox_last_freeze', snapshot);
      debugPrint('[PreAlertService] Local Flash Blackbox committed for ID: $id');
    } catch (_) {
      // Non-fatal
    }
  }

  /// Dispatches signaling SMS over GSM control channels (works even with 0 internet data)
  Future<void> _dispatchSignalingSms(
    double lat,
    double lng,
    double speed,
    double g,
  ) async {
    try {
      final contacts = await EmergencyContactService.instance.getContacts();
      if (contacts.isEmpty) {
        return;
      }

      final smsBody = EmergencySmsService.instance.buildOfflineSignalingPayload(
        lat: lat,
        lng: lng,
        speedKmh: speed,
        gForce: g,
        bloodGroup: 'O+',
      );

      await EmergencySmsService.instance.sendRawSmsToContacts(
        contacts: contacts,
        message: smsBody,
      );
      debugPrint('[PreAlertService] Signaling SMS dispatched over GSM control channels.');
    } catch (e) {
      debugPrint('[PreAlertService] SMS dispatch note: $e');
    }
  }

  /// Fire-and-forget pre-alert HTTP packet to Rakshak Cloud backend with status = 'suspected'
  void _dispatchSuspectedPreAlert({
    required String id,
    required double lat,
    required double lng,
    required double speed,
    required double g,
    required bool isSaturated,
    required DateTime timestamp,
  }) {
    unawaited(() async {
      try {
        await ApiClient().reportIncident(
          id: id,
          latitude: lat,
          longitude: lng,
          status: 'suspected',
          victimMetadata: {
            'source': 'PRE_ALERT_SUSPECTED_IMPACT',
            'idempotency_key': id,
            'impact_g_force': g,
            'is_saturated': isSaturated,
            'speed_before_impact_kmh': speed,
            'timestamp': timestamp.toIso8601String(),
            'pre_alert_status': 'SUSPECTED_AWAITING_CONFIRMATION',
          },
        );
      } catch (_) {
        // Expected when completely offline
      }
    }());
  }
}
