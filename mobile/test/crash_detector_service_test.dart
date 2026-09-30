import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:rakshak_mobile/services/crash_detector_service.dart';
import 'package:rakshak_mobile/services/crash_event_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CrashDetectorService detector;
  late CrashEventService eventService;

  setUp(() {
    detector = CrashDetectorService.instance;
    eventService = CrashEventService.instance;
    detector.stop();
  });

  tearDown(() {
    detector.stop();
  });

  group('CrashDetectorService Configuration & Constants', () {
    test('named constants are defined and configurable', () {
      expect(kImpactDecelerationThresholdG, 6.5);
      expect(kImpactSpeedDropThresholdKmh, 25.0);
      expect(kSpeedDropWindowMs, 500);
      expect(kPotholeMinG, 1.5);
      expect(kPotholeMaxG, 4.0);
      expect(kPotholeOscillationThreshold, 3);
      expect(kPotholeWindowMs, 300);

      // Verify detector attributes can be tuned
      detector.impactDecelerationThresholdG = 7.0;
      detector.impactSpeedDropThresholdKmh = 30.0;
      expect(detector.impactDecelerationThresholdG, 7.0);
      expect(detector.impactSpeedDropThresholdKmh, 30.0);

      // Reset to defaults
      detector.impactDecelerationThresholdG = kImpactDecelerationThresholdG;
      detector.impactSpeedDropThresholdKmh = kImpactSpeedDropThresholdKmh;
    });

    test('start and stop controls monitoring state', () {
      expect(detector.isMonitoring, isFalse);
      detector.start();
      expect(detector.isMonitoring, isTrue);
      detector.stop();
      expect(detector.isMonitoring, isFalse);
    });
  });

  group('Pothole / Speed-Bump False-Positive Filtering', () {
    test('filters out high-frequency low-amplitude vibration bursts', () async {
      detector.start();
      bool crashPublished = false;

      final subscription = eventService.onCrashDetected.listen((_) {
        crashPublished = true;
      });

      final baseTime = DateTime.now();
      // Simulate rapid road vibration oscillations between 1.8G and 3.2G within 200ms
      // netG = (totalAccel/g - 1).abs()
      // totalAccel = (netG + 1) * g
      const g = kEarthGravity;
      const samples = [1.8, 3.2, 1.6, 2.9, 1.7, 3.1];

      for (int i = 0; i < samples.length; i++) {
        final netG = samples[i];
        final totalAccel = (netG + 1.0) * g;
        final timestamp = baseTime.add(Duration(milliseconds: i * 30));

        detector.processAccelerometer(
          AccelerometerEvent(totalAccel, 0.0, 0.0, timestamp),
          timestamp: timestamp,
        );
      }

      await Future.delayed(const Duration(milliseconds: 50));
      expect(crashPublished, isFalse,
          reason: 'Pothole vibration burst must be filtered out and not trigger a crash');

      await subscription.cancel();
    });
  });

  group('Impact Signature & Speed Drop Logic', () {
    test('confirms impact when high-G spike is accompanied by speed drop to 0', () async {
      detector.start();
      CrashEvent? receivedEvent;

      final subscription = eventService.onCrashDetected.listen((event) {
        receivedEvent = event;
      });

      final now = DateTime.now();

      // Vehicle was cruising at 60 km/h
      detector.recordSpeedSample(60.0, timestamp: now.subtract(const Duration(milliseconds: 300)));

      // Vehicle stops abruptly to 0 km/h within 300ms
      detector.recordSpeedSample(0.0, timestamp: now);

      // Deceleration spike: 7.5G
      const totalAccel = (7.5 + 1.0) * kEarthGravity;
      detector.processAccelerometer(
        AccelerometerEvent(totalAccel, 0.0, 0.0, now),
        timestamp: now,
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(receivedEvent, isNotNull);
      expect(receivedEvent!.source, 'sensor');
      expect(receivedEvent!.decelerationG, closeTo(7.5, 0.1));
      expect(receivedEvent!.speedDropKmh, closeTo(60.0, 0.1));

      await subscription.cancel();
    });

    test('suppresses crash event when high-G spike occurs without speed drop (phone drop while driving)', () async {
      detector.start();
      bool crashPublished = false;

      final subscription = eventService.onCrashDetected.listen((_) {
        crashPublished = true;
      });

      final now = DateTime.now();

      // Vehicle cruising at 65 km/h before and continues at 65 km/h (e.g. phone dropped inside car)
      detector.recordSpeedSample(65.0, timestamp: now.subtract(const Duration(milliseconds: 200)));
      detector.recordSpeedSample(65.0, timestamp: now);

      // Deceleration spike: 7.5G
      const totalAccel = (7.5 + 1.0) * kEarthGravity;
      detector.processAccelerometer(
        AccelerometerEvent(totalAccel, 0.0, 0.0, now),
        timestamp: now,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(crashPublished, isFalse,
          reason: 'High-G spike without GPS speed drop must be rejected');

      await subscription.cancel();
    });
  });
}
