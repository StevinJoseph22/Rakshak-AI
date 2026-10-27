# Rakshak-AI Hardware Devices Structure & IoT Architecture

> **Comprehensive Technical Specification for In-Vehicle On-Board Units (OBU), Roadside Units (RSU), Traffic Signal Controllers (ATC), and Edge Smartphone Telematics.**

---

## 📐 1. Master Hardware Topology Diagram

The diagram below illustrates the end-to-end hardware interaction between the victim's edge device, the emergency response vehicle (Ambulance OBU), municipal traffic infrastructure (RSU & ATC cabinets), and multi-agency command centers.

```text
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                       1. IN-VEHICLE / VICTIM EDGE LAYER                     │
 ├────────────────────────────────────────┬────────────────────────────────────┤
 │  A. Smartphone Telematics & Sensors    │  B. In-Vehicle Telematics (OBU)    │
 │  • Tri-axial MEMS Accelerometer (50Hz) │  • OBD-II / CAN-Bus (ISO 15765-4)  │
 │  • Tri-axial MEMS Gyroscope (rad/s)    │  • Airbag ECU Deployment Trigger   │
 │  • MEMS Barometer (Airbag ΔP pulse)    │  • Vehicle Speed Sensor (VSS)      │
 │  • Multi-GNSS (GPS / NavIC / Galileo)  │  • Siren & Strobe Arming Sense     │
 │  • Cellular Telephony Modem (Native SMS)     │  • 12V/24V Automotive Power Supply │
 └───────────────────┬────────────────────┴──────────────────┬─────────────────┘
                     │                                       │
     Sub-Second      │ C-V2X PC5 Sidelink (5.9 GHz)          │ BLE Beacon (UUID: 0xFD6F)
     TLS 1.3 / 4G-5G │ Direct V2V & V2I Distress             │ or USB-OTG Serial
                     ▼                                       ▼
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                   2. AMBULANCE EMERGENCY VEHICLE UNIT (OBU)                 │
 ├─────────────────────────────────────────────────────────────────────────────┤
 │  • Hardware Transceiver: Qualcomm 9150 / Quectel AG15 C-V2X Module         │
 │  • Frequency Band: 5.855 GHz – 5.925 GHz (5.9 GHz ITS Band)                │
 │  • Supported Protocols: SAE J2735 (BSM, SRM), 3GPP Rel-16 PC5 Direct        │
 │  • Paramedic Navigation HUD: High-Brightness Rugged Android Tablet         │
 │  • Hardware Interface Modes: USB-OTG (/dev/ttyUSB0), BLE 5.2, or Sidelink   │
 └───────────────────┬───────────────────────────────────────┬─────────────────┘
                     │                                       │
     SAE J2735 SRM   │ (Signal Request Message)              │ Cellular Backhaul
     Range: 300m-500m│ Latency: < 20ms                       │ 4G LTE / 5G SA
                     ▼                                       ▼
 ┌────────────────────────────────────────┐ ┌──────────────────────────────────┐
 │    3. MUNICIPAL ROADSIDE UNIT (RSU)    │ │   4. CENTRAL CLOUD & DISPATCH    │
 ├────────────────────────────────────────┤ ├──────────────────────────────────┤
 │  • Pole-Mounted C-V2X Transceiver RSU  │ │  • PostGIS Geospatial Engine     │
 │  • Dual Antennas (5.9 GHz Omni/Sector) │ │  • Volatile Redis 7 RAM Broker   │
 │  • Hardware Crypto Acceleration (HSM)  │ │  • NTCIP-1202 SNMP Preemption Hub│
 │  • Physical Interface: Rugged Ethernet │ │  • Hospital Trauma Web Console   │
 └───────────────────┬────────────────────┘ │  • Police City-Wide Command Map │
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

---

## 🚗 2. In-Vehicle On-Board Unit (OBU) Architecture

The Ambulance On-Board Unit connects the vehicle’s physical state with the smart city infrastructure. It runs the **Vehicle OBU Service** (`mobile/lib/services/vehicle_obu_service.dart`) under a unified Hardware Abstraction Layer (HAL).

### Supported Hardware Connection Modes

| Mode | Driver / Device Name | Physical Transport | Protocol / Interface | Use Case |
| :--- | :--- | :--- | :--- | :--- |
| **`simulatedSoftware`** | *Virtual C-V2X OBU Transceiver* | Virtual loopback | Software EVP engine | Hackathon demos, unit testing & emulator runtimes. |
| **`serialUsbOtG`** | *Commsignia / Quectel AG15 Modem* | USB-OTG / RS-232 | `/dev/ttyUSB0` serial baud 115200 | Hardwired dashboard mount to commercial automotive C-V2X modem. |
| **`bluetoothBle`** | *Rakshak BLE Emergency Dash Beacon* | BLE 5.2 | Service UUID `0xFD6F`, characteristic notification | Plug-and-play 12V cigarette lighter wireless beacon. |
| **`directCv2xPc5`** | *Qualcomm 9150 C-V2X Transceiver* | 5.9 GHz RF direct | 3GPP Rel-14/15/16 PC5 Mode 4 direct sidelink | Infrastructure-less direct radio link operating off-grid. |

### In-Vehicle Siren & Beacon Arming Sensor
* **Hardware Trigger**: Senses 12V trigger line from the ambulance emergency siren/strobe bar relay.
* **Armed State (`sirenActive == true`)**: Automated C-V2X preemption requests are transmitted dynamically whenever an active trauma run is claimed.
* **Standby State (`sirenActive == false`)**: Disarms signal preemption requests during non-emergency vehicle transfers to prevent unneeded traffic disruption.

---

## 🚦 3. Roadside Units (RSU) & Traffic Signal Controller (ATC) Architecture

Rakshak-AI interfaces with real-world municipal intelligent transportation systems (ITMS) following international standards:

### Standardized Protocols & Message Sets

#### 1. SAE J2735 Message Formats
* **Basic Safety Message (BSM - `0x01`)**: Broadcast at 10Hz by emergency vehicles:
  ```json
  {
    "msg_type": "BSM_SAE_J2735",
    "vehicle_id": "AMB-BLR-01",
    "plate_number": "KA-01-EA-1080",
    "latitude": 12.9172,
    "longitude": 77.6228,
    "speed_kmh": 68.4,
    "heading": 87.2,
    "elevation_m": 920.0,
    "siren_active": true,
    "lights_active": true,
    "timestamp": "2026-10-13T14:10:00.000Z"
  }
  ```
* **Signal Request Message (SRM - `0x0E`)**: Emitted 300m–500m ahead of an upcoming signalized intersection to demand priority passage:
  ```json
  {
    "msg_type": "SRM_SAE_J2735",
    "request_id": "REQ-8947211",
    "vehicle_id": "AMB-BLR-01",
    "intersection_id": "INT-BLR-004",
    "junction_name": "Silk Board Junction Flyover",
    "priority": "criticalTraumaLevel1",
    "eta_seconds": 18,
    "distance_m": 285.0,
    "inbound_approach": "Eastbound Artery Phase 2",
    "requested_at": "2026-10-13T14:10:05.000Z"
  }
  ```
* **Signal Status Message (SSM - `0x0F`)**: Transmitted back by the RSU confirming preemption lock:
  ```json
  {
    "msg_type": "SSM_SAE_J2735",
    "intersection_id": "INT-BLR-004",
    "junction_name": "Silk Board Junction Flyover",
    "request_id": "REQ-8947211",
    "state": "preemptedGreen",
    "green_hold_s": 28,
    "queue_clearance": true,
    "controller_model": "ATC-NEMA-TS2 / ITMS",
    "confirmed_at": "2026-10-13T14:10:05.320Z"
  }
  ```

#### 2. NTCIP 1202 v03 Standard Implementation
* Implemented via `backend/src/services/ntcipService.ts` (`NtcipTrafficControllerService`).
* Communicates directly with Advanced Traffic Controller (ATC) cabinets using standard SNMP v2c/v3 Management Information Base (MIB) Object Identifiers:

| Object Identifier (OID) | MIB Variable | Action / Payload |
| :--- | :--- | :--- |
| `1.3.6.1.4.1.1206.4.2.1.1.1` | `ascPreemptControl` | `SNMP_SET ... = 1` (Forces emergency green phase on requested approach) |
| `1.3.6.1.4.1.1206.4.2.1.1.2` | `ascPreemptState` | Reads active preemption state (`normal`, `clearing`, `preempted`) |
| `1.3.6.1.4.1.1206.4.2.1.1.3` | `ascPreemptRemainingTime` | Reads remaining green-hold duration in seconds |

#### 3. Signal Preemption State Machine Lifecycle
```text
  [Normal ITMS Cycle]
          │
          │ SRM Received (Ambulance within 300m)
          ▼
  [Yellow Clearance] (3–4s: Halts approaching cross traffic)
          │
          ▼
  [All-Red Safety Buffer] (1–2s: Flushes vehicles trapped in intersection)
          │
          ▼
  [Preempted Green Wave] (Locked green hold along ambulance vector)
          │
          │ Ambulance departs intersection / releasePreemption()
          ▼
  [Departed Handback] (Smoothly transitions intersection back to city timing plan)
