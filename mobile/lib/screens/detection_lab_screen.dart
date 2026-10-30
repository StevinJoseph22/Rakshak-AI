import 'package:flutter/material.dart';
import '../services/detection_lab_engine.dart';
import '../services/live_telemetry_stream_service.dart';

/// Detection Lab Screen providing interactive algorithmic verification across 7 canonical
/// synthetic scenarios. Essential for technical presentations, hackathon pitches, and testing.
class DetectionLabScreen extends StatefulWidget {
  const DetectionLabScreen({super.key});

  @override
  State<DetectionLabScreen> createState() => _DetectionLabScreenState();
}

class _DetectionLabScreenState extends State<DetectionLabScreen> {
  DetectionLabSuiteSummary? _summary;
  bool _isRunning = false;
  String? _selectedScenarioId;

  @override
  void initState() {
    super.initState();
    _runSuite();
  }

  void _runSuite() {
    setState(() {
      _isRunning = true;
    });
    // Brief async delay for smooth UI transition
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _summary = DetectionLabEngine.runFullSuite();
        _isRunning = false;
        if (_selectedScenarioId == null && _summary!.results.isNotEmpty) {
          _selectedScenarioId = _summary!.results.first.scenarioId;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Detection Lab — Evidence Suite',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.blueAccent),
            tooltip: 'Re-run Detection Suite',
            onPressed: _isRunning ? null : _runSuite,
          ),
        ],
      ),
      body: _isRunning
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.blueAccent),
                  SizedBox(height: 16),
                  Text(
                    'Replaying synthetic sensor waveforms...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 0. Live Real-Time Hardware Blackbox & Shake Recorder
                  _buildLiveHardwareRecorder(),
                  const SizedBox(height: 20),

                  // 1. Mandatory Ground-Truth Scientific Disclaimer
                  _buildGroundTruthDisclaimer(),
                  const SizedBox(height: 16),

                  // 2. Summary Confusion Metrics
                  if (_summary != null) _buildSummaryMetrics(_summary!),
                  const SizedBox(height: 20),

                  // 3. Scenario Results Table / Cards
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SCRIPTED TEST SCENARIOS',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        '${_summary?.totalAccurate ?? 0}/${_summary?.totalScenarios ?? 0} Passed',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_summary != null) ..._summary!.results.map(_buildScenarioCard),
                ],
              ),
            ),
    );
  }

  Widget _buildGroundTruthDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.science_outlined, color: Colors.amberAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Algorithmic Verification Methodology',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• Scenarios are scripted synthetic sensor waveforms, NOT real-world crash telemetry.\n'
            '• Phone MEMS accelerometers saturate typically at 16g. Any reading crossing this limit is marked saturated rather than fabricating unmeasurable forces.\n'
            '• All confidence scores and severity tiers are decision-support estimates, not clinical assessments.',
            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetrics(DetectionLabSuiteSummary summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Classifier Performance Suite',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: summary.accuracyPercentage >= 100
                      ? const Color(0xFF065F46)
                      : const Color(0xFF854D0E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${summary.accuracyPercentage.toStringAsFixed(0)}% Accuracy',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Total Scenarios',
                  value: '${summary.totalScenarios}',
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'False Positives',
                  value: '${summary.falsePositives}',
                  color: summary.falsePositives == 0 ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'False Negatives',
                  value: '${summary.falseNegatives}',
                  color: summary.falseNegatives == 0 ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioCard(DetectionLabResult result) {
    final bool match = result.isAccurate;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: match ? const Color(0xFF334155) : Colors.redAccent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: result.expectedCrash
                      ? const Color(0xFF7F1D1D)
                      : const Color(0xFF14532D),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  result.expectedCrash ? Icons.car_crash : Icons.shield_outlined,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.scenarioName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.filterReason,
                      style: TextStyle(
                        color: result.detectedCrash ? Colors.redAccent : Colors.tealAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: match ? const Color(0xFF065F46) : const Color(0xFF7F1D1D),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  match ? 'PASS' : 'FAIL',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Signals and contributing factors
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildBadge(
                label: 'Peak G: ${result.peakDecelerationG.toStringAsFixed(1)}g',
                isFlagged: result.isSaturated,
                flagText: 'SATURATED (≥16g)',
              ),
              _buildBadge(
                label: 'Speed Drop: ${result.speedDropKmh.toStringAsFixed(0)} km/h',
                isFlagged: false,
              ),
              if (result.preImpactFreeFall)
                _buildBadge(
                  label: 'Free-Fall Prior: -50 pts (Drop Penalty)',
                  isFlagged: true,
                  flagColor: Colors.orangeAccent,
                ),
              if (result.rolloverSuspected)
                _buildBadge(
                  label: 'Rollover: Gyro >3.5 rad/s',
                  isFlagged: true,
                  flagColor: Colors.purpleAccent,
                ),
              _buildBadge(
                label: 'Confidence: ${result.confidenceScore}/100 (${result.confidenceLevel})',
                isFlagged: result.detectedCrash,
                flagColor: Colors.redAccent,
              ),
              _buildBadge(
                label: 'Adaptive Countdown: ${result.adaptiveCountdownSeconds}s',
                isFlagged: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required bool isFlagged,
    String? flagText,
    Color? flagColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isFlagged
            ? (flagColor ?? Colors.redAccent).withOpacity(0.15)
            : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isFlagged
              ? (flagColor ?? Colors.redAccent)
              : const Color(0xFF334155),
        ),
      ),
      child: Text(
        isFlagged && flagText != null ? flagText : label,
        style: TextStyle(
          color: isFlagged ? (flagColor ?? Colors.redAccent) : const Color(0xFFCBD5E1),
          fontSize: 11,
          fontWeight: isFlagged ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // ===========================================================================
  // LIVE REAL-TIME HARDWARE BLACKBOX & SHAKE EVENT RECORDER
  // ===========================================================================

  Widget _buildLiveHardwareRecorder() {
    return ValueListenableBuilder<LiveTelemetrySnapshot?>(
      valueListenable: LiveTelemetryStreamService.instance.currentSnapshot,
      builder: (context, snapshot, _) {
        final netG = snapshot?.netG ?? 1.0;
        final ax = snapshot?.ax ?? 0.0;
        final ay = snapshot?.ay ?? 0.0;
        final az = snapshot?.az ?? 1.0;
        final speed = snapshot?.speedKmh ?? 0.0;
        final actionLabel = snapshot?.activeAction ?? 'Stationary / Idle';
        final isShaking = snapshot?.isShaking ?? false;

        final Color gaugeColor = netG >= 4.8
            ? const Color(0xFFEF4444)
            : isShaking || netG >= 2.0
                ? const Color(0xFFF59E0B)
                : netG >= 1.4
                    ? const Color(0xFF38BDF8)
                    : const Color(0xFF10B981);

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isShaking
                  ? const Color(0xFFF59E0B)
                  : netG >= 4.8
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF334155),
              width: isShaking || netG >= 4.8 ? 2.0 : 1.2,
            ),
            boxShadow: isShaking
                ? [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: gaugeColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.sensors, color: gaugeColor, size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'LIVE 50Hz HARDWARE BLACKBOX',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: Color(0xFF10B981)),
                        SizedBox(width: 5),
                        Text(
                          'STREAMING LIVE',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Main Live G-Force & Speed Row
              Row(
                children: [
                  // Net G-Force Primary Indicator
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: gaugeColor.withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NET ACCELERATION',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                netG.toStringAsFixed(2),
                                style: TextStyle(
                                  color: gaugeColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'G',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (netG / 6.0).clamp(0.0, 1.0),
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // GPS Speed Gauge
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GPS SPEED',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                speed.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Text(
                                'km/h',
                                style: TextStyle(color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            speed > 0 ? 'In Motion' : 'Stopped',
                            style: TextStyle(
                              color: speed > 0 ? const Color(0xFF38BDF8) : Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Tri-Axial Breakdown Chips
              Row(
                children: [
                  Expanded(
                    child: _buildAxisChip('Ax (Lateral)', ax, const Color(0xFFF97316)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildAxisChip('Ay (Longit)', ay, const Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildAxisChip('Az (Vert/1G)', az, const Color(0xFFA855F7)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Active Action Classifier Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isShaking
                      ? const Color(0xFFF59E0B).withOpacity(0.2)
                      : netG >= 4.8
                          ? const Color(0xFFEF4444).withOpacity(0.2)
                          : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isShaking
                        ? const Color(0xFFF59E0B)
                        : netG >= 4.8
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF334155),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isShaking
                          ? Icons.vibration
                          : netG >= 4.8
                              ? Icons.warning
                              : Icons.directions_run,
                      size: 18,
                      color: gaugeColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        actionLabel,
                        style: TextStyle(
                          color: isShaking ? const Color(0xFFFCD34D) : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isShaking)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'SHAKING',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Actions Recorded History Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ACTIONS RECORDED SINCE APP OPEN',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    '${LiveTelemetryStreamService.instance.actionHistory.length} Events Logged',
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Action History List (Top 5 most recent)
              ValueListenableBuilder<RecordedActionItem?>(
                valueListenable: LiveTelemetryStreamService.instance.lastRecordedAction,
                builder: (context, _, __) {
                  final history = LiveTelemetryStreamService.instance.actionHistory;
                  if (history.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Open app, shake device, or brake to record actions.',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    );
                  }

                  return Column(
                    children: history.take(4).map((item) {
                      final timeStr =
                          '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}:${item.timestamp.second.toString().padLeft(2, '0')}';
                      final isShake = item.actionType == 'PHONE_SHAKE';
                      final isImpact = item.actionType == 'CRASH_IMPACT';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isShake
                                ? const Color(0xFFF59E0B).withOpacity(0.5)
                                : isImpact
                                    ? const Color(0xFFEF4444).withOpacity(0.5)
                                    : const Color(0xFF334155),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              timeStr,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  color: isShake
                                      ? const Color(0xFFFCD34D)
                                      : isImpact
                                          ? const Color(0xFFF87171)
                                          : Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isShake
                                        ? const Color(0xFFF59E0B)
                                        : isImpact
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFF38BDF8))
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${item.peakG.toStringAsFixed(2)}G',
                                style: TextStyle(
                                  color: isShake
                                      ? const Color(0xFFFCD34D)
                                      : isImpact
                                          ? const Color(0xFFF87171)
                                          : const Color(0xFF38BDF8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 8),

              // Interactive Trigger Shake Test Button for Evaluators
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        LiveTelemetryStreamService.instance.recordAction(
                          actionType: 'PHONE_SHAKE',
                          label: '👋 Manual Test Shake Injected (3.40G)',
                          peakG: 3.40,
                          details: 'Simulated 3.4G shake trigger recorded for evaluators.',
                        );
                      },
                      icon: const Icon(Icons.vibration, size: 14, color: Color(0xFFF59E0B)),
                      label: const Text(
                        'Simulate Shake Test',
                        style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFF59E0B)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        LiveTelemetryStreamService.instance.recordAction(
                          actionType: 'CRASH_IMPACT',
                          label: '🚨 5.80G Impact Signature Injected',
                          peakG: 5.80,
                          details: 'Simulated 5.8G impact spike recorded for evaluators.',
                        );
                      },
                      icon: const Icon(Icons.bolt, size: 14, color: Color(0xFFEF4444)),
                      label: const Text(
                        'Simulate Impact Spike',
                        style: TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAxisChip(String title, double val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 8.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            '${val >= 0 ? "+" : ""}${val.toStringAsFixed(2)}G',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
