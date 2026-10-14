import { redis } from '../redis';
import { query } from '../db';
import { broadcastNewIncident, getIO } from '../socket';
import { Hospital } from '../types';

export const DEFAULT_SENTINEL_LOST_CONTACT_MS = process.env.SENTINEL_LOST_CONTACT_MS
  ? parseInt(process.env.SENTINEL_LOST_CONTACT_MS, 10)
  : 15000; // Tier 2 threshold (15s heartbeat silence)

export const DEFAULT_SENTINEL_ESCALATION_MS = process.env.SENTINEL_ESCALATION_MS
  ? parseInt(process.env.SENTINEL_ESCALATION_MS, 10)
  : 45000; // Tier 3 escalation threshold (45s silence window)

export const REDIS_POSITION_TTL_SECONDS = 60; // Ephemeral 60s TTL for privacy; no trip breadcrumb history

export interface TripSession {
  sessionId: string;
  userId: string;
  vehiclePlate: string;
  driverName?: string;
  driverPhone?: string;
  lastLatitude: number;
  lastLongitude: number;
  lastSpeedKmh: number;
  lastHeading: number;
  lastHeartbeatTime: number; // ms epoch
  status: 'active' | 'lost_contact' | 'escalated' | 'completed';
  bloodGroup?: string;
  emergencyContacts?: Array<{ name: string; phone: string; relation?: string }>;
  startedAt: string;
}

export interface TripHeartbeat {
  sessionId: string;
  latitude: number;
  longitude: number;
  speedKmh: number;
  heading?: number;
  timestamp?: string;
}

/**
 * Three-Tier Cloud Journey Sentinel & Contact Loss Safeguard
 * Tier 1: 'active' monitoring with ephemeral Redis state.
 * Tier 2: 'lost_contact' visible ONLY to Police console when heartbeat drops.
 * Tier 3: Full emergency incident only if silence continues past 45s AND speed was high with no braking.
 * Heartbeat resumption auto-resolves contact loss as a false alarm.
 */
export class TripSentinelService {
  private static instance: TripSentinelService;
  private sessions: Map<string, TripSession> = new Map();
  private watchdogTimer: NodeJS.Timeout | null = null;
  private readonly LOST_CONTACT_TIMEOUT_MS = DEFAULT_SENTINEL_LOST_CONTACT_MS;
  /**
   * Minimum speed threshold: Dead-man switch operates strictly above 60 km/h (highway transit speeds).
   * In slow urban/city traffic (<60 km/h), telemetry silence is attributed to normal stoppage,
   * battery depletion, parking, or tunnel loss to prevent false alarms.
   */
  public readonly CRITICAL_SPEED_THRESHOLD_KMH = 60.0;

  private constructor() {
    this.startWatchdogLoop();
  }

  public static getInstance(): TripSentinelService {
    if (!TripSentinelService.instance) {
      TripSentinelService.instance = new TripSentinelService();
    }
    return TripSentinelService.instance;
  }

  /**
   * Initializes an active vehicle journey (Requires rider in-app consent).
   */
  public async startTrip(session: Omit<TripSession, 'lastHeartbeatTime' | 'status' | 'startedAt'>): Promise<TripSession> {
    const fullSession: TripSession = {
      ...session,
      lastHeartbeatTime: Date.now(),
      status: 'active',
      startedAt: new Date().toISOString(),
    };

    this.sessions.set(session.sessionId, fullSession);

    // Privacy safeguard: Only write ephemeral latest position with short TTL (no trip track/history)
    try {
      await redis.setex(
        `sentinel:latest:${session.sessionId}`,
        REDIS_POSITION_TTL_SECONDS,
        JSON.stringify({
          latitude: session.lastLatitude,
          longitude: session.lastLongitude,
          speedKmh: session.lastSpeedKmh,
          updatedAt: Date.now(),
        })
      );
    } catch {
      // Non-fatal cache failure
    }

    console.log(
      `[TripSentinel] Active Journey Sentinel started for ${session.vehiclePlate} (Session: ${session.sessionId})`
    );
    return fullSession;
  }

