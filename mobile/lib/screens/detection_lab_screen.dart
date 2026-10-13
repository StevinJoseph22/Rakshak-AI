import 'package:flutter/material.dart';
import '../services/detection_lab_engine.dart';

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
}
