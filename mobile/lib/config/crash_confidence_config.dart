import 'dart:math';

/// Configuration, weights, and transparent scoring engine for Crash Confidence.
/// Strictly grounded in measurable phone sensor limits (MEMS accelerometer saturation at 16g).
class CrashConfidenceConfig {
  /// Commercial phone MEMS accelerometers saturate typically between 8g - 16g.
  /// Readings at or above this limit must be flagged as "saturated".
  static const double kAccelerometerSaturationLimitG = 16.0;

  // Thresholds for sensor feature extraction
  static const double kFreeFallGThreshold = 0.35; // Total gravity below 0.35g
  static const int kFreeFallMinDurationMs = 100;   // Free-fall duration > 100ms
  static const double kStillnessVarianceMaxG = 0.20; // Post-impact accel variance
  static const double kStillnessGyroMaxRad = 0.60;   // Post-impact gyro variance
  static const double kRolloverGyroThresholdRad = 3.5; // High rotation rate in rad/s
  static const double kSignificantSpeedDropKmh = 25.0;

  // Factor weights (Nominal maximum sum = 100)
  static const int weightSpeedDrop = 30;
  static const int weightImpactIntensity = 25;
  static const int weightPostImpactStillness = 20;
  static const int weightPostImpactSpeedZero = 15;
  static const int weightRollover = 10;

  // Penalty factors
  /// If phone experienced free-fall immediately before impact, it strongly argues
  /// the phone was dropped from hand/pocket/mount rather than a vehicular crash.
  static const int penaltyPreImpactFreeFall = 50;

  // Adaptive countdown thresholds
  static const int thresholdHighConfidence = 80;
  static const int thresholdModerateConfidence = 50;

  static const int countdownHighConfidenceSeconds = 5;
  static const int countdownModerateConfidenceSeconds = 10;
  static const int countdownLowConfidenceSeconds = 15;
}

/// Detailed transparent breakdown of evidence contributing to crash confidence.
class CrashConfidenceResult {
  final int score; // 0 to 100
  final String confidenceLevel; // 'High' | 'Moderate' | 'Low'
  final int adaptiveCountdownSeconds;
  final bool isSaturated;
  final bool preImpactFreeFall;
  final bool rolloverSuspected;
  final bool postImpactStillness;
  final bool speedDropValidated;
  final Map<String, dynamic> factorBreakdown;

  const CrashConfidenceResult({
    required this.score,
    required this.confidenceLevel,
    required this.adaptiveCountdownSeconds,
    required this.isSaturated,
    required this.preImpactFreeFall,
    required this.rolloverSuspected,
    required this.postImpactStillness,
    required this.speedDropValidated,
    required this.factorBreakdown,
  });

  Map<String, dynamic> toJson() => {
    'confidence_score': score,
    'confidence_level': confidenceLevel,
    'adaptive_countdown_seconds': adaptiveCountdownSeconds,
    'is_saturated': isSaturated,
    'pre_impact_free_fall': preImpactFreeFall,
    'rollover_suspected': rolloverSuspected,
    'post_impact_stillness': postImpactStillness,
    'speed_drop_validated': speedDropValidated,
    'factor_breakdown': factorBreakdown,
  };

