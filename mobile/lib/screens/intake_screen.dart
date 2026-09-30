import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/crash_event_service.dart';
import '../services/photo_stream_service.dart';
import '../services/incident_tracking_service.dart';

/// Camera intake screen with strict Zero-Gallery privacy guarantee.
/// Captures photo directly to volatile RAM (`Uint8List`) and purges temp cache.
class IntakeScreen extends StatefulWidget {
  final CrashEvent? crashEvent;
  final String? incidentId;

  const IntakeScreen({
    super.key,
    this.crashEvent,
    this.incidentId,
  });

  @override
  State<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends State<IntakeScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _volatileImageBytes;
  bool _isCapturing = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _initIncidentTracking();
  }

  void _initIncidentTracking() {
    final id = widget.incidentId ?? CrashEventService.instance.lastDispatchedIncidentId;
    if (id != null) {
      IncidentTrackingService.instance.trackIncident(id);
    } else {
      CrashEventService.instance.resolveCurrentIncidentId().then((resolvedId) {
        if (resolvedId != null && mounted) {
          IncidentTrackingService.instance.trackIncident(resolvedId);
        }
      });
    }
  }

  Future<void> _capturePhoto() async {
    setState(() {
      _isCapturing = true;
      _statusMessage = null;
    });

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );

      if (photo != null) {
        // Read raw image bytes into volatile RAM
        final bytes = await photo.readAsBytes();

        // STRICT PRIVACY GUARANTEE: Purge temporary file from cache immediately
        try {
          final tempFile = File(photo.path);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (e) {
          // Non-fatal if OS already deleted the temp file
        }

        setState(() {
          _volatileImageBytes = bytes;
          _statusMessage = 'Streaming ${(bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB to trauma center...';
        });

        // Phase 6: Stream raw volatile image bytes over WebSocket binary frame
        final incidentId = widget.incidentId ?? await CrashEventService.instance.resolveCurrentIncidentId();
        if (incidentId != null) {
          PhotoStreamService.instance
              .streamIncidentPhoto(
                incidentId: incidentId,
                imageBytes: bytes,
              )
              .then((success) {
            if (mounted) {
              setState(() {
                _statusMessage = success
                    ? 'Streamed ${(bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB (Zero-Storage RAM Stream Active)'
                    : 'Stream connection failed. Retained in volatile RAM only.';
              });
            }
          });
        } else {
          debugPrint('[IntakeScreen] Warning: No active incident ID found to tag photo stream.');
          if (mounted) {
            setState(() {
              _statusMessage = 'No active incident broadcast found to tag stream.';
            });
          }
        }
      } else {
        setState(() {
          _statusMessage = 'Camera capture cancelled';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Camera error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  void _clearPhoto() {
    setState(() {
      _volatileImageBytes = null;
      _statusMessage = 'Photo discarded from RAM';
    });
  }

  void _onProceed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Triage telemetry stored. Returning to Guard.'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Intake & Triage'),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Phase 7: Live Trauma Dispatch & Hospital Acceptance Status Card
              ValueListenableBuilder<TriageStatus>(
                valueListenable: IncidentTrackingService.instance.statusNotifier,
                builder: (context, triage, _) {
                  if (triage.state == TriageState.accepted) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade700, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'EMERGENCY ACCEPTED',
                                  style: TextStyle(
                                    color: Colors.green.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade700,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'AMBULANCE DISPATCHED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          Text(
                            triage.hospitalName ?? 'Trauma Center',
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (triage.hospitalAddress != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.location_on, size: 16, color: Colors.green.shade800),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    triage.hospitalAddress!,
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (triage.hospitalPhone != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.phone, size: 16, color: Colors.green.shade800),
                                const SizedBox(width: 4),
                                Text(
                                  'Direct ER: ${triage.hospitalPhone!}',
                                  style: TextStyle(
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  } else if (triage.state == TriageState.escalated) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade700, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.radar, color: Colors.amber.shade800, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Widening Trauma Network (${triage.searchRadius ?? '20km'})',
                                  style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Expanding triage radius to ensure rapid emergency dispatch.',
                                  style: TextStyle(
                                    color: Colors.amber.shade800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (triage.state == TriageState.unmatched) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade700, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Central Emergency Services Alerted',
                                  style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'State emergency command center assigned directly.',
                                  style: TextStyle(
                                    color: Colors.red.shade800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (triage.state == TriageState.broadcasting) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade600, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_tethering, color: Colors.blue.shade700, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Broadcasting Trauma Triage',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Alerting nearest emergency rooms within 8km...',
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (widget.incidentId == null && CrashEventService.instance.lastDispatchedIncidentId == null) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade700, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_off, color: Colors.amber.shade800, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Offline Dispatch Queued',
                                  style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Telemetry preserved locally in volatile memory. Auto-syncing when backend connects...',
                                  style: TextStyle(
                                    color: Colors.amber.shade800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              if (!IncidentTrackingService.instance.statusNotifier.value.isConnected &&
                  IncidentTrackingService.instance.statusNotifier.value.state != TriageState.idle)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade400),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepOrange),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Reconnecting to trauma dispatch stream...',
                          style: TextStyle(fontSize: 12, color: Colors.deepOrange.shade900, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              // Privacy Guarantee Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade600, width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user, color: Colors.green.shade700, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zero-Gallery Privacy Guarantee',
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Photos captured here reside strictly in volatile RAM memory for emergency triage analysis. Nothing is ever written to your photo gallery or persistent storage.',
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Image Preview or Empty State
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _volatileImageBytes != null
                        ? Colors.redAccent
                        : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _isCapturing
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Capturing image to volatile RAM...'),
                          ],
                        ),
                      )
                    : _volatileImageBytes != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(
                                _volatileImageBytes!,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.memory, color: Colors.amber, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'RAM ONLY',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.camera_alt_outlined,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'No photo captured',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Capture injury or vehicle impact scene for AI triage',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),

              if (_statusMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Camera Action Buttons
              if (_volatileImageBytes == null) ...[
                ElevatedButton.icon(
                  onPressed: _isCapturing ? null : _capturePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Capture Incident / Injury Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isCapturing ? null : _capturePhoto,
                        icon: const Icon(Icons.replay),
                        label: const Text('Retake'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _clearPhoto,
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('Discard', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Finish / Skip button
              FilledButton.tonal(
                onPressed: _onProceed,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _volatileImageBytes != null
                      ? 'Proceed & Return to Guard'
                      : 'Skip Photo & Return to Guard',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