  /**
   * Records a live vehicle telemetry heartbeat.
   * If session was in 'lost_contact', automatically recovers and logs false alarm resolution.
   */
  public async recordHeartbeat(hb: TripHeartbeat): Promise<{ status: string; sessionFound: boolean }> {
    const session = this.sessions.get(hb.sessionId);

    if (!session || (session.status !== 'active' && session.status !== 'lost_contact')) {
      return { status: 'SESSION_NOT_FOUND_OR_INACTIVE', sessionFound: false };
    }

    // Auto-resolve Tier 2 false alarm if contact was previously flagged as lost
    if (session.status === 'lost_contact') {
      console.log(
        `[TripSentinel] Heartbeat resumed for ${session.vehiclePlate} (${hb.sessionId}). Auto-resolving false alarm.`
      );
      session.status = 'active';

      const io = getIO();
      if (io) {
        io.to('all_incidents').emit('sentinel_contact_restored', {
          sessionId: hb.sessionId,
          vehiclePlate: session.vehiclePlate,
          timestamp: new Date().toISOString(),
          message: 'Telemetry heartbeat restored. Contact loss alert auto-resolved.',
        });
      }
    }

    session.lastLatitude = hb.latitude;
    session.lastLongitude = hb.longitude;
    session.lastSpeedKmh = hb.speedKmh;
    session.lastHeading = hb.heading ?? session.lastHeading;
    session.lastHeartbeatTime = Date.now();

    // Privacy: Overwrite only current latest coordinate with short 60s TTL
    try {
      await redis.setex(
        `sentinel:latest:${hb.sessionId}`,
        REDIS_POSITION_TTL_SECONDS,
        JSON.stringify({
          latitude: hb.latitude,
          longitude: hb.longitude,
          speedKmh: hb.speedKmh,
          updatedAt: Date.now(),
        })
      );
    } catch {
      // Non-fatal
    }

    return { status: 'HEARTBEAT_ACKNOWLEDGED', sessionFound: true };
  }

  /**
   * Graceful journey termination (User stopped or parked normally)
   */
  public async endTrip(sessionId: string): Promise<boolean> {
    const session = this.sessions.get(sessionId);
    if (session) {
      session.status = 'completed';
      try {
        await redis.del(`sentinel:latest:${sessionId}`);
      } catch {
        // Ignore
      }
      console.log(`[TripSentinel] Journey completed gracefully: ${session.vehiclePlate} (${sessionId})`);
      return true;
    }
    return false;
  }

  /**
   * Background Watchdog Daemon: Evaluates three tiers of sentinel state
   */
  private startWatchdogLoop() {
    if (this.watchdogTimer) return;

    this.watchdogTimer = setInterval(async () => {
      const now = Date.now();

      for (const session of this.sessions.values()) {
        if (session.status !== 'active' && session.status !== 'lost_contact') continue;

        const ageMs = now - session.lastHeartbeatTime;

        // Tier 2: Transition from 'active' -> 'lost_contact' (POLICE ONLY soft marker)
        if (session.status === 'active' && ageMs > this.LOST_CONTACT_TIMEOUT_MS) {
          if (session.lastSpeedKmh >= this.CRITICAL_SPEED_THRESHOLD_KMH) {
            session.status = 'lost_contact';
            console.warn(
              `[TripSentinel] Tier 2: Contact lost with ${session.vehiclePlate} at ${session.lastSpeedKmh} km/h (Age: ${Math.round(ageMs / 1000)}s). Notifying Police only.`
            );

            const io = getIO();
            if (io) {
              io.to('all_incidents').emit('sentinel_lost_contact', {
                sessionId: session.sessionId,
                vehiclePlate: session.vehiclePlate,
                latitude: session.lastLatitude,
                longitude: session.lastLongitude,
                lastSpeedKmh: session.lastSpeedKmh,
                silenceDurationSeconds: Math.round(ageMs / 1000),
                timestamp: new Date().toISOString(),
                message: `Telemetry heartbeat silent for ${Math.round(ageMs / 1000)}s at highway speed (${session.lastSpeedKmh} km/h). Monitoring...`,
              });
            }
          } else {
            // Signal stopped at low speed (parking lot / garage / engine off)
            console.log(
              `[TripSentinel] Signal ceased at low speed (${session.lastSpeedKmh} km/h) for ${session.vehiclePlate}. Marking session closed without emergency.`
            );
            session.status = 'completed';
          }
        }

        // Tier 3: Escalate to full emergency incident if silence continues past ESCALATION_TIMEOUT_MS
        if (session.status === 'lost_contact' && ageMs > this.ESCALATION_TIMEOUT_MS) {
          if (session.lastSpeedKmh >= this.CRITICAL_SPEED_THRESHOLD_KMH) {
            await this.escalateToFullIncident(session);
          } else {
            session.status = 'completed';
          }
        }
      }
    }, 2000); // Check every 2 seconds
  }

