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
  Maximize2,
  X,
  CheckCircle2,
  Lock,
  Check,
} from 'lucide-react';
import { IncidentPayload, Hospital } from '../types';
import { BACKEND_API_BASE } from '../services/socket';

const REJECTION_REASONS = [
  'No ICU capacity',
  'No trauma specialist',
  'At capacity',
  'Other',
];

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
  const [isHospitalsExpanded, setIsHospitalsExpanded] = useState<boolean>(false);
  const [isLightboxOpen, setIsLightboxOpen] = useState<boolean>(false);
  const [isRejectModalOpen, setIsRejectModalOpen] = useState<boolean>(false);
  const [selectedRejectReason, setSelectedRejectReason] = useState<string>('No ICU capacity');
  const [isSubmittingReject, setIsSubmittingReject] = useState<boolean>(false);
  const [localImageUrl, setLocalImageUrl] = useState<string | null>(incident.imageUrl || null);

  // Auto-fetch ephemeral photo from Redis cache if missing or received after mount
  useEffect(() => {
    if (incident.imageUrl) {
      setLocalImageUrl(incident.imageUrl);
      return;
    }

    let isMounted = true;
    const fetchImage = async () => {
      try {
        const res = await fetch(`${BACKEND_API_BASE}/incidents/${incident.id}/image`);
        if (res.ok) {
          const data = await res.json();
          if (isMounted && data.imageUrl) {
            setLocalImageUrl(data.imageUrl);
          }
        }
      } catch {
        // Non-fatal cache lookup failure
      }
    };

    fetchImage();
    const timer = setTimeout(fetchImage, 2500);
    return () => {
      isMounted = false;
      clearTimeout(timer);
    };
  }, [incident.id, incident.imageUrl]);

  const formattedTime = new Date(incident.created_at).toLocaleTimeString(
    undefined,
    {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    }
  );

  const googleMapsUrl = `https://www.google.com/maps/search/?api=1&query=${incident.latitude},${incident.longitude}`;

  // Urban Road Distance vs Geodesic Straight-Line Distance
  const straightLineKm =
    incident.distance_km !== null ? Number(incident.distance_km) : null;

  // Indian urban road network factor (~1.6x straight-line distance due to urban grid/flyovers)
  const roadDistanceKm =
    incident.road_distance_km !== undefined && incident.road_distance_km !== null
      ? Number(incident.road_distance_km)
      : straightLineKm !== null
        ? Math.round(straightLineKm * 1.6 * 10) / 10
        : null;

  const matchedHospitalsList: Hospital[] = incident.matched_hospitals || [];
  const traumaCentersCount =
    incident.matched_hospitals_count !== undefined
      ? incident.matched_hospitals_count
      : matchedHospitalsList.length;

  const isAccepted = incident.status === 'accepted' || !!incident.accepted_hospital_id;
  const isThisHospitalAccepted =
    isAccepted &&
    !!currentHospitalId &&
    incident.accepted_hospital_id === currentHospitalId;
  const isLockedByOther =
    (incident.case_locked || (isAccepted && !isThisHospitalAccepted && !!incident.accepted_hospital_id)) &&
    viewMode === 'hospital';
  const isEscalated = incident.status === 'escalated' || !!incident.escalated;
  const isUnmatched = incident.status === 'unmatched';

  const cardBorderLeft = isAccepted
    ? '5px solid #16a34a'
    : isLockedByOther
      ? '5px solid #94a3b8'
      : isEscalated
        ? '5px solid #ea580c'
        : isUnmatched
          ? '5px solid #b91c1c'
          : '5px solid #ef4444';

  const cardBorder = isAccepted
    ? '1px solid #bbf7d0'
    : isLockedByOther
      ? '1px solid #e2e8f0'
      : isEscalated
        ? '1px solid #fed7aa'
        : isUnmatched
          ? '1px solid #fecaca'
          : '1px solid #fee2e2';

  return (
    <div
      style={{
        background: '#ffffff',
        border: cardBorder,
        borderLeft: cardBorderLeft,
        borderRadius: '0.625rem',
        padding: '1.25rem',
        boxShadow:
          '0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -1px rgba(0, 0, 0, 0.03)',
        marginBottom: '1rem',
        transition: 'all 0.2s ease',
        opacity: isLockedByOther ? 0.88 : 1,
      }}
    >
      {/* Header Row: Status badge, ID, and Time */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          flexWrap: 'wrap',
          gap: '0.5rem',
          borderBottom: '1px solid #f1f5f9',
          paddingBottom: '0.75rem',
          marginBottom: '0.85rem',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          {isAccepted ? (
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
                fontWeight: 700,
                textTransform: 'uppercase',
                letterSpacing: '0.05em',
              }}
            >
              <CheckCircle2 size={13} />
              {viewMode === 'hospital' && isThisHospitalAccepted
                ? 'ACCEPTED BY YOUR FACILITY'
                : incident.accepted_hospital_name
                  ? `ACCEPTED • ${incident.accepted_hospital_name}`
                  : 'ACCEPTED'}
            </span>
          ) : isLockedByOther ? (
            <span
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.35rem',
                background: '#f1f5f9',
                color: '#64748b',
                padding: '0.25rem 0.65rem',
                borderRadius: '9999px',
                fontSize: '0.75rem',
                fontWeight: 700,
                textTransform: 'uppercase',
                letterSpacing: '0.05em',
              }}
            >
              <Lock size={13} />
              CASE LOCKED ({incident.accepted_hospital_name || 'Accepted by another facility'})
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
                fontWeight: 700,
                textTransform: 'uppercase',
                letterSpacing: '0.05em',
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
                fontWeight: 700,
                textTransform: 'uppercase',
                letterSpacing: '0.05em',
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
                fontWeight: 700,
                textTransform: 'uppercase',
                letterSpacing: '0.05em',
              }}
            >
              <AlertTriangle size={13} />
              BROADCASTING (TRIAGE ACTIVE)
            </span>
          )}
          <span
            style={{
              fontFamily: 'monospace',
              fontSize: '0.8rem',
              color: '#64748b',
              background: '#f8fafc',
              padding: '0.2rem 0.45rem',
              borderRadius: '0.25rem',
              border: '1px solid #e2e8f0',
            }}
            title={incident.id}
          >
            ID: {incident.id.slice(0, 8)}...
          </span>
        </div>

        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '0.35rem',
            color: '#64748b',
            fontSize: '0.8rem',
          }}
        >
          <Clock size={14} />
          <span>{formattedTime}</span>
        </div>
      </div>

      {/* Main Details Grid */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
          gap: '0.85rem',
          marginBottom: '1rem',
        }}
      >
        {/* Distance Banner (Showing Both Road Distance & Aerial Straight-Line) */}
        <div
          style={{
            background: '#fef2f2',
            padding: '0.65rem 0.85rem',
            borderRadius: '0.375rem',
            border: '1px solid #fecaca',
          }}
        >
          <div
            style={{
              fontSize: '0.725rem',
              color: '#991b1b',
              fontWeight: 600,
              textTransform: 'uppercase',
              marginBottom: '0.2rem',
            }}
          >
            {viewMode === 'hospital'
              ? 'Road Distance to Hospital'
              : 'Nearest Trauma Facility'}
          </div>
          <div
            style={{
              display: 'flex',
              alignItems: 'baseline',
              gap: '0.4rem',
            }}
          >
            <div
              style={{
                fontSize: '1.25rem',
                fontWeight: 800,
                color: '#dc2626',
                display: 'flex',
                alignItems: 'center',
                gap: '0.35rem',
              }}
            >
              <Compass size={18} />
              {roadDistanceKm !== null
                ? `~${roadDistanceKm.toFixed(1)} km Road`
                : 'Calculating...'}
            </div>
          </div>
          {straightLineKm !== null && (
            <div
              style={{
                fontSize: '0.725rem',
                color: '#7f1d1d',
                marginTop: '0.15rem',
              }}
            >
              Direct Aerial Line: <strong>{straightLineKm.toFixed(2)} km</strong>
            </div>
          )}
        </div>

        {/* GPS Coordinates */}
        <div
          style={{
            background: '#f8fafc',
            padding: '0.65rem 0.85rem',
            borderRadius: '0.375rem',
            border: '1px solid #e2e8f0',
          }}
        >
          <div
            style={{
              fontSize: '0.725rem',
              color: '#475569',
              fontWeight: 600,
              textTransform: 'uppercase',
              marginBottom: '0.2rem',
            }}
          >
            Incident Crash Location
          </div>
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
            }}
          >
            <span
              style={{
                fontFamily: 'monospace',
                fontSize: '0.85rem',
                color: '#1e293b',
                fontWeight: 600,
              }}
            >
              <MapPin size={14} style={{ display: 'inline', marginRight: 4 }} />
              {incident.latitude.toFixed(5)}, {incident.longitude.toFixed(5)}
            </span>
            <a
              href={googleMapsUrl}
              target="_blank"
              rel="noopener noreferrer"
              style={{
                color: '#2563eb',
                fontSize: '0.75rem',
                display: 'inline-flex',
                alignItems: 'center',
                gap: '0.2rem',
                textDecoration: 'none',
                fontWeight: 600,
              }}
            >
              Maps <ExternalLink size={12} />
            </a>
          </div>
        </div>

        {/* Matched Hospitals (For Police View) - Interactive Expandable Trigger */}
        {viewMode === 'police' && (
          <div
            onClick={() => setIsHospitalsExpanded(!isHospitalsExpanded)}
            style={{
              background: '#f0fdf4',
              padding: '0.65rem 0.85rem',
              borderRadius: '0.375rem',
              border: '1px solid #bbf7d0',
              cursor: 'pointer',
              userSelect: 'none',
              transition: 'background 0.15s ease',
              boxShadow: isHospitalsExpanded ? '0 0 0 2px #86efac' : 'none',
            }}
            title="Click to view all alerted trauma hospitals with distances and contacts"
          >
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
              }}
            >
              <div
                style={{
                  fontSize: '0.725rem',
                  color: '#166534',
                  fontWeight: 600,
                  textTransform: 'uppercase',
                }}
              >
                Trauma Triage Ring (8km)
              </div>
              <span
                style={{
                  fontSize: '0.75rem',
                  color: '#15803d',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.2rem',
                  fontWeight: 600,
                }}
              >
                {isHospitalsExpanded ? 'Hide Details' : 'Click to View'}
                {isHospitalsExpanded ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
              </span>
            </div>
            <div
              style={{
                fontSize: '1.05rem',
                fontWeight: 700,
                color: '#15803d',
                display: 'flex',
                alignItems: 'center',
                gap: '0.35rem',
                marginTop: '0.2rem',
              }}
            >
              <Building2 size={16} />
              {traumaCentersCount > 0 ? (
                <>
                  {traumaCentersCount} Trauma Center
                  {traumaCentersCount === 1 ? '' : 's'} Alerted
                </>
              ) : (
                '0 Trauma Centers (within 8km)'
              )}
            </div>
          </div>
        )}
      </div>

      {/* Police View: Expanded Alerted Hospitals Accordion Panel */}
      {viewMode === 'police' && isHospitalsExpanded && (
        <div
          style={{
            background: '#f8fafc',
            border: '1px solid #bbf7d0',
            borderRadius: '0.5rem',
            padding: '0.85rem',
            marginBottom: '1rem',
          }}
        >
          <div
            style={{
              fontSize: '0.8rem',
              fontWeight: 700,
              color: '#166534',
              marginBottom: '0.65rem',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
            }}
          >
            <span style={{ display: 'flex', alignItems: 'center', gap: '0.35rem' }}>
              <Building2 size={15} />
              Alerted Hospitals Dispatched for Incident {incident.id.slice(0, 8)}:
            </span>
            <span style={{ fontSize: '0.75rem', color: '#64748b' }}>
              Sorted by proximity
            </span>
          </div>

          {matchedHospitalsList.length > 0 ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
              {matchedHospitalsList.map((h, idx) => {
                const hStraightKm = h.distance_km ? Number(h.distance_km) : 0;
                const hRoadKm = h.road_distance_km ?? Math.round(hStraightKm * 1.6 * 10) / 10;
                const routeUrl = `https://www.google.com/maps/dir/?api=1&origin=${incident.latitude},${incident.longitude}&destination=${h.latitude},${h.longitude}`;

                return (
                  <div
                    key={h.id || idx}
                    style={{
                      background: '#ffffff',
                      border: '1px solid #e2e8f0',
                      borderRadius: '0.375rem',
                      padding: '0.65rem 0.85rem',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      flexWrap: 'wrap',
                      gap: '0.5rem',
                    }}
                  >
                    <div style={{ flex: '1 1 300px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.45rem', flexWrap: 'wrap' }}>
                        <span
                          style={{
                            background: '#e0f2fe',
                            color: '#0369a1',
                            fontWeight: 700,
                            fontSize: '0.75rem',
                            padding: '0.1rem 0.35rem',
                            borderRadius: '0.2rem',
                          }}
                        >
                          #{idx + 1}
                        </span>
                        <strong style={{ fontSize: '0.9rem', color: '#0f172a' }}>
                          {h.name}
                        </strong>
                        {h.has_trauma_center && (
                          <span
                            style={{
                              background: '#dcfce7',
                              color: '#15803d',
                              fontSize: '0.65rem',
                              fontWeight: 700,
                              padding: '0.1rem 0.4rem',
                              borderRadius: '9999px',
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: '0.2rem',
                            }}
                          >
                            <ShieldCheck size={11} /> Level 1 Trauma
                          </span>
                        )}
                      </div>
                      <div
                        style={{
                          fontSize: '0.75rem',
                          color: '#64748b',
                          marginTop: '0.2rem',
                        }}
                      >
                        {h.address}
                      </div>
                    </div>

                    {/* Distance & Actions */}
                    <div
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: '0.85rem',
                        flexWrap: 'wrap',
                      }}
                    >
                      <div style={{ textAlign: 'right' }}>
                        <div
                          style={{
                            fontSize: '0.95rem',
                            fontWeight: 800,
                            color: '#dc2626',
                          }}
                        >
                          ~{hRoadKm.toFixed(1)} km Road
                        </div>
                        <div style={{ fontSize: '0.7rem', color: '#64748b' }}>
                          {hStraightKm.toFixed(2)} km direct line
                        </div>
                      </div>

                      <a
                        href={`tel:${h.phone}`}
                        style={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '0.25rem',
                          padding: '0.35rem 0.65rem',
                          background: '#f1f5f9',
                          color: '#334155',
                          borderRadius: '0.375rem',
                          textDecoration: 'none',
                          fontSize: '0.75rem',
                          fontWeight: 600,
                          border: '1px solid #cbd5e1',
                        }}
                        title={`Call ${h.name}`}
                      >
                        <Phone size={12} /> Call
                      </a>

                      <a
                        href={routeUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        style={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '0.25rem',
                          padding: '0.35rem 0.65rem',
                          background: '#2563eb',
                          color: '#ffffff',
                          borderRadius: '0.375rem',
                          textDecoration: 'none',
                          fontSize: '0.75rem',
                          fontWeight: 600,
                        }}
                        title="Open Google Maps Turn-by-Turn Route from Incident to this Hospital"
                      >
                        <Navigation size={12} /> Route
                      </a>
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            <div style={{ padding: '0.75rem', color: '#64748b', fontSize: '0.85rem', textAlign: 'center' }}>
              No trauma centers detected within 8km radius for this crash coordinates.
            </div>
          )}
        </div>
      )}

      {/* Victim Telemetry (if available) */}
      {incident.victim_metadata && (
        <div
          style={{
            background: '#f8fafc',
            border: '1px solid #e2e8f0',
            borderRadius: '0.375rem',
            padding: '0.5rem 0.75rem',
            marginBottom: '0.85rem',
            fontSize: '0.8rem',
            color: '#334155',
          }}
        >
          <span style={{ fontWeight: 600, color: '#0f172a' }}>
            Telemetry Meta:{' '}
          </span>
          {typeof incident.victim_metadata === 'object'
            ? Object.entries(incident.victim_metadata).map(([k, v]) => (
                <span
                  key={k}
                  style={{
                    display: 'inline-block',
                    background: '#e2e8f0',
                    padding: '0.1rem 0.35rem',
                    borderRadius: '0.2rem',
                    marginRight: '0.35rem',
                    fontSize: '0.75rem',
                  }}
                >
                  {k}: {String(v)}
                </span>
              ))
            : JSON.stringify(incident.victim_metadata)}
        </div>
      )}

      {/* Facility Rejection Notices (Visible to Police and Hospitals) */}
      {incident.rejections && incident.rejections.length > 0 && (
        <div
          style={{
            background: '#fff1f2',
            border: '1px solid #fecdd3',
            borderRadius: '0.375rem',
            padding: '0.65rem 0.85rem',
            marginBottom: '0.85rem',
          }}
        >
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '0.45rem',
              color: '#be123c',
              fontSize: '0.75rem',
              fontWeight: 700,
              textTransform: 'uppercase',
              letterSpacing: '0.04em',
              marginBottom: '0.35rem',
            }}
          >
            <AlertTriangle size={14} />
            <span>Facility Rejection Notices ({incident.rejections.length})</span>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.35rem' }}>
            {incident.rejections.map((rej, rIdx) => (
              <div
                key={`${rej.hospital_id}-${rIdx}`}
                style={{
                  fontSize: '0.8rem',
                  color: '#881337',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  flexWrap: 'wrap',
                  gap: '0.5rem',
                  padding: '0.2rem 0',
                  borderTop: rIdx > 0 ? '1px dashed #fecdd3' : 'none',
                }}
              >
                <span>
                  <strong>{rej.hospital_name}</strong> declined dispatch:{' '}
                  <span
                    style={{
                      background: '#ffe4e6',
                      color: '#9f1239',
                      padding: '0.1rem 0.4rem',
                      borderRadius: '0.25rem',
                      fontWeight: 600,
                      fontSize: '0.75rem',
                    }}
                  >
                    {rej.reason}
                  </span>
                </span>
                <span style={{ fontSize: '0.7rem', color: '#9f1239' }}>
                  {new Date(rej.created_at).toLocaleTimeString([], {
                    hour: '2-digit',
                    minute: '2-digit',
                    second: '2-digit',
                  })}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Phase 7: Hospital Action Section (Accept / Decline Emergency) */}
      {viewMode === 'hospital' && (
        <div style={{ marginBottom: '1rem' }}>
          {isThisHospitalAccepted ? (
            <div
              style={{
                background: '#dcfce7',
                border: '1px solid #86efac',
                borderRadius: '0.5rem',
                padding: '0.75rem 1rem',
                display: 'flex',
                alignItems: 'center',
                gap: '0.75rem',
                color: '#15803d',
                fontWeight: 600,
                fontSize: '0.875rem',
              }}
            >
              <CheckCircle2 size={20} />
              <div>
                <div>EMERGENCY ACCEPTED BY YOUR FACILITY</div>
                <div style={{ fontSize: '0.75rem', fontWeight: 400, color: '#166534' }}>
                  Trauma bay alerted • Ambulance dispatched • Case locked across network
                </div>
              </div>
            </div>
          ) : isLockedByOther ? (
            <div
              style={{
                background: '#f8fafc',
                border: '1px solid #e2e8f0',
                borderRadius: '0.5rem',
                padding: '0.75rem 1rem',
                display: 'flex',
                alignItems: 'center',
                gap: '0.75rem',
                color: '#64748b',
                fontWeight: 600,
                fontSize: '0.875rem',
              }}
            >
              <Lock size={18} color="#94a3b8" />
              <div>
                <div>CASE LOCKED — ACCEPTED BY ANOTHER FACILITY</div>
                <div style={{ fontSize: '0.75rem', fontWeight: 400, color: '#64748b' }}>
                  {incident.accepted_hospital_name
                    ? `Emergency response assigned to ${incident.accepted_hospital_name}.`
                    : 'Another trauma center has accepted this emergency.'}
                </div>
              </div>
            </div>
          ) : (
            <div
              style={{
                background: '#f8fafc',
                border: '1px solid #e2e8f0',
                borderRadius: '0.5rem',
                padding: '0.75rem 1rem',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                flexWrap: 'wrap',
                gap: '0.75rem',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <span
                  style={{
                    fontSize: '0.8rem',
                    fontWeight: 600,
                    color: '#334155',
                  }}
                >
                  Trauma Triage Response:
                </span>
                <span
                  style={{
                    fontSize: '0.75rem',
                    color: '#64748b',
                  }}
                >
                  Review patient vitals and accept dispatch
                </span>
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
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
                    padding: '0.45rem 0.85rem',
                    fontSize: '0.8rem',
                    fontWeight: 600,
                    cursor: 'pointer',
                    transition: 'all 0.15s ease',
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.background = '#fef2f2';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.background = '#ffffff';
                  }}
                >
                  <X size={14} />
                  Reject
                </button>

                <button
                  type="button"
                  onClick={() => onAccept && onAccept(incident.id)}
                  disabled={isAccepting}
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '0.4rem',
                    background: isAccepting ? '#86efac' : '#16a34a',
                    color: '#ffffff',
                    border: 'none',
                    borderRadius: '0.375rem',
                    padding: '0.45rem 1.1rem',
                    fontSize: '0.8rem',
                    fontWeight: 700,
                    cursor: isAccepting ? 'not-allowed' : 'pointer',
                    boxShadow: '0 2px 4px rgba(22, 163, 74, 0.25)',
                    transition: 'all 0.15s ease',
                  }}
                  onMouseEnter={(e) => {
                    if (!isAccepting) e.currentTarget.style.background = '#15803d';
                  }}
                  onMouseLeave={(e) => {
                    if (!isAccepting) e.currentTarget.style.background = '#16a34a';
                  }}
                >
                  <Check size={15} />
                  {isAccepting ? 'Accepting...' : 'Accept Emergency'}
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Police View Acceptance Banner */}
      {viewMode === 'police' && isAccepted && (
        <div
          style={{
            background: '#dcfce7',
            border: '1px solid #86efac',
            borderRadius: '0.5rem',
            padding: '0.65rem 0.85rem',
            display: 'flex',
            alignItems: 'center',
            gap: '0.6rem',
            color: '#15803d',
            fontSize: '0.8rem',
            fontWeight: 600,
            marginBottom: '0.85rem',
          }}
        >
          <CheckCircle2 size={16} />
          <span>
            Accepted by:{' '}
            <strong>{incident.accepted_hospital_name || 'Designated Trauma Center'}</strong>
            {' • Ambulance en route'}
          </span>
        </div>
      )}

      {/* Phase 6: Zero-Storage Ephemeral Photo Stream */}
      {localImageUrl ? (
        <>
          <div
            onClick={() => setIsLightboxOpen(true)}
            style={{
              marginTop: '0.85rem',
              borderRadius: '0.625rem',
              overflow: 'hidden',
              border: '1px solid #fee2e2',
              background: '#090d16',
              position: 'relative',
              cursor: 'pointer',
              boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)',
            }}
            title="Click to open full-screen portrait photo inspection"
          >
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '0.45rem 0.85rem',
                background: 'rgba(15, 23, 42, 0.88)',
                color: '#f8fafc',
                fontSize: '0.725rem',
                fontWeight: 600,
                position: 'absolute',
                top: 0,
                left: 0,
                right: 0,
                zIndex: 2,
                backdropFilter: 'blur(6px)',
                borderBottom: '1px solid rgba(255, 255, 255, 0.1)',
              }}
            >
              <span style={{ display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
                <Camera size={14} color="#ef4444" />
                LIVE INTAKE STREAM (RAM ONLY)
              </span>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <span
                  style={{
                    background: 'rgba(255, 255, 255, 0.15)',
                    color: '#e2e8f0',
                    padding: '0.15rem 0.45rem',
                    borderRadius: '0.25rem',
                    fontSize: '0.65rem',
                    fontWeight: 600,
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '0.25rem',
                  }}
                >
                  <Maximize2 size={11} /> Click to Enlarge
                </span>
                <span
                  style={{
                    background: '#dc2626',
                    color: '#ffffff',
                    padding: '0.15rem 0.5rem',
                    borderRadius: '9999px',
                    fontSize: '0.65rem',
                    fontWeight: 700,
                    letterSpacing: '0.05em',
                  }}
                >
                  EPHEMERAL • TTL 15 MIN
                </span>
              </div>
            </div>

            {/*
              SECURITY RATIONALE (Zero-Storage / Non-Downloadable Live Stream):
              Context menu (right-click save) and drag-out are strictly disabled on the image element
              to enforce Rakshak-AI's zero-persistent-storage and victim privacy guarantees.
              The photo is ephemeral in-memory visual triage telemetry that resides strictly in RAM
              and must not be saved to disk, downloaded, or exported.
            */}
            <div
              style={{
                paddingTop: '2.5rem',
                paddingBottom: '0.75rem',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                background: '#090d16',
                minHeight: '260px',
              }}
            >
              <img
                src={localImageUrl}
                alt={`Incident triage intake ${incident.id}`}
                onContextMenu={(e) => e.preventDefault()}
                onDragStart={(e) => e.preventDefault()}
                style={{
                  maxWidth: '100%',
                  maxHeight: '440px',
                  height: 'auto',
                  objectFit: 'contain',
                  display: 'block',
                  borderRadius: '0.375rem',
                  userSelect: 'none',
                  WebkitUserSelect: 'none',
                  boxShadow: '0 8px 16px rgba(0,0,0,0.5)',
                }}
              />
            </div>
          </div>

          {/* Fullscreen Lightbox Modal for Medical/Police High-Resolution Triage */}
          {isLightboxOpen && (
            <div
              onClick={() => setIsLightboxOpen(false)}
              style={{
                position: 'fixed',
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                background: 'rgba(3, 7, 18, 0.92)',
                backdropFilter: 'blur(8px)',
                zIndex: 9999,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                padding: '1rem',
              }}
            >
              {/* Modal Window Header */}
              <div
                onClick={(e) => e.stopPropagation()}
                style={{
                  width: '100%',
                  maxWidth: '920px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '0.75rem 1.25rem',
                  background: 'rgba(15, 23, 42, 0.95)',
                  borderRadius: '0.5rem 0.5rem 0 0',
                  border: '1px solid rgba(255, 255, 255, 0.12)',
                  borderBottom: 'none',
                  color: '#ffffff',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem' }}>
                  <span
                    style={{
                      background: '#dc2626',
                      color: '#ffffff',
                      padding: '0.2rem 0.55rem',
                      borderRadius: '9999px',
                      fontSize: '0.7rem',
                      fontWeight: 800,
                      letterSpacing: '0.05em',
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '0.35rem',
                    }}
                  >
                    <Camera size={13} />
                    FULL RESOLUTION TRIAGE STREAM
                  </span>
                  <span style={{ fontSize: '0.85rem', fontWeight: 600, color: '#f8fafc' }}>
                    Incident ID: {incident.id}
                  </span>
                </div>

                <button
                  onClick={() => setIsLightboxOpen(false)}
                  style={{
                    background: 'rgba(255, 255, 255, 0.15)',
                    border: '1px solid rgba(255, 255, 255, 0.2)',
                    color: '#ffffff',
                    borderRadius: '0.375rem',
                    padding: '0.4rem 0.75rem',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '0.35rem',
                    fontSize: '0.8rem',
                    fontWeight: 700,
                  }}
                  title="Close viewer"
                >
                  <X size={16} /> Close
                </button>
              </div>

              {/* Modal Image Body with unconstrained portrait height */}
              <div
                onClick={(e) => e.stopPropagation()}
                style={{
                  width: '100%',
                  maxWidth: '920px',
                  maxHeight: '82vh',
                  background: '#020617',
                  borderRadius: '0 0 0.5rem 0.5rem',
                  border: '1px solid rgba(255, 255, 255, 0.12)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  padding: '1rem',
                  overflow: 'auto',
                }}
              >
                <img
                  src={localImageUrl}
                  alt={`Full resolution triage intake ${incident.id}`}
                  onContextMenu={(e) => e.preventDefault()}
                  onDragStart={(e) => e.preventDefault()}
                  style={{
                    maxWidth: '100%',
                    maxHeight: '78vh',
                    width: 'auto',
                    height: 'auto',
                    objectFit: 'contain',
                    borderRadius: '0.375rem',
                    userSelect: 'none',
                    WebkitUserSelect: 'none',
                    boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.7)',
                  }}
                />
              </div>

              <div
                style={{
                  marginTop: '0.65rem',
                  color: '#94a3b8',
                  fontSize: '0.75rem',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.5rem',
                }}
              >
                <span>Zero-Persistent-Storage Stream • In-Memory RAM Only • Click outside to close</span>
              </div>
            </div>
          )}
        </>
      ) : (
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '0.5rem',
            padding: '0.5rem 0.75rem',
            background: '#f8fafc',
            borderRadius: '0.375rem',
            fontSize: '0.75rem',
            color: '#64748b',
            border: '1px dashed #cbd5e1',
          }}
        >
          <Camera size={14} />
          <span>
            <strong>Crash Scene Visual:</strong> Awaiting live intake camera stream...
          </span>
        </div>
      )}

      {/* Phase 7: Rejection Reason Selection Modal */}
      {isRejectModalOpen && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            backgroundColor: 'rgba(15, 23, 42, 0.65)',
            backdropFilter: 'blur(3px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 10000,
            padding: '1rem',
          }}
          onClick={() => !isSubmittingReject && setIsRejectModalOpen(false)}
        >
          <div
            style={{
              background: '#ffffff',
              borderRadius: '0.75rem',
              maxWidth: '460px',
              width: '100%',
              padding: '1.5rem',
              boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.2)',
              position: 'relative',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                marginBottom: '1rem',
                paddingBottom: '0.75rem',
                borderBottom: '1px solid #f1f5f9',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <div
                  style={{
                    background: '#fee2e2',
                    color: '#dc2626',
                    padding: '0.35rem',
                    borderRadius: '0.375rem',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  <X size={18} />
                </div>
                <h3 style={{ margin: 0, fontSize: '1.05rem', fontWeight: 700, color: '#0f172a' }}>
                  Decline Emergency Case
                </h3>
              </div>
              <button
                type="button"
                onClick={() => setIsRejectModalOpen(false)}
                disabled={isSubmittingReject}
                style={{
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  color: '#94a3b8',
                  padding: '0.25rem',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <X size={18} />
              </button>
            </div>

            <p style={{ margin: '0 0 1rem 0', fontSize: '0.85rem', color: '#64748b', lineHeight: 1.4 }}>
              Select a reason for declining this emergency dispatch. The Rakshak auto-escalation engine
              will immediately widen the triage search radius to the next available trauma center.
            </p>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem', marginBottom: '1.25rem' }}>
              {REJECTION_REASONS.map((reason) => (
                <label
                  key={reason}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '0.65rem',
                    padding: '0.65rem 0.85rem',
                    borderRadius: '0.375rem',
                    border: selectedRejectReason === reason ? '1.5px solid #dc2626' : '1px solid #e2e8f0',
                    background: selectedRejectReason === reason ? '#fef2f2' : '#ffffff',
                    cursor: 'pointer',
                    fontSize: '0.875rem',
                    fontWeight: selectedRejectReason === reason ? 600 : 500,
                    color: selectedRejectReason === reason ? '#991b1b' : '#334155',
                    transition: 'all 0.15s ease',
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
