import 'package:flutter_test/flutter_test.dart';
import 'package:rakshak_mobile/services/tflite_classifier_stub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TfLiteClassifierStub Tests', () {
    tearDown(() {
      TfLiteClassifierStub.resetForTesting();
    });

    test('stub returns not_available classification with 0.0 confidence when uninitialized', () {
      const stub = TfLiteClassifierStub();
      final accelWindow = [1.2, 1.5, 2.0, 1.8, 1.1];
      final gyroWindow = [0.1, 0.2, 0.1];

      final result = stub.classify(accelWindow, gyroWindow);

      expect(result.label, 'not_available');
      expect(result.confidence, 0.0);
      expect(result.toString(), contains('not_available'));
      expect(stub.shouldFallbackToRuleBased, isTrue);
    });

    test('gracefully fails and returns false without throwing if asset is missing or runtime fails', () async {
      final loaded = await TfLiteClassifierStub.initialize(
        assetPath: 'non_existent_model.tflite',
      );
      expect(loaded, isFalse);

      const stub = TfLiteClassifierStub();
      final result = stub.classify([1.0], [0.1]);
      expect(result.label, 'not_available');
      expect(result.confidence, 0.0);
    });

    test('mock classifier returns synthetic classification predictions with high confidence', () {
      TfLiteClassifierStub.setMockClassifier((accel, gyro) {
        final peakG = accel.isNotEmpty ? accel.reduce((a, b) => a > b ? a : b) : 0.0;
        if (peakG >= 6.5) {
          return const ClassificationResult(label: 'crash', confidence: 0.98);
        } else if (peakG >= 1.5) {
          return const ClassificationResult(label: 'pothole', confidence: 0.89);
        }
        return const ClassificationResult(label: 'normal', confidence: 0.95);
      });

      const stub = TfLiteClassifierStub();
      expect(stub.isModelLoaded, isTrue);

      final crashResult = stub.classify([7.2, 8.1, 6.9], [4.5, 5.0]);
      expect(crashResult.label, 'crash');
      expect(crashResult.confidence, 0.98);

      final potholeResult = stub.classify([2.1, 3.0, 2.5], [1.1]);
      expect(potholeResult.label, 'pothole');
      expect(potholeResult.confidence, 0.89);

      final normalResult = stub.classify([0.2, 0.3], [0.1]);
      expect(normalResult.label, 'normal');
      expect(normalResult.confidence, 0.95);
    });

    test('handles empty and oversized input windows without throwing', () {
      const stub = TfLiteClassifierStub();
      
      // Empty input
      final emptyResult = stub.classify([], []);
      expect(emptyResult.label, 'not_available');

      // Oversized input (e.g. 100 samples)
      final largeAccel = List.generate(100, (i) => i * 0.1);
      final largeGyro = List.generate(100, (i) => i * 0.05);
      final largeResult = stub.classify(largeAccel, largeGyro);
      expect(largeResult.label, 'not_available');
    });
  });
}
