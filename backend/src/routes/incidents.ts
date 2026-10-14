import { Router, Request, Response } from 'express';
import { query, getClient } from '../db';
import {
  createIncidentSchema,
  incidentIdParamsSchema,
  updateIncidentStatusSchema,
  rejectIncidentSchema,
  nearbyIncidentsQuerySchema,
  claimIncidentSchema,
  ambulanceArrivedSchema,
} from '../validations';
import { Incident, Hospital } from '../types';
import {
  broadcastNewIncident,
  broadcastCaseLocked,
  broadcastCaseAccepted,
  broadcastHospitalRejected,
  broadcastIncidentClaimed,
  broadcastAmbulanceArrived,
  getIO,
} from '../socket';
import {
  redis,
  storeEphemeralHealthCard,
  getEphemeralHealthCard,
  hasEphemeralHealthCard,
} from '../redis';
import {
  scheduleAutoEscalation,
  cancelAutoEscalation,
  clearAllEscalations,
  triggerImmediateEscalation,
} from '../escalation';
import {
  scheduleSilentPromotion,
  cancelSilentPromotion,
  promoteSuspectedIncident,
  clearAllSilentPromotions,
} from '../services/preAlertService';
import { TripSentinelService } from '../services/tripSentinelService';
import { checkIncidentBlackspot, getAllBlackspotZones } from '../services/blackspotService';
import { authenticateJWT, optionalAuth, requireRole } from '../middleware/auth';
import { getAbdmMode } from '../services/abdm';

export const incidentsRouter = Router();

// GET /incidents/blackspots - Retrieve high-frequency accident zones for Police Tactical Map
incidentsRouter.get('/blackspots', async (_req: Request, res: Response) => {
  try {
    const zones = await getAllBlackspotZones();
    return res.status(200).json(zones);
  } catch (err) {
    console.error('[Incidents] Error retrieving blackspot zones:', err);
    return res.status(500).json({ error: 'Failed to retrieve blackspot zones' });
  }
});

/**
 * Helper to strip any sensitive medical data from victim_metadata before Postgres persistence.
 * Medical records and emergency health cards are NEVER stored in Postgres.
 * If health_card is present, it is extracted for volatile Redis RAM storage only.
 */
export function sanitizeVictimMetadata(
  rawMetadata: Record<string, unknown> | null | undefined,
  healthCardObj?: unknown
): { sanitized: Record<string, unknown> | null; healthCardToStore: unknown | null } {
  const metadata = rawMetadata ? { ...rawMetadata } : {};
  let card = healthCardObj || metadata.health_card;
  if (!card && metadata.abha_vault) {
    card = metadata.abha_vault;
  }

  delete metadata.health_card;
  delete metadata.abha_vault;
  delete metadata.blood_group;
  delete metadata.critical_allergies;
  delete metadata.chronic_conditions;
  delete metadata.current_medications;
  delete metadata.medical_history;

  if (card) {
    metadata.has_health_card = true;
  }

  return {
    sanitized: Object.keys(metadata).length > 0 ? metadata : null,
    healthCardToStore: card || null,
  };
}

// POST /incidents/suspected - Fast-path for soft pre-alert to police only
incidentsRouter.post('/suspected', async (req: Request, res: Response) => {
  req.body.status = 'suspected';
  const parseResult = createIncidentSchema.safeParse(req.body);
  if (!parseResult.success) {
    return res.status(400).json({
      error: 'Validation failed',
      message: 'Invalid incident payload',
      details: parseResult.error.errors.map((e) => ({
        field: e.path.join('.'),
        message: e.message,
      })),
    });
  }

  const { id, latitude, longitude, victim_metadata, health_card } = parseResult.data;
  const { sanitized, healthCardToStore } = sanitizeVictimMetadata(victim_metadata, health_card);

  // Idempotency: check if already exists
  if (id) {
    if (healthCardToStore) {
      await storeEphemeralHealthCard(id, JSON.stringify(healthCardToStore));
    }

    const checkExisting = await query<Incident>(
      `SELECT id, status, accepted_hospital_id, victim_metadata,
              ST_Y(location::geometry) AS latitude, ST_X(location::geometry) AS longitude,
              created_at, updated_at
       FROM incidents WHERE id = $1`,
      [id]
    );
    if (checkExisting.rows.length > 0) {
      const existing = checkExisting.rows[0];
      return res.status(200).json({
        message: 'Suspected incident already recorded (idempotent)',
        incident: {
          ...existing,
          latitude: Number(existing.latitude),
          longitude: Number(existing.longitude),
        },
      });
    }
  }

  const insertSql = id
    ? `
      INSERT INTO incidents (id, location, status, victim_metadata)
      VALUES ($1, ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography, 'suspected', $4)
      RETURNING id, status, accepted_hospital_id, victim_metadata,
                ST_Y(location::geometry) AS latitude, ST_X(location::geometry) AS longitude,
                created_at, updated_at;
    `
    : `
      INSERT INTO incidents (location, status, victim_metadata)
      VALUES (ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, 'suspected', $3)
      RETURNING id, status, accepted_hospital_id, victim_metadata,
                ST_Y(location::geometry) AS latitude, ST_X(location::geometry) AS longitude,
                created_at, updated_at;
    `;

  const params = id
    ? [id, longitude, latitude, sanitized ? JSON.stringify(sanitized) : null]
    : [longitude, latitude, sanitized ? JSON.stringify(sanitized) : null];

  const insertResult = await query<Incident>(insertSql, params);
  const raw = insertResult.rows[0];

  // Store Health Card strictly in Redis RAM (never in Postgres)
  if (healthCardToStore) {
    await storeEphemeralHealthCard(raw.id, JSON.stringify(healthCardToStore));
  }

  const blackspotInfo = await checkIncidentBlackspot(Number(raw.latitude), Number(raw.longitude));
  const incident: Incident = {
    ...raw,
    latitude: Number(raw.latitude),
    longitude: Number(raw.longitude),
    blackspot_info: blackspotInfo,
  };

  // Broadcast ONLY to police all_incidents room as soft marker (never to hospitals)
  const io = getIO();
  if (io) {
    io.to('all_incidents').emit('incident_suspected', {
      ...incident,
      is_suspected: true,
      soft_marker: true,
      blackspot_info: blackspotInfo,
    });
  }

  // Arm 30-second silent promotion watchdog
  scheduleSilentPromotion(incident.id, 30000);

  return res.status(201).json({
    message: 'Pre-alert suspected incident logged (Police soft standby)',
    incident,
    is_suspected: true,
  });
});

// POST /incidents/:id/confirm - Promotes suspected incident to full broadcasting trauma triage
incidentsRouter.post('/:id/confirm', async (req: Request, res: Response) => {
  const { id } = req.params;
  const promoted = await promoteSuspectedIncident(id, 'USER_CONFIRMED');
  if (!promoted) {
    return res.status(404).json({ error: 'Incident not found or already resolved' });
  }
  return res.json({
    message: 'Incident confirmed and promoted to trauma triage',
    incident: promoted.incident,
    matched_hospitals: promoted.matchedHospitals,
  });
});

// POST /incidents/:id/cancel - Cancels a suspected incident (User tapped "I'm OK")
incidentsRouter.post('/:id/cancel', async (req: Request, res: Response) => {
  const { id } = req.params;
  cancelSilentPromotion(id);

  const updateResult = await query<Incident>(
    `UPDATE incidents 
     SET status = 'cancelled', 
         victim_metadata = jsonb_set(COALESCE(victim_metadata, '{}'::jsonb), '{cancelled_at}', to_jsonb(CURRENT_TIMESTAMP::text)),
         updated_at = CURRENT_TIMESTAMP 
     WHERE id = $1 
     RETURNING id, status, updated_at`,
    [id]
  );

  if (updateResult.rows.length === 0) {
    return res.status(404).json({ error: 'Incident not found' });
  }

  // Notify police room to remove soft marker
  const io = getIO();
  if (io) {
    io.to('all_incidents').emit('incident_cancelled', {
      id,
      timestamp: new Date().toISOString(),
      reason: 'USER_CANCELLED_OK',
    });
  }

  return res.json({
    message: 'Suspected incident cancelled successfully',
    id,
    status: 'cancelled',
  });
});

