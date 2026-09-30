# Rakshak-AI (रक्षक-AI)

> **Autonomous Emergency Crash Detection, Intelligent Dispatch & Multi-Agency Trauma Triage Network**

[![Flutter](https://img.shields.io/badge/Mobile-Flutter%203.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Node.js](https://img.shields.io/badge/Backend-Node.js%20v20%2B-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org/)
[![PostgreSQL](https://img.shields.io/badge/Spatial%20DB-PostgreSQL%20%2B%20PostGIS-336791?logo=postgresql&logoColor=white)](https://postgis.net/)
[![Redis](https://img.shields.io/badge/RAM%20Cache-Redis%207%20Volatile-DC382D?logo=redis&logoColor=white)](https://redis.io/)
[![React](https://img.shields.io/badge/Dashboard-React%20%2B%20Vite%20%2B%20TS-61DAFB?logo=react&logoColor=black)](https://react.dev/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## 🚨 The Problem: The Golden Hour Breakdown

In vehicular trauma accidents, **50% of fatalities occur within the first 60 minutes**—medically known as the **Golden Hour**. In current emergency ecosystems, survival rates collapse due to 4 systemic bottlenecks:

1. **Locked-Screen Obstacle**: The victim’s smartphone is password-protected or biometric-locked in their pocket or mount. Bystanders cannot unlock the device to access emergency contacts or health IDs.
2. **Delayed Family Awareness**: Families often remain unaware of critical crashes for hours until law enforcement arrives at the scene and manually identifies the victim.
3. **Bystander Hesitation & Triage Ambiguity**: Good Samaritans lack emergency medical training, fear legal entanglement, and have no visibility into which nearby hospitals actually have available ICU beds or surgical trauma teams.
4. **Blind Ambulance Navigation & Hospital Gridlock**: Paramedics waste 15–30 minutes calling around to locate open trauma bays while navigating traffic bottlenecks blindly without inter-agency coordination.

---

## 💡 The Solution: What is Rakshak-AI?

**Rakshak-AI** is a multi-tier, zero-friction emergency response platform that detects high-G vehicle collisions on-device, awakens the smartphone over the secure keyguard, triggers autonomous peer-to-peer family alerts, streams ephemeral incident telemetry directly into volatile memory, and coordinates trauma facilities, ambulances, and police control rooms in real time.

```
       [ Victim Smartphone (Locked) ]
                     │  High-G Collision (≥6.5G + Speed Drop to 0)
                     ▼
  ┌──────────────────────────────────────────────────────────────┐
  │  Android 14-16 Full-Screen Intent Overrides Keyguard Lock   │
  │  10-Second Audible Countdown Siren (Abort / Auto-Dispatch)   │
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
     │  (Within 8km Radius)   │            │  City Tactical Map     │  │
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
     │  Paramedic Ambulance Console (Nearby Incidents)   │
     │  One-Click Claim -> Family SMS Milestone 3        │
     │  Live GPS Beacon Broadcast + Speed-Profile Route  │
     └───────────────────────────────────────────────────┘
```

---

## ⚡ Core Technical Innovations

### 1. Edge-Sensor Crash Detection Rule Engine
* **High-G Impact Signature**: Continuously monitors high-frequency linear accelerometer and gyroscope streams at 50Hz. Requires a sustained deceleration spike of $\ge 6.5\text{G}$.
* **GPS Speed Drop Correlation**: The impact spike must be followed by a simultaneous drop in GPS speed toward $0\text{ km/h}$ within a 500ms correlation window.
* **Pothole & Speed-Bump Suppressor**: Distinguishes between multi-axis vehicle crashes and normal road vibrations by analyzing directional oscillation reversals ($1.5\text{G}\text{--}4.0\text{G}$ frequency bursts are automatically filtered out).

### 2. Lock-Screen Bystander Override (`USE_FULL_SCREEN_INTENT`)
* Overrides the native Android keyguard lock screen using `showWhenLocked`, `turnScreenOn`, and high-priority notification channels.
* Allows any passerby to confirm the emergency, initiate help, or speak with central dispatch without unlocking the device.
* Works seamlessly across Android 14, 15, and 16 (API 34–36) with deep-linking to system settings if runtime permissions require authorization.

### 3. Zero-Gallery Ephemeral Photo Streaming
* Bystanders can snap a critical scene or injury photograph.
* **Zero-Disk Privacy Guarantee**: The photo is never saved to the device’s local gallery, media storage, Google Photos, or iCloud.
* The raw JPEG bytes are read directly into volatile RAM, streamed over an encrypted WebSocket binary frame to a 10-minute TTL Redis RAM key, and destroyed automatically upon incident resolution.

### 4. Personal Peer-to-Peer SIM Emergency SMS (TRAI DLT-Exempt)
* Commercial SMS gateways (Twilio, MSG91, AWS SNS) require multi-week TRAI DLT template approvals for Indian phone numbers, incur recurring per-SMS charges, and introduce cloud points of failure.
* Rakshak-AI utilizes Android’s native `SmsManager` to dispatch peer-to-peer SMS directly from the device’s active physical SIM:
  * **Milestone 1 (Crash Alert)**: Sent immediately upon impact confirmation with a Google Maps live location link.
  * **Milestone 2 (Hospital Acceptance)**: Sent the moment an accredited trauma facility locks and accepts the case.
  * **Milestone 3 (Ambulance Dispatched)**: Sent when an ambulance unit claims the incident and begins en-route navigation.
* **Guaranteed GSM Single-Part Formatting**: All message templates are strictly constrained to $\le 160$ characters to prevent carrier/OEM multipart drops on modern Android devices.
* **Resilient Fallback**: Automatically opens an interactive in-app preview screen with 1-tap WhatsApp (`wa.me`) deep links if running on an emulator or if no SIM is present.

### 5. Spatial-AI Trauma Triage & Dynamic Escalation
* **PostGIS Spatial Radius Query**: Evaluates Level-1 and Level-2 trauma centers within an 8km golden radius, factoring in verified ICU capacity and surgical team availability.
* **Atomic Race-Safe Case Locking**: When multiple hospitals view the emergency card simultaneously, an atomic SQL `UPDATE ... WHERE status IN ('broadcasting', 'escalated')` ensures exactly one facility wins. All other facilities are locked out in sub-second time.
* **Autonomous Escalation Engine**: If all matched hospitals reject the case (or if no facility responds within 45 seconds), the search radius dynamically widens from 8km to 20km.

### 6. Turn-by-Turn Speed-Profile Roadway Navigation
* Integrates Leaflet and FlutterMap with OpenStreetMap/OSRM Driving APIs.
* Color-codes road segments based on speed profile annotations:
  * **Blue**: Free Flow ($>30\text{ km/h}$)
  * **Orange**: Moderate Congestion ($16\text{--}30\text{ km/h}$)
  * **Red**: Severe Bottleneck ($<16\text{ km/h}$)
* **Graceful Degradation**: If OSRM times out or internet connectivity drops, the system logs the incident and renders a straight-line spatial vector with distance calculation to prevent map freezes.

---

## 🏛 System Architecture & Ports

| Service | Directory | Tech Stack | Port | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **PostgreSQL + PostGIS** | `/db` | Docker (`postgis/postgis:16-3.4`) | `5432` | Geospatial spatial queries, hospital registry, incident history |
| **Volatile Redis** | - | Docker (`redis:7-alpine`) | `6379` | Zero-storage RAM cache (`--save "" --appendonly no`) for photo frames & beacons |
| **Core Backend & Socket.io**| `/backend` | Node.js + Express (TypeScript) | `5000` | Incident lifecycle, multi-agency socket rooms, escalation engine |
| **Hospital & Police Console**| `/dashboard` | React 18 + Vite + TypeScript | `5173` | Real-time trauma center portal, tactical police command map |
| **Mobile App** | `/mobile` | Flutter 3.x + Kotlin | Mobile | Background crash detector, locked-screen SOS, paramedic console |

---

## 📁 Repository Structure

```text
Rakshak-AI/
├── mobile/                           # Flutter mobile client (Bystander & Ambulance modes)
│   ├── android/                      # Native Android configuration (MethodChannels, Permissions)
│   │   └── app/src/main/kotlin/...   # MainActivity.kt (SmsManager, Keyguard, FullScreenIntent)
│   ├── lib/
│   │   ├── config/                   # Backend failover candidates & lock-screen settings
│   │   ├── models/                   # Incident, hospital, and emergency contact data models
│   │   ├── screens/                  # Crash Guard, Lock-Screen Alert, Intake, Ambulance Console
│   │   └── services/                 # Crash detector, SMS engine, socket tracking, photo streamer
│   └── test/                         # 34 comprehensive unit and widget tests
│
├── backend/                          # Express + TypeScript core server & WebSocket engine
│   ├── src/
│   │   ├── routes/                   # Incident creation, accept, reject, claim, and photo streams
│   │   ├── scripts/                  # reset_demo.ts (1-second pre-pitch state reset)
│   │   ├── db.ts                     # PostGIS connection pool
│   │   ├── redis.ts                  # Volatile RAM client
│   │   ├── server.ts                 # Server entrypoint & graceful shutdown handlers
│   │   └── socket.ts                 # Multi-agency Socket.io room broadcasts
│   └── package.json
│
├── dashboard/                        # Vite + React web console
│   ├── src/
│   │   ├── components/               # Incident cards, Leaflet route maps, tactical police map
│   │   ├── services/                 # Socket.io connection manager & telemetry logger
│   │   └── views/                    # Hospital Trauma Bay View & Police Control Room View
│   └── package.json
│
├── db/                               # Database initialization
│   └── init/                         # 01-schema.sql, 02-seed-hospitals.sql (Bengaluru trauma registry)
│
├── DEMO_SCRIPT.md                    # Exact, timed 2:45 walkthrough script for live judge pitches
├── docker-compose.yml                # PostGIS and Redis container orchestration
└── reset_demo.bat                    # One-click Windows demo state reset script
```

---

## 🛠 Step-by-Step Setup & Execution

### Prerequisites
* [Docker & Docker Desktop](https://www.docker.com/) installed and running.
* [Node.js](https://nodejs.org/) (v20+ recommended).
* [Flutter SDK](https://flutter.dev/) (v3.24+ recommended).
* Android Studio / Android SDK with platform-tools (`adb`).

---

### Step 1: Start Databases (PostGIS & Volatile Redis)
```bash
docker compose up -d
```
Verify containers are running:
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
Health Check: `http://localhost:5000/health`

---

### Step 3: Launch Hospital & Police Dashboard (Port 5173)
```bash
cd dashboard
npm install
npm run dev
```
Open in browser: `http://localhost:5173`
* Toggle between **Hospital View** and **Police View** using the top navigation bar.
* Enable **⚡ Live Telemetry: ON** in the header to view real-time WebSocket packet logs.

---

### Step 4: Run Mobile Client (Physical Device or Emulator)

#### For a Physical Android Device (Recommended for Live Demo):
1. Connect phone via USB or Wireless ADB:
   ```bash
   adb devices
   ```
2. Enable local port forwarding for zero-latency backend connectivity:
   ```bash
   adb reverse tcp:5000 tcp:5000
   ```
3. Run the app:
   ```bash
   cd mobile
   flutter run -d <device_id>
   ```

---

## 🔄 One-Click Demo Reset (Pre-Pitch Cleanup)

To run multiple live demonstrations for different judges without stale data:
```bash
# From repository root:
reset_demo.bat

# Or from backend directory:
cd backend && npm run demo:reset
```
**What this performs in < 1 second:**
1. Truncates all PostgreSQL incidents and rejection history.
2. Clears volatile Redis image streams and ambulance telemetry keys.
3. Automatically broadcasts `feed_cleared` to all connected web dashboards and mobile devices, wiping SMS alert deduplication history so subsequent demo runs fire all 3 emergency SMS alerts cleanly.

---

## 🔒 Privacy, Security & Compliance Guarantees

* **Zero Persistent Image Storage**: Accident photos are held exclusively in volatile RAM and destroyed after 10 minutes.
* **On-Device Contact Privacy**: Victim emergency contacts reside 100% locally on-device in `SharedPreferences`. They are never harvested or stored in cloud user tables; contact info is only attached ephemerally to `victim_metadata` during an active, confirmed crash dispatch.
* **Privacy-Gated Hospital Access**: Family phone numbers are concealed on the dashboard until a hospital officially accepts the case, preventing patient data leaks during initial triage.
* **TRAI DLT Compliance**: Avoids commercial bulk SMS gateways by routing personal peer-to-peer notifications through Android’s native SIM stack.

---

## 👥 Contributors

* **Stevin Joseph** — *System Architecture, Mobile Edge Engine, Backend Core, Spatial Triage & Dashboards*
