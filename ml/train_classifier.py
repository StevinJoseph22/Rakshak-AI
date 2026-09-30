"""
Rakshak-AI Machine Learning Module: 1D-CNN Crash Classifier Trainer
-------------------------------------------------------------------
Trains a lightweight 1D-CNN on synthetic IMU telemetry windows (50 samples x 2 channels)
to classify vehicle dynamics into:
  - normal (Class 0)
  - pothole (Class 1)
  - crash (Class 2)

Exports the optimized model to TensorFlow Lite (.tflite) format for mobile deployment.

VALIDATION DISCLAIMER:
This model is trained and validated on mathematically simulated synthetic IMU data
based on kinematic threshold definitions. It serves as an auxiliary, secondary signal
alongside the deterministic rule-based detector.
"""

import os
import shutil
import numpy as np
import tensorflow as tf
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix

from dataset_generator import (
    generate_synthetic_dataset,
    WINDOW_SIZE,
    CHANNELS,
    CLASSES,
    IDX_TO_CLASS
)

# Output paths
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(BASE_DIR, '..'))
TFLITE_OUT_ML = os.path.join(BASE_DIR, 'crash_classifier.tflite')
MOBILE_ASSETS_DIR = os.path.join(PROJECT_ROOT, 'mobile', 'assets', 'models')
TFLITE_OUT_MOBILE = os.path.join(MOBILE_ASSETS_DIR, 'crash_classifier.tflite')
REPORT_PATH = os.path.join(BASE_DIR, 'evaluation_report.txt')


def build_1d_cnn_model(input_shape=(WINDOW_SIZE, CHANNELS), num_classes=3) -> tf.keras.Model:
    """
    Constructs a lightweight 1D-CNN optimized for low-latency mobile inference.
    Total parameters: ~3,500 parameters (<25 KB unquantized).
    """
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=input_shape, name='imu_window_input'),
        
        # Conv Block 1: local temporal feature extraction
        tf.keras.layers.Conv1D(16, kernel_size=3, padding='same', activation='relu', name='conv1'),
        tf.keras.layers.BatchNormalization(name='bn1'),
        tf.keras.layers.MaxPooling1D(pool_size=2, name='pool1'),  # shape -> (25, 16)
        
        # Conv Block 2: higher-level kinematic oscillation & shock patterns
        tf.keras.layers.Conv1D(32, kernel_size=3, padding='same', activation='relu', name='conv2'),
        tf.keras.layers.BatchNormalization(name='bn2'),
        tf.keras.layers.GlobalAveragePooling1D(name='gap'),  # shape -> (32,)
        
        # Dense classification head
        tf.keras.layers.Dense(16, activation='relu', name='dense1'),
        tf.keras.layers.Dropout(0.2, name='dropout'),
        tf.keras.layers.Dense(num_classes, activation='softmax', name='probabilities')
    ], name='rakshak_imu_cnn')
    
    return model


