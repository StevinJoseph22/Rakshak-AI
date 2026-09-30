import 'package:flutter_test/flutter_test.dart';
import 'package:rakshak_mobile/services/tflite_classifier_stub.dart';

void main() {
  group('TfLiteClassifierStub Tests', () {
    test('stub returns not_available classification with 0.0 confidence', () {
      const stub = TfLiteClassifierStub();
      final accelWindow = [1.2, 1.5, 2.0, 1.8, 1.1];
      final gyroWindow = [0.1, 0.2, 0.1];

      final result = stub.classify(accelWindow, gyroWindow);

      expect(result.label, 'not_available');
      expect(result.confidence, 0.0);
      expect(result.toString(), contains('not_available'));
      expect(stub.shouldFallbackToRuleBased, isTrue);
    });
  });
}