// POST /incidents - Create incident & match trauma hospitals within 8km (or idempotent confirm)
incidentsRouter.post('/', async (req: Request, res: Response) => {
  try {
    const parseResult = createIncidentSchema.safeParse(req.body);
    if (!parseResult.success) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Invalid incident payload',
        details: parseResult.error.errors.map((e) => ({
          field: e.path.join('.'),
          message: e.message,
        })),
      });
    }

    const { id, latitude, longitude, victim_metadata, status, health_card } = parseResult.data;
    const { sanitized, healthCardToStore } = sanitizeVictimMetadata(victim_metadata, health_card);

    // Idempotency check on client UUID
    if (id) {
      if (healthCardToStore) {
        await storeEphemeralHealthCard(id, JSON.stringify(healthCardToStore));
      }

      const checkExisting = await query<Incident>(
        `SELECT id, status, accepted_hospital_id, victim_metadata,
                ST_Y(location::geometry) AS latitude, ST_X(location::geometry) AS longitude,
                created_at, updated_at
         FROM incidents WHERE id = $1`,
        [id]
      );

      if (checkExisting.rows.length > 0) {
        const existing = checkExisting.rows[0];
        // If it was suspected and incoming request is confirm (broadcasting), promote it!
        if (existing.status === 'suspected' && (status === 'broadcasting' || !status)) {
          const promoted = await promoteSuspectedIncident(id, 'COUNTDOWN_EXPIRED');
          if (promoted) {
            return res.status(200).json({
              message: 'Suspected incident promoted to broadcasting (idempotent confirm)',
              incident: promoted.incident,
              matched_hospitals: promoted.matchedHospitals,
            });
          }
        }

        return res.status(200).json({
          message: 'Incident already exists (idempotent)',
          incident: {
            ...existing,
            latitude: Number(existing.latitude),
            longitude: Number(existing.longitude),
          },
        });
      }
    }

    // If client requested 'suspected' status explicitly
    if (status === 'suspected') {
      const insertSql = id
        ? `
          INSERT INTO incidents (id, location, status, victim_metadata)
          VALUES ($1, ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography, 'suspected', $4)
          RETURNING id, status, accepted_hospital_id, victim_metadata,
                    ST_Y(location::geometry) AS latitude, ST_X(location::geometry) AS longitude,
                    created_at, updated_at;
        `
        : `
          INSERT INTO incidents (location, status, victim_metadata)
          VALUES (ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, 'suspected', $3)
          RETURNING id, status, accepted_hospital_id, victim_metadata,
                    ST_Y(location::geometry) AS latitude, ST_X(location::geometry) AS longitude,
                    created_at, updated_at;
        `;
      const params = id
        ? [id, longitude, latitude, sanitized ? JSON.stringify(sanitized) : null]
        : [longitude, latitude, sanitized ? JSON.stringify(sanitized) : null];

      const insertResult = await query<Incident>(insertSql, params);
      const raw = insertResult.rows[0];

      if (healthCardToStore) {
        await storeEphemeralHealthCard(raw.id, JSON.stringify(healthCardToStore));
      }

      const blackspotInfo = await checkIncidentBlackspot(Number(raw.latitude), Number(raw.longitude));
      const incident: Incident = {
        ...raw,
        latitude: Number(raw.latitude),
        longitude: Number(raw.longitude),
        blackspot_info: blackspotInfo,
      };

      const io = getIO();
      if (io) {
        io.to('all_incidents').emit('incident_suspected', {
          ...incident,
          is_suspected: true,
          soft_marker: true,
          blackspot_info: blackspotInfo,
        });
      }

      scheduleSilentPromotion(incident.id, 30000);

      return res.status(201).json({
        message: 'Pre-alert suspected incident logged (Police soft standby)',
        incident,
        is_suspected: true,
      });
    }

    // 1. Insert incident into PostgreSQL + PostGIS with 'broadcasting' status
    const insertSql = id
      ? `
        INSERT INTO incidents (id, location, status, victim_metadata)
        VALUES ($1, ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography, 'broadcasting', $4)
        RETURNING id, status, accepted_hospital_id, victim_metadata,
                  ST_Y(location::geometry) AS latitude, ST_X(location::geometry) AS longitude,
                  created_at, updated_at;
      `
      : `
        INSERT INTO incidents (location, status, victim_metadata)
        VALUES (ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, 'broadcasting', $3)
        RETURNING id, status, accepted_hospital_id, victim_metadata,
                  ST_Y(location::geometry) AS latitude, ST_X(location::geometry) AS longitude,
                  created_at, updated_at;
      `;

    const insertParams = id
      ? [id, longitude, latitude, sanitized ? JSON.stringify(sanitized) : null]
      : [longitude, latitude, sanitized ? JSON.stringify(sanitized) : null];

    const insertResult = await query<Incident>(insertSql, insertParams);

    const rawIncident = insertResult.rows[0];

    if (healthCardToStore) {
      await storeEphemeralHealthCard(rawIncident.id, JSON.stringify(healthCardToStore));
    }

    const blackspotInfo = await checkIncidentBlackspot(Number(rawIncident.latitude), Number(rawIncident.longitude));
    const incident: Incident = {
      ...rawIncident,
      latitude: Number(rawIncident.latitude),
      longitude: Number(rawIncident.longitude),
      blackspot_info: blackspotInfo,
    };

    // 2. PostGIS 8km Radius Matching Query (8000 meters, has_trauma_center = true)
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
      longitude,
      latitude,
    ]);

    const matchedHospitals = matchResult.rows.map((h: Hospital) => {
      const straightKm = Number(h.distance_km);
      // Indian urban road network circuity factor (~1.6x straight-line distance)
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

    // Broadcast in real-time to matched hospital rooms and police all_incidents room
    broadcastNewIncident(incident, matchedHospitals);

    // Cache matched hospital IDs in volatile Redis RAM (15m TTL) for Phase 6 & 7 room routing
    try {
      await redis.setex(
        `incident_hospitals:${incident.id}`,
        900,
        JSON.stringify(matchedHospitals.map((h) => h.id))
      );
    } catch (e) {
      console.warn('[Redis] Failed to cache matched hospital IDs:', e);
    }

    // Phase 7: Schedule auto-escalation timer
    if (matchedHospitals.length === 0) {
      // 0 matched hospitals within 8km -> immediately trigger auto-escalation (Stage 1 / 2)
      scheduleAutoEscalation(incident.id, 1, 0);
    } else {
      // Default 45s timer before search radius widens
      scheduleAutoEscalation(incident.id, 1);
    }

    return res.status(201).json({
      message: 'Incident recorded successfully and trauma triage query executed.',
      incident,
      search_radius_km: 8,
      matched_hospitals_count: matchResult.rowCount,
      matched_hospitals: matchedHospitals,
    });
  } catch (error) {
    console.error('[POST /incidents Error]', error);
    return res.status(500).json({
      error: 'Incident creation failed',
      message:
        error instanceof Error
          ? error.message
          : 'Unexpected database error while creating incident.',
    });
  }
});

