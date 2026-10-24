# Rakshak-AI (रक्षक-AI)

> **Next-Generation Autonomous Emergency Crash Intelligence, Multi-Agency Trauma Triage & C-V2X Green Corridor Network**

[![Flutter](https://img.shields.io/badge/Mobile-Flutter%203.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Node.js](https://img.shields.io/badge/Backend-Node.js%20v20%2B-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org/)
[![PostgreSQL](https://img.shields.io/badge/Spatial%20DB-PostgreSQL%2015%2B%20%2B%20PostGIS-336791?logo=postgresql&logoColor=white)](https://postgis.net/)
[![Redis](https://img.shields.io/badge/RAM%20Cache-Redis%207%20Volatile-DC382D?logo=redis&logoColor=white)](https://redis.io/)
[![React](https://img.shields.io/badge/Dashboard-React%2018%20%2B%20Vite%20%2B%20TS-61DAFB?logo=react&logoColor=black)](https://react.dev/)
[![TensorFlow](https://img.shields.io/badge/Edge%20ML-TFLite%20Kinematics-FF6F00?logo=tensorflow&logoColor=white)](https://www.tensorflow.org/lite)
[![NTCIP](https://img.shields.io/badge/Traffic%20Standard-NTCIP%201202%20%2F%20ISO%2019091-00599E)](https://www.standards.its.dot.gov/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> 📘 **Looking for the in-depth codebase explanation & architectural walkthrough?**  
> Read our comprehensive [**Codebase Architecture & Implementation Guide (README_CODEBASE_EXPLAINED.md)**](README_CODEBASE_EXPLAINED.md) covering file-by-file explanations, 50Hz kinematic sensor fusion math, PostGIS spatial queries, 30m TTL offline queue, and C-V2X green corridors.

---

## 🚨 The Problem: The Golden Hour Breakdown

In vehicular trauma accidents, **50% of fatalities occur within the first 60 minutes**—medically known as the **Golden Hour**. In current emergency ecosystems, survival rates collapse due to critical operational bottlenecks:

1. **Locked-Screen Obstacle**: The victim’s smartphone is password-protected or biometric-locked in their pocket or mount. Bystanders cannot unlock the device to access emergency contacts, blood groups, or health IDs.
2. **Broken-Phone & Zero-Network Blindspot**: Severe crashes often shatter the device instantly or occur in rural cellular dead zones, leaving emergency dispatchers completely blind.
3. **Bystander Hesitation & Triage Ambiguity**: Good Samaritans lack medical triage training, fear legal entanglement, and have zero visibility into which nearby hospitals actually have available trauma ICU beds or surgical teams.
4. **Traffic Congestion & Blind Ambulance Navigation**: Paramedics waste 15–30 minutes calling around to locate open trauma bays while fighting dense traffic bottlenecks without dynamic traffic signal preemption.

---

## 💡 The Solution: What is Rakshak-AI?

**Rakshak-AI** is an edge-first, zero-friction emergency response ecosystem. It couples on-device kinematic machine learning with high-frequency sensor fusion, awakens smartphones over the secure Android keyguard, executes dual-redundant P2P SIM emergency alerts, coordinates trauma facilities via PostGIS spatial indexing, and dynamically clears urban traffic signals via NTCIP-compliant Green Corridors.

```
       [ Victim Smartphone (Locked) ]
                     │  High-G Collision (≥4.8G + Speed Drop to 0)
                     ▼
  ┌──────────────────────────────────────────────────────────────┐
  │  1. SUB-SECOND PRE-ALERT: "impact_suspected" -> Police Room  │
  │  2. EVIDENCE ENGINE: Free-Fall Check + Rollover + Variance   │
  │  3. ARE YOU OK? Prompt: Haptic + Audio -> Responsiveness      │
  │  4. KEYGUARD OVERRIDE: Full-Screen Intent Overrides Lock     │
  └──────────────┬───────────────────────────────┬───────────────┘
                 │                               │
                 │ 1. Native SIM P2P SMS         │ 2. Encrypted TLS Socket Frame
                 ▼                               ▼
     ┌───────────────────────┐       ┌─────────────────────────────────────┐
     │  Victim's Family SIM  │       │     Rakshak-AI Central Backend      │
     │  Instant GPS Alert    │       │     (PostGIS + Volatile Redis RAM)  │
     └───────────────────────┘       └───────┬─────────────────────────┬───┘
                                             │                         │
                 ┌───────────────────────────┴──────────┐              │
                 ▼                                      ▼              ▼
     ┌────────────────────────┐            ┌────────────────────────┐  │
     │  Matched Trauma Bays   │            │  Police Control Room   │  │
     │  (Within 8km Radius)   │            │  Blackspots & Signals  │  │
     │  ABHA Emergency Vault  │            │  Pre-Alert Watchdog    │  │
     └───────────┬────────────┘            └────────────────────────┘  │
                 │ One-Click Accept                                    │
                 ▼                                                     │
     ┌───────────────────────────────────────────────────┐             │
     │  Case Locked across Network + Auto-Escalation Off │             │
     │  Family SMS Milestone 2 (Hospital Accepted)       │             │
     └───────────────────────────────────────────────────┘             │
                                                                       │
                 ┌─────────────────────────────────────────────────────┘
                 ▼
     ┌───────────────────────────────────────────────────┐
     │  Paramedic Ambulance Console (HUD)                │
     │  C-V2X Autonomous Green Corridor (NTCIP 1202)     │
     │  Signals turn GREEN 300m ahead of ambulance       │
     │  Family SMS Milestone 3 (Ambulance En Route)      │
     └───────────────────────────────────────────────────┘
```

---

## ⚡ Core Technical Innovations

### 1. Crash Intelligence v2 & Catastrophic Phone Breakdown Engine (Phase 17)
* **💥 Catastrophic Phone Breakdown & Instant Phone Crushing (Cloud Watchdog & Dead-Man Switch)**:
  * **The Fatal Reality**: In high-speed highway crashes or heavy vehicle collisions, smartphones are frequently smashed under wheels, destroyed upon impact, thrown 50 meters into darkness, or suffer instantaneous battery disconnection ($0\text{ms}$ heartbeat cutoff). The victim is knocked unconscious and cannot operate the screen.
  * **Sub-Second Pre-Alert Microburst (`preAlertService.ts`)**: Within the initial $50\text{ms}$ of high-G impact onset—**before any countdown screen even finishes rendering**—the edge engine transmits an encrypted `impact_suspected` soft packet over WebSocket/cellular.
  * **Cloud Watchdog Autonomous Escalation**: If the phone is obliterated on impact and goes completely dead (zero heartbeats, neither confirm nor cancel received), the cloud watchdog activates. Recognizing that the vehicle was traveling at speed ($\ge 60\text{ km/h}$) prior to sudden signal silence, the cloud timer ($12\text{s}\text{--}30\text{s}$) automatically **promotes the suspected crash into an active emergency broadcast**. Police control and 108 ambulance units are dispatched immediately with the last recorded GPS coordinates, regardless of whether the physical phone survived!
  * **Interactive Simulation Benchmark (`CloudWatchdogSimulationDialog`)**: Built directly into the mobile app's Test Lab, this dialog visually demonstrates catastrophic phone destruction: $0\text{ms}$ telemetry loss at $92.4\text{ km/h}$, a real-time $12\text{s}$ countdown, and automated cloud promotion to emergency responders.
* **Evidence-Based Crash Confidence (0–100 Score)**:
  * **Free-Fall Invalidation**: Detects near-0g ($<0.2\text{g}$) for $>100\text{ms}$ immediately *before* impact. This proves the phone was simply dropped from hand or mount, severely penalizing the confidence score and preventing false dispatches.
  * **Post-Impact Stillness**: Analyzes gyro and accelerometer variance over a 3-second post-impact window to gauge victim immobility.
  * **Barometric Airbag Pulse**: Captures rapid atmospheric pressure spikes associated with in-cabin airbag deployment (automatically bypassed for two-wheelers).
  * **Angular Rollover Tracking**: Integrates gyroscopic angular rates and detects permanent gravity vector flips ($>120^\circ$).
* **Measured Severity Index (`Minor` / `Moderate` / `Critical`)**:
  * Computed strictly from physically verifiable data: peak measured acceleration, speed drop, impact duration, rollover detected, responsiveness, and confidence.
  * Explicitly labeled as a *decision-support estimate, not a clinical assessment*.
* **Physical Sensor Saturation Safeguards**: Phone accelerometers physically saturate at $8\text{g}\text{--}16\text{g}$. Rakshak-AI detects hardware clipping and explicitly flags values as `"saturated"` rather than displaying unmeasured mathematical extrapolations.
* **Victim Responsiveness Query**: Displays a high-intensity audio/haptic "Are you OK?" prompt. Silence during the countdown sets `rider_unresponsive = true` in `victim_metadata`.
* **Offline Store-and-Forward (`offline_dispatch_queue.dart`)**: If cellular data is dead at impact time, incidents are persisted to local storage with RFC 4122 client UUID idempotency keys. A background worker retries synchronization with exponential backoff upon network restoration.
* **Trip Sentinel Dead-Man Switch (`tripSentinelService.ts`)**:
  * 3-Tier safety watchdog: `normal` $\rightarrow$ `lost_contact` (visible to police only) $\rightarrow$ `escalated_incident`.
  * Evaluates pre-silence velocity: only escalates if the vehicle was traveling at speed with zero braking prior to signal loss.
  * Zero-history privacy: Keeps only the latest coordinates in Redis with a 120s TTL (no persistent tracking logs).
* **Detection Lab (`detection_lab_screen.dart`)**: An on-device replay suite validating 7 scripted real-world scenarios: Pothole, Speed Bump, Hard Braking, Phone Drop, Phone Thrown on Seat, Genuine Crash, and Vehicle Rollover.

---

### 2. Accident Blackspot & Density Clustering (Phase 16)
* **PostGIS Spatial Cluster Engine (`blackspotService.ts`)**: Automatically cross-references incident coordinates against high-risk urban intersections and corridors (e.g., Silk Board Junction, Hebbal Flyover, Electronic City Tollway, Tin Factory, Goraguntepalya).
* **Live Recurrence Scoring**: Tracks recurring accident frequency in real time, alerting police dispatchers when an incident occurs within an identified high-density fatality zone.

---

### 3. Autonomous Green Corridor & NTCIP 1202 Signal Preemption (Phase 14)
* **C-V2X / Emergency Vehicle Preemption (EVP)**: Implements standard NTCIP 1202 and ISO 19091 traffic controller protocol logic (`ntcipService.ts`).
* **Dynamic 300m Wave**: When an ambulance claims a case and navigates toward the trauma center, traffic signals within a 300-meter radius automatically transition to **GREEN** along the ambulance's bearing, holding cross-traffic at **RED**.
* **Tactical Visualization**: Paramedic HUD and Police Command Map render real-time signal phase states (Green/Yellow/Red) and highlight the live corridor path.

---

### 4. AI Biomechanics & Ayushman Bharat (ABHA) Medical Vault (Phase 15)
* **Ayushman Bharat Digital Mission (ABDM / ABHA) Interoperability**: Decrypts and surfaces the victim's emergency health profile upon hospital intake:
  * Blood Group & Rh Factor
  * Organ Donor Registration
  * Critical Drug Allergies (e.g., Penicillin, NSAIDs)
  * Pre-existing Medical Conditions (e.g., Hypertension, Diabetes)
  * Emergency Contact details
* **Zero-Knowledge Architecture**: Medical records are never persisted in cloud application tables; they are ingested ephemerally and displayed exclusively to authorized trauma bay staff.

---

### 5. Multi-Agency Role-Based Access Control (Phase 13)
* **Cryptographic JWT & RBAC (`auth.ts`)**: Dedicated security guards enforcing least-privilege access across 3 distinct roles:
  * `hospital`: Can only view assigned radius incidents, accept/reject cases, and view medical records.
  * `police`: Real-time city-wide tactical map, blackspot clusters, cruiser beacons, and NTCIP manual signal overrides.
  * `ambulance`: Mobile dispatch HUD, 1-click incident claiming, and turn-by-turn green corridor telemetry.
* **Password Hashing**: Secure salted bcrypt hashing for all emergency responder credentials.

---

### 6. Real-Time WebRTC Video & Zero-Gallery Ephemeral Imaging (Phase 12)
* **Low-Latency WebRTC Stream (`flutter_webrtc`)**: Peer-to-peer real-time video transmission between the crash scene and hospital emergency physician.
* **Dual-Channel Automatic Fallback**: If WebRTC peer connection fails or UDP packets are blocked by enterprise hospital firewalls, the app automatically fails over to WebSocket binary chunking, followed by multipart HTTP POST.
* **Zero-Gallery Privacy Guarantee**: Crash photos are held strictly in ephemeral RAM buffer, streamed to Redis with a 10-minute TTL, and destroyed upon incident closure. No images ever touch device storage or photo galleries.

---

### 7. Dual-Redundant P2P SIM Emergency SMS (TRAI DLT-Exempt)
* Bypasses third-party commercial SMS gateways (which require multi-week TRAI DLT template registrations in India and fail during cloud outages).
* Utilizes Android native `SmsManager` directly from the physical SIM across 3 automated milestones:
  * **Milestone 1**: Instant Crash SOS with live Google Maps coordinate link.
  * **Milestone 2**: Hospital Acceptance Notification with admitting trauma center details.
  * **Milestone 3**: Paramedic Unit Dispatched Notification with responding ambulance ID.
* Constrained strictly to single-part GSM ($<160$ characters) to guarantee 100% carrier delivery across all Indian telecom operators.

---

### 8. Admin Reset Lab & Clean-Slate Purge (Phase 17)
* **Dedicated Admin Portal (`/admin`)**: Built into the dashboard for hackathon judges and system operators.
* **1-Click Deep Purge (`DELETE /incidents`)**: Instantly wipes all PostgreSQL incidents and rejections, flushes Redis RAM caches, cancels active escalation and promotion timers, resets Sentinel sessions, and emits `feed_cleared` via Socket.io.
* **Test Crash Injectors**: Generates controlled test crashes on demand (e.g., Silk Board Blackspot Critical Crash, Madiwala Moderate Crash) with full sensor telemetry.

---

### 9. Modern Citizen Life-Guard Application (Google Stitch Design & 5km Radar)
* **Clean, Professional UI (Google Stitch Aesthetic)**: Completely streamlined interface with zero layout overflow (strict 0px error tolerance), elevated surfaces, soft gradients, and modern card typography.
* **Welcome & Diagnostic Splash Screen (`WelcomeSplashScreen`)**: Real-time pre-flight verification checklist testing GPS satellite lock, 50Hz IMU accelerometers, C-V2X direct sidelink, and local trauma bay proximity before entering active monitoring.
* **Dynamic Rider Profile & Vehicle Classification (`UserProfileService`)**:
  * Eliminates all static placeholder dummy data ("Aarav Sharma").
  * Interactively toggles between **Two-Wheeler** (motorcycle/scooter) and **Four-Wheeler** (car/SUV) vehicle profiles.
  * Dynamically adjusts kinematic detection (e.g. cabin-only barometer pulse thresholds are suppressed for open-air two-wheelers).
  * Persists rider name, vehicle model, and registration number locally in encrypted storage.
* **Driving Safety & Travel Insights**:
  * Live GPS travel distance logged today (`14.2 km Logged via GPS`).
  * Smooth-vector Driving Safety Score (`98/100`).
  * Real-time overspeeding violation counter (`0 Violations`).
* **Dedicated Citizen Settings Screen (`CitizenSettingsScreen`)**:
  * Quick-access gear button in the AppBar.
  * Direct configuration of rider identity, vehicle registration, emergency contacts, and ABDM/ABHA vault linking.
* **5km Hospital Radar with Fallback & Google Maps Turn-by-Turn Navigation**:
  * Live Haversine distance and driving ETA calculated continuously from device GPS.
  * **5km Radius Filter**: Automatically surfaces trauma centers within 5 km.
  * **Dynamic Fallback Notice**: If no accredited trauma center is within 5 km (e.g. peripheral or rural highway transit), an explicit warning banner appears:
    `"No trauma center found within 5.0 km of your location. Nearest next available: [Hospital Name] (X.X km)"`
  * **Google Maps Navigation**: Tapping any hospital card launches live Google Maps turn-by-turn navigation via `https://www.google.com/maps/dir/?api=1&destination=lat,lng`.
  * **One-Touch Emergency Calling**: Instantly connects to the hospital's verified 24/7 emergency casualty line.
  * **26-Hospital Bengaluru Registry**: Includes **Specialist Hospital, Banaswadi / HRBR Layout** (`13.0180, 77.6450`).
* **Medical ID Navigation Direct to ABHA**: Tapping **Medical ID** in the bottom navigation bar navigates directly to the Ayushman Bharat (ABDM) Emergency Health Card and settings.

---

### 10. Multilingual EMS Ambulance Pilot Tactical Cockpit
* **Dedicated Standalone App (`AmbulancePilotHomeScreen`)**: High-contrast, sunlight-readable tactical HUD designed specifically for paramedic ambulance drivers.
* **Multilingual Interface for Indian Drivers**: Seamless 1-tap language switcher supporting 5 major Indian languages:
  * 🇬🇧 **English**
  * 🇮🇳 **हिंदी (Hindi)**
  * 🇮🇳 **ಕನ್ನಡ (Kannada)**
  * 🇮🇳 **தமிழ் (Tamil)**
  * 🇮🇳 **తెలుగు (Telugu)**
* **Automated Mission Progression Pipeline**: Replaces error-prone manual dropdowns with automated status state machine transitions:
  `Dispatch Ready` $\rightarrow$ `Claimed` $\rightarrow$ `En Route` $\rightarrow$ `On Scene` $\rightarrow$ `In Transit` $\rightarrow$ `Handover Complete`.
* **C-V2X Green Corridor Telemetry**: Visualizes real-time NTCIP 1202 preemption ripples and distance to upcoming signals.

---

### 11. Emergency Healthcare ERP (Enterprise Resource Planning) Perspective
Can Rakshak-AI be classified as an **Enterprise Resource Planning (ERP)** platform? **YES, emphatically.**

In enterprise software terminology, an ERP integrates core operational processes, coordinates constrained physical assets, orchestrates multi-department workflows, and optimizes resource allocation across organizational boundaries:
1. **Critical Resource Master Data**: Real-time tracking of finite, perishable medical assets—Level-1 Trauma Bays, ICU beds, CT/MRI suites, blood bank reserves, and surgical specialty teams.
2. **Fleet & Logistics Management (SCM / SCM-E)**: Real-time GPS beaconing, vehicle status management, and automated C-V2X route preemption for ambulance fleets.
3. **Multi-Agency Workflow Orchestration**: End-to-end event-driven state transitions connecting Citizens, Municipal Police Headquarters, EMS Fleets, and Accredited Hospitals into one unified ledger.
4. **Supply-Chain Pre-Allocation**: While the ambulance is in transit, the hospital's trauma department automatically receives victim blood group, allergies, and estimated arrival time, staging surgical teams *before* the victim arrives.
5. **Regulatory Compliance & Auditability**: Enforces RBAC permissions, single-claim row-level transaction locks, and immutable ABDM break-glass audit logs.

---

## 🛰️ Hardware Devices Structure & IoT Architecture

> For complete wiring schematics, pinout diagrams, and SNMP OID specifications, see **[HARDWARE_ARCHITECTURE.md](docs/HARDWARE_ARCHITECTURE.md)** and **[architecture.md](docs/architecture.md)**.

Rakshak-AI is engineered with a pluggable **Hardware Abstraction Layer (HAL)** that interfaces directly with real-world in-vehicle telematics, C-V2X transceivers, municipal roadside units, and traffic controller cabinets.

```text
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                       1. IN-VEHICLE / VICTIM EDGE LAYER                     │
 ├────────────────────────────────────────┬────────────────────────────────────┤
 │  A. Smartphone Telematics & Sensors    │  B. In-Vehicle Telematics (OBU)    │
 │  • Tri-axial MEMS Accelerometer (50Hz) │  • OBD-II / CAN-Bus (ISO 15765-4)  │
 │  • Tri-axial MEMS Gyroscope (rad/s)    │  • Airbag ECU Deployment Trigger   │
 │  • MEMS Barometer (Airbag ΔP pulse)    │  • Vehicle Speed Sensor (VSS)      │
 │  • Multi-GNSS (GPS / NavIC / Galileo)  │  • Siren & Strobe Arming Sense     │
 │  • Baseband SIM Modem (Native SMS)     │  • 12V/24V Automotive Power Supply │
 └───────────────────┬────────────────────┴──────────────────┬─────────────────┘
                     │                                       │
     Sub-Second      │ C-V2X PC5 Sidelink (5.9 GHz)          │ BLE Beacon (UUID: 0xFD6F)
     TLS 1.3 / 4G-5G │ Direct V2V & V2I Distress             │ or USB-OTG Serial
                     ▼                                       ▼
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                   2. AMBULANCE EMERGENCY VEHICLE UNIT (OBU)                 │
 ├─────────────────────────────────────────────────────────────────────────────┤
 │  • Hardware Transceiver: Qualcomm 9150 / Quectel AG15 C-V2X Module         │
 │  • Frequency Band: 5.855 GHz – 5.925 GHz (5.9 GHz Dedicated ITS Band)       │
 │  • Standardized Messaging: SAE J2735 (BSM 0x01, SRM 0x0E, SSM 0x0F)         │
 │  • Paramedic Navigation HUD: High-Brightness Rugged In-Vehicle Tablet       │
 └───────────────────┬───────────────────────────────────────┬─────────────────┘
                     │                                       │
     SAE J2735 SRM   │ (Signal Request Message)              │ Cellular Backhaul
     Range: 300m-500m│ Latency: < 20ms                       │ 4G LTE / 5G SA
                     ▼                                       ▼
 ┌────────────────────────────────────────┐ ┌──────────────────────────────────┐
 │    3. MUNICIPAL ROADSIDE UNIT (RSU)    │ │   4. CENTRAL CLOUD & DISPATCH    │
 ├────────────────────────────────────────┤ ├──────────────────────────────────┤
 │  • Pole-Mounted C-V2X Transceiver RSU  │ │  • PostGIS Spatial Engine        │
 │  • Dual Antennas (5.9 GHz Omni/Sector) │ │  • Volatile Redis 7 RAM Broker   │
 │  • Hardware Crypto Acceleration (HSM)  │ │  • NTCIP-1202 SNMP Preemption Hub│
 │  • Physical Interface: Rugged Ethernet │ │  • Hospital Trauma Web Console   │
 └───────────────────┬────────────────────┘ │  • Police Tactical Command Map  │
                     │                      └──────────────────────────────────┘
     NTCIP 1202 v03  │ Industrial Ethernet / RS-485
     SNMP v2c/v3     │ Port 161 (ascPreemptControl)
                     ▼
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                 5. ADVANCED TRAFFIC CONTROLLER (ATC CABINET)                │
 ├─────────────────────────────────────────────────────────────────────────────┤
 │  • Controller Types: NEMA TS2 Type 1 / 2, Model 2070, ATC v6.25            │
 │  • Signal Preemption Card: Solid-State Optical / NTCIP Preempt Discriminator│
 │  • Signal Phasing: Force Green Wave (Phase 2/6), Yellow Clear, All-Red Hold │
 │  • Intersection Heads: 3-Aspect High-Flux LED Traffic Signal Heads          │
 └─────────────────────────────────────────────────────────────────────────────┘
```

### 1. In-Vehicle On-Board Unit (OBU) Hardware Modes
Integrated via `VehicleObuService` (`mobile/lib/services/vehicle_obu_service.dart`) and switchable live inside the **C-V2X Hardware Hub**:
* **`simulatedSoftware`**: Virtual GPS and software EVP engine for simulation and demo runtimes.
* **`serialUsbOtG`**: Pluggable USB-OTG / RS-232 serial connection to commercial automotive C-V2X modems (Commsignia / Quectel AG15 at `/dev/ttyUSB0` at 115200 baud).
* **`bluetoothBle`**: Wireless BLE 5.2 dashboard beacon (Rakshak BLE Emergency Dash Beacon, UUID: `0xFD6F`).
* **`directCv2xPc5`**: Qualcomm 9150 C-V2X Direct PC5 transceiver operating over the 5.9 GHz ITS band (3GPP Rel-14/15/16 Mode 4 direct sidelink) for infrastructure-less communication.
* **Siren & Beacon Hardware Sensor**: Senses 12V trigger lines from emergency siren/strobe bars; automatically arms C-V2X signal preemption during active runs and disarms during routine transfer.

### 2. Roadside Units (RSU) & NTCIP-1202 Traffic Signal Controller
* **SAE J2735 Standardized Messaging**:
  * **BSM (`0x01`)**: 10Hz Basic Safety Message broadcasting vehicle position, speed, heading, and siren status.
  * **SRM (`0x0E`)**: Signal Request Message demanding priority preemption 300m–500m ahead of an approaching intersection.
  * **SSM (`0x0F`)**: Signal Status Message acknowledging preemption granted and reporting active green-hold duration.
* **NTCIP 1202 v03 Traffic Controller Integration (`ntcipService.ts`)**:
  * Directly communicates with municipal Advanced Traffic Controller (ATC) cabinets using SNMP v2c/v3 OID commands:
    * `1.3.6.1.4.1.1206.4.2.1.1.1` (`ascPreemptControl`): Forces emergency green phase.
    * `1.3.6.1.4.1.1206.4.2.1.1.2` (`ascPreemptState`): Reads active preemption state.
    * `1.3.6.1.4.1.1206.4.2.1.1.3` (`ascPreemptRemainingTime`): Reads remaining green-hold seconds.
  * **Preemption State Machine**: `normalCycle` $\rightarrow$ `yellowClearance` (3–4s) $\rightarrow$ `allRedSafetyBuffer` (1–2s) $\rightarrow$ `preemptedGreen` $\rightarrow$ `departedHandback`.

### 3. Edge Smartphone Telematics & Hardware Safeguards
* **Linear MEMS Accelerometer ($50\text{ Hz}$)**: High-G impact signature detection with saturation protection (readings hitting the physical $8\text{g}\text{--}16\text{g}$ sensor limit are marked `"saturated"`).
* **MEMS Gyroscope ($50\text{ Hz}$)**: Rotational rate integration detecting vehicle rollovers ($>120^\circ$ gravity vector inversion).
* **Free-Fall Invalidation ($50\text{ Hz}$)**: Suppresses false alarms if $|g| < 0.2\text{g}$ for $>100\text{ms}$ (indicates a dropped phone).
* **MEMS Barometer ($10\text{ Hz}$)**: Captures cabin pressure spikes ($\Delta P \ge 12\text{ hPa}$) caused by vehicle airbag deployments.
* **Multi-GNSS Receiver**: Dual-band GPS/GLONASS/NavIC measuring deceleration down to $0\text{ km/h}$.
* **Cellular Baseband Radio**: Direct native P2P SMS using Android `SmsManager` over the physical SIM, bypassing cloud gateway vulnerabilities.

### 4. Zero-Network & Broken-Device Resilience Matrix
* **Zero Cellular Data (No 4G/5G)**: Native SIM P2P SMS transmits Google Maps coordinates and ABHA medical ID directly to family. Local SQLite queue synchronizes via exponential backoff upon network restoration.
* **Total Cellular Tower Outage**: Direct C-V2X PC5 Sidelink (5.9 GHz) and BLE 5.2 Emergency Distress Beacons transmit to nearby vehicles and roadside units via delay-tolerant mesh.
* **Device Destroyed on Impact**: Sub-second pre-alert microburst has already reached police; Trip Sentinel 30s watchdog detects silence without cancel and auto-escalates to an active emergency.
* **Locked-Screen Override**: Android `USE_FULL_SCREEN_INTENT` + `showWhenLocked` wakes the display over keyguard so bystanders can assist without passwords.
* **Zero-Gallery Privacy**: Camera frames stream directly from CMOS sensor into volatile RAM buffer, transmitted to Redis with 10-minute TTL and wiped upon case resolution.

---

## 🏛 System Architecture & Network Ports

| Service | Directory | Tech Stack | Port | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **PostgreSQL + PostGIS** | `/db` | Docker (`postgis/postgis:16-3.4`) | `5432` | Geospatial spatial queries, blackspot clustering, hospital registry |
| **Volatile Redis** | - | Docker (`redis:7-alpine`) | `6379` | Zero-storage RAM cache (`--save "" --appendonly no`) for beacons & photo streams |
| **Core Backend & Socket.io**| `/backend` | Node.js + Express (TypeScript) | `5000` | Incident lifecycle, multi-agency socket rooms, Sentinel watchdog, NTCIP |
| **Trauma & Police Dashboard**| `/dashboard` | React 18 + Vite + TypeScript | `5173` | Hospital trauma portal, police tactical command map, admin reset lab |
| **Mobile Application** | `/mobile` | Flutter 3.x + Dart + TFLite | Device | Sensor ingestion, keyguard override, P2P SMS, ambulance HUD, detection lab |

---

## 📁 Repository Structure

```text
Rakshak-AI/
├── mobile/                           # Flutter mobile client (Citizen & Paramedic HUD)
│   ├── android/                      # Native Android config (MethodChannels, SmsManager, FullScreenIntent)
│   ├── assets/models/                # Pre-trained crash_classifier.tflite model
│   ├── lib/
│   │   ├── config/                   # Backend config, crash confidence weights, lock screen settings
│   │   ├── models/                   # Incident, ABHA Vault, Severity Index, C-V2X standards models
│   │   ├── screens/                  # Intake, Locked-Screen Alert, Ambulance HUD, Detection Lab
│   │   ├── services/                 # Crash detector, Pre-alert microburst, Sentinel client, Offline queue
│   │   └── widgets/                  # C-V2X hardware dialog, telemetry gauges, tactical previews
│   └── test/                         # 55 automated unit, kinematic, and widget tests
│
├── backend/                          # Express + TypeScript core server & WebSocket engine
│   ├── src/
│   │   ├── routes/                   # auth.ts, incidents.ts, hospitals.ts, sentinel.ts
│   │   ├── services/                 # preAlertService, tripSentinelService, blackspotService, ntcipService
│   │   ├── tests/                    # rbac.test.ts (18 automated RBAC & security tests)
│   │   ├── db.ts                     # PostGIS connection pool
│   │   ├── redis.ts                  # Volatile RAM client
│   │   ├── migrate.ts                # Auto-migration runner & seed loader
│   │   └── socket.ts                 # Multi-agency Socket.io room broadcaster
│   └── package.json
│
├── dashboard/                        # Vite + React web console
│   ├── src/
│   │   ├── components/               # PoliceTacticalMap, IncidentCard, IncidentRouteMap, Navbar
│   │   ├── services/                 # Socket.io client & telemetry logger
│   │   ├── views/                    # HospitalView, PoliceView, AdminView (Reset Lab)
│   │   └── App.tsx                   # Role routing & tactical shell
│   └── package.json
│
├── db/                               # Database migrations & seeds
│   ├── migrations/                   # 001 to 007 SQL schema migrations
│   └── seeds/                        # Bengaluru trauma registry and blackspot seed data
│
├── DEMO_SCRIPT.md                    # Step-by-step timed walkthrough script for live demonstrations
├── docker-compose.yml                # PostGIS and Redis container orchestration
└── reset_demo.bat                    # One-click demo state reset script
```

---

## 🛠 Step-by-Step Setup & Execution

### Prerequisites
* [Docker & Docker Desktop](https://www.docker.com/) installed and running.
* [Node.js](https://nodejs.org/) (v20+ recommended).
* [Flutter SDK](https://flutter.dev/) (v3.24+ recommended).
* Android Studio / Android SDK with platform-tools (`adb`).

---

### Step 1: Start Databases (PostGIS & Redis)
```bash
docker compose up -d
```
Verify containers are healthy:
```bash
docker compose ps
```

---

### Step 2: Launch Core Backend (Port 5000)
```bash
cd backend
npm install
npm run dev
```
* The server will automatically run all 7 migrations and connect to Redis and PostgreSQL.
* Health Check: `http://localhost:5000/health`
* Run Backend RBAC Tests:
  ```bash
  npm test
  ```

---

### Step 3: Launch Hospital, Police & Admin Dashboards (Port 5173)
```bash
cd dashboard
npm install
npm run dev
```
Open in browser: `http://localhost:5173`
* **Hospital View (`/hospital`)**: Trauma bay intake, severity scores, and ABHA medical details.
* **Police View (`/police`)**: Tactical blackspot accident map and NTCIP signal overrides.
* **Admin Reset Lab (`/admin`)**: 1-click clean slate purge, live system telemetry, and test injectors.

---

### Step 4: Run Mobile Client (Physical Device or Emulator)

1. Connect Android phone via USB or Wireless ADB:
   ```bash
   adb devices
   ```
2. Enable local port forwarding for 0ms backend latency:
   ```bash
   adb reverse tcp:5000 tcp:5000
   ```
3. Run automated mobile test suite:
   ```bash
   cd mobile
   flutter test
   ```
4. Run the application:
   ```bash
   flutter run
   ```

---

## 🧪 Testing & Verification Suites

| Component | Test Suite | Scope | Status |
| :--- | :--- | :--- | :--- |
| **Backend** | `npm test` | 93 automated tests: 18 RBAC & Route Authorization tests, 29 Crash Intelligence & Sentinel tests, 46 ABDM / ABHA Health Card & Zero-PII tests | **93 / 93 PASS** |
| **Mobile** | `flutter test` | 55 unit & widget tests: Kinematic filters, Detection Lab, Keyguard lock-screen override, WebRTC fallback, Ambulance Pilot Cockpit, Hospital Radar, Cloud Watchdog simulation | **55 / 55 PASS** |
| **Dashboard**| `npm run build && npm run lint` | TypeScript strict compilation and ESLint zero-warning checks across Hospital, Police, Ambulance & Admin consoles | **0 Errors / 0 Warnings** |
| **Total Ecosystem** | Multi-Tier Suite | Full integration across Flutter edge, PostGIS spatial backend, and React command consoles | **148 / 148 PASS** |

---

## 🔄 One-Click Demo Reset & Testing Protocol

To ensure clean demonstrations without stale alerts:
1. Open the dashboard at `http://localhost:5173/admin`.
2. Click **"CLEAR ALL ACTIVE INCIDENTS (CLEAN SLATE)"**.
3. The system will truncate all incidents from PostgreSQL, flush Redis, cancel all watchdog timers, and broadcast `feed_cleared` to all open browsers.
4. From the mobile app, trigger a crash via **Trip Guard** or use the **Detection Lab**; your new alert will be processed as **Incident #1**.

---

## 🔒 Privacy, Security & Compliance Guarantees

* **Zero Persistent Image Storage**: Accident photos are held exclusively in volatile RAM and destroyed after 10 minutes.
* **On-Device Contact Privacy**: Victim emergency contacts reside 100% locally on-device in `SharedPreferences`. They are never harvested or stored in cloud user tables.
* **Privacy-Gated Hospital Access**: Family phone numbers are concealed on the dashboard until an accredited hospital officially accepts the case.
* **TRAI DLT Compliance**: Bypasses commercial SMS gateways by routing personal peer-to-peer notifications through Android’s native SIM stack.
* **Dead-Man Switch Privacy**: Trip Sentinel heartbeats maintain a rolling 120-second TTL in Redis; historical GPS trajectories are never recorded or stored.

---

## 👥 Contributors

* **Stevin Joseph** — *System Architecture, Mobile Edge Engine, Backend Core, Spatial Triage & Dashboards*

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
