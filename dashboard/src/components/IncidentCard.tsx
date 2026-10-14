import React, { useState, useEffect } from 'react';
import {
  AlertTriangle,
  MapPin,
  Clock,
  Compass,
  Building2,
  Camera,
  ExternalLink,
  ChevronDown,
  ChevronUp,
  Navigation,
  Phone,
  ShieldCheck,
  X,
  CheckCircle2,
  Lock,
  Check,
  Activity,
  Radio,
  Zap,
  Layers,
  Stethoscope,
} from 'lucide-react';
import { IncidentPayload, Hospital, EmergencyHealthCard, HealthCardField } from '../types';
import { getSocket, BACKEND_API_BASE } from '../services/socket';
import { authFetch } from '../services/auth';
import { IncidentRouteMap } from './IncidentRouteMap';

const REJECTION_REASONS = [
  'No ICU capacity',
  'No trauma specialist',
  'At capacity',
  'Other',
];

export interface PredictedInjury {
  injury: string;
  risk_percent: number;
  severity: string;
  clinical_action: string;
}

export interface CrashBiomechanicsData {
  deltaV_kmh: number;
  peak_g: number;
  pdof_degrees: number;
  impact_direction: string;
  energy_dissipation_kj: number;
  iss_score_estimate: number;
  predicted_injuries: PredictedInjury[];
}

interface IncidentCardProps {
  incident: IncidentPayload;
  viewMode?: 'hospital' | 'police';
  currentHospitalId?: string;
  onAccept?: (incidentId: string) => Promise<void> | void;
  onReject?: (incidentId: string, reason: string) => Promise<void> | void;
  isAccepting?: boolean;
}