// GET /incidents - Retrieve recent incidents with matched trauma hospitals (for Police & Hospital views)
incidentsRouter.get('/', optionalAuth, async (req: Request, res: Response) => {
  try {
    const limit = Math.min(Math.max(parseInt(req.query.limit as string) || 20, 1), 100);
    let hospitalId = typeof req.query.hospital_id === 'string' ? req.query.hospital_id : undefined;

    // Phase 13: Automatically scope incident queries to authenticated hospital_staff's hospital_id
    if (!hospitalId && req.user?.role === 'hospital_staff' && req.user.hospital_id) {
      hospitalId = req.user.hospital_id;
    }

    let sql = '';
    const params: unknown[] = [];

    if (hospitalId) {
      // Filter to incidents within 8km (or 20km if escalated) of the requested hospital
      sql = `
        SELECT 
          i.id,
          i.status,
          i.accepted_hospital_id,
          i.ambulance_id,
          i.ambulance_plate,
          i.ambulance_driver_name,
          i.ambulance_driver_phone,
          i.ambulance_origin_station,
          i.ambulance_arrived_at,
          i.ambulance_arrival_lat,
          i.ambulance_arrival_lng,
          i.victim_metadata,
          ST_Y(i.location::geometry) AS latitude,
          ST_X(i.location::geometry) AS longitude,
          i.created_at,
          i.updated_at,
          ROUND((ST_Distance(h_spec.location, i.location) / 1000)::numeric, 2) AS hospital_distance_km,
          CASE 
            WHEN h_acc.id IS NOT NULL THEN
              json_build_object(
                'id', h_acc.id,
                'name', h_acc.name,
                'phone', h_acc.phone,
                'address', h_acc.address,
                'has_trauma_center', h_acc.has_trauma_center,
                'has_icu_capacity', h_acc.has_icu_capacity,
                'latitude', ST_Y(h_acc.location::geometry),
                'longitude', ST_X(h_acc.location::geometry),
                'distance_km', ROUND((ST_Distance(h_acc.location, i.location) / 1000)::numeric, 2)
              )
            ELSE NULL 
          END AS accepted_hospital,
          COALESCE(
            (
              SELECT json_agg(
                json_build_object(
                  'id', h.id,
                  'name', h.name,
                  'phone', h.phone,
                  'address', h.address,
                  'has_trauma_center', h.has_trauma_center,
                  'has_icu_capacity', h.has_icu_capacity,
                  'is_verified', h.is_verified,
                  'latitude', ST_Y(h.location::geometry),
                  'longitude', ST_X(h.location::geometry),
                  'distance_km', ROUND((ST_Distance(h.location, i.location) / 1000)::numeric, 2),
                  'road_distance_km', ROUND(((ST_Distance(h.location, i.location) / 1000) * 1.6)::numeric, 1)
                ) ORDER BY ST_Distance(h.location, i.location) ASC
              )
              FROM hospitals h
              WHERE h.has_trauma_center = true
                AND ST_DWithin(h.location, i.location, CASE WHEN i.status = 'escalated' THEN 20000 ELSE 8000 END)
            ),
            '[]'::json
          ) AS matched_hospitals,
          COALESCE(
            (
              SELECT json_agg(
                json_build_object(
                  'hospital_id', ir.hospital_id,
                  'hospital_name', h_rej.name,
                  'reason', ir.reason,
                  'created_at', ir.created_at
                ) ORDER BY ir.created_at ASC
              )
              FROM incident_rejections ir
              JOIN hospitals h_rej ON h_rej.id = ir.hospital_id
              WHERE ir.incident_id = i.id
            ),
            '[]'::json
          ) AS rejections
        FROM incidents i
        JOIN hospitals h_spec ON h_spec.id = $1
        LEFT JOIN hospitals h_acc ON i.accepted_hospital_id = h_acc.id
        WHERE ST_DWithin(h_spec.location, i.location, CASE WHEN i.status = 'escalated' THEN 20000 ELSE 8000 END)
        ORDER BY i.created_at DESC
        LIMIT $2;
      `;
      params.push(hospitalId, limit);
    } else {
      // City-wide incidents for Police Control Room with all matched trauma centers
      sql = `
        SELECT 
          i.id,
          i.status,
          i.accepted_hospital_id,
          i.ambulance_id,
          i.ambulance_plate,
          i.ambulance_driver_name,
          i.ambulance_driver_phone,
          i.ambulance_origin_station,
          i.ambulance_arrived_at,
          i.ambulance_arrival_lat,
          i.ambulance_arrival_lng,
          i.victim_metadata,
          ST_Y(i.location::geometry) AS latitude,
          ST_X(i.location::geometry) AS longitude,
          i.created_at,
          i.updated_at,
          CASE 
            WHEN h_acc.id IS NOT NULL THEN
              json_build_object(
                'id', h_acc.id,
                'name', h_acc.name,
                'phone', h_acc.phone,
                'address', h_acc.address,
                'has_trauma_center', h_acc.has_trauma_center,
                'has_icu_capacity', h_acc.has_icu_capacity,
                'latitude', ST_Y(h_acc.location::geometry),
                'longitude', ST_X(h_acc.location::geometry),
                'distance_km', ROUND((ST_Distance(h_acc.location, i.location) / 1000)::numeric, 2)
              )
            ELSE NULL 
          END AS accepted_hospital,
          COALESCE(
            (
              SELECT json_agg(
                json_build_object(
                  'id', h.id,
                  'name', h.name,
                  'phone', h.phone,
                  'address', h.address,
                  'has_trauma_center', h.has_trauma_center,
                  'has_icu_capacity', h.has_icu_capacity,
                  'is_verified', h.is_verified,
                  'latitude', ST_Y(h.location::geometry),
                  'longitude', ST_X(h.location::geometry),
                  'distance_km', ROUND((ST_Distance(h.location, i.location) / 1000)::numeric, 2),
                  'road_distance_km', ROUND(((ST_Distance(h.location, i.location) / 1000) * 1.6)::numeric, 1)
                ) ORDER BY ST_Distance(h.location, i.location) ASC
              )
              FROM hospitals h
              WHERE h.has_trauma_center = true
                AND ST_DWithin(h.location, i.location, 20000)
            ),
            '[]'::json
          ) AS matched_hospitals,
          COALESCE(
            (
              SELECT json_agg(
                json_build_object(
                  'hospital_id', ir.hospital_id,
                  'hospital_name', h_rej.name,
                  'reason', ir.reason,
                  'created_at', ir.created_at
                ) ORDER BY ir.created_at ASC
              )
              FROM incident_rejections ir
              JOIN hospitals h_rej ON h_rej.id = ir.hospital_id
              WHERE ir.incident_id = i.id
            ),
            '[]'::json
          ) AS rejections
        FROM incidents i
        LEFT JOIN hospitals h_acc ON i.accepted_hospital_id = h_acc.id
        ORDER BY i.created_at DESC
        LIMIT $1;
      `;
      params.push(limit);
    }

    const result = await query(sql, params);

    // Retrieve active volatile image stream URLs and ambulance telemetry from Redis RAM
    const imageKeys = result.rows.map((row: Record<string, unknown>) => `incident_image:${row.id}`);
    const ambKeys = result.rows.map((row: Record<string, unknown>) => `ambulance_loc:${row.id}`);

    let cachedImages: (string | null)[] = [];
    let cachedAmbulanceLocs: (string | null)[] = [];

    if (imageKeys.length > 0) {
      try {
        [cachedImages, cachedAmbulanceLocs] = await Promise.all([
          redis.mget(imageKeys),
          redis.mget(ambKeys),
        ]);
      } catch (err) {
        console.warn('[Redis] Failed to fetch cached image URLs / ambulance telemetry:', err);
      }
    }

    const incidents = result.rows.map((row: Record<string, unknown>, idx: number) => {
      const matchedHospitals = Array.isArray(row.matched_hospitals) ? row.matched_hospitals : [];
      const straightKm = row.hospital_distance_km !== undefined && row.hospital_distance_km !== null
        ? Number(row.hospital_distance_km)
        : matchedHospitals.length > 0
          ? Number(matchedHospitals[0].distance_km)
          : null;
      const roadKm = straightKm !== null ? Math.round(straightKm * 1.6 * 10) / 10 : null;

      let ambLoc = null;
      if (cachedAmbulanceLocs[idx]) {
        try {
          ambLoc = JSON.parse(cachedAmbulanceLocs[idx] as string);
        } catch {
          // ignore
        }
      }

      return {
        id: row.id,
        latitude: Number(row.latitude),
        longitude: Number(row.longitude),
        status: row.status,
        accepted_hospital_id: row.accepted_hospital_id,
        accepted_hospital: row.accepted_hospital || null,
        ambulance_id: row.ambulance_id || null,
        ambulance_plate: (row.ambulance_plate as string) || (row.ambulance_id ? 'KA-01-EA-108' : null),
        ambulance_driver_name: (row.ambulance_driver_name as string) || (row.ambulance_id ? 'Ramesh Kumar' : null),
        ambulance_driver_phone: (row.ambulance_driver_phone as string) || (row.ambulance_id ? '+91 98450 12345' : null),
        ambulance_origin_station: (row.ambulance_origin_station as string) || (row.ambulance_id ? 'Manipal Hospital HAL Depot Base' : null),
        ambulance_arrived_at: (row.ambulance_arrived_at as string) || null,
        ambulance_arrival_lat: row.ambulance_arrival_lat ? Number(row.ambulance_arrival_lat) : null,
        ambulance_arrival_lng: row.ambulance_arrival_lng ? Number(row.ambulance_arrival_lng) : null,
        ambulance_location: ambLoc,
        victim_metadata: row.victim_metadata,
        created_at: row.created_at,
        updated_at: row.updated_at,
        distance_km: straightKm,
        road_distance_km: roadKm,
        imageUrl: cachedImages[idx] || null,
        hospital_id: hospitalId || (matchedHospitals[0]?.id ?? undefined),
        hospital_name: matchedHospitals[0]?.name ?? undefined,
        matched_hospitals_count: matchedHospitals.length,
        matched_hospitals: matchedHospitals,
        rejections: Array.isArray(row.rejections) ? row.rejections : [],
      };
    });

    const incidentsWithBlackspots = await Promise.all(
      incidents.map(async (inc) => {
        const blackspot_info = await checkIncidentBlackspot(inc.latitude, inc.longitude);
        return {
          ...inc,
          blackspot_info,
        };
      })
    );

    return res.json({
      incidents: incidentsWithBlackspots,
      total: incidentsWithBlackspots.length,
    });
  } catch (error) {
    console.error('[GET /incidents Error]', error);
    return res.status(500).json({
      error: 'Query failed',
      message:
        error instanceof Error
          ? error.message
          : 'Unexpected database error while fetching incidents.',
    });
  }
});

