# Rakshak-AI: Codebase Architecture & Implementation Guide
> **Comprehensive technical deep-dive into the codebase, design patterns, folder structure, edge sensing algorithms, PostGIS spatial queries, and multi-agency coordination protocols of Rakshak-AI.**

---

## Table of Contents
1. [System Architectural Blueprint](#1-system-architectural-blueprint)
2. [End-to-End Emergency Lifecycle (State Machine)](#2-end-to-end-emergency-lifecycle-state-machine)
3. [Repository Directory & File Breakdown](#3-repository-directory--file-breakdown)
   - [3.1 Backend Core (`backend/src`)](#31-backend-core-backendsrc)
   - [3.2 Web Dashboards (`dashboard/src`)](#32-web-dashboards-dashboardsrc)
   - [3.3 Mobile Sensing & Pilot App (`mobile/lib`)](#33-mobile-sensing--pilot-app-mobilelib)
   - [3.4 Database Migrations & Seeds (`db/`)](#34-database-migrations--seeds-db)
4. [Edge Crash Detection & Kinematic Algorithms](#4-edge-crash-detection--kinematic-algorithms)
5. [Store-and-Forward Offline Queue (30-Minute Emergency TTL)](#5-store-and-forward-offline-queue-30-minute-emergency-ttl)
6. [PostGIS Spatial Triage & 45-Second Auto-Escalation Engine](#6-postgis-spatial-triage--45-second-auto-escalation-engine)
7. [Concurrency Control & PostgreSQL Row-Level Locking](#7-concurrency-control--postgresql-row-level-locking)
8. [Zero-PII Storage & Ephemeral Volatile RAM Architecture](#8-zero-pii-storage--ephemeral-volatile-ram-architecture)
9. [ABHA Integration & Clinician Break-Glass Protocol](#9-abha-integration--clinician-break-glass-protocol)
10. [C-V2X Autonomous Green Corridor & Traffic Preemption](#10-c-v2x-autonomous-green-corridor--traffic-preemption)
11. [Complete 25-Hospital Registry & RBAC Credentials](#11-complete-25-hospital-registry--rbac-credentials)
12. [API Reference & Real-Time Socket.io Contracts](#12-api-reference--real-time-socketio-contracts)
13. [Verification, Testing & Running the System](#13-verification-testing--running-the-system)

---

## 1. System Architectural Blueprint

Rakshak-AI is structured into three distributed operational tiers:
1. **Edge Sensing Tier (Flutter Mobile Engine)**: Runs continuous 50Hz IMU circular buffers, kinematic collision detection, sub-second pre-alert microbursts, locked-screen full-screen intents, native P2P SMS alerts, and WebRTC streaming.
2. **Central Spatial Coordination Tier (Node.js, PostGIS, Volatile Redis RAM)**: Evaluates high-speed PostGIS radius searches, dispatches real-time Socket.io frames, runs 45-second auto-escalation watchdogs, enforces single-hospital acceptance locks via PostgreSQL transactions, and maintains zero medical PII in disk databases.
3. **Multi-Agency Tactical Control Tier (React 18 + TypeScript Dashboards)**: Provides specialized views for Hospital Trauma Bays, Police Control Headquarters, Paramedic Ambulance Cockpits, and System Administration.

```mermaid
flowchart TD
    subgraph EdgeTier ["Edge Sensing Tier (Mobile App)"]
        Sensors["50Hz Accelerometer & Gyroscope"] --> RingBuffer["100-Sample Ring Buffer"]
        RingBuffer --> CrashDetector["Crash Detector Engine<br/>(Peak-G >= 6.5g + Speed Drop)"]
        CrashDetector --> PreAlert["Pre-Alert Microburst<br/>(impact_suspected)"]
        CrashDetector --> KeyguardOverride["Keyguard Locked Screen Override<br/>(10s Countdown)"]
        KeyguardOverride --> OfflineQueue["Store-and-Forward Queue<br/>(SQLite / 30m TTL)"]
        KeyguardOverride --> TelephonySMS["Native Dual-SIM GSM SMS<br/>(GPS + Live Link)"]
        KeyguardOverride --> WebRTC["WebRTC Photo Stream<br/>(Camera Capture)"]
    end

    subgraph BackendTier ["Central Coordination Tier (Node.js + PostGIS + Redis)"]
        PreAlert --> SocketServer["Socket.io Server<br/>(Room Routing)"]
        OfflineQueue --> RestAPI["Express API Server"]
        WebRTC --> SocketServer
        RestAPI --> PostGIS["PostgreSQL 15 + PostGIS<br/>(Spatial Geometries)"]
        RestAPI --> RedisRAM["Volatile Redis RAM<br/>(Ephemeral 2h TTL Cache)"]
        RestAPI --> EscalationService["45s Auto-Escalation Engine<br/>(8km -> 20km -> Registry)"]
    end

    subgraph AgencyTier ["Tactical Agency Dashboards (React + Vite)"]
        SocketServer --> HospitalConsole["Hospital Trauma Bay Console<br/>(One-Click Bed Reservation)"]
        SocketServer --> PoliceConsole["Police Tactical Command<br/>(Blackspots & Radar)"]
        SocketServer --> AmbulanceHUD["Ambulance Pilot Cockpit<br/>(C-V2X Green Corridor)"]
        HospitalConsole --> BreakGlass["ABHA Break-Glass Decryption<br/>(Audit Logged)"]
    end
```

---

## 2. End-to-End Emergency Lifecycle (State Machine)

Every vehicular accident progresses through an immutable state machine designed to eliminate human latency and prevent false alarms.

```mermaid
stateDiagram-v2
    [*] --> detected: High-G Collision Spike (>=6.5g)
    detected --> suspected: Sub-second Pre-Alert Microburst
    
    note right of suspected
        Police tactical room alerted on standby.
        10s mobile audible buzzer triggered.
        Victim given "I'm OK" option.
    end note

    suspected --> cancelled: User taps "I'm OK" within 10s
    suspected --> broadcasting: 10s expires OR Phone destroyed (30s watchdog)
    
    note right of broadcasting
        PostGIS 8km radius search queries trauma centers.
        Matched hospitals receive synchronized alert.
        45-second auto-escalation timer arms.
    end note

    broadcasting --> escalated: 45s expires without hospital acceptance
    escalated --> escalated: Search perimeter widens (8km -> 20km -> Registry)
    
    broadcasting --> accepted: Hospital clicks "Accept Emergency Case"
    escalated --> accepted: Hospital clicks "Accept Emergency Case"
    
    note right of accepted
        PostgreSQL row-level lock acquired (FOR UPDATE).
        Case locked across all other hospitals.
        Bed & trauma team reserved.
        ABHA emergency health card unlocked.
    end note

    accepted --> en_route: Paramedic Ambulance claims dispatch
    en_route --> arrived: Ambulance reaches crash site (GPS geofenced)
    arrived --> resolved: Victim delivered to hospital trauma bay
    resolved --> [*]
    cancelled --> [*]
```

---

## 3. Repository Directory & File Breakdown

### 3.1 Backend Core (`backend/src`)

```
backend/src/
├── server.ts                  # Application bootstrap, Express + HTTP + Socket.io server
├── socket.ts                  # Real-time WebSocket room routing and global event broadcasts
├── db.ts                      # PostgreSQL connection pool with parameterized query helpers
├── redis.ts                   # Volatile RAM cache client & ephemeral Health Card storage helpers
├── escalation.ts              # 45-second multi-stage auto-escalation radius widening engine
├── migrate.ts                 # Database migration & seed synchronization runner
├── validations.ts             # Zod input validation schemas for all REST API endpoints
├── types.ts                   # TypeScript interfaces (Incident, Hospital, HealthCard, etc.)
├── middleware/
│   └── auth.ts                # JWT authentication, role-based access control (RBAC), hospital scoping
├── routes/
│   ├── incidents.ts           # REST endpoints: /incidents, /suspected, /accept, /claim, /arrived
│   ├── hospitals.ts           # REST endpoints: /hospitals (lists all 25 facilities, spatial ?near)
│   ├── auth.ts                # REST endpoints: /auth/login, /auth/me (JWT issuance)
│   └── sentinel.ts            # REST endpoints: /sentinel (Highway dead-man journey monitoring)
├── services/
│   ├── preAlertService.ts     # 30-second silent auto-promotion watchdog for destroyed phones
│   ├── tripSentinelService.ts # High-speed highway collapse detection (>60 km/h)
│   ├── blackspotService.ts    # Spatial clustering of high-accident frequency road segments
│   ├── abdm.ts                # Ayushman Bharat Digital Mission (ABDM) mock FHIR gateway
│   ├── trafficPreemptionService.ts # NTCIP 1202 / ISO 19091 Green Corridor signal simulation
│   └── osrmService.ts         # Open Source Routing Machine (OSRM) driving route & distance service
├── scripts/
│   └── reset_demo.ts          # Demo state cleaner (purges test records, resets Redis RAM)
└── tests/
    ├── rbac.test.ts           # 18 test cases verifying RBAC tokens and authorization boundaries
    ├── phase17_intelligence.test.ts # 29 test cases verifying pre-alert, idempotency & sentinel
    ├── phase18_health_card.test.ts  # 46 test cases verifying ephemeral ABHA storage & zero-PII
    └── e2e_case_verification.test.ts # Full end-to-end incident lifecycle test suite
```

### 3.2 Web Dashboards (`dashboard/src`)

```
dashboard/src/
├── main.tsx                   # React DOM root entrypoint
├── App.tsx                    # Multi-agency role selector & navigation wrapper
├── types/
│   └── index.ts               # Shared TypeScript models (IncidentPayload, Hospital, etc.)
├── config/
│   ├── hospitals.ts           # Seeded list of 25 Bengaluru hospitals with coordinates
│   └── mapConfig.ts           # OpenStreetMap tile server URLs and fallback layers
├── services/
│   ├── socket.ts              # Socket.io client singleton with auto-reconnection
│   ├── auth.ts                # Local session persistence & authenticated fetch helper
│   └── webrtc.ts              # WebRTC peer connection signaling receiver for photo stream
├── views/
│   ├── HospitalView.tsx       # Hospital Emergency Room console with bed reservation
│   ├── PoliceView.tsx         # Police Control Room radar, blackspot monitoring & signal state
│   ├── AmbulanceView.tsx      # Paramedic cockpit with turn-by-turn navigation & telemetry
│   └── AdminView.tsx          # System diagnostics deck, live event drawer & demo reset
└── components/
    ├── IncidentCard.tsx       # Multi-agency incident presentation card with backside deck
    ├── IncidentRouteMap.tsx   # Leaflet map showing ambulance OSRM route & green corridors
    ├── PoliceTacticalMap.tsx  # City-wide tactical overview showing blackspots & ambulances
    ├── BreakGlassModal.tsx    # ABDM emergency break-glass authorization & justification modal
    ├── LoginView.tsx          # Unified RBAC login form for Hospital, Police, and Ambulance
    ├── DemoModeLiveDrawer.tsx # Slide-out diagnostic log showing real-time socket events
    └── ReconnectingBanner.tsx # Visual network connection degradation indicator
```

### 3.3 Mobile Sensing & Pilot App (`mobile/lib`)

```
mobile/lib/
├── main.dart                  # Main citizen smartphone entrypoint
├── ambulance_pilot_app.dart   # Dedicated EMS ambulance cockpit entrypoint
├── models/
│   ├── crash_event.dart       # Kinematic telemetry payload model
│   ├── emergency_health_card.dart # ABDM emergency profile and provenance fields
│   └── incident_model.dart    # SQLite offline dispatch record model
├── screens/
│   ├── crash_detection_screen.dart # Sensor monitoring HUD and manual test trigger
│   ├── locked_screen_alert_screen.dart # Keyguard-bypassing 10-second emergency countdown
│   ├── ambulance_dispatch_screen.dart  # Paramedic incident view with road distance
│   ├── ambulance_pilot_home_screen.dart # Ambulance status, GPS beaconing & active missions
│   ├── abha_onboarding_screen.dart # Citizen ABHA ID linking & local AES-256 vault setup
│   ├── emergency_contacts_screen.dart  # Management of native SIM SMS emergency contacts
│   └── test_lab_screen.dart   # Developer simulation bench for impact spikes and drops
└── services/
    ├── crash_detector_service.dart # 50Hz IMU circular buffer, peak-G & speed drop filter
    ├── pre_alert_service.dart # Keyguard override, buzzer, and sub-second pre-alert ping
    ├── offline_dispatch_queue.dart # Delay-tolerant SQLite queue with 30m emergency TTL
    ├── photo_stream_service.dart # 3-tier photo upload: WebRTC -> WebSocket -> HTTP
    ├── vehicle_obu_service.dart # C-V2X PC5 direct sidelink OBU broadcast simulator
    ├── emergency_sms_service.dart # Native telephony SMS dispatcher
    ├── emergency_contact_service.dart # SharedPreferences contact persistence
    ├── location_service.dart  # High-frequency GPS position and speed tracker
    └── trip_sentinel_client.dart # Highway journey dead-man telemetry worker
```

### 3.4 Database Migrations & Seeds (`db/`)

```
db/
├── init/
│   ├── 01-init.sh             # Docker PostgreSQL PostGIS extension enabler
│   └── 02-schema-and-seeds.sql # Monolithic baseline backup schema
├── migrations/
│   ├── 001_create_schema.sql  # Initial PostGIS schema (hospitals, incidents)
│   ├── 002_create_incident_rejections.sql # Hospital rejection audit table
│   ├── 003_add_unmatched_status.sql # Support for out-of-network escalation state
│   ├── 004_add_ambulance_id.sql # Links paramedic vehicles to incident rows
│   ├── 005_create_users_and_auth.sql # RBAC users table with 25 hospital logins
│   ├── 006_add_ambulance_arrival_metadata.sql # Paramedic scene arrival telemetry
│   ├── 007_add_suspected_and_cancelled_status.sql # Pre-alert state machine columns
│   └── 008_create_health_card_access_audit.sql # Immutable break-glass audit logs
└── seeds/
    └── 001_hospitals_bengaluru.sql # 25 verified hospitals with PostGIS Point geometries
```

---

## 4. Edge Crash Detection & Kinematic Algorithms

The edge detection logic in [`crash_detector_service.dart`](file:///e:/Projects%20and%20Case%20Study/Rakshak-AI/mobile/lib/services/crash_detector_service.dart) executes over high-frequency accelerometer and gyroscope telemetry ($50\text{ Hz}$).

### 4.1 Kinematic Trigger Criteria
To prevent false triggers from dropped phones, potholes, or sharp braking, a crash is confirmed only when multiple physical indicators correlate:

$$\text{Impact Trigger} \iff (G_{\text{peak}} \ge 6.5g) \land (\Delta V \ge 35\text{ km/h}) \land (V_{\text{post}} \le 5\text{ km/h}) \land (\neg \text{FreeFall})$$

1. **Peak Deceleration Magnitude ($G_{\text{peak}}$)**:
   $$\|a(t)\| = \frac{\sqrt{a_x^2(t) + a_y^2(t) + a_z^2(t)}}{9.80665}$$
   * Threshold: $\|a(t)\| \ge 6.5g$. Sensor hardware saturation is flagged if $\|a(t)\| \ge 16.0g$.
2. **Delta-V Speed Drop ($\Delta V$)**:
   $$\Delta V = V_{\text{pre}} - V_{\text{post}}$$
   * Measured over a 500ms sliding window before and after the acceleration spike.
   * Speed drop must exceed $35\text{ km/h}$, with vehicle stopping ($V_{\text{post}} \approx 0\text{ km/h}$).
3. **Free-Fall Drop Rejection Filter**:
   * If a smartphone is dropped onto pavement, it experiences near zero-G immediately prior to impact ($a_{\text{norm}} < 0.25g$ for $>80\text{ms}$).
   * If zero-G is detected preceding the impact spike, the event is classified as an **accidental phone drop** and rejected.
4. **Angular Tumble / Rollover Check**:
   $$\|\omega(t)\| = \sqrt{\omega_x^2(t) + \omega_y^2(t) + \omega_z^2(t)} \ge 300^\circ/\text{s}$$
   * Confirms high-rate rotational tumbling characteristic of motorcycle or vehicular rollovers.
5. **Barometric Airbag Pressure Pulse (Enclosed Vehicles)**:
   * Senses rapid cabin pressure jumps ($\Delta P \ge 1.5\text{ hPa}$ within $30\text{ms}$) caused by pyrotechnic airbag deployment. Automatically bypassed for two-wheelers.

### 4.2 Composite Confidence Score (0–100)
Every crash event is scored algorithmically:
* **Delta-V Magnitude**: Up to 30 points
* **Peak G-Force**: Up to 25 points
* **Post-Impact Stillness**: 20 points
* **Post-Impact Near-Zero Speed**: 15 points
* **Rollover Angular Rotation**: 10 points
* **Confidence Level**: Scores $\ge 75$ are categorized as `Critical Trauma`; scores between $50-74$ as `Moderate Trauma`.

---

## 5. Store-and-Forward Offline Queue (30-Minute Emergency TTL)

In rural blind spots, tunnels, or highway cellular dead-zones, network requests fail. The [`OfflineDispatchQueue`](file:///e:/Projects%20and%20Case%20Study/Rakshak-AI/mobile/lib/services/offline_dispatch_queue.dart) implements delay-tolerant networking:

1. **RFC 4122 Idempotent Client UUID**:
   * The client generates a unique UUID `id` on the device at impact time.
   * If the payload is resent multiple times, the backend database treats it idempotently without generating duplicate incidents.
2. **Fast Backoff Retry Watchdog**:
   * If transmission fails, retries occur with fast backoff capped at 6s ($2\text{s}, 4\text{s}, 6\text{s}$).
3. **Strict 30-Minute Validity TTL**:
   * An emergency accident payload is clinically actionable only during the Golden Hour.
   * If an offline queue item remains un-sent for $> 30\text{ minutes}$ ($1,800\text{ seconds}$), it is automatically purged from disk storage upon loading and discarded:
   ```dart
   if (delaySeconds > maxTtlSeconds) {
     debugPrint('[OfflineDispatchQueue] Dropped expired queued incident ${item.id}');
     _queue.removeWhere((i) => i.id == item.id);
     await _saveToDisk();
     continue;
   }
   ```
4. **Backend Stale Payload Guard**:
   * In [`backend/src/routes/incidents.ts`](file:///e:/Projects%20and%20Case%20Study/Rakshak-AI/backend/src/routes/incidents.ts), any incoming store-and-forward payload with `delivery_delay_seconds > 1800` is rejected with `400 EXPIRED_STORE_AND_FORWARD`, preventing historical test records from resurfacing as live emergencies.

---

## 6. PostGIS Spatial Triage & 45-Second Auto-Escalation Engine

When an emergency incident reaches `broadcasting` status, Rakshak-AI queries trauma facilities using native PostGIS spherical spatial mathematics.

### 6.1 Initial 8km Radius Spatial Query
```sql
SELECT 
  id, name, phone, address, has_trauma_center, has_icu_capacity, is_verified,
  ST_Y(location::geometry) AS latitude,
  ST_X(location::geometry) AS longitude,
  ROUND((ST_Distance(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography) / 1000)::numeric, 2) AS distance_km
FROM hospitals
WHERE has_trauma_center = true
  AND ST_DWithin(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, 8000)
ORDER BY distance_km ASC;
```
* `$1` is longitude, `$2` is latitude.
* `ST_DWithin` operates on spheroidal geography types (WGS 84 / SRID 4326) within an 8,000-meter ($8\text{km}$) buffer.
* Road distance is calculated via OSRM or circuity estimation ($d_{\text{road}} \approx d_{\text{aerial}} \times 1.6$).

### 6.2 45-Second Auto-Escalation Protocol
If no hospital clicks **"Accept Emergency Case"** within 45 seconds ($45,000\text{ms}$):
1. **Stage 1 Escalation ($20\text{km}$ Perimeter)**:
   * The backend escalation timer in [`escalation.ts`](file:///e:/Projects%20and%20Case%20Study/Rakshak-AI/backend/src/escalation.ts) fires.
   * PostGIS widens the query radius to $20,000\text{ meters}$ ($20\text{km}$), excluding any hospitals that explicitly declined.
   * PostgreSQL updates `status = 'escalated'` and sets `victim_metadata.search_radius = '20km'`.
   * Newly reached trauma centers receive `new_incident` room broadcasts with cached scene photos.
   * All connected clients receive an `incident_escalated` event containing both `newly_matched_hospitals` and `all_matched_hospitals`.
   * On the dashboard, the card updates to:
     `⚡ 20km Escalated Network (N)`
     `⚡ 45s AUTO-ESCALATED: 20KM PERIMETER`
2. **Stage 2 Escalation (State/City Registry)**:
   * If after an additional 45 seconds the case is still unclaimed, the engine widens search registry-wide to all tertiary apex medical centers.
3. **Incident Unmatched**:
   * If every hospital in the state network is exhausted or declines, the incident transitions to `unmatched` and alerts state disaster management authorities.

---

## 7. Concurrency Control & PostgreSQL Row-Level Locking

In an emergency network broadcasting to 10+ hospitals simultaneously, two trauma facilities might click **"Accept Emergency Case"** at the exact same millisecond. 

To eliminate race conditions, [`backend/src/routes/incidents.ts`](file:///e:/Projects%20and%20Case%20Study/Rakshak-AI/backend/src/routes/incidents.ts) utilizes explicit PostgreSQL row-level locks within a transaction:

```sql
BEGIN;

-- Lock the incident row against all concurrent transactions
SELECT id, status, accepted_hospital_id 
FROM incidents 
WHERE id = $1 
FOR UPDATE;

-- Check if another facility acquired the case in the interim
-- If already accepted:
-- ROLLBACK and return HTTP 409 Conflict with the winning hospital's name.

-- If unclaimed:
UPDATE incidents 
SET status = 'accepted', accepted_hospital_id = $2, updated_at = CURRENT_TIMESTAMP 
WHERE id = $1;

COMMIT;
```

* **Winner**: Receives `HTTP 200 OK`, acquires exclusive clinical custody of the case, and disarms the auto-escalation timer across the entire network.
* **Other Facilities**: Receive `HTTP 409 Conflict: Case already accepted by <Hospital Name>`. Their consoles instantly display a locked badge (`LOCKED • St. John's Medical College Hospital`) with action buttons disabled.

---

## 8. Zero-PII Storage & Ephemeral Volatile RAM Architecture

Medical data compliance (under ABDM, HIPAA, and DPDP regulations) strictly prohibits storing unencrypted victim health records on disk databases.

Rakshak-AI implements an **Ephemeral Volatile RAM Storage Pipeline**:

```
[ Victim Smartphone / ABDM Gateway ]
                │
                │ Encrypted Dispatch Payload
                ▼
      [ Sanitizer Service ]
     (sanitizeVictimMetadata)
        │                   │
        │ Clean Kinematics   │ Raw ABHA Records & Blood Group
        ▼                   ▼
┌──────────────────┐   ┌─────────────────────────────────────┐
│  PostgreSQL 15   │   │         Volatile Redis RAM          │
│  (Disk Storage)  │   │        (In-Memory Key-Value)        │
│                  │   │                                     │
│  - Incident UUID │   │  KEY: "health_card:<UUID>"          │
│  - Coordinates   │   │  TTL: 7,200 Seconds (2 Hours Auto)  │
│  - Speed Drop    │   │  VALUE: Full Emergency Health Card  │
│  - Peak G        │   │                                     │
│  - NO BLOOD GRP  │   │  KEY: "incident_image:<UUID>"       │
│  - NO HEALTH REC │   │  TTL: 7,200 Seconds (2 Hours Auto)  │
└──────────────────┘   └─────────────────────────────────────┘
```

1. **PostgreSQL Sanitization Guard**:
   * Function `sanitizeVictimMetadata()` strips `health_card`, `blood_group`, `critical_allergies`, `chronic_conditions`, and `medications` before SQL persistence.
   * Postgres only stores a boolean indicator: `has_health_card: true`.
2. **Volatile Redis RAM with Auto-Eviction**:
   * Sensitive clinical profiles are stored strictly in Redis RAM with a **2-hour Time-to-Live (TTL = 7,200s)**.
   * If Redis is restarted or 2 hours elapse, the clinical data vaporizes completely, leaving zero residual PII on disk.

---

## 9. ABHA Integration & Clinician Break-Glass Protocol

Under the Ayushman Bharat Digital Mission (ABDM), citizens link their 14-digit ABHA ID (`name@abdm`) to personal health records. In a crash where the victim is unconscious, clinicians require instant access to blood type, cardiac stents, or penicillin allergies.

### 9.1 Access Guard
* **Before Acceptance**: All hospital and police dashboards display locked provenance indicators (`ABHA Health Record: Clinical access available after case acceptance`).
* **After Acceptance**: The designated hospital that reserved the trauma bay gains authorized access to the **"Access ABHA Health Record (Break-Glass)"** trigger.

### 9.2 Immutable Break-Glass Audit Trail
When clinician breaks glass, [`backend/src/routes/incidents.ts`](file:///e:/Projects%20and%20Case%20Study/Rakshak-AI/backend/src/routes/incidents.ts) requires a mandatory clinical justification (e.g. *"Unconscious blunt trauma victim requiring urgent laparotomy and cross-match blood transfusion"*).

An immutable regulatory audit record is written to the `health_card_access_audit` table:
```sql
INSERT INTO health_card_access_audit (
    incident_id, accessed_by_user_id, hospital_id, justification, ip_address, user_agent
) VALUES ($1, $2, $3, $4, $5, $6);
```

The decrypted health card is then served to the trauma bay with full field-level provenance:
* `ABDM_VERIFIED`: Verified directly from government hospital FHIR records (Green check).
* `SELF_ATTESTED`: Entered by user or family (Blue shield).
* `INFERRED_WEARABLE`: Recorded from smartwatch biometric sensors (Purple watch).

---

## 10. C-V2X Autonomous Green Corridor & Traffic Preemption

During ambulance transit, traffic signals along the route are preempted dynamically using the international **NTCIP 1202 / ISO 19091 standard** implemented in [`trafficPreemptionService.ts`](file:///e:/Projects%20and%20Case%20Study/Rakshak-AI/backend/src/services/trafficPreemptionService.ts):

1. **GPS Telemetry Geofencing**:
   * The ambulance broadcasts real-time GPS telemetry every 1 second (`ambulance_location_update`).
   * The backend maps the ambulance's velocity vector along its OSRM transit polyline.
2. **300-Meter Signal Ingress Trigger**:
   * When the ambulance reaches within $300\text{ meters}$ of a signaled intersection, a preempt signal command is triggered.
   * Opposing traffic phases receive a forced 4-second clearance yellow, followed by an all-red phase.
   * The ambulance's approach corridor transitions to continuous **GREEN** until 15 seconds after the ambulance clears the intersection box.
3. **Police Tactical Feedback**:
   * The Police Tactical Map renders live preempted signals with animated green pulsing ripples, giving traffic dispatchers full visibility into active green corridors.

---

## 11. Complete 25-Hospital Registry & RBAC Credentials

All 25 hospitals are seeded in the database with authentic coordinates, trauma capability flags, addresses, emergency phone lines, and RBAC user accounts:

| ID | Hospital Name | Coordinates (Lat, Lng) | Trauma | Username | Password |
|---|---|---|:---:|---|---|
| `11111111-...` | Manipal Hospital, Old Airport Road | `12.9592, 77.6499` | Yes | `manipal_hal` | `hospital123` |
| `22222222-...` | St. John's Medical College Hospital | `12.9343, 77.6190` | Yes | `st_johns` | `hospital123` |
| `33333333-...` | Apollo Hospitals, Bannerghatta Road | `12.8938, 77.5976` | Yes | `apollo_bg` | `hospital123` |
| `44444444-...` | Fortis Hospital, Cunningham Road | `12.9868, 77.5949` | Yes | `fortis_cunningham` | `hospital123` |
| `55555555-...` | Manipal Hospital, Whitefield | `12.9880, 77.7317` | Yes | `manipal_whitefield` | `hospital123` |
| `66666666-...` | Cloudnine Hospital, Jayanagar | `12.9298, 77.5834` | No | `cloudnine_jayanagar` | `hospital123` |
| `77777777-...` | Chinmaya Mission Hospital, Indiranagar | `12.9772, 77.6441` | No | `chinmaya_mission` | `hospital123` |
| `88888888-...` | Narayana Multispeciality Hospital, HSR | `12.9112, 77.6387` | Yes | `narayana_hsr` | `hospital123` |
| `99999999-...` | Sagar Hospitals, DSI Campus | `12.9080, 77.5601` | No | `sagar_dsi` | `hospital123` |
| `aaaaaaaa-...` | Aster CMI Hospital, Hebbal | `13.0560, 77.5925` | Yes | `aster_hebbal` | `hospital123` |
| `bbbbbbbb-...` | Columbia Asia Hospital, Hebbal | `13.0487, 77.5935` | Yes | `columbia_hebbal` | `hospital123` |
| `cccccccc-...` | Fortis Hospital, Nagarbhavi | `12.9851, 77.5126` | Yes | `fortis_nagarbhavi` | `hospital123` |
| `dddddddd-...` | BGS Gleneagles Global Hospital, Kengeri | `12.9113, 77.4830` | Yes | `bgs_kengeri` | `hospital123` |
| `eeeeeeee-...` | Manipal Hospital, Yeshwanthpur | `13.0272, 77.5500` | Yes | `manipal_yeshwanthpur` | `hospital123` |
| `ffffffff-...` | Sparsh Hospital, Yelahanka | `13.1020, 77.5960` | Yes | `sparsh_yelahanka` | `hospital123` |
| `a1b2c3d4-...` | Sakra World Hospital, Marathahalli | `12.9260, 77.6850` | Yes | `sakra_marathahalli` | `hospital123` |
| `b1000001-...` | **Cratis Hospital, Hennur / Kothanur** | `13.0583, 77.6480` | **Yes** | `cratis_kothanur` | `hospital123` |
| `b1000002-...` | Bangalore Baptist Hospital, Bellary Road | `13.0298, 77.5898` | Yes | `baptist_hebbal` | `hospital123` |
| `b1000003-...` | Ramaiah Memorial Hospital, Mathikere | `13.0315, 77.5645` | Yes | `ramaiah_memorial` | `hospital123` |
| `b1000004-...` | Victoria Hospital (BMCRI Apex Trauma) | `12.9634, 77.5744` | Yes | `victoria_trauma` | `hospital123` |
| `b1000005-...` | Bowring and Lady Curzon Hospital | `12.9839, 77.6033` | Yes | `bowring_curzon` | `hospital123` |
| `b1000006-...` | Aster RV Hospital, JP Nagar | `12.9121, 77.5888` | Yes | `aster_jpnagar` | `hospital123` |
| `b1000007-...` | Sparsh Hospital, Electronic City | `12.8452, 77.6601` | Yes | `sparsh_ecity` | `hospital123` |
| `b1000008-...` | Akash Hospital & Trauma (Devanahalli Airport) | `13.2450, 77.7120` | Yes | `akash_devanahalli` | `hospital123` |
| `b1000009-...` | Nelamangala General Hospital (NH-48 Outskirts) | `13.0982, 77.3871` | Yes | `nelamangala_trauma` | `hospital123` |

* **Police Control Headquarters**: Username `police_control` / Password `police123`
* **Ambulance Pilot Cockpit**: Username `ambulance_pilot` / Password `ambulance123`

---

## 12. API Reference & Real-Time Socket.io Contracts

### 12.1 Core REST Endpoints

| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `POST` | `/auth/login` | Validates credentials and returns JWT bearer token | Public |
| `GET` | `/auth/me` | Validates token and returns current user session | Bearer JWT |
| `GET` | `/hospitals` | Returns all 25 hospitals (supports `?near=lat,lng&radius_km=N`) | Public |
| `POST` | `/incidents/suspected` | Logs soft pre-alert marker for Police Control radar | Public / Citizen |
| `POST` | `/incidents/:id/confirm` | Promotes suspected alert to full broadcasting triage | Public / Citizen |
| `POST` | `/incidents/:id/cancel` | Cancels suspected alert when user taps "I'm OK" | Public / Citizen |
| `POST` | `/incidents` | Reports active crash dispatch; triggers PostGIS triage & 45s timer | Public / Citizen |
| `GET` | `/incidents` | Lists active incidents for Police or Hospital feeds | Optional JWT |
| `GET` | `/incidents/active` | Queries unaccepted or active incidents within hospital radius | Optional JWT |
| `POST` | `/incidents/:id/accept` | Claims trauma bay with PostgreSQL row-lock (`FOR UPDATE`) | Hospital Staff |
| `POST` | `/incidents/:id/reject` | Records hospital diversion with reason; triggers escalation | Hospital Staff |
| `POST` | `/incidents/:id/claim` | Paramedic ambulance claims patient transport dispatch | Ambulance |
| `POST` | `/incidents/:id/arrived` | Records ambulance arrival at scene with GPS coordinates | Ambulance |
| `POST` | `/incidents/:id/health-card/break-glass` | Decrypts ABHA emergency card with mandatory audit log | Hospital Staff |
| `DELETE`| `/incidents` | Admin cleanup: wipes database, Redis keys, resets dashboards | Public / Admin |

### 12.2 Real-Time Socket.io Event Matrix

```
Client / Mobile                       Backend Server                       Dashboards
      │                                     │                                  │
      ├─── incident_suspected ─────────────>│─── incident_suspected ──────────>│ (Police only)
      │                                     │                                  │
      ├─── new_incident ───────────────────>│─── new_incident ────────────────>│ (Matched Hospitals)
      │                                     │─── new_incident ────────────────>│ (Police Room)
      │                                     │                                  │
      │    [45s Timeout fires]              │─── incident_escalated ──────────>│ (Global Broadcast)
      │                                     │    (Perimeter: 8km -> 20km)      │
      │                                     │                                  │
      │                                     │<─── accept_case (Hospital A) ────┤
      │                                     ├─── case_locked ─────────────────>│ (All Hospitals)
      │                                     ├─── case_accepted ───────────────>│ (Police & Mobile)
      │                                     │                                  │
      ├─── ambulance_location_update ──────>│─── ambulance_location_update ───>│ (Live Map Track)
      │                                     ├─── traffic_signal_preempted ────>│ (Green Corridor)
```

---

## 13. Verification, Testing & Running the System

### 13.1 Automated Test Execution

```bash
# 1. Run all 93 Backend Unit & Integration Tests (100% Pass)
cd backend
npm test

# Output:
# --- RBAC TEST SUMMARY: 18 PASSED, 0 FAILED
# --- PHASE 17 TEST SUMMARY: 29 PASSED, 0 FAILED
# --- PHASE 18 TEST SUMMARY: 46 PASSED, 0 FAILED
# ALL 93 BACKEND TESTS PASSED SUCCESSFULLY.

# 2. Run all 54 Flutter Mobile Kinematic & UI Tests (100% Pass)
cd ../mobile
flutter test

# Output:
# 00:10 +54: All tests passed!

# 3. Verify Dashboard Production Build
cd ../dashboard
npm run build

# Output:
# ✓ 1560 modules transformed.
# ✓ built in 2.62s with zero TypeScript errors.
```

### 13.2 Running the Development Environment

1. **Start PostgreSQL & Redis**:
   ```bash
   docker-compose up -d
   ```
2. **Apply Migrations and Seed 25 Hospitals**:
   ```bash
   cd backend
   npm run migrate
   ```
3. **Start Central Coordination Backend**:
   ```bash
   cd backend
   npm run dev
   # Server active on http://127.0.0.1:5000
   ```
4. **Start Web Tactical Dashboards**:
   ```bash
   cd dashboard
   npm run dev
   # Dashboard active on http://localhost:5173
   ```
5. **Launch Citizen Edge App**:
   ```bash
   cd mobile
   flutter run -d chrome # or run on connected Android/iOS device
   ```
6. **Pre-Pitch Clean Reset**:
   * To wipe all test accidents and reset all open browser consoles back to zero:
   ```bash
   cd backend
   npm run demo:reset
   ```
   * Or click the red **"Purge Test Incidents & Reset Demo Feed"** button in the Admin View.
