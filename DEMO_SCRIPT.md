# Rakshak-AI — Hackathon Demo Script (< 3 Minutes)

> **Objective:** Deliver a high-energy, flawless, end-to-end live demonstration of Rakshak-AI to judges.  
> **Core Narrative:** When severe road accidents strike, the "Golden Hour" is lost because victim phones are locked, bystanders panic without clinical training, and ambulances navigate blindly without knowing hospital trauma bed readiness. Rakshak-AI solves this edge-first with zero friction, locked-screen bystander override, zero-gallery volatile imaging, native SIM peer-to-peer family emergency SMS alerts, and sub-second multi-agency coordination.

---

## Pre-Flight Setup Checklist (Do This 5 Minutes Before Pitch)

1. **Docker Services:** Ensure Postgres (PostGIS) & Redis are running:
   ```bash
   docker compose up -d
   ```
2. **Backend Server:**
   ```bash
   cd backend && npm run dev
   ```
3. **Web Dashboard:** Open in browser (`http://localhost:5173`):
   - Click the top right **"⚡ Live Telemetry: ON"** switch to show the live WebSocket event drawer.
   - Keep two tabs open: Tab 1 = **Hospital View** (`Apollo Hospital`), Tab 2 = **Police View**.
4. **Mobile Device / Physical Phone:**
   - Ensure the app is open on the **Bystander Mode** screen (Crash Guard Active).
   - Check **Settings -> Emergency Contacts**: ensure an emergency contact is saved (pre-seeded with demo contacts or set to your own number for real live SMS receipt).
5. **Clean Reset:** Double-click `reset_demo.bat` or run:
   ```bash
   npm run demo:reset
   ```
   *(Wipes test database incidents, rejections, Redis RAM cache, and signals all mobile apps to wipe SMS deduplication keys in 1 second).*

---

## Timed Pitch Walkthrough (Total: 2:45)

---

### Act 1: Hook & The Golden Hour Crisis (0:00 – 0:30)

* **Phone State:** Held in hand, showing **"Crash Guard Active: Monitoring Telemetry"** with live accelerometer/gyroscope readings moving.
* **Dashboard State:** Showing clean Apollo Hospital Bay with 0 active trauma alerts.
* **Words to Say:**
  > *"Judges, in road accidents, 50% of fatalities occur in the first 60 minutes — the Golden Hour. But today, the system breaks in four places:  
  > 1. The victim's phone is password locked in their pocket.  
  > 2. The victim's family has no idea an accident even happened until police piece together ID hours later.  
  > 3. Bystanders freeze — they don't know CPR and don't know which hospital actually has ICU beds ready.  
  > 4. Ambulances waste 20 minutes calling around to find an open trauma bay.  
  >  
  > This is **Rakshak-AI** — an autonomous emergency response ecosystem that bridges the victim, the bystander, the family, the paramedic, and the trauma center instantly."*
* **Fallback Plan:** If device sensors aren't active, point to the live IMU diagnostics card on screen: the sensor values update on any physical motion.

---

### Act 2: High-G Crash, Family SOS SMS & Zero-Gallery Triage (0:30 – 1:15)

* **Phone Action:**
  1. Under **Crash Simulation Harness**, leave Deceleration at **6.5 G** and Speed Drop at **65 km/h**.
  2. Tap the red button: **`TRIGGER IMPACT SIGNATURE`**.
  3. The phone screen instantly switches to the high-contrast emergency screen: **"CRASH DETECTED — EMERGENCY SOS TRIGGERED"** with the 10-second countdown timer and siren pulsing.
  4. Tap **"CONFIRM & DISPATCH HELP NOW"** (or let the countdown reach zero).
  5. The screen immediately transitions to **Intake & Triage**.
  6. Point to the green **Zero-Gallery Privacy Guarantee** badge.
  7. Tap **"Capture Incident / Injury Photo"**, snap a quick picture of the desk/laptop, and tap checkmark.
* **Family / Emergency Contact SMS (Milestone 1):**
  * Hold up the second phone (or point to notification banner): **Milestone 1 SMS** has arrived via the phone's native SIM:
    > *"RAKSHAK-AI ALERT: Rahul Verma may have been in an accident. Live location: https://maps.google.com/?q=13.0126,77.5946 . Emergency services have been notified."*
* **Dashboard Observation:**
  * Point to the top telemetry drawer: notice `new_incident` fires instantly via WebSocket room `incident:<id>`.
  * A red trauma alert card slides into the Apollo Hospital Bay with audio ping!
  * Point to the live photo on the card: the photo appeared in less than 400 milliseconds.
