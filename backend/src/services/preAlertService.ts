import { query } from '../db';
import { Hospital, Incident } from '../types';
import { redis } from '../redis';
import { broadcastNewIncident, getIO } from '../socket';
import { scheduleAutoEscalation } from '../escalation';

export const DEFAULT_SILENT_PROMOTION_TIMEOUT_MS = process.env.SILENT_PROMOTION_TIMEOUT_MS
  ? parseInt(process.env.SILENT_PROMOTION_TIMEOUT_MS, 10)
  : 30000;

interface SilentPromotionTimer {
  timeout: NodeJS.Timeout;
  incidentId: string;
  createdAt: number;
}

const activeSilentPromotions = new Map<string, SilentPromotionTimer>();

/**
 * Schedules a silent promotion timer for a suspected incident.
 * If the phone goes silent (neither confirmed nor cancelled within timeoutMs),
 * the incident is automatically promoted to a full broadcasting emergency.
 */
export function scheduleSilentPromotion(
  incidentId: string,
  timeoutMs: number = DEFAULT_SILENT_PROMOTION_TIMEOUT_MS,
): void {
  cancelSilentPromotion(incidentId);

  const timeout = setTimeout(async () => {
    try {
      console.log(
        `[Pre-Alert Service] Silent promotion watchdog fired for incident ${incidentId} after ${timeoutMs}ms. Phone went dark. Promoting...`
      );
      await promoteSuspectedIncident(incidentId, 'SILENT_WATCHDOG_TIMEOUT');
    } catch (err) {
      console.error(`[Pre-Alert Service] Failed to execute silent promotion for ${incidentId}:`, err);
    }
  }, timeoutMs);

  activeSilentPromotions.set(incidentId, {
    timeout,
    incidentId,
    createdAt: Date.now(),
  });

  console.log(
    `[Pre-Alert Service] Armed 30s silent promotion watchdog (${timeoutMs}ms) for suspected incident ${incidentId}`
  );
}

/**
 * Cancels pending silent promotion watchdog when incident is confirmed or cancelled.
 */
export function cancelSilentPromotion(incidentId: string): void {
  const existing = activeSilentPromotions.get(incidentId);
  if (existing) {
    clearTimeout(existing.timeout);
    activeSilentPromotions.delete(incidentId);
    console.log(`[Pre-Alert Service] Disarmed silent promotion watchdog for incident ${incidentId}`);
  }
}

/**
 * Promotes a suspected incident to normal broadcasting flow:
 * 1. Updates DB status from 'suspected' -> 'broadcasting'
 * 2. Runs PostGIS 8km trauma center matching
 * 3. Dispatches 'new_incident' to matched ER rooms & Police
 * 4. Schedules standard auto-escalation
 */
export async function promoteSuspectedIncident(
  incidentId: string,
  reason: 'USER_CONFIRMED' | 'COUNTDOWN_EXPIRED' | 'SILENT_WATCHDOG_TIMEOUT' = 'USER_CONFIRMED',
): Promise<{ incident: Incident; matchedHospitals: Hospital[] } | null> {
  cancelSilentPromotion(incidentId);

  // 1. Update status in PostgreSQL
  const updateSql = `
    UPDATE incidents
    SET status = 'broadcasting',
        victim_metadata = jsonb_set(
          COALESCE(victim_metadata, '{}'::jsonb),
          '{pre_alert_promoted_reason}',
          to_jsonb($2::text)
        ),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = $1
    RETURNING 
      id,
      status,
      accepted_hospital_id,
      victim_metadata,
      ST_Y(location::geometry) AS latitude,
      ST_X(location::geometry) AS longitude,
      created_at,
      updated_at;
  `;

  const result = await query<Incident>(updateSql, [incidentId, reason]);
  if (result.rows.length === 0) {
    console.warn(`[Pre-Alert Service] Cannot promote non-existent incident: ${incidentId}`);
    return null;
  }

  const rawIncident = result.rows[0];
  const incident: Incident = {
    ...rawIncident,
    latitude: Number(rawIncident.latitude),
    longitude: Number(rawIncident.longitude),
  };

  // 2. PostGIS 8km Trauma Center matching query
  const matchHospitalsSql = `
    SELECT 
      id,
      name,
      phone,
      address,
      has_trauma_center,
      has_icu_capacity,
      is_verified,
      ST_Y(location::geometry) AS latitude,
      ST_X(location::geometry) AS longitude,
      ROUND((ST_Distance(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography) / 1000)::numeric, 2) AS distance_km
    FROM hospitals
    WHERE has_trauma_center = true
      AND ST_DWithin(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, 8000)
    ORDER BY distance_km ASC;
  `;

  const matchResult = await query<Hospital>(matchHospitalsSql, [
    incident.longitude,
    incident.latitude,
  ]);

  const matchedHospitals = matchResult.rows.map((h: Hospital) => {
    const straightKm = Number(h.distance_km);
    const roadKm = Math.round(straightKm * 1.6 * 10) / 10;
    return {
      ...h,
      latitude: Number(h.latitude),
      longitude: Number(h.longitude),
      distance_km: straightKm,
      road_distance_km: roadKm,
      distance_meters: Math.round(straightKm * 1000),
    };
  });

  // 3. Broadcast to matched hospitals and police
  broadcastNewIncident(incident, matchedHospitals);

  // Notify police room that suspected marker is now fully promoted
  const io = getIO();
  if (io) {
    io.to('all_incidents').emit('suspected_incident_promoted', {
      id: incident.id,
      reason,
      incident,
      matched_hospitals_count: matchedHospitals.length,
      timestamp: new Date().toISOString(),
    });
  }

  // 4. Cache matched hospitals in Redis
  try {
    await redis.setex(
      `incident_hospitals:${incident.id}`,
      900,
      JSON.stringify(matchedHospitals.map((h) => h.id)),
    );
  } catch (e) {
    console.warn('[Redis] Failed to cache matched hospital IDs on promotion:', e);
  }

  // 5. Schedule auto-escalation
  if (matchedHospitals.length === 0) {
    scheduleAutoEscalation(incident.id, 1, 0);
  } else {
    scheduleAutoEscalation(incident.id, 1);
  }

  console.log(
    `[Pre-Alert Service] Successfully promoted suspected incident ${incidentId} (Reason: ${reason}) to ${matchedHospitals.length} trauma hospitals.`
  );

  return { incident, matchedHospitals };
}
