// ==============================================================================
// POST-HACKATHON TENSORFLOW LITE INTEGRATION ROADMAP:
// ------------------------------------------------------------------------------
// This file serves as an architectural integration point and stub for on-device
// deep learning IMU crash classification.
//
// In this hackathon scope, production-grade rule-based kinematic filters (IMU
// deceleration spikes + GPS speed-drop + frequency-domain pothole rejection)
// provide deterministic and reliable crash detection.
//
// To replace this stub post-hackathon with a full TensorFlow Lite neural model:
// 1. Labeled Dataset Collection: Collect high-frequency 50Hz-100Hz 3-axis
//    accelerometer & gyroscope windows (e.g. 100-sample / 1-second slices) across
//    four distinct classes:
//      (a) severe vehicle collision (frontal/lateral/rollover impacts),
//      (b) pothole/speed-bump impact bursts,
//      (c) phone drop / harsh device handling,
//      (d) normal highway / stop-and-go city driving.
// 2. Model Training & Quantization: Train a lightweight 1D-CNN or Bi-LSTM model
//    in TensorFlow/Keras, evaluate ROC-AUC, and export to quantized 8-bit
//    integer (`crash_model.tflite`) format for sub-5ms mobile inference latency.
// 3. Flutter Integration: Add `tflite_flutter: ^0.10.4` dependency, bundle
//    `assets/models/crash_model.tflite` in `pubspec.yaml`, allocate native
//    input/output tensor buffers, and route the real-time sensor window
//    through `interpreter.run(input, output)`.
// ==============================================================================

/// Output contract for on-device IMU machine learning classification.
class ClassificationResult {
  final String label;
  final double confidence;

  const ClassificationResult({
    required this.label,
    required this.confidence,
  });

  @override
  String toString() =>
      'ClassificationResult(label: $label, confidence: ${confidence.toStringAsFixed(2)})';
}

/// TensorFlow Lite integration point for IMU telemetry window classification.
class TfLiteClassifierStub {
  const TfLiteClassifierStub();

  /// Classifies a window of accelerometer and gyroscope magnitudes.
  /// Currently returns hardcoded stub result and triggers fallback to rule-based detector.
  ClassificationResult classify(
    List<double> accelWindow,
    List<double> gyroWindow,
  ) {
    // Stub implementation: Returns not_available so pipeline falls back to rule-based logic
    return const ClassificationResult(
      label: 'not_available',
      confidence: 0.0,
    );
  }

  /// Whether the pipeline should fall back to rule-based kinematic analysis.
  bool get shouldFallbackToRuleBased => true;
}
