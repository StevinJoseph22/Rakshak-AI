import React, { useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { Hospital } from '../types';

interface IncidentRouteMapProps {
  incidentId: string;
  incidentLat: number;
  incidentLng: number;
  hospital: Hospital;
  ambulanceLocation?: {
    latitude: number;
    longitude: number;
    speed_kmh?: number;
    heading?: number;
  } | null;
  height?: string;
}

// Custom Leaflet DivIcon helpers
function createPulsingIcon(color: string, emoji: string) {
  return L.divIcon({
    className: 'custom-leaflet-icon',
    html: `
      <div style="
        background-color: ${color};
        width: 32px;
        height: 32px;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        border: 2.5px solid #ffffff;
        box-shadow: 0 3px 8px rgba(0,0,0,0.35);
        font-size: 15px;
      ">
        ${emoji}
      </div>
    `,
    iconSize: [32, 32],
    iconAnchor: [16, 16],
    popupAnchor: [0, -18],
  });
}

export const IncidentRouteMap: React.FC<IncidentRouteMapProps> = ({
  incidentId,
  incidentLat,
  incidentLng,
  hospital,
  ambulanceLocation,
  height = '250px',
}) => {
  const mapContainerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<L.Map | null>(null);
  const ambulanceMarkerRef = useRef<L.Marker | null>(null);
  const routeLayerGroupRef = useRef<L.LayerGroup | null>(null);

  const [routeDistanceKm, setRouteDistanceKm] = useState<string | null>(null);
  const [routeDurationMin, setRouteDurationMin] = useState<number | null>(null);
  const [trafficDelayMin, setTrafficDelayMin] = useState<number | null>(null);
  const [trafficSeverity, setTrafficSeverity] = useState<'Clear' | 'Moderate' | 'Heavy'>('Clear');

  // Initialize Leaflet map
  useEffect(() => {
    if (!mapContainerRef.current) return;

    const map = L.map(mapContainerRef.current, {
      center: [incidentLat, incidentLng],
      zoom: 13,
      zoomControl: false,
    });

    L.control.zoom({ position: 'topright' }).addTo(map);

    // High performance Esri World Street Map (zero API key, zero watermark)
    L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}', {
      maxZoom: 19,
      attribution: '&copy; OpenStreetMap contributors &copy; Esri',
    }).addTo(map);

    const routeGroup = L.layerGroup().addTo(map);
    routeLayerGroupRef.current = routeGroup;
    mapRef.current = map;

    // 1. Incident Marker
    const incidentMarker = L.marker([incidentLat, incidentLng], {
      icon: createPulsingIcon('#ef4444', '💥'),
    }).addTo(map);
    incidentMarker.bindPopup(`<b>Collision Site</b><br/>Emergency Beacon: ${incidentId.substring(0, 8)}...`);

    // 2. Hospital Marker
    if (hospital && hospital.latitude && hospital.longitude) {
      const hospitalMarker = L.marker([hospital.latitude, hospital.longitude], {
        icon: createPulsingIcon('#10b981', '🏥'),
      }).addTo(map);
      hospitalMarker.bindPopup(`<b>${hospital.name}</b><br/>${hospital.address}`);
    }

    // 3. Fetch Real Roadway Route with Live Traffic Speed Annotations
    if (hospital && hospital.latitude && hospital.longitude) {
      const osrmUrl = `https://router.project-osrm.org/route/v1/driving/${incidentLng},${incidentLat};${hospital.longitude},${hospital.latitude}?overview=full&geometries=geojson&annotations=speed,distance,duration`;

      fetch(osrmUrl)
        .then((res) => res.json())
        .then((data) => {
          if (data && data.routes && data.routes[0]) {
            const route = data.routes[0];
            const coordinates: [number, number][] = route.geometry.coordinates.map(
              (c: [number, number]) => [c[1], c[0]] // Leaflet takes [lat, lng]
            );

            routeGroup.clearLayers();

            const speeds: number[] = route.legs?.[0]?.annotation?.speed || [];
            let heavyCount = 0;
            let moderateCount = 0;

            // Partition coordinates into Google-Maps-style traffic colored segments
            if (speeds.length > 0 && speeds.length === coordinates.length - 1) {
              let currentColor = '#2563eb'; // blue: fast/clear
              let currentPoints: [number, number][] = [coordinates[0]];

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

              currentColor = getColorForSpeed(speeds[0]);

              for (let i = 0; i < speeds.length; i++) {
                const segColor = getColorForSpeed(speeds[i]);
                currentPoints.push(coordinates[i + 1]);

                // When color changes or end of route, flush polyline
                if (segColor !== currentColor || i === speeds.length - 1) {
                  L.polyline(currentPoints, {
                    color: currentColor,
                    weight: 6,
                    opacity: 0.9,
                    lineJoin: 'round',
                  }).addTo(routeGroup);

                  currentColor = segColor;
                  currentPoints = [coordinates[i + 1]];
                }
              }
            } else {
              // Fallback single route line if annotations absent
              L.polyline(coordinates, {
                color: '#2563eb',
                weight: 6,
                opacity: 0.9,
                lineJoin: 'round',
              }).addTo(routeGroup);
            }

            const distKm = (route.distance / 1000).toFixed(1);
            const durationMin = Math.round(route.duration / 60);

            // Calculate realistic traffic delay from slow segments
            let extraDelay = 0;
            if (heavyCount > 15) {
              extraDelay = 5;
              setTrafficSeverity('Heavy');
            } else if (heavyCount > 5 || moderateCount > 20) {
              extraDelay = 3;
              setTrafficSeverity('Moderate');
            } else {
              setTrafficSeverity('Clear');
            }

            setTrafficDelayMin(extraDelay);
            setRouteDistanceKm(distKm);
            setRouteDurationMin(durationMin + extraDelay);

            // Fit bounds to full road polyline
            const fullLine = L.polyline(coordinates);
            map.fitBounds(fullLine.getBounds(), { padding: [40, 40], maxZoom: 15 });
          } else {
            // Fallback straight line
            const fallbackLine = L.polyline(
              [
                [incidentLat, incidentLng],
                [hospital.latitude, hospital.longitude],
              ],
              { color: '#2563eb', weight: 4, dashArray: '6, 6' }
            ).addTo(routeGroup);
            map.fitBounds(fallbackLine.getBounds(), { padding: [40, 40] });
          }
        })
        .catch(() => {
          // Fallback straight line
          const fallbackLine = L.polyline(
            [
              [incidentLat, incidentLng],
              [hospital.latitude, hospital.longitude],
            ],
            { color: '#2563eb', weight: 4, dashArray: '6, 6' }
          ).addTo(routeGroup);
          map.fitBounds(fallbackLine.getBounds(), { padding: [40, 40] });
        });
    }

    const resizeTimer = setTimeout(() => {
      map.invalidateSize();
    }, 250);

    return () => {
      clearTimeout(resizeTimer);
      map.remove();
      mapRef.current = null;
    };
  }, [incidentId, incidentLat, incidentLng, hospital]);

  // Update dynamic ambulance marker live
  useEffect(() => {
    if (!mapRef.current) return;
    const map = mapRef.current;

    if (ambulanceLocation && ambulanceLocation.latitude && ambulanceLocation.longitude) {
      const ambPos: [number, number] = [ambulanceLocation.latitude, ambulanceLocation.longitude];

      if (!ambulanceMarkerRef.current) {
        const marker = L.marker(ambPos, {
          icon: createPulsingIcon('#2563eb', '🚑'),
          zIndexOffset: 1000,
        }).addTo(map);
        marker.bindPopup(`<b>Unit En Route</b><br/>Live GPS Telemetry Active`);
        ambulanceMarkerRef.current = marker;
      } else {
        ambulanceMarkerRef.current.setLatLng(ambPos);
      }

      // Pan to keep ambulance in view
      if (!map.getBounds().contains(ambPos)) {
        map.panTo(ambPos);
      }
    }
  }, [ambulanceLocation]);

  return (
    <div
      style={{
        position: 'relative',
        width: '100%',
        height,
        borderRadius: '0.625rem',
        overflow: 'hidden',
        border: '1px solid #cbd5e1',
        boxShadow: '0 2px 4px rgba(0,0,0,0.06)',
      }}
    >
      <div ref={mapContainerRef} style={{ width: '100%', height: '100%' }} />

      {/* Floating Google-Maps-Style Traffic Legend & ETA HUD */}
      <div
        style={{
          position: 'absolute',
          bottom: '10px',
          left: '10px',
          backgroundColor: 'rgba(15, 23, 42, 0.92)',
          backdropFilter: 'blur(8px)',
          borderRadius: '0.5rem',
          padding: '8px 12px',
          color: '#ffffff',
          fontSize: '11px',
          fontWeight: 600,
          zIndex: 1000,
          display: 'flex',
          flexDirection: 'column',
          gap: '6px',
          boxShadow: '0 4px 10px rgba(0,0,0,0.3)',
          border: '1px solid rgba(255,255,255,0.15)',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span>
            🛣️ <b>{routeDistanceKm ? `${routeDistanceKm} km Road` : 'Calculating route...'}</b>
            {routeDurationMin && ` (~${routeDurationMin} min in Traffic)`}
          </span>
          {trafficDelayMin && trafficDelayMin > 0 ? (
            <span
              style={{
                backgroundColor: trafficSeverity === 'Heavy' ? '#dc2626' : '#ea580c',
                padding: '2px 6px',
                borderRadius: '4px',
                fontSize: '10px',
                fontWeight: 700,
              }}
            >
              +{trafficDelayMin}m Traffic Delay
            </span>
          ) : (
            <span
              style={{
                backgroundColor: '#16a34a',
                padding: '2px 6px',
                borderRadius: '4px',
                fontSize: '10px',
                fontWeight: 700,
              }}
            >
              Clear Flow
            </span>
          )}
        </div>

        {/* Traffic Color Indicators */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', fontSize: '10px', color: '#cbd5e1' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
            <span style={{ width: 8, height: 8, borderRadius: '50%', backgroundColor: '#2563eb' }} />
            Fast Flow
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
            <span style={{ width: 8, height: 8, borderRadius: '50%', backgroundColor: '#f59e0b' }} />
            Moderate
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
            <span style={{ width: 8, height: 8, borderRadius: '50%', backgroundColor: '#ef4444' }} />
            Congested
          </div>
          <span style={{ color: '#64748b' }}>|</span>
          <span style={{ color: ambulanceLocation ? '#38bdf8' : '#94a3b8' }}>
            {ambulanceLocation ? '🚑 Unit GPS Live' : '📍 Awaiting Unit'}
          </span>
        </div>
      </div>
    </div>
  );
};
