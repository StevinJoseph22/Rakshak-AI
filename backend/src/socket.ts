import { Server as SocketIOServer, Socket } from 'socket.io';
import { Server as HttpServer } from 'http';
import { Hospital } from './types';
import { redis, registerPurgeVerification } from './redis';
import { query } from './db';

let io: SocketIOServer | null = null;

export interface IncidentBroadcastPayload {
  id: string;
  latitude: number;
  longitude: number;
  distance_km: number | null;
  road_distance_km?: number | null;
  created_at: string | Date;
  imageUrl: string | null;
  hospital_id?: string;
  hospital_name?: string;
  matched_hospitals_count?: number;
  matched_hospitals?: Hospital[];
  victim_metadata?: Record<string, unknown> | null;
  status?: string;
  escalated?: boolean;
  accepted_hospital_id?: string | null;
  accepted_hospital_name?: string;
}

export function initSocketIO(httpServer: HttpServer): SocketIOServer {
  io = new SocketIOServer(httpServer, {
    cors: {
      origin: '*', // Allow connections from Vite dashboard (5173), mobile, etc.
      methods: ['GET', 'POST', 'PATCH'],
      credentials: true,
    },
  });

  io.on('connection', (socket: Socket) => {
    console.log(`[Socket.io] Client connected: ${socket.id}`);

    // Hospital ER view joins its dedicated room
    socket.on('join_hospital', (hospitalId: string) => {
      if (hospitalId) {
        // Leave any previously joined rooms (including all_incidents and other hospitals)
        for (const room of socket.rooms) {
          if (room !== socket.id) {
            socket.leave(room);
            console.log(`[Socket.io] Socket ${socket.id} left room: ${room}`);
          }
        }
        socket.join(hospitalId);
        console.log(`[Socket.io] Socket ${socket.id} joined hospital room: ${hospitalId}`);
        socket.emit('joined_hospital', { hospitalId, status: 'ok' });
      }
    });

    // Police Control Room joins the city-wide all_incidents room
    socket.on('join_police', () => {
      // Leave any hospital rooms so police only listens to all_incidents
      for (const room of socket.rooms) {
        if (room !== socket.id && room !== 'all_incidents') {
          socket.leave(room);
          console.log(`[Socket.io] Socket ${socket.id} left room: ${room}`);
        }
      }
      socket.join('all_incidents');
      console.log(`[Socket.io] Socket ${socket.id} joined police all_incidents room`);
      socket.emit('joined_police', { room: 'all_incidents', status: 'ok' });
    });

    // Phase 7: Mobile client joins its per-incident status room
    socket.on('join_incident', (incidentId: string) => {
      if (incidentId) {
        socket.join(`incident:${incidentId}`);
        console.log(`[Socket.io] Socket ${socket.id} joined room: incident:${incidentId}`);
        socket.emit('joined_incident', { incidentId, status: 'ok' });
      }
    });

    // Phase 6: Zero-Storage Ephemeral Photo Stream Handler
    socket.on(
      'incident_image',
      async (
        data: { incident_id?: string; image?: unknown },
        ack?: (response: { status: string; incident_id?: string; message?: string }) => void
      ) => {
        try {
          const incidentId = data?.incident_id;
          const imagePayload = data?.image;

          if (!incidentId || !imagePayload) {
            console.warn('[Socket.io] Invalid incident_image payload received:', {
              incidentId,
              hasImage: !!imagePayload,
            });
            if (typeof ack === 'function') {
              ack({ status: 'error', message: 'Missing incident_id or image payload' });
            }
            return;
          }

          console.log(`[Socket.io] Received incident_image for incident: ${incidentId}`);

          // Convert incoming binary (Buffer, Uint8Array, base64 string, or byte array) to base64 Data URL
          let base64Data: string;
          if (Buffer.isBuffer(imagePayload)) {
            base64Data = imagePayload.toString('base64');
          } else if (imagePayload instanceof Uint8Array) {
            base64Data = Buffer.from(imagePayload).toString('base64');
          } else if (typeof imagePayload === 'string') {
            base64Data = imagePayload.replace(/^data:image\/\w+;base64,/, '');
          } else if (
            typeof imagePayload === 'object' &&
            imagePayload !== null &&
            'data' in imagePayload &&
            Array.isArray((imagePayload as { data: number[] }).data)
          ) {
            base64Data = Buffer.from((imagePayload as { data: number[] }).data).toString('base64');
          } else if (imagePayload instanceof ArrayBuffer) {
            base64Data = Buffer.from(imagePayload).toString('base64');
          } else {
            base64Data = Buffer.from(String(imagePayload)).toString('base64');
          }

          const dataUrl = `data:image/jpeg;base64,${base64Data}`;

          // Verify if incident exists in DB; if stale/unknown, auto-heal to the most recent incident in last 5 minutes
          let effectiveIncidentId = incidentId;
          try {
            const checkRes = await query('SELECT id FROM incidents WHERE id = $1;', [incidentId]);
            if (checkRes.rowCount === 0) {
              const recentRes = await query<{ id: string }>(
                `SELECT id FROM incidents WHERE created_at > NOW() - INTERVAL '5 minutes' ORDER BY created_at DESC LIMIT 1;`
              );
              if (recentRes.rowCount && recentRes.rowCount > 0) {
                console.warn(
                  `[Socket.io] Stale incident ID '${incidentId}' auto-healed to active incident '${recentRes.rows[0].id}'`
                );
                effectiveIncidentId = recentRes.rows[0].id;
              }
            }
          } catch (healErr) {
            console.warn('[Socket.io] Error during incident ID validation/healing:', healErr);
          }

          // 1. Strict Zero-Storage Guarantee: Store exclusively in volatile Redis RAM with 15-minute TTL (900 seconds)
          // ZERO persistent file writes occur.
          const redisKey = `incident_image:${effectiveIncidentId}`;
          await redis.setex(redisKey, 900, dataUrl);
          if (effectiveIncidentId !== incidentId) {
            await redis.setex(`incident_image:${incidentId}`, 900, dataUrl);
          }
          console.log(`[Zero-Storage Engine] Stored photo stream in Redis RAM (TTL 900s): ${redisKey}`);

          // 2. Register background purge-confirmation verification job
          registerPurgeVerification(effectiveIncidentId, 900);

          // 3. Resolve matched hospital IDs to strictly enforce Phase 5 room isolation
          let hospitalIds: string[] = [];
          try {
            const cachedHospitals = await redis.get(`incident_hospitals:${effectiveIncidentId}`);
            if (cachedHospitals) {
              hospitalIds = JSON.parse(cachedHospitals);
            }
          } catch {
            // Non-fatal cache read error
          }

          if (hospitalIds.length === 0) {
            // Fallback: Query PostGIS directly for hospitals within 8km of incident
            try {
              const matchRes = await query<{ id: string }>(
                `SELECT h.id FROM hospitals h
                 JOIN incidents i ON ST_DWithin(h.location, i.location, 8000)
                 WHERE i.id = $1 AND h.has_trauma_center = true`,
                [effectiveIncidentId]
              );
              hospitalIds = matchRes.rows.map((r) => r.id);
            } catch (dbErr) {
              console.error('[Socket.io] Error querying matched hospitals for image_update:', dbErr);
            }
          }

          const updatePayload = {
            incident_id: effectiveIncidentId,
            imageUrl: dataUrl,
          };

          // 4. Emit image_update ONLY to matched hospital rooms (unmatched hospitals receive nothing)
          hospitalIds.forEach((hospitalId) => {
            io!.to(hospitalId).emit('image_update', updatePayload);
            if (effectiveIncidentId !== incidentId) {
              io!.to(hospitalId).emit('image_update', { incident_id: incidentId, imageUrl: dataUrl });
            }
            console.log(`[Socket.io] Emitted image_update to hospital room: ${hospitalId}`);
          });

          // 5. Emit image_update to city-wide police room
          io!.to('all_incidents').emit('image_update', updatePayload);
          if (effectiveIncidentId !== incidentId) {
            io!.to('all_incidents').emit('image_update', { incident_id: incidentId, imageUrl: dataUrl });
          }
          console.log(`[Socket.io] Emitted image_update to all_incidents room (Police Control Room)`);

          if (typeof ack === 'function') {
            ack({ status: 'ok', incident_id: effectiveIncidentId });
          }
        } catch (err) {
          console.error('[Socket.io] Error handling incident_image:', err);
          if (typeof ack === 'function') {
            ack({ status: 'error', message: err instanceof Error ? err.message : 'Unknown error' });
          }
        }
      }
    );

    socket.on('disconnect', (reason) => {
      console.log(`[Socket.io] Client disconnected: ${socket.id} (${reason})`);
    });
  });

  return io;
}

