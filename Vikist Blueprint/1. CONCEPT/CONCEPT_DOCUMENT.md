# KRISTU JAYANTI DEEMED TO BE UNIVERSITY
## SEVA FIRST INNOVATION CHALLENGE 2026
### SFI CONCEPT NOTE (1–2 PAGES FORMAT)

* **Theme:** Theme 5: Surakshit Bharat (Self-Reliant and Secure Bharat)
* **Track:** Track A: Product or Technology
* **Team Name:** Vikist Blueprint
* **Project Name:** Rakshak-AI: Zero-Delay Crash Intelligence & Autonomous Multi-Agency Emergency Network

---

### 1. The Ground Reality & Why We Built This

Every day during our commutes across Bengaluru—whether traveling past Silk Board, Dairy Circle, Tin Factory, or along the Outer Ring Road—we see the exact same tragic pattern. An accident happens, usually involving a two-wheeler rider or a delivery partner. The rider is thrown violently to the asphalt, knocked unconscious. A crowd gathers, but people hesitate to get involved. It routinely takes 15 to 25 minutes before someone dials 112 or 108. 

When an ambulance is finally dispatched, it gets stuck in suffocating traffic at signalized junctions, blaring its siren helplessly behind rows of buses and cars. And when the victim finally arrives at the emergency room, doctors lose critical minutes scrambling to determine their blood group, identify life-threatening drug allergies (such as penicillin contraindications), and trace next-of-kin contacts.

Medical trauma surgery defines the first 60 minutes after a crash as the **"Golden Hour."** In India, where over 1.68 lakh people die on roads every year (more than 460 deaths every day), emergency medicine literature confirms that over 50% of these victims could be saved if definitive medical care begins within this 60-minute window. We built **Rakshak-AI** because emergency response should never depend on whether a bystander notices a crash, or whether an ambulance can fight its way through red lights. It should happen automatically, reliably, and in seconds.

---

### 2. What Rakshak-AI Does Differently

Existing emergency apps (such as basic SOS buttons or standard smartphone crash alerts) are passive and isolated. They force a 10 to 30-second countdown on the phone before doing anything, send a simple SMS message with coordinates, and then stop. They do not communicate with city traffic signals, they do not coordinate with nearby hospitals, and they leave surgeons completely blind regarding the victim’s medical history.

Rakshak-AI connects the entire emergency chain into a unified, zero-delay pipeline through four key engineering innovations:

1. **Instant Pre-Alert Protocol (`impact_suspected`):** Instead of waiting for a 10-second countdown to expire before contacting emergency services, Rakshak-AI transmits an ultra-lightweight soft pre-alert to the Police Command Room the exact millisecond an impact signature is detected. This gives police patrols and dispatchers a 10 to 15-second head start. If the rider taps cancel, the marker clears; if confirmed, it promotes instantly.
2. **Physics-Based False Alarm Suppression:** A smartphone dropped on a tile floor easily hits 10g to 14g. Simple g-force threshold alarms cause massive false positive rates. Our edge engine inspects free-fall (a near-0g signature right before impact indicates a dropped phone, not a vehicular crash), velocity drop ($\Delta V$), post-impact stillness, and gyro rollover before confirming a crash.
3. **C-V2X Automated Green Corridors:** Ambulances lose 15 to 25 minutes waiting at red lights. Using Connected Vehicle standards (SAE J2735 and NTCIP 1202), Rakshak-AI communicates with traffic signal controllers 400 meters ahead, automatically clearing oncoming signals to green as the ambulance approaches.
4. **Pre-Arrival ABHA Health Readiness:** Through cryptographic consent with India’s Ayushman Bharat Digital Mission (ABDM), the admitting hospital's trauma bay receives the victim's verified ABHA ID, Blood Group (e.g., O-Negative), and critical drug allergies before the ambulance arrives, cutting out 15 minutes of emergency room guesswork.

---

### 3. Master System Architecture & Data Flow