* **Words to Say:**
  > *"Our edge-sensor engine detected a 6.5G deceleration accompanied by an instant speed drop to zero — filtering out ordinary phone drops or potholes.  
  > Even with the device locked, Android's Full-Screen Intent overrides the lock screen so any bystander can initiate help.  
  > The moment impact is confirmed, two things happen instantly:  
  > First, the phone sends an immediate SOS SMS directly to the victim's emergency contacts via native peer-to-peer SIM messaging — zero third-party gateway delays, zero TRAI DLT template blocks.  
  > Second, when the bystander captures a photo of the vehicle impact, look closely at our privacy guarantee: **the photo is never saved to the device's photo gallery**. It streams purely through volatile RAM directly to the trauma team and expires in Redis after 10 minutes. Zero privacy risk, maximum clinical context."*
* **Fallback Plan:** If no physical SIM is in the device, the app automatically opens the **Emergency SMS Preview Screen** with a 1-tap **"Send via WhatsApp"** deep link.

---

### Act 3: Trauma Center Acceptance, Family Update & Roadway Routing (1:15 – 2:00)

* **Dashboard Action:**
  1. On the **Hospital Dashboard** (`Apollo Hospital`), click the incoming incident card.
  2. Point out:
     - Exact impact telemetry: **6.5G | 65 km/h**.
     - Vehicle Type: **Two-Wheeler**, Rider Status: **SOS Active (Unresponsive)**.
     - Live trauma bed capacity: **14 Beds Available, Level 1 Trauma Facility**.
  3. Click **"Accept Emergency"** button.
* **Dashboard & Mobile Observation:**
  * The card flips from amber to **Emergency Accepted** with green pulsing border.
  * **Privacy-Safe Family Contact Revealed**: Notice the card now displays:
    `Emergency Contact: Priya Sharma, +91-XXXXXXXXXX` — strictly hidden until acceptance so staff can immediately coordinate clinical consent.
  * An interactive **OSRM road route** instantly renders on the hospital map connecting the incident to Apollo Hospital.
  * Switch to the phone: the mobile triage card switches to **EMERGENCY ACCEPTED — APOLLO HOSPITAL** with direct ER phone number and address!
* **Family / Emergency Contact SMS (Milestone 2):**
  * The family member's phone receives **Milestone 2 SMS**:
    > *"UPDATE: Rahul Verma has been accepted by Apollo Hospital, Bannerghatta Road. Hospital contact: +91-80-26304050."*
* **Words to Say:**
  > *"Behind the scenes, Rakshak-AI queried our PostGIS spatial engine, identifying all Level-1 trauma centers within an 8-kilometer golden radius.  
  > Apollo Hospital sees the severity, checks their ER capacity, and accepts the case with one click.  
  > Instantly, the WebSocket room and dual-channel polling synchronize:  
  > The family immediately receives an automated update SMS naming Apollo Hospital and their emergency contact number.  
  > Simultaneously, Apollo's staff gets the family's contact details, and speed-profile road routing calculates the fastest pathway."*
* **Fallback Plan:** If OSRM public server has high latency, our graceful fallback draws the straight-line spatial path with distance in kilometers without interrupting the presentation.

---

### Act 4: Paramedic Ambulance Dispatch & Police City-Wide Command (2:00 – 2:30)

* **Phone Action:**
  1. On the mobile phone, tap the bottom navigation: **"Ambulance Mode"**.
  2. Notice the live **Ambulance Console**: shows the nearby incident with distance (e.g. `2.4 km away`) and status `ACCEPTED (Apollo Hospital)`.
  3. Tap the incident card to open **Ambulance Dispatch Screen** and claim the run.
* **Family / Emergency Contact SMS (Milestone 3):**
  * The family member's phone receives **Milestone 3 SMS**:
    > *"UPDATE: Ambulance BLR-01 has been dispatched and is en route to Rahul Verma's location. Emergency services are responding."*
* **Navigation & Live Beacon:**
  * Point out:
    - The **interactive navigation map** showing the ambulance's live vehicle icon, the red crash site, and the hospital destination.
    - The **speed profile overlay** (Blue = Clear Flow, Orange = Moderate, Red = Congested) with estimated ETA.
