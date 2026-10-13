import 'dart:math';
import '../config/crash_confidence_config.dart';

/// Represents a single recorded / synthetic sensor sample in a test scenario.
class SyntheticSensorSample {
  final int offsetMs;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroRadS;
  final double speedKmh;

  const SyntheticSensorSample({
    required this.offsetMs,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    this.gyroRadS = 0.0,
    required this.speedKmh,
  });

  double get netG {
    final mag = sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ) / 9.80665;
    return (mag - 1.0).abs();
  }

  double get totalG {
    return sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ) / 9.80665;
  }
}

/// Scenario definition for the Detection Lab replay suite.
class LabScenario {
  final String id;
  final String name;
  final String description;
  final bool expectCrash;
  final String expectedLabel;
  final List<SyntheticSensorSample> samples;

  const LabScenario({
    required this.id,
    required this.name,
    required this.description,
    required this.expectCrash,
    required this.expectedLabel,
    required this.samples,
  });
}

/// Detailed execution outcome of running a scenario through the detector pipeline.
class DetectionLabResult {
  final String scenarioId;
  final String scenarioName;
  final bool expectedCrash;
  final bool detectedCrash;
  final bool isAccurate;
  final String filterReason;
  final double peakDecelerationG;
  final double speedDropKmh;
  final bool isSaturated;
  final bool preImpactFreeFall;
  final bool rolloverSuspected;
  final bool postImpactStillness;
  final int confidenceScore;
  final String confidenceLevel;
  final int adaptiveCountdownSeconds;
  final Map<String, dynamic> factorBreakdown;
  final String disclaimer;

  const DetectionLabResult({
    required this.scenarioId,
    required this.scenarioName,
    required this.expectedCrash,
    required this.detectedCrash,
    required this.isAccurate,
    required this.filterReason,
    required this.peakDecelerationG,
    required this.speedDropKmh,
    required this.isSaturated,
    required this.preImpactFreeFall,
    required this.rolloverSuspected,
    required this.postImpactStillness,
    required this.confidenceScore,
    required this.confidenceLevel,
    required this.adaptiveCountdownSeconds,
    required this.factorBreakdown,
    this.disclaimer = 'Scripted synthetic scenario for algorithmic validation, not real-world crash telemetry.',
  });
}

/// Overall test suite summary for presentation and confusion matrix.
class DetectionLabSuiteSummary {
  final List<DetectionLabResult> results;
  final int totalScenarios;
  final int totalAccurate;
  final int falsePositives;
  final int falseNegatives;
  final double accuracyPercentage;
  final String disclaimer;

  const DetectionLabSuiteSummary({
    required this.results,
    required this.totalScenarios,
    required this.totalAccurate,
    required this.falsePositives,
    required this.falseNegatives,
    required this.accuracyPercentage,
    this.disclaimer = 'All test waveforms are scripted synthetic scenarios, not real-world crash data.',
  });
}

/// Replay engine that drives synthetic scenarios through the exact same logic
/// as CrashDetectorService and CrashConfidenceConfig.
class DetectionLabEngine {
  /// Builds the canonical 7 test scenarios specified in Phase 17 Part F:
  /// 1. Pothole (vibration oscillation filter)
  /// 2. Speed bump (smooth vertical rise)
  /// 3. Hard brake (high deceleration, tyre grip limited, no crash)
  /// 4. Phone drop (free-fall near-0g >100ms before impact)
  /// 5. Phone thrown on seat (moderate deceleration, no vehicle stop)
  /// 6. Genuine crash profile (high deceleration, sudden speed drop to 0, stillness)
  /// 7. Rollover (angular tumbling > 3.5 rad/s)
  static List<LabScenario> getCanonicalScenarios() {
    return [
      _createPotholeScenario(),
      _createSpeedBumpScenario(),
      _createHardBrakeScenario(),
      _createPhoneDropScenario(),
      _createPhoneThrownOnSeatScenario(),
      _createGenuineCrashScenario(),
      _createRolloverScenario(),
    ];
  }