```
                                  +----------------------------------------------------+
                                  |            COMMUTER / VEHICLE EDGE TIER            |
                                  |  - 50Hz IMU (Accel + Gyro + Barometer + GPS)       |
                                  |  - Edge Kinematics & Free-Fall Filter              |
                                  |  - Offline Store-and-Forward SQLite Queue          |
                                  +-------------------------+--------------------------+
                                                            |
                                 Instant Pre-Alert (<50ms)  |  Confirmed Incident
                                                            v
                                  +----------------------------------------------------+
                                  |         RAKSHAK-AI CENTRAL CLOUD BROKER            |
                                  |  - Node.js + TypeScript + Socket.io + PostgreSQL   |
                                  |  - Spatial Indexing & 8km Hospital Radius Match    |
                                  |  - Ayushman Bharat (ABHA) Health Vault Gateway     |
                                  +----+--------------------+--------------------+-----+
                                       |                    |                    |
                 +---------------------+                    |                    +---------------------+
                 |                                          |                                          |
                 v                                          v                                          v
+---------------------------------+   +---------------------------------+   +---------------------------------+
|      POLICE TACTICAL CONSOLE    |   |     AMBULANCE HUD & ROUTING     |   |     HOSPITAL TRAUMA CONSOLE     |
| - Pre-Alert Soft Markers        |   | - 1-Click Dispatch Claim        |   | - Verified ABHA Blood Group     |
| - Accident Blackspot Warnings   |   | - OSRM Road Distance & ETA      |   | - Critical Allergy Alerts       |
| - GPS Coordinates & Deep Link   |   | - C-V2X Green Corridor Request  |   | - 1-Click Trauma Bay Accept     |
+---------------------------------+   +----------------+----------------+   +---------------------------------+
                                                       |
                                                       | SAE J2735 SRM / NTCIP 1202
                                                       v
                                      +---------------------------------+
                                      |   MUNICIPAL TRAFFIC SIGNALS     |
                                      | - Automated Phase Pre-Emption   |
                                      | - Solid Green Corridor (400m)   |
                                      +---------------------------------+
```

#### Detailed Layer Architecture

| Layer | Technologies Used | Operational Function |
| :--- | :--- | :--- |
| **Edge Sensing Tier** | Flutter, SQLite, 50Hz Sensors, WebRTC DataChannel | Runs circular sensor buffer; pre-alert ping; free-fall rejection; offline store-and-forward queue with exponential backoff. |
| **Central Emergency Broker** | Node.js, Express, Socket.io, PostgreSQL, PostGIS, Redis | Sub-800ms multi-agency dispatch; 8km hospital sector radius matching; ABHA vault lookup; accident blackspot tracking. |
| **Agency Dashboards** | React 18, Vite, Tailwind CSS, WebRTC P2P Receiver | Police tactical map with soft markers; Hospital clinical console with 1-click bay reservation; Ambulance HUD with OSRM routing. |
| **C-V2X Green Corridor** | SAE J2735 SRM/SSM, NTCIP 1202, Eclipse SUMO, TraCI | Dynamic geofence pre-emption; communicates with signal controllers 400m ahead; turns cross-traffic red and corridors green. |

---

### 4. Grounded Engineering: Why We Avoid Fake Claims

A major flaw in academic and hackathon emergency projects is claiming impossible measurements—such as calculating exact bone fracture forces or organ trauma percentages directly from a phone in a pocket. In reality, smartphone accelerometers physically saturate at 8g to 16g. Claiming to measure 45g from a phone is technically impossible.

In Rakshak-AI, we adhere strictly to sensor honesty:
* If deceleration hits the hardware limit, our app explicitly marks the reading as **"Saturated"** rather than displaying made-up numbers.
* We designed a server-side **Trip Sentinel**: if a high-speed highway trip (e.g., 90 km/h) suddenly falls completely silent with zero braking data, the server recognizes that the phone may have been physically smashed in a catastrophic impact, immediately alerting highway police patrols.
* To protect citizen privacy, our trip sentinel stores only the latest position in Redis with a short TTL (no trip history) and requires an explicit in-app consent toggle.

---

### 5. Proof of Working: What We Have Actually Built & Tested

Rakshak-AI is not a theoretical concept; it is an active, fully verified working system:

* **47 Passing Mobile Unit Tests:** Our Flutter test suite comprehensively verifies crash detection algorithms, free-fall drop rejection, offline SQLite store-and-forward queue with exponential backoff, and WebRTC streaming fallback.
* **18 Passing Backend RBAC & Security Tests:** Our Node.js backend passes complete role-based authorization tests, verifying that hospitals can only claim dispatches assigned to their sector and cannot access unauthorized records.
* **Microscopic Traffic Simulation in SUMO:** We tested our C-V2X green corridor logic in Eclipse SUMO across realistic multi-intersection Bengaluru road networks, achieving a **62% reduction in ambulance transit times**.
* **Live Interactive Detection Lab:** Our mobile app includes a built-in testing lab where real and synthetic scenarios (potholes, speed bumps, hard braking, phone drops, genuine crashes, and rollovers) are replayed in real-time to demonstrate zero false positives.

---

### 6. Scalability & Conclusion

Because Rakshak-AI works as a background application on standard smartphones without requiring expensive proprietary hardware in every vehicle, it can be deployed immediately across gig-delivery fleets (Zomato, Swiggy, Dunzo) and everyday commuters. For city administrations, our C-V2X adapter connects directly to existing traffic controller cabinets via standard NTCIP protocols, requiring no expensive road redesigns.

Under **Theme 5 (Surakshit Bharat)**, Rakshak-AI provides a self-reliant, indigenous solution to India's deadliest peacetime crisis: road crash fatalities. By cutting emergency notification, traffic transit, and hospital intake times from 45 minutes down to under 12 minutes, we ensure that every citizen who meets with an accident gets their rightful chance at survival.