export function getIO(): SocketIOServer {
  if (!io) {
    throw new Error('Socket.io has not been initialized yet.');
  }
  return io;
}

export async function broadcastNewIncident(
  incident: {
    id: string;
    latitude: number;
    longitude: number;
    created_at: string | Date;
    victim_metadata?: Record<string, unknown> | null;
    status?: string;
  },
  matchedHospitals: Hospital[],
  isEscalated: boolean = false
): Promise<void> {
  if (!io) {
    console.warn('[Socket.io] Skipping broadcast: Socket.io not initialized.');
    return;
  }

  // Retrieve cached in-memory image from Redis RAM if already uploaded
  let activeImageUrl: string | null = null;
  try {
    activeImageUrl = await redis.get(`incident_image:${incident.id}`);
  } catch {
    // Non-fatal cache read error
  }

  // 1. Emit to each matched hospital's room
  matchedHospitals.forEach((hospital) => {
    const payload: IncidentBroadcastPayload = {
      id: incident.id,
      latitude: incident.latitude,
      longitude: incident.longitude,
      distance_km: hospital.distance_km ?? null,
      road_distance_km:
        hospital.road_distance_km ??
        (hospital.distance_km ? Math.round(hospital.distance_km * 1.6 * 10) / 10 : null),
      created_at: incident.created_at,
      imageUrl: activeImageUrl,
      hospital_id: hospital.id,
      hospital_name: hospital.name,
      matched_hospitals_count: matchedHospitals.length,
      matched_hospitals: matchedHospitals,
      victim_metadata: incident.victim_metadata,
      status: incident.status || (isEscalated ? 'escalated' : 'broadcasting'),
      escalated: isEscalated,
    };
    io!.to(hospital.id).emit('new_incident', payload);
    console.log(
      `[Socket.io] Emitted new_incident to hospital room: ${hospital.id} (${hospital.name}) [escalated=${isEscalated}, hasImage=${!!activeImageUrl}]`
    );
  });

  // 2. Emit city-wide to the "all_incidents" room (Police Control Room)
  const policePayload: IncidentBroadcastPayload = {
    id: incident.id,
    latitude: incident.latitude,
    longitude: incident.longitude,
    distance_km: matchedHospitals.length > 0 ? (matchedHospitals[0].distance_km ?? null) : null,
    road_distance_km:
      matchedHospitals.length > 0
        ? matchedHospitals[0].road_distance_km ??
          (matchedHospitals[0].distance_km
            ? Math.round(matchedHospitals[0].distance_km * 1.6 * 10) / 10
            : null)
        : null,
    created_at: incident.created_at,
    imageUrl: activeImageUrl,
    matched_hospitals_count: matchedHospitals.length,
    matched_hospitals: matchedHospitals,
    victim_metadata: incident.victim_metadata,
    status: incident.status || (isEscalated ? 'escalated' : 'broadcasting'),
    escalated: isEscalated,
  };
  io.to('all_incidents').emit('new_incident', policePayload);
  console.log(
    `[Socket.io] Emitted new_incident to all_incidents room (Police Control Room) [hasImage=${!!activeImageUrl}]`
  );
}