  /// Computes transparent confidence score from measured sensor observations.
  static CrashConfidenceResult compute({
    required double measuredPeakG,
    required double speedDropKmh,
    required double postImpactSpeedKmh,
    required bool preImpactFreeFall,
    required bool postImpactStillness,
    required bool rolloverSuspected,
    double? barometerDeltaHpa,
  }) {
    final bool isSaturated = measuredPeakG >= CrashConfidenceConfig.kAccelerometerSaturationLimitG;
    final double effectiveG = isSaturated
        ? CrashConfidenceConfig.kAccelerometerSaturationLimitG
        : measuredPeakG;

    int points = 0;
    final Map<String, dynamic> breakdown = {};

    // 1. Speed drop factor (up to 30 pts)
    final bool speedDropOk = speedDropKmh >= CrashConfidenceConfig.kSignificantSpeedDropKmh;
    final int speedDropPts = (min(speedDropKmh / 50.0, 1.0) * CrashConfidenceConfig.weightSpeedDrop).round();
    points += speedDropPts;
    breakdown['speed_drop'] = {
      'measured_drop_kmh': speedDropKmh,
      'points_awarded': speedDropPts,
      'max_points': CrashConfidenceConfig.weightSpeedDrop,
    };

    // 2. Impact intensity factor (up to 25 pts)
    final int impactPts = (min((effectiveG - 4.0) / 8.0, 1.0) * CrashConfidenceConfig.weightImpactIntensity)
        .clamp(0, CrashConfidenceConfig.weightImpactIntensity)
        .round();
    points += impactPts;
    breakdown['impact_intensity'] = {
      'measured_peak_g': measuredPeakG,
      'saturated': isSaturated,
      'points_awarded': impactPts,
      'max_points': CrashConfidenceConfig.weightImpactIntensity,
    };

    // 3. Post-impact stillness (up to 20 pts)
    final int stillnessPts = postImpactStillness ? CrashConfidenceConfig.weightPostImpactStillness : 5;
    points += stillnessPts;
    breakdown['post_impact_stillness'] = {
      'detected': postImpactStillness,
      'points_awarded': stillnessPts,
      'max_points': CrashConfidenceConfig.weightPostImpactStillness,
    };

    // 4. Post-impact speed near zero (up to 15 pts)
    final int speedZeroPts = postImpactSpeedKmh <= 5.0
        ? CrashConfidenceConfig.weightPostImpactSpeedZero
        : (postImpactSpeedKmh <= 15.0 ? 5 : 0);
    points += speedZeroPts;
    breakdown['post_impact_speed_near_zero'] = {
      'post_speed_kmh': postImpactSpeedKmh,
      'points_awarded': speedZeroPts,
      'max_points': CrashConfidenceConfig.weightPostImpactSpeedZero,
    };

    // 5. Rollover / rotation (up to 10 pts)
    final int rolloverPts = rolloverSuspected ? CrashConfidenceConfig.weightRollover : 0;
    points += rolloverPts;
    breakdown['rollover_rotation'] = {
      'rollover_suspected': rolloverSuspected,
      'points_awarded': rolloverPts,
      'max_points': CrashConfidenceConfig.weightRollover,
    };

    // 6. Barometer change (if available)
    if (barometerDeltaHpa != null) {
      breakdown['barometer_delta_hpa'] = barometerDeltaHpa;
    }

    // 7. Free-fall penalty: phone drop deduction
    if (preImpactFreeFall) {
      points -= CrashConfidenceConfig.penaltyPreImpactFreeFall;
      breakdown['pre_impact_free_fall_penalty'] = {
        'detected': true,
        'deduction': -CrashConfidenceConfig.penaltyPreImpactFreeFall,
        'rationale': 'Phone drop signature (near-0g free-fall >100ms before impact)',
      };
    } else {
      breakdown['pre_impact_free_fall_penalty'] = {
        'detected': false,
        'deduction': 0,
      };
    }

    final int finalScore = points.clamp(0, 100);

    String level;
    int countdown;
    if (finalScore >= CrashConfidenceConfig.thresholdHighConfidence) {
      level = 'High';
      countdown = CrashConfidenceConfig.countdownHighConfidenceSeconds;
    } else if (finalScore >= CrashConfidenceConfig.thresholdModerateConfidence) {
      level = 'Moderate';
      countdown = CrashConfidenceConfig.countdownModerateConfidenceSeconds;
    } else {
      level = 'Low';
      countdown = CrashConfidenceConfig.countdownLowConfidenceSeconds;
    }

    return CrashConfidenceResult(
      score: finalScore,
      confidenceLevel: level,
      adaptiveCountdownSeconds: countdown,
      isSaturated: isSaturated,
      preImpactFreeFall: preImpactFreeFall,
      rolloverSuspected: rolloverSuspected,
      postImpactStillness: postImpactStillness,
      speedDropValidated: speedDropOk,
      factorBreakdown: breakdown,
    );
  }
}
