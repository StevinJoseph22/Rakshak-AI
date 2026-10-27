import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  Hospital as HospitalIcon,
  CheckCircle2,
  Phone,
  MapPin,
  Trash2,
  Volume2,
  VolumeX,
  LogOut,
} from 'lucide-react';
import { Hospital, IncidentPayload, ConnectionStatus } from '../types';
import { SEEDED_HOSPITALS } from '../config/hospitals';
import { getSocket, BACKEND_API_BASE, updateSocketAuth } from '../services/socket';
import { getStoredUser, clearStoredSession, AuthUser, authFetch } from '../services/auth';
import { LoginView } from '../components/LoginView';
import { IncidentCard } from '../components/IncidentCard';
import { ReconnectingBanner } from '../components/ReconnectingBanner';
import {
  HospitalCapabilityManager,
  DEFAULT_HOSPITAL_CAPABILITIES,
} from '../components/HospitalCapabilityManager';
import { HospitalCapabilities } from '../types';

export const HospitalView: React.FC = () => {
  const [currentUser, setCurrentUser] = useState<AuthUser | null>(() => {
    const user = getStoredUser();
    return user && user.role === 'hospital_staff' ? user : null;
  });
  const [hospitals, setHospitals] = useState<Hospital[]>(SEEDED_HOSPITALS);
  const [selectedHospitalId, setSelectedHospitalId] = useState<string>(() => {
    const user = getStoredUser();
    return (user && user.role === 'hospital_staff' && user.hospital_id)
      ? user.hospital_id
      : SEEDED_HOSPITALS[0].id;
  });
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
  const [filterMode, setFilterMode] = useState<'all' | 'action_required' | 'accepted'>('all');
  const [isCapabilityManagerExpanded, setIsCapabilityManagerExpanded] = useState<boolean>(true);
  const [hospitalCapabilities, setHospitalCapabilities] = useState<HospitalCapabilities>(() => {
    try {
      const user = getStoredUser();
      const hId = (user && user.role === 'hospital_staff' && user.hospital_id) || 'default';
      const saved = localStorage.getItem(`rakshak_hospital_capabilities_${hId}`);
      return saved ? JSON.parse(saved) : DEFAULT_HOSPITAL_CAPABILITIES;
    } catch {
      return DEFAULT_HOSPITAL_CAPABILITIES;
    }
  });

  // 1. Fetch server-persisted capabilities on mount / hospital change
  useEffect(() => {
    let isMounted = true;
    const fetchCapabilities = async () => {
      try {
        const res = await fetch(`${BACKEND_API_BASE}/hospitals/${selectedHospitalId}/capabilities`);
        if (res.ok) {
          const data = await res.json();
          if (isMounted && data.capabilities) {
            setHospitalCapabilities(data.capabilities);
          }
        }
      } catch (err) {
        console.warn('Failed to fetch capabilities from server:', err);
      }
    };
    fetchCapabilities();
    return () => {
      isMounted = false;
    };
  }, [selectedHospitalId]);

  // 2. Real-time capability synchronization via Socket.IO
  useEffect(() => {
    const socket = getSocket();
    const onCapabilitiesUpdated = (data: { hospital_id: string; capabilities: HospitalCapabilities }) => {
      if (data.hospital_id === selectedHospitalId) {
        setHospitalCapabilities(data.capabilities);
      }
    };
    socket.on('hospital:capabilities_updated', onCapabilitiesUpdated);
    return () => {
      socket.off('hospital:capabilities_updated', onCapabilitiesUpdated);
    };
  }, [selectedHospitalId]);

  // 3. Persist capabilities to backend with audit logging & RBAC authorization
  const handleCapabilitiesChange = async (updated: HospitalCapabilities) => {
    setHospitalCapabilities(updated);
    try {
      localStorage.setItem(`rakshak_hospital_capabilities_${selectedHospitalId}`, JSON.stringify(updated));
    } catch {
      // ignore
    }
    try {
      await authFetch(`${BACKEND_API_BASE}/hospitals/${selectedHospitalId}/capabilities`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ capabilities: updated }),
      });
    } catch (err) {
      console.warn('Failed to update hospital capabilities on server:', err);
    }
  };

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
    authFetch(`${BACKEND_API_BASE}/incidents?hospital_id=${selectedHospitalId}&limit=20`)
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
    if (!currentUser || !currentUser.hospital_id) return;
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
      all_matched_hospitals?: Hospital[];
      newly_matched_hospitals?: Hospital[];
    }) => {
      setIncidentsByHospital((prev) => {
        let hasChanges = false;
        const updated: Record<string, IncidentPayload[]> = {};

        for (const [hId, list] of Object.entries(prev)) {
          const idx = list.findIndex((item) => item.id === payload.incident_id);
          if (idx !== -1) {
            hasChanges = true;
            const updatedList = [...list];
            const currentHospitals = updatedList[idx].matched_hospitals || [];
            const finalHospitals =
              payload.all_matched_hospitals && payload.all_matched_hospitals.length > 0
                ? payload.all_matched_hospitals
                : payload.newly_matched_hospitals
                ? (() => {
                    const ids = new Set(currentHospitals.map((h) => h.id));
                    const additions = payload.newly_matched_hospitals.filter((h) => !ids.has(h.id));
                    return [...currentHospitals, ...additions];
                  })()
                : currentHospitals;

            const currentMeta = (updatedList[idx].victim_metadata || {}) as Record<string, unknown>;

            updatedList[idx] = {
              ...updatedList[idx],
              status: 'escalated',
              escalated: true,
              search_radius: payload.search_radius || '20km',
              matched_hospitals: finalHospitals,
              victim_metadata: {
                ...currentMeta,
                search_radius: payload.search_radius || '20km',
              },
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

    const handleHospitalRejected = (payload: {
      incident_id: string;
      hospital_id: string;
      hospital_name: string;
      reason: string;
      created_at?: string;
    }) => {
      setIncidentsByHospital((prev) => {
        let hasChanges = false;
        const updated: Record<string, IncidentPayload[]> = {};

        for (const [hId, list] of Object.entries(prev)) {
          const idx = list.findIndex((item) => item.id === payload.incident_id);
          if (idx !== -1) {
            hasChanges = true;
            const updatedList = [...list];
            const target = updatedList[idx];
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
            updatedList[idx] = {
              ...target,
              rejections: newRejections,
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

    const handleIncidentClaimed = (payload: {
      incident_id: string;
      ambulance_id: string;
      ambulance_plate?: string;
      driver_name?: string;
      driver_phone?: string;
      origin_station?: string;
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
              ambulance_id: payload.ambulance_id,
              ambulance_plate: payload.ambulance_plate || updatedList[idx].ambulance_plate,
              ambulance_driver_name: payload.driver_name || updatedList[idx].ambulance_driver_name,
              ambulance_driver_phone: payload.driver_phone || updatedList[idx].ambulance_driver_phone,
              ambulance_origin_station: payload.origin_station || updatedList[idx].ambulance_origin_station,
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
              ambulance_id: payload.ambulance_id,
              ambulance_plate: payload.ambulance_plate || updatedList[idx].ambulance_plate,
              ambulance_driver_name: payload.driver_name || updatedList[idx].ambulance_driver_name,
              ambulance_driver_phone: payload.driver_phone || updatedList[idx].ambulance_driver_phone,
              ambulance_origin_station: payload.origin_station || updatedList[idx].ambulance_origin_station,
              ambulance_arrived_at: payload.arrived_at,
              ambulance_arrival_lat: payload.latitude,
              ambulance_arrival_lng: payload.longitude,
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

    const handleAmbulanceLocationUpdate = (payload: {
      incident_id: string;
      ambulance_id: string;
      latitude: number;
      longitude: number;
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
              ambulance_id: payload.ambulance_id,
              ambulance_location: {
                latitude: payload.latitude,
                longitude: payload.longitude,
              },
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

    const handleDeadManCollapseDetected = () => {
      setLastAlertFlash(true);
      setTimeout(() => setLastAlertFlash(false), 2000);
      playAlertChime();
    };

    socket.on('connect', handleConnect);
    socket.on('disconnect', handleDisconnect);
    socket.on('connect_error', handleConnectError);
    socket.io.on('reconnect_attempt', handleReconnectAttempt);
    socket.on('new_incident', handleNewIncident);
    socket.on('dead_man_collapse_detected', handleDeadManCollapseDetected);
    socket.on('feed_cleared', handleFeedCleared);
    socket.on('image_update', handleImageUpdate);
    socket.on('case_locked', handleCaseLocked);
    socket.on('case_accepted', handleCaseAccepted);
    socket.on('incident_escalated', handleIncidentEscalated);
    socket.on('incident_unmatched', handleIncidentUnmatched);
    socket.on('hospital_rejected', handleHospitalRejected);
    socket.on('incident_claimed', handleIncidentClaimed);
    socket.on('ambulance_arrived', handleAmbulanceArrived);
    socket.on('ambulance_location_update', handleAmbulanceLocationUpdate);

    return () => {
      socket.off('connect', handleConnect);
      socket.off('disconnect', handleDisconnect);
      socket.off('connect_error', handleConnectError);
      socket.io.off('reconnect_attempt', handleReconnectAttempt);
      socket.off('new_incident', handleNewIncident);
      socket.off('dead_man_collapse_detected', handleDeadManCollapseDetected);
      socket.off('feed_cleared', handleFeedCleared);
      socket.off('image_update', handleImageUpdate);
      socket.off('case_locked', handleCaseLocked);
      socket.off('case_accepted', handleCaseAccepted);
      socket.off('incident_escalated', handleIncidentEscalated);
      socket.off('incident_unmatched', handleIncidentUnmatched);
      socket.off('hospital_rejected', handleHospitalRejected);
      socket.off('incident_claimed', handleIncidentClaimed);
      socket.off('ambulance_arrived', handleAmbulanceArrived);
      socket.off('ambulance_location_update', handleAmbulanceLocationUpdate);
    };
  }, [selectedHospitalId, currentUser, playAlertChime]);

  const [acceptingIncidentId, setAcceptingIncidentId] = useState<string | null>(null);

  const handleAcceptEmergency = async (incidentId: string) => {
    setAcceptingIncidentId(incidentId);
    try {
      const res = await authFetch(`${BACKEND_API_BASE}/incidents/${incidentId}/accept`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ hospital_id: selectedHospitalId }),
      });

      const data = await res.json();

      if (res.status === 409) {
        // Already accepted by another facility
        const acceptingName = data.accepted_hospital_name || 'another trauma facility';
        setIncidentsByHospital((prev) => {
          const list = prev[selectedHospitalId] || [];
          const updatedList = list.map((inc) =>
            inc.id === incidentId
              ? {
                  ...inc,
                  case_locked: true,
                  status: 'accepted' as const,
                  accepted_hospital_name: acceptingName,
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
        alert(data.message || `This emergency case has already been accepted by ${acceptingName}.`);
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
      const res = await authFetch(`${BACKEND_API_BASE}/incidents/${incidentId}/reject`, {
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

  const handleLoginSuccess = (user: AuthUser) => {
    setCurrentUser(user);
    if (user.hospital_id) {
      setSelectedHospitalId(user.hospital_id);
    }
  };

  const handleLogout = () => {
    clearStoredSession();
    updateSocketAuth();
    setCurrentUser(null);
  };

  if (!currentUser || !currentUser.hospital_id) {
    return (
      <LoginView
        requiredRole="hospital_staff"
        onLoginSuccess={handleLoginSuccess}
      />
    );
  }

  const handleManualReconnect = () => {
    const socket = getSocket();
    setConnectionStatus('reconnecting');
    socket.connect();
    socket.emit('join_hospital', selectedHospitalId);
  };

  const broadcastingCount = activeIncidents.filter(
    (inc) => inc.status === 'broadcasting' || inc.status === 'escalated'
  ).length;
  const acceptedCount = activeIncidents.filter(
    (inc) => inc.status === 'accepted' && inc.accepted_hospital_id === selectedHospitalId
  ).length;

  const displayedIncidents = activeIncidents.filter((inc) => {
    if (filterMode === 'action_required') {
      return inc.status === 'broadcasting' || inc.status === 'escalated';
    }
    if (filterMode === 'accepted') {
      return inc.status === 'accepted' && inc.accepted_hospital_id === selectedHospitalId;
    }
    return true;
  });

  return (
    <div style={{ maxWidth: '1280px', margin: '0 auto', padding: '1.5rem 1rem' }}>
      {/* Reconnecting banner if socket disconnects */}
      <ReconnectingBanner
        status={connectionStatus}
        onRetry={handleManualReconnect}
      />

      {/* Unified Executive Clinical Command Header */}
      <div
        style={{
          background: 'linear-gradient(135deg, #ffffff 0%, #f8fafc 100%)',
          borderRadius: '0.875rem',
          padding: '1.25rem 1.5rem',
          border: '1px solid #e2e8f0',
          boxShadow: '0 4px 12px rgba(0, 0, 0, 0.04)',
          marginBottom: '1.25rem',
          display: 'flex',
          flexWrap: 'wrap',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: '1rem',
          borderColor: lastAlertFlash ? '#ef4444' : '#e2e8f0',
          transition: 'border-color 0.3s ease',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.85rem', flexWrap: 'wrap' }}>
          <div
            style={{
              padding: '0.75rem',
              background: '#ecfdf5',
              borderRadius: '0.625rem',
              border: '1.5px solid #a7f3d0',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <HospitalIcon size={26} color="#059669" />
          </div>

          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', flexWrap: 'wrap' }}>
              <h1 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 800, color: '#0f172a' }}>
                {currentUser.hospital_name || selectedHospital?.name || 'Assigned Trauma Facility'}
              </h1>
              <span
                style={{
                  background: '#dcfce7',
                  color: '#15803d',
                  padding: '0.2rem 0.55rem',
                  borderRadius: '9999px',
                  fontSize: '0.7rem',
                  fontWeight: 800,
                  letterSpacing: '0.04em',
                }}
              >
                LEVEL-1 TRAUMA BAY READY
              </span>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '0.85rem', marginTop: '0.25rem', color: '#64748b', fontSize: '0.8rem', flexWrap: 'wrap' }}>
              <span style={{ display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                <MapPin size={12} /> {selectedHospital?.address}
              </span>
              <span style={{ display: 'flex', alignItems: 'center', gap: '0.25rem' }}>
                <Phone size={12} /> {selectedHospital?.phone}
              </span>
              <span style={{ display: 'flex', alignItems: 'center', gap: '0.25rem', color: '#059669', fontWeight: 600 }}>
                <CheckCircle2 size={12} /> ER Staff: @{currentUser.username}
              </span>
            </div>
          </div>
        </div>

        {/* Top Controls: Sound, Purge, Sign out */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem' }}>
          <button
            type="button"
            onClick={() => setSoundEnabled(!soundEnabled)}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.35rem',
              padding: '0.45rem 0.8rem',
              background: soundEnabled ? '#ecfdf5' : '#f1f5f9',
              border: `1px solid ${soundEnabled ? '#a7f3d0' : '#cbd5e1'}`,
              borderRadius: '0.375rem',
              color: soundEnabled ? '#047857' : '#64748b',
              cursor: 'pointer',
              fontSize: '0.8rem',
              fontWeight: 600,
            }}
          >
            {soundEnabled ? <Volume2 size={15} /> : <VolumeX size={15} />}
            <span>{soundEnabled ? 'Chime Armed' : 'Muted'}</span>
          </button>

          {activeIncidents.length > 0 && (
            <button
              type="button"
              onClick={handleClearAlerts}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.35rem',
                padding: '0.45rem 0.8rem',
                background: '#fef2f2',
                border: '1px solid #fecaca',
                borderRadius: '0.375rem',
                color: '#dc2626',
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
              background: '#f8fafc',
              border: '1px solid #cbd5e1',
              borderRadius: '0.375rem',
              color: '#475569',
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

      {/* Real-Time Hospital Trauma Bay Capabilities & Readiness Matrix */}
      <HospitalCapabilityManager
        hospitalName={currentUser.hospital_name || selectedHospital?.name || 'Assigned Trauma Facility'}
        capabilities={hospitalCapabilities}
        onChange={handleCapabilitiesChange}
        isExpanded={isCapabilityManagerExpanded}
        onToggleExpand={() => setIsCapabilityManagerExpanded(!isCapabilityManagerExpanded)}
      />

      {/* Clinical KPI Status Deck */}
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
            Active Trauma Alerts
          </div>
          <div style={{ fontSize: '1.65rem', fontWeight: 900, color: activeIncidents.length > 0 ? '#dc2626' : '#059669', marginTop: '0.2rem' }}>
            {activeIncidents.length}
          </div>
        </div>

        <div style={{ background: '#ffffff', borderRadius: '0.5rem', padding: '0.85rem 1rem', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.03)' }}>
          <div style={{ color: '#64748b', fontSize: '0.7rem', fontWeight: 700, textTransform: 'uppercase' }}>
            Action Required
          </div>
          <div style={{ fontSize: '1.65rem', fontWeight: 900, color: broadcastingCount > 0 ? '#ea580c' : '#64748b', marginTop: '0.2rem' }}>
            {broadcastingCount}
          </div>
        </div>

        <div style={{ background: '#ffffff', borderRadius: '0.5rem', padding: '0.85rem 1rem', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.03)' }}>
          <div style={{ color: '#64748b', fontSize: '0.7rem', fontWeight: 700, textTransform: 'uppercase' }}>
            Cases Accepted by Us
          </div>
          <div style={{ fontSize: '1.65rem', fontWeight: 900, color: '#16a34a', marginTop: '0.2rem' }}>
            {acceptedCount}
          </div>
        </div>

        <div style={{ background: '#ffffff', borderRadius: '0.5rem', padding: '0.85rem 1rem', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.03)' }}>
          <div style={{ color: '#64748b', fontSize: '0.7rem', fontWeight: 700, textTransform: 'uppercase' }}>
            Triage Golden Sector
          </div>
          <div style={{ fontSize: '1.25rem', fontWeight: 800, color: '#0f172a', marginTop: '0.35rem' }}>
            8.0 km Radius
          </div>
        </div>
      </div>

      {/* Incident Stream & Clean Filter Tabs */}
      <div>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginBottom: '0.85rem',
            flexWrap: 'wrap',
            gap: '0.5rem',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
            <button
              type="button"
              onClick={() => setFilterMode('all')}
              style={{
                padding: '0.35rem 0.75rem',
                borderRadius: '9999px',
                border: '1px solid',
                borderColor: filterMode === 'all' ? '#0f172a' : '#cbd5e1',
                background: filterMode === 'all' ? '#0f172a' : '#ffffff',
                color: filterMode === 'all' ? '#ffffff' : '#475569',
                fontSize: '0.75rem',
                fontWeight: 700,
                cursor: 'pointer',
              }}
            >
              All Alerts ({activeIncidents.length})
            </button>
            <button
              type="button"
              onClick={() => setFilterMode('action_required')}
              style={{
                padding: '0.35rem 0.75rem',
                borderRadius: '9999px',
                border: '1px solid',
                borderColor: filterMode === 'action_required' ? '#dc2626' : '#cbd5e1',
                background: filterMode === 'action_required' ? '#fef2f2' : '#ffffff',
                color: filterMode === 'action_required' ? '#dc2626' : '#475569',
                fontSize: '0.75rem',
                fontWeight: 700,
                cursor: 'pointer',
              }}
            >
              Action Required ({broadcastingCount})
            </button>
            <button
              type="button"
              onClick={() => setFilterMode('accepted')}
              style={{
                padding: '0.35rem 0.75rem',
                borderRadius: '9999px',
                border: '1px solid',
                borderColor: filterMode === 'accepted' ? '#16a34a' : '#cbd5e1',
                background: filterMode === 'accepted' ? '#f0fdf4' : '#ffffff',
                color: filterMode === 'accepted' ? '#16a34a' : '#475569',
                fontSize: '0.75rem',
                fontWeight: 700,
                cursor: 'pointer',
              }}
            >
              Accepted by Us ({acceptedCount})
            </button>
          </div>

          <span style={{ fontSize: '0.75rem', color: '#64748b' }}>
            Live Socket Channel: <code style={{ color: '#0f172a', fontWeight: 600 }}>hospital_{selectedHospitalId.slice(0, 8)}</code>
          </span>
        </div>

        {displayedIncidents.length === 0 ? (
          <div
            style={{
              background: '#ffffff',
              borderRadius: '0.75rem',
              padding: '3.5rem 1.5rem',
              textAlign: 'center',
              border: '2px dashed #cbd5e1',
              color: '#64748b',
            }}
          >
            <CheckCircle2
              size={48}
              color="#10b981"
              style={{ margin: '0 auto 0.75rem' }}
            />
            <h3
              style={{
                margin: '0 0 0.35rem 0',
                fontSize: '1.15rem',
                color: '#0f172a',
                fontWeight: 800,
              }}
            >
              Trauma Intake Clear
            </h3>
            <p
              style={{
                margin: '0 auto',
                maxWidth: '480px',
                fontSize: '0.85rem',
                color: '#64748b',
                lineHeight: 1.5,
              }}
            >
              No active collisions pending admission in this filter sector. When a vehicular collision occurs within the 8km golden radius, immediate clinical trauma telemetry will stream here in sub-second real time.
            </p>
          </div>
        ) : (
          <div>
            {displayedIncidents.map((incident) => (
              <IncidentCard
                key={incident.id}
                incident={incident}
                viewMode="hospital"
                currentHospitalId={selectedHospitalId}
                capabilities={hospitalCapabilities}
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