def main():
    print("=" * 70)
    print("RAKSHAK-AI: PHASE 11 TFLITE CLASSIFIER TRAINING")
    print("=" * 70)
    
    # 1. Generate Synthetic Dataset
    print("\n[Step 1/5] Generating synthetic IMU windows (2,000 samples per class)...")
    X, y = generate_synthetic_dataset(n_per_class=2000, seed=42)
    print(f"Total samples: {len(y)} | Window shape: {X.shape[1:]} | Classes: {CLASSES}")
    
    # Split into 80% train, 20% held-out test
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    print(f"Train set: {X_train.shape[0]} samples | Test set: {X_test.shape[0]} samples")
    
    # 2. Build & Compile Model
    print("\n[Step 2/5] Building lightweight 1D-CNN architecture...")
    model = build_1d_cnn_model()
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.002),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    model.summary()
    
    # 3. Train Model
    print("\n[Step 3/5] Training model on synthetic data...")
    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor='val_loss',
            patience=5,
            restore_best_weights=True
        )
    ]
    history = model.fit(
        X_train, y_train,
        validation_split=0.15,
        epochs=25,
        batch_size=64,
        callbacks=callbacks,
        verbose=1
    )
    
    # 4. Evaluate on Held-out Test Set
    print("\n[Step 4/5] Evaluating model on held-out synthetic test set...")
    test_loss, test_acc = model.evaluate(X_test, y_test, verbose=0)
    y_pred_probs = model.predict(X_test, verbose=0)
    y_pred = np.argmax(y_pred_probs, axis=-1)
    
    report = classification_report(y_test, y_pred, target_names=CLASSES, digits=4)
    conf_mat = confusion_matrix(y_test, y_pred)
    
    print("\n" + "=" * 50)
    print(f"HELD-OUT TEST ACCURACY: {test_acc * 100:.2f}%")
    print("=" * 50)
    print("\nCLASSIFICATION REPORT:")
    print(report)
    print("CONFUSION MATRIX (Rows: Actual, Cols: Predicted):")
    print(f"{'':>10} {'normal':>10} {'pothole':>10} {'crash':>10}")
    for idx, row in enumerate(conf_mat):
        print(f"{CLASSES[idx]:>10} {row[0]:>10} {row[1]:>10} {row[2]:>10}")
        
    # Write evaluation report to file
    with open(REPORT_PATH, 'w') as f:
        f.write("RAKSHAK-AI PHASE 11: TFLITE MODEL EVALUATION REPORT\n")
        f.write("==================================================\n")
        f.write("NOTE ON VALIDATION DATA:\n")
        f.write("All test windows are synthetically generated to model the kinematic\n")
        f.write("specifications of vehicle collisions, road vibrations, and normal driving.\n")
        f.write("Validated against held-out synthetic distribution, NOT real crash telemetry.\n\n")
        f.write(f"Test Accuracy: {test_acc * 100:.2f}%\n")
        f.write(f"Test Loss: {test_loss:.4f}\n\n")
        f.write("Classification Report:\n")
        f.write(report + "\n\n")
        f.write("Confusion Matrix:\n")
        f.write(f"{'':>10} {'normal':>10} {'pothole':>10} {'crash':>10}\n")
        for idx, row in enumerate(conf_mat):
            f.write(f"{CLASSES[idx]:>10} {row[0]:>10} {row[1]:>10} {row[2]:>10}\n")
            
    print(f"\nSaved evaluation metrics to: {REPORT_PATH}")
    
    # 5. Convert to TensorFlow Lite
    print("\n[Step 5/5] Converting model to TensorFlow Lite (.tflite)...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    
    with open(TFLITE_OUT_ML, 'wb') as f:
        f.write(tflite_model)
    print(f"Saved TFLite model to: {TFLITE_OUT_ML} ({len(tflite_model)} bytes)")
    
    # Copy to mobile assets
    os.makedirs(MOBILE_ASSETS_DIR, exist_ok=True)
    shutil.copyfile(TFLITE_OUT_ML, TFLITE_OUT_MOBILE)
    print(f"Copied TFLite model to mobile assets: {TFLITE_OUT_MOBILE}")
    
    # 6. Verify TFLite Inference
    print("\nVerifying TFLite Interpreter inference...")
    interpreter = tf.lite.Interpreter(model_content=tflite_model)
    interpreter.allocate_tensors()
    
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    print(f"TFLite Input tensor shape: {input_details[0]['shape']}, type: {input_details[0]['dtype']}")
    print(f"TFLite Output tensor shape: {output_details[0]['shape']}, type: {output_details[0]['dtype']}")
    
    # Run test sample through interpreter
    test_sample = np.expand_dims(X_test[0], axis=0).astype(np.float32)
    interpreter.set_tensor(input_details[0]['index'], test_sample)
    interpreter.invoke()
    tflite_pred = interpreter.get_tensor(output_details[0]['index'])
    
    print(f"Interpreter test output: {tflite_pred[0]}")
    predicted_class = CLASSES[np.argmax(tflite_pred[0])]
    actual_class = CLASSES[y_test[0]]
    print(f"Verification: Predicted '{predicted_class}' (Actual: '{actual_class}')")
    print("\nTraining and TFLite export completed successfully!")


if __name__ == '__main__':
    main()