// DELETE /incidents - Purge test incidents from database, Redis RAM, watchdog timers, and broadcast feed_cleared
incidentsRouter.delete('/', async (req: Request, res: Response) => {
  try {
    await query('DELETE FROM incident_rejections;');
    await query('DELETE FROM incidents;');
    clearAllEscalations();
    clearAllSilentPromotions();
    TripSentinelService.getInstance().clearAllSessions();

    try {
      const io = getIO();
      if (io) {
        io.emit('feed_cleared');
        io.to('all_incidents').emit('feed_cleared');
      }
    } catch {
      // Socket.io might not be initialized
    }

    // Clean up volatile Redis RAM keys so future feeds start 100% clean
    try {
      const [incidentKeys, ambKeys, sentinelKeys] = await Promise.all([
        redis.keys('incident_*'),
        redis.keys('ambulance_*'),
        redis.keys('sentinel_*'),
      ]);
      const allKeys = [...incidentKeys, ...ambKeys, ...sentinelKeys];
      if (allKeys.length > 0) {
        await redis.del(...allKeys);
      }
    } catch (redisErr) {
      console.warn('[Redis] Failed to clear keys on DELETE /incidents:', redisErr);
    }

    return res.json({
      message: 'All active alerts and test incidents purged successfully from database, Redis RAM, and memory timers.',
      cleared: true,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('[DELETE /incidents Error]', error);
    return res.status(500).json({
      error: 'Purge failed',
      message:
        error instanceof Error
          ? error.message
          : 'Unexpected database error while purging incidents.',
    });
  }
});

// GET /incidents/stats - System health and incident counts for Admin Console
incidentsRouter.get('/stats', async (_req: Request, res: Response) => {
  try {
    const countsRes = await query<{ status: string; count: string }>(
      `SELECT status, COUNT(*)::text AS count FROM incidents GROUP BY status`
    );

    const statusCounts: Record<string, number> = {
      detected: 0,
      broadcasting: 0,
      accepted: 0,
      en_route: 0,
      resolved: 0,
      escalated: 0,
      unmatched: 0,
      suspected: 0,
      cancelled: 0,
    };

    let total = 0;
    countsRes.rows.forEach((r) => {
      const c = parseInt(r.count, 10) || 0;
      statusCounts[r.status] = c;
      total += c;
    });

    const activeHospitalsRes = await query<{ count: string }>(
      `SELECT COUNT(*)::text AS count FROM hospitals WHERE is_verified = true`
    );
    const totalHospitals = parseInt(activeHospitalsRes.rows[0]?.count || '0', 10);

    const [incidentKeys, ambKeys, sentinelKeys] = await Promise.all([
      redis.keys('incident_*'),
      redis.keys('ambulance_*'),
      redis.keys('sentinel_*'),
    ]);

    const sentinelSessions = TripSentinelService.getInstance().getActiveSessionsSummary();

    return res.json({
      total_incidents: total,
      status_counts: statusCounts,
      total_hospitals: totalHospitals,
      redis_cached_keys: incidentKeys.length + ambKeys.length + sentinelKeys.length,
      active_sentinel_sessions: sentinelSessions.length,
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    console.error('[GET /incidents/stats Error]', err);
    return res.status(500).json({ error: 'Failed to retrieve incident stats' });
  }
});

// GET /incidents/nearby - Retrieve active incidents within radius_km of ambulance GPS location
incidentsRouter.get('/nearby', async (req: Request, res: Response) => {
  try {
    const parseResult = nearbyIncidentsQuerySchema.safeParse(req.query);
    if (!parseResult.success) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Invalid nearby incidents query parameters',
        details: parseResult.error.errors.map((e) => ({
          field: e.path.join('.'),
          message: e.message,
        })),
      });
    }

    const { lat, lng, radius_km } = parseResult.data;
    const radiusMeters = radius_km * 1000;

    const sql = `
      SELECT 
        i.id,
        i.status,
        i.accepted_hospital_id,
        i.ambulance_id,
        i.ambulance_plate,
        i.ambulance_driver_name,
        i.ambulance_driver_phone,
        i.ambulance_origin_station,
        i.ambulance_arrived_at,
        i.ambulance_arrival_lat,
        i.ambulance_arrival_lng,
        i.victim_metadata,
        ST_Y(i.location::geometry) AS latitude,
        ST_X(i.location::geometry) AS longitude,
        i.created_at,
        i.updated_at,
        ROUND((ST_Distance(i.location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography) / 1000)::numeric, 2) AS distance_km,
        CASE 
          WHEN h.id IS NOT NULL THEN
            json_build_object(
              'id', h.id,
              'name', h.name,
              'phone', h.phone,
              'address', h.address,
              'has_trauma_center', h.has_trauma_center,
              'has_icu_capacity', h.has_icu_capacity,
              'latitude', ST_Y(h.location::geometry),
              'longitude', ST_X(h.location::geometry),
              'distance_km', ROUND((ST_Distance(h.location, i.location) / 1000)::numeric, 2)
            )
          ELSE NULL 
        END AS accepted_hospital
      FROM incidents i
      LEFT JOIN hospitals h ON i.accepted_hospital_id = h.id
      WHERE i.status IN ('broadcasting', 'escalated', 'accepted', 'en_route')
        AND ST_DWithin(i.location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $3)
      ORDER BY distance_km ASC;
    `;

    const result = await query(sql, [lng, lat, radiusMeters]);

    // Check Redis RAM for ephemeral photos and ambulance live telemetry
    const imageKeys = result.rows.map((row: Record<string, unknown>) => `incident_image:${row.id}`);
    const ambKeys = result.rows.map((row: Record<string, unknown>) => `ambulance_loc:${row.id}`);

    let cachedImages: (string | null)[] = [];
    let cachedAmbulanceLocs: (string | null)[] = [];

    if (imageKeys.length > 0) {
      try {
        [cachedImages, cachedAmbulanceLocs] = await Promise.all([
          redis.mget(imageKeys),
          redis.mget(ambKeys),
        ]);
      } catch (err) {
        console.warn('[Redis] Failed to fetch cached image URLs / ambulance telemetry in nearby:', err);
      }
    }

    const incidents = result.rows.map((row: Record<string, unknown>, idx: number) => {
      const straightKm = Number(row.distance_km);
      const roadKm = Math.round(straightKm * 1.6 * 10) / 10;

      let ambLoc = null;
      if (cachedAmbulanceLocs[idx]) {
        try {
          ambLoc = JSON.parse(cachedAmbulanceLocs[idx] as string);
        } catch {
          // ignore
        }
      }

      return {
        id: row.id,
        latitude: Number(row.latitude),
        longitude: Number(row.longitude),
        status: row.status,
        accepted_hospital_id: row.accepted_hospital_id,
        accepted_hospital: row.accepted_hospital || null,
        ambulance_id: row.ambulance_id || null,
        ambulance_plate: (row.ambulance_plate as string) || (row.ambulance_id ? 'KA-01-EA-108' : null),
        ambulance_driver_name: (row.ambulance_driver_name as string) || (row.ambulance_id ? 'Ramesh Kumar' : null),
        ambulance_driver_phone: (row.ambulance_driver_phone as string) || (row.ambulance_id ? '+91 98450 12345' : null),
        ambulance_origin_station: (row.ambulance_origin_station as string) || (row.ambulance_id ? 'Manipal Hospital HAL Depot Base' : null),
        ambulance_arrived_at: (row.ambulance_arrived_at as string) || null,
        ambulance_arrival_lat: row.ambulance_arrival_lat ? Number(row.ambulance_arrival_lat) : null,
        ambulance_arrival_lng: row.ambulance_arrival_lng ? Number(row.ambulance_arrival_lng) : null,
        ambulance_location: ambLoc,
        victim_metadata: row.victim_metadata,
        created_at: row.created_at,
        updated_at: row.updated_at,
        distance_km: straightKm,
        road_distance_km: roadKm,
        imageUrl: cachedImages[idx] || null,
      };
    });

    return res.json({
      incidents,
      total: incidents.length,
      search_radius_km: radius_km,
      ambulance_location: { latitude: lat, longitude: lng },
    });
  } catch (error) {
    console.error('[GET /incidents/nearby Error]', error);
    return res.status(500).json({
      error: 'Query failed',
      message:
        error instanceof Error
          ? error.message
          : 'Unexpected database error while fetching nearby incidents.',
    });
  }
});

// POST /incidents/:id/claim - Ambulance claims the emergency case
// Scope Limitation Note: Mobile ambulance console uses device-UUID claiming from Phase 8
// without full personnel login. If an auth token is provided, ambulance/hospital_staff/police roles are allowed.
incidentsRouter.post('/:id/claim', optionalAuth, async (req: Request, res: Response) => {
  try {
    if (req.user && !['ambulance', 'hospital_staff', 'police'].includes(req.user.role)) {
      return res.status(403).json({
        error: 'Forbidden',
        message: `Role '${req.user.role}' is not authorized to claim incidents.`,
      });
    }

    const paramsResult = incidentIdParamsSchema.safeParse(req.params);
    if (!paramsResult.success) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Invalid incident ID format. Must be a valid UUID.',
      });
    }

    const bodyResult = claimIncidentSchema.safeParse(req.body);
    if (!bodyResult.success) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Invalid claim payload',
        details: bodyResult.error.errors.map((e) => ({
          field: e.path.join('.'),
          message: e.message,
        })),
      });
    }

    const { id } = paramsResult.data;
    const { ambulance_id, ambulance_plate, driver_name, driver_phone, origin_station } = bodyResult.data;

    const incCheck = await query<{ id: string; status: string; ambulance_id: string | null }>(
      'SELECT id, status, ambulance_id FROM incidents WHERE id = $1;',
      [id]
    );

    if (incCheck.rowCount === 0) {
      return res.status(404).json({
        error: 'Not found',
        message: `Incident with ID '${id}' does not exist.`,
      });
    }

    const existing = incCheck.rows[0];
    if (existing.ambulance_id && existing.ambulance_id !== ambulance_id) {
      return res.status(409).json({
        error: 'Conflict',
        message: `Incident is already claimed by another ambulance unit: ${existing.ambulance_id}`,
        claimed_by: existing.ambulance_id,
        incident_id: id,
      });
    }

    const plate = ambulance_plate || 'KA-01-EA-108';
    const driver = driver_name || 'Ramesh Kumar';
    const phone = driver_phone || '+91 98450 12345';
    const origin = origin_station || 'Manipal Hospital HAL Depot Base';

    const updateRes = await query<Incident>(
      `UPDATE incidents
       SET ambulance_id = $1,
           ambulance_plate = COALESCE($2, ambulance_plate, 'KA-01-EA-108'),
           ambulance_driver_name = COALESCE($3, ambulance_driver_name, 'Ramesh Kumar'),
           ambulance_driver_phone = COALESCE($4, ambulance_driver_phone, '+91 98450 12345'),
           ambulance_origin_station = COALESCE($5, ambulance_origin_station, 'Manipal Hospital HAL Depot Base'),
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $6 AND (ambulance_id IS NULL OR ambulance_id = $1)
       RETURNING 
         id, status, accepted_hospital_id, ambulance_id,
         ambulance_plate, ambulance_driver_name, ambulance_driver_phone, ambulance_origin_station,
         ambulance_arrived_at, ambulance_arrival_lat, ambulance_arrival_lng,
         victim_metadata,
         ST_Y(location::geometry) AS latitude,
         ST_X(location::geometry) AS longitude,
         created_at, updated_at;`,
      [ambulance_id, plate, driver, phone, origin, id]
    );

    if (updateRes.rowCount === 0) {
      return res.status(409).json({
        error: 'Conflict',
        message: 'Incident was claimed by another unit concurrently.',
        incident_id: id,
      });
    }

    const claimedIncident = {
      ...updateRes.rows[0],
      latitude: Number(updateRes.rows[0].latitude),
      longitude: Number(updateRes.rows[0].longitude),
    };

    broadcastIncidentClaimed(id, ambulance_id, {
      ambulance_plate: plate,
      driver_name: driver,
      driver_phone: phone,
      origin_station: origin,
    });

    return res.json({
      message: `Incident successfully claimed by ambulance ${ambulance_id}`,
      incident: claimedIncident,
    });
  } catch (error) {
    console.error('[POST /incidents/:id/claim Error]', error);
    return res.status(500).json({
      error: 'Claim failed',
      message:
        error instanceof Error
          ? error.message
          : 'Unexpected database error while claiming incident.',
    });
  }
});