/**
 * Phase 7: Case Locked - Emitted to all other matched hospital rooms
 * when a case has been accepted by a winning facility.
 */
export function broadcastCaseLocked(
  incidentId: string,
  acceptedHospitalId: string,
  acceptedHospitalName: string,
  otherHospitalIds: string[]
): void {
  if (!io) return;
  const payload = {
    incident_id: incidentId,
    accepted_hospital_id: acceptedHospitalId,
    accepted_hospital_name: acceptedHospitalName,
    message: 'Emergency incident accepted by another trauma center.',
  };

  otherHospitalIds.forEach((hId) => {
    if (hId !== acceptedHospitalId) {
      io!.to(hId).emit('case_locked', payload);
      console.log(`[Socket.io] Emitted case_locked to hospital room: ${hId}`);
    }
  });
}

/**
 * Phase 7: Case Accepted - Emitted to Police Control Room and Mobile Client room.
 */
export function broadcastCaseAccepted(
  incidentId: string,
  hospital: {
    id: string;
    name: string;
    phone: string;
    address: string;
    latitude: number;
    longitude: number;
  }
): void {
  if (!io) return;
  const payload = {
    incident_id: incidentId,
    status: 'accepted',
    hospital,
  };

  // Emit to Police Control Room
  io.to('all_incidents').emit('case_accepted', payload);
  console.log(`[Socket.io] Emitted case_accepted to all_incidents room`);

  // Emit to Mobile device room for this incident
  io.to(`incident:${incidentId}`).emit('case_accepted', payload);
  console.log(`[Socket.io] Emitted case_accepted to incident:${incidentId} room`);
}

