# Rakshak-AI (रक्षक-AI)

> **Autonomous Emergency Crash Detection, Intelligent Dispatch & Hospital Triage System**

Rakshak-AI is an end-to-end emergency response platform that detects vehicular accidents in real time via smartphone telemetry, autonomously triages victims to optimal trauma care centers using spatial-AI reasoning, and coordinates emergency response teams through real-time dashboards.

---

## 🏛 Architecture & Port Allocation

All local services run on non-conflicting dedicated ports:

| Service | Directory | Tech Stack | Port | Local URL |
| :--- | :--- | :--- | :--- | :--- |
| **PostgreSQL + PostGIS** | `/db` | Docker (`postgis/postgis:16-3.4`) | `5432` | `localhost:5432` |
| **Redis** | - | Docker (`redis:7-alpine`) | `6379` | `localhost:6379` |
| **Backend API** | `/backend` | Node.js + Express (TypeScript) | `5000` | `http://localhost:5000` |
| **Triage Service** | `/triage-service` | Python FastAPI + Uvicorn | `8000` | `http://localhost:8000` |
| **Dashboard** | `/dashboard` | React + Vite + TypeScript | `5173` | `http://localhost:5173` |
| **Mobile App** | `/mobile` | Flutter (iOS & Android) | Emulator | Mobile Target |

---

## 📁 Monorepo Structure

```text
Rakshak-AI/
├── mobile/            # Flutter app for crash detection & SOS alerts
├── backend/           # Node.js + Express + TypeScript core API
├── triage-service/    # Python FastAPI for spatial matching & triage AI
├── dashboard/         # React + Vite (Police & Hospital dashboards)
├── db/                # PostgreSQL + PostGIS init scripts and schemas
├── docs/              # Architectural documentation and specifications
├── docker-compose.yml # PostgreSQL + PostGIS and Redis container setup
├── .env.example       # Global environment template
└── README.md          # Project guide and execution manual
```

---

## 🚀 Quickstart Guide

### Prerequisites
- [Docker & Docker Desktop](https://www.docker.com/)
- [Node.js](https://nodejs.org/) (v20+ recommended, tested with v24)
- [Python](https://www.python.org/) (v3.10+ recommended, tested with v3.14)
- [Flutter SDK](https://flutter.dev/) (for `/mobile`)

---

### Step 1: Start Databases (Postgres + PostGIS & Redis)
```bash
docker compose up -d
```
Verify containers are healthy:
```bash
docker compose ps
```

---

### Step 2: Run Backend API (Port 5000)
```bash
cd backend
npm install
npm run dev
```
Health Check: `http://localhost:5000/health`

---

### Step 3: Run Triage Service (Port 8000)
In a new terminal:
```bash
cd triage-service
python -m venv .venv

# On Windows PowerShell / Command Prompt:
.venv\Scripts\activate
# On macOS / Linux:
# source .venv/bin/activate

pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```
Health Check: `http://localhost:8000/health`  
Interactive Swagger Docs: `http://localhost:8000/docs`

---

### Step 4: Run Dashboard (Port 5173)
In a new terminal:
```bash
cd dashboard
npm install
npm run dev
```
Open in browser: `http://localhost:5173`

---

### Step 5: Mobile App (Flutter)
In a new terminal:
```bash
cd mobile
flutter pub get
flutter run
```

---

## 🛠 Code Quality & Linters
- **Backend & Dashboard**: ESLint + Prettier
  ```bash
  # backend
  cd backend && npm run lint && npm run format
  # dashboard
  cd dashboard && npm run lint && npm run format
  ```
- **Triage Service**: Ruff + Black
  ```bash
  cd triage-service
  ruff check .
  black --check .
  ```
