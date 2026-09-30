import 'package:flutter_test/flutter_test.dart';
import 'package:rakshak_mobile/services/crash_event_service.dart';

void main() {
  group('CrashEventService Tests', () {
    test('CrashEvent properties and toString', () {
      final now = DateTime.now();
      final event = CrashEvent(
        timestamp: now,
        decelerationG: 7.2,
        speedDropKmh: 80.0,
        source: 'unit_test',
        simulatedLatitude: 12.9716,
        simulatedLongitude: 77.5946,
      );

      expect(event.timestamp, now);
      expect(event.decelerationG, 7.2);
      expect(event.speedDropKmh, 80.0);
      expect(event.source, 'unit_test');
      expect(event.simulatedLatitude, 12.9716);
      expect(event.simulatedLongitude, 77.5946);
      expect(event.toString(), contains('7.2G'));
    });

    test('CrashEventService broadcast stream emits events to listeners', () async {
      final service = CrashEventService.instance;
      final expectedEvent = CrashEvent(
        timestamp: DateTime.now(),
        decelerationG: 8.5,
        speedDropKmh: 95.0,
      );

      expectLater(
        service.onCrashDetected,
        emits(predicate<CrashEvent>((e) =>
            e.decelerationG == 8.5 && e.speedDropKmh == 95.0)),
      );

      service.triggerCrash(expectedEvent);
    });
  });
}