export const IncidentCard: React.FC<IncidentCardProps> = ({
  incident,
  viewMode = 'hospital',
  currentHospitalId,
  onAccept,
  onReject,
  isAccepting = false,
}) => {
  const [isLightboxOpen, setIsLightboxOpen] = useState<boolean>(false);
  const [isRejectModalOpen, setIsRejectModalOpen] = useState<boolean>(false);
  const [selectedRejectReason, setSelectedRejectReason] = useState<string>('No ICU capacity');
  const [isSubmittingReject, setIsSubmittingReject] = useState<boolean>(false);
  const [localImageUrl, setLocalImageUrl] = useState<string | null>(incident.imageUrl || null);
  const [photoTransport, setPhotoTransport] = useState<'webrtc' | 'websocket'>('websocket');

  // Executive Clean Layout: "Backside" Drawer Toggle & Active Tab
  const [isBacksideExpanded, setIsBacksideExpanded] = useState<boolean>(false);
  const [backsideTab, setBacksideTab] = useState<'clinical' | 'kinematics' | 'hospitals' | 'route'>(
    viewMode === 'hospital' ? 'clinical' : 'hospitals'
  );

  // Phase 18: Emergency Health Card & Break-Glass Audit
  const [healthCard, setHealthCard] = useState<EmergencyHealthCard | null | undefined>(undefined);
  const [healthCardMode, setHealthCardMode] = useState<string>('MOCK');
  const [unlockedAudit, setUnlockedAudit] = useState<{ by: string; at: string } | null>(null);
  const [isBreakGlassModalOpen, setIsBreakGlassModalOpen] = useState<boolean>(false);
  const [breakGlassReason, setBreakGlassReason] = useState<string>('Acute polytrauma resuscitation in emergency department');
  const [breakGlassError, setBreakGlassError] = useState<string | null>(null);
  const [isSubmittingBreakGlass, setIsSubmittingBreakGlass] = useState<boolean>(false);
  const [policeHasCard, setPoliceHasCard] = useState<boolean | null>(null);

  // Police view: query whether health card is on file (strictly yes/no only, zero medical content)
  useEffect(() => {
    if (viewMode !== 'police') return;
    let isMounted = true;
    const checkStatus = async () => {
      try {
        const res = await fetch(`${BACKEND_API_BASE}/incidents/${incident.id}/health-card/status`);
        if (res.ok) {
          const data = await res.json();
          if (isMounted) setPoliceHasCard(Boolean(data.has_health_card));
        }
      } catch {
        if (isMounted) setPoliceHasCard(false);
      }
    };
    checkStatus();
    return () => {
      isMounted = false;
    };
  }, [incident.id, viewMode]);

  // WebRTC P2P DataChannel Receiver with WebSocket fallback
  useEffect(() => {
    let pc: RTCPeerConnection | null = null;
    let isMounted = true;
    const socket = getSocket();

    const handleWebRtcOffer = async (payload: {
      incident_id: string;
      sdp: RTCSessionDescriptionInit;
      sender_id?: string;
    }) => {
      if (payload.incident_id !== incident.id || !payload.sdp) return;
      try {
        if (pc) pc.close();
        pc = new RTCPeerConnection({
          iceServers: [
            { urls: 'stun:stun.l.google.com:19302' },
            { urls: 'stun:stun1.l.google.com:19302' },
          ],
        });

        pc.ondatachannel = (event) => {
          const receiveChannel = event.channel;
          const chunks: ArrayBuffer[] = [];

          receiveChannel.onmessage = (msgEvent) => {
            if (typeof msgEvent.data === 'string' && msgEvent.data === 'EOF') {
              const blob = new Blob(chunks, { type: 'image/jpeg' });
              const objectUrl = URL.createObjectURL(blob);
              if (isMounted) {
                setLocalImageUrl(objectUrl);
                setPhotoTransport('webrtc');
              }
              receiveChannel.close();
              if (pc) pc.close();
            } else if (msgEvent.data instanceof ArrayBuffer) {
              chunks.push(msgEvent.data);
            }
          };
        };

        pc.onicecandidate = (event) => {
          if (event.candidate) {
            socket.emit('webrtc_ice_candidate', {
              incident_id: incident.id,
              candidate: event.candidate,
              target_id: payload.sender_id,
            });
          }
        };

        await pc.setRemoteDescription(new RTCSessionDescription(payload.sdp));
        const answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);

        socket.emit('webrtc_answer', {
          incident_id: incident.id,
          sdp: answer,
          target_id: payload.sender_id,
        });
      } catch (err) {
        console.warn('[WebRTC Dashboard] Peer connection failed, falling back:', err);
      }
    };

    const handleImageUpdate = (payload: { incident_id: string; imageUrl: string }) => {
      if (payload.incident_id === incident.id && payload.imageUrl) {
        setLocalImageUrl(payload.imageUrl);
        setPhotoTransport('websocket');
      }
    };

    socket.on('webrtc_offer', handleWebRtcOffer);
    socket.on('image_update', handleImageUpdate);

    return () => {
      isMounted = false;
      if (pc) pc.close();
      socket.off('webrtc_offer', handleWebRtcOffer);
      socket.off('image_update', handleImageUpdate);
    };
  }, [incident.id]);

  useEffect(() => {
    if (incident.imageUrl) {
      setLocalImageUrl(incident.imageUrl);
    }
  }, [incident.imageUrl]);

  // Road distance and aerial line calculations
  const [roadDistanceKm, setRoadDistanceKm] = useState<number | null>(null);
  const [straightLineKm, setStraightLineKm] = useState<number | null>(null);

  useEffect(() => {
    let targetLat = 12.9352;
    let targetLng = 77.6245;

    if (viewMode === 'hospital' && incident.accepted_hospital) {
      targetLat = incident.accepted_hospital.latitude;
      targetLng = incident.accepted_hospital.longitude;
    } else if (incident.matched_hospitals && incident.matched_hospitals.length > 0) {
      targetLat = incident.matched_hospitals[0].latitude;
      targetLng = incident.matched_hospitals[0].longitude;
    }

    const toRad = (v: number) => (v * Math.PI) / 180;
    const R = 6371;
    const dLat = toRad(targetLat - incident.latitude);
    const dLng = toRad(targetLng - incident.longitude);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(toRad(incident.latitude)) *
        Math.cos(toRad(targetLat)) *
        Math.sin(dLng / 2) *
        Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    const aerial = Math.round(R * c * 100) / 100;
    setStraightLineKm(aerial);

    let isMounted = true;
    const osrmUrl = `https://router.project-osrm.org/route/v1/driving/${incident.longitude},${incident.latitude};${targetLng},${targetLat}?overview=false`;

    fetch(osrmUrl)
      .then((res) => res.json())
      .then((data) => {
        if (!isMounted) return;
        if (data.code === 'Ok' && data.routes && data.routes[0]) {
          const meters = data.routes[0].distance;
          setRoadDistanceKm(Math.round((meters / 1000) * 10) / 10);
        } else {
          setRoadDistanceKm(Math.round(aerial * 1.5 * 10) / 10);
        }
      })
      .catch(() => {
        if (isMounted) setRoadDistanceKm(Math.round(aerial * 1.5 * 10) / 10);
      });

    return () => {
      isMounted = false;
    };
  }, [incident, viewMode]);

  // Status computation
  const isAccepted = incident.status === 'accepted';
  const isThisHospitalAccepted =
    isAccepted &&
    Boolean(
      currentHospitalId &&
        incident.accepted_hospital_id &&
        currentHospitalId === incident.accepted_hospital_id
    );
  const isLockedByOther = isAccepted && !isThisHospitalAccepted && viewMode === 'hospital';
  const isEscalated = incident.status === 'escalated';
  const isUnmatched = incident.status === 'unmatched';
  const isSuspected = incident.status === 'suspected';

  const metadata = (incident.victim_metadata || {}) as Record<string, unknown>;
  const rawSeverity = metadata.severity_index as {
    level?: string;
    measured_peak_g?: number;
    is_saturated?: boolean;
    speed_drop_kmh?: number;
    impact_duration_ms?: number;
    rollover_suspected?: boolean;
    rider_unresponsive?: boolean;
    confidence_score?: number;
    contributing_factors?: string[];
  } | undefined;

  const measuredPeakG = Number(rawSeverity?.measured_peak_g ?? metadata.deceleration_g ?? 6.5);
  const isSaturated = Boolean(rawSeverity?.is_saturated ?? metadata.deceleration_saturated ?? (measuredPeakG >= 16.0));
  const speedDropKmh = Number(rawSeverity?.speed_drop_kmh ?? metadata.speed_drop_kmh ?? 55.0);
  const impactDurationMs = Number(rawSeverity?.impact_duration_ms ?? 180);
  const rolloverSuspected = Boolean(rawSeverity?.rollover_suspected ?? false);
  const riderUnresponsive = Boolean(rawSeverity?.rider_unresponsive ?? (metadata.rider_unresponsive !== undefined ? metadata.rider_unresponsive : true));
  const confidenceScore = Number(rawSeverity?.confidence_score ?? metadata.confidence_score ?? 85);
  const severityLevel: 'Critical' | 'Moderate' | 'Minor' = (rawSeverity?.level as 'Critical' | 'Moderate' | 'Minor') || (riderUnresponsive ? 'Critical' : 'Moderate');
  const contributingFactors: string[] = rawSeverity?.contributing_factors || [
    isSaturated ? 'Peak acceleration saturated sensor limit (>=16g)' : `Peak acceleration: ${measuredPeakG.toFixed(1)}g`,
    `Delta-V (speed drop): ${speedDropKmh.toFixed(1)} km/h`,
    `Impact duration: ${impactDurationMs}ms`,
    rolloverSuspected ? 'Vehicle rollover / angular tumble detected' : 'No vehicle rollover',
    riderUnresponsive ? 'Rider unresponsive to on-screen/haptic prompts' : 'Rider responsive',
    `Crash confidence score: ${confidenceScore}%`,
  ];

  const rawBiomechanics = metadata.biomechanics as CrashBiomechanicsData | undefined;
  const biomechanics: CrashBiomechanicsData = rawBiomechanics || {
    deltaV_kmh: speedDropKmh,
    peak_g: isSaturated ? 16.0 : measuredPeakG,
    pdof_degrees: 12,
    impact_direction: "Frontal Oblique (12 o'clock)",
    energy_dissipation_kj: 142.8,
    iss_score_estimate: 26,
    predicted_injuries: [
      { injury: 'Cervical Spine Whiplash / Fracture Risk', risk_percent: 84, severity: 'CRITICAL', clinical_action: 'Immediate C-Spine Collar Immobilization' },
      { injury: 'Blunt Sternal / Myocardial Contusion', risk_percent: 76, severity: 'HIGH', clinical_action: 'Prepare 12-lead ECG & Cardiac Troponin' },
      { injury: 'Intra-Abdominal / Splenic Laceration', risk_percent: 61, severity: 'HIGH', clinical_action: 'FAST Abdominal Ultrasound Protocol on Arrival' },
      { injury: 'Traumatic Brain Injury (Closed Head Shock)', risk_percent: 48, severity: 'MODERATE', clinical_action: 'Non-Contrast Head CT Protocol' }
    ]
  };

  const handleConfirmBreakGlass = async () => {
    if (!breakGlassReason || breakGlassReason.trim().length < 5) {
      setBreakGlassError('Please enter a clinical justification of at least 5 characters.');
      return;
    }
    setIsSubmittingBreakGlass(true);
    setBreakGlassError(null);
    try {
      const res = await authFetch(`${BACKEND_API_BASE}/incidents/${incident.id}/health-card/break-glass`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reason: breakGlassReason.trim() }),
      });
      const data = await res.json();
      if (!res.ok) {
        if (res.status === 404) {
          setHealthCard(null);
          setIsBreakGlassModalOpen(false);
          return;
        }
        throw new Error(data.message || data.error || 'Failed to authorize break-glass access');
      }

      setHealthCard(data.card as EmergencyHealthCard);
      setHealthCardMode(data.mode || 'MOCK');
      setUnlockedAudit({
        by: data.accessed_by || 'Staff',
        at: data.accessed_at ? new Date(data.accessed_at).toLocaleTimeString() : new Date().toLocaleTimeString(),
      });
      setIsBreakGlassModalOpen(false);
    } catch (err: unknown) {
      const errorMsg = err instanceof Error ? err.message : 'Error authorizing break-glass access';
      setBreakGlassError(errorMsg);
    } finally {
      setIsSubmittingBreakGlass(false);
    }
  };

  const renderFieldProvenanceChip = (field?: HealthCardField<unknown>) => {
    if (!field || field.status === 'NOT_AVAILABLE') {
      return (
        <span
          style={{
            background: '#f1f5f9',
            color: '#64748b',
            fontSize: '0.65rem',
            fontWeight: 700,
            padding: '0.15rem 0.45rem',
            borderRadius: '4px',
            display: 'inline-flex',
            alignItems: 'center',
            gap: '0.2rem',
          }}
        >
          ✕ Not Available {field?.reason ? `(${field.reason})` : ''}
        </span>
      );
    }
    if (field.source === 'ABDM_VERIFIED') {
      return (
        <span
          style={{
            background: '#dcfce7',
            color: '#15803d',
            fontSize: '0.65rem',
            fontWeight: 700,
            padding: '0.15rem 0.45rem',
            borderRadius: '4px',
            display: 'inline-flex',
            alignItems: 'center',
            gap: '0.25rem',
          }}
        >
          <ShieldCheck size={11} /> ABDM Verified
        </span>
      );
    }
    if (field.source === 'SELF_DECLARED') {
      return (
        <span
          style={{
            background: '#fef3c7',
            color: '#b45309',
            fontSize: '0.65rem',
            fontWeight: 700,
            padding: '0.15rem 0.45rem',
            borderRadius: '4px',
          }}
        >
          Self-declared (Not verified)
        </span>
      );
    }
    return null;
  };

  const formattedTime = new Date(incident.created_at).toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });

  const googleMapsUrl = `https://www.google.com/maps/search/?api=1&query=${incident.latitude},${incident.longitude}`;

  const acceptedHospital: Hospital | undefined = incident.accepted_hospital ||
    (incident.matched_hospitals && incident.matched_hospitals.length > 0
      ? incident.matched_hospitals[0]
      : undefined);

  const matchedHospitalsList: Hospital[] = incident.matched_hospitals || [];

  return (
    <div
      style={{
        background: '#ffffff',
        border: isThisHospitalAccepted
          ? '2px solid #22c55e'
          : isAccepted
          ? '1px solid #cbd5e1'
          : severityLevel === 'Critical'
          ? '2px solid #ef4444'
          : '1px solid #e2e8f0',
        borderRadius: '0.75rem',
        padding: '1.25rem',
        boxShadow: isThisHospitalAccepted
          ? '0 8px 24px rgba(34, 197, 94, 0.12)'
          : severityLevel === 'Critical'
          ? '0 8px 24px rgba(239, 68, 68, 0.08)'
          : '0 2px 8px rgba(0, 0, 0, 0.04)',
        marginBottom: '1.25rem',
        transition: 'all 0.2s ease',
        opacity: isLockedByOther ? 0.75 : 1,
      }}
    >
      {/* ──────────────────────────────────────────────────────────────────────────
          FRONT STAGE (CLEAN & ROLE-OPTIMIZED)
      ────────────────────────────────────────────────────────────────────────── */}

      {/* Header Row: Status Badge, Time, and Delayed Flag */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          flexWrap: 'wrap',
          gap: '0.5rem',
          borderBottom: '1px solid #f1f5f9',
          paddingBottom: '0.65rem',
          marginBottom: '0.85rem',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', flexWrap: 'wrap' }}>
          {isThisHospitalAccepted ? (
            <span
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.35rem',
                background: '#dcfce7',
                color: '#15803d',
                padding: '0.25rem 0.65rem',
                borderRadius: '9999px',
                fontSize: '0.75rem',
                fontWeight: 800,
                letterSpacing: '0.04em',
              }}
            >
              <CheckCircle2 size={13} />
              ACCEPTED BY YOUR FACILITY
            </span>
          ) : isAccepted ? (
            <span
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.35rem',
                background: '#f1f5f9',
                color: '#475569',
                padding: '0.25rem 0.65rem',
                borderRadius: '9999px',
                fontSize: '0.75rem',
                fontWeight: 700,
              }}
            >
              <Lock size={12} />
              ACCEPTED • {incident.accepted_hospital_name || 'Designated Trauma Bay'}
            </span>
          ) : isSuspected ? (
            <span
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.35rem',
                background: '#ede9fe',
                color: '#6d28d9',
                padding: '0.25rem 0.65rem',
                borderRadius: '9999px',
                fontSize: '0.75rem',
                fontWeight: 800,
              }}
            >
              <Zap size={13} />
              IMPACT SUSPECTED (PRE-ALERT)
            </span>
          ) : isEscalated ? (
            <span
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.35rem',
                background: '#ffedd5',
                color: '#c2410c',
                padding: '0.25rem 0.65rem',
                borderRadius: '9999px',
                fontSize: '0.75rem',
                fontWeight: 800,
              }}
            >
              <AlertTriangle size={13} />
              ESCALATED (SEARCH AREA EXPANDED)
            </span>
          ) : isUnmatched ? (
            <span
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.35rem',
                background: '#fee2e2',
                color: '#991b1b',
                padding: '0.25rem 0.65rem',
                borderRadius: '9999px',
                fontSize: '0.75rem',
                fontWeight: 800,
              }}
            >
              <X size={13} />
              UNMATCHED (NO NEARBY FACILITY)
            </span>
          ) : (
            <span
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.35rem',
                background: '#fee2e2',
                color: '#b91c1c',
                padding: '0.25rem 0.65rem',
                borderRadius: '9999px',
                fontSize: '0.75rem',
                fontWeight: 800,
              }}
            >
              <AlertTriangle size={13} />
              CRITICAL TRAUMA DISPATCH (BROADCASTING)
            </span>
          )}

          {Boolean(metadata.delayed_delivery) && (
            <span
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.25rem',
                background: '#fef3c7',
                color: '#92400e',
                border: '1px solid #f59e0b',
                padding: '0.2rem 0.5rem',
                borderRadius: '9999px',
                fontSize: '0.7rem',
                fontWeight: 700,
              }}
            >
              <Clock size={11} color="#d97706" />
              STORE-AND-FORWARD (+{String(metadata.delivery_delay_seconds || '15')}s)
            </span>
          )}

          <span
            style={{
              fontFamily: 'monospace',
              fontSize: '0.75rem',
              color: '#64748b',
              background: '#f8fafc',
              padding: '0.15rem 0.45rem',
              borderRadius: '0.25rem',
              border: '1px solid #e2e8f0',
            }}
          >
            ID: {incident.id.slice(0, 8)}
          </span>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', color: '#64748b', fontSize: '0.8rem' }}>
          <Clock size={13} />
          <span>{formattedTime}</span>
        </div>
      </div>

      {/* ──────────────────────────────────────────────────────────────────────────
          ROLE-SPECIFIC EXECUTIVE FRONT CONTENT
      ────────────────────────────────────────────────────────────────────────── */}

      {viewMode === 'hospital' ? (
        /* ======================== HOSPITAL EXECUTIVE FRONT ======================== */
        <div>
          {/* Main Patient & Clinical Profile Strip */}
          <div
            style={{
              background: severityLevel === 'Critical' ? '#fff1f2' : '#f0fdf4',
              border: `1.5px solid ${severityLevel === 'Critical' ? '#fecdd3' : '#bbf7d0'}`,
              borderRadius: '0.5rem',
              padding: '0.85rem 1rem',
              marginBottom: '0.85rem',
              display: 'flex',
              flexWrap: 'wrap',
              alignItems: 'center',
              justifyContent: 'space-between',
              gap: '0.75rem',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
              {/* Blood Group Pill or Locked Indicator */}
              <div
                style={{
                  background: healthCard?.blood_group?.status === 'AVAILABLE' ? '#dc2626' : '#475569',
                  color: '#ffffff',
                  padding: '0.45rem 0.85rem',
                  borderRadius: '0.5rem',
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  justifyContent: 'center',
                  boxShadow: '0 2px 6px rgba(0, 0, 0, 0.15)',
                  minWidth: '70px',
                }}
              >
                <div style={{ fontSize: '0.65rem', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                  BLOOD
                </div>
                <div style={{ fontSize: '1.15rem', fontWeight: 900, lineHeight: 1.1 }}>
                  {healthCard
                    ? (healthCard.blood_group.status === 'AVAILABLE' ? healthCard.blood_group.value : 'N/A')
                    : '🔒'}
                </div>
              </div>

              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', flexWrap: 'wrap' }}>
                  <span style={{ fontSize: '1rem', fontWeight: 800, color: '#0f172a' }}>
                    {healthCard
                      ? (healthCard.name.status === 'AVAILABLE' ? healthCard.name.value : 'Emergency Patient')
                      : isThisHospitalAccepted
                      ? 'Trauma Patient (Break-Glass Required)'
                      : 'Trauma Patient (Locked Prior to Acceptance)'}
                  </span>
                  {healthCard ? (
                    renderFieldProvenanceChip(healthCard.name)
                  ) : (
                    <span
                      style={{
                        background: '#f1f5f9',
                        color: '#64748b',
                        fontSize: '0.65rem',
                        fontWeight: 700,
                        padding: '0.1rem 0.4rem',
                        borderRadius: '4px',
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '0.2rem',
                      }}
                    >
                      <Lock size={10} /> {isThisHospitalAccepted ? 'Break-Glass to Decrypt' : 'Accept Case to Access'}
                    </span>
                  )}
                </div>
                <div style={{ fontSize: '0.775rem', color: '#475569', marginTop: '0.15rem' }}>
                  {healthCard ? (
                    <>
                      ABHA Address:{' '}
                      <strong style={{ fontFamily: 'monospace' }}>
                        {healthCard.abha_address.status === 'AVAILABLE' ? healthCard.abha_address.value : 'None linked'}
                      </strong>
                    </>
                  ) : (
                    <span>ABHA Health Record: Ephemeral Volatile RAM (Audited Clinical Access)</span>
                  )}
                </div>
              </div>
            </div>

            {/* Severity & Responsiveness Badges */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', flexWrap: 'wrap' }}>
              <span
                style={{
                  background: severityLevel === 'Critical' ? '#e11d48' : '#d97706',
                  color: '#ffffff',
                  padding: '0.35rem 0.65rem',
                  borderRadius: '0.375rem',
                  fontSize: '0.75rem',
                  fontWeight: 800,
                  textTransform: 'uppercase',
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '0.3rem',
                }}
              >
                <Activity size={13} />
                {severityLevel} Trauma
              </span>

              <span
                style={{
                  background: riderUnresponsive ? '#ffe4e6' : '#ecfdf5',
                  color: riderUnresponsive ? '#be123c' : '#047857',
                  border: `1px solid ${riderUnresponsive ? '#f43f5e' : '#10b981'}`,
                  padding: '0.35rem 0.65rem',
                  borderRadius: '0.375rem',
                  fontSize: '0.75rem',
                  fontWeight: 700,
                }}
              >
                {riderUnresponsive ? '⚠️ Victim Unresponsive' : '✓ Conscious & Responsive'}
              </span>
            </div>
          </div>

          {/* High-Urgency Critical Drug Allergy Alert (Displayed ONLY if decrypted & available) */}
          {healthCard && healthCard.allergies.status === 'AVAILABLE' && healthCard.allergies.value && healthCard.allergies.value.length > 0 && (
            <div
              style={{
                background: '#fef2f2',
                border: '1.5px solid #f87171',
                borderRadius: '0.5rem',
                padding: '0.65rem 0.85rem',
                marginBottom: '0.85rem',
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
              }}
            >
              <AlertTriangle size={16} color="#dc2626" />
              <div style={{ fontSize: '0.8rem', color: '#991b1b' }}>
                <strong>CRITICAL DRUG CONTRAINDICATION:</strong> Patient is allergic to{' '}
                <strong style={{ textDecoration: 'underline' }}>{healthCard.allergies.value.join(', ')}</strong>. Do not administer during acute resuscitation.
              </div>
            </div>
          )}

          {/* Logistics & Ambulance Status Strip */}
          <div
            style={{
              background: '#f8fafc',
              border: '1px solid #e2e8f0',
              borderRadius: '0.5rem',
              padding: '0.75rem 1rem',
              marginBottom: '0.85rem',
              display: 'flex',
              flexWrap: 'wrap',
              alignItems: 'center',
              justifyContent: 'space-between',
              gap: '0.75rem',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', flexWrap: 'wrap' }}>
              <div>
                <div style={{ fontSize: '0.7rem', color: '#64748b', fontWeight: 600, textTransform: 'uppercase' }}>
                  Road Distance to Bay
                </div>
                <div style={{ fontSize: '1.1rem', fontWeight: 800, color: '#dc2626', display: 'flex', alignItems: 'center', gap: '0.3rem' }}>
                  <Compass size={16} />
                  {roadDistanceKm !== null ? (
                    <span>
                      ~{roadDistanceKm.toFixed(1)} km Road
                      {straightLineKm !== null && (
                        <span style={{ fontSize: '0.75rem', fontWeight: 500, color: '#64748b', marginLeft: '0.35rem' }}>
                          ({straightLineKm.toFixed(1)} km direct)
                        </span>
                      )}
                    </span>
                  ) : (
                    'Calculating...'
                  )}
                </div>
              </div>

              {incident.ambulance_plate ? (
                <div>
                  <div style={{ fontSize: '0.7rem', color: '#64748b', fontWeight: 600, textTransform: 'uppercase' }}>
                    Assigned Unit
                  </div>
                  <div style={{ fontSize: '0.85rem', fontWeight: 700, color: '#0f172a' }}>
                    🚑 {incident.ambulance_plate} ({incident.ambulance_driver_name || 'Paramedic Unit'})
                  </div>
                </div>
              ) : (
                <div>
                  <div style={{ fontSize: '0.7rem', color: '#64748b', fontWeight: 600, textTransform: 'uppercase' }}>
                    Ambulance Dispatch
                  </div>
                  <div style={{ fontSize: '0.85rem', fontWeight: 600, color: '#d97706' }}>
                    Pending Paramedic Claim
                  </div>
                </div>
              )}
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              {incident.ambulance_driver_phone && (
                <a
                  href={`tel:${incident.ambulance_driver_phone}`}
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '0.3rem',
                    padding: '0.4rem 0.75rem',
                    background: '#1d4ed8',
                    color: '#ffffff',
                    borderRadius: '0.375rem',
                    fontSize: '0.75rem',
                    fontWeight: 700,
                    textDecoration: 'none',
                  }}
                >
                  <Phone size={12} /> Call Paramedic
                </a>
              )}

              {/* Compact Scene Photo Thumbnail */}
              {localImageUrl && (
                <button
                  type="button"
                  onClick={() => setIsLightboxOpen(true)}
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '0.3rem',
                    padding: '0.4rem 0.75rem',
                    background: '#0f172a',
                    color: '#ffffff',
                    border: 'none',
                    borderRadius: '0.375rem',
                    fontSize: '0.75rem',
                    fontWeight: 600,
                    cursor: 'pointer',
                  }}
                >
                  <Camera size={12} color="#ef4444" /> View Scene Photo ({photoTransport === 'webrtc' ? 'P2P' : 'Relay'})
                </button>
              )}
            </div>
          </div>

          {/* Action Row: Accept / Decline Emergency */}
          {!isAccepted && (
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                paddingTop: '0.5rem',
                borderTop: '1px solid #f1f5f9',
                marginBottom: '0.85rem',
                flexWrap: 'wrap',
                gap: '0.5rem',
              }}
            >
              <div style={{ fontSize: '0.8rem', color: '#475569' }}>
                Review trauma profile & bed availability to reserve trauma bay:
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem' }}>
                <button
                  type="button"
                  onClick={() => setIsRejectModalOpen(true)}
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '0.35rem',
                    background: '#ffffff',
                    color: '#dc2626',
                    border: '1px solid #fca5a5',
                    borderRadius: '0.375rem',
                    padding: '0.5rem 0.9rem',
                    fontSize: '0.8rem',
                    fontWeight: 700,
                    cursor: 'pointer',
                  }}
                >
                  <X size={14} /> Divert / Decline
                </button>

                <button
                  type="button"
                  onClick={() => onAccept && onAccept(incident.id)}
                  disabled={isAccepting}
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '0.45rem',
                    background: isAccepting ? '#86efac' : '#16a34a',
                    color: '#ffffff',
                    border: 'none',
                    borderRadius: '0.375rem',
                    padding: '0.5rem 1.25rem',
                    fontSize: '0.85rem',
                    fontWeight: 800,
                    cursor: isAccepting ? 'not-allowed' : 'pointer',
                    boxShadow: '0 2px 6px rgba(22, 163, 74, 0.3)',
                  }}
                >
                  <Check size={16} />
                  {isAccepting ? 'Accepting Dispatch...' : 'ACCEPT EMERGENCY CASE'}
                </button>
              </div>
            </div>
          )}
        </div>
      ) : (
        /* ======================== POLICE EXECUTIVE FRONT ======================== */
        <div>
          {/* Tactical Location & Blackspot Banner */}
          <div
            style={{
              background: incident.blackspot_info?.is_blackspot ? 'linear-gradient(135deg, #450a0a 0%, #1e1b4b 100%)' : '#0f172a',
              border: `1.5px solid ${incident.blackspot_info?.is_blackspot ? '#ef4444' : '#334155'}`,
              borderRadius: '0.5rem',
              padding: '0.85rem 1rem',
              marginBottom: '0.85rem',
              color: '#ffffff',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '0.5rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <MapPin size={18} color="#38bdf8" />
                <span style={{ fontSize: '0.95rem', fontWeight: 800, color: '#f8fafc' }}>
                  {incident.latitude.toFixed(5)}, {incident.longitude.toFixed(5)}
                </span>
                <a
                  href={googleMapsUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  style={{
                    color: '#38bdf8',
                    fontSize: '0.75rem',
                    fontWeight: 700,
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '0.2rem',
                    textDecoration: 'none',
                  }}
                >
                  Open Maps <ExternalLink size={11} />
                </a>
              </div>

              {incident.blackspot_info?.is_blackspot && (
                <span
                  style={{
                    background: '#dc2626',
                    color: '#ffffff',
                    padding: '0.2rem 0.6rem',
                    borderRadius: '9999px',
                    fontSize: '0.7rem',
                    fontWeight: 900,
                    textTransform: 'uppercase',
                    letterSpacing: '0.04em',
                  }}
                >
                  🚨 HIGH-RISK BLACKSPOT: {incident.blackspot_info.zone_name} ({incident.blackspot_info.incident_count} Collisions • Learned from Rakshak demo data)
                </span>
              )}
            </div>

            {/* Pre-Crash or Sentinel Alert Notice */}
            {incident.status === 'suspected' && (
              <div style={{ marginTop: '0.45rem', fontSize: '0.75rem', color: '#c7d2fe', display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                <Zap size={14} color="#a5b4fc" />
                <span>Soft Pre-Alert: Impact signature detected; 10s countdown running on device. Monitor for escalation.</span>
              </div>
            )}
            {metadata.source === 'DEAD_MAN_COLLAPSE' && (
              <div style={{ marginTop: '0.45rem', fontSize: '0.75rem', color: '#fca5a5', display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
                <Radio size={14} color="#f87171" />
                <span>Trip Sentinel Alert: Sudden telemetry silence after high-speed run ({String(metadata.last_speed_kmh || '90+')} km/h). Immediate patrol check recommended.</span>
              </div>
            )}
          </div>

          {/* Agency Coordination Strip */}
          <div
            style={{
              background: '#f8fafc',
              border: '1px solid #e2e8f0',
              borderRadius: '0.5rem',
              padding: '0.75rem 1rem',
              marginBottom: '0.85rem',
              display: 'flex',
              flexWrap: 'wrap',
              alignItems: 'center',
              justifyContent: 'space-between',
              gap: '0.75rem',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '1.25rem', flexWrap: 'wrap' }}>
              <div>
                <div style={{ fontSize: '0.7rem', color: '#64748b', fontWeight: 600, textTransform: 'uppercase' }}>
                  Admitting Trauma Center
                </div>
                <div style={{ fontSize: '0.875rem', fontWeight: 700, color: incident.accepted_hospital_name ? '#16a34a' : '#d97706' }}>
                  {incident.accepted_hospital_name ? `🏥 ${incident.accepted_hospital_name}` : 'Triage In Progress (8km Sector)'}
                </div>
              </div>

              <div>
                <div style={{ fontSize: '0.7rem', color: '#64748b', fontWeight: 600, textTransform: 'uppercase' }}>
                  Responding Ambulance
                </div>
                <div style={{ fontSize: '0.875rem', fontWeight: 700, color: '#0f172a' }}>
                  {incident.ambulance_plate ? `🚑 ${incident.ambulance_plate}` : 'Dispatching...'}
                </div>
              </div>

              <div>
                <div style={{ fontSize: '0.7rem', color: '#64748b', fontWeight: 600, textTransform: 'uppercase' }}>
                  Victim Responsiveness
                </div>
                <div style={{ fontSize: '0.875rem', fontWeight: 700, color: riderUnresponsive ? '#dc2626' : '#16a34a' }}>
                  {riderUnresponsive ? '⚠️ Unresponsive' : '✓ Responsive'}
                </div>
              </div>

              <div>
                <div style={{ fontSize: '0.7rem', color: '#64748b', fontWeight: 600, textTransform: 'uppercase' }}>
                  Health Card On File
                </div>
                <div style={{ fontSize: '0.875rem', fontWeight: 700, color: policeHasCard ? '#16a34a' : '#64748b' }}>
                  {policeHasCard === null ? 'Checking...' : policeHasCard ? '✓ YES (Encrypted on File)' : 'NO'}
                </div>
              </div>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              {incident.ambulance_driver_phone && (
                <a
                  href={`tel:${incident.ambulance_driver_phone}`}
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '0.3rem',
                    padding: '0.4rem 0.75rem',
                    background: '#1e293b',
                    color: '#ffffff',
                    borderRadius: '0.375rem',
                    fontSize: '0.75rem',
                    fontWeight: 700,
                    textDecoration: 'none',
                  }}
                >
                  <Phone size={12} /> Contact Ambulance
                </a>
              )}

              {localImageUrl && (
                <button
                  type="button"
                  onClick={() => setIsLightboxOpen(true)}
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '0.3rem',
                    padding: '0.4rem 0.75rem',
                    background: '#0f172a',
                    color: '#ffffff',
                    border: 'none',
                    borderRadius: '0.375rem',
                    fontSize: '0.75rem',
                    fontWeight: 600,
                    cursor: 'pointer',
                  }}
                >
                  <Camera size={12} color="#ef4444" /> Scene Photo ({photoTransport === 'webrtc' ? 'P2P' : 'Relay'})
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ──────────────────────────────────────────────────────────────────────────
          "BACKSIDE" ADVANCED DIAGNOSTICS & TELEMETRY ACCORDION DECK
      ────────────────────────────────────────────────────────────────────────── */}
      <div style={{ marginTop: '0.75rem', borderTop: '1px dashed #cbd5e1', paddingTop: '0.75rem' }}>
        <button
          type="button"
          onClick={() => setIsBacksideExpanded(!isBacksideExpanded)}
          style={{
            width: '100%',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '0.65rem 0.95rem',
            background: isBacksideExpanded ? '#0f172a' : '#f8fafc',
            color: isBacksideExpanded ? '#ffffff' : '#475569',
            border: `1px solid ${isBacksideExpanded ? '#1e293b' : '#e2e8f0'}`,
            borderRadius: '0.5rem',
            cursor: 'pointer',
            fontSize: '0.8rem',
            fontWeight: 700,
            transition: 'all 0.2s ease',
          }}
        >
          <span style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <Layers size={15} color={isBacksideExpanded ? '#38bdf8' : '#64748b'} />
            <span>
              {viewMode === 'hospital'
                ? '🔬 Full Clinical Diagnostics & Telemetry (Backside Deck)'
                : '📋 Tactical Forensics & Agency Triage Network (Backside Deck)'}
            </span>
          </span>

          <span style={{ display: 'flex', alignItems: 'center', gap: '0.35rem', fontSize: '0.75rem' }}>
            <span>{isBacksideExpanded ? 'Hide Diagnostics' : 'Expand Diagnostics'}</span>
            {isBacksideExpanded ? <ChevronUp size={15} /> : <ChevronDown size={15} />}
          </span>
        </button>

        {/* Expanded Backside Tabs & Content */}
        {isBacksideExpanded && (
          <div
            style={{
              marginTop: '0.65rem',
              background: '#f8fafc',
              border: '1px solid #cbd5e1',
              borderRadius: '0.5rem',
              padding: '1rem',
            }}
          >
            {/* Tab Navigation Strip */}
            <div style={{ display: 'flex', gap: '0.4rem', borderBottom: '1px solid #cbd5e1', paddingBottom: '0.5rem', marginBottom: '0.85rem', flexWrap: 'wrap' }}>
              {viewMode === 'hospital' ? (
                <>
                  <button
                    type="button"
                    onClick={() => setBacksideTab('clinical')}
                    style={{
                      padding: '0.4rem 0.85rem',
                      borderRadius: '0.375rem',
                      border: 'none',
                      background: backsideTab === 'clinical' ? '#1e293b' : '#ffffff',
                      color: backsideTab === 'clinical' ? '#ffffff' : '#475569',
                      fontWeight: 700,
                      fontSize: '0.75rem',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '0.35rem',
                    }}
                  >
                    <Stethoscope size={13} /> Biomechanics & Organ Trauma
                  </button>

                  <button
                    type="button"
                    onClick={() => setBacksideTab('kinematics')}
                    style={{
                      padding: '0.4rem 0.85rem',
                      borderRadius: '0.375rem',
                      border: 'none',
                      background: backsideTab === 'kinematics' ? '#1e293b' : '#ffffff',
                      color: backsideTab === 'kinematics' ? '#ffffff' : '#475569',
                      fontWeight: 700,
                      fontSize: '0.75rem',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '0.35rem',
                    }}
                  >
                    <Activity size={13} /> Physical Kinematics & Factors
                  </button>

                  <button
                    type="button"
                    onClick={() => setBacksideTab('route')}
                    style={{
                      padding: '0.4rem 0.85rem',
                      borderRadius: '0.375rem',
                      border: 'none',
                      background: backsideTab === 'route' ? '#1e293b' : '#ffffff',
                      color: backsideTab === 'route' ? '#ffffff' : '#475569',
                      fontWeight: 700,
                      fontSize: '0.75rem',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '0.35rem',
                    }}
                  >
                    <Navigation size={13} /> Route & Highway Transit
                  </button>
                </>
              ) : (
                <>
                  <button
                    type="button"
                    onClick={() => setBacksideTab('hospitals')}
                    style={{
                      padding: '0.4rem 0.85rem',
                      borderRadius: '0.375rem',
                      border: 'none',
                      background: backsideTab === 'hospitals' ? '#1e293b' : '#ffffff',
                      color: backsideTab === 'hospitals' ? '#ffffff' : '#475569',
                      fontWeight: 700,
                      fontSize: '0.75rem',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '0.35rem',
                    }}
                  >
                    <Building2 size={13} /> 8km Hospital Network ({matchedHospitalsList.length})
                  </button>

                  <button
                    type="button"
                    onClick={() => setBacksideTab('kinematics')}
                    style={{
                      padding: '0.4rem 0.85rem',
                      borderRadius: '0.375rem',
                      border: 'none',
                      background: backsideTab === 'kinematics' ? '#1e293b' : '#ffffff',
                      color: backsideTab === 'kinematics' ? '#ffffff' : '#475569',
                      fontWeight: 700,
                      fontSize: '0.75rem',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '0.35rem',
                    }}
                  >
                    <Activity size={13} /> Impact Forensics & Telemetry
                  </button>

                  <button
                    type="button"
                    onClick={() => setBacksideTab('route')}
                    style={{
                      padding: '0.4rem 0.85rem',
                      borderRadius: '0.375rem',
                      border: 'none',
                      background: backsideTab === 'route' ? '#1e293b' : '#ffffff',
                      color: backsideTab === 'route' ? '#ffffff' : '#475569',
                      fontWeight: 700,
                      fontSize: '0.75rem',
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '0.35rem',
                    }}
                  >
                    <Navigation size={13} /> Tactical Route Map
                  </button>
                </>
              )}
            </div>

            {/* TAB CONTENT: Biomechanics & Organ Trauma */}
            {backsideTab === 'clinical' && (
              <div>
                <div style={{ background: '#0f172a', color: '#f8fafc', borderRadius: '0.5rem', padding: '0.85rem', marginBottom: '0.85rem' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '0.65rem' }}>
                    <span style={{ fontSize: '0.8rem', fontWeight: 800, color: '#38bdf8' }}>
                      KINETIC TRAUMA ESTIMATE (ILLUSTRATIVE / SIMULATED)
                    </span>
                    <span style={{ fontSize: '0.7rem', color: '#94a3b8' }}>
                      Orientation: {biomechanics.impact_direction} ({biomechanics.pdof_degrees}°)
                    </span>
                  </div>

                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(120px, 1fr))', gap: '0.5rem', marginBottom: '0.65rem' }}>
                    <div style={{ background: 'rgba(255,255,255,0.05)', padding: '0.4rem 0.6rem', borderRadius: '4px' }}>
                      <div style={{ fontSize: '0.65rem', color: '#94a3b8' }}>Delta-V Drop</div>
                      <div style={{ fontSize: '1rem', fontWeight: 800, color: '#f87171' }}>{biomechanics.deltaV_kmh.toFixed(1)} km/h</div>
                    </div>
                    <div style={{ background: 'rgba(255,255,255,0.05)', padding: '0.4rem 0.6rem', borderRadius: '4px' }}>
                      <div style={{ fontSize: '0.65rem', color: '#94a3b8' }}>Energy Dissipated</div>
                      <div style={{ fontSize: '1rem', fontWeight: 800, color: '#fbbf24' }}>{biomechanics.energy_dissipation_kj.toFixed(1)} kJ</div>
                    </div>
                    <div style={{ background: 'rgba(255,255,255,0.05)', padding: '0.4rem 0.6rem', borderRadius: '4px' }}>
                      <div style={{ fontSize: '0.65rem', color: '#94a3b8' }}>Predicted ISS Score</div>
                      <div style={{ fontSize: '1rem', fontWeight: 800, color: '#ef4444' }}>{biomechanics.iss_score_estimate}</div>
                    </div>
                  </div>

                  <div style={{ fontSize: '0.725rem', fontWeight: 700, color: '#cbd5e1', marginBottom: '0.4rem' }}>
                    Organ Trauma Probability Matrix:
                  </div>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.35rem' }}>
                    {biomechanics.predicted_injuries.map((inj, i) => (
                      <div key={i} style={{ background: 'rgba(255,255,255,0.03)', padding: '0.4rem 0.6rem', borderRadius: '4px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <div>
                          <div style={{ fontSize: '0.75rem', fontWeight: 700, color: '#ffffff' }}>{inj.injury}</div>
                          <div style={{ fontSize: '0.65rem', color: '#38bdf8' }}>Action: {inj.clinical_action}</div>
                        </div>
                        <span style={{ background: inj.severity === 'CRITICAL' ? '#dc2626' : '#d97706', color: '#fff', fontSize: '0.65rem', fontWeight: 800, padding: '0.1rem 0.4rem', borderRadius: '3px' }}>
                          {inj.risk_percent}% Risk
                        </span>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Phase 18: Emergency Health Card Panel (Hospital View, Break-Glass Protected) */}
                <div style={{ background: '#ffffff', border: '1px solid #e2e8f0', borderRadius: '0.5rem', padding: '0.85rem' }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.65rem', flexWrap: 'wrap', gap: '0.5rem' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.45rem' }}>
                      <ShieldCheck size={16} color="#059669" />
                      <span style={{ fontSize: '0.8rem', fontWeight: 800, color: '#0f172a' }}>
                        EMERGENCY HEALTH CARD
                      </span>
                      {healthCardMode === 'MOCK' && (
                        <span
                          style={{
                            background: '#fef3c7',
                            color: '#b45309',
                            fontSize: '0.65rem',
                            fontWeight: 800,
                            padding: '0.1rem 0.4rem',
                            borderRadius: '4px',
                            border: '1px solid #fde68a',
                          }}
                        >
                          MOCK DATA
                        </span>
                      )}
                    </div>
                    {unlockedAudit && (
                      <span style={{ fontSize: '0.68rem', color: '#64748b' }}>
                        Audited access by <strong>{unlockedAudit.by}</strong> at {unlockedAudit.at}
                      </span>
                    )}
                  </div>

                  {!isThisHospitalAccepted ? (
                    <div
                      style={{
                        background: '#f8fafc',
                        border: '1px dashed #cbd5e1',
                        borderRadius: '0.375rem',
                        padding: '1rem',
                        textAlign: 'center',
                      }}
                    >
                      <Lock size={20} color="#64748b" style={{ margin: '0 auto 0.4rem' }} />
                      <div style={{ fontSize: '0.8rem', fontWeight: 700, color: '#334155' }}>
                        Confidential Emergency Medical Records
                      </div>
                      <div style={{ fontSize: '0.725rem', color: '#64748b', marginTop: '0.2rem' }}>
                        Health card data is restricted under ABDM regulations. Accessible only after your trauma center accepts this case.
                      </div>
                    </div>
                  ) : healthCard === undefined ? (
                    <div
                      style={{
                        background: '#fffbeb',
                        border: '1.5px solid #fde68a',
                        borderRadius: '0.375rem',
                        padding: '0.85rem',
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '0.65rem' }}>
                        <div style={{ maxWidth: '420px' }}>
                          <div style={{ fontSize: '0.775rem', fontWeight: 800, color: '#92400e', display: 'flex', alignItems: 'center', gap: '0.3rem' }}>
                            <Lock size={14} />
                            <span>CLINICAL BREAK-GLASS AUTHORIZATION REQUIRED</span>
                          </div>
                          <div style={{ fontSize: '0.725rem', color: '#78350f', marginTop: '0.2rem' }}>
                            Under NHA/ABDM policy, viewing patient health data requires documented clinical justification. Every access is logged to the regulatory audit log.
                          </div>
                        </div>
                        <button
                          type="button"
                          onClick={() => setIsBreakGlassModalOpen(true)}
                          style={{
                            background: '#dc2626',
                            color: '#ffffff',
                            border: 'none',
                            borderRadius: '0.375rem',
                            padding: '0.45rem 0.85rem',
                            fontSize: '0.75rem',
                            fontWeight: 800,
                            cursor: 'pointer',
                            boxShadow: '0 1px 3px rgba(220, 38, 38, 0.3)',
                          }}
                        >
                          🔓 Break Glass to View
                        </button>
                      </div>
                    </div>
                  ) : healthCard === null ? (
                    <div
                      style={{
                        background: '#f8fafc',
                        border: '1px solid #e2e8f0',
                        borderRadius: '0.375rem',
                        padding: '1rem',
                        textAlign: 'center',
                        color: '#64748b',
                        fontSize: '0.775rem',
                      }}
                    >
                      No health data available. The patient has not linked ABHA or shared emergency information.
                    </div>
                  ) : (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                      {/* Identity Row */}
                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '0.5rem' }}>
                        <div style={{ background: '#f8fafc', padding: '0.45rem 0.65rem', borderRadius: '4px', border: '1px solid #f1f5f9' }}>
                          <div style={{ fontSize: '0.65rem', color: '#64748b', fontWeight: 600 }}>PATIENT NAME</div>
                          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '0.4rem', marginTop: '0.15rem' }}>
                            <span style={{ fontSize: '0.8rem', fontWeight: 700, color: '#0f172a' }}>
                              {healthCard.name.status === 'AVAILABLE' ? healthCard.name.value : 'Unregistered'}
                            </span>
                            {renderFieldProvenanceChip(healthCard.name)}
                          </div>
                        </div>

                        <div style={{ background: '#f8fafc', padding: '0.45rem 0.65rem', borderRadius: '4px', border: '1px solid #f1f5f9' }}>
                          <div style={{ fontSize: '0.65rem', color: '#64748b', fontWeight: 600 }}>AGE / GENDER</div>
                          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '0.4rem', marginTop: '0.15rem' }}>
                            <span style={{ fontSize: '0.8rem', fontWeight: 700, color: '#0f172a' }}>
                              {healthCard.age_gender.status === 'AVAILABLE' ? healthCard.age_gender.value : 'N/A'}
                            </span>
                            {renderFieldProvenanceChip(healthCard.age_gender)}
                          </div>
                        </div>

                        <div style={{ background: '#f8fafc', padding: '0.45rem 0.65rem', borderRadius: '4px', border: '1px solid #f1f5f9' }}>
                          <div style={{ fontSize: '0.65rem', color: '#64748b', fontWeight: 600 }}>ABHA ADDRESS</div>
                          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '0.4rem', marginTop: '0.15rem' }}>
                            <span style={{ fontSize: '0.8rem', fontWeight: 700, color: '#0f172a', fontFamily: 'monospace' }}>
                              {healthCard.abha_address.status === 'AVAILABLE' ? healthCard.abha_address.value : 'None'}
                            </span>
                            {renderFieldProvenanceChip(healthCard.abha_address)}
                          </div>
                        </div>
                      </div>

                      {/* Clinical Row */}
                      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '0.5rem' }}>
                        <div style={{ background: '#f8fafc', padding: '0.45rem 0.65rem', borderRadius: '4px', border: '1px solid #f1f5f9' }}>
                          <div style={{ fontSize: '0.65rem', color: '#64748b', fontWeight: 600 }}>BLOOD GROUP</div>
                          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '0.4rem', marginTop: '0.15rem' }}>
                            <span style={{ fontSize: '0.85rem', fontWeight: 800, color: '#dc2626' }}>
                              {healthCard.blood_group.status === 'AVAILABLE' ? healthCard.blood_group.value : 'N/A'}
                            </span>
                            {renderFieldProvenanceChip(healthCard.blood_group)}
                          </div>
                        </div>

                        <div style={{ background: '#f8fafc', padding: '0.45rem 0.65rem', borderRadius: '4px', border: '1px solid #f1f5f9' }}>
                          <div style={{ fontSize: '0.65rem', color: '#64748b', fontWeight: 600 }}>NOTTO ORGAN DONOR</div>
                          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '0.4rem', marginTop: '0.15rem' }}>
                            <span style={{ fontSize: '0.8rem', fontWeight: 700, color: healthCard.organ_donor_status.value ? '#15803d' : '#64748b' }}>
                              {healthCard.organ_donor_status.status === 'AVAILABLE'
                                ? (healthCard.organ_donor_status.value ? '✓ YES (Registered)' : 'No')
                                : 'N/A'}
                            </span>
                            {renderFieldProvenanceChip(healthCard.organ_donor_status)}
                          </div>
                        </div>

                        <div style={{ background: '#f8fafc', padding: '0.45rem 0.65rem', borderRadius: '4px', border: '1px solid #f1f5f9' }}>
                          <div style={{ fontSize: '0.65rem', color: '#64748b', fontWeight: 600 }}>LAST RECORD UPDATE</div>
                          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '0.4rem', marginTop: '0.15rem' }}>
                            <span style={{ fontSize: '0.75rem', fontWeight: 600, color: '#334155' }}>
                              {healthCard.last_updated ? new Date(healthCard.last_updated).toLocaleString() : 'Never'}
                            </span>
                          </div>
                        </div>
                      </div>

                      {/* Detailed Medical Rows: Allergies, Conditions, Medications */}
                      <div style={{ background: '#f8fafc', padding: '0.5rem 0.65rem', borderRadius: '4px', border: '1px solid #f1f5f9' }}>
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '0.4rem', marginBottom: '0.2rem' }}>
                          <span style={{ fontSize: '0.65rem', color: '#dc2626', fontWeight: 700 }}>CRITICAL ALLERGIES</span>
                          {renderFieldProvenanceChip(healthCard.allergies)}
                        </div>
                        <div style={{ fontSize: '0.75rem', color: '#0f172a', fontWeight: 600 }}>
                          {healthCard.allergies.status === 'AVAILABLE' && healthCard.allergies.value.length > 0
                            ? healthCard.allergies.value.join(', ')
                            : 'No known allergies reported'}
                        </div>
                      </div>

                      <div style={{ background: '#f8fafc', padding: '0.5rem 0.65rem', borderRadius: '4px', border: '1px solid #f1f5f9' }}>
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '0.4rem', marginBottom: '0.2rem' }}>
                          <span style={{ fontSize: '0.65rem', color: '#64748b', fontWeight: 700 }}>CHRONIC CONDITIONS</span>
                          {renderFieldProvenanceChip(healthCard.chronic_conditions)}
                        </div>
                        <div style={{ fontSize: '0.75rem', color: '#0f172a', fontWeight: 600 }}>
                          {healthCard.chronic_conditions.status === 'AVAILABLE' && healthCard.chronic_conditions.value.length > 0
                            ? healthCard.chronic_conditions.value.join(', ')
                            : 'None reported'}
                        </div>
                      </div>

                      <div style={{ background: '#f8fafc', padding: '0.5rem 0.65rem', borderRadius: '4px', border: '1px solid #f1f5f9' }}>
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '0.4rem', marginBottom: '0.2rem' }}>
                          <span style={{ fontSize: '0.65rem', color: '#64748b', fontWeight: 700 }}>CURRENT MEDICATIONS</span>
                          {renderFieldProvenanceChip(healthCard.current_medications)}
                        </div>
                        <div style={{ fontSize: '0.75rem', color: '#0f172a', fontWeight: 600 }}>
                          {healthCard.current_medications.status === 'AVAILABLE' && healthCard.current_medications.value.length > 0
                            ? healthCard.current_medications.value.join(', ')
                            : 'None reported'}
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* TAB CONTENT: Kinematics & Measured Factors */}
            {backsideTab === 'kinematics' && (
              <div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(130px, 1fr))', gap: '0.5rem', marginBottom: '0.75rem' }}>
                  <div style={{ background: '#ffffff', padding: '0.5rem 0.75rem', borderRadius: '0.375rem', border: '1px solid #e2e8f0' }}>
                    <div style={{ fontSize: '0.65rem', color: '#64748b', fontWeight: 600 }}>PEAK DECELERATION</div>
                    <div style={{ fontSize: '1.05rem', fontWeight: 800, color: isSaturated ? '#e11d48' : '#0f172a' }}>
                      {measuredPeakG.toFixed(1)}g {isSaturated && <span style={{ fontSize: '0.65rem', color: '#e11d48' }}>(Saturated)</span>}
                    </div>
                  </div>
                  <div style={{ background: '#ffffff', padding: '0.5rem 0.75rem', borderRadius: '0.375rem', border: '1px solid #e2e8f0' }}>
                    <div style={{ fontSize: '0.65rem', color: '#64748b', fontWeight: 600 }}>SPEED DROP (ΔV)</div>
                    <div style={{ fontSize: '1.05rem', fontWeight: 800, color: '#0f172a' }}>{speedDropKmh.toFixed(1)} km/h</div>
                  </div>
                  <div style={{ background: '#ffffff', padding: '0.5rem 0.75rem', borderRadius: '0.375rem', border: '1px solid #e2e8f0' }}>
                    <div style={{ fontSize: '0.65rem', color: '#64748b', fontWeight: 600 }}>IMPACT DURATION</div>
                    <div style={{ fontSize: '1.05rem', fontWeight: 800, color: '#0f172a' }}>{impactDurationMs} ms</div>
                  </div>
                  <div style={{ background: '#ffffff', padding: '0.5rem 0.75rem', borderRadius: '0.375rem', border: '1px solid #e2e8f0' }}>
                    <div style={{ fontSize: '0.65rem', color: '#64748b', fontWeight: 600 }}>CRASH CONFIDENCE</div>
                    <div style={{ fontSize: '1.05rem', fontWeight: 800, color: confidenceScore >= 80 ? '#16a34a' : '#d97706' }}>{confidenceScore}%</div>
                  </div>
                </div>

                <div style={{ background: '#ffffff', border: '1px solid #e2e8f0', borderRadius: '0.375rem', padding: '0.75rem', fontSize: '0.75rem' }}>
                  <strong>Measured Factor Breakdown:</strong>
                  <ul style={{ margin: '0.25rem 0 0 1rem', padding: 0, color: '#475569' }}>
                    {contributingFactors.map((factor, idx) => (
                      <li key={idx}>{factor}</li>
                    ))}
                  </ul>
                </div>
              </div>
            )}

            {/* TAB CONTENT: 8km Hospital Network (Police) */}
            {backsideTab === 'hospitals' && (
              <div>
                <div style={{ fontSize: '0.75rem', color: '#64748b', marginBottom: '0.5rem' }}>
                  Trauma centers within 8km radius dispatched for this incident:
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.4rem' }}>
                  {matchedHospitalsList.map((h, idx) => (
                    <div
                      key={h.id || idx}
                      style={{
                        background: '#ffffff',
                        border: '1px solid #e2e8f0',
                        borderRadius: '0.375rem',
                        padding: '0.5rem 0.75rem',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        flexWrap: 'wrap',
                        gap: '0.5rem',
                      }}
                    >
                      <div>
                        <strong style={{ fontSize: '0.85rem', color: '#0f172a' }}>{h.name}</strong>
                        <div style={{ fontSize: '0.7rem', color: '#64748b' }}>{h.address}</div>
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <span style={{ fontSize: '0.8rem', fontWeight: 700, color: '#dc2626' }}>
                          ~{h.distance_km ? Number(h.distance_km).toFixed(1) : '3.2'} km
                        </span>
                        <a
                          href={`tel:${h.phone}`}
                          style={{
                            padding: '0.25rem 0.5rem',
                            background: '#f1f5f9',
                            color: '#334155',
                            borderRadius: '3px',
                            fontSize: '0.7rem',
                            fontWeight: 600,
                            textDecoration: 'none',
                          }}
                        >
                          <Phone size={10} style={{ display: 'inline' }} /> Call
                        </a>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* TAB CONTENT: Transit Route Map */}
            {backsideTab === 'route' && acceptedHospital && (
              <div>
                <IncidentRouteMap
                  incidentId={incident.id}
                  incidentLat={incident.latitude}
                  incidentLng={incident.longitude}
                  hospital={acceptedHospital}
                  ambulanceLocation={incident.ambulance_location}
                />
              </div>
            )}
          </div>
        )}
      </div>

      {/* ──────────────────────────────────────────────────────────────────────────
          MODALS: LIGHTBOX & REJECTION MODAL
      ────────────────────────────────────────────────────────────────────────── */}

      {/* Lightbox Modal */}
      {isLightboxOpen && localImageUrl && (
        <div
          onClick={() => setIsLightboxOpen(false)}
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(0, 0, 0, 0.85)',
            zIndex: 9999,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '1.5rem',
            backdropFilter: 'blur(8px)',
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              position: 'relative',
              maxWidth: '900px',
              maxHeight: '90vh',
              background: '#0f172a',
              borderRadius: '0.75rem',
              overflow: 'hidden',
              boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.5)',
              display: 'flex',
              flexDirection: 'column',
            }}
          >
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '0.75rem 1rem',
                background: '#1e293b',
                color: '#ffffff',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontSize: '0.85rem', fontWeight: 700 }}>
                <Camera size={16} color="#ef4444" />
                <span>EPHEMERAL INCIDENT PHOTO (RAM BUFFER ONLY)</span>
                <span
                  style={{
                    background: photoTransport === 'webrtc' ? '#047857' : '#1e3a8a',
                    color: '#ffffff',
                    fontSize: '0.65rem',
                    padding: '0.15rem 0.45rem',
                    borderRadius: '4px',
                    fontWeight: 600,
                  }}
                >
                  {photoTransport === 'webrtc' ? '⚡ WebRTC P2P' : '🔄 WebSocket Relay'}
                </span>
              </div>
              <button
                type="button"
                onClick={() => setIsLightboxOpen(false)}
                style={{
                  background: 'transparent',
                  border: 'none',
                  color: '#ffffff',
                  cursor: 'pointer',
                }}
              >
                <X size={18} />
              </button>
            </div>
            <div style={{ padding: '1rem', display: 'flex', justifyContent: 'center' }}>
              <img
                src={localImageUrl}
                alt="High Resolution Incident Triage"
                onContextMenu={(e) => e.preventDefault()}
                onDragStart={(e) => e.preventDefault()}
                style={{
                  maxWidth: '100%',
                  maxHeight: '75vh',
                  objectFit: 'contain',
                  borderRadius: '0.375rem',
                }}
              />
            </div>
          </div>
        </div>
      )}

      {/* Rejection Modal */}
      {isRejectModalOpen && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(0, 0, 0, 0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 9999,
          }}
        >
          <div
            style={{
              background: '#ffffff',
              borderRadius: '0.5rem',
              padding: '1.5rem',
              width: '100%',
              maxWidth: '420px',
              boxShadow: '0 20px 25px -5px rgba(0,0,0,0.1)',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1rem' }}>
              <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 700, color: '#0f172a' }}>
                Decline Emergency Dispatch
              </h3>
              <button
                type="button"
                onClick={() => setIsRejectModalOpen(false)}
                style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748b' }}
              >
                <X size={18} />
              </button>
            </div>

            <p style={{ fontSize: '0.825rem', color: '#64748b', marginBottom: '1rem' }}>
              Select clinical reason for declining incident {incident.id.slice(0, 8)}. The system will automatically escalate dispatch to the next nearest facility.
            </p>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem', marginBottom: '1.25rem' }}>
              {REJECTION_REASONS.map((reason) => (
                <label
                  key={reason}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '0.5rem',
                    fontSize: '0.85rem',
                    color: '#334155',
                    cursor: 'pointer',
                  }}
                >
                  <input
                    type="radio"
                    name={`reject_reason_${incident.id}`}
                    value={reason}
                    checked={selectedRejectReason === reason}
                    onChange={() => setSelectedRejectReason(reason)}
                    style={{ accentColor: '#dc2626' }}
                  />
                  <span>{reason}</span>
                </label>
              ))}
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.75rem' }}>
              <button
                type="button"
                onClick={() => setIsRejectModalOpen(false)}
                disabled={isSubmittingReject}
                style={{
                  padding: '0.5rem 1rem',
                  borderRadius: '0.375rem',
                  border: '1px solid #cbd5e1',
                  background: '#ffffff',
                  color: '#475569',
                  fontSize: '0.85rem',
                  fontWeight: 600,
                  cursor: 'pointer',
                }}
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={async () => {
                  if (!onReject) return;
                  setIsSubmittingReject(true);
                  try {
                    await onReject(incident.id, selectedRejectReason);
                    setIsRejectModalOpen(false);
                  } catch (err) {
                    console.error('Failed to submit rejection:', err);
                  } finally {
                    setIsSubmittingReject(false);
                  }
                }}
                disabled={isSubmittingReject}
                style={{
                  padding: '0.5rem 1.1rem',
                  borderRadius: '0.375rem',
                  border: 'none',
                  background: isSubmittingReject ? '#fca5a5' : '#dc2626',
                  color: '#ffffff',
                  fontSize: '0.85rem',
                  fontWeight: 600,
                  cursor: isSubmittingReject ? 'not-allowed' : 'pointer',
                }}
              >
                {isSubmittingReject ? 'Declining...' : 'Confirm Decline'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Phase 18: Break-Glass Authorization Modal */}
      {isBreakGlassModalOpen && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(15, 23, 42, 0.75)',
            backdropFilter: 'blur(4px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 9999,
            padding: '1rem',
          }}
          onClick={(e) => {
            if (e.target === e.currentTarget && !isSubmittingBreakGlass) {
              setIsBreakGlassModalOpen(false);
            }
          }}
        >
          <div
            style={{
              background: '#ffffff',
              borderRadius: '0.75rem',
              maxWidth: '520px',
              width: '100%',
              padding: '1.5rem',
              boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.25)',
              border: '1.5px solid #f87171',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <div style={{ background: '#fee2e2', padding: '0.4rem', borderRadius: '0.375rem', color: '#dc2626' }}>
                  <Lock size={20} />
                </div>
                <h3 style={{ margin: 0, fontSize: '1.05rem', fontWeight: 800, color: '#0f172a' }}>
                  Break-Glass Clinical Access
                </h3>
              </div>
              <button
                type="button"
                onClick={() => setIsBreakGlassModalOpen(false)}
                disabled={isSubmittingBreakGlass}
                style={{
                  background: 'none',
                  border: 'none',
                  color: '#94a3b8',
                  cursor: 'pointer',
                  padding: '0.25rem',
                }}
              >
                <X size={20} />
              </button>
            </div>

            <div
              style={{
                background: '#fff1f2',
                border: '1px solid #fecdd3',
                borderRadius: '0.375rem',
                padding: '0.75rem 0.85rem',
                marginBottom: '1rem',
                fontSize: '0.775rem',
                color: '#9f1239',
                lineHeight: 1.45,
              }}
            >
              <strong>REGULATORY AUDIT MANDATE (ABDM / NHA):</strong> Accessing an emergency patient's health records without live OTP is restricted to verified clinical personnel treating acute trauma. Your staff username, hospital ID, timestamp, and clinical justification will be permanently written to the compliance audit table.
            </div>

            {breakGlassError && (
              <div
                style={{
                  background: '#fef2f2',
                  border: '1px solid #f87171',
                  color: '#b91c1c',
                  padding: '0.65rem 0.85rem',
                  borderRadius: '0.375rem',
                  fontSize: '0.8rem',
                  marginBottom: '1rem',
                  fontWeight: 600,
                }}
              >
                ⚠️ {breakGlassError}
              </div>
            )}

            <div style={{ marginBottom: '1.25rem' }}>
              <label
                htmlFor={`break_glass_reason_${incident.id}`}
                style={{ display: 'block', fontSize: '0.8rem', fontWeight: 700, color: '#334155', marginBottom: '0.4rem' }}
              >
                Mandatory Clinical Reason / Justification:
              </label>
              <textarea
                id={`break_glass_reason_${incident.id}`}
                value={breakGlassReason}
                onChange={(e) => setBreakGlassReason(e.target.value)}
                placeholder="e.g. Acute polytrauma resuscitation in ED, unconscious victim, urgent blood crossmatch required"
                rows={3}
                disabled={isSubmittingBreakGlass}
                style={{
                  width: '100%',
                  padding: '0.6rem 0.75rem',
                  borderRadius: '0.375rem',
                  border: '1px solid #cbd5e1',
                  fontSize: '0.85rem',
                  fontFamily: 'inherit',
                  boxSizing: 'border-box',
                  outline: 'none',
                }}
              />
              <div style={{ fontSize: '0.7rem', color: '#64748b', marginTop: '0.25rem' }}>
                Minimum 5 characters. Must reflect authentic clinical necessity.
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.75rem' }}>
              <button
                type="button"
                onClick={() => setIsBreakGlassModalOpen(false)}
                disabled={isSubmittingBreakGlass}
                style={{
                  padding: '0.5rem 1rem',
                  borderRadius: '0.375rem',
                  border: '1px solid #cbd5e1',
                  background: '#ffffff',
                  color: '#475569',
                  fontSize: '0.85rem',
                  fontWeight: 600,
                  cursor: 'pointer',
                }}
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleConfirmBreakGlass}
                disabled={isSubmittingBreakGlass || breakGlassReason.trim().length < 5}
                style={{
                  padding: '0.5rem 1.15rem',
                  borderRadius: '0.375rem',
                  border: 'none',
                  background: isSubmittingBreakGlass || breakGlassReason.trim().length < 5 ? '#fca5a5' : '#dc2626',
                  color: '#ffffff',
                  fontSize: '0.85rem',
                  fontWeight: 700,
                  cursor: isSubmittingBreakGlass || breakGlassReason.trim().length < 5 ? 'not-allowed' : 'pointer',
                  boxShadow: '0 2px 4px rgba(220, 38, 38, 0.25)',
                }}
              >
                {isSubmittingBreakGlass ? 'Authorizing & Decrypting...' : 'Authorize Break-Glass'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