```

---

## 📱 4. Edge Smartphone Telematics & Sensor Ingestion

The mobile client (`/mobile`) turns standard commodity smartphones into high-precision edge crash telemetry units.

### Physical Sensor Pipeline & Specifications

| Sensor Component | Physical Principle | Sampling Rate | Processing Engine | Safety Rules & Limits |
| :--- | :--- | :--- | :--- | :--- |
| **Linear MEMS Accelerometer** | Capacitive micro-cantilever displacement | $50\text{ Hz}$ | `crash_detector_service.dart` | Saturation safeguard: readings $\ge 8g\text{--}16g$ (physical sensor limit) are marked `"saturated"`. |
| **MEMS Gyroscope** | Coriolis acceleration on vibrating rings | $50\text{ Hz}$ | `detection_lab_engine.dart` | Rotational velocity integrated to estimate vehicle rollover ($>120^\circ$ gravity vector inversion). |
| **Free-Fall Invalidator** | Near-zero gravity detection | $50\text{ Hz}$ | `crash_confidence_config.dart` | If $|g| < 0.2\text{g}$ for $>100\text{ms}$ immediately prior to impact, flags dropped phone and suppresses alert. |
| **MEMS Barometer** | Piezoresistive diaphragm pressure | $10\text{ Hz}$ | `crash_confidence_config.dart` | Captures in-cabin pressure transient spikes ($\Delta P \ge 12\text{ hPa}$) caused by vehicle airbag deployments. |
| **Multi-GNSS Receiver** | L1/L5 dual-band GPS, GLONASS, NavIC | $1\text{ Hz} - 5\text{ Hz}$ | `geolocator` | Deceleration correlation: requires vehicle speed drop toward $0\text{ km/h}$ upon impact. |
| **Cellular Telephony Modem (SMS)** | Qualcomm Snapdragon / MediaTek RF Transceiver | Android SmsManager | `emergency_sms_service.dart` | Direct native P2P SMS using Android `SmsManager` over physical SIM; bypasses cloud gateways. |
| **Haptic Feedback Motor** | Linear Resonant Actuator (LRA) | Real-time | `locked_screen_alert_screen.dart` | Graduated high-intensity haptic pulse patterns during responsiveness checks. |

---

## 🛰 5. Zero-Network & Broken-Device Resilience Hardware Matrix

| Failure Scenario | Physical Hardware State | Rakshak-AI Fallback Mechanism |
| :--- | :--- | :--- |
| **Zero Cellular Data (No 4G/5G)** | SIM registered to GSM voice/SMS tower only | Transmits **Native SIM P2P Emergency SMS** containing Google Maps coordinates and ABHA medical ID directly to family. Caches incident in local SQLite queue with exponential retry. |
| **Total Cellular Tower Outage** | SIM has zero signal / No service | Broadcasts **C-V2X PC5 Direct Sidelink (5.9 GHz)** and **BLE 5.2 Emergency Distress Beacons** to passing vehicles and roadside units via Delay-Tolerant Mesh. |
| **Phone Destroyed Upon Impact** | Smartphone crushed or powered off instantly | **Sub-Second Pre-Alert Microburst** already reached police control room. **Trip Sentinel 30s Watchdog** detects sudden silence without cancel and automatically escalates to full active emergency. |
| **Phone Screen Locked by Biometrics** | Screen locked with PIN / Fingerprint | Android `USE_FULL_SCREEN_INTENT` + `showWhenLocked` wakes the display over keyguard, giving bystanders 1-tap access to call help and snap scene photos. |
| **Camera Privacy Constraints** | Zero disk storage permissible | Photos stream directly from camera CMOS sensor into volatile RAM buffer, transmitted to Redis with 10-minute TTL and wiped upon case resolution. |

---

## 🔌 6. Physical Wiring & Pinout Guide for Field Deployments

### Ambulance In-Vehicle OBU Serial Port Interface (USB-OTG / DB9 RS-232)
```text
  Pin 1: DCD (Data Carrier Detect)
  Pin 2: RXD (Receive Data <- C-V2X Transceiver)
  Pin 3: TXD (Transmit Data -> C-V2X Transceiver)
  Pin 4: DTR (Data Terminal Ready)
  Pin 5: GND (Chassis Ground)
  Pin 6: DSR (Data Set Ready)
  Pin 7: RTS (Request to Send)
  Pin 8: CTS (Clear to Send)
  Pin 9: RI  (12V Siren Trigger Sense Line)