  /// Evaluates a single scenario through the kinematic detection filters and confidence engine.
  static DetectionLabResult evaluateScenario(LabScenario scenario) {
    // 1. Analyze acceleration samples for peak G, free-fall, oscillations, stillness
    double peakNetG = 0.0;
    int peakIndex = 0;
    double initialSpeed = scenario.samples.first.speedKmh;
    double finalSpeed = scenario.samples.last.speedKmh;

    for (int i = 0; i < scenario.samples.length; i++) {
      final s = scenario.samples[i];
      if (s.netG > peakNetG) {
        peakNetG = s.netG;
        peakIndex = i;
      }
    }

    // 2. Pre-impact free-fall check: near-0g for >100ms before impact
    bool preImpactFreeFall = false;
    int continuousFreeFallMs = 0;
    for (int i = 0; i < peakIndex; i++) {
      final s = scenario.samples[i];
      if (s.totalG < CrashConfidenceConfig.kFreeFallGThreshold) {
        continuousFreeFallMs += (i > 0 ? (s.offsetMs - scenario.samples[i - 1].offsetMs) : 20);
        if (continuousFreeFallMs >= CrashConfidenceConfig.kFreeFallMinDurationMs) {
          preImpactFreeFall = true;
        }
      } else {
        continuousFreeFallMs = 0;
      }
    }

    // 3. Pothole oscillation filter check: 1.5g - 4.0g with >= 4 reversals
    bool potholeDetected = false;
    if (peakNetG >= 1.5 && peakNetG <= 4.0) {
      int reversals = 0;
      for (int i = 1; i < scenario.samples.length - 1; i++) {
        final p = scenario.samples[i - 1].netG;
        final c = scenario.samples[i].netG;
        final n = scenario.samples[i + 1].netG;
        if ((c > p && c > n) || (c < p && c < n)) {
          reversals++;
        }
      }
      if (reversals >= 4) {
        potholeDetected = true;
      }
    }

    // 4. Rollover check: max gyro >= 3.5 rad/s
    bool rolloverSuspected = false;
    for (final s in scenario.samples) {
      if (s.gyroRadS >= CrashConfidenceConfig.kRolloverGyroThresholdRad) {
        rolloverSuspected = true;
        break;
      }
    }

    // 5. Post-impact stillness check (variance of samples after impact pulse ends)
    bool postImpactStillness = true;
    final peakOffset = scenario.samples[peakIndex].offsetMs;
    final postSamples = scenario.samples.where((s) => s.offsetMs >= peakOffset + 150).toList();
    if (postSamples.length >= 3) {
      double mean = 0.0;
      for (final s in postSamples) mean += s.netG;
      mean /= postSamples.length;
      double variance = 0.0;
      for (final s in postSamples) variance += (s.netG - mean) * (s.netG - mean);
      variance /= postSamples.length;
      postImpactStillness = variance <= CrashConfidenceConfig.kStillnessVarianceMaxG;
    }

    // 6. Kinematic crash decision:
    // Deceleration must cross 6.0G threshold
    // Speed drop must be >= 25 km/h or drop to <= 5 km/h
    // Must NOT be filtered by pothole or free-fall drop suppression
    final speedDropKmh = max(0.0, initialSpeed - finalSpeed);
    final bool speedDroppedTowardZero =
        speedDropKmh >= CrashConfidenceConfig.kSignificantSpeedDropKmh ||
        (initialSpeed >= CrashConfidenceConfig.kSignificantSpeedDropKmh && finalSpeed <= 5.0);

    final bool crossedGThreshold = peakNetG >= 6.0;

    // Compute confidence breakdown
    final confidence = CrashConfidenceResult.compute(
      measuredPeakG: peakNetG,
      speedDropKmh: speedDropKmh,
      postImpactSpeedKmh: finalSpeed,
      preImpactFreeFall: preImpactFreeFall,
      postImpactStillness: postImpactStillness,
      rolloverSuspected: rolloverSuspected,
    );

    bool detectedCrash = false;
    String filterReason = 'Normal Driving';

    if (potholeDetected) {
      detectedCrash = false;
      filterReason = 'Filtered: High-frequency pothole vibration oscillations (peak ${peakNetG.toStringAsFixed(1)}g)';
    } else if (preImpactFreeFall && confidence.score < 40) {
      detectedCrash = false;
      filterReason = 'Suppressed: Phone-drop signature (pre-impact free-fall >100ms, confidence ${confidence.score}/100)';
    } else if (!crossedGThreshold) {
      detectedCrash = false;
      filterReason = 'Filtered: Peak deceleration ${peakNetG.toStringAsFixed(1)}g did not cross 6.0g threshold';
    } else if (!speedDroppedTowardZero) {
      detectedCrash = false;
      filterReason = 'Suppressed: Deceleration spike ${peakNetG.toStringAsFixed(1)}g without vehicle speed drop to 0';
    } else {
      detectedCrash = true;
      filterReason = 'Confirmed Impact: G-spike ${peakNetG.toStringAsFixed(1)}g with validated speed drop ($speedDropKmh km/h)';
    }

    final isAccurate = (detectedCrash == scenario.expectCrash);

    return DetectionLabResult(
      scenarioId: scenario.id,
      scenarioName: scenario.name,
      expectedCrash: scenario.expectCrash,
      detectedCrash: detectedCrash,
      isAccurate: isAccurate,
      filterReason: filterReason,
      peakDecelerationG: peakNetG,
      speedDropKmh: speedDropKmh,
      isSaturated: confidence.isSaturated,
      preImpactFreeFall: preImpactFreeFall,
      rolloverSuspected: rolloverSuspected,
      postImpactStillness: postImpactStillness,
      confidenceScore: confidence.score,
      confidenceLevel: confidence.confidenceLevel,
      adaptiveCountdownSeconds: confidence.adaptiveCountdownSeconds,
      factorBreakdown: confidence.factorBreakdown,
    );
  }

