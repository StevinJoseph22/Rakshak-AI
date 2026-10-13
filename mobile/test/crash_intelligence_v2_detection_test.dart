import 'package:flutter_test/flutter_test.dart';
import 'package:rakshak_mobile/config/crash_confidence_config.dart';
import 'package:rakshak_mobile/services/detection_lab_engine.dart';

void main() {
  group('Phase 17 Part F: Detection Lab & Crash Intelligence v2 Tests', () {
    test('Canonical test suite contains all 7 required scenarios', () {
      final scenarios = DetectionLabEngine.getCanonicalScenarios();
      expect(scenarios.length, equals(7));

      final scenarioIds = scenarios.map((s) => s.id).toSet();
      expect(
        scenarioIds,
        containsAll([
          'pothole',
          'speed_bump',
          'hard_brake',
          'phone_drop',
          'thrown_seat',
          'genuine_crash',
          'rollover',
        ]),
      );
    });

    test('Pothole scenario is successfully filtered by oscillation burst check', () {
      final scenarios = DetectionLabEngine.getCanonicalScenarios();
      final pothole = scenarios.firstWhere((s) => s.id == 'pothole');
      final result = DetectionLabEngine.evaluateScenario(pothole);

      expect(result.detectedCrash, isFalse, reason: 'Pothole must not trigger crash');
      expect(result.isAccurate, isTrue);
      expect(result.filterReason, contains('pothole vibration oscillations'));
    });

    test('Speed bump scenario is suppressed due to sub-threshold deceleration', () {
      final scenarios = DetectionLabEngine.getCanonicalScenarios();
      final speedBump = scenarios.firstWhere((s) => s.id == 'speed_bump');
      final result = DetectionLabEngine.evaluateScenario(speedBump);

      expect(result.detectedCrash, isFalse, reason: 'Speed bump must not trigger crash');
      expect(result.isAccurate, isTrue);
      expect(result.peakDecelerationG, lessThan(6.0));
    });

    test('Hard braking at tyre adhesion limit (~0.94g) is suppressed without impact spike', () {
      final scenarios = DetectionLabEngine.getCanonicalScenarios();
      final hardBrake = scenarios.firstWhere((s) => s.id == 'hard_brake');
      final result = DetectionLabEngine.evaluateScenario(hardBrake);

      expect(result.detectedCrash, isFalse, reason: 'Hard braking must not trigger crash');
      expect(result.isAccurate, isTrue);
      expect(result.peakDecelerationG, lessThan(2.0));
    });

    test('Phone drop exhibits pre-impact free-fall (>100ms) and is suppressed with 50pt penalty', () {
      final scenarios = DetectionLabEngine.getCanonicalScenarios();
      final phoneDrop = scenarios.firstWhere((s) => s.id == 'phone_drop');
      final result = DetectionLabEngine.evaluateScenario(phoneDrop);

      expect(result.detectedCrash, isFalse, reason: 'Phone drop must be suppressed');
      expect(result.isAccurate, isTrue);
      expect(result.preImpactFreeFall, isTrue, reason: 'Pre-impact free fall must be detected');
      expect(result.confidenceScore, lessThan(40), reason: 'Penalty must reduce confidence below threshold');
      expect(result.filterReason, contains('Phone-drop signature'));
    });

    test('Phone thrown on car seat is suppressed without vehicle speed drop to zero', () {
      final scenarios = DetectionLabEngine.getCanonicalScenarios();
      final thrownSeat = scenarios.firstWhere((s) => s.id == 'thrown_seat');
      final result = DetectionLabEngine.evaluateScenario(thrownSeat);

      expect(result.detectedCrash, isFalse, reason: 'Phone thrown on seat must not trigger crash');
      expect(result.isAccurate, isTrue);
      expect(result.speedDropKmh, equals(0.0));
    });

    test('Genuine frontal crash (65 km/h) triggers crash detection with High Confidence', () {
      final scenarios = DetectionLabEngine.getCanonicalScenarios();
      final genuineCrash = scenarios.firstWhere((s) => s.id == 'genuine_crash');
      final result = DetectionLabEngine.evaluateScenario(genuineCrash);

      expect(result.detectedCrash, isTrue, reason: 'Genuine crash must be detected');
      expect(result.isAccurate, isTrue);
      expect(result.confidenceScore, greaterThanOrEqualTo(CrashConfidenceConfig.thresholdHighConfidence));
      expect(result.confidenceLevel, equals('High'));
      expect(result.postImpactStillness, isTrue);
      expect(result.adaptiveCountdownSeconds, equals(CrashConfidenceConfig.countdownHighConfidenceSeconds));
    });

    test('Rollover collision flags high rotation (>3.5 rad/s) and marks accelerometer saturation if >= 16g', () {
      final scenarios = DetectionLabEngine.getCanonicalScenarios();
      final rollover = scenarios.firstWhere((s) => s.id == 'rollover');
      final result = DetectionLabEngine.evaluateScenario(rollover);

      expect(result.detectedCrash, isTrue, reason: 'Rollover collision must be detected');
      expect(result.isAccurate, isTrue);
      expect(result.rolloverSuspected, isTrue, reason: 'Rollover gyro tumble must be flagged');
      expect(result.isSaturated, isTrue, reason: 'Deceleration >= 16g must be marked saturated');
      expect(result.factorBreakdown['impact_intensity']['saturated'], isTrue);
    });

    test('Full Detection Lab Suite achieves 100% accuracy with 0 false positives and 0 false negatives', () {
      final summary = DetectionLabEngine.runFullSuite();

      expect(summary.totalScenarios, equals(7));
      expect(summary.totalAccurate, equals(7));
      expect(summary.falsePositives, equals(0), reason: 'Zero false positives on non-crash events');
      expect(summary.falseNegatives, equals(0), reason: 'Zero false negatives on real crashes');
      expect(summary.accuracyPercentage, equals(100.0));
      expect(summary.disclaimer, contains('scripted synthetic scenarios'));
    });
  });
}
