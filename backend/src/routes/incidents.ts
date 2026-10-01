import { Router, Request, Response } from 'express';
import { query, getClient } from '../db';
import {
  createIncidentSchema,
  incidentIdParamsSchema,
  updateIncidentStatusSchema,
  rejectIncidentSchema,
  nearbyIncidentsQuerySchema,
  claimIncidentSchema,
} from '../validations';
import { Incident, Hospital } from '../types';
import {
  broadcastNewIncident,
  broadcastCaseLocked,
  broadcastCaseAccepted,
  broadcastHospitalRejected,
  broadcastIncidentClaimed,
  getIO,
} from '../socket';
import { redis } from '../redis';
import {
  scheduleAutoEscalation,
  cancelAutoEscalation,
  clearAllEscalations,
  triggerImmediateEscalation,
} from '../escalation';

export const incidentsRouter = Router();

// POST /incidents - Create incident & match trauma hospitals within 8km
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

    const { latitude, longitude, victim_metadata } = parseResult.data;

    // 1. Insert incident into PostgreSQL + PostGIS with 'broadcasting' status
    const insertSql = `
      INSERT INTO incidents (
        location,
        status,
        victim_metadata
      )
      VALUES (
        ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
        'broadcasting',
        $3
      )
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

    const insertResult = await query<Incident>(insertSql, [
      longitude,
      latitude,
      victim_metadata ? JSON.stringify(victim_metadata) : null,
    ]);

    const rawIncident = insertResult.rows[0];
    const incident = {
      ...rawIncident,
      latitude: Number(rawIncident.latitude),
      longitude: Number(rawIncident.longitude),
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
incidentsRouter.get('/', async (req: Request, res: Response) => {
  try {
    const limit = Math.min(Math.max(parseInt(req.query.limit as string) || 20, 1), 100);
    const hospitalId = typeof req.query.hospital_id === 'string' ? req.query.hospital_id : undefined;

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

    return res.json({
      incidents,
      total: incidents.length,
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

// DELETE /incidents - Purge test incidents from database and broadcast feed_cleared to dashboard
incidentsRouter.delete('/', async (req: Request, res: Response) => {
  try {
    await query('DELETE FROM incident_rejections;');
    await query('DELETE FROM incidents;');
    clearAllEscalations();
    try {
      const io = getIO();
      io.emit('feed_cleared');
    } catch {
      // Socket.io might not be initialized
    }
    // Clean up volatile Redis RAM keys so future feeds start 100% clean
    try {
      const keys = await redis.keys('incident_*');
      if (keys.length > 0) {
        await redis.del(...keys);
      }
    } catch (redisErr) {
      console.warn('[Redis] Failed to clear keys on DELETE /incidents:', redisErr);
    }
    return res.json({
      message: 'All test incidents purged successfully from database.',
      cleared: true,
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
incidentsRouter.post('/:id/claim', async (req: Request, res: Response) => {
  try {
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
    const { ambulance_id } = bodyResult.data;

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

    const updateRes = await query<Incident>(
      `UPDATE incidents
       SET ambulance_id = $1, updated_at = CURRENT_TIMESTAMP
       WHERE id = $2 AND (ambulance_id IS NULL OR ambulance_id = $1)
       RETURNING 
         id, status, accepted_hospital_id, ambulance_id, victim_metadata,
         ST_Y(location::geometry) AS latitude,
         ST_X(location::geometry) AS longitude,
         created_at, updated_at;`,
      [ambulance_id, id]
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

    broadcastIncidentClaimed(id, ambulance_id);

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
    } catch (_) {}

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
      } catch (_) {}

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
incidentsRouter.post('/:id/accept', async (req: Request, res: Response) => {
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

  return handleAcceptIncident(paramsResult.data.id, hospitalId, res);
});

// POST /incidents/:id/reject - Hospital rejects the emergency case
incidentsRouter.post('/:id/reject', async (req: Request, res: Response) => {
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
incidentsRouter.patch('/:id/status', async (req: Request, res: Response) => {
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