// POST /incidents/:id/ambulance-arrived - Ambulance reports zero-touch or manual on-scene arrival
incidentsRouter.post('/:id/ambulance-arrived', optionalAuth, async (req: Request, res: Response) => {
  try {
    const paramsResult = incidentIdParamsSchema.safeParse(req.params);
    if (!paramsResult.success) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Invalid incident ID format. Must be a valid UUID.',
      });
    }

    const bodyResult = ambulanceArrivedSchema.safeParse(req.body);
    if (!bodyResult.success) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Invalid arrival payload',
        details: bodyResult.error.errors.map((e) => ({
          field: e.path.join('.'),
          message: e.message,
        })),
      });
    }

    const { id } = paramsResult.data;
    const {
      ambulance_id,
      latitude,
      longitude,
      arrived_at,
      ambulance_plate,
      driver_name,
      driver_phone,
      origin_station,
    } = bodyResult.data;

    const arrivalTimestamp = arrived_at || new Date().toISOString();
    const plate = ambulance_plate || 'KA-01-EA-108';
    const driver = driver_name || 'Ramesh Kumar';
    const phone = driver_phone || '+91 98450 12345';
    const origin = origin_station || 'Manipal Hospital HAL Depot Base';

    const updateRes = await query<Incident>(
      `UPDATE incidents
       SET ambulance_arrived_at = $1,
           ambulance_arrival_lat = $2,
           ambulance_arrival_lng = $3,
           ambulance_id = COALESCE(ambulance_id, $4),
           ambulance_plate = COALESCE($5, ambulance_plate, 'KA-01-EA-108'),
           ambulance_driver_name = COALESCE($6, ambulance_driver_name, 'Ramesh Kumar'),
           ambulance_driver_phone = COALESCE($7, ambulance_driver_phone, '+91 98450 12345'),
           ambulance_origin_station = COALESCE($8, ambulance_origin_station, 'Manipal Hospital HAL Depot Base'),
           updated_at = CURRENT_TIMESTAMP
       WHERE id = $9
       RETURNING 
         id, status, accepted_hospital_id, ambulance_id,
         ambulance_plate, ambulance_driver_name, ambulance_driver_phone, ambulance_origin_station,
         ambulance_arrived_at, ambulance_arrival_lat, ambulance_arrival_lng,
         victim_metadata,
         ST_Y(location::geometry) AS latitude,
         ST_X(location::geometry) AS longitude,
         created_at, updated_at;`,
      [
        arrivalTimestamp,
        latitude ?? null,
        longitude ?? null,
        ambulance_id,
        plate,
        driver,
        phone,
        origin,
        id,
      ]
    );

    if (updateRes.rowCount === 0) {
      return res.status(404).json({
        error: 'Not found',
        message: `Incident with ID '${id}' does not exist.`,
      });
    }

    const arrivedIncident = {
      ...updateRes.rows[0],
      latitude: Number(updateRes.rows[0].latitude),
      longitude: Number(updateRes.rows[0].longitude),
    };

    const arrivalPayload = {
      incident_id: id,
      ambulance_id,
      ambulance_plate: plate,
      driver_name: driver,
      driver_phone: phone,
      origin_station: origin,
      arrived_at: arrivalTimestamp,
      latitude,
      longitude,
    };

    try {
      await redis.setex(`ambulance_arrived:${id}`, 1800, JSON.stringify(arrivalPayload));
    } catch {
      // Non-fatal cache write
    }

    await broadcastAmbulanceArrived(arrivalPayload);

    return res.json({
      message: `Ambulance ${ambulance_id} arrival recorded on-scene.`,
      incident: arrivedIncident,
      arrival: arrivalPayload,
    });
  } catch (error) {
    console.error('[POST /incidents/:id/ambulance-arrived Error]', error);
    return res.status(500).json({
      error: 'Arrival logging failed',
      message:
        error instanceof Error
          ? error.message
          : 'Unexpected database error while recording ambulance arrival.',
    });
  }
});

