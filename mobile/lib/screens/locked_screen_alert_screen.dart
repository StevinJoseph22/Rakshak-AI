import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/crash_biomechanics_model.dart';
import '../models/crash_severity_model.dart';
import '../models/abha_emergency_vault_model.dart';
import '../models/emergency_health_card_model.dart';
import '../services/health_card_storage_service.dart';
import '../services/api_client.dart';
import '../services/crash_detector_service.dart';
import '../services/crash_event_service.dart';
import '../services/emergency_contact_service.dart';
import '../services/emergency_sms_service.dart';
import '../services/incident_tracking_service.dart';
import '../services/offline_dispatch_queue.dart';
import '../services/pre_crash_microburst_service.dart';
import 'intake_screen.dart';

/// Full-screen high-urgency alert screen with 10s countdown ring.
/// Triggered when crash signature is detected.
class LockedScreenAlertScreen extends StatefulWidget {
  final CrashEvent? crashEvent;
  final ApiClient? apiClient;

  const LockedScreenAlertScreen({
    super.key,
    this.crashEvent,
    this.apiClient,
  });

  @override
  State<LockedScreenAlertScreen> createState() => _LockedScreenAlertScreenState();
}

class _LockedScreenAlertScreenState extends State<LockedScreenAlertScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final ApiClient _apiClient;
  late final int _countdownDurationSeconds;
  bool _hasDispatched = false;
  bool _riderUnresponsive = true;
  EmergencyHealthCard? _healthCard;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _countdownDurationSeconds = widget.crashEvent?.adaptiveCountdownSeconds ?? 10;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: _countdownDurationSeconds),
    );

    HealthCardStorageService.instance.getHealthCard().then((c) {
      if (mounted) setState(() => _healthCard = c);
    });

    // Initial alert haptic vibration
    try {
      HapticFeedback.vibrate();
    } catch (_) {}

    _controller.addListener(() {
      setState(() {});
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onAutoDispatch();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    // Do not call _apiClient.dispose() here; the emergency incident broadcast is
    // an asynchronous operation that must complete in the background as the UI transitions.
    super.dispose();
  }

  void _onAutoDispatch() {
    if (!_hasDispatched && mounted) {
      _hasDispatched = true;
      _riderUnresponsive = true; // Auto-dispatch implies rider did not tap prompt within countdown
      _broadcastIncident();
      _navigateToNext();
    }
  }

  void _onConfirm() {
    if (!_hasDispatched) {
      _hasDispatched = true;
      _riderUnresponsive = false; // User actively interacted with prompt
      _controller.stop();
      _broadcastIncident();
      _navigateToNext();
    }
  }

  void _broadcastIncident() {
    // Reset previous incident ID to prevent race conditions or stale photo streaming
    CrashEventService.instance.beginNewIncidentDispatch();
    EmergencySmsService.instance.resetAlertHistory();

    final lat = widget.crashEvent?.latitude ?? CrashDetectorService.instance.lastKnownLatitude;
    final lng = widget.crashEvent?.longitude ?? CrashDetectorService.instance.lastKnownLongitude;

    final primaryContact = EmergencyContactService.instance.primaryContactSync;
    final victimName = EmergencyContactService.instance.victimNameSync;

    final decelG = widget.crashEvent?.decelerationG ?? 6.5;
    final isSaturated = widget.crashEvent?.isSaturated ?? (decelG >= 16.0);
    final speedDrop = widget.crashEvent?.speedDropKmh ?? 60.0;
    final rollover = widget.crashEvent?.rolloverSuspected ?? false;
    final confidence = widget.crashEvent?.confidenceScore ?? 85;

    final severityIndex = CrashSeverityIndex.compute(
      peakG: decelG,
      speedDropKmh: speedDrop,
      isSaturated: isSaturated,
      rolloverSuspected: rollover,
      riderUnresponsive: _riderUnresponsive,
      confidenceScore: confidence,
    );

    final biomechanics = CrashBiomechanics.generateSimulated(
      decelerationG: decelG,
      speedDropKmh: speedDrop,
    );
    final abhaVault = AbhaEmergencyVault.defaultProfile();

    final metadata = {
      'vehicle_type': 'Two-Wheeler',
      'rider_status': _riderUnresponsive
          ? 'SOS Active (Unresponsive to prompt)'
          : 'SOS Active (Rider responsive)',
      'rider_unresponsive': _riderUnresponsive,
      'deceleration_g': decelG,
      'deceleration_saturated': isSaturated,
      'speed_drop_kmh': speedDrop,
      'confidence_score': confidence,
      'severity_index': severityIndex.toJson(),
      'source': widget.crashEvent?.source ?? 'locked_screen_alert',
      'timestamp': (widget.crashEvent?.timestamp ?? DateTime.now()).toIso8601String(),
      'victim_name': victimName,
      'biomechanics': {
        ...biomechanics.toJson(),
        'is_simulated_illustrative': true,
        'label': 'Illustrative / Simulated Model',
      },
      'abha_vault': abhaVault.toJson(),
      if (primaryContact != null) ...{
        'emergency_contact_name': primaryContact.name,
        'emergency_contact_phone': primaryContact.phone,
        'emergency_contact_relationship': primaryContact.relationship,
      },
    };

    final clientIncidentId = PreCrashMicroBurstService.instance.currentSuspectedIncidentId;

    final cardJson = (_healthCard ?? EmergencyHealthCard.empty()).toJson();

    // Auto-broadcast alert to backend (idempotently promotes suspected incident to broadcasting)
    _apiClient.reportIncident(
      id: clientIncidentId,
      status: 'broadcasting',
      latitude: lat,
      longitude: lng,
      victimMetadata: metadata,
      healthCard: cardJson,
    ).then((result) {
      if (result.isSuccess) {
        final incidentId = result.data?.incident.id;
        CrashEventService.instance.lastDispatchedIncidentId = incidentId;
        if (incidentId != null) {
          IncidentTrackingService.instance.trackIncident(incidentId);
        }
        debugPrint('Successfully broadcast incident $incidentId to backend');
      } else {
        CrashEventService.instance.lastDispatchedIncidentId = null;
        debugPrint('Incident broadcast queued / offline fallback: ${result.errorMessage}');
        final fallbackId = clientIncidentId ?? PreCrashMicroBurstService.generateClientUuid();
        OfflineDispatchQueue.instance.enqueue(
          id: fallbackId,
          latitude: lat,
          longitude: lng,
          victimMetadata: metadata,
          healthCard: cardJson,
          originalTimestamp: (widget.crashEvent?.timestamp ?? DateTime.now()).toIso8601String(),
        );
      }
    });

    // Auto-dispatch SMS alert to registered emergency contacts (Real SIM SmsManager or WhatsApp fallback)
    EmergencySmsService.instance.sendCrashAlert(
      lat: lat,
      lng: lng,
      context: mounted ? context : null,
    );
  }

  void _navigateToNext() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => IntakeScreen(
          crashEvent: widget.crashEvent,
        ),
      ),
    );
  }

  void _onCancel() {
    // Full abort: cancel animation, flag as dispatched to prevent late callbacks
    _hasDispatched = true;
    _controller.stop();
    PreCrashMicroBurstService.instance.cancelSuspectedImpact();
    _apiClient.dispose();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final double remainingFraction = 1.0 - _controller.value;
    final int remainingSeconds = (_countdownDurationSeconds * remainingFraction).ceil();

    return Scaffold(
      backgroundColor: const Color(0xFF1A0000), // Deep emergency dark red
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
              // Top alert banner
              Column(
                children: [
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.redAccent, width: 1.5),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'EMERGENCY SOS TRIGGERED',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'CRASH DETECTED',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'TAP TO ALERT AMBULANCE & POLICE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  if (widget.crashEvent != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Telemetry: ${widget.crashEvent!.decelerationG.toStringAsFixed(1)}G drop | ${widget.crashEvent!.speedDropKmh.toStringAsFixed(0)} km/h delta',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),

              // Center: 10-second countdown circular indicator
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          value: remainingFraction,
                          strokeWidth: 8,
                          backgroundColor: Colors.red.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            remainingSeconds <= 3 ? Colors.redAccent : Colors.amberAccent,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$remainingSeconds',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                              color: remainingSeconds <= 3 ? Colors.redAccent : Colors.white,
                            ),
                          ),
                          const Text(
                            'SECONDS',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Broadcasting alert to nearest trauma centers\nif no response is received.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Ayushman Bharat (ABDM / ABHA) Emergency Health Card Chip
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF0EA5E9), width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user, color: Color(0xFF38BDF8), size: 20),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _healthCard?.isLinked == true
                                    ? 'ABHA: ${_healthCard!.abhaAddress.value ?? "Linked"} (${_healthCard!.bloodGroup.isAvailable ? _healthCard!.bloodGroup.value : "Verified Identity"})'
                                    : 'Emergency Health Card: ${_healthCard?.bloodGroup.isAvailable == true ? _healthCard!.bloodGroup.value! : "Self-Declared"}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _healthCard?.allergies.isAvailable == true && _healthCard!.allergies.value!.isNotEmpty
                                    ? '⚠️ ${_healthCard!.allergies.value!.join(" • ")}'
                                    : (_healthCard?.isLinked == true
                                        ? 'ABDM Verified Identity • Volatile RAM (2h TTL)'
                                        : 'Self-Declared • Shared strictly upon crash claim'),
                                style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Bottom Actions
              Column(
                children: [
                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _onConfirm,
                      icon: const Icon(Icons.emergency, color: Colors.white, size: 28),
                      label: const Text(
                        'CONFIRM & DISPATCH HELP NOW',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // I'm okay / cancel button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _onCancel,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white38, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "I'm Okay — Cancel SOS",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
