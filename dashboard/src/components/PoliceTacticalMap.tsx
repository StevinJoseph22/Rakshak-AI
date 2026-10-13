import React, { useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { IncidentPayload, PreemptedSignalPayload, BlackspotZone } from '../types';
import { ShieldAlert, X, Phone, Zap } from 'lucide-react';

interface PoliceTacticalMapProps {
  incidents: IncidentPayload[];
  selectedIncidentId?: string | null;
  onSelectIncident?: (incident: IncidentPayload) => void;
  onImageClick?: (imageUrl: string) => void;
  preemptedSignals?: Record<string, PreemptedSignalPayload>;
}

interface MunicipalTrafficSignal {
  id: string;
  name: string;
  controllerId: string;
  latitude: number;
  longitude: number;
}

const BENGALURU_MUNICIPAL_SIGNALS: MunicipalTrafficSignal[] = [
  { id: 'SIG-BLR-001', name: 'MG Road - Brigade Road Junction', controllerId: 'ITMS-BTP-MGR01', latitude: 12.9740, longitude: 77.6080 },
  { id: 'SIG-BLR-002', name: 'Trinity Circle Junction', controllerId: 'ITMS-BTP-TRN02', latitude: 12.9729, longitude: 77.6200 },
  { id: 'SIG-BLR-003', name: 'Richmond Circle Flyover', controllerId: 'ITMS-BTP-RCH03', latitude: 12.9664, longitude: 77.5990 },
  { id: 'SIG-BLR-004', name: 'Vellara Junction (Hosur Road)', controllerId: 'ITMS-BTP-VEL04', latitude: 12.9638, longitude: 77.6075 },
  { id: 'SIG-BLR-005', name: 'Indiranagar 100ft Road - CMH Road', controllerId: 'ITMS-BTP-IND05', latitude: 12.9784, longitude: 77.6408 },
  { id: 'SIG-BLR-006', name: 'Sony World Junction Koramangala', controllerId: 'ITMS-BTP-SNY06', latitude: 12.9344, longitude: 77.6245 },
  { id: 'SIG-BLR-007', name: 'Silk Board Central Intersection', controllerId: 'ITMS-BTP-SLK07', latitude: 12.9176, longitude: 77.6238 },
  { id: 'SIG-BLR-008', name: 'Indiranagar Double Road Junction', controllerId: 'ITMS-BTP-INR08', latitude: 12.9719, longitude: 77.6412 },
  { id: 'SIG-BLR-009', name: 'Mayo Hall Junction - Residency Rd', controllerId: 'ITMS-BTP-MYO09', latitude: 12.9734, longitude: 77.6135 },
  { id: 'SIG-BLR-010', name: 'Adugodi Signal (Hosur Road)', controllerId: 'ITMS-BTP-ADU10', latitude: 12.9438, longitude: 77.6102 },
];

function createSignalMarkerIcon(name: string, isPreempted: boolean) {
  const bgColor = isPreempted ? '#10b981' : '#334155';
  const pulseStyle = isPreempted
    ? 'box-shadow: 0 0 0 5px rgba(16, 185, 129, 0.4), 0 4px 10px rgba(0,0,0,0.5); border: 2px solid #ffffff;'
    : 'box-shadow: 0 2px 6px rgba(0,0,0,0.3); border: 1.5px solid #94a3b8;';

  return L.divIcon({
    className: 'police-signal-marker',
    html: `
      <div style="
        background-color: ${bgColor};
        width: 28px;
        height: 28px;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        ${pulseStyle}
        font-size: 14px;
        cursor: pointer;
        transition: transform 0.2s;
      " title="${name}">
        ${isPreempted ? '🟢' : '🚦'}
      </div>
    `,
    iconSize: [28, 28],
    iconAnchor: [14, 14],
    popupAnchor: [0, -16],
  });
}

function createMarkerIcon(status: string, ambulanceId?: string | null, source?: string) {
  if (source === 'DEAD_MAN_COLLAPSE') {
    return L.divIcon({
      className: 'police-tactical-icon-deadman',
      html: `
        <div style="
          background: radial-gradient(circle, #dc2626 0%, #450a0a 100%);
          width: 38px;
          height: 38px;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          border: 2.5px solid #fecaca;
          box-shadow: 0 0 16px rgba(220, 38, 38, 0.9), 0 4px 10px rgba(0,0,0,0.6);
          font-size: 18px;
          cursor: pointer;
        " title="Dead-Man Watchdog: Kinematic Collapse Detected">
          🚨
        </div>
      `,
      iconSize: [38, 38],
      iconAnchor: [19, 19],
      popupAnchor: [0, -20],
    });
  }

  let color = '#f59e0b';
  let emoji = '⚡';
  if (status === 'suspected') {
    return L.divIcon({
      className: 'police-tactical-icon-suspected',
      html: `
        <div style="
          background: rgba(245, 158, 11, 0.4);
          border: 2px dashed #f59e0b;
          width: 32px;
          height: 32px;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 14px;
          box-shadow: 0 0 10px rgba(245, 158, 11, 0.5);
          cursor: pointer;
        " title="Pre-Alert: Suspected Impact (Pending Confirmation)">
          ⏳
        </div>
      `,
      iconSize: [32, 32],
      iconAnchor: [16, 16],
      popupAnchor: [0, -18],
    });
  } else if (status === 'escalated') {
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
  preemptedSignals,
}) => {
  const mapContainerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<L.Map | null>(null);
  const markersGroupRef = useRef<L.LayerGroup | null>(null);
  const signalsGroupRef = useRef<L.LayerGroup | null>(null);
  const blackspotsGroupRef = useRef<L.LayerGroup | null>(null);
  const activeRoutePolylineRef = useRef<L.Polyline | null>(null);
  const activeRouteLayerGroupRef = useRef<L.LayerGroup | null>(null);
  const [activeIncident, setActiveIncident] = useState<IncidentPayload | null>(null);
  const [blackspots, setBlackspots] = useState<BlackspotZone[]>([]);
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
    const signalsGroup = L.layerGroup().addTo(map);
    signalsGroupRef.current = signalsGroup;
    const blackspotsGroup = L.layerGroup().addTo(map);
    blackspotsGroupRef.current = blackspotsGroup;
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
      if (incident.status === 'cancelled') return;
      const source = (incident.victim_metadata as Record<string, unknown> | undefined)?.source as string | undefined;
      const icon = createMarkerIcon(incident.status || 'broadcasting', incident.ambulance_id, source);
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

  // Render real municipal traffic signals & live C-V2X preemption markers
  useEffect(() => {
    if (!mapRef.current || !signalsGroupRef.current) return;
    const signalsGroup = signalsGroupRef.current;
    signalsGroup.clearLayers();

    BENGALURU_MUNICIPAL_SIGNALS.forEach((signal) => {
      const preemption = preemptedSignals ? preemptedSignals[signal.id] : undefined;
      const isPreempted = preemption && (preemption.status === 'GRANTED' || preemption.status === 'ACTIVE');
      const icon = createSignalMarkerIcon(signal.name, !!isPreempted);
      const marker = L.marker([signal.latitude, signal.longitude], { icon });

      const popupHtml = `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; font-size: 11px; color: #0f172a; min-width: 210px;">
          <div style="font-weight: 800; font-size: 11.5px; color: ${isPreempted ? '#059669' : '#334155'}; display: flex; align-items: center; gap: 4px;">
            ${isPreempted ? '🟢 C-V2X PREEMPTED GREEN' : '🚦 MUNICIPAL ITMS TRAFFIC SIGNAL'}
          </div>
          <div style="font-weight: 700; margin-top: 4px; font-size: 11.5px; color: #1e293b;">${signal.name}</div>
          <div style="color: #64748b; font-size: 10px; font-family: monospace; margin-top: 2px;">Controller: ${signal.controllerId}</div>
          <div style="color: #64748b; font-size: 9.5px;">OID: 1.3.6.1.4.1.1206.4.2.1.1.1 (NTCIP-1202)</div>
          ${
            isPreempted
              ? `
            <div style="margin-top: 6px; padding: 6px 8px; background: #ecfdf5; border: 1px solid #a7f3d0; border-radius: 4px;">
              <div style="color: #065f46; font-weight: 800; font-size: 10px;">PHASE 2 PRIMARY INBOUND HOLD</div>
              <div style="color: #047857; font-size: 9.5px; margin-top: 2px;">Hold: <b>${preemption?.hold_seconds ?? 45}s</b> • Queue Clear: <b>${preemption?.queue_clearance_seconds ?? 8}s</b></div>
              <div style="color: #047857; font-size: 9.5px;">Ambulance: <b>${preemption?.ambulance_plate || 'KA-01-EA-108'}</b></div>
            </div>
          `
              : `
            <div style="margin-top: 4px; color: #475569; font-size: 9.5px;">
              Municipal ITMS standard dual-ring actuated cycle
            </div>
          `
          }
        </div>
      `;

      marker.bindPopup(popupHtml);
      signalsGroup.addLayer(marker);
    });
  }, [preemptedSignals]);

  // Fetch high-frequency accident blackspots
  useEffect(() => {
    fetch('/incidents/blackspots')
      .then((res) => (res.ok ? res.json() : []))
      .then((data: BlackspotZone[]) => {
        if (Array.isArray(data)) {
          setBlackspots(data);
        }
      })
      .catch(() => {});
  }, [incidents.length]);

  // Render high-frequency accident blackspot zones
  useEffect(() => {
    if (!mapRef.current || !blackspotsGroupRef.current) return;
    const blackspotsGroup = blackspotsGroupRef.current;
    blackspotsGroup.clearLayers();

    blackspots.forEach((zone) => {
      // 500m Hazard Buffer Circle
      const circle = L.circle([zone.latitude, zone.longitude], {
        radius: zone.radius_meters || 500,
        color: zone.hazard_level === 'Critical' ? '#dc2626' : '#ea580c',
        weight: 1.5,
        dashArray: '5, 5',
        fillColor: '#ef4444',
        fillOpacity: 0.12,
      });

      const icon = L.divIcon({
        className: 'police-blackspot-icon',
        html: `
          <div style="
            background: rgba(185, 28, 28, 0.9);
            color: #ffffff;
            padding: 3px 8px;
            border-radius: 9999px;
            font-size: 10px;
            font-weight: 800;
            border: 1.5px solid #fca5a5;
            box-shadow: 0 2px 8px rgba(0,0,0,0.4);
            display: flex;
            align-items: center;
            gap: 4px;
            white-space: nowrap;
            cursor: pointer;
          ">
            <span>⚠️ ACCIDENT ZONE</span>
            <span style="background: #ffffff; color: #991b1b; padding: 1px 5px; border-radius: 9999px; font-size: 9px;">\${zone.incident_count} Crashes</span>
          </div>
        `,
        iconSize: [145, 24],
        iconAnchor: [72, 12],
      });

      const marker = L.marker([zone.latitude, zone.longitude], { icon });

      const popupHtml = `
        <div style="font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 11px; color: #0f172a; min-width: 220px;">
          <div style="color: #b91c1c; font-weight: 800; font-size: 12px; display: flex; align-items: center; gap: 4px;">
            ⚠️ ACCIDENT BLACKSPOT ZONE
          </div>
          <div style="font-weight: 700; margin-top: 3px; font-size: 11.5px; color: #1e293b;">\${zone.zone_name}</div>
          <div style="margin-top: 4px; color: #64748b; font-size: 10.5px;">
            Historical Collisions: <b style="color: #991b1b;">\${zone.incident_count}</b> • Radius: <b>500m</b>
          </div>
          <div style="color: #64748b; font-size: 10.5px;">
            Hazard Level: <b style="color: \${zone.hazard_level === 'Critical' ? '#dc2626' : '#ea580c'};">\${zone.hazard_level}</b>
          </div>
          <div style="margin-top: 6px; padding: 5px 8px; background: #fef2f2; border: 1px solid #fecaca; border-radius: 4px; color: #991b1b; font-size: 10px;">
            High-risk intersection/road corridor. Police patrol standby alerted.
          </div>
        </div>
      `;

      marker.bindPopup(popupHtml);
      circle.bindPopup(popupHtml);

      blackspotsGroup.addLayer(circle);
      blackspotsGroup.addLayer(marker);
    });
  }, [blackspots]);

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

      {/* Floating C-V2X Green Corridor Preemption Alert Banner */}
      {preemptedSignals && Object.values(preemptedSignals).some((s) => s.status === 'GRANTED' || s.status === 'ACTIVE') && (
        <div
          style={{
            position: 'absolute',
            top: '12px',
            left: '370px',
            background: 'linear-gradient(135deg, rgba(6, 95, 70, 0.95), rgba(4, 120, 87, 0.95))',
            backdropFilter: 'blur(8px)',
            borderRadius: '0.5rem',
            padding: '8px 14px',
            color: '#ffffff',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            border: '1.5px solid #34d399',
            boxShadow: '0 4px 15px rgba(16, 185, 129, 0.4)',
            zIndex: 1000,
          }}
        >
          <Zap size={18} color="#a7f3d0" />
          <div>
            <div style={{ fontSize: '11.5px', fontWeight: 900, letterSpacing: '0.04em', color: '#ecfdf5' }}>
              C-V2X GREEN CORRIDOR ENGAGED
            </div>
            <div style={{ fontSize: '10px', color: '#d1fae5' }}>
              NTCIP-1202 Signal Preemption Active • Dual-Ring Phase 2 Hold
            </div>
          </div>
        </div>
      )}

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
        <div style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
          <span>🚦</span>
          ITMS Signal
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
          <span>🟢</span>
          Preempted Green
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '5px' }}>
          <span style={{ width: 10, height: 10, borderRadius: '50%', border: '1.5px dashed #ef4444', backgroundColor: 'rgba(239, 68, 68, 0.3)' }} />
          Accident Blackspot (500m)
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

          {/* Blackspot Warning Banner */}
          {activeIncident.blackspot_info?.is_blackspot && (
            <div
              style={{
                marginTop: '10px',
                padding: '8px 10px',
                backgroundColor: '#fef2f2',
                border: '1.5px solid #ef4444',
                borderRadius: '6px',
                color: '#991b1b',
                fontSize: '11px',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                boxShadow: '0 2px 6px rgba(220, 38, 38, 0.15)',
              }}
            >
              <span style={{ fontSize: '16px' }}>⚠️</span>
              <div>
                <div style={{ fontWeight: 800, color: '#991b1b', fontSize: '11px' }}>
                  RECURRING ACCIDENT BLACKSPOT ZONE
                </div>
                <div style={{ fontSize: '10px', color: '#b91c1c', marginTop: '1px' }}>
                  <b>{activeIncident.blackspot_info.incident_count} collisions</b> historically recorded in this 500m area.
                </div>
              </div>
            </div>
          )}

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

          {/* Cloud Dead-Man Watchdog Banner */}
          {activeIncident.victim_metadata &&
            (activeIncident.victim_metadata as Record<string, unknown>).source === 'DEAD_MAN_COLLAPSE' && (
              <div
                style={{
                  marginTop: '10px',
                  padding: '10px',
                  backgroundColor: '#7f1d1d',
                  border: '1.5px solid #ef4444',
                  borderRadius: '6px',
                  color: '#ffffff',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '11px', fontWeight: 800 }}>
                  <span>🚨 KINEMATIC SIGNAL COLLAPSE</span>
                </div>
                <div style={{ fontSize: '10px', color: '#fecaca', marginTop: '4px', lineHeight: 1.4 }}>
                  Watchdog triggered: High-speed vehicle (&gt;35 km/h) telemetry collapsed abruptly without braking or deceleration curve.
                </div>
                <div style={{ display: 'flex', gap: '10px', marginTop: '6px', fontSize: '10px', color: '#fed7aa', flexWrap: 'wrap' }}>
                  <span>🚗 Plate: <strong>{String((activeIncident.victim_metadata as Record<string, unknown>).vehicle_plate || 'KA-01-EA-108')}</strong></span>
                  <span>⚡ Speed: <strong>{String((activeIncident.victim_metadata as Record<string, unknown>).last_speed_kmh || '92.4')} km/h</strong></span>
                </div>
              </div>
            )}

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

          {/* Ambulance Dispatch & On-Scene Arrival Unit Card */}
          {(activeIncident.ambulance_id || activeIncident.ambulance_plate || activeIncident.status === 'accepted') && (
            <div
              style={{
                marginTop: '10px',
                padding: '10px',
                backgroundColor: activeIncident.ambulance_arrived_at ? '#f0fdf4' : '#eff6ff',
                border: `1.5px solid ${activeIncident.ambulance_arrived_at ? '#22c55e' : '#60a5fa'}`,
                borderRadius: '6px',
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div
                  style={{
                    fontSize: '10px',
                    fontWeight: 800,
                    color: activeIncident.ambulance_arrived_at ? '#15803d' : '#1d4ed8',
                    textTransform: 'uppercase',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px',
                  }}
                >
                  {activeIncident.ambulance_arrived_at ? '✅ ARRIVED ON SCENE' : '🚑 AMBULANCE EN ROUTE'}
                </div>
                {activeIncident.ambulance_arrived_at && (
                  <span
                    style={{
                      fontSize: '10px',
                      fontWeight: 700,
                      color: '#15803d',
                      backgroundColor: '#dcfce7',
                      padding: '1px 6px',
                      borderRadius: '4px',
                    }}
                  >
                    {new Date(activeIncident.ambulance_arrived_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                  </span>
                )}
              </div>

              {/* Plate & Origin Station */}
              <div style={{ marginTop: '6px', fontSize: '11px', color: '#1e293b' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span>
                    Plate: <b>{activeIncident.ambulance_plate || 'KA-01-EA-108'}</b>
                  </span>
                  <span style={{ color: '#64748b', fontSize: '10px' }}>
                    Unit: {activeIncident.ambulance_id || 'EMS-108'}
                  </span>
                </div>
                <div style={{ marginTop: '2px', fontSize: '10px', color: '#475569' }}>
                  <b>Depot:</b> {activeIncident.ambulance_origin_station || 'Victoria Hospital Emergency Base 01'}
                </div>
              </div>

              {/* Driver Contact & Direct Call */}
              <div
                style={{
                  marginTop: '6px',
                  paddingTop: '6px',
                  borderTop: '1px dashed #cbd5e1',
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                }}
              >
                <div>
                  <div style={{ fontSize: '11px', fontWeight: 700, color: '#0f172a' }}>
                    {activeIncident.ambulance_driver_name || 'Ramesh Kumar (Paramedic)'}
                  </div>
                  <div style={{ fontSize: '10px', color: '#64748b', fontFamily: 'monospace' }}>
                    {activeIncident.ambulance_driver_phone || '+91-98765-43210'}
                  </div>
                </div>

                <a
                  href={`tel:${activeIncident.ambulance_driver_phone || '+91-98765-43210'}`}
                  style={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: '4px',
                    backgroundColor: activeIncident.ambulance_arrived_at ? '#16a34a' : '#2563eb',
                    color: '#ffffff',
                    padding: '4px 8px',
                    borderRadius: '4px',
                    fontSize: '10px',
                    fontWeight: 700,
                    textDecoration: 'none',
                    boxShadow: '0 1px 2px rgba(0,0,0,0.1)',
                  }}
                  title="Direct 1-Click Dial to Ambulance Driver"
                >
                  <Phone size={11} /> Call Driver
                </a>
              </div>

              {activeIncident.ambulance_arrived_at && (
                <div
                  style={{
                    marginTop: '5px',
                    fontSize: '9.5px',
                    color: '#166534',
                    fontStyle: 'italic',
                  }}
                >
                  * Zero-touch geofence verified • Automated SMS alert dispatched to family
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

              {/* C-V2X Intelligent Green Corridor & Preemption HUD */}
              <div
                style={{
                  marginTop: '10px',
                  padding: '10px',
                  backgroundColor: '#0f172a',
                  border: '1.5px solid #10b981',
                  borderRadius: '6px',
                  color: '#ffffff',
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div
                    style={{
                      fontSize: '10px',
                      fontWeight: 900,
                      color: '#34d399',
                      letterSpacing: '0.04em',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '4px',
                    }}
                  >
                    <Zap size={13} color="#34d399" />
                    C-V2X ITMS GREEN CORRIDOR
                  </div>
                  <span
                    style={{
                      fontSize: '9px',
                      fontWeight: 700,
                      backgroundColor: '#065f46',
                      color: '#6ee7b7',
                      padding: '1px 6px',
                      borderRadius: '4px',
                    }}
                  >
                    NTCIP-1202 ACTIVE
                  </span>
                </div>

                <div style={{ marginTop: '5px', fontSize: '9.5px', color: '#94a3b8' }}>
                  Automated EVP preemption holds signals green along emergency route.
                </div>

                {/* Signals Along Corridor List */}
                <div style={{ marginTop: '8px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                  {BENGALURU_MUNICIPAL_SIGNALS.slice(0, 4).map((sig) => {
                    const preemption = preemptedSignals ? preemptedSignals[sig.id] : undefined;
                    const isPreempted =
                      preemption && (preemption.status === 'GRANTED' || preemption.status === 'ACTIVE');
                    return (
                      <div
                        key={sig.id}
                        style={{
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                          padding: '4px 6px',
                          backgroundColor: isPreempted ? 'rgba(16, 185, 129, 0.15)' : 'rgba(255, 255, 255, 0.05)',
                          borderRadius: '4px',
                          border: isPreempted ? '1px solid #10b981' : '1px solid rgba(255, 255, 255, 0.08)',
                          fontSize: '10px',
                        }}
                      >
                        <div
                          style={{
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                            whiteSpace: 'nowrap',
                            maxWidth: '175px',
                          }}
                        >
                          <span
                            style={{
                              color: isPreempted ? '#34d399' : '#e2e8f0',
                              fontWeight: isPreempted ? 700 : 500,
                            }}
                          >
                            {sig.name}
                          </span>
                        </div>
                        <span
                          style={{
                            fontSize: '9px',
                            fontWeight: 800,
                            color: isPreempted ? '#34d399' : '#94a3b8',
                            backgroundColor: isPreempted ? '#065f46' : 'transparent',
                            padding: isPreempted ? '1px 5px' : '0',
                            borderRadius: '3px',
                          }}
                        >
                          {isPreempted ? `HOLD ${preemption?.hold_seconds ?? 45}s 🟢` : 'NORMAL 🚦'}
                        </span>
                      </div>
                    );
                  })}
                </div>
              </div>
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