// GET /incidents/:id - Retrieve incident detail by ID
incidentsRouter.get('/:id', async (req: Request, res: Response) => {
  try {
    const paramsResult = incidentIdParamsSchema.safeParse(req.params);
    if (!paramsResult.success) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Invalid incident ID format. Must be a valid UUID.',
      });
    }

    const { id } = paramsResult.data;

    const sql = `
      SELECT 
        i.id,
        i.status,
        i.accepted_hospital_id,
        i.ambulance_id,
        i.ambulance_plate,
        i.ambulance_driver_name,
        i.ambulance_driver_phone,
        i.ambulance_origin_station,
        i.ambulance_arrived_at,
        i.ambulance_arrival_lat,
        i.ambulance_arrival_lng,
        i.victim_metadata,
        ST_Y(i.location::geometry) AS latitude,
        ST_X(i.location::geometry) AS longitude,
        i.created_at,
        i.updated_at,
        CASE 
          WHEN h.id IS NOT NULL THEN
            json_build_object(
              'id', h.id,
              'name', h.name,
              'phone', h.phone,
              'address', h.address,
              'has_trauma_center', h.has_trauma_center,
              'has_icu_capacity', h.has_icu_capacity,
              'latitude', ST_Y(h.location::geometry),
              'longitude', ST_X(h.location::geometry)
            )
          ELSE NULL 
        END AS accepted_hospital
      FROM incidents i
      LEFT JOIN hospitals h ON i.accepted_hospital_id = h.id
      WHERE i.id = $1;
    `;

    const result = await query(sql, [id]);

    if (result.rowCount === 0) {
      return res.status(404).json({
        error: 'Not found',
        message: `Incident with ID '${id}' does not exist.`,
      });
    }

    let imageUrl: string | null = null;
    let ambulanceLocation = null;

    try {
      const [img, amb] = await Promise.all([
        redis.get(`incident_image:${id}`),
        redis.get(`ambulance_loc:${id}`),
      ]);
      imageUrl = img;
      if (amb) {
        ambulanceLocation = JSON.parse(amb);
      }
    } catch {
      // Non-fatal cache read
    }

    return res.json({
      incident: {
        ...result.rows[0],
        imageUrl,
        ambulance_location: ambulanceLocation,
      },
    });
  } catch (error) {
    console.error('[GET /incidents/:id Error]', error);
    return res.status(500).json({
      error: 'Query failed',
      message:
        error instanceof Error
          ? error.message
          : 'Unexpected error while retrieving incident.',
    });
  }
});

// GET /incidents/:id/image - Directly retrieve ephemeral in-memory photo from Redis RAM
incidentsRouter.get('/:id/image', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const imageUrl = await redis.get(`incident_image:${id}`);
    if (!imageUrl) {
      return res.status(404).json({ error: 'Image not found or expired', imageUrl: null });
    }
    return res.json({ incident_id: id, imageUrl });
  } catch (err) {
    console.error('[GET /incidents/:id/image Error]', err);
    return res.status(500).json({ error: 'Failed to retrieve image from cache' });
  }
});

// POST /incidents/:id/image - Upload ephemeral in-memory photo stream (HTTP fallback for WebSockets)
incidentsRouter.post('/:id/image', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { image } = req.body;

    if (!image) {
      return res.status(400).json({ error: 'Missing image payload' });
    }

    let base64Data: string;
    if (typeof image === 'string') {
      base64Data = image.replace(/^data:image\/\w+;base64,/, '');
    } else {
      base64Data = Buffer.from(image).toString('base64');
    }

    const dataUrl = `data:image/jpeg;base64,${base64Data}`;

    // Verify incident ID or auto-heal
    let effectiveIncidentId = id;
    try {
      const checkRes = await query('SELECT id FROM incidents WHERE id = $1;', [id]);
      if (checkRes.rowCount === 0) {
        const recentRes = await query<{ id: string }>(
          `SELECT id FROM incidents WHERE created_at > NOW() - INTERVAL '5 minutes' ORDER BY created_at DESC LIMIT 1;`
        );
        if (recentRes.rowCount && recentRes.rowCount > 0) {
          effectiveIncidentId = recentRes.rows[0].id;
        }
      }
    } catch (_) {
      // Non-fatal incident auto-healing check failure
    }

    // Store in volatile Redis RAM with 15-minute TTL (900 seconds)
    await redis.setex(`incident_image:${effectiveIncidentId}`, 900, dataUrl);
    if (effectiveIncidentId !== id) {
      await redis.setex(`incident_image:${id}`, 900, dataUrl);
    }
    console.log(`[Zero-Storage Engine] Stored photo stream via HTTP POST in Redis RAM (TTL 900s): incident_image:${effectiveIncidentId}`);

    // Broadcast image_update via Socket.IO
    const io = getIO();
    if (io) {
      let hospitalIds: string[] = [];
      try {
        const cachedHospitals = await redis.get(`incident_hospitals:${effectiveIncidentId}`);
        if (cachedHospitals) {
          hospitalIds = JSON.parse(cachedHospitals);
        }
      } catch (_) {
        // Non-fatal cache read failure
      }

      const updatePayload = {
        incident_id: effectiveIncidentId,
        imageUrl: dataUrl,
      };

      hospitalIds.forEach((hId) => {
        io!.to(hId).emit('image_update', updatePayload);
      });
      io!.to('all_incidents').emit('image_update', updatePayload);
      console.log(`[Socket.io] Broadcast image_update via HTTP upload for incident: ${effectiveIncidentId}`);
    }

    return res.json({ status: 'ok', incident_id: effectiveIncidentId });
  } catch (err) {
    console.error('[POST /incidents/:id/image Error]', err);
    return res.status(500).json({ error: 'Failed to store image in volatile cache' });
  }
});

