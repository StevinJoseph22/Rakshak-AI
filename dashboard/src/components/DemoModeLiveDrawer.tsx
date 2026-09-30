import React, { useEffect, useState, useRef } from 'react';
import { Terminal, X, Trash2, ChevronDown, ChevronUp } from 'lucide-react';
import { getSocket } from '../services/socket';

interface SocketEventLog {
  id: string;
  time: string;
  event: string;
  badgeColor: string;
  summary: string;
  details?: unknown;
}

interface DemoModeLiveDrawerProps {
  isOpen: boolean;
  onClose: () => void;
}

export const DemoModeLiveDrawer: React.FC<DemoModeLiveDrawerProps> = ({ isOpen, onClose }) => {
  const [logs, setLogs] = useState<SocketEventLog[]>([]);
  const [isMinimized, setIsMinimized] = useState(false);
  const logContainerRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const socket = getSocket();

    const addLog = (event: string, badgeColor: string, summary: string, details?: unknown) => {
      const now = new Date();
      const timeStr = now.toTimeString().split(' ')[0] + '.' + String(now.getMilliseconds()).padStart(3, '0');
      const logEntry: SocketEventLog = {
        id: `${Date.now()}-${Math.random()}`,
        time: timeStr,
        event,
        badgeColor,
        summary,
        details,
      };
      setLogs((prev) => [logEntry, ...prev.slice(0, 49)]); // keep last 50 events
    };

    const handleNewIncident = (data: Record<string, unknown>) => {
      const id = data?.id ? String(data.id).substring(0, 8) : 'unknown';
      addLog('new_incident', '#f59e0b', `Crash broadcast: #${id} matched ${(data?.matched_hospitals_count as number) ?? 0} trauma facilities`);
    };

    const handleImageUpdate = (data: Record<string, unknown>) => {
      const id = data?.incident_id ? String(data.incident_id).substring(0, 8) : 'unknown';
      addLog('image_update', '#38bdf8', `Zero-Gallery image streamed for #${id} (RAM TTL 900s)`);
    };

    const handleCaseAccepted = (data: Record<string, unknown>) => {
      const hospObj = data?.hospital as Record<string, unknown> | undefined;
      const hosp = (hospObj?.name as string) ?? (data?.hospital_name as string) ?? 'Facility';
      addLog('case_accepted', '#10b981', `Trauma bay locked: ${hosp} accepted emergency`);
    };

    const handleCaseLocked = (data: Record<string, unknown>) => {
      const hosp = (data?.accepted_hospital_name as string) ?? 'Trauma Center';
      addLog('case_locked', '#059669', `Triage room sealed: ${hosp}`);
    };

    const handleEscalated = (data: Record<string, unknown>) => {
      const id = data?.incident_id ? String(data.incident_id).substring(0, 8) : 'unknown';
      addLog('incident_escalated', '#ea580c', `Triage perimeter expanded to 20km for #${id}`);
    };

    const handleHospitalRejected = (data: Record<string, unknown>) => {
      const hosp = (data?.hospital_name as string) ?? 'Hospital';
      const reason = (data?.reason as string) ?? 'Facility unavailable';
      addLog('hospital_rejected', '#ef4444', `Rejection: ${hosp} declined (${reason})`);
    };

    const handleClaimed = (data: Record<string, unknown>) => {
      const amb = (data?.ambulance_id as string) ?? 'Ambulance';
      addLog('incident_claimed', '#6366f1', `Ambulance ${amb} claimed crash site response`);
    };

    const handleAmbulanceLoc = (data: Record<string, unknown>) => {
      const amb = (data?.ambulance_id as string) ?? 'Unit';
      const lat = typeof data?.latitude === 'number' ? data.latitude.toFixed(4) : '?';
      const lng = typeof data?.longitude === 'number' ? data.longitude.toFixed(4) : '?';
      addLog('ambulance_location', '#0284c7', `${amb} GPS beacon: (${lat}, ${lng})`);
    };

    socket.on('new_incident', handleNewIncident);
    socket.on('image_update', handleImageUpdate);
    socket.on('case_accepted', handleCaseAccepted);
    socket.on('case_locked', handleCaseLocked);
    socket.on('incident_escalated', handleEscalated);
    socket.on('hospital_rejected', handleHospitalRejected);
    socket.on('incident_rejected_by_hospital', handleHospitalRejected);
    socket.on('incident_claimed', handleClaimed);
    socket.on('ambulance_location_update', handleAmbulanceLoc);

    return () => {
      socket.off('new_incident', handleNewIncident);
      socket.off('image_update', handleImageUpdate);
      socket.off('case_accepted', handleCaseAccepted);
      socket.off('case_locked', handleCaseLocked);
      socket.off('incident_escalated', handleEscalated);
      socket.off('hospital_rejected', handleHospitalRejected);
      socket.off('incident_rejected_by_hospital', handleHospitalRejected);
      socket.off('incident_claimed', handleClaimed);
      socket.off('ambulance_location_update', handleAmbulanceLoc);
    };
  }, []);

  if (!isOpen) return null;

  return (
    <div
      style={{
        position: 'fixed',
        bottom: '16px',
        right: '16px',
        width: '420px',
        maxWidth: 'calc(100vw - 32px)',
        zIndex: 9999,
        background: 'rgba(15, 23, 42, 0.95)',
        backdropFilter: 'blur(12px)',
        borderRadius: '0.75rem',
        border: '1px solid rgba(255, 255, 255, 0.15)',
        boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.5), 0 8px 10px -6px rgba(0, 0, 0, 0.5)',
        color: '#f8fafc',
        fontFamily: 'monospace',
        overflow: 'hidden',
        transition: 'all 0.2s ease',
      }}
    >
      {/* Header */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '8px 12px',
          background: 'rgba(30, 41, 59, 0.9)',
          borderBottom: '1px solid rgba(255, 255, 255, 0.1)',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <Terminal size={16} color="#38bdf8" />
          <span style={{ fontSize: '12px', fontWeight: 800, letterSpacing: '0.05em', color: '#38bdf8' }}>
            DEMO MODE: REAL-TIME TELEMETRY FEED
          </span>
          <span
            style={{
              fontSize: '10px',
              padding: '1px 5px',
              borderRadius: '4px',
              background: '#047857',
              color: '#a7f3d0',
              fontWeight: 700,
            }}
          >
            LIVE
          </span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          <button
            onClick={() => setLogs([])}
            title="Clear Logs"
            style={{
              background: 'transparent',
              border: 'none',
              color: '#94a3b8',
              cursor: 'pointer',
              padding: '2px',
            }}
          >
            <Trash2 size={14} />
          </button>
          <button
            onClick={() => setIsMinimized(!isMinimized)}
            style={{
              background: 'transparent',
              border: 'none',
              color: '#94a3b8',
              cursor: 'pointer',
              padding: '2px',
            }}
          >
            {isMinimized ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
          </button>
          <button
            onClick={onClose}
            style={{
              background: 'transparent',
              border: 'none',
              color: '#94a3b8',
              cursor: 'pointer',
              padding: '2px',
            }}
          >
            <X size={16} />
          </button>
        </div>
      </div>

      {/* Log Feed */}
      {!isMinimized && (
        <div
          ref={logContainerRef}
          style={{
            maxHeight: '260px',
            overflowY: 'auto',
            padding: '8px 10px',
            display: 'flex',
            flexDirection: 'column',
            gap: '6px',
            fontSize: '11px',
          }}
        >
          {logs.length === 0 ? (
            <div style={{ color: '#64748b', fontStyle: 'italic', padding: '12px 0', textAlign: 'center' }}>
              Awaiting live WebSocket telemetry events from mobile app / backend...
            </div>
          ) : (
            logs.map((log) => (
              <div
                key={log.id}
                style={{
                  display: 'flex',
                  alignItems: 'flex-start',
                  gap: '8px',
                  padding: '4px 6px',
                  borderRadius: '4px',
                  background: 'rgba(30, 41, 59, 0.4)',
                  borderLeft: `3px solid ${log.badgeColor}`,
                }}
              >
                <span style={{ color: '#64748b', fontSize: '9.5px', whiteSpace: 'nowrap', marginTop: '2px' }}>
                  {log.time}
                </span>
                <div style={{ flex: 1 }}>
                  <span
                    style={{
                      fontSize: '9.5px',
                      fontWeight: 700,
                      color: log.badgeColor,
                      marginRight: '6px',
                    }}
                  >
                    [{log.event}]
                  </span>
                  <span style={{ color: '#e2e8f0', wordBreak: 'break-word' }}>
                    {log.summary}
                  </span>
                </div>
              </div>
            ))
          )}
        </div>
      )}
    </div>
  );
};