* **Dashboard Action:**
  1. Switch browser to **Police View** tab.
  2. Point out the interactive tactical city-wide map:
     - The active emergency appears as a color-coded tactical pin.
     - Clicking the pin pops up the victim telemetry, assigned ambulance ID (`Ambulance-BLR-01`), and accepting trauma facility.
* **Words to Say:**
  > *"Every ambulance crew has Ambulance Mode built right into their mobile device. The paramedic claims the run, and the family receives an automated SMS confirming that Ambulance BLR-01 is en route.  
  > Every 4 seconds, the ambulance emits a live GPS beacon over the incident socket room — allowing the hospital trauma team to track the incoming ambulance in real-time.  
  > Simultaneously, Police Dispatch has full city-wide situational awareness: active crashes, green-corridor routes, and inter-agency status all on one real-time tactical map."*
* **Fallback Plan:** If switching tabs takes too long, toggle between Hospital and Police views using the top navigation bar.

---

### Act 5: Closing & Architectural Differentiators (2:30 – 2:45)

* **Visual:** Point to the **⚡ Live Telemetry Drawer** showing all socket events chronologically (`new_incident` -> `image_update` -> `case_accepted` -> `ambulance_location`).
* **Words to Say:**
  > *"To summarize the engineering under the hood:  
  > - **Zero-Gallery Privacy:** Photos reside strictly in volatile RAM, streamed over WebSocket binary frames to Redis with non-persistent TTL.  
  > - **Peer-to-Peer Family SMS:** Direct SIM integration keeps families informed across all 3 emergency milestones with zero commercial gateway costs and zero DLT registration hurdles.  
  > - **Multi-Agency Sockets:** Bystander, Hospital, Paramedic, and Police communicate through synchronized rooms with dual-channel failover.  
  > - **Dynamic Escalation:** If no hospital accepts within 30 seconds, the search radius automatically widens from 8km to 20km.  
  >  
  > Rakshak-AI turns passive bystander phones and disjointed emergency departments into an autonomous, synchronized lifesaving network.  
  > Thank you — we're ready for your questions!"*

---

## Judge Q&A Cheat Sheet (Anticipated Questions)

| Question | Winning Answer |
| :--- | :--- |
| **"Why native SIM SMS instead of Twilio or cloud SMS gateways?"** | *"In India, commercial SMS gateways require multi-week TRAI DLT template registration, business entity verifications, and charge per-SMS fees. Sending directly through Android's native `SmsManager` is personal peer-to-peer messaging: zero DLT delays, zero API costs, works off-grid with regular cellular towers, and automatically falls back to an interactive WhatsApp deep link if running on an emulator."* |
| **"What if the phone just drops off the car seat?"** | *"We require dual confirmation: a high-G impact spike (6.5G+) AND an immediate drop in GPS speed to 0. A dropped phone has high acceleration but maintains vehicle cruising speed, which our rule engine explicitly filters out."* |
| **"What if the bystander takes an inappropriate photo?"** | *"The photo never touches Android media storage, Google Photos, or iCloud. It streams via volatile RAM directly to the authenticated trauma bay and self-destructs from Redis RAM after 10 minutes."* |
| **"What if the venue WiFi disconnects during emergency dispatch?"** | *"Every screen has graceful offline degradation. Telemetry is queued locally in volatile memory, the map displays cached spatial boundaries, and our dual-channel architecture uses a 2-second background HTTP polling heartbeat alongside WebSockets to ensure zero dropped milestones."* |
| **"Is the traffic on the map real-time Google probes?"** | *"We use OSRM routing with OpenStreetMap road-hierarchy speed annotations. It maps arterial versus local road speed limits, providing speed-profile delay estimates without costly third-party API dependencies."* |
| **"Why not just dial 108/911?"** | *"Voice calls take 2-4 minutes to explain landmarks, determine caller coordinates, and relay medical context. Rakshak-AI transmits exact GPS, impact severity, injury imagery, bed reservations, and family notifications within 400 milliseconds."* |

---

## 1-Second Reset Command

If you need to re-run the demo for another judge:
```bash
# In project root:
reset_demo.bat
```
*(Or in backend directory: `npm run demo:reset`)*  
**What this does:**
1. Purges PostgreSQL test incidents and rejections.
2. Purges Redis ephemeral photo streams and ambulance GPS beacons.
3. Automatically broadcasts `feed_cleared` to all connected web dashboards and mobile devices, wiping `_dispatchedAlertKeys` so subsequent runs re-fire all 3 emergency SMS messages cleanly without deduplication conflicts.  
**You are immediately ready for the next live pitch!**