// GET /incidents/:id/health-card/status - Check if an ephemeral health card exists (Yes/No only, no contents)
incidentsRouter.get('/:id/health-card/status', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const hasCard = await hasEphemeralHealthCard(id);
    return res.status(200).json({
      incident_id: id,
      has_health_card: hasCard,
    });
  } catch (err: unknown) {
    console.error('[GET /incidents/:id/health-card/status Error]', err);
    return res.status(500).json({ error: 'Failed to check health card status' });
  }
});

// POST /incidents/:id/health-card - Upload/update ephemeral health card snapshot (volatile Redis RAM only, TTL 2h)
incidentsRouter.post('/:id/health-card', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const card = req.body.health_card || req.body;
    if (!card || typeof card !== 'object') {
      return res.status(400).json({ error: 'Missing health_card payload' });
    }

    await storeEphemeralHealthCard(id, JSON.stringify(card));

    const io = getIO();
    if (io) {
      io.to('all_incidents').emit('incident_health_card_status', {
        incident_id: id,
        has_health_card: true,
      });
    }

    return res.status(200).json({
      status: 'ok',
      incident_id: id,
      message: 'Emergency health card stored in volatile Redis RAM (TTL 2h)',
    });
  } catch (err: unknown) {
    console.error('[POST /incidents/:id/health-card Error]', err);
    return res.status(500).json({ error: 'Failed to store health card' });
  }
});

// POST /incidents/:id/health-card/break-glass - Hospital Staff Break-Glass access with mandatory clinical reason
incidentsRouter.post(
  '/:id/health-card/break-glass',
  authenticateJWT,
  requireRole('hospital_staff'),
  async (req: Request, res: Response) => {
    try {
      const { id } = req.params;
      const { reason } = req.body;

      if (!reason || typeof reason !== 'string' || reason.trim().length < 5) {
        return res.status(400).json({
          error: 'Bad Request',
          message: 'Mandatory clinical break-glass reason required (minimum 5 characters).',
        });
      }

      // Verify incident exists and has been accepted by this user's assigned hospital
      const incRes = await query<{
        id: string;
        status: string;
        accepted_hospital_id: string | null;
      }>(
        'SELECT id, status, accepted_hospital_id FROM incidents WHERE id = $1',
        [id]
      );

      if (incRes.rows.length === 0) {
        return res.status(404).json({ error: 'Incident not found' });
      }

      const incident = incRes.rows[0];

      // 1. Must be accepted or en_route
      if (incident.status !== 'accepted' && incident.status !== 'en_route') {
        return res.status(403).json({
          error: 'Forbidden',
          message: 'Health card is accessible only after this hospital has officially accepted the case.',
        });
      }

      // 2. Must be the accepting hospital's staff
      if (incident.accepted_hospital_id !== req.user!.hospital_id) {
        return res.status(403).json({
          error: 'Forbidden',
          message: 'Access restricted: Health card is only accessible to staff of the accepted hospital.',
        });
      }

      // 3. Write access audit record
      try {
        await query(
          `INSERT INTO health_card_access_audit (incident_id, hospital_id, user_id, username, reason)
           VALUES ($1, $2, $3, $4, $5)`,
          [
            id,
            req.user!.hospital_id,
            req.user!.id,
            req.user!.username,
            reason.trim(),
          ]
        );
      } catch (auditErr) {
        console.warn('[HealthCard Audit Warning] Audit write deferred:', auditErr);
      }

      // 4. Retrieve ephemeral card from volatile Redis RAM
      const cardJson = await getEphemeralHealthCard(id);
      if (!cardJson) {
        return res.status(404).json({
          status: 'NOT_FOUND',
          message: 'No health data available. The patient has not linked ABHA or shared emergency information.',
          card: null,
        });
      }

      const card = JSON.parse(cardJson);
      return res.status(200).json({
        status: 'SUCCESS',
        incident_id: id,
        card,
        mode: getAbdmMode().toUpperCase(),
        accessed_by: req.user!.username,
        accessed_at: new Date().toISOString(),
      });
    } catch (err: unknown) {
      console.error('[POST /incidents/:id/health-card/break-glass Error]', err);
      return res.status(500).json({ error: 'Internal server error retrieving health card' });
    }
  }
);

