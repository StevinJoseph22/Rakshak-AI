import 'dart:async';
import 'package:flutter/material.dart';
import '../services/crash_detector_service.dart';
import '../services/crash_event_service.dart';
import 'locked_screen_alert_screen.dart';

/// Authentic simulated Android lock screen for reliable live judging demonstrations.
/// Simulates the device being locked and proves the bystander override takeover.
class SimulatedLockScreen extends StatefulWidget {
  const SimulatedLockScreen({super.key});

  @override
  State<SimulatedLockScreen> createState() => _SimulatedLockScreenState();
}

class _SimulatedLockScreenState extends State<SimulatedLockScreen> {
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();
  bool _isTriggeringImpact = false;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  void _triggerBystanderOverride() async {
    setState(() {
      _isTriggeringImpact = true;
    });

    // Brief 500ms flash/impact haptic delay
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final event = CrashEvent(
      timestamp: DateTime.now(),
      decelerationG: 7.8,
      speedDropKmh: 75.0,
      source: 'bystander_simulation',
      latitude: CrashDetectorService.instance.lastKnownLatitude,
      longitude: CrashDetectorService.instance.lastKnownLongitude,
    );

    // Publish to the common CrashEventService pipeline
    CrashEventService.instance.publish(event);

    // Transition directly into LockedScreenAlertScreen over the locked view
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => LockedScreenAlertScreen(crashEvent: event),
      ),
    );
  }

  String _formatTwoDigits(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final hour = _formatTwoDigits(_currentTime.hour);
    final minute = _formatTwoDigits(_currentTime.minute);

    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    final dayName = dayNames[_currentTime.weekday - 1];
    final monthName = monthNames[_currentTime.month - 1];
    final dateStr = '$dayName, $monthName ${_currentTime.day}';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradient Wallpaper
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF020617),
                  Colors.black,
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Status / Demo Indicator Banner
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, color: Colors.white70, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'DEVICE LOCKED • DEMO BYSTANDER VIEW',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Lock Icon & Large Digital Clock
                      const Icon(Icons.lock_outline, color: Colors.white54, size: 36),
                      const SizedBox(height: 16),
                      Text(
                        '$hour:$minute',
                        style: const TextStyle(
                          fontSize: 76,
                          fontWeight: FontWeight.w200,
                          color: Colors.white,
                          letterSpacing: -2,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),

                  // Middle: Impact Simulation Trigger Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sensors_off, color: Colors.amberAccent, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Phone in Pocket / Locked Screen',
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Test the bystander override: simulate an impact while the device is locked.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isTriggeringImpact ? null : _triggerBystanderOverride,
                            icon: const Icon(Icons.flash_on, color: Colors.white),
                            label: Text(
                              _isTriggeringImpact
                                  ? 'TRIGGERING OVERRIDE...'
                                  : 'SIMULATE CRASH IMPACT NOW',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom: Unlock hint and Exit Demo button
                  Column(
                    children: [
                      const Text(
                        'Swipe up to unlock',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'Exit Lock Screen Simulation',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