```

### Roadside Unit (RSU) to Traffic Cabinet Ethernet Connection
```text
  RSU Pole Transceiver (5.9 GHz)
         │  Cat-6A Industrial Shielded Twisted Pair (PoE+ 802.3at)
         ▼
  M12 Industrial Ethernet Switch
         │  Port 1: RSU Transceiver
         │  Port 2: ATC Cabinet Controller (Port 161 SNMP)
         │  Port 3: Municipal Fiber Backhaul / Cellular Gateway
         ▼
  ATC Controller (NEMA TS2 Type 1 / 2070-1C)
```

---

## 💰 7. Hardware Cost Estimates & Bill of Materials (BOM) (Indicative Estimates)

All hardware costs below are **indicative estimates** based on COTS hardware pricing, reference module vendor quotes, and preliminary laboratory prototyping.

### Key Assumptions:
1. **Procurement Scale**: Prices reflect commercial batch procurement (>1,000 units).
2. **Exclusions**: Estimates do not include local state GST (18%), customs/import levies, or installation field labor.
3. **Citizen Layer**: **₹0 incremental cost** (uses citizen's existing smartphone sensors and Android `SmsManager`).

| Subsystem | Hardware Component | Indicative Unit Cost (INR) | Primary Role | Assumptions & Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Ambulance OBU** | C-V2X Transceiver (Qualcomm 9150 / Quectel AG15) | ₹14,000 – ₹22,000 | 5.9 GHz PC5 direct V2I broadcast | External dual-polarization roof antenna |
| **Ambulance Cockpit** | Rugged Android EMS Navigation Display | ₹8,000 – ₹14,000 | Paramedic tactical dispatch display | 12V DC vehicle powered, 700-nit panel |
| **Ambulance Beacon Sensor** | 12V Siren & Strobe Sense Interface | ₹800 – ₹1,500 | Detects active siren state | Opto-isolated 12V-to-5V TTL trigger |
| **Total Ambulance Pack** | **Complete In-Vehicle EMS Telematics Pack** | **₹22,800 – ₹37,500** | **Per Ambulance Unit** | Excludes vehicle installation labor |
| **Traffic Signal RSU** | Pole-Mounted C-V2X Roadside Unit (RSU) | ₹45,000 – ₹75,000 | Receives J2735 SRM preemption requests | IP67 outdoor enclosure, dual omni antennas |
| **Traffic Controller Card**| NEMA TS2 / 2070 SNMP Preemption Card | ₹15,000 – ₹28,000 | Triggers NTCIP 1202 hold on controller | Interfaces to municipal ATC cabinet |
| **Total Intersection** | **Complete Green Corridor Junction Hub** | **₹60,000 – ₹1,03,000** | **Per Signalized Intersection** | Assumes existing municipal ATC controller |
