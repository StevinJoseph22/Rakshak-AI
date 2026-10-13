import { Router, Request, Response } from 'express';
import { TripSentinelService } from '../services/tripSentinelService';

export const sentinelRouter = Router();
const sentinelService = TripSentinelService.getInstance();

// POST /sentinel/start-trip - Begins an active journey sentinel
sentinelRouter.post('/start-trip', async (req: Request, res: Response) => {
  try {
    const {
      sessionId,
      userId,
      vehiclePlate,
      driverName,
      driverPhone,
      latitude,
      longitude,
      speedKmh,
      heading,
      bloodGroup,
      emergencyContacts,
    } = req.body;

    if (!sessionId || !vehiclePlate || latitude === undefined || longitude === undefined) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'sessionId, vehiclePlate, latitude, and longitude are required',
      });
    }

    const session = await sentinelService.startTrip({
      sessionId,
      userId: userId || 'anonymous_driver',
      vehiclePlate,
      driverName: driverName || 'Registered Driver',
      driverPhone: driverPhone || '+91 98450 12345',
      lastLatitude: Number(latitude),
      lastLongitude: Number(longitude),
      lastSpeedKmh: Number(speedKmh || 0),
      lastHeading: Number(heading || 0),
      bloodGroup: bloodGroup || 'O+',
      emergencyContacts: emergencyContacts || [],
    });

    return res.status(201).json({
      status: 'SENTINEL_ARMED',
      session,
      watchdogTimeoutSeconds: 45,
      message: "Three-tier trip sentinel active. Telemetry loss creates soft lost-contact alert, escalating after 45s of high-speed silence.",
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return res.status(500).json({ error: 'Failed to start trip sentinel', details: message });
  }
});

// POST /sentinel/heartbeat - Periodic telemetry ping (every 3-5 seconds while driving)
sentinelRouter.post('/heartbeat', async (req: Request, res: Response) => {
  try {
    const { sessionId, latitude, longitude, speedKmh, heading, timestamp } = req.body;

    if (!sessionId || latitude === undefined || longitude === undefined) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'sessionId, latitude, and longitude are required',
      });
    }

    const result = await sentinelService.recordHeartbeat({
      sessionId,
      latitude: Number(latitude),
      longitude: Number(longitude),
      speedKmh: Number(speedKmh || 0),
      heading: Number(heading || 0),
      timestamp: timestamp || new Date().toISOString(),
    });

    return res.status(200).json(result);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return res.status(500).json({ error: 'Failed to record heartbeat', details: message });
  }
});

// POST /sentinel/end-trip - Graceful stop when driver parks normally
sentinelRouter.post('/end-trip', async (req: Request, res: Response) => {
  try {
    const { sessionId } = req.body;
    if (!sessionId) {
      return res.status(400).json({ error: 'sessionId is required' });
    }

    const ended = await sentinelService.endTrip(sessionId);
    return res.status(200).json({ status: ended ? 'TRIP_COMPLETED' : 'SESSION_NOT_FOUND' });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return res.status(500).json({ error: 'Failed to end trip', details: message });
  }
});

// GET /sentinel/active - Diagnostic listing of active monitored vehicles
sentinelRouter.get('/active', (_req: Request, res: Response) => {
  const active = sentinelService.getActiveSessionsSummary();
  return res.status(200).json({
    monitoredVehiclesCount: active.length,
    sessions: active,
  });
});

// POST /sentinel/simulate-collapse - Lab simulation trigger for hackathon demo
sentinelRouter.post('/simulate-collapse', async (req: Request, res: Response) => {
  try {
    const {
      vehiclePlate = 'KA-01-EA-108',
      speedKmh = 88.5,
      latitude = 12.9716,
      longitude = 77.5946,
    } = req.body;

    const testSessionId = `SIM-COLLAPSE-${Date.now()}`;
    await sentinelService.startTrip({
      sessionId: testSessionId,
      userId: 'test_victim_driver',
      vehiclePlate,
      driverName: 'Suresh Raina',
      driverPhone: '+91 98450 99887',
      lastLatitude: Number(latitude),
      lastLongitude: Number(longitude),
      lastSpeedKmh: Number(speedKmh),
      lastHeading: 180,
      bloodGroup: 'B+',
      emergencyContacts: [{ name: 'Pooja', phone: '+91 99887 76655', relation: 'Spouse' }],
    });

    return res.status(200).json({
      status: 'COLLAPSE_SIMULATION_ARMED',
      sessionId: testSessionId,
      vehiclePlate,
      speedKmh,
      message: 'Simulating contact loss: Heartbeat severed! Watchdog transitions to lost_contact, and escalates if high-speed silence persists for 45 seconds.',
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return res.status(500).json({ error: 'Simulation failed', details: message });
  }
});
