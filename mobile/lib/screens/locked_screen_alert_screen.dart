import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/crash_detector_service.dart';
import '../services/crash_event_service.dart';
import '../services/emergency_contact_service.dart';
import '../services/emergency_sms_service.dart';
import '../services/incident_tracking_service.dart';
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
  static const int _countdownDurationSeconds = 10;
  bool _hasDispatched = false;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _countdownDurationSeconds),
    );

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
      _broadcastIncident();
      _navigateToNext();
    }
  }

  void _onConfirm() {
    if (!_hasDispatched) {
      _hasDispatched = true;
      _controller.stop();
      _broadcastIncident();
      _navigateToNext();
    }
  }

  void _broadcastIncident() {
    // Reset previous incident ID to prevent race conditions or stale photo streaming
    CrashEventService.instance.beginNewIncidentDispatch();

    final lat = widget.crashEvent?.latitude ?? CrashDetectorService.instance.lastKnownLatitude;
    final lng = widget.crashEvent?.longitude ?? CrashDetectorService.instance.lastKnownLongitude;

    // Privacy note: Emergency contact data is the victim's own chosen contact,
    // stored locally on-device and only sent alongside an actual confirmed incident dispatch
    // via victim_metadata. It is never stored in a standalone contacts table or cached
    // in Redis alongside temporary photos.
    final primaryContact = EmergencyContactService.instance.primaryContactSync;
    final victimName = EmergencyContactService.instance.victimNameSync;

    final metadata = {
      'vehicle_type': 'Two-Wheeler',
      'rider_status': 'SOS Active (Unresponsive)',
      'deceleration_g': widget.crashEvent?.decelerationG ?? 6.5,
      'speed_drop_kmh': widget.crashEvent?.speedDropKmh ?? 60.0,
      'source': widget.crashEvent?.source ?? 'locked_screen_alert',
      'timestamp': (widget.crashEvent?.timestamp ?? DateTime.now()).toIso8601String(),
      'victim_name': victimName,
      if (primaryContact != null) ...{
        'emergency_contact_name': primaryContact.name,
        'emergency_contact_phone': primaryContact.phone,
        'emergency_contact_relationship': primaryContact.relationship,
      },
    };

    // Auto-broadcast alert to backend
    _apiClient.reportIncident(
      latitude: lat,
      longitude: lng,
      victimMetadata: metadata,
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top alert banner
              Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.redAccent, width: 1.5),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'EMERGENCY SOS TRIGGERED',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
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
                        width: 180,
                        height: 180,
                        child: CircularProgressIndicator(
                          value: remainingFraction,
                          strokeWidth: 10,
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
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: remainingSeconds <= 3 ? Colors.redAccent : Colors.white,
                            ),
                          ),
                          const Text(
                            'SECONDS',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              letterSpacing: 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Broadcasting alert to nearest trauma centers\nif no response is received.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
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
  }
}
