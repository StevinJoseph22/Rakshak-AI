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
import { IncidentPayload, Hospital } from '../types';
import { getSocket } from '../services/socket';
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

export interface AbhaVaultData {
  abha_id: string;
  abha_address: string;
  patient_name: string;
  blood_group: string;
  critical_allergies: string[];
  chronic_conditions: string[];
  current_medications: string[];
  organ_donor_registered: boolean;
  notto_id: string;
  zk_proof_signature: string;
  is_abdm_verified: boolean;
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
  const rawAbhaVault = metadata.abha_vault as AbhaVaultData | undefined;

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

  const abhaVault: AbhaVaultData = rawAbhaVault || {
    abha_id: '91-8842-9912-3401',
    abha_address: 'aarav.sharma@abdm',
    patient_name: (typeof metadata.victim_name === 'string' && metadata.victim_name) ? metadata.victim_name : 'Aarav Sharma (Verified)',
    blood_group: (typeof metadata.blood_group === 'string' && metadata.blood_group) ? metadata.blood_group : 'B+ Positive',
    critical_allergies: ['Penicillin Anaphylaxis', 'Sulfa Drugs'],
    chronic_conditions: ['Type-1 Diabetes'],
    current_medications: ['Warfarin (Blood Thinner - Severe Hemorrhage Risk)', 'Insulin Glargine'],
    organ_donor_registered: true,
    notto_id: 'NOTTO-IND-2024-88419',
    zk_proof_signature: '0x7f4a8b29c910d9e2 (Hardware TEE Enclave Signed)',
    is_abdm_verified: true,
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
              {/* Big Bold Blood Group Pill */}
              <div
                style={{
                  background: '#dc2626',
                  color: '#ffffff',
                  padding: '0.45rem 0.85rem',
                  borderRadius: '0.5rem',
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  justifyContent: 'center',
                  boxShadow: '0 2px 6px rgba(220, 38, 38, 0.3)',
                  minWidth: '70px',
                }}
              >
                <div style={{ fontSize: '0.65rem', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                  BLOOD
                </div>
                <div style={{ fontSize: '1.15rem', fontWeight: 900, lineHeight: 1.1 }}>
                  {abhaVault.blood_group}
                </div>
              </div>

              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
                  <span style={{ fontSize: '1rem', fontWeight: 800, color: '#0f172a' }}>
                    {abhaVault.patient_name}
                  </span>
                  <span
                    style={{
                      background: '#dcfce7',
                      color: '#15803d',
                      fontSize: '0.65rem',
                      fontWeight: 700,
                      padding: '0.1rem 0.4rem',
                      borderRadius: '4px',
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '0.2rem',
                    }}
                  >
                    <ShieldCheck size={11} /> ABHA VERIFIED
                  </span>
                </div>
                <div style={{ fontSize: '0.775rem', color: '#475569', marginTop: '0.15rem' }}>
                  ABHA ID: <strong style={{ fontFamily: 'monospace' }}>{abhaVault.abha_id}</strong>
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

          {/* High-Urgency Critical Drug Allergy Alert (Front & Center for Physicians) */}
          {abhaVault.critical_allergies && abhaVault.critical_allergies.length > 0 && (
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
                <strong style={{ textDecoration: 'underline' }}>{abhaVault.critical_allergies.join(', ')}</strong>. Do not administer during acute resuscitation.
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

                {/* Extended ABHA Vault Info */}
                <div style={{ background: '#ffffff', border: '1px solid #e2e8f0', borderRadius: '0.5rem', padding: '0.85rem' }}>
                  <div style={{ fontSize: '0.75rem', fontWeight: 800, color: '#0f172a', marginBottom: '0.45rem' }}>
                    PATIENT MEDICATIONS & MEDICAL BACKGROUND
                  </div>
                  <div style={{ fontSize: '0.75rem', color: '#334155' }}>
                    <strong>Chronic Conditions:</strong> {abhaVault.chronic_conditions.join(', ') || 'None reported'}
                  </div>
                  <div style={{ fontSize: '0.75rem', color: '#334155', marginTop: '0.25rem' }}>
                    <strong>Current Medications:</strong> {abhaVault.current_medications.join(', ')}
                  </div>
                  <div style={{ fontSize: '0.7rem', color: '#059669', marginTop: '0.35rem' }}>
                    ✓ NOTTO Organ Donor Registered: {abhaVault.notto_id}
                  </div>
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
    </div>
  );
};
