import React, { useState, useEffect } from 'react';
import { NavLink } from 'react-router-dom';
import { ShieldAlert, Hospital, Activity, Radio, Wifi, WifiOff, Settings, Info, Gauge } from 'lucide-react';
import { AboutSystemModal } from './AboutSystemModal';
import { ConnectionStatus } from '../types';
import { BACKEND_API_BASE } from '../services/socket';

interface NavbarProps {
  status: ConnectionStatus;
  demoMode?: boolean;
  onToggleDemoMode?: () => void;
}

export const Navbar: React.FC<NavbarProps> = ({ status, demoMode = false, onToggleDemoMode }) => {
  const [abdmMode, setAbdmMode] = useState<'SANDBOX' | 'MOCK'>('MOCK');
  const [isAboutModalOpen, setIsAboutModalOpen] = useState<boolean>(false);

  useEffect(() => {
    let isMounted = true;
    const fetchAbdmStatus = async () => {
      try {
        const res = await fetch(`${BACKEND_API_BASE}/abha/status`);
        if (res.ok) {
          const data = await res.json();
          if (isMounted && data.mode) {
            setAbdmMode(data.mode.toUpperCase() === 'SANDBOX' ? 'SANDBOX' : 'MOCK');
          }
        }
      } catch (err) {
        // Fallback default is MOCK
      }
    };

    fetchAbdmStatus();
    const interval = setInterval(fetchAbdmStatus, 30000);
    return () => {
      isMounted = false;
      clearInterval(interval);
    };
  }, []);
  return (
    <header
      style={{
        background: '#ffffff',
        borderBottom: '1px solid #e2e8f0',
        padding: '0.875rem 2rem',
        boxShadow: '0 1px 3px rgba(0,0,0,0.04)',
      }}
    >
      <div
        style={{
          maxWidth: '1280px',
          margin: '0 auto',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          flexWrap: 'wrap',
          gap: '1rem',
        }}
      >
        {/* Brand / Logo */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          <div
            style={{
              background: '#fee2e2',
              color: '#dc2626',
              padding: '0.5rem',
              borderRadius: '0.5rem',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <ShieldAlert size={28} />
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <h1
                style={{
                  margin: 0,
                  fontSize: '1.25rem',
                  fontWeight: 800,
                  letterSpacing: '-0.025em',
                  color: '#0f172a',
                }}
              >
                Rakshak-AI
              </h1>
              <span
                style={{
                  background: '#f1f5f9',
                  color: '#475569',
                  fontSize: '0.7rem',
                  padding: '0.15rem 0.45rem',
                  borderRadius: '9999px',
                  fontWeight: 600,
                }}
              >
                Phase 5 Triage
              </span>
            </div>
            <p
              style={{
                margin: 0,
                color: '#64748b',
                fontSize: '0.785rem',
              }}
            >
              Real-time Geospatial Emergency Dispatch & Trauma Network
            </p>
          </div>
        </div>

        {/* Navigation Tabs */}
        <nav style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <NavLink
            to="/hospital"
            style={({ isActive }) => ({
              display: 'flex',
              alignItems: 'center',
              gap: '0.45rem',
              padding: '0.5rem 1rem',
              borderRadius: '0.375rem',
              textDecoration: 'none',
              fontSize: '0.875rem',
              fontWeight: 600,
              background: isActive ? '#f0fdf4' : 'transparent',
              color: isActive ? '#15803d' : '#64748b',
              border: isActive ? '1px solid #bbf7d0' : '1px solid transparent',
              transition: 'all 0.15s ease',
            })}
          >
            <Hospital size={18} />
            <span>Hospital ER Console</span>
          </NavLink>

          <NavLink
            to="/police"
            style={({ isActive }) => ({
              display: 'flex',
              alignItems: 'center',
              gap: '0.45rem',
              padding: '0.5rem 1rem',
              borderRadius: '0.375rem',
              textDecoration: 'none',
              fontSize: '0.875rem',
              fontWeight: 600,
              background: isActive ? '#eff6ff' : 'transparent',
              color: isActive ? '#1d4ed8' : '#64748b',
              border: isActive ? '1px solid #bfdbfe' : '1px solid transparent',
              transition: 'all 0.15s ease',
            })}
          >
            <Activity size={18} />
            <span>Police Control Room</span>
          </NavLink>

          <NavLink
            to="/telemetry"
            style={({ isActive }) => ({
              display: 'flex',
              alignItems: 'center',
              gap: '0.45rem',
              padding: '0.5rem 1rem',
              borderRadius: '0.375rem',
              textDecoration: 'none',
              fontSize: '0.875rem',
              fontWeight: 600,
              background: isActive ? '#f0f9ff' : 'transparent',
              color: isActive ? '#0284c7' : '#64748b',
              border: isActive ? '1px solid #bae6fd' : '1px solid transparent',
              transition: 'all 0.15s ease',
            })}
          >
            <Gauge size={18} />
            <span>⚡ Live Telemetry</span>
          </NavLink>

          <NavLink
            to="/admin"
            style={({ isActive }) => ({
              display: 'flex',
              alignItems: 'center',
              gap: '0.45rem',
              padding: '0.5rem 1rem',
              borderRadius: '0.375rem',
              textDecoration: 'none',
              fontSize: '0.875rem',
              fontWeight: 600,
              background: isActive ? '#fef2f2' : 'transparent',
              color: isActive ? '#dc2626' : '#64748b',
              border: isActive ? '1px solid #fecaca' : '1px solid transparent',
              transition: 'all 0.15s ease',
            })}
          >
            <Settings size={18} />
            <span>Admin Reset Lab</span>
          </NavLink>
        </nav>

        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          <button
            onClick={() => setIsAboutModalOpen(true)}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.4rem',
              padding: '0.35rem 0.75rem',
              borderRadius: '0.375rem',
              border: '1px solid #cbd5e1',
              background: '#ffffff',
              color: '#334155',
              fontSize: '0.75rem',
              fontWeight: 700,
              cursor: 'pointer',
              transition: 'all 0.15s ease',
            }}
            title="View System Status, Implemented vs Simulated capabilities, and Claims Register"
          >
            <Info size={14} color="#2563eb" />
            <span>About System</span>
          </button>
          {onToggleDemoMode && (
            <button
              onClick={onToggleDemoMode}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.4rem',
                padding: '0.35rem 0.75rem',
                borderRadius: '0.375rem',
                border: demoMode ? '1px solid #38bdf8' : '1px solid #cbd5e1',
                background: demoMode ? '#0f172a' : '#ffffff',
                color: demoMode ? '#38bdf8' : '#64748b',
                fontSize: '0.75rem',
                fontWeight: 700,
                cursor: 'pointer',
                transition: 'all 0.15s ease',
              }}
              title="Toggle Live Real-Time Telemetry Feed"
            >
              <span>⚡ Live Telemetry:</span>
              <span
                style={{
                  color: demoMode ? '#10b981' : '#94a3b8',
                  textTransform: 'uppercase',
                }}
              >
                {demoMode ? 'ON' : 'OFF'}
              </span>
            </button>
          )}

          {/* ABDM Active Adapter Mode Pill */}
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.45rem',
              padding: '0.35rem 0.85rem',
              borderRadius: '9999px',
              fontSize: '0.775rem',
              fontWeight: 700,
              background: abdmMode === 'SANDBOX' ? '#ecfdf5' : '#fffbeb',
              color: abdmMode === 'SANDBOX' ? '#047857' : '#b45309',
              border: `1px solid ${abdmMode === 'SANDBOX' ? '#a7f3d0' : '#fde68a'}`,
              letterSpacing: '0.02em',
            }}
            title={`ABDM Integration Mode: ${abdmMode} (National Health Authority)`}
          >
            <span
              style={{
                width: '7px',
                height: '7px',
                borderRadius: '50%',
                backgroundColor: abdmMode === 'SANDBOX' ? '#10b981' : '#f59e0b',
                display: 'inline-block',
              }}
            />
            <span>ABDM: {abdmMode}</span>
          </div>

          {/* Global Connection Status Pill */}
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.5rem',
              padding: '0.35rem 0.85rem',
            borderRadius: '9999px',
            fontSize: '0.775rem',
            fontWeight: 600,
            background:
              status === 'connected'
                ? '#ecfdf5'
                : status === 'reconnecting'
                  ? '#fffbeb'
                  : '#fef2f2',
            color:
              status === 'connected'
                ? '#059669'
                : status === 'reconnecting'
                  ? '#d97706'
                  : '#dc2626',
            border: `1px solid ${
              status === 'connected'
                ? '#a7f3d0'
                : status === 'reconnecting'
                  ? '#fde68a'
                  : '#fecaca'
            }`,
          }}
        >
          {status === 'connected' ? (
            <>
              <Radio size={14} />
              <span>WebSocket Connected</span>
            </>
          ) : status === 'reconnecting' ? (
            <>
              <Wifi size={14} />
              <span>Reconnecting...</span>
            </>
          ) : (
            <>
              <WifiOff size={14} />
              <span>Disconnected</span>
            </>
          )}
        </div>
      </div>
    </div>
    <AboutSystemModal isOpen={isAboutModalOpen} onClose={() => setIsAboutModalOpen(false)} />
  </header>
  );
};
