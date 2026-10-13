/// Measured Crash Severity Index model.
/// Computed strictly from sensor features measurable on-device.
/// "decision-support estimate, not a clinical assessment"
class CrashSeverityIndex {
  static const String disclaimer = 'decision-support estimate, not a clinical assessment';

  final String level; // 'Minor' | 'Moderate' | 'Critical'
  final double measuredPeakG;
  final bool isSaturated;
  final double speedDropKmh;
  final int impactDurationMs;
  final bool rolloverSuspected;
  final bool riderUnresponsive;
  final int confidenceScore;
  final List<String> contributingFactors;

  const CrashSeverityIndex({
    required this.level,
    required this.measuredPeakG,
    required this.isSaturated,
    required this.speedDropKmh,
    required this.impactDurationMs,
    required this.rolloverSuspected,
    required this.riderUnresponsive,
    required this.confidenceScore,
    required this.contributingFactors,
  });

  Map<String, dynamic> toJson() => {
    'level': level,
    'measured_peak_g': measuredPeakG,
    'is_saturated': isSaturated,
    'speed_drop_kmh': speedDropKmh,
    'impact_duration_ms': impactDurationMs,
    'rollover_suspected': rolloverSuspected,
    'rider_unresponsive': riderUnresponsive,
    'confidence_score': confidenceScore,
    'contributing_factors': contributingFactors,
    'disclaimer': disclaimer,
  };

  /// Computes the Measured Crash Severity Index purely from verified on-device physical measurements.
  static CrashSeverityIndex compute({
    required double peakG,
    required double speedDropKmh,
    required bool isSaturated,
    required bool rolloverSuspected,
    required bool riderUnresponsive,
    required int confidenceScore,
    int impactDurationMs = 180,
  }) {
    final List<String> factors = [];

    if (isSaturated) {
      factors.add('Peak acceleration saturated sensor limit (>=16g)');
    } else {
      factors.add('Peak acceleration: ${peakG.toStringAsFixed(1)}g');
    }

    factors.add('Delta-V (speed drop): ${speedDropKmh.toStringAsFixed(1)} km/h');
    factors.add('Impact duration: ${impactDurationMs}ms');

    if (rolloverSuspected) {
      factors.add('Vehicle rollover / angular tumble detected');
    }

    if (riderUnresponsive) {
      factors.add('Rider unresponsive to on-screen/haptic prompts');
    } else {
      factors.add('Rider responsive (interaction logged)');
    }

    factors.add('Crash confidence score: $confidenceScore%');

    // Deterministic classification
    String severityLevel;
    if (riderUnresponsive && (peakG >= 10.0 || isSaturated || speedDropKmh >= 45.0 || rolloverSuspected)) {
      severityLevel = 'Critical';
    } else if (peakG >= 6.0 || speedDropKmh >= 25.0 || rolloverSuspected || riderUnresponsive) {
      severityLevel = 'Moderate';
    } else {
      severityLevel = 'Minor';
    }

    return CrashSeverityIndex(
      level: severityLevel,
      measuredPeakG: peakG,
      isSaturated: isSaturated,
      speedDropKmh: speedDropKmh,
      impactDurationMs: impactDurationMs,
      rolloverSuspected: rolloverSuspected,
      riderUnresponsive: riderUnresponsive,
      confidenceScore: confidenceScore,
      contributingFactors: factors,
    );
  }
}
