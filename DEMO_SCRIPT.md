# Rakshak-AI — Hackathon Demo Script (< 3 Minutes)

> **Objective:** Deliver a high-energy, flawless, end-to-end live demonstration of Rakshak-AI to judges.  
> **Core Narrative:** When severe road accidents strike, the "Golden Hour" is lost because victim phones are locked, bystanders panic without clinical training, and ambulances navigate blindly without knowing hospital trauma bed readiness. Rakshak-AI solves this edge-first with zero friction: locked-screen bystander override, on-device kinematic crash intelligence, sub-second police pre-alerts, zero-gallery volatile imaging, native SIM peer-to-peer family emergency SMS alerts, C-V2X Green Corridor signal preemption, and sub-second multi-agency coordination.

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
   - Keep three tabs open:
     - Tab 1 = **Hospital View** (`Apollo Hospital / Manipal Hospital`)
     - Tab 2 = **Police View** (Tactical Blackspot & Signal Map)
     - Tab 3 = **Admin Reset Lab** (`/admin`)
4. **Mobile Device / Physical Phone:**
   - Ensure the app is open on the **Trip Guard** screen (Monitoring Active).
   - Check **Settings -> Emergency Contacts**: ensure an emergency contact is saved.
5. **Clean Reset:**
   - On the Admin page (`/admin`), click **"CLEAR ALL ACTIVE INCIDENTS (CLEAN SLATE)"** or double-click `reset_demo.bat`.
   *(Instantly flushes PostgreSQL incidents, Redis caches, watchdog timers, and resets all dashboard feeds to 0).*

---

## Timed Pitch Walkthrough (Total: 2:45)

---

### Act 1: Hook & The Golden Hour Crisis (0:00 – 0:30)

* **Phone State:** Held in hand, showing **"Trip Guard Active: Monitoring Telemetry"** with live accelerometer/gyroscope readings moving.
* **Dashboard State:** Showing Apollo Hospital Trauma Bay with 0 active trauma alerts.
* **Words to Say:**
  > *"Judges, in vehicular accidents, 50% of fatalities happen in the first 60 minutes — the Golden Hour. But today, the system collapses in four places:  
  > 1. The victim's phone is password locked in their pocket.  
  > 2. What happens if the phone is crushed or there's zero network? No one knows until hours later.  
  > 3. Bystanders panic — they don't know CPR and don't know which hospital actually has open trauma ICU beds.  
  > 4. Ambulances fight bumper-to-bumper traffic without green lights.  
  >  
  > This is **Rakshak-AI** — an autonomous emergency response ecosystem that bridges the victim, bystander, family, trauma center, police, and traffic signals instantly."*

---

### Act 2: High-G Crash, Pre-Alert, and Evidence Engine (0:30 – 1:15)

* **Phone Action:**
  1. Under **Crash Simulation Harness**, tap **`TRIGGER IMPACT SIGNATURE`** (or open the **Detection Lab**).
  2. The phone screen immediately transitions to the emergency countdown with audible siren and graduated haptics: **"CRASH DETECTED — EMERGENCY SOS TRIGGERED"**.
  3. **Point to Police View Tab:** An **`impact_suspected`** pre-alert marker has ALREADY appeared in the police room — *before the countdown has even expired*!
  4. Point to the **Are You OK?** responsiveness prompt.
  5. Tap **"CONFIRM & DISPATCH HELP NOW"** (or let the countdown reach zero).
  6. Transition to **Intake Screen**: Snap a quick photo with the **Zero-Gallery Privacy Guarantee** badge.
* **Family / Emergency Contact SMS (Milestone 1):**
  * Show the notification: **Milestone 1 SMS** has arrived via native SIM:
    > *"RAKSHAK-AI ALERT: Rahul Verma may have been in an accident. Live location: https://maps.google.com/?q=12.9172,77.6228 . Emergency services have been notified."*
* **Hospital Dashboard Observation:**
  * Red trauma alert card slides into the Apollo Hospital Bay with audio chime.
  * Point to the live photo: appeared in $<400\text{ms}$ via volatile RAM.
  * Point to the **Measured Crash Severity Index** (Peak Accel, Speed Drop, Rollover, Responsiveness) and **Ayushman Bharat (ABHA) Medical Profile** (Blood Group O+, Organ Donor, Allergies).
