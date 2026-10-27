import 'package:flutter/material.dart';

class AboutSystemDialog extends StatelessWidget {
  const AboutSystemDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => const AboutSystemDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 680),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.verified_user, color: Colors.blue.shade700, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About Rakshak-AI',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'System Claims & Verification Register',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
            const Divider(height: 20),

            // Scrollable Category Sections
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Section 1: Implemented
                    _buildCategoryCard(
                      title: '1. Implemented (Backed by Live Code & Tests)',
                      badgeColor: Colors.green.shade800,
                      badgeBg: Colors.green.shade50,
                      borderColor: Colors.green.shade200,
                      icon: Icons.check_circle_outline,
                      items: const [
                        'Smartphone IMU Multi-Axis Crash Telemetry (speed drop, peak G, rollover detection).',
                        'Geospatial 8km Radius Hospital Dispatch via PostGIS & Socket.IO.',
                        'Atomic Case Acceptance Lock (single-winner race-safe concurrency).',
                        'Server-Persisted Hospital Capabilities (real-time sync, 403 authorization scoping, non-blocking fallback matching).',
                        'Cryptographic Hash-Chained Audit Trail (SHA-256 links, database tamper-proof trigger, verify-chain endpoint).',
                        'Scoped Break-Glass Access (accepted cases only, 30-min window, mandatory licence ID + reason).',
                        'Real Native Emergency SMS via Android SmsManager to 3 emergency contacts.',
                        'Store-and-Forward Offline SQLite Retry Queue with exponential backoff.',
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Section 2: Simulated
                    _buildCategoryCard(
                      title: '2. Simulated (Mock Telemetry / Demo Flow)',
                      badgeColor: Colors.orange.shade900,
                      badgeBg: Colors.orange.shade50,
                      borderColor: Colors.orange.shade200,
                      icon: Icons.science_outlined,
                      items: const [
                        'C-V2X Green Corridor Signal Preemption (simulated timer and HUD for pilot and police).',
                        'Cloud Server Crash & Watchdog Heartbeat simulation.',
                        'Phone Breakdown / Battery Rip kill-switch simulation.',
                        'Central Inbound Telecom Gateway (+91-800-RAKSHAK); native SIM dispatches directly to personal emergency contacts.',
                        'Simulate CT Scan Down toggle in hospital dashboard.',
                        'ABHA Emergency Health Card in Mock ABDM mode.',
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Section 3: Roadmap
                    _buildCategoryCard(
                      title: '3. Roadmap (Production Hardware Clearances)',
                      badgeColor: Colors.blueGrey.shade800,
                      badgeBg: Colors.blueGrey.shade50,
                      borderColor: Colors.blueGrey.shade200,
                      icon: Icons.schedule_outlined,
                      items: const [
                        'Physical C-V2X 5.9 GHz PC5 Roadside Unit (RSU) intersection controllers.',
                        'Production ABDM Bridge credentials and national registry key exchange.',
                        'TRAI DLT-approved telecom inbound shortcode carrier aggregator.',
                        'Vehicle OBD-II / CAN-Bus hardwired airbag sensor telemetry.',
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Footer action
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('GOT IT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required Color badgeColor,
    required Color badgeBg,
    required Color borderColor,
    required IconData icon,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: badgeColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  Expanded(
                    child: Text(
                      it,
                      style: TextStyle(
                        fontSize: 11,
                        color: badgeColor.withValues(alpha: 0.9),
                        height: 1.3,
                      ),
                    ),
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
