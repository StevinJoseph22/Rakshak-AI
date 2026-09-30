import React from 'react';
import { NavLink } from 'react-router-dom';
import { ShieldAlert, Hospital, Activity, Radio, Wifi, WifiOff } from 'lucide-react';
import { ConnectionStatus } from '../types';

interface NavbarProps {
  status: ConnectionStatus;
  demoMode?: boolean;
  onToggleDemoMode?: () => void;
}

export const Navbar: React.FC<NavbarProps> = ({ status, demoMode = false, onToggleDemoMode }) => {
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
        </nav>

        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
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
  </header>
  );
};
