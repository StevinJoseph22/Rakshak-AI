import { query } from './db';
import { Hospital, Incident } from './types';
import { redis } from './redis';
import {
  broadcastIncidentEscalated,
  broadcastIncidentUnmatched,
} from './socket';

interface EscalationTimer {
  timeout: NodeJS.Timeout;
  stage: 1 | 2;
  incidentId: string;
}

const activeEscalations = new Map<string, EscalationTimer>();

export const DEFAULT_ESCALATION_TIMEOUT_MS = process.env.AUTO_ESCALATION_TIMEOUT_MS
  ? parseInt(process.env.AUTO_ESCALATION_TIMEOUT_MS, 10)
  : 45000;

/**
 * Schedules auto-escalation timer for an incident.
 * Idempotent: clears any previous timer for this incident.
 */
export function scheduleAutoEscalation(
  incidentId: string,
  stage: 1 | 2 = 1,
  timeoutMs: number = DEFAULT_ESCALATION_TIMEOUT_MS
): void {
  cancelAutoEscalation(incidentId);

  const timeout = setTimeout(async () => {
    try {
      console.log(
        `[Auto-Escalation] Timeout fired for incident ${incidentId} (Stage ${stage}). Escalating...`
      );
      await performEscalation(incidentId, stage);
    } catch (err) {
      console.error(`[Auto-Escalation] Failed to execute escalation for ${incidentId}:`, err);
    }
  }, timeoutMs);

  activeEscalations.set(incidentId, {
    timeout,
    stage,
    incidentId,
  });

  console.log(
    `[Auto-Escalation] Scheduled Stage ${stage} timer (${timeoutMs}ms) for incident ${incidentId}`
  );
}

/**
 * Cancels auto-escalation timer when an incident is accepted or resolved.
 */
export function cancelAutoEscalation(incidentId: string): void {
  const existing = activeEscalations.get(incidentId);
  if (existing) {
    clearTimeout(existing.timeout);
    activeEscalations.delete(incidentId);
    console.log(`[Auto-Escalation] Cancelled escalation timer for incident ${incidentId}`);
  }
}

/**
 * Cancels all active auto-escalation timers (e.g. during database purge).
 */
export function clearAllEscalations(): void {
  for (const timer of activeEscalations.values()) {
    clearTimeout(timer.timeout);
  }
  activeEscalations.clear();
  console.log('[Auto-Escalation] Cleared all active escalation timers.');
}

/**
 * Triggers immediate escalation (e.g. when all currently matched hospitals reject).
 */
export async function triggerImmediateEscalation(incidentId: string): Promise<void> {
  const existing = activeEscalations.get(incidentId);
  const currentStage = existing ? existing.stage : 1;
  cancelAutoEscalation(incidentId);
  console.log(
    `[Auto-Escalation] All matched hospitals rejected incident ${incidentId}. Triggering immediate escalation (Stage ${currentStage})...`
  );
  await performEscalation(incidentId, currentStage);
}

/**
 * Performs escalation widening search:
 * Step 1: Trauma centers within 20km (excluding rejected hospitals)
 * Step 2: Any trauma center in the registry (excluding rejected hospitals)
 * If none match: emits incident_unmatched
 */
