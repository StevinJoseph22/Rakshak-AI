# Rakshak-AI Mobile Life-Guard Client (`mobile`)

> **Edge-First Crash Sensing, Keyguard Override, Sub-Second Pre-Alert Microburst, Catastrophic Phone Breakdown Watchdog, 5km Hospital Radar & Multilingual EMS Ambulance Cockpit**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
[![TFLite](https://img.shields.io/badge/Edge%20ML-TFLite-FF6F00?logo=tensorflow&logoColor=white)](https://www.tensorflow.org/lite)
[![Tests](https://img.shields.io/badge/Tests-55%20%2F%2055%20PASS-brightgreen)](test/)

---

## 📱 Overview

The `mobile` package powers two dedicated edge experiences within the Rakshak-AI emergency ecosystem:
1. **Citizen Life-Guard Mobile Application (`lib/main.dart`)**: Runs continuous 50Hz circular sensor buffers, detects high-G vehicular collisions, awakens locked smartphones over the secure keyguard, handles instant phone breakdown via cloud dead-man switches, surfaces a 5km hospital radar with Google Maps navigation, and synchronizes personal vehicle & emergency profiles.
2. **EMS Ambulance Pilot Tactical Cockpit (`lib/screens/ambulance_pilot_home_screen.dart`)**: High-contrast, sunlight-readable tactical dashboard supporting 5 major Indian languages (English, Hindi, Kannada, Tamil, Telugu), automated state transitions, and real-time C-V2X NTCIP 1202 Green Corridor telemetry.

---

## ⚡ Core Mobile Features

### 1. 💥 Catastrophic Phone Breakdown & Cloud Watchdog (Dead-Man Switch)
* **The High-Speed Crash Dilemma**: In high-velocity impacts or motorcycle accidents, smartphones are often instantly smashed under wheels, detached from batteries ($0\text{ms}$ telemetry death), or thrown into dark foliage. Victims are rendered unconscious and unable to touch a screen.
* **Sub-Second Pre-Alert Microburst (`pre_alert_service.dart`)**: Within $50\text{ms}$ of high-G impact onset—before any UI countdown screen renders—the app transmits an encrypted `impact_suspected` marker over WebSocket.
* **Cloud Watchdog Autonomous Escalation**: If the phone is pulverized and goes dead (abrupt heartbeat loss following highway speed $\ge 60\text{ km/h}$), the Cloud Watchdog promotes the suspected accident to an active emergency after $12\text{s}\text{--}30\text{s}$, dispatching police and ambulances to the last recorded GPS coordinates.
* **Interactive Simulation Dialog (`CloudWatchdogSimulationDialog`)**: Accessible in the Test Lab under **"Simulate Phone Breakdown (Cloud Watchdog)"**, providing an animated simulation of vehicle speed at $92.4\text{ km/h}$, $0\text{ms}$ heartbeat cutoff, live $12\text{s}$ countdown, and multi-agency escalation.

### 2. 🛡️ Modern Citizen UI & Google Stitch Layout (0px Overflow)
* Clean, professional UI inspired by Google Stitch with elevated card surfaces, smooth corners, and high-contrast typography.
* Optimized flex constraints across all AppBar actions, completely eliminating layout overflow (`OVERFLOWED BY 9.3 PIXELS`) on any device viewport.

### 3. 🚀 Welcome & Diagnostic Splash (`WelcomeSplashScreen`)
* Displays an animated shield upon launch with a pre-flight system checklist:
  * **GPS Satellite Lock**: Lat/lng fix within 10 meters.
  * **50Hz IMU Sensors**: Triaxial accelerometer & gyroscope streams.
  * **C-V2X Direct Sidelink**: Direct 5.9 GHz ITS transceiver status.
  * **Trauma Proximity**: Verification of local hospital radius index.

### 4. 🏍️ Dynamic Profile & Vehicle Classification (`UserProfileService`)
* Replaces all static mock placeholder data ("Aarav Sharma") with persistent local profile settings.
* **Interactive Vehicle Class Selection**:
  * **Two-Wheeler (Motorcycle / Scooter)**: Bypasses enclosed cabin pressure pulse requirements; tunes rollover angular rate thresholds.
  * **Four-Wheeler (Car / SUV)**: Arms barometric pressure sensor for in-cabin airbag deployment spikes ($\Delta P \ge 1.5\text{ hPa}$).
* **Safe Driving Insights Card**:
  * Distance Traveled Today (`14.2 km Logged via GPS`).
  * Safety Score (`98/100 Smooth Vector`).
  * Overspeeding Violations (`0 Violations`).

### 5. 🏥 5km Hospital Radar with Fallback & Google Maps Directions
* Implemented in [`hospital_radar_screen.dart`](lib/screens/hospital_radar_screen.dart) and [`hospital_directory_service.dart`](lib/services/hospital_directory_service.dart).
* Real-time Haversine distance and driving ETA calculation from live device GPS.
* **5km Radius Filter**: Displays all accredited trauma centers within 5.0 km (e.g. Banaswadi region `13.013, 77.649`).
* **Dynamic Fallback Notice**: If outside a 5km radius:
  > *"No trauma center found within 5.0 km of your location. Nearest next available: [Hospital Name] (X.X km)"*
* **Turn-by-Turn Google Maps Navigation**: Tapping any card launches Google Maps directions via `https://www.google.com/maps/dir/?api=1&destination=lat,lng`.
* **One-Touch Emergency Hotline**: Direct telephone dialing to the hospital's 24/7 casualty desk.
* Includes all 26 Bengaluru trauma centers, including **Specialist Hospital, Banaswadi / HRBR Layout** (`13.0180, 77.6450`).

### 6. ⚙️ Dedicated Citizen Settings & Medical ID / ABHA
* Dedicated Settings Screen ([`citizen_settings_screen.dart`](lib/screens/citizen_settings_screen.dart)) for rider name, vehicle classification, license plate, emergency contacts, and blood group.
* **Medical ID Navigation**: Tapping **Medical ID** in the bottom navigation bar routes directly to the Ayushman Bharat Digital Mission (ABDM / ABHA) Health Card settings.

### 7. 🚑 Multilingual EMS Ambulance Pilot Cockpit
* Dedicated standalone pilot screen ([`ambulance_pilot_home_screen.dart`](lib/screens/ambulance_pilot_home_screen.dart)).
* **5 Major Indian Languages**: 1-tap language switching for ambulance drivers:
  * 🇬🇧 **English**
  * 🇮🇳 **हिंदी (Hindi)**
  * 🇮🇳 **ಕನ್ನಡ (Kannada)**
  * 🇮🇳 **தமிழ் (Tamil)**
  * 🇮🇳 **తెలుగు (Telugu)**
* **Automated Status State Machine**: Replaces manual dropdowns with automated progression:
  `Claimed` $\rightarrow$ `En Route` $\rightarrow$ `On Scene` $\rightarrow$ `In Transit` $\rightarrow$ `Handover Complete`.
* **C-V2X Green Corridor HUD**: Shows live NTCIP 1202 preemption status and distance to upcoming signals.

---

## 📁 Directory Structure

```text
mobile/
├── android/                           # Android native configuration
│   ├── app/src/main/kotlin/           # MethodChannel handlers (SmsManager, Keyguard override)
│   └── app/src/main/AndroidManifest.xml # Permissions (USE_FULL_SCREEN_INTENT, SEND_SMS)
├── assets/
│   └── models/
│       └── crash_classifier.tflite    # Pre-trained edge kinematic TFLite model
├── lib/
│   ├── main.dart                      # Citizen Life-Guard Application entrypoint
│   ├── ambulance_pilot_app.dart       # EMS Ambulance Pilot Application entrypoint
│   ├── models/
│   │   ├── crash_event.dart           # Kinematic telemetry payload model
│   │   ├── emergency_health_card.dart # ABDM emergency profile and provenance fields
│   │   ├── hospital_model.dart        # Hospital facility model with distance & ETA
│   │   └── incident_model.dart        # SQLite offline dispatch record model
│   ├── screens/
│   │   ├── welcome_splash_screen.dart # Diagnostics checklist welcome splash
│   │   ├── citizen_settings_screen.dart # Citizen profile, vehicle class & SOS settings
│   │   ├── hospital_radar_screen.dart # 5km hospital radar with Google Maps navigation
│   │   ├── crash_detection_screen.dart # Real-time sensor telemetry & Guard controls
│   │   ├── locked_screen_alert_screen.dart # Keyguard-bypassing 10s countdown alert
│   │   ├── ambulance_dispatch_screen.dart  # Paramedic incident view with road distance
│   │   ├── ambulance_pilot_home_screen.dart # Multilingual cockpit (5 Indian languages)
│   │   ├── abha_onboarding_screen.dart # Citizen ABHA ID linking & local AES-256 vault
│   │   ├── emergency_contacts_screen.dart  # Management of native SIM SMS contacts
│   │   └── test_lab_screen.dart       # Developer simulation bench for impact spikes
│   ├── widgets/
│   │   ├── cloud_watchdog_simulation_dialog.dart # Interactive phone breakdown simulator
│   │   └── c_v2x_hardware_dialog.dart # OBU transceiver selector & antenna monitor
│   └── services/
│       ├── crash_detector_service.dart # 50Hz IMU circular buffer, peak-G & speed drop
│       ├── pre_alert_service.dart     # Keyguard override, buzzer & sub-second pre-alert
│       ├── user_profile_service.dart  # Local profile persistence (name, 2W/4W, plate)
│       ├── hospital_directory_service.dart # 26-hospital registry, 5km filter & Maps launcher
│       ├── offline_dispatch_queue.dart # Delay-tolerant SQLite queue (30m emergency TTL)
│       ├── photo_stream_service.dart  # 3-tier photo upload: WebRTC -> WebSocket -> HTTP
│       ├── vehicle_obu_service.dart   # C-V2X PC5 direct sidelink OBU simulator
│       ├── emergency_sms_service.dart # Native telephony P2P SMS dispatcher
│       ├── emergency_contact_service.dart # SharedPreferences contact persistence
│       ├── location_service.dart      # High-frequency GPS position and speed tracker
│       └── trip_sentinel_client.dart  # Highway journey dead-man telemetry worker
└── test/
    ├── ambulance_pilot_app_test.dart  # Paramedic cockpit rendering & state tests
    ├── crash_detector_service_test.dart # Kinematic filters, peak-G & false-positive rejection
    ├── locked_screen_alert_test.dart  # Countdown timer & keyguard override tests
    ├── photo_stream_service_test.dart # WebRTC signaling & fallback transport tests
    ├── phase18_health_card_widget_test.dart # ABDM provenance & field rendering tests
    └── widget_test.dart               # Guard toggle, Test Lab, simulation trigger & Intake tests
```

---

## 🧪 Testing & Verification

The mobile test suite contains **55 automated unit, kinematic, and widget tests** covering all operational flows:

```bash
flutter test
```

### Test Suite Breakdown

| Test File | Tests | Key Validations |
| :--- | :---: | :--- |
| `widget_test.dart` | 4 | Initial guard state, Test Lab mode toggle, impact simulation navigation, zero-gallery intake banner |
| `ambulance_pilot_app_test.dart` | 2 | Multilingual tab switching, automated state machine progression, C-V2X HUD |
| `crash_detector_service_test.dart` | 6 | 50Hz sensor buffer, pothole/speed-bump false-positive rejection, free-fall drop invalidation, rollover detection |
| `locked_screen_alert_test.dart` | 4 | 10-second countdown timer, "I'm OK" cancellation, auto-broadcast completion, keyguard dismissal |
| `photo_stream_service_test.dart` | 8 | 3-tier transport failover: WebRTC peer negotiation $\rightarrow$ WebSocket binary $\rightarrow$ HTTP POST fallback |
| `phase18_health_card_widget_test.dart` | 31 | ABDM health card serialization, field-level provenance badges, break-glass view constraints |
| **Total Suite** | **55** | **100% Passed with 0 Errors** |

---

## 🚀 Running the App

### Prerequisites
* Flutter SDK (v3.24+ recommended).
* Android device or emulator running API 26+ (Android 8.0 Oreo or higher for full-screen intents).

### Steps
1. Navigate to the `mobile` directory:
   ```bash
   cd mobile
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run all tests:
   ```bash
   flutter test
   ```
4. Reverse backend ports for 0ms local debugging:
   ```bash
   adb reverse tcp:5000 tcp:5000
   ```
5. Run the Citizen Life-Guard app:
   ```bash
   flutter run
   ```
6. Or run the EMS Ambulance Pilot Cockpit:
   ```bash
   flutter run lib/ambulance_pilot_app.dart
   ```
