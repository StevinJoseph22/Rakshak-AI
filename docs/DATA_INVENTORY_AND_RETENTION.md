# Rakshak-AI: Data Inventory & Retention Schedule

**Framework Standard**: Digital Personal Data Protection (DPDP) Act, 2023 (Section 7(f) & Section 12)  
**Classification**: Sensitive Personal Data (SPD), Personal Identifiable Information (PII), Telemetry, Audit Logs  
**System Version**: Phase 26 Hardened Production Architecture  
**Last Updated**: October 2026  

---

## 1. Executive Summary

Rakshak-AI operates on a strict **Zero-Storage Privacy Architecture** for transient emergency data and medical records. Personal health information, emergency contacts, scene photographs, and driving telemetry are either stored exclusively in volatile memory (RAM) with hard time-to-live (TTL) auto-purge verifiers, or retained locally on the user's mobile device. No medical records or crash scene photos ever persist to permanent relational or disk storage.

---

## 2. Comprehensive Data Inventory & Retention Schedule

| Data Category | Data Elements | Source | Primary Storage Location | Encryption at Rest | Encryption in Transit | Retention Period / TTL | Disposal Mechanism | Legal Basis |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Crash Scene Photos** | Base64 JPEG/PNG incident imagery | Citizen Mobile App | Redis Volatile RAM (`incident_image:{id}`) | **AES-256-GCM** (Per-incident HKDF-derived key) | TLS 1.3 / WSS (HTTPS) | **15 minutes** (900 seconds) | Automatic Redis key expiry + Background RAM Purge Verification Job | DPDP Act Sec 7(f) (Medical Emergency) |
| **Emergency Health Cards (ABHA)** | Blood group, allergies, emergency conditions, emergency contacts | Citizen ABHA Vault / ABDM Sandbox | Redis Volatile RAM (`health_card:{id}`) | Application-layer envelope encryption | TLS 1.3 / WSS (HTTPS) | **2 hours** (7,200 seconds) | Automatic Redis TTL expiration + Background Purge Verification | DPDP Act Sec 7(f); ABDM Consent Architecture |
| **Ambulance Live GPS Telemetry** | Lat, Lng, speed_kmh, heading, timestamp | Ambulance Pilot Mobile App | Redis Volatile RAM (`ambulance_loc:{id}`) | RAM only (ephemeral) | TLS 1.3 / WSS (HTTPS) | **10 minutes** (600 seconds) | Redis TTL auto-purge upon arrival | Motor Vehicles Act / Emergency Response |
| **Incident Core Record** | Incident UUID, PostGIS Point (Lat/Lng), Status, Accepted Hospital ID | Mobile app / Triage Engine | PostgreSQL Database (`incidents`) | Host filesystem LUKS / Cloud Storage KMS | TLS 1.3 / HTTPS | **90 days** (Statutory incident review) | Soft deletion / Scheduled archiving partition purge | MVA Sec 134A / Traffic Police Mandate |
| **Hospital Rejection Logs** | Incident UUID, Hospital ID, Reason (e.g. ICU Full), Timestamp | Hospital Dashboard | PostgreSQL Database (`incident_rejections`) | Host filesystem LUKS / KMS | TLS 1.3 / HTTPS | **90 days** | Automated audit rotation | Health Department QA & Capacity Planning |
| **Cryptographic Audit Log** | Action, Actor ID, Actor Role, Hash-Chain SHA-256, Previous Hash | Backend Audit Service | PostgreSQL Database (`system_audit_log`) | Append-Only Table, Revoked DELETE/UPDATE | TLS 1.3 / HTTPS | **365 days** (Permanent verification chain) | Never updated or deleted; chain broken if tampered | ISO 27001 / DPDP Accountability |
| **Staff & Police Credentials** | Username, Bcrypt Password Hash ($2a$12), Role, Hospital ID | Admin Seeding / Database | PostgreSQL Database (`users`) | Bcrypt salted hash (cost factor 12) | TLS 1.3 / HTTPS | Until user termination | Account deletion via `DELETE /auth/me/data` | DPDP Sec 12 (Right to Erasure) |
| **Citizen Stored Profile** | Rider name, contact phone, vehicle model, plate, blood group | Citizen Device | Local On-Device `SharedPreferences` | Android Keystore / iOS Keychain sandbox | Encrypted in transit | Persistent until user erases | In-app "Delete My Stored Data" button (`UserProfileService.clearProfile`) | DPDP Sec 12 |
| **Emergency Contacts** | Contact name, phone, relationship, primary flag | Citizen Device | Local On-Device `SharedPreferences` | Sandboxed app private storage | Encrypted in transit | Persistent until user erases | In-app "Delete My Stored Data" or contacts screen removal | DPDP Sec 7(f) & Sec 12 |
| **Trip Sentinel Heartbeat** | Speed (km/h), timestamp, anonymized session ID | Citizen Device | Redis Volatile RAM (`trip_heartbeat:{id}`) | RAM only | TLS 1.3 / WSS | **3 minutes** during active highway trip | Immediate eviction upon trip termination | DPDP Sec 7(f) Explicit User Consent |

---

## 3. Right to Erasure (DPDP Act Section 12) Workflow

1. **Citizen In-App Self-Service Erasure**:
   - The Citizen Settings screen features a prominent, dedicated section: **"DATA PRIVACY & RIGHT TO ERASURE (DPDP ACT)"**.
   - Tapping **"DELETE MY STORED DATA"** triggers an explicit confirmation modal detailing affected elements.
   - Upon user approval:
     1. `EmergencyContactService.instance.saveContacts([])` permanently clears all local contact records.
     2. `UserProfileService.instance.clearProfile()` wipes vehicle registration, rider phone, and blood group.
     3. An asynchronous request is dispatched to `/auth/citizen/delete-my-data` to purge any transient server sessions or telemetry nonces.

2. **Authenticated Staff/Police Erasure**:
   - Any authenticated user may execute `DELETE /auth/me/data`.
   - The API verifies session ownership, purges their user record from PostgreSQL, invalidates active JWT refresh tokens, and emits a verified audit event.

---

## 4. Log Redaction & PII Masking Policy

To eliminate accidental PII leakage across centralized observability tools, application loggers enforce real-time masking:
- **Phone Numbers**: Masked to country prefix and terminal 3 digits (e.g. `+91 98450 12345` -> `+91 ******345`).
- **Victim & Driver Names**: Replaced with initial and asterisks (e.g. `Ramesh Kumar` -> `R***** K****`).
- **Health Diagnostic Telemetry**: Excluded entirely from server console logs.