  /// Runs the full canonical scenario suite and aggregates accuracy metrics.
  static DetectionLabSuiteSummary runFullSuite() {
    final scenarios = getCanonicalScenarios();
    final List<DetectionLabResult> results = [];
    int falsePositives = 0;
    int falseNegatives = 0;
    int accurate = 0;

    for (final scenario in scenarios) {
      final res = evaluateScenario(scenario);
      results.add(res);
      if (res.isAccurate) {
        accurate++;
      } else {
        if (!res.expectedCrash && res.detectedCrash) {
          falsePositives++;
        } else if (res.expectedCrash && !res.detectedCrash) {
          falseNegatives++;
        }
      }
    }

    final accuracy = (scenarios.isNotEmpty) ? (accurate / scenarios.length) * 100.0 : 0.0;

    return DetectionLabSuiteSummary(
      results: results,
      totalScenarios: scenarios.length,
      totalAccurate: accurate,
      falsePositives: falsePositives,
      falseNegatives: falseNegatives,
      accuracyPercentage: accuracy,
    );
  }

  // --- Synthetic Scenario Waveform Generators ---

  static LabScenario _createPotholeScenario() {
    final List<SyntheticSensorSample> samples = [];
    // Vehicle traveling steady at 45 km/h hits sharp pothole at 200ms
    for (int t = 0; t <= 600; t += 25) {
      double az = 9.80665;
      if (t >= 200 && t <= 350) {
        // High-frequency alternating vertical ripple: 2.2g, -1.8g, 2.5g, -2.1g
        final phase = (t - 200) / 150.0 * 4 * pi;
        az = 9.80665 + (sin(phase) * 2.6 * 9.80665);
      }
      samples.add(SyntheticSensorSample(
        offsetMs: t,
        accelX: 0.1,
        accelY: 0.2,
        accelZ: az,
        speedKmh: 45.0,
      ));
    }
    return LabScenario(
      id: 'pothole',
      name: 'Pothole Vibration Burst',
      description: 'Vehicle at 45 km/h strikes road pothole. High-frequency oscillating vertical acceleration (2.6g peak) with zero drop in vehicle speed.',
      expectCrash: false,
      expectedLabel: 'Suppressed (Pothole Filter)',
      samples: samples,
    );
  }

