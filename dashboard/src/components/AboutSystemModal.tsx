import React from 'react';
import { ShieldCheck, AlertTriangle, Clock, X, Info } from 'lucide-react';

interface AboutSystemModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const AboutSystemModal: React.FC<AboutSystemModalProps> = ({ isOpen, onClose }) => {
  if (!isOpen) return null;

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        backgroundColor: 'rgba(15, 23, 42, 0.75)',
        backdropFilter: 'blur(4px)',
        zIndex: 9999,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '1rem',
      }}
      onClick={onClose}
    >
      <div
        style={{
          backgroundColor: '#ffffff',
          borderRadius: '1rem',
          maxWidth: '850px',
          width: '100%',
          maxHeight: '90vh',
          display: 'flex',
          flexDirection: 'column',
          boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
          overflow: 'hidden',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div
          style={{
            padding: '1.25rem 1.75rem',
            borderBottom: '1px solid #e2e8f0',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            background: '#f8fafc',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <div
              style={{
                backgroundColor: '#eff6ff',
                color: '#2563eb',
                padding: '0.5rem',
                borderRadius: '0.5rem',
                display: 'flex',
              }}
            >
              <Info size={22} />
            </div>
            <div>
              <h2 style={{ margin: 0, fontSize: '1.2rem', fontWeight: 800, color: '#0f172a' }}>
                About Rakshak-AI System Status & Claims Register
              </h2>
              <p style={{ margin: '0.2rem 0 0 0', fontSize: '0.8rem', color: '#64748b' }}>
                Audited capabilities, running mechanisms, simulated features, and production roadmap
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            style={{
              background: 'transparent',
              border: 'none',
              cursor: 'pointer',
              color: '#94a3b8',
              padding: '0.4rem',
              borderRadius: '0.375rem',
            }}
          >
            <X size={20} />
          </button>
        </div>

        {/* Content Tabs / Scrollable Body */}
        <div style={{ padding: '1.5rem 1.75rem', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
          {/* Section 1: Implemented */}
          <div style={{ border: '1px solid #bbf7d0', borderRadius: '0.75rem', padding: '1rem 1.25rem', background: '#f0fdf4' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.75rem' }}>
              <ShieldCheck size={20} color="#16a34a" />
              <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 700, color: '#166534' }}>
                1. Implemented (Backed by Live Code & Verification Tests)
              </h3>
            </div>
            <ul style={{ margin: 0, paddingLeft: '1.25rem', fontSize: '0.85rem', color: '#14532d', display: 'flex', flexDirection: 'column', gap: '0.4rem' }}>
              <li>
                <strong>Smartphone Sensor Crash Detection:</strong> Real-time accelerometer & gyroscope sampling with speed drop, jerk, and rollover detection (mobile/lib/services/sensor_service.dart).
              </li>
              <li>
                <strong>Geospatial 8km Hospital Dispatch:</strong> PostGIS spatial queries rank trauma centers and broadcast via Socket.IO (backend/src/routes/incidents.ts).
              </li>
              <li>
                <strong>Server-Persisted Hospital Capabilities:</strong> Real-time DB sync for 8 trauma capabilities, authorization scoping (403 for other hospitals), and non-blocking fallback matching.
              </li>
              <li>
                <strong>Cryptographic Hash-Chained Audit Trail:</strong> Append-only log with SHA-256 chain links, database engine anti-tamper trigger, and verify-chain validation (backend/src/services/auditService.ts).
              </li>
              <li>
                <strong>Scoped Break-Glass Access:</strong> Scoped exclusively to accepting hospital, 30-minute access window, mandatory doctor licence ID + justification, and hash audit logging.
              </li>
              <li>
                <strong>Native SIM Emergency SMS:</strong> Direct emergency SMS dispatch to up to 3 contacts using Android SmsManager via MethodChannel (mobile/lib/services/emergency_sms_service.dart).
              </li>
              <li>
                <strong>Zero-Loss Offline Store-and-Forward:</strong> SQLite incident persistence queue with exponential backoff retry (mobile/lib/services/offline_dispatch_queue.dart).
              </li>
            </ul>
          </div>

          {/* Section 2: Simulated */}
          <div style={{ border: '1px solid #fed7aa', borderRadius: '0.75rem', padding: '1rem 1.25rem', background: '#fff7ed' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.75rem' }}>
              <AlertTriangle size={20} color="#ea580c" />
              <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 700, color: '#9a3412' }}>
                2. Simulated (Mocked / Demo Flow Components)
              </h3>
            </div>
            <ul style={{ margin: 0, paddingLeft: '1.25rem', fontSize: '0.85rem', color: '#7c2d12', display: 'flex', flexDirection: 'column', gap: '0.4rem' }}>
              <li>
                <strong>C-V2X Green Corridor Signal Preemption:</strong> Traffic signal override and countdown timer are simulated via Socket.IO events for police and ambulance pilots (no physical intersection controller connected).
              </li>
              <li>
                <strong>Cloud Server Crash & Watchdog Heartbeat:</strong> Cloud watchdog expiration simulation for testing citizen fail-safe countdowns.
              </li>
              <li>
                <strong>Phone Breakdown / Battery Rip:</strong> Instant app kill and state persistence test simulation.
              </li>
              <li>
                <strong>Central Telecom Carrier Gateway:</strong> Simulated central carrier shortcode (+91-800-RAKSHAK); native SIM dispatches directly to personal emergency contacts.
              </li>
              <li>
                <strong>Simulate CT Scan Down:</strong> Facility toggle in Hospital Dashboard to demonstrate non-blocking trauma advisory and ranking fallbacks.
              </li>
              <li>
                <strong>ABHA Emergency Health Card (Mock Mode):</strong> ABDM sandbox/mock schema profile generation for emergency clinical card demonstration.
              </li>
            </ul>
          </div>

          {/* Section 3: Roadmap */}
          <div style={{ border: '1px solid #cbd5e1', borderRadius: '0.75rem', padding: '1rem 1.25rem', background: '#f8fafc' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.75rem' }}>
              <Clock size={20} color="#475569" />
              <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 700, color: '#334155' }}>
                3. Roadmap (Physical Infrastructure & Production Authorizations)
              </h3>
            </div>
            <ul style={{ margin: 0, paddingLeft: '1.25rem', fontSize: '0.85rem', color: '#475569', display: 'flex', flexDirection: 'column', gap: '0.4rem' }}>
              <li>
                <strong>Physical C-V2X RSU Controllers:</strong> Direct integration with NTCIP 1211 signal controllers and 5.9 GHz PC5 roadside units via city traffic police ITMS.
              </li>
              <li>
                <strong>Production ABDM Bridge Authorization:</strong> Production NHA client credentials and cryptographic token issuance.
              </li>
              <li>
                <strong>Telecom Inbound DLT Aggregator:</strong> Registered carrier shortcode with TRAI DLT approved emergency scrubbers for inbound SMS parsing.
              </li>
              <li>
                <strong>Vehicle CAN-Bus / OBD-II Hardware:</strong> Hardware in-cabin dongle for native airbag deployment pulse and direct vehicle sensor telemetry.
              </li>
            </ul>
          </div>
        </div>

        {/* Footer */}
        <div
          style={{
            padding: '1rem 1.75rem',
            borderTop: '1px solid #e2e8f0',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            background: '#ffffff',
          }}
        >
          <span style={{ fontSize: '0.75rem', color: '#94a3b8' }}>
            Audited for Phase 25 &bull; See docs/CLAIMS_REGISTER.md for file & test references
          </span>
          <button
            onClick={onClose}
            style={{
              padding: '0.5rem 1.25rem',
              backgroundColor: '#0f172a',
              color: '#ffffff',
              border: 'none',
              borderRadius: '0.5rem',
              fontSize: '0.85rem',
              fontWeight: 600,
              cursor: 'pointer',
            }}
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};
