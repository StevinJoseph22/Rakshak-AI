import 'dart:async';
import 'package:flutter/material.dart';
import '../services/trip_sentinel_client_service.dart';

class CloudWatchdogSimulationDialog extends StatefulWidget {
  final VoidCallback? onDismiss;

  const CloudWatchdogSimulationDialog({super.key, this.onDismiss});

  @override
  State<CloudWatchdogSimulationDialog> createState() => _CloudWatchdogSimulationDialogState();
}

class _CloudWatchdogSimulationDialogState extends State<CloudWatchdogSimulationDialog> {
  int _countdownSeconds = 3;
  bool _isDispatched = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startSimulationSequence();
  }

  void _startSimulationSequence() {
    // 1. Immediately cut client heartbeat and notify backend
    TripSentinelClientService.instance.simulateCatastrophicPhoneBreakdown();

    // 2. Animate countdown to escalation
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() {
          if (_countdownSeconds > 1) {
            _countdownSeconds--;
          } else {
            _countdownSeconds = 0;
            _isDispatched = true;
            _timer?.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.purple, width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flash_off, color: Colors.purpleAccent, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cloud Watchdog Simulated',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      Text(
                        'Dead-Man Phone Breakdown Safeguard',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                children: [
                  _buildStatusRow(
                    label: 'Client Telemetry Heartbeat',
                    value: 'CUT OFF (0ms Phone Destruction)',
                    color: Colors.redAccent,
                    icon: Icons.cancel,
                  ),
                  const Divider(height: 16, color: Color(0xFF334155)),
                  _buildStatusRow(
                    label: 'Pre-Loss Travel Vector',
                    value: '92.4 km/h (Highway Speed Limit)',
                    color: Colors.amberAccent,
                    icon: Icons.speed,
                  ),
                  const Divider(height: 16, color: Color(0xFF334155)),
                  _buildStatusRow(
                    label: 'Cloud Dead-Man Escalator',
                    value: _isDispatched
                        ? 'ESCALATION COMPLETE (12s EXPIRED)'
                        : 'WATCHDOG GRACE COUNTDOWN: ${_countdownSeconds}s',
                    color: _isDispatched ? const Color(0xFF10B981) : Colors.purpleAccent,
                    icon: _isDispatched ? Icons.check_circle : Icons.timer,
                  ),
                  const Divider(height: 16, color: Color(0xFF334155)),
                  _buildStatusRow(
                    label: 'Police & Ambulance Dispatch',
                    value: _isDispatched ? 'AUTONOMOUS SOS BROADCAST ACTIVE' : 'PENDING SILENT TIMEOUT...',
                    color: _isDispatched ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                    icon: _isDispatched ? Icons.emergency : Icons.hourglass_top,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _isDispatched
                  ? '🛡️ Cloud Watchdog successfully confirmed catastrophic phone destruction without cellular transmission. Incident published to Police ITMS & nearest Apex Trauma center.'
                  : 'Simulating instant physical phone destruction at 92 km/h. Notice the server automatically triggers rescue dispatch even when client phone stops sending heartbeats.',
              style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1), height: 1.4),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onDismiss?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('DISMISS TEST HARNESS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