  /**
   * Tier 3 escalation: Dispatches verified emergency to trauma centers and police
   */
  private async escalateToFullIncident(session: TripSession) {
    session.status = 'escalated';
    console.error(
      `[TripSentinel] 🚨 TIER 3 ESCALATION: Telemetry silent for >${this.ESCALATION_TIMEOUT_MS / 1000}s at ${session.lastSpeedKmh} km/h!\n` +
      `Vehicle: ${session.vehiclePlate} (Session: ${session.sessionId})\n` +
      `Coordinates: ${session.lastLatitude}, ${session.lastLongitude}\n` +
      `Initiating Autonomous Emergency Corridor Dispatch!`
    );

    try {
      const victimMetadata = {
        source: 'DEAD_MAN_COLLAPSE',
        detection_mechanism: 'Three-Tier Cloud Journey Sentinel',
        reason: 'Prolonged Telemetry Loss Following High-Speed Motion Without Braking',
        last_speed_kmh: session.lastSpeedKmh,
        last_heading: session.lastHeading,
        vehicle_plate: session.vehiclePlate,
        driver_name: session.driverName,
        driver_phone: session.driverPhone,
        bloodGroup: session.bloodGroup,
        emergency_contacts: session.emergencyContacts,
        extrapolated_crash_zone: true,
        watchdog_elapsed_seconds: Math.round(this.ESCALATION_TIMEOUT_MS / 1000),
        collapse_diagnosis: 'Heartbeat telemetry lost following high-speed motion without braking deceleration. Contact lost with vehicle.',
      };

      const insertSql = `
        INSERT INTO incidents (
          location,
          status,
          victim_metadata
        )
        VALUES (
          ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
          'escalated',
          $3
        )
        RETURNING
          id,
          ST_Y(location::geometry) as latitude,
          ST_X(location::geometry) as longitude,
          status,
          created_at,
          victim_metadata;
      `;

      const result = await query(insertSql, [
        session.lastLongitude,
        session.lastLatitude,
        JSON.stringify(victimMetadata),
      ]);

      if (result.rows.length > 0) {
        const incidentRow = result.rows[0];
        const incident = {
          id: incidentRow.id,
          latitude: Number(incidentRow.latitude),
          longitude: Number(incidentRow.longitude),
          created_at: incidentRow.created_at,
          victim_metadata: incidentRow.victim_metadata,
          status: 'escalated' as const,
        };

        // Query trauma hospitals within 15km
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
            AND ST_DWithin(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, 15000)
          ORDER BY distance_km ASC;
        `;
        const matchResult = await query<Hospital>(matchHospitalsSql, [
          session.lastLongitude,
          session.lastLatitude,
        ]);
        const matchedHospitals: Hospital[] = matchResult.rows.map((h: Hospital) => ({
          ...h,
          latitude: Number(h.latitude),
          longitude: Number(h.longitude),
          distance_km: Number(h.distance_km),
        }));

        await broadcastNewIncident(incident, matchedHospitals, true);

        const io = getIO();
        io?.to('all_incidents').emit('dead_man_collapse_detected', {
          incident_id: incidentRow.id,
          vehicle_plate: session.vehiclePlate,
          last_speed_kmh: session.lastSpeedKmh,
          latitude: session.lastLatitude,
          longitude: session.lastLongitude,
          heading: session.lastHeading,
          reason: 'Prolonged Telemetry Loss Following High-Speed Motion Without Braking',
          timestamp: new Date().toISOString(),
        });
      }
    } catch (err) {
      console.error('[TripSentinel] Failed to dispatch escalated incident:', err);
    }
  }

  public getActiveSessionsSummary(): Array<{
    sessionId: string;
    vehiclePlate: string;
    lastSpeedKmh: number;
    ageSeconds: number;
    status: string;
  }> {
    const now = Date.now();
    return Array.from(this.sessions.values()).map((s) => ({
      sessionId: s.sessionId,
      vehiclePlate: s.vehiclePlate,
      lastSpeedKmh: s.lastSpeedKmh,
      ageSeconds: Math.round((now - s.lastHeartbeatTime) / 1000),
      status: s.status,
    }));
  }

  public clearAllSessions(): void {
    this.sessions.clear();
    console.log('[TripSentinel] All in-memory trip sentinel sessions cleared');
  }
}
