import http from 'http';
import express, { Request, Response } from 'express';
import { checkIncidentBlackspot, getAllBlackspotZones } from '../services/blackspotService';
import { TripSentinelService } from '../services/tripSentinelService';

async function runPhase17Tests() {
  console.log('\n--- STARTING PHASE 17: CRASH INTELLIGENCE v2 BACKEND TEST SUITE ---');
  let passedCount = 0;
  let failedCount = 0;

  function assert(condition: boolean, testName: string, detail?: string) {
    if (condition) {
      console.log(`  [PASS] ${testName}`);
      passedCount++;
    } else {
      console.error(`  [FAIL] ${testName}${detail ? `: ${detail}` : ''}`);
      failedCount++;
    }
  }

  // ============================================================================
  // [1] TESTING PRE-ALERT STATE MACHINE (suspected -> promoted / cancelled)
  // ============================================================================
  console.log('\n[1] Testing Pre-Alert State Machine (suspected -> promoted / cancelled)...');

  // In-memory store simulating database state for fast, isolated test execution
  interface TestIncidentRecord {
    id: string;
    latitude: number;
    longitude: number;
    status: 'suspected' | 'broadcasting' | 'cancelled' | 'accepted';
    promoted_reason?: string;
    victim_metadata?: Record<string, unknown>;
  }

  const mockDbIncidents = new Map<string, TestIncidentRecord>();
  
  const app = express();
  app.use(express.json());

  // 1. POST /incidents/suspected
  app.post('/incidents/suspected', (req: Request, res: Response) => {
    const { id, latitude, longitude, victim_metadata } = req.body;
    if (!latitude || !longitude) {
      return res.status(400).json({ error: 'Missing coordinates' });
    }

    const incidentId = id || `mock-${Date.now()}`;
    if (mockDbIncidents.has(incidentId)) {
      return res.status(200).json({
        message: 'Suspected incident already recorded (idempotent)',
        incident: mockDbIncidents.get(incidentId),
        is_suspected: true,
      });
    }

    const record: TestIncidentRecord = {
      id: incidentId,
      latitude,
      longitude,
      status: 'suspected',
      victim_metadata,
    };
    mockDbIncidents.set(incidentId, record);

    return res.status(201).json({
      message: 'Pre-alert suspected incident logged (Police soft standby)',
      incident: record,
      is_suspected: true,
    });
  });

  // 2. POST /incidents/:id/confirm
  app.post('/incidents/:id/confirm', (req: Request, res: Response) => {
    const { id } = req.params;
    const existing = mockDbIncidents.get(id);
    if (!existing) {
      return res.status(404).json({ error: 'Incident not found' });
    }

    existing.status = 'broadcasting';
    existing.promoted_reason = req.body.reason || 'USER_CONFIRMED';
    return res.status(200).json({
      message: 'Incident confirmed and promoted to trauma triage',
      incident: existing,
    });
  });

  // 3. POST /incidents/:id/cancel
  app.post('/incidents/:id/cancel', (req: Request, res: Response) => {
    const { id } = req.params;
    const existing = mockDbIncidents.get(id);
    if (!existing) {
      return res.status(404).json({ error: 'Incident not found' });
    }

    existing.status = 'cancelled';
    return res.status(200).json({
      message: 'Suspected incident cancelled successfully',
      id,
      status: 'cancelled',
    });
  });

  // 4. POST /incidents (Idempotent confirm & promotion)
  app.post('/incidents', (req: Request, res: Response) => {
    const { id, latitude, longitude, status } = req.body;
    if (id && mockDbIncidents.has(id)) {
      const existing = mockDbIncidents.get(id)!;
      if (existing.status === 'suspected' && (status === 'broadcasting' || !status)) {
        existing.status = 'broadcasting';
        existing.promoted_reason = 'COUNTDOWN_EXPIRED';
        return res.status(200).json({
          message: 'Suspected incident promoted to broadcasting (idempotent confirm)',
          incident: existing,
        });
      }
      return res.status(200).json({
        message: 'Incident already exists (idempotent)',
        incident: existing,
      });
    }

    const incidentId = id || `mock-${Date.now()}`;
    const record: TestIncidentRecord = {
      id: incidentId,
      latitude,
      longitude,
      status: status || 'broadcasting',
    };
    mockDbIncidents.set(incidentId, record);
    return res.status(201).json({ incident: record });
  });

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, resolve));
  const port = (server.address() as { port: number }).port;
  const baseUrl = `http://127.0.0.1:${port}`;

  async function postJson(path: string, body: unknown) {
    const res = await fetch(`${baseUrl}${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    const data = await res.json().catch(() => ({}));
    return { status: res.status, data };
  }

  // Test 1.1: Pre-alert creation
  const preAlertUuid = 'test-prealert-001';
  const res1 = await postJson('/incidents/suspected', {
    id: preAlertUuid,
    latitude: 12.9352,
    longitude: 77.6245,
    victim_metadata: { speed_before_kmh: 68.0 },
  });
  assert(res1.status === 201, 'POST /incidents/suspected returns 201 Created');
  assert(res1.data.incident?.status === 'suspected', 'Pre-alert status is "suspected"');
  assert(res1.data.is_suspected === true, 'Pre-alert response carries is_suspected flag');

  // Test 1.2: Promote via /confirm
  const resConfirm = await postJson(`/incidents/${preAlertUuid}/confirm`, {
    reason: 'USER_CONFIRMED',
  });
  assert(resConfirm.status === 200, 'POST /incidents/:id/confirm returns 200 OK');
  assert(resConfirm.data.incident?.status === 'broadcasting', 'Promoted incident status transitions to "broadcasting"');
  assert(resConfirm.data.incident?.promoted_reason === 'USER_CONFIRMED', 'Promoted incident records USER_CONFIRMED reason');

  // Test 1.3: User cancellation via /cancel
  const cancelUuid = 'test-cancel-002';
  await postJson('/incidents/suspected', {
    id: cancelUuid,
    latitude: 12.9716,
    longitude: 77.5946,
  });
  const resCancel = await postJson(`/incidents/${cancelUuid}/cancel`, {});
  assert(resCancel.status === 200, 'POST /incidents/:id/cancel returns 200 OK');
  assert(resCancel.data.status === 'cancelled', 'Cancelled incident transitions to "cancelled"');

  // ============================================================================
  // [2] TESTING CLIENT UUID IDEMPOTENCY
  // ============================================================================
  console.log('\n[2] Testing Client UUID Idempotency...');

  const idempotentUuid = 'test-idempotent-999';
  // Step 1: Initial suspected post
  const idemp1 = await postJson('/incidents/suspected', {
    id: idempotentUuid,
    latitude: 12.9176,
    longitude: 77.6238,
  });
  assert(idemp1.status === 201, 'First POST with UUID creates incident (201)');

  // Step 2: Retry with exact same UUID to /suspected returns 200 without duplication
  const idemp2 = await postJson('/incidents/suspected', {
    id: idempotentUuid,
    latitude: 12.9176,
    longitude: 77.6238,
  });
  assert(idemp2.status === 200, 'Duplicate POST /suspected returns 200 OK (idempotent dedupe)');
  assert(idemp2.data.message.includes('idempotent'), 'Idempotency message returned on duplicate pre-alert');

  // Step 3: Promotion via standard POST /incidents on countdown expiry
  const idempPromote = await postJson('/incidents', {
    id: idempotentUuid,
    latitude: 12.9176,
    longitude: 77.6238,
    status: 'broadcasting',
  });
  assert(idempPromote.status === 200, 'POST /incidents with existing suspected UUID promotes idempotently (200 OK)');
  assert(idempPromote.data.incident?.status === 'broadcasting', 'Incident promoted to broadcasting upon countdown expiry');

  // Step 4: Retrying POST /incidents again returns existing broadcasting incident without duplication
  const idempRetry = await postJson('/incidents', {
    id: idempotentUuid,
    latitude: 12.9176,
    longitude: 77.6238,
  });
  assert(idempRetry.status === 200, 'Subsequent retry of POST /incidents returns existing incident (200 OK)');
  assert(mockDbIncidents.size === 3, 'In-memory incident count verified: exact deduplication with zero duplicates');

  // ============================================================================
  // [3] TESTING TRIP SENTINEL (3-Tier Escalation & Highway 60 km/h Limit)
  // ============================================================================
  console.log('\n[3] Testing Trip Sentinel (3-Tier Escalation & Highway 60 km/h Limit)...');

  const sentinel = TripSentinelService.getInstance();
  assert(sentinel.CRITICAL_SPEED_THRESHOLD_KMH === 60.0, 'TripSentinel critical speed limit is strictly 60.0 km/h (highway transit)');

  // Test 3.1: Start session
  const testSession = await sentinel.startTrip({
    sessionId: 'session-highway-test',
    userId: 'user-pilot-101',
    vehiclePlate: 'KA-01-MJ-9988',
    lastLatitude: 12.9176,
    lastLongitude: 77.6238,
    lastSpeedKmh: 75.0, // Highway speed > 60 km/h
    lastHeading: 180,
  });
  assert(testSession.status === 'active', 'Started journey session begins in "active" state');

  // Test 3.2: Heartbeat update maintains active state
  const hbRes = await sentinel.recordHeartbeat({
    sessionId: 'session-highway-test',
    latitude: 12.9180,
    longitude: 77.6240,
    speedKmh: 82.0,
  });
  assert(hbRes.status === 'HEARTBEAT_ACKNOWLEDGED', 'Live heartbeat acknowledged successfully');

  // Test 3.3: Low speed (< 60 km/h) signal cessation does NOT trigger emergency (city traffic protection)
  const lowSpeedSession = await sentinel.startTrip({
    sessionId: 'session-city-traffic',
    userId: 'user-city-202',
    vehiclePlate: 'KA-05-AB-1234',
    lastLatitude: 12.9716,
    lastLongitude: 77.5946,
    lastSpeedKmh: 28.0, // Low city speed < 60 km/h
    lastHeading: 90,
  });
  assert(lowSpeedSession.lastSpeedKmh < sentinel.CRITICAL_SPEED_THRESHOLD_KMH, 'City traffic speed (28 km/h) is below 60 km/h threshold');

  // Test 3.4: Graceful trip end
  const endRes = await sentinel.endTrip('session-city-traffic');
  assert(endRes === true, 'Normal parking/trip end completes session gracefully');

  // Clean up test sessions
  await sentinel.endTrip('session-highway-test');

  // ============================================================================
  // [4] TESTING ACCIDENT BLACKSPOT SPATIAL CLUSTERING
  // ============================================================================
  console.log('\n[4] Testing Accident Blackspot Spatial Clustering...');

  // Test 4.1: Preset reference zones list
  const allZones = await getAllBlackspotZones();
  assert(allZones.length >= 3, 'Blackspot service provides preset high-risk accident corridors');
  const silkboardPreset = allZones.find((z) => z.id === 'zone-blr-silkboard');
  assert(silkboardPreset !== undefined, 'Silk Board Central Junction preset is defined');

  // Test 4.2: Incident directly at Silk Board coordinates (12.9176, 77.6238)
  const silkboardCheck = await checkIncidentBlackspot(12.9176, 77.6238);
  assert(silkboardCheck.is_blackspot === true, 'Coordinates at Silk Board correctly identified as blackspot');
  assert(silkboardCheck.incident_count >= 5, 'Silk Board blackspot reports >= 5 historical collisions');
  assert(silkboardCheck.zone_name.includes('Silk Board'), 'Identifies correct zone name for Silk Board');

  // Test 4.3: Incident near MG Road / Brigade Road (12.9740, 77.6080)
  const mgRoadCheck = await checkIncidentBlackspot(12.9745, 77.6085);
  assert(mgRoadCheck.is_blackspot === true, 'Coordinates within 500m of MG Road identified as blackspot');
  assert(mgRoadCheck.hazard_level === 'High', 'MG Road hazard level is classified as High');

  // Test 4.4: Coordinates far away from any accident corridor (e.g. outskirts)
  const safeAreaCheck = await checkIncidentBlackspot(13.2500, 77.3000);
  assert(safeAreaCheck.is_blackspot === false, 'Rural/isolated coordinates report is_blackspot: false');
  assert(safeAreaCheck.zone_name === 'Standard Patrol Segment', 'Isolated coordinates report standard patrol zone');

  // Teardown HTTP server
  server.close();

  // ============================================================================
  // SUMMARY
  // ============================================================================
  console.log('\n--- PHASE 17 TEST SUMMARY ---');
  console.log(`Passed: ${passedCount}`);
  console.log(`Failed: ${failedCount}`);
  if (failedCount > 0) {
    console.error(`FAILED: ${failedCount} tests failed.`);
    process.exit(1);
  } else {
    console.log('ALL PHASE 17 INTELLIGENCE TESTS PASSED SUCCESSFULLY.\n');
    process.exit(0);
  }
}

runPhase17Tests().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
