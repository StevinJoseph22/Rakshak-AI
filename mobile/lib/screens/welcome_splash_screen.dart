import 'dart:async';
import 'package:flutter/material.dart';
import '../services/user_profile_service.dart';

class WelcomeSplashScreen extends StatefulWidget {
  final VoidCallback onContinue;

  const WelcomeSplashScreen({
    super.key,
    required this.onContinue,
  });

  @override
  State<WelcomeSplashScreen> createState() => _WelcomeSplashScreenState();
}

class _WelcomeSplashScreenState extends State<WelcomeSplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isInitDone = false;

  final List<Map<String, dynamic>> _checks = [
    {'title': '50Hz IMU Edge Sensing', 'sub': 'Microburst kinematic analysis active', 'done': false},
    {'title': 'GPS Live Coordinate Fix', 'sub': 'Banaswadi & Bengaluru road vector lock', 'done': false},
    {'title': 'C-V2X PC5 Direct Sidelink', 'sub': '5.9 GHz ITS Band emergency channel armed', 'done': false},
    {'title': '26 Regional Trauma Centers', 'sub': 'Level-1 apex hospital hotlines connected', 'done': false},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _runDiagnosticsSequence();
  }

  Future<void> _runDiagnosticsSequence() async {
    for (int i = 0; i < _checks.length; i++) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) {
        setState(() {
          _checks[i]['done'] = true;
        });
      }
    }
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _isInitDone = true;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _finishWelcome() {
    UserProfileService.instance.setWelcomeScreenSeen(true);
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Brand Header
              Column(
                children: [
                  const SizedBox(height: 20),
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626).withOpacity(0.5),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shield,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'RAKSHAK-AI',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Autonomous Road Crash Detection & Emergency Lifeline',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              // Diagnostics Checklist Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isInitDone ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isInitDone ? 'ALL LIFEGUARD SYSTEMS OPERATIONAL' : 'INITIALIZING SENSOR MESH...',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: _isInitDone ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ..._checks.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: Row(
                            children: [
                              Icon(
                                c['done'] ? Icons.check_circle : Icons.radio_button_unchecked,
                                size: 16,
                                color: c['done'] ? const Color(0xFF10B981) : Colors.grey,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c['title'] as String,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      c['sub'] as String,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),

              // Bottom Button
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _finishWelcome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'ENTER GUARDIAN DASHBOARD',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Zero-Touch Autonomous Guard • Ayushman Bharat (ABDM) Compatible',
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
