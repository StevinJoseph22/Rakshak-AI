import { query } from '../db';
import { BlackspotInfo, BlackspotZone } from '../types';

// Distance calculation between two lat/lng points in meters
function haversineDistanceMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000; // Earth radius in meters
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// Well-known high-incident blackspot corridors in Bengaluru for ground-truth reference
const PRESET_BLACKSPOT_ZONES: BlackspotZone[] = [
  {
    id: 'zone-blr-silkboard',
    latitude: 12.9176,
    longitude: 77.6238,
    radius_meters: 500,
    incident_count: 5,
    hazard_level: 'Severe',
    zone_name: 'Silk Board Central Junction (High-Frequency Collision Hotspot)',
  },
  {
    id: 'zone-blr-mgr-brigade',
    latitude: 12.9740,
    longitude: 77.6080,
    radius_meters: 500,
    incident_count: 4,
    hazard_level: 'High',
    zone_name: 'MG Road / Brigade Road Intersection (Accident Blackspot)',
  },
  {
    id: 'zone-blr-richmond',
    latitude: 12.9664,
    longitude: 77.5990,
    radius_meters: 500,
    incident_count: 3,
    hazard_level: 'High',
    zone_name: 'Richmond Circle Flyover Descent (Recurring Blind-Turn Crashes)',
  },
];

/**
 * Checks whether a given accident location falls into a recognized accident blackspot
 * (either from historical database collision density >= 3 within 500m, or preset known blackspots).
 */
export async function checkIncidentBlackspot(
  latitude: number,
  longitude: number
): Promise<BlackspotInfo> {
  let dbCount = 0;

  try {
    const res = await query<{ count: string }>(
      `SELECT COUNT(*)::text AS count
       FROM incidents
       WHERE status NOT IN ('cancelled')
         AND ST_DWithin(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, 500)`,
      [longitude, latitude]
    );

    if (res.rows.length > 0) {
      dbCount = parseInt(res.rows[0].count, 10) || 0;
    }
  } catch (err) {
    console.warn('[BlackspotService] DB check failed, using spatial fallback:', err);
  }

  // Check against preset reference zones
  for (const preset of PRESET_BLACKSPOT_ZONES) {
    const dist = haversineDistanceMeters(latitude, longitude, preset.latitude, preset.longitude);
    if (dist <= preset.radius_meters) {
      const totalCount = Math.max(dbCount, preset.incident_count);
      return {
        is_blackspot: true,
        incident_count: totalCount,
        hazard_level: preset.hazard_level,
        zone_name: preset.zone_name,
      };
    }
  }

  // If DB records >= 3 incidents within 500m, dynamically flag as a confirmed blackspot
  if (dbCount >= 3) {
    const hazardLevel: 'High' | 'Severe' | 'Critical' =
      dbCount >= 6 ? 'Critical' : dbCount >= 4 ? 'Severe' : 'High';

    return {
      is_blackspot: true,
      incident_count: dbCount,
      hazard_level: hazardLevel,
      zone_name: `Recurring Accident Blackspot (${dbCount} Recorded Collisions in 500m)`,
    };
  }

  return {
    is_blackspot: false,
    incident_count: dbCount,
    hazard_level: 'High',
    zone_name: 'Standard Patrol Segment',
  };
}

/**
 * Retrieves all active accident blackspot zones across the city for the Police Tactical Map.
 * Aggregates database clusters within 500m radius and merges with verified municipal blackspot corridors.
 */
export async function getAllBlackspotZones(): Promise<BlackspotZone[]> {
  const zones: BlackspotZone[] = [...PRESET_BLACKSPOT_ZONES];

  try {
    const res = await query<{
      id: string;
      latitude: string;
      longitude: string;
      created_at: string;
    }>(
      `SELECT id,
              ST_Y(location::geometry)::text AS latitude,
              ST_X(location::geometry)::text AS longitude,
              created_at
       FROM incidents
       WHERE status NOT IN ('cancelled')
       ORDER BY created_at DESC
       LIMIT 100`
    );

    const points = res.rows.map((r) => ({
      id: r.id,
      lat: parseFloat(r.latitude),
      lng: parseFloat(r.longitude),
    }));

    // Cluster points within 500 meters
    const clusters: Array<typeof points> = [];
    const visited = new Set<string>();

    for (const p of points) {
      if (visited.has(p.id)) continue;
      const cluster = [p];
      visited.add(p.id);

      for (const other of points) {
        if (!visited.has(other.id)) {
          const dist = haversineDistanceMeters(p.lat, p.lng, other.lat, other.lng);
          if (dist <= 500) {
            cluster.push(other);
            visited.add(other.id);
          }
        }
      }

      if (cluster.length >= 3) {
        clusters.push(cluster);
      }
    }

    // Convert dynamic clusters into BlackspotZones
    clusters.forEach((cluster, idx) => {
      const avgLat = cluster.reduce((sum, p) => sum + p.lat, 0) / cluster.length;
      const avgLng = cluster.reduce((sum, p) => sum + p.lng, 0) / cluster.length;

      // Avoid duplicating existing preset zones
      const alreadyCovered = zones.some(
        (z) => haversineDistanceMeters(avgLat, avgLng, z.latitude, z.longitude) <= 400
      );

      if (!alreadyCovered) {
        const count = cluster.length;
        const hazard: 'High' | 'Severe' | 'Critical' =
          count >= 6 ? 'Critical' : count >= 4 ? 'Severe' : 'High';

        zones.push({
          id: `cluster-zone-${idx + 1}`,
          latitude: parseFloat(avgLat.toFixed(5)),
          longitude: parseFloat(avgLng.toFixed(5)),
          radius_meters: 500,
          incident_count: count,
          hazard_level: hazard,
          zone_name: `Police Alert: High-Density Accident Zone (${count} Crashes Recorded)`,
        });
      }
    });
  } catch (err) {
    console.warn('[BlackspotService] Error fetching dynamic clusters, serving presets:', err);
  }

  return zones;
}
