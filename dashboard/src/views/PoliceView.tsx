import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  ShieldAlert,
  Activity,
  Radio,
  Trash2,
  Volume2,
  VolumeX,
} from 'lucide-react';
import { IncidentPayload, ConnectionStatus } from '../types';
import { getSocket, BACKEND_API_BASE } from '../services/socket';
import { IncidentCard } from '../components/IncidentCard';
import { ReconnectingBanner } from '../components/ReconnectingBanner';

export const PoliceView: React.FC = () => {
  const [incidents, setIncidents] = useState<IncidentPayload[]>(() => {
    try {
      const saved = localStorage.getItem('rakshak_police_feed');
      return saved ? JSON.parse(saved) : [];
    } catch {
      return [];
    }
  });
  const [connectionStatus, setConnectionStatus] =
    useState<ConnectionStatus>('connected');
  const [soundEnabled, setSoundEnabled] = useState<boolean>(true);
  const [lastAlertFlash, setLastAlertFlash] = useState<boolean>(false);

  const audioContextRef = useRef<AudioContext | null>(null);

  const playPoliceChime = useCallback(() => {
    if (!soundEnabled) return;
    try {
      if (!audioContextRef.current) {
        const AudioCtx =
          window.AudioContext ||
          (window as unknown as { webkitAudioContext: typeof AudioContext })
            .webkitAudioContext;
        audioContextRef.current = new AudioCtx();
      }
      const ctx = audioContextRef.current;
      if (ctx.state === 'suspended') {
        ctx.resume();
      }
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = 'sawtooth';
      osc.frequency.setValueAtTime(600, ctx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(1200, ctx.currentTime + 0.2);

      gain.gain.setValueAtTime(0.2, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.4);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start();
      osc.stop(ctx.currentTime + 0.4);
    } catch {
      // Audio autoplay policy catch
    }
  }, [soundEnabled]);

  // Initial fetch of recent incidents from backend on mount
  useEffect(() => {
    let isMounted = true;
    const isCleared = localStorage.getItem('rakshak_police_cleared') === 'true';
    if (isCleared) {
      return;
    }

    fetch(`${BACKEND_API_BASE}/incidents?limit=20`)
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP error ${res.status}`);
        return res.json();
      })
      .then((data) => {
        if (!isMounted) return;
        if (data.incidents && Array.isArray(data.incidents)) {
          setIncidents((prev) => {
            const mergedMap = new Map<string, IncidentPayload>();
            data.incidents.forEach((inc: IncidentPayload) => {
              mergedMap.set(inc.id, inc);
            });
            prev.forEach((inc: IncidentPayload) => {
              const existing = mergedMap.get(inc.id);
              mergedMap.set(inc.id, existing ? { ...existing, ...inc } : inc);
            });
            const merged = Array.from(mergedMap.values()).sort(
              (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
            );
            try {
              localStorage.setItem('rakshak_police_feed', JSON.stringify(merged));
            } catch {
              // Ignore
            }
            return merged;
          });
        }
      })
      .catch((err) => {
        console.warn('[PoliceView] Failed to fetch incidents on mount:', err);
      });

    return () => {
      isMounted = false;
    };
  }, []);

  // Connect and join police "all_incidents" broadcast room
  useEffect(() => {
    const socket = getSocket();

    const handleConnect = () => {
      setConnectionStatus('connected');
      socket.emit('join_police');
    };

    const handleDisconnect = () => {
      setConnectionStatus('disconnected');
    };

    const handleReconnectAttempt = () => {
      setConnectionStatus('reconnecting');
    };

    const handleConnectError = () => {
      setConnectionStatus('reconnecting');
    };

    if (socket.connected) {
      setConnectionStatus('connected');
      socket.emit('join_police');
    } else {
      socket.connect();
    }

    const handleNewIncident = (payload: IncidentPayload) => {
      try {
        localStorage.removeItem('rakshak_police_cleared');
      } catch {
        // ignore
      }

      setIncidents((prev) => {
        const existingIndex = prev.findIndex((item) => item.id === payload.id);
        let updatedList: IncidentPayload[];
        if (existingIndex >= 0) {
          updatedList = [...prev];
          updatedList[existingIndex] = { ...updatedList[existingIndex], ...payload };
        } else {
          updatedList = [payload, ...prev];
        }
        try {
          localStorage.setItem('rakshak_police_feed', JSON.stringify(updatedList));
        } catch {
          // ignore
        }
        return updatedList;
      });

      setLastAlertFlash(true);
      setTimeout(() => setLastAlertFlash(false), 2000);
      playPoliceChime();
    };

    const handleFeedCleared = () => {
      setIncidents([]);
      try {
        localStorage.setItem('rakshak_police_feed', '[]');
        localStorage.setItem('rakshak_police_cleared', 'true');
      } catch {
        // ignore
      }
    };

    const handleImageUpdate = (payload: { incident_id: string; imageUrl: string }) => {
      setIncidents((prev) => {
        const existingIndex = prev.findIndex((item) => item.id === payload.incident_id);
        if (existingIndex === -1) return prev;
        const updatedList = [...prev];
        updatedList[existingIndex] = { ...updatedList[existingIndex], imageUrl: payload.imageUrl };
        try {
          localStorage.setItem('rakshak_police_feed', JSON.stringify(updatedList));
        } catch {
          // ignore
        }
        return updatedList;
      });
    };

    const handleCaseAccepted = (payload: {
      incident_id: string;
      status: string;
      hospital: { id: string; name: string };
    }) => {
      setIncidents((prev) => {
        const existingIndex = prev.findIndex((item) => item.id === payload.incident_id);
        if (existingIndex === -1) return prev;
        const updatedList = [...prev];
        updatedList[existingIndex] = {
          ...updatedList[existingIndex],
          status: 'accepted',
          accepted_hospital_id: payload.hospital.id,
          accepted_hospital_name: payload.hospital.name,
        };
        try {
          localStorage.setItem('rakshak_police_feed', JSON.stringify(updatedList));
        } catch {
          // ignore
        }
        return updatedList;
      });
    };

    const handleIncidentEscalated = (payload: {
      incident_id: string;
      status: string;
      search_radius?: string;
    }) => {
      setIncidents((prev) => {
        const existingIndex = prev.findIndex((item) => item.id === payload.incident_id);
        if (existingIndex === -1) return prev;
        const updatedList = [...prev];
        updatedList[existingIndex] = {
          ...updatedList[existingIndex],
          status: 'escalated',
          escalated: true,
        };
        try {
          localStorage.setItem('rakshak_police_feed', JSON.stringify(updatedList));
        } catch {
          // ignore
        }
        return updatedList;
      });
    };

    const handleIncidentUnmatched = (payload: {
      incident_id: string;
      status: string;
    }) => {
      setIncidents((prev) => {
        const existingIndex = prev.findIndex((item) => item.id === payload.incident_id);
        if (existingIndex === -1) return prev;
        const updatedList = [...prev];
        updatedList[existingIndex] = {
          ...updatedList[existingIndex],
          status: 'unmatched',
        };
        try {
          localStorage.setItem('rakshak_police_feed', JSON.stringify(updatedList));
        } catch {
          // ignore
        }
        return updatedList;
      });
    };

    const handleCaseLocked = (payload: {
      incident_id: string;
      accepted_hospital_id: string;
      accepted_hospital_name: string;
    }) => {
      setIncidents((prev) => {
        const existingIndex = prev.findIndex((item) => item.id === payload.incident_id);
        if (existingIndex === -1) return prev;
        const updatedList = [...prev];
        updatedList[existingIndex] = {
          ...updatedList[existingIndex],
          status: 'accepted',
          accepted_hospital_id: payload.accepted_hospital_id,
          accepted_hospital_name: payload.accepted_hospital_name,
        };
        try {
          localStorage.setItem('rakshak_police_feed', JSON.stringify(updatedList));
        } catch {
          // ignore
        }
        return updatedList;
      });
    };

    const handleHospitalRejected = (payload: {
      incident_id: string;
      hospital_id: string;
      hospital_name: string;
      reason: string;
      created_at?: string;
    }) => {
      setIncidents((prev) => {
        const existingIndex = prev.findIndex((item) => item.id === payload.incident_id);
        if (existingIndex === -1) return prev;
        const updatedList = [...prev];
        const target = updatedList[existingIndex];
        const currentRejections = target.rejections || [];
        const isAlreadyPresent = currentRejections.some(
          (r) => r.hospital_id === payload.hospital_id
        );
        const newRejections = isAlreadyPresent
          ? currentRejections.map((r) =>
              r.hospital_id === payload.hospital_id
                ? { ...r, reason: payload.reason, created_at: payload.created_at || new Date().toISOString() }
                : r
            )
          : [
              ...currentRejections,
              {
                hospital_id: payload.hospital_id,
                hospital_name: payload.hospital_name,
                reason: payload.reason,
                created_at: payload.created_at || new Date().toISOString(),
              },
            ];

        updatedList[existingIndex] = {
          ...target,
          rejections: newRejections,
        };
        try {
          localStorage.setItem('rakshak_police_feed', JSON.stringify(updatedList));
        } catch {
          // ignore
        }
        return updatedList;
      });
    };

    socket.on('connect', handleConnect);
    socket.on('disconnect', handleDisconnect);
    socket.on('connect_error', handleConnectError);
    socket.io.on('reconnect_attempt', handleReconnectAttempt);
    socket.on('new_incident', handleNewIncident);
    socket.on('feed_cleared', handleFeedCleared);
    socket.on('image_update', handleImageUpdate);
    socket.on('case_accepted', handleCaseAccepted);
    socket.on('incident_escalated', handleIncidentEscalated);
    socket.on('incident_unmatched', handleIncidentUnmatched);
    socket.on('case_locked', handleCaseLocked);
    socket.on('hospital_rejected', handleHospitalRejected);

    return () => {
      socket.off('connect', handleConnect);
      socket.off('disconnect', handleDisconnect);
      socket.off('connect_error', handleConnectError);
      socket.io.off('reconnect_attempt', handleReconnectAttempt);
      socket.off('new_incident', handleNewIncident);
      socket.off('feed_cleared', handleFeedCleared);
      socket.off('image_update', handleImageUpdate);
      socket.off('case_accepted', handleCaseAccepted);
      socket.off('incident_escalated', handleIncidentEscalated);
      socket.off('incident_unmatched', handleIncidentUnmatched);
      socket.off('case_locked', handleCaseLocked);
      socket.off('hospital_rejected', handleHospitalRejected);
    };
  }, [playPoliceChime]);

  const handleClearFeed = async () => {
    setIncidents([]);
    try {
      localStorage.setItem('rakshak_police_feed', '[]');
      localStorage.setItem('rakshak_police_cleared', 'true');
      // Purge test incidents from database so they do not resurrect
      await fetch(`${BACKEND_API_BASE}/incidents`, { method: 'DELETE' });
    } catch {
      // ignore
    }
  };

  const handleManualReconnect = () => {
    const socket = getSocket();
    setConnectionStatus('reconnecting');
    socket.connect();
    socket.emit('join_police');
  };

  return (
    <div style={{ maxWidth: '1280px', margin: '0 auto', padding: '1.5rem 1rem' }}>
      {/* Reconnecting banner if socket disconnects */}
      <ReconnectingBanner
        status={connectionStatus}
        onRetry={handleManualReconnect}
      />

      {/* Control Room Header */}
      <div
        style={{
          background: '#ffffff',
          borderRadius: '0.75rem',
          padding: '1.25rem 1.5rem',
          border: '1px solid #e2e8f0',
          boxShadow: '0 1px 3px rgba(0,0,0,0.05)',
          marginBottom: '1.5rem',
          display: 'flex',
          flexWrap: 'wrap',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: '1rem',
          borderColor: lastAlertFlash ? '#ef4444' : '#e2e8f0',
          transition: 'border-color 0.3s ease',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          <div
            style={{
              background: '#eff6ff',
              color: '#1d4ed8',
              padding: '0.65rem',
              borderRadius: '0.5rem',
            }}
          >
            <Activity size={26} />
          </div>
          <div>
            <h2
              style={{
                margin: 0,
                fontSize: '1.25rem',
                fontWeight: 800,
                color: '#0f172a',
              }}
            >
              City-Wide Police Control Room
            </h2>
            <p style={{ margin: 0, color: '#64748b', fontSize: '0.825rem' }}>
              Monitoring all collisions across Bengaluru jurisdiction in real
              time via <code>all_incidents</code> WebSocket broadcast.
            </p>
          </div>
        </div>

        {/* Action Controls */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          <button
            onClick={() => setSoundEnabled(!soundEnabled)}
            title={soundEnabled ? 'Mute alert siren' : 'Enable alert siren'}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.35rem',
              padding: '0.5rem 0.75rem',
              background: '#f1f5f9',
              border: '1px solid #e2e8f0',
              borderRadius: '0.375rem',
              color: soundEnabled ? '#0f172a' : '#94a3b8',
              cursor: 'pointer',
              fontSize: '0.8rem',
              fontWeight: 500,
            }}
          >
            {soundEnabled ? <Volume2 size={16} /> : <VolumeX size={16} />}
            <span>{soundEnabled ? 'Siren ON' : 'Muted'}</span>
          </button>

          {incidents.length > 0 && (
            <button
              onClick={handleClearFeed}
              title="Clear current view alerts"
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.35rem',
                padding: '0.5rem 0.75rem',
                background: '#fef2f2',
                border: '1px solid #fecaca',
                borderRadius: '0.375rem',
                color: '#dc2626',
                cursor: 'pointer',
                fontSize: '0.8rem',
                fontWeight: 500,
              }}
            >
              <Trash2 size={16} />
              <span>Clear Feed</span>
            </button>
          )}
        </div>
      </div>

      {/* Police Stats Overview */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
          gap: '1rem',
          marginBottom: '1.5rem',
        }}
      >
        <div
          style={{
            background: '#ffffff',
            borderRadius: '0.5rem',
            padding: '1rem',
            border: '1px solid #e2e8f0',
            boxShadow: '0 1px 2px rgba(0,0,0,0.04)',
          }}
        >
          <div style={{ color: '#64748b', fontSize: '0.75rem', fontWeight: 600 }}>
            CITY-WIDE ACTIVE ALERTS
          </div>
          <div
            style={{
              fontSize: '1.75rem',
              fontWeight: 800,
              color: incidents.length > 0 ? '#dc2626' : '#059669',
              marginTop: '0.25rem',
            }}
          >
            {incidents.length}
          </div>
        </div>

        <div
          style={{
            background: '#ffffff',
            borderRadius: '0.5rem',
            padding: '1rem',
            border: '1px solid #e2e8f0',
            boxShadow: '0 1px 2px rgba(0,0,0,0.04)',
          }}
        >
          <div style={{ color: '#64748b', fontSize: '0.75rem', fontWeight: 600 }}>
            BROADCAST CHANNEL
          </div>
          <div
            style={{
              fontSize: '1.1rem',
              fontWeight: 700,
              color: '#2563eb',
              marginTop: '0.35rem',
              display: 'flex',
              alignItems: 'center',
              gap: '0.35rem',
            }}
          >
            <Radio size={18} />
            <span>all_incidents</span>
          </div>
        </div>

        <div
          style={{
            background: '#ffffff',
            borderRadius: '0.5rem',
            padding: '1rem',
            border: '1px solid #e2e8f0',
            boxShadow: '0 1px 2px rgba(0,0,0,0.04)',
          }}
        >
          <div style={{ color: '#64748b', fontSize: '0.75rem', fontWeight: 600 }}>
            DISPATCH PROTOCOL
          </div>
          <div
            style={{
              fontSize: '1.1rem',
              fontWeight: 700,
              color: '#15803d',
              marginTop: '0.35rem',
            }}
          >
            PostGIS 8km Triage Ring
          </div>
        </div>
      </div>

      {/* Incidents Stream */}
      <div>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginBottom: '0.75rem',
          }}
        >
          <h3
            style={{
              margin: 0,
              fontSize: '1rem',
              fontWeight: 700,
              color: '#334155',
            }}
          >
            Live Emergency Incident Stream
          </h3>
          <span style={{ fontSize: '0.8rem', color: '#64748b' }}>
            Broadcasting 24/7 across Bengaluru Urban & Rural
          </span>
        </div>

        {incidents.length === 0 ? (
          <div
            style={{
              background: '#ffffff',
              borderRadius: '0.75rem',
              padding: '3rem 1.5rem',
              textAlign: 'center',
              border: '2px dashed #cbd5e1',
              color: '#64748b',
            }}
          >
            <ShieldAlert
              size={44}
              color="#3b82f6"
              style={{ margin: '0 auto 0.75rem' }}
            />
            <h4
              style={{
                margin: '0 0 0.35rem 0',
                fontSize: '1.1rem',
                color: '#0f172a',
              }}
            >
              No Active Emergencies in City Stream
            </h4>
            <p
              style={{
                margin: '0 auto',
                maxWidth: '480px',
                fontSize: '0.875rem',
              }}
            >
              Police Control Room is actively connected. When any mobile sensor
              detects a crash or an incident is created via the API, it will appear
              here in real time with matched hospital counts and coordinates.
            </p>
            <button
              onClick={() => {
                localStorage.removeItem('rakshak_police_cleared');
                fetch(`${BACKEND_API_BASE}/incidents?limit=20`)
                  .then((res) => res.json())
                  .then((data) => {
                    if (data.incidents && data.incidents.length > 0) {
                      setIncidents(data.incidents);
                      localStorage.setItem('rakshak_police_feed', JSON.stringify(data.incidents));
                    }
                  });
              }}
              style={{
                marginTop: '1rem',
                padding: '0.45rem 0.85rem',
                background: '#f8fafc',
                border: '1px solid #cbd5e1',
                borderRadius: '0.375rem',
                color: '#475569',
                fontSize: '0.8rem',
                fontWeight: 600,
                cursor: 'pointer',
              }}
            >
              Fetch Database Records
            </button>
          </div>
        ) : (
          <div>
            {incidents.map((incident) => (
              <IncidentCard
                key={incident.id}
                incident={incident}
                viewMode="police"
              />
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
