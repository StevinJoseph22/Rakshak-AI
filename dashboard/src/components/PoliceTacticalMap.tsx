import React, { useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { IncidentPayload } from '../types';
import { ShieldAlert, X, Phone } from 'lucide-react';

interface PoliceTacticalMapProps {
  incidents: IncidentPayload[];
  selectedIncidentId?: string | null;
  onSelectIncident?: (incident: IncidentPayload) => void;
  onImageClick?: (imageUrl: string) => void;
}

function createMarkerIcon(status: string, ambulanceId?: string | null) {
  let color = '#f59e0b';
  let emoji = '⚡';
  if (status === 'escalated') {
    color = '#ea580c';
    emoji = '⚠️';
  } else if (status === 'accepted') {
    color = '#10b981';
    emoji = ambulanceId ? '🚑' : '✓';
  } else if (status === 'unmatched') {
    color = '#ef4444';
    emoji = '✕';
  }

  return L.divIcon({
    className: 'police-tactical-icon',
    html: `
      <div style="
        background-color: ${color};
        width: 34px;
        height: 34px;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        border: 2.5px solid #ffffff;
        box-shadow: 0 4px 10px rgba(0,0,0,0.4);
        font-size: 16px;
        cursor: pointer;
        transition: transform 0.2s;
      ">
        ${emoji}
      </div>
    `,
    iconSize: [34, 34],
    iconAnchor: [17, 17],
    popupAnchor: [0, -18],
  });
}

export const PoliceTacticalMap: React.FC<PoliceTacticalMapProps> = ({
  incidents,
  selectedIncidentId,
  onSelectIncident,
  onImageClick,
}) => {
  const mapContainerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<L.Map | null>(null);
  const markersGroupRef = useRef<L.LayerGroup | null>(null);
  const activeRoutePolylineRef = useRef<L.Polyline | null>(null);
  const activeRouteLayerGroupRef = useRef<L.LayerGroup | null>(null);
  const [activeIncident, setActiveIncident] = useState<IncidentPayload | null>(null);
  const [routeInfo, setRouteInfo] = useState<{
    distanceKm: number;
    durationMin: number;
    delayMin: number | null;
    condition: 'Clear' | 'Moderate' | 'Heavy';
  } | null>(null);

  // Sync selectedIncidentId with activeIncident or auto-select first incident
  useEffect(() => {
    if (selectedIncidentId) {
      const match = incidents.find((i) => i.id === selectedIncidentId);
      if (match) {
        setActiveIncident(match);
        if (mapRef.current) {
          mapRef.current.flyTo([match.latitude, match.longitude], 14, { duration: 0.8 });
        }
      }
    } else if (incidents.length > 0 && !activeIncident) {
      setActiveIncident(incidents[0]);
    }
  }, [selectedIncidentId, incidents, activeIncident]);

  // Ensure map tiles are fully refreshed whenever incidents list updates
  useEffect(() => {
    if (mapRef.current) {
      const timer = setTimeout(() => mapRef.current?.invalidateSize(), 200);
      return () => clearTimeout(timer);
    }
  }, [incidents.length]);

  // Initialize Leaflet map
  useEffect(() => {
    if (!mapContainerRef.current) return;

    const map = L.map(mapContainerRef.current, {
      center: [12.9716, 77.5946], // Bengaluru center
      zoom: 12,
      zoomControl: false,
    });

    L.control.zoom({ position: 'topright' }).addTo(map);

    // High performance tile server (zero API key, zero watermark)
    L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}', {
      maxZoom: 19,
      attribution: '&copy; OpenStreetMap contributors &copy; Esri',
    }).addTo(map);

    const markersGroup = L.layerGroup().addTo(map);
    markersGroupRef.current = markersGroup;
    mapRef.current = map;

    const resizeTimer = setTimeout(() => {
      map.invalidateSize();
    }, 250);

    return () => {
      clearTimeout(resizeTimer);
      map.remove();
      mapRef.current = null;
    };
  }, []);

  // Render incident markers dynamically
  useEffect(() => {
    if (!mapRef.current || !markersGroupRef.current) return;
    const map = mapRef.current;
    const markersGroup = markersGroupRef.current;

    markersGroup.clearLayers();

    incidents.forEach((incident) => {
      const icon = createMarkerIcon(incident.status || 'broadcasting', incident.ambulance_id);
      const marker = L.marker([incident.latitude, incident.longitude], { icon });

      marker.on('click', () => {
        setActiveIncident(incident);
        if (onSelectIncident) {
          onSelectIncident(incident);
        }
        map.flyTo([incident.latitude, incident.longitude], 14, { duration: 0.8 });
      });

      markersGroup.addLayer(marker);
    });

    // Auto-fit if incidents exist
    if (incidents.length > 0 && !activeIncident) {
      const bounds = L.latLngBounds(incidents.map((i) => [i.latitude, i.longitude]));
      map.fitBounds(bounds, { padding: [60, 60], maxZoom: 14 });
    }
  }, [incidents, onSelectIncident, activeIncident]);

  // Draw real OSRM roadway route with live traffic coloring for the selected/active accepted incident
  useEffect(() => {
    if (!mapRef.current) return;
    const map = mapRef.current;

    if (activeRouteLayerGroupRef.current) {
      map.removeLayer(activeRouteLayerGroupRef.current);
      activeRouteLayerGroupRef.current = null;
    }
    if (activeRoutePolylineRef.current) {
      map.removeLayer(activeRoutePolylineRef.current);
      activeRoutePolylineRef.current = null;
    }
    setRouteInfo(null);

    if (!activeIncident) return;

    const hosp = activeIncident.accepted_hospital;
    if (hosp && hosp.latitude && hosp.longitude) {
      const osrmUrl = `https://router.project-osrm.org/route/v1/driving/${activeIncident.longitude},${activeIncident.latitude};${hosp.longitude},${hosp.latitude}?overview=full&geometries=geojson&annotations=speed,distance,duration`;

      fetch(osrmUrl)
        .then((res) => res.json())
        .then((data) => {
          if (data && data.routes && data.routes[0]) {
            const route = data.routes[0];
            const coordinates: [number, number][] = route.geometry.coordinates.map(
              (c: [number, number]) => [c[1], c[0]]
            );

            const speeds: number[] = route.legs?.[0]?.annotation?.speed || [];
            const routeLayerGroup = L.layerGroup();
            let heavyCount = 0;
            let moderateCount = 0;

            const getColorForSpeed = (speedMps: number) => {
              if (speedMps < 4.5) {
                heavyCount++;
                return '#ef4444'; // Red: Heavy Congestion (< 16 km/h)
              } else if (speedMps < 8.5) {
                moderateCount++;
                return '#f59e0b'; // Orange: Moderate Traffic (< 30 km/h)
              } else {
                return '#2563eb'; // Blue: Clear Flow
              }
            };

            if (speeds.length > 0 && speeds.length === coordinates.length - 1) {
              let currentColor = getColorForSpeed(speeds[0]);
              let currentPoints: [number, number][] = [coordinates[0]];

              for (let i = 0; i < speeds.length; i++) {
                const segColor = getColorForSpeed(speeds[i]);
                currentPoints.push(coordinates[i + 1]);

                if (segColor !== currentColor || i === speeds.length - 1) {
                  L.polyline(currentPoints, {
                    color: currentColor,
                    weight: 6,
                    opacity: 0.9,
                    lineJoin: 'round',
                  }).addTo(routeLayerGroup);

                  currentColor = segColor;
                  currentPoints = [coordinates[i + 1]];
                }
              }
            } else {
              L.polyline(coordinates, {
                color: '#2563eb',
                weight: 6,
                opacity: 0.9,
                lineJoin: 'round',
              }).addTo(routeLayerGroup);
            }

            routeLayerGroup.addTo(map);
            activeRouteLayerGroupRef.current = routeLayerGroup;

            const distM = route.distance || 0;
            const durS = route.duration || 0;
            const freeFlowSecs = distM / 12.5; // ~45 km/h urban speed
            const diffSecs = durS - freeFlowSecs;
            const delayMin = diffSecs > 60 ? Math.round(diffSecs / 60) : null;

            setRouteInfo({
              distanceKm: parseFloat((distM / 1000).toFixed(1)),
              durationMin: Math.round(durS / 60),
              delayMin,
              condition: heavyCount > 0 ? 'Heavy' : moderateCount > 2 ? 'Moderate' : 'Clear',
            });
          }
        })
        .catch(() => {
          // Fallback line
          console.warn('[PoliceTacticalMap] OSRM route fetch failed or timed out. Falling back to direct line.');
          const fallback = L.polyline(
            [
              [activeIncident.latitude, activeIncident.longitude],
              [hosp.latitude, hosp.longitude],
            ],
            { color: '#2563eb', weight: 4, dashArray: '5, 5' }
          ).addTo(map);
          activeRoutePolylineRef.current = fallback;
        });
    }
  }, [activeIncident]);

  return (
    <div
      style={{
        position: 'relative',
        width: '100%',
        height: '620px',
        borderRadius: '0.75rem',
        overflow: 'hidden',
        boxShadow: '0 4px 6px -1px rgba(0,0,0,0.1), 0 2px 4px -1px rgba(0,0,0,0.06)',
        border: '1px solid #cbd5e1',
      }}
    >
      <div ref={mapContainerRef} style={{ width: '100%', height: '100%' }} />

      {/* Floating Tactical Header Badge */}
      <div
        style={{
          position: 'absolute',
          top: '12px',
          left: '14px',
          background: 'rgba(15, 23, 42, 0.9)',
          backdropFilter: 'blur(8px)',
          borderRadius: '0.5rem',
          padding: '8px 14px',
          color: '#ffffff',
          display: 'flex',
          alignItems: 'center',
          gap: '10px',
          border: '1px solid rgba(255,255,255,0.15)',
          zIndex: 1000,
        }}
      >
        <ShieldAlert size={20} color="#38bdf8" />
        <div>
          <div style={{ fontSize: '13px', fontWeight: 800, letterSpacing: '0.04em' }}>
            POLICE CITY-WIDE TACTICAL MAP
          </div>
          <div style={{ fontSize: '11px', color: '#94a3b8' }}>
            {incidents.length} active emergencies currently tracked across Bengaluru
          </div>
        </div>
      </div>

      {/* Floating Status Filter Legend */}
      <div
        style={{
          position: 'absolute',
          bottom: '14px',
          left: '14px',
          background: 'rgba(15, 23, 42, 0.9)',
          backdropFilter: 'blur(8px)',
          borderRadius: '0.5rem',
          padding: '8px 12px',
          color: '#ffffff',
          display: 'flex',
          gap: '12px',
          fontSize: '11px',
          fontWeight: 600,
          border: '1px solid rgba(255,255,255,0.15)',
          zIndex: 1000,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
          <span style={{ width: 10, height: 10, borderRadius: '50%', backgroundColor: '#f59e0b' }} />
          Broadcasting (8km)
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
          <span style={{ width: 10, height: 10, borderRadius: '50%', backgroundColor: '#ea580c' }} />
          Escalated (20km)
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
          <span style={{ width: 10, height: 10, borderRadius: '50%', backgroundColor: '#10b981' }} />
          Accepted / En Route
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
          <span style={{ width: 10, height: 10, borderRadius: '50%', backgroundColor: '#ef4444' }} />
          Unmatched
        </div>
      </div>

      {/* Selected Incident Drawer / HUD Overlay */}
      {activeIncident && (
        <div
          style={{
            position: 'absolute',
            top: '12px',
            right: '12px',
            width: '340px',
            maxHeight: '596px',
            overflowY: 'auto',
            background: 'rgba(255, 255, 255, 0.98)',
            backdropFilter: 'blur(12px)',
            borderRadius: '0.75rem',
            padding: '16px',
            boxShadow: '0 20px 25px -5px rgba(0,0,0,0.3)',
            border: '1px solid #cbd5e1',
            zIndex: 1000,
          }}
        >
          {/* Header */}
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <div style={{ fontSize: '10px', color: '#64748b', fontWeight: 700 }}>
                INCIDENT DOSSIER
              </div>
              <div style={{ fontSize: '14px', fontWeight: 800, color: '#0f172a', fontFamily: 'monospace' }}>
                {activeIncident.id.substring(0, 13)}...
              </div>
            </div>
            <button
              onClick={() => setActiveIncident(null)}
              style={{
                background: 'transparent',
                border: 'none',
                cursor: 'pointer',
                color: '#64748b',
                padding: '2px',
              }}
            >
              <X size={18} />
            </button>
          </div>

          {/* Status Badge */}
          <div style={{ marginTop: '8px', display: 'flex', gap: '8px', alignItems: 'center', flexWrap: 'wrap' }}>
            <span
              style={{
                fontSize: '11px',
                fontWeight: 800,
                padding: '3px 8px',
                borderRadius: '4px',
                color: '#ffffff',
                backgroundColor:
                  activeIncident.status === 'accepted'
                    ? '#10b981'
                    : activeIncident.status === 'escalated'
                    ? '#ea580c'
                    : activeIncident.status === 'unmatched'
                    ? '#ef4444'
                    : '#f59e0b',
              }}
            >
              {(activeIncident.status || 'broadcasting').toUpperCase()}
            </span>
            {activeIncident.ambulance_id && (
              <span
                style={{
                  fontSize: '11px',
                  fontWeight: 700,
                  padding: '3px 8px',
                  borderRadius: '4px',
                  backgroundColor: '#dbeafe',
                  color: '#1e40af',
                }}
              >
                🚑 {activeIncident.ambulance_id}
              </span>
            )}
          </div>

          {/* Coordinates & Time */}
          <div
            style={{
              marginTop: '12px',
              padding: '8px',
              backgroundColor: '#f8fafc',
              borderRadius: '6px',
              fontSize: '11px',
              color: '#334155',
            }}
          >
            <div>
              <b>GPS:</b> {activeIncident.latitude.toFixed(5)}, {activeIncident.longitude.toFixed(5)}
            </div>
            <div>
              <b>Detected:</b> {new Date(activeIncident.created_at).toLocaleTimeString()}
            </div>
          </div>

          {/* Privacy note: Emergency contact data is the victim's own chosen contact,
              stored locally on-device and only sent alongside an actual incident dispatch via victim_metadata.
              It is never stored in a standalone contacts table or cached in Redis alongside temporary photos. */}
          {activeIncident.victim_metadata &&
            typeof activeIncident.victim_metadata === 'object' &&
            Boolean((activeIncident.victim_metadata as Record<string, unknown>).emergency_contact_name) && (
              <div
                style={{
                  marginTop: '10px',
                  padding: '8px 10px',
                  backgroundColor: '#f0fdf4',
                  border: '1px solid #86efac',
                  borderRadius: '6px',
                  fontSize: '11px',
                  color: '#14532d',
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ fontSize: '10px', fontWeight: 800, color: '#166534', textTransform: 'uppercase' }}>
                    📞 EMERGENCY CONTACT (FAMILY NOTIFIED)
                  </div>
                  <a
                    href={`tel:${String((activeIncident.victim_metadata as Record<string, unknown>).emergency_contact_phone)}`}
                    style={{
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '2px',
                      fontSize: '10px',
                      fontWeight: 700,
                      color: '#15803d',
                      textDecoration: 'none',
                    }}
                  >
                    <Phone size={10} /> Call
                  </a>
                </div>
                <div style={{ fontSize: '12px', fontWeight: 700, color: '#14532d', marginTop: '3px' }}>
                  Emergency Contact:{' '}
                  {String((activeIncident.victim_metadata as Record<string, unknown>).emergency_contact_name)}
                  {', '}
                  <span style={{ fontFamily: 'monospace' }}>
                    {String((activeIncident.victim_metadata as Record<string, unknown>).emergency_contact_phone)}
                  </span>
                </div>
                {Boolean((activeIncident.victim_metadata as Record<string, unknown>).emergency_contact_relationship) && (
                  <div style={{ fontSize: '10px', color: '#15803d', marginTop: '1px' }}>
                    Relationship: {String((activeIncident.victim_metadata as Record<string, unknown>).emergency_contact_relationship)}
                  </div>
                )}
              </div>
            )}

          {/* Accepted Hospital Details */}
          {activeIncident.accepted_hospital ? (
            <>
              <div
                style={{
                  marginTop: '12px',
                  padding: '10px',
                  backgroundColor: '#ecfdf5',
                  border: '1px solid #a7f3d0',
                  borderRadius: '6px',
                }}
              >
                <div style={{ fontSize: '11px', fontWeight: 800, color: '#065f46' }}>
                  ACCEPTED TRAUMA CENTER
                </div>
                <div style={{ fontSize: '13px', fontWeight: 700, color: '#047857', marginTop: '2px' }}>
                  {activeIncident.accepted_hospital.name}
                </div>
                <div style={{ fontSize: '11px', color: '#065f46', marginTop: '2px' }}>
                  {activeIncident.accepted_hospital.address}
                </div>
                <div style={{ fontSize: '11px', color: '#047857', marginTop: '4px', fontWeight: 600 }}>
                  📞 Emergency: {activeIncident.accepted_hospital.phone}
                </div>
              </div>

              {/* Live Traffic Route & Delay HUD */}
              {routeInfo && (
                <div
                  style={{
                    marginTop: '8px',
                    padding: '8px 10px',
                    backgroundColor: '#ffffff',
                    border: '1px solid #bfdbfe',
                    borderRadius: '6px',
                    fontSize: '11px',
                    color: '#1e3a8a',
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div style={{ fontWeight: 700 }}>
                      🛣️ {routeInfo.distanceKm} km • ~{routeInfo.durationMin} mins
                    </div>
                    {routeInfo.delayMin && routeInfo.delayMin > 0 ? (
                      <span
                        style={{
                          fontSize: '10px',
                          fontWeight: 700,
                          padding: '2px 6px',
                          borderRadius: '4px',
                          backgroundColor: routeInfo.condition === 'Heavy' ? '#fee2e2' : '#fef3c7',
                          color: routeInfo.condition === 'Heavy' ? '#991b1b' : '#92400e',
                        }}
                      >
                        +{routeInfo.delayMin}m Profile Delay
                      </span>
                    ) : (
                      <span
                        style={{
                          fontSize: '10px',
                          fontWeight: 700,
                          padding: '2px 6px',
                          borderRadius: '4px',
                          backgroundColor: '#ecfdf5',
                          color: '#065f46',
                        }}
                      >
                        Clear Flow
                      </span>
                    )}
                  </div>
                  <div
                    style={{
                      display: 'flex',
                      gap: '10px',
                      marginTop: '6px',
                      paddingTop: '6px',
                      borderTop: '1px dashed #e2e8f0',
                      fontSize: '9.5px',
                      color: '#64748b',
                    }}
                  >
                    <span style={{ display: 'flex', alignItems: 'center', gap: '3px' }}>
                      <span style={{ width: 6, height: 6, borderRadius: '50%', backgroundColor: '#2563eb' }} />
                      Clear
                    </span>
                    <span style={{ display: 'flex', alignItems: 'center', gap: '3px' }}>
                      <span style={{ width: 6, height: 6, borderRadius: '50%', backgroundColor: '#f59e0b' }} />
                      Moderate
                    </span>
                    <span style={{ display: 'flex', alignItems: 'center', gap: '3px' }}>
                      <span style={{ width: 6, height: 6, borderRadius: '50%', backgroundColor: '#ef4444' }} />
                      Congested
                    </span>
                  </div>
                </div>
              )}
            </>
          ) : (
            <div
              style={{
                marginTop: '12px',
                padding: '10px',
                backgroundColor: '#fffbeb',
                border: '1px solid #fde68a',
                borderRadius: '6px',
                fontSize: '11px',
                color: '#92400e',
              }}
            >
              ⚡ Broadcasting to trauma centers within{' '}
              {activeIncident.status === 'escalated' ? '20 km' : '8 km'}
            </div>
          )}

          {/* Rejection History Audit Trail */}
          {activeIncident.rejections && activeIncident.rejections.length > 0 && (
            <div style={{ marginTop: '12px' }}>
              <div style={{ fontSize: '11px', fontWeight: 800, color: '#b91c1c' }}>
                REJECTION AUDIT TRAIL ({activeIncident.rejections.length})
              </div>
              <div style={{ marginTop: '4px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                {activeIncident.rejections.map((rej, i) => (
                  <div
                    key={i}
                    style={{
                      fontSize: '10.5px',
                      padding: '4px 6px',
                      backgroundColor: '#fef2f2',
                      border: '1px solid #fecaca',
                      borderRadius: '4px',
                      color: '#991b1b',
                    }}
                  >
                    <b>{rej.hospital_name}:</b> {rej.reason}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* On-Scene Visual Triage Photo */}
          {activeIncident.imageUrl && (
            <div style={{ marginTop: '12px' }}>
              <div style={{ fontSize: '11px', fontWeight: 800, color: '#1e293b', marginBottom: '4px' }}>
                LIVE ON-SCENE TRIAGE STREAM
              </div>
              <img
                src={activeIncident.imageUrl}
                alt="Scene Photo"
                onClick={() => onImageClick && onImageClick(activeIncident.imageUrl!)}
                style={{
                  width: '100%',
                  height: '140px',
                  objectFit: 'cover',
                  borderRadius: '6px',
                  border: '1px solid #cbd5e1',
                  cursor: 'pointer',
                }}
              />
              <div style={{ fontSize: '10px', color: '#64748b', marginTop: '2px', textAlign: 'center' }}>
                Ephemeral zero-storage RAM stream. Click for lightbox.
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
};
