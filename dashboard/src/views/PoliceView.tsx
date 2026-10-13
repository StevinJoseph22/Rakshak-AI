import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  ShieldAlert,
  Radio,
  Trash2,
  Volume2,
  VolumeX,
  Map as MapIcon,
  List as ListIcon,
  LayoutGrid,
  X,
  LogOut,
} from 'lucide-react';
import { IncidentPayload, ConnectionStatus, PreemptedSignalPayload } from '../types';
import { getSocket, BACKEND_API_BASE, updateSocketAuth } from '../services/socket';
import { getStoredUser, clearStoredSession, AuthUser, authFetch } from '../services/auth';
import { LoginView } from '../components/LoginView';
import { IncidentCard } from '../components/IncidentCard';
import { ReconnectingBanner } from '../components/ReconnectingBanner';
import { PoliceTacticalMap } from '../components/PoliceTacticalMap';

export const PoliceView: React.FC = () => {
  const [currentUser, setCurrentUser] = useState<AuthUser | null>(() => {
    const user = getStoredUser();
    return user && user.role === 'police' ? user : null;
  });
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
  const [viewMode, setViewMode] = useState<'map' | 'split' | 'cards'>('map');
  const [selectedIncidentId, setSelectedIncidentId] = useState<string | null>(null);
  const [lightboxImage, setLightboxImage] = useState<string | null>(null);
  const [preemptedSignals, setPreemptedSignals] = useState<Record<string, PreemptedSignalPayload>>({});
  const [isSimulatingCollapse, setIsSimulatingCollapse] = useState<boolean>(false);

  // Countdown timer for C-V2X traffic signal preemption hold duration
  useEffect(() => {
    const timer = setInterval(() => {
      setPreemptedSignals((prev) => {
        let changed = false;
        const next: Record<string, PreemptedSignalPayload> = {};
        for (const [id, sig] of Object.entries(prev)) {
          if (sig.hold_seconds > 0) {
            changed = true;
            next[id] = { ...sig, hold_seconds: sig.hold_seconds - 1 };
          }
        }
        return changed ? next : prev;
      });
    }, 1000);

    return () => clearInterval(timer);
  }, []);

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

  // Fetch live incidents from backend API
  const fetchPoliceIncidents = useCallback(async () => {
    if (!currentUser || currentUser.role !== 'police') return;
    try {
      localStorage.removeItem('rakshak_police_cleared');
      const res = await authFetch(`${BACKEND_API_BASE}/incidents?limit=20`);
      if (!res.ok) return;
      const data = await res.json();
      if (data.incidents && Array.isArray(data.incidents)) {
        setIncidents((prev) => {
          const mergedMap = new Map<string, IncidentPayload>();
          data.incidents.forEach((inc: IncidentPayload) => {
            mergedMap.set(inc.id, inc);
          });
          // Preserve any in-memory socket attributes if they are newer
          prev.forEach((inc: IncidentPayload) => {
            if (mergedMap.has(inc.id)) {
              const fromServer = mergedMap.get(inc.id)!;
              mergedMap.set(inc.id, {
                ...fromServer,
                ambulance_location: inc.ambulance_location || fromServer.ambulance_location,
                imageUrl: inc.imageUrl || fromServer.imageUrl,
              });
            }
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
    } catch (err) {
      console.warn('[PoliceView] Failed to fetch incidents:', err);
    }
  }, [currentUser]);

  // Fetch on mount, window focus, and background sync every 4 seconds
  useEffect(() => {
    fetchPoliceIncidents();

    const interval = setInterval(fetchPoliceIncidents, 4000);
    const handleFocus = () => fetchPoliceIncidents();
    window.addEventListener('focus', handleFocus);

    return () => {
      clearInterval(interval);
      window.removeEventListener('focus', handleFocus);
    };
  }, [fetchPoliceIncidents]);

  // Connect and join police "all_incidents" broadcast room
  useEffect(() => {
    if (!currentUser || currentUser.role !== 'police') return;
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
      } catch {
        // ignore
      }
    };

    const handleImageUpdate = (payload: { incident_id: string; imageUrl: string }) => {
      setIncidents((prev) => {
        const existingIndex = prev.findIndex((item) => item.id === payload.incident_id);
        if (existingIndex === -1) {
          fetchPoliceIncidents();
          return prev;
        }
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
        if (existingIndex === -1) {
          fetchPoliceIncidents();
          return prev;
        }
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
        if (existingIndex === -1) {
          fetchPoliceIncidents();
          return prev;
        }
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
        if (existingIndex === -1) {
          fetchPoliceIncidents();
          return prev;
        }
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
        if (existingIndex === -1) {
          fetchPoliceIncidents();
          return prev;
        }
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
        if (existingIndex === -1) {
          fetchPoliceIncidents();
          return prev;
        }
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

    const handleIncidentClaimed = (payload: {
      incident_id: string;
      ambulance_id: string;
      ambulance_plate?: string;
      driver_name?: string;
      driver_phone?: string;
      origin_station?: string;
    }) => {
      setIncidents((prev) => {
        const existingIndex = prev.findIndex((item) => item.id === payload.incident_id);
        if (existingIndex === -1) {
          fetchPoliceIncidents();
          return prev;
        }
        const updatedList = [...prev];
        updatedList[existingIndex] = {
          ...updatedList[existingIndex],
          ambulance_id: payload.ambulance_id,
          ambulance_plate: payload.ambulance_plate || updatedList[existingIndex].ambulance_plate,
          ambulance_driver_name: payload.driver_name || updatedList[existingIndex].ambulance_driver_name,
          ambulance_driver_phone: payload.driver_phone || updatedList[existingIndex].ambulance_driver_phone,
          ambulance_origin_station: payload.origin_station || updatedList[existingIndex].ambulance_origin_station,
        };
        try {
          localStorage.setItem('rakshak_police_feed', JSON.stringify(updatedList));
        } catch {
          // ignore
        }
        return updatedList;
      });
    };

    const handleAmbulanceArrived = (payload: {
      incident_id: string;
      ambulance_id: string;
      ambulance_plate?: string;
      driver_name?: string;
      driver_phone?: string;
      origin_station?: string;
      arrived_at: string;
      latitude?: number;
      longitude?: number;
    }) => {
      setIncidents((prev) => {
        const existingIndex = prev.findIndex((item) => item.id === payload.incident_id);
        if (existingIndex === -1) {
          fetchPoliceIncidents();
          return prev;
        }
        const updatedList = [...prev];
        updatedList[existingIndex] = {
          ...updatedList[existingIndex],
          ambulance_id: payload.ambulance_id,
          ambulance_plate: payload.ambulance_plate || updatedList[existingIndex].ambulance_plate,
          ambulance_driver_name: payload.driver_name || updatedList[existingIndex].ambulance_driver_name,
          ambulance_driver_phone: payload.driver_phone || updatedList[existingIndex].ambulance_driver_phone,
          ambulance_origin_station: payload.origin_station || updatedList[existingIndex].ambulance_origin_station,
          ambulance_arrived_at: payload.arrived_at,
          ambulance_arrival_lat: payload.latitude,
          ambulance_arrival_lng: payload.longitude,
        };
        try {
          localStorage.setItem('rakshak_police_feed', JSON.stringify(updatedList));
        } catch {
          // ignore
        }
        return updatedList;
      });
    };

    const handleAmbulanceLocationUpdate = (payload: {
      incident_id: string;
      ambulance_id: string;
      latitude: number;
      longitude: number;
    }) => {
      setIncidents((prev) => {
        const existingIndex = prev.findIndex((item) => item.id === payload.incident_id);
        if (existingIndex === -1) {
          fetchPoliceIncidents();
          return prev;
        }
        const updatedList = [...prev];
        updatedList[existingIndex] = {
          ...updatedList[existingIndex],
          ambulance_id: payload.ambulance_id,
          ambulance_location: {
            latitude: payload.latitude,
            longitude: payload.longitude,
          },
        };
        try {
          localStorage.setItem('rakshak_police_feed', JSON.stringify(updatedList));
        } catch {
          // ignore
        }
        return updatedList;
      });
    };

    const handleTrafficSignalPreempted = (payload: PreemptedSignalPayload) => {
      setPreemptedSignals((prev) => ({
        ...prev,
        [payload.intersection_id]: payload,
      }));
    };

    const handleDeadManCollapseDetected = () => {
      setLastAlertFlash(true);
      setTimeout(() => setLastAlertFlash(false), 2000);
      playPoliceChime();
    };

    const handleIncidentSuspected = (payload: IncidentPayload) => {
      setIncidents((prev) => {
        const existingIndex = prev.findIndex((item) => item.id === payload.id);
        let updatedList: IncidentPayload[];
        if (existingIndex >= 0) {
          updatedList = [...prev];
          updatedList[existingIndex] = { ...updatedList[existingIndex], ...payload, status: 'suspected' };
        } else {
          updatedList = [{ ...payload, status: 'suspected' }, ...prev];
        }
        try {
          localStorage.setItem('rakshak_police_feed', JSON.stringify(updatedList));
        } catch {
          // ignore
        }
        return updatedList;
      });
    };

    const handleIncidentCancelled = (payload: { id: string; reason?: string }) => {
      setIncidents((prev) => {
        const updatedList = prev.filter((item) => item.id !== payload.id);
        try {
          localStorage.setItem('rakshak_police_feed', JSON.stringify(updatedList));
        } catch {
          // ignore
        }
        return updatedList;
      });
    };

    const handleSuspectedIncidentPromoted = (payload: { id: string; incident: IncidentPayload }) => {
      setIncidents((prev) => {
        const existingIndex = prev.findIndex((item) => item.id === payload.id);
        let updatedList: IncidentPayload[];
        if (existingIndex >= 0) {
          updatedList = [...prev];
          updatedList[existingIndex] = { ...updatedList[existingIndex], ...payload.incident, status: 'broadcasting' };
        } else {
          updatedList = [{ ...payload.incident, status: 'broadcasting' }, ...prev];
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

    socket.on('connect', handleConnect);
    socket.on('disconnect', handleDisconnect);
    socket.on('connect_error', handleConnectError);
    socket.io.on('reconnect_attempt', handleReconnectAttempt);
    socket.on('new_incident', handleNewIncident);
    socket.on('incident_suspected', handleIncidentSuspected);
    socket.on('incident_cancelled', handleIncidentCancelled);
    socket.on('suspected_incident_promoted', handleSuspectedIncidentPromoted);
    socket.on('dead_man_collapse_detected', handleDeadManCollapseDetected);
    socket.on('feed_cleared', handleFeedCleared);
    socket.on('image_update', handleImageUpdate);
    socket.on('case_accepted', handleCaseAccepted);
    socket.on('incident_escalated', handleIncidentEscalated);
    socket.on('incident_unmatched', handleIncidentUnmatched);
    socket.on('case_locked', handleCaseLocked);
    socket.on('hospital_rejected', handleHospitalRejected);
    socket.on('incident_claimed', handleIncidentClaimed);
    socket.on('ambulance_arrived', handleAmbulanceArrived);
    socket.on('ambulance_location_update', handleAmbulanceLocationUpdate);
    socket.on('traffic_signal_preempted', handleTrafficSignalPreempted);

    return () => {
      socket.off('connect', handleConnect);
      socket.off('disconnect', handleDisconnect);
      socket.off('connect_error', handleConnectError);
      socket.io.off('reconnect_attempt', handleReconnectAttempt);
      socket.off('new_incident', handleNewIncident);
      socket.off('incident_suspected', handleIncidentSuspected);
      socket.off('incident_cancelled', handleIncidentCancelled);
      socket.off('suspected_incident_promoted', handleSuspectedIncidentPromoted);
      socket.off('dead_man_collapse_detected', handleDeadManCollapseDetected);
      socket.off('feed_cleared', handleFeedCleared);
      socket.off('image_update', handleImageUpdate);
      socket.off('case_accepted', handleCaseAccepted);
      socket.off('incident_escalated', handleIncidentEscalated);
      socket.off('incident_unmatched', handleIncidentUnmatched);
      socket.off('case_locked', handleCaseLocked);
      socket.off('hospital_rejected', handleHospitalRejected);
      socket.off('incident_claimed', handleIncidentClaimed);
      socket.off('ambulance_arrived', handleAmbulanceArrived);
      socket.off('ambulance_location_update', handleAmbulanceLocationUpdate);
      socket.off('traffic_signal_preempted', handleTrafficSignalPreempted);
    };
  }, [currentUser, playPoliceChime, fetchPoliceIncidents]);

  const handleClearFeed = async () => {
    setIncidents([]);
    try {
      localStorage.setItem('rakshak_police_feed', '[]');
      // Purge test incidents from database so they do not resurrect
      await authFetch(`${BACKEND_API_BASE}/incidents`, { method: 'DELETE' });
    } catch {
      // ignore
    }
  };

  const handleSimulateDeadManCollapse = async () => {
    setIsSimulatingCollapse(true);
    try {
      await fetch(`${BACKEND_API_BASE}/sentinel/simulate-collapse`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          vehiclePlate: 'KA-01-EA-108',
          speedKmh: 94.6,
          latitude: 12.9716,
          longitude: 77.5946,
        }),
      });
    } catch (err) {
      console.error('Failed to simulate dead-man collapse', err);
    } finally {
      setIsSimulatingCollapse(false);
    }
  };

  const handleLogout = () => {
    clearStoredSession();
    updateSocketAuth();
    setCurrentUser(null);
  };

  if (!currentUser || currentUser.role !== 'police') {
    return (
      <LoginView
        requiredRole="police"
        onLoginSuccess={(user) => setCurrentUser(user)}
      />
    );
  }

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

      {/* Unified Executive Tactical Operations Header */}
      <div
        style={{
          background: 'linear-gradient(135deg, #0f172a 0%, #1e293b 100%)',
          borderRadius: '0.875rem',
          padding: '1.25rem 1.5rem',
          border: '1px solid #334155',
          boxShadow: '0 8px 24px rgba(0, 0, 0, 0.25)',
          marginBottom: '1.25rem',
          display: 'flex',
          flexWrap: 'wrap',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: '1rem',
          borderColor: lastAlertFlash ? '#ef4444' : '#334155',
          transition: 'border-color 0.3s ease',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.85rem' }}>
          <div
            style={{
              background: '#1e3a8a',
              color: '#60a5fa',
              padding: '0.75rem',
              borderRadius: '0.625rem',
              border: '1.5px solid #3b82f6',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <ShieldAlert size={26} color="#60a5fa" />
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', flexWrap: 'wrap' }}>
              <h1 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 800, color: '#f8fafc' }}>
                BTP & ERSS Police Tactical Command Center
              </h1>
              <span
                style={{
                  background: '#1e3a8a',
                  color: '#93c5fd',
                  padding: '0.15rem 0.5rem',
                  borderRadius: '9999px',
                  fontSize: '0.7rem',
                  fontWeight: 800,
                  border: '1px solid #3b82f6',
                }}
              >
                TACTICAL BROADCAST ACTIVE
              </span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginTop: '0.25rem', color: '#94a3b8', fontSize: '0.8rem', flexWrap: 'wrap' }}>
              <span>Jurisdiction: Bengaluru Urban & Rural Police Control</span>
              <span>•</span>
              <span style={{ color: '#60a5fa', fontWeight: 600 }}>
                Verified Dispatcher: @{currentUser.username}
              </span>
            </div>
          </div>
        </div>

        {/* Action Controls */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem' }}>
          <button
            type="button"
            onClick={() => setSoundEnabled(!soundEnabled)}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.35rem',
              padding: '0.45rem 0.8rem',
              background: soundEnabled ? '#1e293b' : '#0f172a',
              border: `1px solid ${soundEnabled ? '#3b82f6' : '#475569'}`,
              borderRadius: '0.375rem',
              color: soundEnabled ? '#60a5fa' : '#94a3b8',
              cursor: 'pointer',
              fontSize: '0.8rem',
              fontWeight: 600,
            }}
          >
            {soundEnabled ? <Volume2 size={15} /> : <VolumeX size={15} />}
            <span>{soundEnabled ? 'Siren Armed' : 'Muted'}</span>
          </button>

          <button
            type="button"
            onClick={handleSimulateDeadManCollapse}
            disabled={isSimulatingCollapse}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.35rem',
              padding: '0.45rem 0.8rem',
              background: '#7f1d1d',
              border: '1px solid #ef4444',
              borderRadius: '0.375rem',
              color: '#fee2e2',
              cursor: isSimulatingCollapse ? 'not-allowed' : 'pointer',
              fontSize: '0.8rem',
              fontWeight: 700,
            }}
          >
            <Radio size={14} color="#fca5a5" />
            <span>{isSimulatingCollapse ? 'Simulating...' : 'Simulate Phone Collapse'}</span>
          </button>

          {incidents.length > 0 && (
            <button
              type="button"
              onClick={handleClearFeed}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.35rem',
                padding: '0.45rem 0.8rem',
                background: 'rgba(239, 68, 68, 0.2)',
                border: '1px solid #ef4444',
                borderRadius: '0.375rem',
                color: '#fca5a5',
                cursor: 'pointer',
                fontSize: '0.8rem',
                fontWeight: 600,
              }}
            >
              <Trash2 size={14} />
              <span>Clear Feed</span>
            </button>
          )}

          <button
            type="button"
            onClick={handleLogout}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.35rem',
              padding: '0.45rem 0.8rem',
              background: '#1e293b',
              border: '1px solid #475569',
              borderRadius: '0.375rem',
              color: '#cbd5e1',
              cursor: 'pointer',
              fontSize: '0.8rem',
              fontWeight: 600,
            }}
          >
            <LogOut size={14} />
            <span>Sign Out</span>
          </button>
        </div>
      </div>

      {/* Police Tactical KPI Deck */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: '0.85rem',
          marginBottom: '1.25rem',
        }}
      >
        <div style={{ background: '#ffffff', borderRadius: '0.5rem', padding: '0.85rem 1rem', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.03)' }}>
          <div style={{ color: '#64748b', fontSize: '0.7rem', fontWeight: 700, textTransform: 'uppercase' }}>
            City-Wide Active Collisions
          </div>
          <div style={{ fontSize: '1.65rem', fontWeight: 900, color: incidents.length > 0 ? '#dc2626' : '#059669', marginTop: '0.2rem' }}>
            {incidents.length}
          </div>
        </div>

        <div style={{ background: '#ffffff', borderRadius: '0.5rem', padding: '0.85rem 1rem', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.03)' }}>
          <div style={{ color: '#64748b', fontSize: '0.7rem', fontWeight: 700, textTransform: 'uppercase' }}>
            Pre-Alert Soft Markers
          </div>
          <div style={{ fontSize: '1.65rem', fontWeight: 900, color: incidents.filter((i) => i.status === 'suspected').length > 0 ? '#7c3aed' : '#64748b', marginTop: '0.2rem' }}>
            {incidents.filter((i) => i.status === 'suspected').length}
          </div>
        </div>

        <div style={{ background: '#ffffff', borderRadius: '0.5rem', padding: '0.85rem 1rem', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.03)' }}>
          <div style={{ color: '#64748b', fontSize: '0.7rem', fontWeight: 700, textTransform: 'uppercase' }}>
            Accident Blackspots Flagged
          </div>
          <div style={{ fontSize: '1.65rem', fontWeight: 900, color: incidents.filter((i) => i.blackspot_info?.is_blackspot).length > 0 ? '#dc2626' : '#64748b', marginTop: '0.2rem' }}>
            {incidents.filter((i) => i.blackspot_info?.is_blackspot).length}
          </div>
        </div>

        <div
          style={{
            background: Object.values(preemptedSignals).some((s) => s.status === 'GRANTED' || s.status === 'ACTIVE' || s.hold_seconds > 0)
              ? '#ecfdf5'
              : '#ffffff',
            borderRadius: '0.5rem',
            padding: '0.85rem 1rem',
            border: Object.values(preemptedSignals).some((s) => s.status === 'GRANTED' || s.status === 'ACTIVE' || s.hold_seconds > 0)
              ? '1.5px solid #10b981'
              : '1px solid #e2e8f0',
            boxShadow: '0 1px 3px rgba(0,0,0,0.03)',
          }}
        >
          <div style={{ color: '#64748b', fontSize: '0.7rem', fontWeight: 700, textTransform: 'uppercase' }}>
            C-V2X Green Corridor
          </div>
          <div
            style={{
              fontSize: '1.15rem',
              fontWeight: 800,
              color: Object.values(preemptedSignals).some((s) => s.status === 'GRANTED' || s.status === 'ACTIVE' || s.hold_seconds > 0)
                ? '#047857'
                : '#475569',
              marginTop: '0.35rem',
            }}
          >
            {Object.values(preemptedSignals).some((s) => s.status === 'GRANTED' || s.status === 'ACTIVE' || s.hold_seconds > 0)
              ? '🟢 Preemption Active'
              : '🚦 ITMS Standby'}
          </div>
        </div>
      </div>

      {/* Incidents Stream Header with View Mode Switcher */}
      <div style={{ marginBottom: '1rem' }}>
        <div
          style={{
            display: 'flex',
            flexWrap: 'wrap',
            alignItems: 'center',
            justifyContent: 'space-between',
            gap: '0.75rem',
            marginBottom: '0.75rem',
          }}
        >
          <div>
            <h3
              style={{
                margin: 0,
                fontSize: '1.05rem',
                fontWeight: 700,
                color: '#334155',
              }}
            >
              Live Emergency Incident Stream & Dispatch Radar
            </h3>
            <span style={{ fontSize: '0.8rem', color: '#64748b' }}>
              Broadcasting 24/7 across Bengaluru Urban & Rural jurisdiction
            </span>
          </div>

          {/* View Mode Toggle Controls */}
          <div
            style={{
              display: 'inline-flex',
              background: '#f1f5f9',
              padding: '3px',
              borderRadius: '0.5rem',
              border: '1px solid #e2e8f0',
              gap: '2px',
            }}
          >
            <button
              onClick={() => setViewMode('map')}
              title="Tactical City-Wide Map"
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.35rem',
                padding: '0.4rem 0.75rem',
                border: 'none',
                borderRadius: '0.375rem',
                fontSize: '0.8rem',
                fontWeight: 600,
                cursor: 'pointer',
                background: viewMode === 'map' ? '#ffffff' : 'transparent',
                color: viewMode === 'map' ? '#0f172a' : '#64748b',
                boxShadow: viewMode === 'map' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none',
                transition: 'all 0.15s ease',
              }}
            >
              <MapIcon size={15} />
              <span>Tactical Map</span>
            </button>
            <button
              onClick={() => setViewMode('split')}
              title="Split View (Map + Cards)"
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.35rem',
                padding: '0.4rem 0.75rem',
                border: 'none',
                borderRadius: '0.375rem',
                fontSize: '0.8rem',
                fontWeight: 600,
                cursor: 'pointer',
                background: viewMode === 'split' ? '#ffffff' : 'transparent',
                color: viewMode === 'split' ? '#0f172a' : '#64748b',
                boxShadow: viewMode === 'split' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none',
                transition: 'all 0.15s ease',
              }}
            >
              <LayoutGrid size={15} />
              <span>Split View</span>
            </button>
            <button
              onClick={() => setViewMode('cards')}
              title="Feed Cards View"
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.35rem',
                padding: '0.4rem 0.75rem',
                border: 'none',
                borderRadius: '0.375rem',
                fontSize: '0.8rem',
                fontWeight: 600,
                cursor: 'pointer',
                background: viewMode === 'cards' ? '#ffffff' : 'transparent',
                color: viewMode === 'cards' ? '#0f172a' : '#64748b',
                boxShadow: viewMode === 'cards' ? '0 1px 3px rgba(0,0,0,0.1)' : 'none',
                transition: 'all 0.15s ease',
              }}
            >
              <ListIcon size={15} />
              <span>Feed Cards ({incidents.length})</span>
            </button>
          </div>
        </div>

        {/* View Mode: Tactical Map */}
        {(viewMode === 'map' || viewMode === 'split') && (
          <div style={{ marginBottom: viewMode === 'split' ? '1.5rem' : '0' }}>
            <PoliceTacticalMap
              incidents={incidents}
              selectedIncidentId={selectedIncidentId}
              onSelectIncident={(inc) => setSelectedIncidentId(inc.id)}
              onImageClick={(img) => setLightboxImage(img)}
              preemptedSignals={preemptedSignals}
            />

            {/* Quick incident ticker below map when in Map mode */}
            {viewMode === 'map' && incidents.length > 0 && (
              <div
                style={{
                  marginTop: '0.75rem',
                  display: 'flex',
                  gap: '0.5rem',
                  overflowX: 'auto',
                  padding: '0.5rem 0',
                }}
              >
                {incidents.map((inc) => (
                  <button
                    key={inc.id}
                    onClick={() => setSelectedIncidentId(inc.id)}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '0.4rem',
                      padding: '0.4rem 0.75rem',
                      background: selectedIncidentId === inc.id ? '#1e293b' : '#ffffff',
                      color: selectedIncidentId === inc.id ? '#ffffff' : '#334155',
                      border: `1px solid ${selectedIncidentId === inc.id ? '#0f172a' : '#e2e8f0'}`,
                      borderRadius: '0.375rem',
                      fontSize: '0.75rem',
                      fontWeight: 600,
                      cursor: 'pointer',
                      whiteSpace: 'nowrap',
                    }}
                  >
                    <span
                      style={{
                        width: 8,
                        height: 8,
                        borderRadius: '50%',
                        backgroundColor:
                          inc.status === 'accepted'
                            ? '#10b981'
                            : inc.status === 'escalated'
                            ? '#ea580c'
                            : inc.status === 'unmatched'
                            ? '#ef4444'
                            : '#f59e0b',
                      }}
                    />
                    <span>{inc.id.substring(0, 8)}...</span>
                    {inc.ambulance_id && <span>🚑</span>}
                  </button>
                ))}
              </div>
            )}
          </div>
        )}

        {/* View Mode: Incident Cards */}
        {(viewMode === 'cards' || viewMode === 'split') && (
          <div>
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
                  onClick={fetchPoliceIncidents}
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
        )}

        {/* Empty state when only map is shown and incidents are 0 */}
        {viewMode === 'map' && incidents.length === 0 && (
          <div
            style={{
              marginTop: '1rem',
              background: '#ffffff',
              borderRadius: '0.5rem',
              padding: '1.5rem',
              textAlign: 'center',
              border: '1px solid #e2e8f0',
              color: '#64748b',
              fontSize: '0.875rem',
            }}
          >
            Tactical Radar scanning Bengaluru city perimeter (0 active emergency beacons). Listening on <code>all_incidents</code> socket room.
          </div>
        )}
      </div>

      {/* Lightbox Modal for Photo Inspection */}
      {lightboxImage && (
        <div
          onClick={() => setLightboxImage(null)}
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.85)',
            backdropFilter: 'blur(6px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 9999,
            padding: '1rem',
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              position: 'relative',
              maxWidth: '850px',
              maxHeight: '90vh',
              background: '#0f172a',
              borderRadius: '0.75rem',
              overflow: 'hidden',
              boxShadow: '0 25px 50px -12px rgba(0,0,0,0.5)',
              border: '1px solid #334155',
            }}
          >
            <button
              onClick={() => setLightboxImage(null)}
              style={{
                position: 'absolute',
                top: '12px',
                right: '12px',
                background: 'rgba(0,0,0,0.6)',
                border: 'none',
                color: '#ffffff',
                borderRadius: '50%',
                width: '32px',
                height: '32px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: 'pointer',
                zIndex: 10,
              }}
            >
              <X size={18} />
            </button>
            <img
              src={lightboxImage}
              alt="High-Res On-Scene Triage"
              style={{
                width: '100%',
                maxHeight: '85vh',
                objectFit: 'contain',
                display: 'block',
              }}
            />
            <div
              style={{
                padding: '10px 16px',
                background: '#0f172a',
                color: '#94a3b8',
                fontSize: '12px',
                textAlign: 'center',
                borderTop: '1px solid #1e293b',
              }}
            >
              🔒 Ephemeral On-Scene RAM Stream • Auto-purged after 15m TTL • Zero Persistent Storage
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