  static LabScenario _createSpeedBumpScenario() {
    final List<SyntheticSensorSample> samples = [];
    // Vehicle slows gently from 30 km/h to 22 km/h over a smooth speed bump
    for (int t = 0; t <= 1000; t += 50) {
      double az = 9.80665;
      if (t >= 300 && t <= 700) {
        // Smooth sine dome: peak 1.4g
        final phase = (t - 300) / 400.0 * pi;
        az = 9.80665 + (sin(phase) * 1.4 * 9.80665);
      }
      final speed = 30.0 - (t / 1000.0 * 8.0);
      samples.add(SyntheticSensorSample(
        offsetMs: t,
        accelX: 0.1,
        accelY: -1.5, // gentle braking deceleration (~0.15g)
        accelZ: az,
        speedKmh: speed,
      ));
    }
    return LabScenario(
      id: 'speed_bump',
      name: 'Speed Bump Transition',
      description: 'Vehicle crosses speed bump at 25 km/h. Smooth single-arch rise (1.4g), modest deceleration without sudden stop.',
      expectCrash: false,
      expectedLabel: 'Suppressed (Sub-threshold)',
      samples: samples,
    );
  }

  static LabScenario _createHardBrakeScenario() {
    final List<SyntheticSensorSample> samples = [];
    // Vehicle traveling at 75 km/h slams brakes to avoid pedestrian.
    // Automotive road friction limit is ~0.9g - 1.0g. No physical impact.
    for (int t = 0; t <= 2000; t += 50) {
      double ay = 0.0;
      double speed = 75.0;
      if (t >= 200 && t <= 1800) {
        // Tyre friction limit: -9.2 m/s^2 (~0.94g)
        ay = -9.2;
        speed = max(10.0, 75.0 - ((t - 200) / 1600.0 * 65.0));
      } else if (t > 1800) {
        speed = 10.0;
      }
      samples.add(SyntheticSensorSample(
        offsetMs: t,
        accelX: 0.1,
        accelY: ay,
        accelZ: 9.80665,
        speedKmh: speed,
      ));
    }
    return LabScenario(
      id: 'hard_brake',
      name: 'Emergency Hard Braking',
      description: 'Vehicle emergency stops from 75 km/h to 10 km/h. Deceleration peaks at tyre adhesion limit (0.94g), well below 6.0g impact threshold.',
      expectCrash: false,
      expectedLabel: 'Suppressed (Tyre Adhesion Limit)',
      samples: samples,
    );
  }

  static LabScenario _createPhoneDropScenario() {
    final List<SyntheticSensorSample> samples = [];
    // Phone held at waist height (0.0 km/h walking or in car) falls to floor.
    // Experiences near-0g free fall for 200ms (>100ms threshold), followed by 9.5g floor slap.
    for (int t = 0; t <= 800; t += 20) {
      double ax = 0.0, ay = 0.0, az = 9.80665;
      if (t >= 200 && t < 400) {
        // Free fall state: total acceleration drops near 0 m/s^2 (0.1g)
        ax = 0.2;
        ay = 0.2;
        az = 0.5;
      } else if (t >= 400 && t <= 440) {
        // Impact with floor tile: 9.5g spike
        az = 9.80665 + (9.5 * 9.80665);
      } else if (t > 440) {
        // Resting on floor
        az = 9.80665;
      }
      samples.add(SyntheticSensorSample(
        offsetMs: t,
        accelX: ax,
        accelY: ay,
        accelZ: az,
        speedKmh: 0.0,
      ));
    }
    return LabScenario(
      id: 'phone_drop',
      name: 'Phone Dropped to Floor',
      description: 'Phone slips from hand: 200ms of near-0g free-fall followed by 9.5g impact spike on floor. Free-fall penalty suppresses false alarm.',
      expectCrash: false,
      expectedLabel: 'Suppressed (Pre-Impact Free-Fall)',
      samples: samples,
    );
  }

