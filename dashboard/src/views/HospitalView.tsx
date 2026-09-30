import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  Hospital as HospitalIcon,
  CheckCircle2,
  Phone,
  MapPin,
  Trash2,
  Volume2,
  VolumeX,
} from 'lucide-react';
import { Hospital, IncidentPayload, ConnectionStatus } from '../types';
import { SEEDED_HOSPITALS } from '../config/hospitals';
import { getSocket, BACKEND_API_BASE } from '../services/socket';
import { IncidentCard } from '../components/IncidentCard';
import { ReconnectingBanner } from '../components/ReconnectingBanner';

export const HospitalView: React.FC = () => {
  const [hospitals, setHospitals] = useState<Hospital[]>(SEEDED_HOSPITALS);
  const [selectedHospitalId, setSelectedHospitalId] = useState<string>(
    SEEDED_HOSPITALS[0].id
  );
  const [incidentsByHospital, setIncidentsByHospital] = useState<
    Record<string, IncidentPayload[]>
  >(() => {
    try {
      const saved = localStorage.getItem('rakshak_hospital_feed');
      return saved ? JSON.parse(saved) : {};
    } catch {
      return {};
    }
  });
  const [connectionStatus, setConnectionStatus] =
    useState<ConnectionStatus>('connected');
  const [soundEnabled, setSoundEnabled] = useState<boolean>(true);
  const [lastAlertFlash, setLastAlertFlash] = useState<boolean>(false);

  // Audio Context Ref for instant emergency buzzer/chime without external files
  const audioContextRef = useRef<AudioContext | null>(null);

  const playAlertChime = useCallback(() => {
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

      osc.type = 'sine';
      osc.frequency.setValueAtTime(880, ctx.currentTime); // A5
      osc.frequency.exponentialRampToValueAtTime(440, ctx.currentTime + 0.35); // A4

      gain.gain.setValueAtTime(0.3, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.35);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start();
      osc.stop(ctx.currentTime + 0.35);
    } catch {
      // Audio autoplay policy catch
    }
  }, [soundEnabled]);

  // Fetch live hospitals from backend on mount
  useEffect(() => {
    let isMounted = true;
    fetch(`${BACKEND_API_BASE}/hospitals`)
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP error ${res.status}`);
        return res.json();
      })
      .then((data) => {
        if (isMounted && data.hospitals && Array.isArray(data.hospitals)) {
          setHospitals(data.hospitals);
        }
      })
      .catch((err) => {
        console.warn(
          '[HospitalView] Failed to fetch hospitals from backend, using seeded defaults:',
          err
        );
      });
    return () => {
      isMounted = false;
    };
  }, []);

  // Fetch incidents within 8km of the selected hospital on mount or hospital change
  useEffect(() => {
    let isMounted = true;
    fetch(`${BACKEND_API_BASE}/incidents?hospital_id=${selectedHospitalId}&limit=20`)
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP error ${res.status}`);
        return res.json();
      })
      .then((data) => {
        if (!isMounted) return;
        if (data.incidents && Array.isArray(data.incidents)) {
          setIncidentsByHospital((prev) => {
            const currentList = prev[selectedHospitalId] || [];
            const mergedMap = new Map<string, IncidentPayload>();
            data.incidents.forEach((inc: IncidentPayload) => {
              mergedMap.set(inc.id, inc);
            });
            currentList.forEach((inc: IncidentPayload) => {
              const existing = mergedMap.get(inc.id);
              mergedMap.set(inc.id, existing ? { ...existing, ...inc } : inc);
            });
            const merged = Array.from(mergedMap.values()).sort(
              (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
            );
            const updated = {
              ...prev,
              [selectedHospitalId]: merged,
            };
            try {
              localStorage.setItem('rakshak_hospital_feed', JSON.stringify(updated));
            } catch {
              // ignore
            }
            return updated;
          });
        }
      })
      .catch((err) => {
        console.warn('[HospitalView] Failed to fetch incidents for hospital:', err);
      });

    return () => {
      isMounted = false;
    };
  }, [selectedHospitalId]);

  const selectedHospital =
    hospitals.find((h) => h.id === selectedHospitalId) || hospitals[0];

  // Socket.io room management
  useEffect(() => {
    const socket = getSocket();

    const handleConnect = () => {
      setConnectionStatus('connected');
      socket.emit('join_hospital', selectedHospitalId);
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

    // Join room immediately if already connected
    if (socket.connected) {
      setConnectionStatus('connected');
      socket.emit('join_hospital', selectedHospitalId);
    } else {
      socket.connect();
    }

    const handleNewIncident = (payload: IncidentPayload) => {
      // Strictly verify if incident matches this hospital room
      if (payload.hospital_id && payload.hospital_id !== selectedHospitalId) {
        return;
      }

      setIncidentsByHospital((prev) => {
        const currentList = prev[selectedHospitalId] || [];
        const index = currentList.findIndex((item) => item.id === payload.id);
        let updatedList: IncidentPayload[];
        if (index >= 0) {
          updatedList = [...currentList];
          updatedList[index] = { ...updatedList[index], ...payload };
        } else {
          updatedList = [payload, ...currentList];
        }
        const updated = {
          ...prev,
          [selectedHospitalId]: updatedList,
        };
        try {
          localStorage.setItem('rakshak_hospital_feed', JSON.stringify(updated));
        } catch {
          // ignore
        }
        return updated;
      });

      // Visual flash & sound chime
      setLastAlertFlash(true);
      setTimeout(() => setLastAlertFlash(false), 2000);
      playAlertChime();
    };

    const handleFeedCleared = () => {
      setIncidentsByHospital({});
      try {
        localStorage.setItem('rakshak_hospital_feed', '{}');
      } catch {
        // ignore
      }
    };

    const handleImageUpdate = (payload: { incident_id: string; imageUrl: string }) => {
      setIncidentsByHospital((prev) => {
        let hasChanges = false;
        const updated: Record<string, IncidentPayload[]> = {};

        for (const [hId, list] of Object.entries(prev)) {
          const idx = list.findIndex((item) => item.id === payload.incident_id);
          if (idx !== -1) {
            hasChanges = true;
            const updatedList = [...list];
            updatedList[idx] = { ...updatedList[idx], imageUrl: payload.imageUrl };
            updated[hId] = updatedList;
          } else {
            updated[hId] = list;
          }
        }

        if (!hasChanges) return prev;

        try {
          localStorage.setItem('rakshak_hospital_feed', JSON.stringify(updated));
        } catch {
          // ignore
        }
        return updated;
      });
    };

    const handleCaseLocked = (payload: {
      incident_id: string;
      accepted_hospital_id: string;
      accepted_hospital_name: string;
    }) => {
      setIncidentsByHospital((prev) => {
        let hasChanges = false;
        const updated: Record<string, IncidentPayload[]> = {};

        for (const [hId, list] of Object.entries(prev)) {
          const idx = list.findIndex((item) => item.id === payload.incident_id);
          if (idx !== -1) {
            hasChanges = true;
            const updatedList = [...list];
            updatedList[idx] = {
              ...updatedList[idx],
              case_locked: payload.accepted_hospital_id !== hId,
              accepted_hospital_id: payload.accepted_hospital_id,
              accepted_hospital_name: payload.accepted_hospital_name,
            };
            updated[hId] = updatedList;
          } else {
            updated[hId] = list;
          }
        }

        if (!hasChanges) return prev;
        try {
          localStorage.setItem('rakshak_hospital_feed', JSON.stringify(updated));
        } catch {
          // ignore
        }
        return updated;
      });
    };

    const handleCaseAccepted = (payload: {
      incident_id: string;
      status: string;
      hospital: { id: string; name: string };
    }) => {
      setIncidentsByHospital((prev) => {
        let hasChanges = false;
        const updated: Record<string, IncidentPayload[]> = {};

        for (const [hId, list] of Object.entries(prev)) {
          const idx = list.findIndex((item) => item.id === payload.incident_id);
          if (idx !== -1) {
            hasChanges = true;
            const updatedList = [...list];
            updatedList[idx] = {
              ...updatedList[idx],
              status: 'accepted',
              accepted_hospital_id: payload.hospital.id,
              accepted_hospital_name: payload.hospital.name,
              case_locked: payload.hospital.id !== hId,
            };
            updated[hId] = updatedList;
          } else {
            updated[hId] = list;
          }
        }

        if (!hasChanges) return prev;
        try {
          localStorage.setItem('rakshak_hospital_feed', JSON.stringify(updated));
        } catch {
          // ignore
        }
        return updated;
      });
    };

    const handleIncidentEscalated = (payload: {
      incident_id: string;
      status: string;
      search_radius: string;
    }) => {
      setIncidentsByHospital((prev) => {
        let hasChanges = false;
        const updated: Record<string, IncidentPayload[]> = {};

        for (const [hId, list] of Object.entries(prev)) {
          const idx = list.findIndex((item) => item.id === payload.incident_id);
          if (idx !== -1) {
            hasChanges = true;
            const updatedList = [...list];
            updatedList[idx] = {
              ...updatedList[idx],
              status: 'escalated',
              escalated: true,
            };
            updated[hId] = updatedList;
          } else {
            updated[hId] = list;
          }
        }

        if (!hasChanges) return prev;
        try {
          localStorage.setItem('rakshak_hospital_feed', JSON.stringify(updated));
        } catch {
          // ignore
        }
        return updated;
      });
    };

    const handleIncidentUnmatched = (payload: { incident_id: string; status: string }) => {
      setIncidentsByHospital((prev) => {
        let hasChanges = false;
        const updated: Record<string, IncidentPayload[]> = {};

        for (const [hId, list] of Object.entries(prev)) {
          const idx = list.findIndex((item) => item.id === payload.incident_id);
          if (idx !== -1) {
            hasChanges = true;
            const updatedList = [...list];
            updatedList[idx] = {
              ...updatedList[idx],
              status: 'unmatched',
            };
            updated[hId] = updatedList;
          } else {
            updated[hId] = list;
          }
        }

        if (!hasChanges) return prev;
        try {
          localStorage.setItem('rakshak_hospital_feed', JSON.stringify(updated));
        } catch {
          // ignore
        }
        return updated;
      });
    };

    socket.on('connect', handleConnect);
    socket.on('disconnect', handleDisconnect);
    socket.on('connect_error', handleConnectError);
    socket.io.on('reconnect_attempt', handleReconnectAttempt);
    socket.on('new_incident', handleNewIncident);
    socket.on('feed_cleared', handleFeedCleared);
    socket.on('image_update', handleImageUpdate);
    socket.on('case_locked', handleCaseLocked);
    socket.on('case_accepted', handleCaseAccepted);
    socket.on('incident_escalated', handleIncidentEscalated);
    socket.on('incident_unmatched', handleIncidentUnmatched);

    return () => {
      socket.off('connect', handleConnect);
      socket.off('disconnect', handleDisconnect);
      socket.off('connect_error', handleConnectError);
      socket.io.off('reconnect_attempt', handleReconnectAttempt);
      socket.off('new_incident', handleNewIncident);
      socket.off('feed_cleared', handleFeedCleared);
      socket.off('image_update', handleImageUpdate);
      socket.off('case_locked', handleCaseLocked);
      socket.off('case_accepted', handleCaseAccepted);
      socket.off('incident_escalated', handleIncidentEscalated);
      socket.off('incident_unmatched', handleIncidentUnmatched);
    };
  }, [selectedHospitalId, playAlertChime]);

  const [acceptingIncidentId, setAcceptingIncidentId] = useState<string | null>(null);

  const handleAcceptEmergency = async (incidentId: string) => {
    setAcceptingIncidentId(incidentId);
    try {
      const res = await fetch(`${BACKEND_API_BASE}/incidents/${incidentId}/accept`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ hospital_id: selectedHospitalId }),
      });

      const data = await res.json();

      if (res.status === 409) {
        // Already accepted by another facility
        setIncidentsByHospital((prev) => {
          const list = prev[selectedHospitalId] || [];
          const updatedList = list.map((inc) =>
            inc.id === incidentId
              ? {
                  ...inc,
                  case_locked: true,
                  accepted_hospital_name: data.accepted_hospital_name || 'Another facility',
                }
              : inc
          );
          const updated = { ...prev, [selectedHospitalId]: updatedList };
          try {
            localStorage.setItem('rakshak_hospital_feed', JSON.stringify(updated));
          } catch {
            // ignore
          }
          return updated;
        });
        alert('This emergency case has already been accepted by another facility.');
        return;
      }

      if (!res.ok) {
        throw new Error(data.message || 'Failed to accept emergency');
      }

      // Success! Update local state to accepted
      setIncidentsByHospital((prev) => {
        const list = prev[selectedHospitalId] || [];
        const updatedList = list.map((inc) =>
          inc.id === incidentId
            ? {
                ...inc,
                status: 'accepted' as const,
                accepted_hospital_id: selectedHospitalId,
                accepted_hospital_name: selectedHospital.name,
              }
            : inc
        );
        const updated = { ...prev, [selectedHospitalId]: updatedList };
        try {
          localStorage.setItem('rakshak_hospital_feed', JSON.stringify(updated));
        } catch {
          // ignore
        }
        return updated;
      });
    } catch (err) {
      console.error('[HospitalView] Failed to accept emergency:', err);
      alert(`Accept failed: ${err instanceof Error ? err.message : 'Unknown error'}`);
    } finally {
      setAcceptingIncidentId(null);
    }
  };

  const handleRejectEmergency = async (incidentId: string, reason: string) => {
    try {
      const res = await fetch(`${BACKEND_API_BASE}/incidents/${incidentId}/reject`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          hospital_id: selectedHospitalId,
          reason,
        }),
      });

      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.message || 'Failed to decline incident');
      }

      // Remove card from this hospital's view only
      setIncidentsByHospital((prev) => {
        const list = prev[selectedHospitalId] || [];
        const updatedList = list.filter((inc) => inc.id !== incidentId);
        const updated = { ...prev, [selectedHospitalId]: updatedList };
        try {
          localStorage.setItem('rakshak_hospital_feed', JSON.stringify(updated));
        } catch {
          // ignore
        }
        return updated;
      });
    } catch (err) {
      console.error('[HospitalView] Failed to decline emergency:', err);
      alert(`Decline failed: ${err instanceof Error ? err.message : 'Unknown error'}`);
    }
  };

  const activeIncidents = incidentsByHospital[selectedHospitalId] || [];

  const handleClearAlerts = () => {
    setIncidentsByHospital((prev) => {
      const updated = {
        ...prev,
        [selectedHospitalId]: [],
      };
      try {
        localStorage.setItem('rakshak_hospital_feed', JSON.stringify(updated));
      } catch {
        // ignore
      }
      return updated;
    });
  };

  const handleManualReconnect = () => {
    const socket = getSocket();
    setConnectionStatus('reconnecting');
    socket.connect();
    socket.emit('join_hospital', selectedHospitalId);
  };

  return (
    <div style={{ maxWidth: '1280px', margin: '0 auto', padding: '1.5rem 1rem' }}>
      {/* Reconnecting banner if socket disconnects */}
      <ReconnectingBanner
        status={connectionStatus}
        onRetry={handleManualReconnect}
      />

      {/* Hospital Switcher & Status Bar */}
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
          transition: 'border-color 0.3s ease',
          borderColor: lastAlertFlash ? '#ef4444' : '#e2e8f0',
        }}
      >
        <div style={{ flex: '1 1 350px' }}>
          <label
            htmlFor="hospital-selector"
            style={{
              display: 'block',
              fontSize: '0.75rem',
              fontWeight: 700,
              textTransform: 'uppercase',
              color: '#64748b',
              marginBottom: '0.35rem',
            }}
          >
            Active Trauma Facility Receptor
          </label>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <HospitalIcon size={22} color="#059669" />
            <select
              id="hospital-selector"
              value={selectedHospitalId}
              onChange={(e) => setSelectedHospitalId(e.target.value)}
              style={{
                width: '100%',
                maxWidth: '480px',
                padding: '0.55rem 0.85rem',
                borderRadius: '0.375rem',
                border: '1px solid #cbd5e1',
                fontSize: '0.925rem',
                fontWeight: 600,
                color: '#0f172a',
                background: '#f8fafc',
                cursor: 'pointer',
              }}
            >
              {hospitals.map((h) => (
                <option key={h.id} value={h.id}>
                  {h.name} {h.has_trauma_center ? '(Trauma Level 1)' : '(Secondary Care)'}
                </option>
              ))}
            </select>
          </div>
        </div>

        {/* Controls & Sound Toggle */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
          <button
            onClick={() => setSoundEnabled(!soundEnabled)}
            title={soundEnabled ? 'Mute alert chime' : 'Enable alert chime'}
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
            <span>{soundEnabled ? 'Chime ON' : 'Muted'}</span>
          </button>

          {activeIncidents.length > 0 && (
            <button
              onClick={handleClearAlerts}
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

      {/* Selected Hospital Spec Card */}
      {selectedHospital && (
        <div
          style={{
            background: '#f8fafc',
            borderRadius: '0.5rem',
            padding: '1rem 1.25rem',
            border: '1px solid #e2e8f0',
            marginBottom: '1.5rem',
            display: 'flex',
            flexWrap: 'wrap',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: '1rem',
          }}
        >
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <h2
                style={{
                  margin: 0,
                  fontSize: '1.1rem',
                  fontWeight: 700,
                  color: '#0f172a',
                }}
              >
                {selectedHospital.name}
              </h2>
              {selectedHospital.has_trauma_center ? (
                <span
                  style={{
                    background: '#dcfce7',
                    color: '#15803d',
                    padding: '0.2rem 0.5rem',
                    borderRadius: '9999px',
                    fontSize: '0.7rem',
                    fontWeight: 700,
                  }}
                >
                  TRAUMA READY
                </span>
              ) : (
                <span
                  style={{
                    background: '#fef3c7',
                    color: '#b45309',
                    padding: '0.2rem 0.5rem',
                    borderRadius: '9999px',
                    fontSize: '0.7rem',
                    fontWeight: 600,
                  }}
                >
                  NO TRAUMA CENTER
                </span>
              )}
            </div>
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '1rem',
                marginTop: '0.35rem',
                color: '#64748b',
                fontSize: '0.8rem',
                flexWrap: 'wrap',
              }}
            >
              <span style={{ display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                <MapPin size={13} /> {selectedHospital.address}
              </span>
              <span style={{ display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                <Phone size={13} /> {selectedHospital.phone}
              </span>
            </div>
          </div>

          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '1rem',
              fontSize: '0.8rem',
            }}
          >
            <div style={{ textAlign: 'right' }}>
              <div style={{ color: '#64748b', fontSize: '0.725rem' }}>
                SOCKET ROOM ID
              </div>
              <div
                style={{
                  fontFamily: 'monospace',
                  color: '#0f172a',
                  fontWeight: 600,
                }}
              >
                {selectedHospital.id.slice(0, 13)}...
              </div>
            </div>
            <div
              style={{
                background: '#ffffff',
                padding: '0.5rem 0.85rem',
                borderRadius: '0.375rem',
                border: '1px solid #cbd5e1',
                textAlign: 'center',
              }}
            >
              <div style={{ fontSize: '0.725rem', color: '#64748b' }}>
                ACTIVE ALERTS
              </div>
              <div
                style={{
                  fontSize: '1.25rem',
                  fontWeight: 800,
                  color: activeIncidents.length > 0 ? '#dc2626' : '#059669',
                }}
              >
                {activeIncidents.length}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Main Incident Feed */}
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
              display: 'flex',
              alignItems: 'center',
              gap: '0.5rem',
            }}
          >
            <span>Incoming Trauma Dispatches</span>
            {activeIncidents.length > 0 && (
              <span
                style={{
                  background: '#ef4444',
                  color: '#ffffff',
                  fontSize: '0.75rem',
                  padding: '0.1rem 0.5rem',
                  borderRadius: '9999px',
                  fontWeight: 700,
                }}
              >
                {activeIncidents.length} NEW
              </span>
            )}
          </h3>
          <span style={{ fontSize: '0.8rem', color: '#64748b' }}>
            Listening to room:{' '}
            <code style={{ color: '#0f172a', fontWeight: 600 }}>
              {selectedHospitalId}
            </code>
          </span>
        </div>

        {activeIncidents.length === 0 ? (
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
            <CheckCircle2
              size={44}
              color="#10b981"
              style={{ margin: '0 auto 0.75rem' }}
            />
            <h4
              style={{
                margin: '0 0 0.35rem 0',
                fontSize: '1.1rem',
                color: '#0f172a',
              }}
            >
              Emergency Channel Clear
            </h4>
            <p
              style={{
                margin: '0 auto',
                maxWidth: '480px',
                fontSize: '0.875rem',
              }}
            >
              Awaiting real-time collision packets. When a high-G impact is
              detected within this hospital&apos;s 8km triage radius, incident
              telemetry will broadcast here instantly.
            </p>
          </div>
        ) : (
          <div>
            {activeIncidents.map((incident) => (
              <IncidentCard
                key={incident.id}
                incident={incident}
                viewMode="hospital"
                currentHospitalId={selectedHospitalId}
                onAccept={handleAcceptEmergency}
                onReject={handleRejectEmergency}
                isAccepting={acceptingIncidentId === incident.id}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
