# Rakshak-AI: Threat Model (STRIDE Methodology)

**System Classification**: Life-Critical Emergency Response & Geospatial Triage Platform  
**Target Architecture**: Android/iOS Mobile Apps, Express/TypeScript Core Backend, PostgreSQL/PostGIS, Redis Ephemeral RAM, Vite/React Web Portals  
**Standard**: STRIDE (Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege)  
**Status**: Phase 26 Hardened Baseline  

---

## 1. System Decomposition & Data Flow Diagram (DFD)

```
[ Citizen App / Crash Sensors ]
         │ (HTTPS / WSS + HMAC Signatures)
         ▼
[ Express API Gateway (TLS 1.3, Helmet, CSP, CORS, Rate Limiting) ]
   ├── [ Auth & RBAC Service (JWT 15m + Refresh 7d, Account Lockout) ]
   ├── [ Redis Volatile RAM (AES-256-GCM Ephemeral Photos, 900s TTL) ]
   ├── [ PostgreSQL 16 + PostGIS (Incidents, Hospitals, Hash-Chained Audit Log) ]
   └── [ Socket.IO Gateway (Role-Scoped Rooms, Authorized Joins) ]
         │ (WSS)
   ┌─────┴──────────────────────────────┐
   ▼                                    ▼
[ Hospital ER Dashboard ]    [ Police ITMS Tactical Map ]
```

---

## 2. Component-by-Component STRIDE Matrix

### 2.1 Citizen Mobile Client (Sensor Layer & Dispatch)

| Threat Category | Threat Description | Impact | Mitigation Mechanism | Implementation Status |
| :--- | :--- | :--- | :--- | :--- |
| **Spoofing** | Attacker impersonates legitimate citizen app and floods fake accident reports. | Severe: Emergency resources diverted from genuine victims. | Payload signing (`x-device-signature`) with HMAC-SHA256, device ID attribution, and timestamp clock-skew validation. | **Implemented** |
| **Tampering** | Attacker intercepts and modifies GPS coordinates or victim medical indicators en route. | High: Ambulance routed to wrong intersection; wrong clinical prep. | TLS 1.3 transport security, strict HMAC-SHA256 verification over payload body. | **Implemented** |
| **Repudiation** | Malicious prankster denies triggering a false emergency dispatch. | Medium: Inability to hold fraudulent callers accountable. | Device ID attribution, cryptographically timestamped audit log records with SIM carrier telemetry. | **Implemented** |
| **Information Disclosure** | Local malware on rooted phone extracts stored emergency contacts or ABHA health data. | High: PII / Medical data leakage. | On-device data sandboxed in Android EncryptedSharedPreferences / iOS Keychain; zero medical records in plaintext. | **Implemented** |
| **Denial of Service** | Malicious app repeatedly triggers crash broadcasts to overwhelm local network stack. | High: Device battery exhaustion, backend congestion. | Local sensor debouncing (20s countdown gate), store-and-forward backoff queue, server-side device rate limiting (5 req/min). | **Implemented** |
| **Elevation of Privilege** | Compromised citizen client attempts to access police triage controls or hospital acceptance APIs. | Critical: Unauthorized acceptance/locking of emergencies. | Strict JWT RBAC middleware (`requireRole('police')`, `requireRole('hospital_staff')`). Citizen requests unauthenticated or scoped only to incident creation. | **Implemented** |

---

### 2.2 Backend API & Socket.IO Gateway

