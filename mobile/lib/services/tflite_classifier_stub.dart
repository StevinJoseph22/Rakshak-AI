// ==============================================================================
// RAKSHAK-AI PHASE 11: TENSORFLOW LITE IMU CRASH CLASSIFIER
// ------------------------------------------------------------------------------
// Replaces the Phase 3 stub with real on-device inference using a trained 1D-CNN
// model (assets/models/crash_classifier.tflite) converted from TensorFlow.
//
// CLASSIFICATION CLASSES:
//   - 'normal':   Everyday vehicle cruising, phone handling, mild road vibration.
//   - 'pothole':  High-frequency, low-amplitude oscillatory burst (1.5G - 4.0G).
//   - 'crash':    Severe deceleration spike (>=6.5G) with sudden stop.
//
// ARCHITECTURAL ROLE:
//   This model acts as a SECOND OPINION / AUXILIARY SIGNAL alongside the primary
//   rule-based kinematic detector in CrashDetectorService.
//   If the model fails to load (headless unit tests, missing asset, incompatible
//   device), it logs a clear warning and falls back gracefully to the rule-based
//   kinematic detector without crashing.
// ==============================================================================

import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

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

/// TensorFlow Lite IMU classifier for 50-sample (1.0-second) rolling windows.
class TfLiteClassifierStub {
  const TfLiteClassifierStub();

  static const List<String> kClassLabels = ['normal', 'pothole', 'crash'];
  static const int kWindowSize = 50; // 50 samples @ 50Hz = 1.0s
  static const int kChannels = 2;    // [accel_net_g, gyro_mag]
  static const String kModelAssetPath = 'assets/models/crash_classifier.tflite';

  static Interpreter? _interpreter;
  static bool _isModelLoaded = false;
  static bool _loadAttempted = false;

  /// Optional mock for deterministic unit testing in environments without native TFLite binaries.
  static ClassificationResult Function(List<double> accel, List<double> gyro)? _mockClassifier;

  /// Whether the TFLite model is currently loaded and ready for inference.
  bool get isModelLoaded => _isModelLoaded || _mockClassifier != null;

  /// Whether the pipeline should execute the rule-based kinematic detector.
  /// Always returns true in Phase 11 because rule-based is the authoritative primary signal.
  bool get shouldFallbackToRuleBased => true;

  /// Asynchronously loads and initializes the TFLite interpreter from assets.
  static Future<bool> initialize({String assetPath = kModelAssetPath}) async {
    if (_isModelLoaded && _interpreter != null) return true;
    _loadAttempted = true;

    try {
      _interpreter = await Interpreter.fromAsset(assetPath);
      _interpreter!.allocateTensors();
      _isModelLoaded = true;
      debugPrint('[TfLiteClassifier] Loaded model: $assetPath (Input: ${_interpreter!.getInputTensors()})');
      return true;
    } catch (e) {
      _isModelLoaded = false;
      _interpreter = null;
      debugPrint(
        '[TfLiteClassifier] WARNING: Failed to load TFLite model ($e). '
        'Gracefully falling back to rule-based kinematic detection.',
      );
      return false;
    }
  }

  /// Injects a test classifier for unit test suites without native TFLite bindings.
  @visibleForTesting
  static void setMockClassifier(
    ClassificationResult Function(List<double> accel, List<double> gyro)? mock,
  ) {
    _mockClassifier = mock;
  }

  /// Resets the classifier state (useful for test tearDown).
  @visibleForTesting
  static void resetForTesting() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
    _loadAttempted = false;
    _mockClassifier = null;
  }

  /// Classifies a window of accelerometer deviations and gyroscope magnitudes.
  ClassificationResult classify(
    List<double> accelWindow,
    List<double> gyroWindow,
  ) {
    // 1. Check for test mock override
    if (_mockClassifier != null) {
      return _mockClassifier!(accelWindow, gyroWindow);
    }

    // 2. If model is not loaded, attempt lazy initialization or return fallback
    if (!_isModelLoaded || _interpreter == null) {
      if (!_loadAttempted) {
        // Trigger background load for subsequent samples
        initialize();
      }
      return const ClassificationResult(
        label: 'not_available',
        confidence: 0.0,
      );
    }

    try {
      // 3. Format input buffer into shape [1, 50, 2]
      final input = _prepareInput(accelWindow, gyroWindow);

      // 4. Allocate output tensor: shape [1, 3]
      final output = List.generate(1, (_) => List.filled(3, 0.0));

      // 5. Execute inference
      _interpreter!.run(input, output);

      // 6. Decode output probabilities
      final probs = output[0];
      int bestIdx = 0;
      double bestConfidence = probs[0];

      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > bestConfidence) {
          bestConfidence = probs[i];
          bestIdx = i;
        }
      }

      final label = bestIdx < kClassLabels.length ? kClassLabels[bestIdx] : 'unknown';
      return ClassificationResult(
        label: label,
        confidence: bestConfidence,
      );
    } catch (e) {
      debugPrint('[TfLiteClassifier] Inference error: $e');
      return const ClassificationResult(
        label: 'not_available',
        confidence: 0.0,
      );
    }
  }

  /// Resamples, pads, or slices the input windows to exact shape [1, 50, 2].
  static List<List<List<double>>> _prepareInput(
    List<double> accelWindow,
    List<double> gyroWindow,
  ) {
    final List<List<double>> window = [];

    final a = accelWindow.length > kWindowSize
        ? accelWindow.sublist(accelWindow.length - kWindowSize)
        : accelWindow;
    final g = gyroWindow.length > kWindowSize
        ? gyroWindow.sublist(gyroWindow.length - kWindowSize)
        : gyroWindow;

    for (int i = 0; i < kWindowSize; i++) {
      final aIdx = i - (kWindowSize - a.length);
      final aVal = (aIdx >= 0 && aIdx < a.length) ? a[aIdx] : 0.0;

      final gIdx = i - (kWindowSize - g.length);
      final gVal = (gIdx >= 0 && gIdx < g.length) ? g[gIdx] : 0.0;

      window.add([aVal, gVal]);
    }

    return [window];
  }
}