export async function performEscalation(
  incidentId: string,
  stage: 1 | 2 = 1
): Promise<{ success: boolean; stage: number; newHospitalsCount: number }> {
  // 1. Check current incident status in database (Idempotent guard)
  const incRes = await query<Incident>(
    `SELECT 
       id,
       status,
       accepted_hospital_id,
       victim_metadata,
       ST_Y(location::geometry) AS latitude,
       ST_X(location::geometry) AS longitude,
       created_at,
       updated_at
     FROM incidents 
     WHERE id = $1;`,
    [incidentId]
  );

  if (incRes.rowCount === 0) {
    console.warn(`[Auto-Escalation] Incident ${incidentId} not found in DB.`);
    cancelAutoEscalation(incidentId);
    return { success: false, stage, newHospitalsCount: 0 };
  }

  const incident = {
    ...incRes.rows[0],
    latitude: Number(incRes.rows[0].latitude),
    longitude: Number(incRes.rows[0].longitude),
  };

  // If incident already accepted, resolved, or unmatched, stop escalation
  if (
    incident.status === 'accepted' ||
    incident.status === 'resolved' ||
    incident.status === 'unmatched'
  ) {
    console.log(
      `[Auto-Escalation] Incident ${incidentId} is in '${incident.status}' state. Escalation aborted.`
    );
    cancelAutoEscalation(incidentId);
    return { success: false, stage, newHospitalsCount: 0 };
  }

  // 2. Fetch all rejected hospitals for this incident
  const rejectRes = await query<{ hospital_id: string }>(
    `SELECT hospital_id FROM incident_rejections WHERE incident_id = $1;`,
    [incidentId]
  );
  const rejectedIds = new Set<string>(rejectRes.rows.map((r) => r.hospital_id));

  // 3. Fetch currently matched hospital IDs from volatile Redis RAM
  let currentMatchedIds: string[] = [];
  try {
    const cached = await redis.get(`incident_hospitals:${incidentId}`);
    if (cached) {
      currentMatchedIds = JSON.parse(cached);
    }
  } catch {
    // Non-fatal cache read error
  }

  // Hospitals to exclude: already rejected + already matched
  const excludedIds = Array.from(new Set([...Array.from(rejectedIds), ...currentMatchedIds]));

  let matchedHospitals: Hospital[] = [];

  if (stage === 1) {
    // Stage 1: Search within 20km (20,000 meters) for trauma centers
    const matchSql = `
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
        AND ST_DWithin(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, 20000)
        AND id != ALL($3::uuid[])
      ORDER BY distance_km ASC;
    `;

    const matchRes = await query<Hospital>(matchSql, [
      incident.longitude,
      incident.latitude,
      excludedIds.length > 0 ? excludedIds : ['00000000-0000-0000-0000-000000000000'],
    ]);

    matchedHospitals = matchRes.rows.map((h) => {
      const straightKm = Number(h.distance_km);
      const roadKm = Math.round(straightKm * 1.6 * 10) / 10;
      return {
        ...h,
        latitude: Number(h.latitude),
        longitude: Number(h.longitude),
        distance_km: straightKm,
        road_distance_km: roadKm,
      };
    });

    if (matchedHospitals.length === 0) {
      console.log(
        `[Auto-Escalation] No trauma centers within 20km for incident ${incidentId}. Moving to Stage 2 (Registry-wide)...`
      );
      // Immediately cascade to Stage 2
      return performEscalation(incidentId, 2);
    }
  } else {
    // Stage 2: Any trauma center in the registry (state/city-wide)
    const matchSql = `
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
        AND id != ALL($3::uuid[])
      ORDER BY distance_km ASC;
    `;

    const matchRes = await query<Hospital>(matchSql, [
      incident.longitude,
      incident.latitude,
      excludedIds.length > 0 ? excludedIds : ['00000000-0000-0000-0000-000000000000'],
    ]);

    matchedHospitals = matchRes.rows.map((h) => {
      const straightKm = Number(h.distance_km);
      const roadKm = Math.round(straightKm * 1.6 * 10) / 10;
      return {
        ...h,
        latitude: Number(h.latitude),
        longitude: Number(h.longitude),
        distance_km: straightKm,
        road_distance_km: roadKm,
      };
    });
  }

  // If no facilities found in this stage or registry
  if (matchedHospitals.length === 0) {
    console.warn(
      `[Auto-Escalation] Incident ${incidentId} UNMATCHED: No eligible trauma centers available anywhere.`
    );
    await query(
      `UPDATE incidents SET status = 'unmatched', updated_at = CURRENT_TIMESTAMP WHERE id = $1 AND status IN ('broadcasting', 'escalated');`,
      [incidentId]
    );
    cancelAutoEscalation(incidentId);
    broadcastIncidentUnmatched(incidentId);
    return { success: true, stage, newHospitalsCount: 0 };
  }

  // Facilities found! Update incident status to 'escalated'
  await query(
    `UPDATE incidents SET status = 'escalated', updated_at = CURRENT_TIMESTAMP WHERE id = $1 AND status IN ('broadcasting', 'escalated');`,
    [incidentId]
  );

  // Update Redis matched hospitals cache with newly added hospitals
  const updatedMatchedIds = [
    ...currentMatchedIds,
    ...matchedHospitals.map((h) => h.id),
  ];
  try {
    await redis.setex(
      `incident_hospitals:${incidentId}`,
      900,
      JSON.stringify(updatedMatchedIds)
    );
  } catch (err) {
    console.warn('[Redis] Failed to update matched hospitals during escalation:', err);
  }

  // Broadcast escalation via Socket.io
  const radiusDescription = stage === 1 ? '20km' : 'State Registry';
  broadcastIncidentEscalated(incident, matchedHospitals, radiusDescription);

  // If this was Stage 1, schedule Stage 2 auto-escalation in case newly matched hospitals also timeout/reject
  if (stage === 1) {
    scheduleAutoEscalation(incidentId, 2);
  } else {
    // Stage 2 scheduled timeout: if all stage 2 reject or timeout, mark unmatched
    scheduleAutoEscalation(incidentId, 2);
  }

  return { success: true, stage, newHospitalsCount: matchedHospitals.length };
}