| Threat Category | Threat Description | Impact | Mitigation Mechanism | Implementation Status |
| :--- | :--- | :--- | :--- | :--- |
| **Spoofing** | Attacker connects to WebSocket room `incident:{id}` or `all_incidents` without authorization. | Critical: Eavesdropping on ongoing emergencies and patient location. | Server-side authorization on `join_incident` and `join_police`; hospital staff permitted only for matched facilities. | **Implemented** |
| **Tampering** | Man-in-the-Middle attacker intercepts or modifies transit payloads. | Critical: Corruption of hospital acceptance or dispatch routes. | Mandatory TLS 1.3/HTTPS and WSS; HSTS preload; cleartext strictly prohibited in production builds. | **Implemented** |
| **Tampering** | Rogue DBA or attacker modifies database audit logs to conceal medical malpractice or neglect. | Critical: Loss of evidentiary audit integrity. | Hash-chained audit log with SHA-256 links (`prev_hash`), PostgreSQL triggers revoking UPDATE/DELETE. | **Implemented** |
| **Repudiation** | Hospital disputes having rejected an emergency case during Golden Hour. | High: Accountability void in fatality investigation. | Mandatory rejection logging in `incident_rejections` with hash-chained cryptographic audit entry recording user & hospital ID. | **Implemented** |
| **Information Disclosure** | Redis RAM dump exposes incident scene photos or victim injuries. | Critical: Non-consensual dissemination of traumatic accident imagery. | AES-256-GCM encryption before writing to Redis (`storeEncryptedIncidentPhoto`); per-incident HKDF keys; 900s auto-purge. | **Implemented** |
| **Information Disclosure** | Log aggregators leak victim telephone numbers, full names, or blood types. | Medium: Privacy violation under DPDP Act 2023. | Centralized PII log redaction (`maskPhoneNumber`, `maskName`); raw telephone numbers never written to console output. | **Implemented** |
| **Denial of Service** | Volumetric HTTP DDoS or credential stuffing against `/auth/login`. | High: Dashboard unavailable to trauma center staff during mass casualty. | Helmet, CORS origin allowlist, rate limiting (5 failed logins -> 15m lockout), 5MB payload caps. | **Implemented** |
| **Elevation of Privilege** | Hospital A attempts to accept or view incidents assigned exclusively to Hospital B. | Critical: Inter-hospital conflict, unauthorized patient data access. | API and Socket scoping: staff role verified against `accepted_hospital_id` or `matched_hospitals`; 403 returned on mismatch. | **Implemented** |

---

### 2.3 Web Dashboards (Hospital ER & Police Tactical Portals)

| Threat Category | Threat Description | Impact | Mitigation Mechanism | Implementation Status |
| :--- | :--- | :--- | :--- | :--- |
| **Spoofing** | Attacker brute-forces hospital credentials or steals long-lived session token. | High: Impersonation of emergency physician. | 15-minute access token lifespan, 7-day refresh token rotation, login rate limiting with temporary account lock. | **Implemented** |
| **Tampering** | Cross-Site Scripting (XSS) injecting malicious scripts to redirect ambulances. | Critical: Unauthorized command execution in hospital browser. | React automated DOM escaping, Helmet Content Security Policy (CSP) blocking external unsafe inline scripts. | **Implemented** |
| **Information Disclosure** | Accidental shoulder-surfing or public display of ABHA records in ER reception. | High: Sensitive personal medical history revealed to bystander. | Minimalist triage display: indicates only essential trauma flags; full ABHA requires explicit Break-Glass justification. | **Implemented** |
| **Information Disclosure** | Hardcoded demo credentials bundled into compiled production dashboard bundle. | High: Default password exploitation by external attacker. | Vite environment check (`import.meta.env.PROD`) strips all quick-fill demo presets from production builds. | **Implemented** |
| **Elevation of Privilege** | Police user attempts to accept hospital surgical cases or mark beds unavailable. | Medium: Mismanagement of hospital clinical resources. | RBAC role check: Police role receives 403 Forbidden on `PATCH /incidents/:id/status`. | **Implemented** |

---

## 3. Residual Risks & Roadmap Items

| Item | Threat Description | Current State | Target Roadmap Mitigation | Target Phase |
| :--- | :--- | :--- | :--- | :--- |
| **1. Hardware Secure Element** | Phone sensor firmware spoofing via rooted OS or kernel emulator. | Client software validation & GPS sanity checks. | Android Keystore Hardware-backed Attestation (SafetyNet / Play Integrity API) with TPM / StrongBox. | Phase 28 |
| **2. mTLS for Corridors** | Traffic signal preemption controller spoofing on local NTCIP network. | Simulated NTCIP service with IP/Token checks. | Mutual TLS (mTLS) with IEEE 1609.2 PKI digital certificates installed in physical roadside units (RSUs). | Phase 29 |
| **3. Automated Key Rotation** | Master photo encryption secret (`PHOTO_ENCRYPTION_SECRET`) rotation. | Static server secret with dynamic per-incident HKDF derivation. | Cloud KMS envelope encryption with automated 90-day key rotation schedule. | Phase 30 |
| **4. Third-Party Dependency Vulnerabilities** | Outdated npm/flutter packages flagged in security advisories. | Continuous audit via `npm audit` and `flutter pub outdated`. Documented exceptions for non-breaking API locks. | Automated Dependabot CI scanning with regression test coverage. | Phase 27 |