/**
 * Hospital Rejected - Emitted to Police Control Room and incident room so police know which facility rejected and why.
 */
export function broadcastHospitalRejected(
  incidentId: string,
  hospitalId: string,
  hospitalName: string,
  reason: string,
  createdAt: string = new Date().toISOString()
): void {
  if (!io) return;
  const payload = {
    incident_id: incidentId,
    hospital_id: hospitalId,
    hospital_name: hospitalName,
    reason,
    created_at: createdAt,
  };

  io.to('all_incidents').emit('hospital_rejected', payload);
  io.to(`incident:${incidentId}`).emit('hospital_rejected', payload);
  console.log(
    `[Socket.io] Emitted hospital_rejected to all_incidents room for incident ${incidentId} by ${hospitalName} (${reason})`
  );
}

/**
 * Phase 7: Incident Escalated - Emitted to new hospitals, Police, and Mobile Client.
 */
export function broadcastIncidentEscalated(
  incident: {
    id: string;
    latitude: number;
    longitude: number;
    created_at: string | Date;
    victim_metadata?: Record<string, unknown> | null;
  },
  newlyMatchedHospitals: Hospital[],
  searchRadius: string
): void {
  if (!io) return;

  // 1. Broadcast new_incident to newly reached trauma centers (checks Redis RAM for existing photo)
  broadcastNewIncident(incident, newlyMatchedHospitals, true).then(() => {
    // 2. Also emit image_update explicitly if photo is cached in Redis
    redis.get(`incident_image:${incident.id}`).then((cachedImage) => {
      if (cachedImage && io) {
        newlyMatchedHospitals.forEach((h) => {
          io!.to(h.id).emit('image_update', {
            incident_id: incident.id,
            imageUrl: cachedImage,
          });
        });
        io.to('all_incidents').emit('image_update', {
          incident_id: incident.id,
          imageUrl: cachedImage,
        });
      }
    }).catch(() => {
      // Non-fatal
    });
  }).catch((err) => {
    console.error('[Socket.io] Error in broadcastNewIncident during escalation:', err);
  });

  // 3. Broadcast incident_escalated to Police and Mobile
  const payload = {
    incident_id: incident.id,
    status: 'escalated',
    search_radius: searchRadius,
    matched_hospitals_count: newlyMatchedHospitals.length,
    newly_matched_hospitals: newlyMatchedHospitals,
  };

  io.to('all_incidents').emit('incident_escalated', payload);
  io.to(`incident:${incident.id}`).emit('incident_escalated', payload);
  console.log(
    `[Socket.io] Emitted incident_escalated for ${incident.id} (radius: ${searchRadius})`
  );
}

/**
 * Phase 7: Incident Unmatched - Emitted when no facility in network matches.
 */
export function broadcastIncidentUnmatched(incidentId: string): void {
  if (!io) return;
  const payload = {
    incident_id: incidentId,
    status: 'unmatched',
    message: 'No trauma facilities available in coverage network.',
  };

  io.to('all_incidents').emit('incident_unmatched', payload);
  io.to(`incident:${incidentId}`).emit('incident_unmatched', payload);
  console.log(`[Socket.io] Emitted incident_unmatched for incident ${incidentId}`);
}

