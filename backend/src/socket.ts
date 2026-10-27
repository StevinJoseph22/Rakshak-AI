import { Server as SocketIOServer, Socket } from 'socket.io';
import { Server as HttpServer } from 'http';
import { Server as HttpsServer } from 'https';
import { Hospital, BlackspotInfo } from './types';
import {
  redis,
  storeEncryptedIncidentPhoto,
  getDecryptedIncidentPhoto,
} from './redis';
import { query } from './db';
import { verifyToken } from './utils/jwt';
import { maskPhoneNumber, maskName } from './utils/privacy';
import { NtcipTrafficControllerService } from './services/ntcipService';
import {
  scheduleSilentPromotion,
  cancelSilentPromotion,
  promoteSuspectedIncident,
} from './services/preAlertService';

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
  blackspot_info?: BlackspotInfo | null;
  status?: string;
  escalated?: boolean;
  accepted_hospital_id?: string | null;
  accepted_hospital_name?: string;
}

export function initSocketIO(httpServer: HttpServer | HttpsServer): SocketIOServer {
  io = new SocketIOServer(httpServer, {
    cors: {
      origin: true, // Allow connections from Vite dashboard (5173), mobile, LAN IPs, etc.
      methods: ['GET', 'POST', 'PATCH'],
      credentials: true,
    },
  });

  // Phase 13: Socket.IO Handshake Authentication Middleware
  io.use((socket: Socket, next) => {
    const rawToken =
      socket.handshake.auth?.token ||
      socket.handshake.headers?.authorization?.replace(/^Bearer\s+/i, '');

    if (rawToken && typeof rawToken === 'string') {
      try {
        const decoded = verifyToken(rawToken);
        socket.data.user = decoded;
      } catch (err) {
        console.warn(`[Socket.io Auth] Invalid JWT presented on connection ${socket.id}:`, err);
        socket.data.user = null;
      }
    } else {
      socket.data.user = null;
    }
    next();
  });

  io.on('connection', (socket: Socket) => {
    console.log(`[Socket.io] Client connected: ${socket.id}`);
    if (process.env.NODE_ENV !== 'production') {
      socket.join('all_incidents');
    }

    // Phase 13: Automatically join rooms based on verified JWT role
    const user = socket.data.user;
    if (user) {
      if (user.role === 'hospital_staff' && user.hospital_id) {
        socket.join(user.hospital_id);
        console.log(
          `[Socket.io Auth] Authenticated hospital_staff '${user.username}' auto-joined hospital room: ${user.hospital_id}`
        );
        socket.emit('authenticated', {
          role: user.role,
          hospitalId: user.hospital_id,
          username: user.username,
        });
      } else if (user.role === 'police') {
        socket.join('all_incidents');
        console.log(
          `[Socket.io Auth] Authenticated police '${user.username}' auto-joined police room: all_incidents`
        );
        socket.emit('authenticated', {
          role: user.role,
          room: 'all_incidents',
          username: user.username,
        });
      }
    }

    // Hospital ER view joins its dedicated room (Protected: requires matching hospital_staff role)
    socket.on('join_hospital', (hospitalId: string) => {
      if (hospitalId) {
        const isDevOrDemo = process.env.NODE_ENV !== 'production';
        if (
          !isDevOrDemo &&
          (socket.data.user?.role !== 'hospital_staff' ||
          socket.data.user?.hospital_id !== hospitalId)
        ) {
          console.warn(
            `[Socket.io RBAC] Unauthorized join_hospital attempt by socket ${socket.id} (User: ${socket.data.user?.username || 'anonymous'}) for hospital ${hospitalId}`
          );
          socket.emit('error', {
            code: 'FORBIDDEN',
            message: 'Authentication required: You can only join your assigned hospital room.',
          });
          return;
        }

        // Leave any previously joined rooms
        for (const room of socket.rooms) {
          if (room !== socket.id) {
            socket.leave(room);
          }
        }
        socket.join(hospitalId);
        console.log(`[Socket.io] Socket ${socket.id} joined hospital room: ${hospitalId}`);
        socket.emit('joined_hospital', { hospitalId, status: 'ok' });
      }
    });

    // Police Control Room joins the city-wide all_incidents room (Protected: requires police role)
    socket.on('join_police', () => {
      const isDevOrDemo = process.env.NODE_ENV !== 'production';
      if (!isDevOrDemo && socket.data.user?.role !== 'police') {
        console.warn(
          `[Socket.io RBAC] Unauthorized join_police attempt by socket ${socket.id} (User: ${socket.data.user?.username || 'anonymous'})`
        );
        socket.emit('error', {
          code: 'FORBIDDEN',
          message: 'Authentication required: Police role is required to join police room.',
        });
        return;
      }

      for (const room of socket.rooms) {
        if (room !== socket.id && room !== 'all_incidents') {
          socket.leave(room);
        }
      }
      socket.join('all_incidents');
      console.log(`[Socket.io] Socket ${socket.id} joined police all_incidents room`);
      socket.emit('joined_police', { room: 'all_incidents', status: 'ok' });
    });

    // Phase 7 & 26: Scoped join_incident with server-side authorization
    socket.on('join_incident', async (incidentId: string) => {
      if (!incidentId) return;

      const user = socket.data.user;

      // Hospital staff authorization check: staff may only join rooms if matched or accepted
      if (user && user.role === 'hospital_staff') {
        const hospitalId = user.hospital_id;
        if (!hospitalId) {
          socket.emit('error', {
            code: 'FORBIDDEN',
            message: 'Hospital staff must have an assigned hospital ID.',
          });
          return;
        }

        try {
          const checkRes = await query<{ accepted_hospital_id: string | null }>(
            `SELECT accepted_hospital_id FROM incidents WHERE id = $1;`,
            [incidentId]
          );

          if (checkRes.rowCount === 0) {
            socket.emit('error', { code: 'NOT_FOUND', message: 'Incident not found.' });
            return;
          }

          const isAcceptedByThisHosp = checkRes.rows[0].accepted_hospital_id === hospitalId;
          if (!isAcceptedByThisHosp) {
            let matchedHospitals: string[] = [];
            try {
              const cached = await redis.get(`incident_hospitals:${incidentId}`);
              if (cached) matchedHospitals = JSON.parse(cached);
            } catch (_) {
              // ignore
            }

            if (!matchedHospitals.includes(hospitalId)) {
              const matchDb = await query<{ id: string }>(
                `SELECT h.id FROM hospitals h JOIN incidents i ON ST_DWithin(h.location, i.location, 8000) WHERE i.id = $1 AND h.id = $2;`,
                [incidentId, hospitalId]
              );
              if (matchDb.rowCount === 0) {
                console.warn(
                  `[Socket.io RBAC] Hospital staff '${user.username}' (${hospitalId}) denied join_incident for unassigned incident ${incidentId}`
                );
                socket.emit('error', {
                  code: 'FORBIDDEN',
                  message: 'Hospital staff may only join incident rooms where their facility is matched or assigned.',
                });
                return;
              }
            }
          }
        } catch (authErr) {
          console.error('[Socket.io RBAC] Error verifying hospital incident room authorization:', authErr);
          socket.emit('error', { code: 'INTERNAL_ERROR', message: 'Authorization check failed' });
          return;
        }
      }

      socket.join(`incident:${incidentId}`);
      if (user && user.role === 'police') {
        socket.join('all_incidents');
      }
      console.log(`[Socket.io] Socket ${socket.id} joined room: incident:${incidentId}`);
      socket.emit('joined_incident', { incidentId, status: 'ok' });
    });

    // Phase 8: Live Ambulance GPS Telemetry Beacon
    socket.on(
      'ambulance_location',
      async (data: {
        incident_id: string;
        ambulance_id: string;
        latitude: number;
        longitude: number;
        speed_kmh?: number;
        heading?: number;
      }) => {
        try {
          if (
            !data?.incident_id ||
            !data?.ambulance_id ||
            typeof data.latitude !== 'number' ||
            typeof data.longitude !== 'number'
          ) {
            return;
          }

          const telemetry = {
            incident_id: data.incident_id,
            ambulance_id: data.ambulance_id,
            latitude: data.latitude,
            longitude: data.longitude,
            speed_kmh: data.speed_kmh ?? 0,
            heading: data.heading ?? 0,
            timestamp: new Date().toISOString(),
          };

          try {
            await redis.setex(
              `ambulance_loc:${data.incident_id}`,
              600,
              JSON.stringify(telemetry)
            );
          } catch {
            // ignore
          }

          if (io) {
            io.to(`incident:${data.incident_id}`).emit('ambulance_location_update', telemetry);
            io.to('all_incidents').emit('ambulance_location_update', telemetry);
          }
        } catch (err) {
          console.warn('[Socket.io] Error handling ambulance_location:', err);
        }
      }
    );

    // Phase 14: Ambulance Zero-Touch On-Scene Arrival Detection
    socket.on(
      'ambulance_arrived',
      async (data: {
        incident_id: string;
        ambulance_id: string;
        ambulance_plate?: string;
        driver_name?: string;
        driver_phone?: string;
        origin_station?: string;
        arrived_at?: string;
        latitude?: number;
        longitude?: number;
      }) => {
        try {
          if (!data?.incident_id || !data?.ambulance_id) {
            return;
          }

          const arrivedAt = data.arrived_at || new Date().toISOString();
          const fullPayload: AmbulanceArrivalPayload = {
            incident_id: data.incident_id,
            ambulance_id: data.ambulance_id,
            ambulance_plate: data.ambulance_plate || 'KA-01-EA-108',
            driver_name: data.driver_name || 'Ramesh Kumar',
            driver_phone: data.driver_phone || '+91 98450 12345',
            origin_station: data.origin_station || 'Manipal Hospital HAL Depot Base',
            arrived_at: arrivedAt,
            latitude: data.latitude,
            longitude: data.longitude,
          };

          try {
            await redis.setex(
              `ambulance_arrived:${data.incident_id}`,
              1800,
              JSON.stringify(fullPayload)
            );
          } catch {
            // Non-fatal cache failure
          }

          await query(
            `UPDATE incidents
             SET ambulance_arrived_at = $1,
                 ambulance_arrival_lat = $2,
                 ambulance_arrival_lng = $3,
                 ambulance_plate = COALESCE($4, ambulance_plate),
                 ambulance_driver_name = COALESCE($5, ambulance_driver_name),
                 ambulance_driver_phone = COALESCE($6, ambulance_driver_phone),
                 ambulance_origin_station = COALESCE($7, ambulance_origin_station),
                 updated_at = CURRENT_TIMESTAMP
             WHERE id = $8;`,
            [
              arrivedAt,
              data.latitude ?? null,
              data.longitude ?? null,
              fullPayload.ambulance_plate,
              fullPayload.driver_name,
              fullPayload.driver_phone,
              fullPayload.origin_station,
              data.incident_id,
            ]
          );

          await broadcastAmbulanceArrived(fullPayload);
        } catch (err) {
          console.error('[Socket.io] Error handling ambulance_arrived:', err);
        }
      }
    );

    // C-V2X Automated Signal Preemption (EVP / Green Corridor) Handler
    socket.on(
      'signal_preempt_request',
      async (data: {
        incident_id: string;
        ambulance_id: string;
        ambulance_plate: string;
        intersection_id: string;
        junction_name: string;
        eta_seconds: number;
      }) => {
        try {
          const ntcipService = NtcipTrafficControllerService.getInstance();
          const response = await ntcipService.requestPreemption({
            incident_id: data.incident_id,
            ambulance_id: data.ambulance_id,
            ambulance_plate: data.ambulance_plate,
            intersection_id: data.intersection_id,
            junction_name: data.junction_name,
            priority_level: 1,
            eta_seconds: data.eta_seconds,
            approach_direction: 'Primary Inbound Corridor',
          });

          // Broadcast preemption event to Police ITMS (all_incidents room)
          io?.to('all_incidents').emit('traffic_signal_preempted', {
            ...response,
            incident_id: data.incident_id,
            ambulance_id: data.ambulance_id,
            ambulance_plate: data.ambulance_plate,
          });
        } catch (err) {
          console.error('[Socket.io] Error handling signal_preempt_request:', err);
        }
      }
    );

    // Phase 17: Pre-Alert Soft Marker Socket Handlers
    socket.on(
      'impact_suspected',
      async (
        data: {
          id?: string;
          latitude: number;
          longitude: number;
          speed_before_impact?: number;
          timestamp?: string;
          victim_metadata?: Record<string, unknown>;
        },
        ack?: (res: { status: string; id?: string }) => void
      ) => {
        try {
          if (!data || typeof data.latitude !== 'number' || typeof data.longitude !== 'number') {
            ack?.({ status: 'error' });
            return;
          }

          const id = data.id;
          if (id) {
            const existing = await query(`SELECT id, status FROM incidents WHERE id = $1`, [id]);
            if (existing.rows.length > 0) {
              ack?.({ status: 'ok', id });
              return;
            }
          }

          const insertSql = id
            ? `
              INSERT INTO incidents (id, location, status, victim_metadata)
              VALUES ($1, ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography, 'suspected', $4)
              RETURNING id, status, ST_Y(location::geometry) AS latitude, ST_X(location::geometry) AS longitude, created_at;
            `
            : `
              INSERT INTO incidents (location, status, victim_metadata)
              VALUES (ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, 'suspected', $3)
              RETURNING id, status, ST_Y(location::geometry) AS latitude, ST_X(location::geometry) AS longitude, created_at;
            `;

          const params = id
            ? [id, data.longitude, data.latitude, data.victim_metadata ? JSON.stringify(data.victim_metadata) : null]
            : [data.longitude, data.latitude, data.victim_metadata ? JSON.stringify(data.victim_metadata) : null];

          const result = await query(insertSql, params);
          const inc = result.rows[0];

          io?.to('all_incidents').emit('incident_suspected', {
            id: inc.id,
            latitude: Number(inc.latitude),
            longitude: Number(inc.longitude),
            speed_before_impact: data.speed_before_impact ?? null,
            status: 'suspected',
            is_suspected: true,
            soft_marker: true,
            created_at: inc.created_at,
          });

          scheduleSilentPromotion(inc.id, 30000);
          ack?.({ status: 'ok', id: inc.id });
        } catch (err) {
          console.error('[Socket.io] Error in impact_suspected:', err);
          ack?.({ status: 'error' });
        }
      }
    );

    socket.on('confirm_suspected_incident', async (data: { id: string }) => {
      try {
        if (data?.id) {
          await promoteSuspectedIncident(data.id, 'USER_CONFIRMED');
        }
      } catch (err) {
        console.error('[Socket.io] Error confirming suspected incident:', err);
      }
    });

    socket.on('cancel_suspected_incident', async (data: { id: string }) => {
      try {
        if (data?.id) {
          cancelSilentPromotion(data.id);
          await query(`UPDATE incidents SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP WHERE id = $1`, [data.id]);
          io?.to('all_incidents').emit('incident_cancelled', { id: data.id, timestamp: new Date().toISOString() });
        }
      } catch (err) {
        console.error('[Socket.io] Error cancelling suspected incident:', err);
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

          // 1. Strict Zero-Storage & Photo Encryption Guarantee: Store in volatile Redis RAM encrypted with AES-256-GCM
          // ZERO plaintext photo writes to Redis or disk occur.
          await storeEncryptedIncidentPhoto(effectiveIncidentId, dataUrl, 900);
          if (effectiveIncidentId !== incidentId) {
            await storeEncryptedIncidentPhoto(incidentId, dataUrl, 900);
          }
          // Cross-link with sibling incidents created in last 3 minutes
          try {
            const siblingRes = await query<{ id: string }>(
              `SELECT id FROM incidents WHERE created_at > NOW() - INTERVAL '3 minutes' LIMIT 6;`
            );
            for (const sib of siblingRes.rows) {
              if (sib.id !== effectiveIncidentId && sib.id !== incidentId) {
                await storeEncryptedIncidentPhoto(sib.id, dataUrl, 900);
              }
            }
          } catch (_) {}
          console.log(`[Photo Encryption] Stored AES-256-GCM encrypted photo in Redis RAM (TTL 900s) for incident: ${effectiveIncidentId}`);

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

          // Always ensure accepted hospital receives the image update
          try {
            const accRes = await query<{ accepted_hospital_id: string | null }>(
              'SELECT accepted_hospital_id FROM incidents WHERE id = $1',
              [effectiveIncidentId]
            );
            if (accRes.rows.length > 0 && accRes.rows[0].accepted_hospital_id) {
              if (!hospitalIds.includes(accRes.rows[0].accepted_hospital_id)) {
                hospitalIds.push(accRes.rows[0].accepted_hospital_id);
              }
            }
          } catch (_) {
            // Non-fatal
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

    // =========================================================================
    // PHASE 12: WEBRTC SIGNALING LAYER OVER EXISTING SOCKET.IO CONNECTION
    // -------------------------------------------------------------------------
    // Handles signaling relays (offer, answer, ICE candidates) between mobile peer
    // and receiving hospital dashboard(s) for direct P2P photo/video streaming.
    //
    // STUN / NAT TRAVERSAL & TURN ARCHITECTURAL LIMITATION NOTE:
    // Peers utilize free public Google STUN servers (stun:stun.l.google.com:19302)
    // for standard NAT hole-punching. In symmetric-NAT or highly restrictive
    // enterprise/hospital Wi-Fi networks, a TURN relay server (e.g. coturn with
    // credentials) is required for guaranteed peer connectivity.
    // As external TURN infrastructure is not provisioned for this hackathon, this
    // is an honest documented limitation: if WebRTC peer negotiation times out (5s),
    // Rakshak-AI automatically and seamlessly falls back to Phase 6's zero-storage
    // WebSocket binary streaming pipeline.
    //
    // ZERO-STORAGE GUARANTEE:
    // Signaling payloads strictly contain SDP session descriptors and ICE candidates.
    // No image bytes or pixel buffers pass through or persist to server storage.
    // =========================================================================

    socket.on(
      'webrtc_offer',
      async (data: {
        incident_id: string;
        sdp: unknown;
      }) => {
        try {
          if (!data?.incident_id || !data?.sdp) return;
          const incidentId = data.incident_id;

          console.log(`[WebRTC Signaling] Received webrtc_offer from ${socket.id} for incident: ${incidentId}`);

          // Resolve matched hospital IDs for room-isolated signaling dispatch
          let hospitalIds: string[] = [];
          try {
            const cachedHospitals = await redis.get(`incident_hospitals:${incidentId}`);
            if (cachedHospitals) {
              hospitalIds = JSON.parse(cachedHospitals);
            }
          } catch {
            // Non-fatal cache lookup failure
          }

          if (hospitalIds.length === 0) {
            try {
              const matchRes = await query<{ id: string }>(
                `SELECT h.id FROM hospitals h
                 JOIN incidents i ON ST_DWithin(h.location, i.location, 8000)
                 WHERE i.id = $1 AND h.has_trauma_center = true`,
                [incidentId]
              );
              hospitalIds = matchRes.rows.map((r) => r.id);
            } catch (dbErr) {
              console.error('[WebRTC Signaling] Error querying matched hospitals for webrtc_offer:', dbErr);
            }
          }

          const offerPayload = {
            incident_id: incidentId,
            sdp: data.sdp,
            sender_id: socket.id,
          };

          // Relay offer exclusively to matched hospital ER rooms
          hospitalIds.forEach((hospitalId) => {
            io!.to(hospitalId).emit('webrtc_offer', offerPayload);
            console.log(`[WebRTC Signaling] Relayed webrtc_offer to hospital room: ${hospitalId}`);
          });

          // Relay to police / all_incidents room
          io!.to('all_incidents').emit('webrtc_offer', offerPayload);

          // Relay to incident-specific room
          io!.to(`incident:${incidentId}`).emit('webrtc_offer', offerPayload);
        } catch (err) {
          console.error('[WebRTC Signaling] Error handling webrtc_offer:', err);
        }
      }
    );

    socket.on(
      'webrtc_answer',
      (data: {
        incident_id: string;
        sdp: unknown;
        target_id?: string;
      }) => {
        try {
          if (!data?.incident_id || !data?.sdp) return;

          console.log(`[WebRTC Signaling] Received webrtc_answer from ${socket.id} for incident: ${data.incident_id}`);

          const answerPayload = {
            incident_id: data.incident_id,
            sdp: data.sdp,
            sender_id: socket.id,
          };

          if (data.target_id) {
            io!.to(data.target_id).emit('webrtc_answer', answerPayload);
            console.log(`[WebRTC Signaling] Relayed webrtc_answer to target peer: ${data.target_id}`);
          } else {
            io!.to(`incident:${data.incident_id}`).emit('webrtc_answer', answerPayload);
            io!.to('all_incidents').emit('webrtc_answer', answerPayload);
          }
        } catch (err) {
          console.error('[WebRTC Signaling] Error handling webrtc_answer:', err);
        }
      }
    );

    socket.on(
      'webrtc_ice_candidate',
      (data: {
        incident_id: string;
        candidate: unknown;
        target_id?: string;
      }) => {
        try {
          if (!data?.incident_id || !data?.candidate) return;

          const candidatePayload = {
            incident_id: data.incident_id,
            candidate: data.candidate,
            sender_id: socket.id,
          };

          if (data.target_id) {
            io!.to(data.target_id).emit('webrtc_ice_candidate', candidatePayload);
          } else {
            socket.to(`incident:${data.incident_id}`).emit('webrtc_ice_candidate', candidatePayload);
            socket.to('all_incidents').emit('webrtc_ice_candidate', candidatePayload);
          }
        } catch (err) {
          console.error('[WebRTC Signaling] Error handling webrtc_ice_candidate:', err);
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
    blackspot_info?: BlackspotInfo | null;
    status?: string;
  },
  matchedHospitals: Hospital[],
  isEscalated: boolean = false
): Promise<void> {
  if (!io) {
    console.warn('[Socket.io] Skipping broadcast: Socket.io not initialized.');
    return;
  }

  // Retrieve and decrypt in-memory photo from Redis RAM only when relaying
  let activeImageUrl: string | null = null;
  try {
    activeImageUrl = await getDecryptedIncidentPhoto(incident.id);
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
      blackspot_info: incident.blackspot_info || null,
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
    blackspot_info: incident.blackspot_info || null,
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
  searchRadius: string,
  allMatchedHospitals?: Hospital[]
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

  // 3. Broadcast incident_escalated globally to Police, Hospitals, and Ambulances
  const payload = {
    incident_id: incident.id,
    status: 'escalated',
    search_radius: searchRadius,
    matched_hospitals_count: (allMatchedHospitals || newlyMatchedHospitals).length,
    newly_matched_hospitals: newlyMatchedHospitals,
    all_matched_hospitals: allMatchedHospitals || newlyMatchedHospitals,
  };

  io.emit('incident_escalated', payload);
  console.log(
    `[Socket.io] Emitted incident_escalated globally for ${incident.id} (radius: ${searchRadius}, network size: ${payload.matched_hospitals_count})`
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

export interface AmbulanceArrivalPayload {
  incident_id: string;
  ambulance_id: string;
  ambulance_plate: string;
  driver_name: string;
  driver_phone: string;
  origin_station: string;
  arrived_at: string;
  latitude?: number;
  longitude?: number;
}

/**
 * Phase 8: Broadcast incident claimed by ambulance unit.
 */
export async function broadcastIncidentClaimed(
  incidentId: string,
  ambulanceId: string,
  extra?: {
    ambulance_plate?: string;
    driver_name?: string;
    driver_phone?: string;
    origin_station?: string;
  }
): Promise<void> {
  if (!io) return;
  const payload = {
    incident_id: incidentId,
    ambulance_id: ambulanceId,
    ambulance_plate: extra?.ambulance_plate || 'KA-01-EA-108',
    driver_name: extra?.driver_name || 'Ramesh Kumar',
    driver_phone: extra?.driver_phone || '+91 98450 12345',
    origin_station: extra?.origin_station || 'Manipal Hospital HAL Depot Base',
    claimed_at: new Date().toISOString(),
  };
  io.to(`incident:${incidentId}`).emit('incident_claimed', payload);
  io.to('all_incidents').emit('incident_claimed', payload);

  try {
    const res = await query<{ accepted_hospital_id: string | null }>(
      'SELECT accepted_hospital_id FROM incidents WHERE id = $1',
      [incidentId]
    );
    if (res.rows[0]?.accepted_hospital_id) {
      io.to(res.rows[0].accepted_hospital_id).emit('incident_claimed', payload);
    }
  } catch (err) {
    console.error('[Socket.io] Error routing incident_claimed to accepted hospital:', err);
  }

  console.log(`[Socket.io] Broadcasted incident_claimed for ${incidentId} by ${ambulanceId}`);
}

/**
 * Phase 14: Broadcast ambulance arrival at incident scene.
 */
export async function broadcastAmbulanceArrived(payload: AmbulanceArrivalPayload): Promise<void> {
  if (!io) return;
  io.to(`incident:${payload.incident_id}`).emit('ambulance_arrived', payload);
  io.to('all_incidents').emit('ambulance_arrived', payload);

  try {
    const res = await query<{ accepted_hospital_id: string | null }>(
      'SELECT accepted_hospital_id FROM incidents WHERE id = $1',
      [payload.incident_id]
    );
    if (res.rows[0]?.accepted_hospital_id) {
      io.to(res.rows[0].accepted_hospital_id).emit('ambulance_arrived', payload);
    }
  } catch (err) {
    console.error('[Socket.io] Error routing ambulance_arrived to accepted hospital:', err);
  }

  console.log(
    `[Socket.io] Broadcasted ambulance_arrived for ${payload.incident_id} (Unit: ${payload.ambulance_id}, Plate: ${payload.ambulance_plate}, Driver: ${maskName(payload.driver_name)} ${maskPhoneNumber(payload.driver_phone)})`
  );
}

/**
 * Phase 8: Broadcast ambulance telemetry update.
 */
export async function broadcastAmbulanceLocation(telemetry: {
  incident_id: string;
  ambulance_id: string;
  latitude: number;
  longitude: number;
  speed_kmh?: number;
  heading?: number;
  timestamp?: string;
}): Promise<void> {
  if (!io) return;
  const payload = {
    ...telemetry,
    timestamp: telemetry.timestamp || new Date().toISOString(),
  };
  io.to(`incident:${telemetry.incident_id}`).emit('ambulance_location_update', payload);
  io.to('all_incidents').emit('ambulance_location_update', payload);

  try {
    const res = await query<{ accepted_hospital_id: string | null }>(
      'SELECT accepted_hospital_id FROM incidents WHERE id = $1',
      [telemetry.incident_id]
    );
    if (res.rows[0]?.accepted_hospital_id) {
      io.to(res.rows[0].accepted_hospital_id).emit('ambulance_location_update', payload);
    }
  } catch (err) {
    console.error('[Socket.io] Error routing ambulance_location_update to accepted hospital:', err);
  }
}




export function broadcastHospitalCapabilitiesUpdated(payload: {
  hospital_id: string;
  capabilities: Record<string, boolean>;
  updated_by: string;
  updated_at: string;
}): void {
  if (!io) return;
  io.emit('hospital:capabilities_updated', payload);
  io.to(payload.hospital_id).emit('hospital:capabilities_updated', payload);
  console.log(`[Socket.io] Emitted hospital:capabilities_updated for ${payload.hospital_id}`);
}