// Helper function to execute race-safe accept
async function handleAcceptIncident(
  incidentId: string,
  hospitalId: string,
  res: Response
) {
  // 1. Check hospital exists
  const hospCheck = await query<Hospital>(
    `SELECT id, name, phone, address, has_trauma_center, has_icu_capacity,
            ST_Y(location::geometry) AS latitude, ST_X(location::geometry) AS longitude
     FROM hospitals WHERE id = $1;`,
    [hospitalId]
  );

  if (hospCheck.rowCount === 0) {
    return res.status(400).json({
      error: 'Invalid hospital',
      message: `Hospital '${hospitalId}' does not exist in registry.`,
    });
  }

  const hospital = {
    ...hospCheck.rows[0],
    latitude: Number(hospCheck.rows[0].latitude),
    longitude: Number(hospCheck.rows[0].longitude),
  };

  // 2. Atomic race-safe accept query:
  // Exactly ONE winner updates from 'broadcasting' or 'escalated' to 'accepted'
  const acceptSql = `
    UPDATE incidents
    SET 
      status = 'accepted',
      accepted_hospital_id = $1,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = $2 AND status IN ('broadcasting', 'escalated')
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

  const updateResult = await query<Incident>(acceptSql, [hospitalId, incidentId]);

  if (updateResult.rowCount === 0) {
    // Check if incident exists
    const checkInc = await query<{ id: string; status: string; accepted_hospital_id: string }>(
      `SELECT id, status, accepted_hospital_id FROM incidents WHERE id = $1;`,
      [incidentId]
    );

    if (checkInc.rowCount === 0) {
      return res.status(404).json({
        error: 'Not found',
        message: `Incident with ID '${incidentId}' does not exist.`,
      });
    }

    // Already accepted by another hospital or already resolved
    return res.status(409).json({
      error: 'Conflict',
      message: 'Emergency incident has already been accepted by another facility.',
      incident_id: incidentId,
      status: checkInc.rows[0].status,
      accepted_hospital_id: checkInc.rows[0].accepted_hospital_id,
    });
  }

  const acceptedIncident = {
    ...updateResult.rows[0],
    latitude: Number(updateResult.rows[0].latitude),
    longitude: Number(updateResult.rows[0].longitude),
  };

  // 3. Cancel auto-escalation timer immediately
  cancelAutoEscalation(incidentId);

  // 4. Retrieve matched hospital IDs to lock case across other facilities
  let otherHospitalIds: string[] = [];
  try {
    const cached = await redis.get(`incident_hospitals:${incidentId}`);
    if (cached) {
      otherHospitalIds = JSON.parse(cached);
    }
  } catch {
    // ignore
  }

  if (otherHospitalIds.length === 0) {
    try {
      const matchRes = await query<{ id: string }>(
        `SELECT h.id FROM hospitals h
         JOIN incidents i ON ST_DWithin(h.location, i.location, 20000)
         WHERE i.id = $1 AND h.has_trauma_center = true;`,
        [incidentId]
      );
      otherHospitalIds = matchRes.rows.map((r) => r.id);
    } catch {
      // ignore
    }
  }

  // 5. Emit 'case_locked' to other matched hospitals
  broadcastCaseLocked(incidentId, hospital.id, hospital.name, otherHospitalIds);

  // 6. Emit 'case_accepted' to Police Control Room and Mobile Client room
  broadcastCaseAccepted(incidentId, hospital);

  return res.json({
    message: `Emergency incident successfully accepted by '${hospital.name}'.`,
    incident: acceptedIncident,
    accepted_hospital: hospital,
  });
}

// POST /incidents/:id/accept - Hospital accepts the emergency case
incidentsRouter.post('/:id/accept', authenticateJWT, async (req: Request, res: Response) => {
  if (req.user?.role === 'police') {
    return res.status(403).json({
      error: 'Forbidden',
      message: 'Police role may view incidents but is not authorized to accept or reject hospital triage cases.',
    });
  }

  const paramsResult = incidentIdParamsSchema.safeParse(req.params);
  if (!paramsResult.success) {
    return res.status(400).json({
      error: 'Validation failed',
      message: 'Invalid incident ID format. Must be a valid UUID.',
    });
  }

  const hospitalId = req.body?.hospital_id;
  if (!hospitalId || typeof hospitalId !== 'string') {
    return res.status(400).json({
      error: 'Validation failed',
      message: "Field 'hospital_id' (valid UUID) is required to accept an incident.",
    });
  }

  if (req.user?.role === 'hospital_staff' && req.user.hospital_id !== hospitalId) {
    return res.status(403).json({
      error: 'Forbidden',
      message: `Hospital staff may only accept incidents on behalf of their assigned hospital (${req.user.hospital_id}).`,
    });
  }

  return handleAcceptIncident(paramsResult.data.id, hospitalId, res);
});

// POST /incidents/:id/reject - Hospital rejects the emergency case
incidentsRouter.post('/:id/reject', authenticateJWT, async (req: Request, res: Response) => {
  if (req.user?.role === 'police') {
    return res.status(403).json({
      error: 'Forbidden',
      message: 'Police role may view incidents but is not authorized to accept or reject hospital triage cases.',
    });
  }

  try {
    const paramsResult = incidentIdParamsSchema.safeParse(req.params);
    if (!paramsResult.success) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Invalid incident ID format. Must be a valid UUID.',
      });
    }

    const bodyResult = rejectIncidentSchema.safeParse(req.body);
    if (!bodyResult.success) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Invalid rejection payload',
        details: bodyResult.error.errors.map((e) => ({
          field: e.path.join('.'),
          message: e.message,
        })),
      });
    }

    const { id } = paramsResult.data;
    const { hospital_id, reason } = bodyResult.data;

    if (req.user?.role === 'hospital_staff' && req.user.hospital_id !== hospital_id) {
      return res.status(403).json({
        error: 'Forbidden',
        message: `Hospital staff may only reject incidents on behalf of their assigned hospital (${req.user.hospital_id}).`,
      });
    }

    // Check incident exists and check status
    const incCheck = await query<{ id: string; status: string }>(
      `SELECT id, status FROM incidents WHERE id = $1;`,
      [id]
    );

    if (incCheck.rowCount === 0) {
      return res.status(404).json({
        error: 'Not found',
        message: `Incident with ID '${id}' does not exist.`,
      });
    }

    if (incCheck.rows[0].status === 'accepted') {
      return res.status(409).json({
        error: 'Conflict',
        message: 'Cannot reject an emergency that has already been accepted.',
      });
    }

    // Insert rejection into incident_rejections (ZERO photo/image data stored)
    await query(
      `INSERT INTO incident_rejections (incident_id, hospital_id, reason)
       VALUES ($1, $2, $3)
       ON CONFLICT (incident_id, hospital_id)
       DO UPDATE SET reason = EXCLUDED.reason, created_at = CURRENT_TIMESTAMP;`,
      [id, hospital_id, reason]
    );

    console.log(
      `[Triage Engine] Hospital ${hospital_id} rejected incident ${id} (Reason: ${reason})`
    );

    // Query hospital name and broadcast rejection notice to Police Control Room
    const hospRes = await query<{ name: string }>(
      'SELECT name FROM hospitals WHERE id = $1;',
      [hospital_id]
    );
    const hospitalName = hospRes.rows[0]?.name || 'Trauma Center';
    broadcastHospitalRejected(id, hospital_id, hospitalName, reason);

    // Check if ALL currently matched hospitals have rejected
    let matchedHospitals: string[] = [];
    try {
      const cached = await redis.get(`incident_hospitals:${id}`);
      if (cached) {
        matchedHospitals = JSON.parse(cached);
      }
    } catch {
      // ignore
    }

    if (matchedHospitals.length === 0) {
      const matchDb = await query<{ id: string }>(
        `SELECT h.id FROM hospitals h JOIN incidents i ON ST_DWithin(h.location, i.location, 8000) WHERE i.id = $1 AND h.has_trauma_center = true;`,
        [id]
      );
      matchedHospitals = matchDb.rows.map((r) => r.id);
    }

    const rejectionsRes = await query<{ hospital_id: string }>(
      `SELECT hospital_id FROM incident_rejections WHERE incident_id = $1;`,
      [id]
    );
    const rejectedSet = new Set(rejectionsRes.rows.map((r) => r.hospital_id));

    const allRejected =
      matchedHospitals.length > 0 &&
      matchedHospitals.every((hId) => rejectedSet.has(hId));

    if (allRejected) {
      console.log(
        `[Auto-Escalation] All ${matchedHospitals.length} matched hospitals have rejected incident ${id}. Triggering immediate escalation!`
      );
      triggerImmediateEscalation(id).catch((err) => {
        console.error('[Auto-Escalation Error]', err);
      });
    }

    return res.json({
      message: 'Rejection recorded successfully.',
      incident_id: id,
      hospital_id,
      reason,
      all_matched_rejected: allRejected,
    });
  } catch (error) {
    console.error('[POST /incidents/:id/reject Error]', error);
    return res.status(500).json({
      error: 'Rejection failed',
      message:
        error instanceof Error
          ? error.message
          : 'Unexpected database error while recording rejection.',
    });
  }
});

// PATCH /incidents/:id/status - Update status (and accepted_hospital_id if status=accepted)
incidentsRouter.patch('/:id/status', authenticateJWT, async (req: Request, res: Response) => {
  if (req.user?.role === 'police') {
    return res.status(403).json({
      error: 'Forbidden',
      message: 'Police role may view incidents but is not authorized to accept or reject hospital triage cases.',
    });
  }

  const paramsResult = incidentIdParamsSchema.safeParse(req.params);
  if (!paramsResult.success) {
    return res.status(400).json({
      error: 'Validation failed',
      message: 'Invalid incident ID format. Must be a valid UUID.',
    });
  }

  const bodyResult = updateIncidentStatusSchema.safeParse(req.body);
  if (!bodyResult.success) {
    return res.status(400).json({
      error: 'Validation failed',
      message: 'Invalid status update payload',
      details: bodyResult.error.errors.map((e) => ({
        field: e.path.join('.'),
        message: e.message,
      })),
    });
  }

  const { id } = paramsResult.data;
  const { status, accepted_hospital_id } = bodyResult.data;

  // RBAC: hospital_staff may ONLY accept on behalf of their own assigned hospital
  if (req.user?.role === 'hospital_staff') {
    if (status === 'accepted') {
      if (!accepted_hospital_id || accepted_hospital_id !== req.user.hospital_id) {
        return res.status(403).json({
          error: 'Forbidden',
          message: `Hospital staff may only accept incidents on behalf of their assigned hospital (${req.user.hospital_id}).`,
        });
      }
    }
  }

  // If status is 'accepted', route through race-safe handleAcceptIncident
  if (status === 'accepted' && accepted_hospital_id) {
    return handleAcceptIncident(id, accepted_hospital_id, res);
  }

  const client = await getClient();

  try {
    await client.query('BEGIN');

    // 1. Verify incident exists
    const checkIncidentSql = `
      SELECT id, status, accepted_hospital_id 
      FROM incidents 
      WHERE id = $1 
      FOR UPDATE;
    `;
    const checkResult = await client.query(checkIncidentSql, [id]);

    if (checkResult.rowCount === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({
        error: 'Not found',
        message: `Incident with ID '${id}' does not exist.`,
      });
    }

    // 2. Perform update for non-accepted status changes
    const updateSql = `
      UPDATE incidents
      SET 
        status = $1,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = $2
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

    const updateResult = await client.query<Incident>(updateSql, [
      status,
      id,
    ]);

    await client.query('COMMIT');

    return res.json({
      message: `Incident status successfully updated to '${status}'.`,
      incident: updateResult.rows[0],
    });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('[PATCH /incidents/:id/status Error]', error);
    return res.status(500).json({
      error: 'Status update failed',
      message:
        error instanceof Error
          ? error.message
          : 'Database transaction failed during status update.',
    });
  } finally {
    client.release();
  }
});