  static LabScenario _createPhoneThrownOnSeatScenario() {
    final List<SyntheticSensorSample> samples = [];
    // Passenger tosses phone onto cushioned rear car seat while car travels at 50 km/h
    for (int t = 0; t <= 600; t += 25) {
      double ay = 0.0;
      if (t >= 200 && t <= 275) {
        // Soft cushion landing: 2.8g peak
        ay = -2.8 * 9.80665;
      }
      samples.add(SyntheticSensorSample(
        offsetMs: t,
        accelX: 0.2,
        accelY: ay,
        accelZ: 9.80665,
        speedKmh: 50.0,
      ));
    }
    return LabScenario(
      id: 'thrown_seat',
      name: 'Phone Tossed on Car Seat',
      description: 'Phone tossed onto passenger car seat at 50 km/h. Soft deceleration (2.8g) without vehicle speed drop.',
      expectCrash: false,
      expectedLabel: 'Suppressed (Sub-threshold)',
      samples: samples,
    );
  }

  static LabScenario _createGenuineCrashScenario() {
    final List<SyntheticSensorSample> samples = [];
    // Vehicle traveling at 65 km/h suffers high-speed frontal collision.
    // Extreme 12.5g impact spike, violent deceleration to 0 km/h within 300ms, followed by motionless stillness.
    for (int t = 0; t <= 1200; t += 20) {
      double ay = 0.0;
      double speed = 65.0;
      if (t < 300) {
        speed = 65.0;
      } else if (t >= 300 && t <= 420) {
        // Impact pulse: 12.5g deceleration
        ay = -12.5 * 9.80665;
        speed = max(0.0, 65.0 - ((t - 300) / 120.0 * 65.0));
      } else {
        // Complete halt & motionless stillness
        speed = 0.0;
        ay = 0.0;
      }
      samples.add(SyntheticSensorSample(
        offsetMs: t,
        accelX: 0.1,
        accelY: ay,
        accelZ: 9.80665,
        gyroRadS: (t >= 300 && t <= 420) ? 1.8 : 0.05,
        speedKmh: speed,
      ));
    }
    return LabScenario(
      id: 'genuine_crash',
      name: 'Genuine Frontal Collision (65 km/h)',
      description: 'Direct vehicle collision at 65 km/h: 12.5g impact pulse, immediate speed collapse to 0 km/h, verified post-impact stillness.',
      expectCrash: true,
      expectedLabel: 'CRASH DETECTED (High Confidence)',
      samples: samples,
    );
  }

  static LabScenario _createRolloverScenario() {
    final List<SyntheticSensorSample> samples = [];
    // Vehicle traveling at 80 km/h veers and rolls over.
    // Impact spike hits accelerometer saturation limit (16.0g+), angular tumble gyro rate = 5.4 rad/s (>3.5 rad/s), vehicle stops.
    for (int t = 0; t <= 1400; t += 25) {
      double ax = 0.0, ay = 0.0;
      double gyro = 0.1;
      double speed = 80.0;
      if (t >= 250 && t <= 450) {
        // Rollover impact with severe tumbling: sensor saturates at 16.5g
        ay = -16.5 * 9.80665;
        ax = 8.0 * 9.80665;
        gyro = 5.4; // Exceeds 3.5 rad/s rollover threshold
        speed = max(0.0, 80.0 - ((t - 250) / 200.0 * 80.0));
      } else if (t > 450) {
        speed = 0.0;
        gyro = 0.05;
      }
      samples.add(SyntheticSensorSample(
        offsetMs: t,
        accelX: ax,
        accelY: ay,
        accelZ: 9.80665,
        gyroRadS: gyro,
        speedKmh: speed,
      ));
    }
    return LabScenario(
      id: 'rollover',
      name: 'Vehicular Rollover Collision',
      description: 'Vehicle flips at 80 km/h: Gyroscope registers 5.4 rad/s tumble, accelerometer saturates at limit (marked saturated), speed drops to 0.',
      expectCrash: true,
      expectedLabel: 'CRASH DETECTED (Rollover Flagged)',
      samples: samples,
    );
  }
}