* **Words to Say:**
  > *"Our edge-sensor engine detected a 6.5G deceleration and instant speed drop, checking for free-fall to eliminate false drops.  
  > Even before the 10-second countdown finished, a sub-second pre-alert flagged the police. And if the phone had been smashed to pieces, our 30-second silent watchdog would auto-escalate it anyway.  
  > Notice the photo: it is streamed straight through volatile RAM into Redis with a 10-minute TTL — never saved to the victim's device gallery. Maximum clinical context, zero privacy risk."*

---

### Act 3: Trauma Center Acceptance & Accident Blackspot (1:15 – 2:00)

* **Dashboard Action:**
  1. On the **Hospital Dashboard**, click **"Accept Emergency"**.
  2. Point out:
     - Card flips to **Emergency Accepted** with green pulsing border.
     - Family contact is revealed now that the case is locked.
     - An interactive **OSRM speed-profile route** renders to Apollo Hospital.
  3. Switch to **Police View Tab**:
     - Point out the **Silk Board High-Risk Blackspot** cluster badge!
     - The police console flags that this intersection has recurring accidents, showing historical incident frequency.
* **Family / Emergency Contact SMS (Milestone 2):**
  * Family receives **Milestone 2 SMS**:
    > *"UPDATE: Rahul Verma has been accepted by Apollo Hospital, Bannerghatta Road. Hospital contact: +91-80-26304050."*
* **Words to Say:**
  > *"PostGIS evaluated all Level-1 trauma centers within the golden radius. Apollo Hospital accepted with one click, locking the case across the city.  
  > The family immediately received Milestone 2 SMS naming Apollo Hospital.  
  > Simultaneously, Police Dispatch sees the incident mapped against Bangalore's known high-risk accident blackspots."*

---

### Act 4: Paramedic Ambulance Dispatch & C-V2X Green Corridor (2:00 – 2:30)

* **Phone Action:**
  1. On the mobile phone, tap **"Ambulance Mode"**.
  2. Tap the incident card and claim the run.
* **Family / Emergency Contact SMS (Milestone 3):**
  * Family receives **Milestone 3 SMS**:
    > *"UPDATE: Ambulance BLR-01 has been dispatched and is en route to Rahul Verma's location. Emergency services are responding."*
* **C-V2X Green Corridor & NTCIP Signal Preemption:**
  * Point to the **Ambulance Navigation HUD** and **Police Map**:
    - The live route shows traffic signal nodes.
    - Notice signals within 300 meters turn **GREEN** automatically, holding cross-traffic at **RED**!
    - The ambulance transmits a live GPS beacon every 4 seconds.
* **Words to Say:**
  > *"The paramedic claims the run. Immediately, Milestone 3 SMS alerts the family.  
  > As the ambulance rolls, our NTCIP 1202 traffic engine establishes an autonomous Green Corridor — flipping upcoming traffic signals green 300 meters ahead of the ambulance to clear gridlock."*

---

### Act 5: Closing & Detection Lab (2:30 – 2:45)

* **Mobile Action:**
  1. Open the **Detection Lab** in the mobile app.
  2. Show the scripted scenario replay table: Pothole, Speed Bump, Hard Brake, Phone Drop, Phone Thrown on Seat, Genuine Crash, Rollover.
* **Words to Say:**
  > *"To verify our engineering rigor, our Detection Lab replays standard edge scenarios on-device to prove immunity against potholes, seat tosses, and phone drops.  
  > Combined with our Admin Reset Lab, Trip Sentinel dead-man switch, and offline store-and-forward queue, Rakshak-AI is a battle-tested, life-saving reality.  
  > Thank you — we are ready for your questions!"*

---

## 1-Click Clean Slate Reset

To reset the entire system before another judging panel:
- Open `http://localhost:5173/admin` and click **"CLEAR ALL ACTIVE INCIDENTS (CLEAN SLATE)"**, or
- Run `reset_demo.bat` in the project root.
- The next alert will be clean **Incident #1**.
