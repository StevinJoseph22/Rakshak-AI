# Rakshak-AI: Security Audit & Vulnerability Assessment Report

**Audit Date**: October 2026  
**Auditor**: Rakshak-AI Automated Security Hardening Pipeline (Phase 26)  
**Scope**: Backend API (`backend/`), Web Dashboard (`dashboard/`), Citizen & Pilot Mobile Apps (`mobile/`)  
**Status**: Completed  

---

## 1. Secrets Management & Codebase Scan

- **Git & Source Scan Status**: PASSED (0 hardcoded secrets or unhashed passwords found).
- **Environment Isolation**:
  - All secret keys (`JWT_SECRET`, `JWT_REFRESH_SECRET`, `PHOTO_ENCRYPTION_SECRET`, `DEVICE_HMAC_SECRET`) reside exclusively in `.env` (gitignored).
  - Sanitized template maintained in `backend/.env.example`.
- **Release Build Hardening**:
  - Default demo credentials in `dashboard/src/components/LoginView.tsx` are dynamically stripped in production release builds via `import.meta.env.PROD ? [] : DEMO_PRESETS`.
  - Mobile client (`mobile/lib/`) contains zero hardcoded API keys or master passwords; runtime URLs are configured dynamically or via secure preferences.

---

## 2. Dependency Vulnerability Analysis (`npm audit`)

### 2.1 Backend (`backend/package.json`)

| Package | Severity | Advisory / CVE | Resolution / Mitigation | Status |
| :--- | :--- | :--- | :--- | :--- |
| `body-parser` | High | GHSA-27r3-jxmh-p828 (DoS via trailing bytes) | Upgraded to patched release via `npm audit fix`. | **RESOLVED** |
| `zod` (< 4.6.6) | High | GHSA-mrhx-c7xc-m3w5 (Memory exhaustion on unbounded arrays) | Zod v4 contains major breaking schema changes. **Mitigation implemented**: Express JSON payload cap strictly set to 10MB; Zod array schemas bounded with `.max(50)` and `.min(1)` limits; custom abuse prevention middleware caps image uploads to 5MB. | **MITIGATED & DOCUMENTED** |

### 2.2 Dashboard (`dashboard/package.json`)

| Package | Severity | Advisory / CVE | Resolution / Mitigation | Status |
| :--- | :--- | :--- | :--- | :--- |
| `source-map-js` | High | GHSA-68fv-2mgg-jv7q (Event-loop DoS via indexed source-map offsets) | Upgraded to patched release via `npm audit fix`. | **RESOLVED** |
| `esbuild` / `vite` | Moderate | GHSA-67mh-4wv8-2f99 (Dev server cross-origin request handling) | Development-only advisory affecting local dev server when exposed to malicious websites. **Mitigation implemented**: Strict CORS origin allowlist configured; production builds compile to static assets served behind HTTPS/Caddy/Nginx; dev server binds exclusively to localhost. | **MITIGATED & DOCUMENTED** |

---

## 3. Mobile Dependency Health (`flutter pub outdated`)

- **Analysis Summary**: 30 upgradable packages identified in lockfile; 0 known critical security CVEs reported for direct dependencies.
- **Direct Dependencies Status**:
  - `geolocator`: 14.0.3 (upgradable to 14.1.2 - non-breaking)
  - `sensors_plus`: 7.1.0 (upgradable to 7.1.1 - non-breaking)
  - `shared_preferences`: 2.5.5 (upgradable to 2.5.6 - non-breaking)
  - `flutter_webrtc`: 1.6.2+hotfix.3 (upgradable to 1.6.3 - non-breaking)
- **Recommendation**: Upgrades locked to stable versions to guarantee deterministic background sensor execution across real physical test devices. Scheduled for major bump in Phase 27.

---

## 4. Cryptographic & Application Layer Hardening Verification

1. **In-Flight Transport Security**:
   - Backend configured with TLS 1.3 / HTTPS and WSS via `ensureDevCertificates()` / `getTlsCredentials()`.
   - Strict Helmet headers: CSP directives restricting scripts, styles, and connect sources; HSTS with `max-age=31536000` and subdomains included.
2. **At-Rest Photo Encryption**:
   - Redis RAM incident photo storage upgraded to AES-256-GCM.
   - HKDF-SHA256 key isolation per incident; random 96-bit IV per photo; 900-second auto-purge verified.
3. **Authentication & Session Security**:
   - Access tokens shortened to 15 minutes; refresh tokens (7 days) require token rotation.
   - Brute-force protection: 5 consecutive failed logins triggers a 15-minute account lockout (HTTP 429).
4. **Abuse & Replay Prevention**:
   - HMAC payload signature verification with 5-minute timestamp clock-skew check.
   - Nonce replay protection with 10-minute cache preventing duplicate dispatch injection.
   - Device rate limiting: max 5 incident alerts per minute per device.
5. **Privacy & DPDP Compliance**:
   - Centralized PII masking (`maskPhoneNumber`, `maskName`) in application logging.
   - Dedicated "Delete My Stored Data" self-service erasure button in citizen app.
   - Explicit consent modals for emergency contacts and Trip Sentinel journey monitoring.
