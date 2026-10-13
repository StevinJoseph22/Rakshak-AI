# Rakshak-AI System & Enterprise Architecture

> **Multi-Tier Autonomous Crash Intelligence, Real-Time Emergency Dispatch, PostGIS Spatial Triage & C-V2X Green Corridor Infrastructure**

```mermaid
graph TD
    subgraph Edge Layer [1. Victim & Bystander Edge Devices]
        Sensors[MEMS Accel / Gyro / Barometer / GNSS] --> ML[On-Device TFLite + Kinematic Filter]
        ML --> PreAlert[Sub-Second Pre-Alert Microburst]
        ML --> LockScreen[Keyguard Override Alert Screen]
        LockScreen --> SIM[Direct Baseband P2P SIM SMS]
        LockScreen --> EphemeralCam[Zero-Gallery RAM Photo Buffer]
        LockScreen --> OfflineQueue[Offline Store-and-Forward Queue]
    end

    subgraph Hardware & IoT [2. C-V2X & Municipal Traffic Infrastructure]
        OBU[Ambulance OBU: Quectel AG15 / Qualcomm 9150]
        RSU[Municipal Roadside Units: 5.9 GHz ITS Band]
        ATC[NEMA TS2 / Model 2070 Traffic Signal Controllers]
        OBU -->|SAE J2735 SRM| RSU
        RSU -->|NTCIP 1202 SNMP OIDs| ATC
    end

    subgraph Backend Core [3. Central Dispatch Engine - Node.js & TypeScript]
        API[Express REST API / Port 5000]
        SocketServer[Socket.io Real-Time Broker]
        PreAlertWatchdog[30s Silent Auto-Promotion Watchdog]
        TripSentinel[Trip Sentinel 3-Tier Dead-Man Switch]
        NtcipService[NTCIP-1202 EVP Traffic Signal Hub]
        BlackspotService[Accident Blackspot Clustering Engine]
        EscalationService[15-Second Multi-Hospital Cascader]
    end

    subgraph Data & Cache [4. Data & Volatile Caching Layer]
        PG[(PostgreSQL 15+ & PostGIS 3.4 / Port 5432)]
        Redis[(Redis 7 Volatile RAM / Port 6379)]
    end

    subgraph Mission Consoles [5. Multi-Agency Emergency Operations Center]
        HospitalConsole[Hospital Trauma Bay Intake - React 18 / Port 5173]
        PoliceConsole[Police Tactical Blackspot & Signal Map - React 18]
        AdminConsole[Admin Reset Lab & Telemetry Stream - React 18]
        AmbulanceHUD[Ambulance Navigation & Green Corridor HUD - Flutter]
    end

    %% Data Flows
    PreAlert -->|impact_suspected| SocketServer
    LockScreen -->|Encrypted TLS Payload| API
    EphemeralCam -->|WebSocket Binary Chunks| Redis
    OfflineQueue -->|Auto-Sync on Reconnect| API

    API --> PG
    API --> Redis
    SocketServer --> Redis

    API --> BlackspotService
    BlackspotService --> PG
    TripSentinel --> Redis
    NtcipService --> RSU

    SocketServer -->|Room: hospital_id| HospitalConsole
    SocketServer -->|Room: police| PoliceConsole
    SocketServer -->|Room: ambulance_id| AmbulanceHUD
    SocketServer -->|Room: all_incidents| AdminConsole

    OBU -->|GPS Beacons & EVP Preemption| API
```

---

## 🏛 Tier-by-Tier Architectural Breakdown

### 1. Mobile Edge & Sensor Fusion Layer (`/mobile`)
* **Hardware Sensing**: $50\text{ Hz}$ linear acceleration, angular rates, atmospheric barometric pressure transients, and high-precision GNSS positioning.
* **On-Device Inference**: TensorFlow Lite model (`crash_classifier.tflite`) paired with a rule-based kinematic fallback engine.
* **Pre-Alert Microburst**: Sub-second `impact_suspected` soft marker sent to police before the countdown completes.
* **Keyguard Bypass**: Android `USE_FULL_SCREEN_INTENT` + `showWhenLocked` waking the display over the PIN/biometric lock screen.
* **Zero-Gallery Camera**: Captures incident scenes directly into volatile memory buffers, bypassing persistent storage.
* **Native Baseband P2P SMS**: Direct SIM-to-SIM cellular dispatch over GSM/LTE radio, bypassing commercial cloud SMS gateways.
* **Offline Store-and-Forward**: RFC 4122 client UUID idempotency keys with exponential backoff synchronization.

### 2. Vehicle Telematics, C-V2X & Smart City IoT
* **Vehicle OBU Service**: Interfaces with in-vehicle telematics via USB-OTG serial, Bluetooth Low Energy (BLE 5.2), or native 3GPP Rel-16 C-V2X PC5 direct sidelink transceivers.
* **Emergency Vehicle Preemption (EVP)**: Broadcasts SAE J2735 Signal Request Messages (SRM) to municipal Roadside Units (RSU).
* **NTCIP 1202 Controller Interface**: Formats standard SNMP v2c/v3 OID commands (`1.3.6.1.4.1.1206.4.2.1.1.1` `ascPreemptControl`) to force green signal corridors for approaching ambulances.

### 3. Core Dispatch & Event Broker (`/backend`)
* **TypeScript & Node.js 20+ Runtime**: High-throughput asynchronous event processing.
* **Socket.io Multi-Agency Rooms**: Isolated namespaces and rooms (`hospital_{id}`, `police`, `ambulance_{id}`, `all_incidents`).
* **Silent Auto-Promotion Watchdog**: Promotes incidents to full emergency if the victim's phone loses power or breaks down upon impact.
* **Trip Sentinel Dead-Man Switch**: Monitors trip heartbeats with speed-before-silence sanity checks and short-TTL Redis storage.
* **Blackspot Cluster Engine**: PostGIS spatial queries identifying recurring accident blackspots in real time.
* **15-Second Multi-Hospital Escalation**: Cascades unaccepted emergency trauma cases across golden radius sectors.

### 4. Persistence & Volatile Storage Layer (`/db`)
* **PostgreSQL 15+ & PostGIS 3.4**: Spatial indexing (`geometry(Point, 4326)`, `ST_DWithin`, `ST_DistanceSphere`, GIST indexes) for hospital matching and accident clusters.
* **Volatile Redis 7**: Configured with zero disk persistence (`--save "" --appendonly no`) for volatile 10-minute image storage, ambulance beacons, and rate-limiting.

### 5. Multi-Agency Tactical Consoles (`/dashboard`)
* **Trauma Bay Intake Console (`/hospital`)**: Real-time crash cards, measured severity index, Ayushman Bharat (ABHA) medical profiles, and 1-click dispatch.
* **Police Command Map (`/police`)**: Tactical GIS map displaying active incidents, cruiser GPS locations, blackspot clusters, and manual traffic signal overrides.
* **Admin Reset Lab (`/admin`)**: System telemetry monitor, crash injectors, and 1-click clean slate purge engine.
