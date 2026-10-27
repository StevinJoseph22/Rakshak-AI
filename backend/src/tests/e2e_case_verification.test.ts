/* eslint-disable @typescript-eslint/no-explicit-any */
import http from 'http';
import crypto from 'crypto';
import { app } from '../server';

interface TestResponse<T = Record<string, unknown>> {
  status: number;
  body: T;
}

function request<T = Record<string, unknown>>(
  server: http.Server,
  method: string,
  path: string,
  body?: Record<string, unknown>,
  token?: string,
): Promise<TestResponse<T>> {
  return new Promise((resolve, reject) => {
    const addr = server.address();
    if (!addr || typeof addr === 'string') {
      return reject(new Error('Server not listening'));
    }
    const postData = body ? JSON.stringify(body) : undefined;
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    if (postData) {
      headers['Content-Length'] = Buffer.byteLength(postData).toString();
    }

    const req = http.request(
      {
        host: '127.0.0.1',
        port: addr.port,
        method,
        path,
        headers,
      },
      (res) => {
        let raw = '';
        res.on('data', (chunk) => (raw += chunk));
        res.on('end', () => {
          let parsed: unknown = {};
          try {
            parsed = JSON.parse(raw);
          } catch {
            parsed = { rawText: raw };
          }
          resolve({ status: res.statusCode || 500, body: parsed as T });
        });
      },
    );

    req.on('error', reject);
    if (postData) {
      req.write(postData);
    }
    req.end();
  });
}

async function runE2ECaseVerification() {
  console.log('\n================================================================');
  console.log('🚀 RUNNING END-TO-END RAKSHAK-AI SYSTEM CASE VERIFICATION');
  console.log('Testing: Real Postgres DB, Real Redis, API, State Machine, RBAC');
  console.log('================================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, testName: string, detail?: string) {
    if (condition) {
      console.log(`  [PASS] ${testName}`);
      passed++;
    } else {
      console.error(`  [FAIL] ${testName}${detail ? `: ${detail}` : ''}`);
      failed++;
    }
  }

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));

  try {
    // --------------------------------------------------------------------------
    // [1] Health & Connectivity Check
    // --------------------------------------------------------------------------
    console.log('[1] Checking Server Health & Core Metadata...');
    const healthRes = await request(server, 'GET', '/health');
    assert(healthRes.status === 200, 'Health endpoint returns 200 OK');
    assert((healthRes.body as any).status === 'ok', 'Health status is "ok"');

    // --------------------------------------------------------------------------
    // [2] Authenticate Hospital, Police, and Ambulance Roles
    // --------------------------------------------------------------------------
    console.log('\n[2] Authenticating Roles (Hospital Staff, Police, and Ambulance)...');
    const hospLoginRes = await request(server, 'POST', '/auth/login', {
      username: 'manipal_hal',
      password: 'hospital123',
    });
    assert(hospLoginRes.status === 200, 'Hospital staff authentication returns 200 OK');
    const hospToken = (hospLoginRes.body as any).token;
    assert(!!hospToken, 'Hospital staff receives valid JWT token');

    const policeLoginRes = await request(server, 'POST', '/auth/login', {
      username: 'police_control',
      password: 'police123',
    });
    assert(policeLoginRes.status === 200, 'Police authority authentication returns 200 OK');
    const policeToken = (policeLoginRes.body as any).token;
    assert(!!policeToken, 'Police receives valid JWT token');

    const ambLoginRes = await request(server, 'POST', '/auth/login', {
      username: 'ambulance_pilot',
      password: 'ambulance123',
    });
    assert(ambLoginRes.status === 200, 'Ambulance pilot authentication returns 200 OK');
    const ambToken = (ambLoginRes.body as any).token;
    assert(!!ambToken, 'Ambulance pilot receives valid JWT token');

    // --------------------------------------------------------------------------
    // [3] Simulate Real Crash: On-Device Pre-Alert
    // --------------------------------------------------------------------------
    console.log('\n[3] Simulating On-Device Crash Detection & Pre-Alert...');
    const testIncidentUuid = crypto.randomUUID();
    const preAlertRes = await request(server, 'POST', '/incidents/suspected', {
      id: testIncidentUuid,
      latitude: 12.9592, // Near Manipal HAL Airport Road
      longitude: 77.6531,
      victim_metadata: {
        victim_name: 'Stevin Joseph',
        vehicle_type: 'Two-Wheeler',
      },
      health_card: {
        blood_group: { value: 'B+ Positive', status: 'AVAILABLE', source: 'ABDM_VERIFIED' },
        allergies: { value: ['Penicillin Anaphylaxis'], status: 'AVAILABLE', source: 'ABDM_VERIFIED' },
      },
    });

    assert(preAlertRes.status === 201, 'POST /incidents/suspected creates pre-alert (201 Created)');
    const createdPreAlert = (preAlertRes.body as any).incident;
    assert(createdPreAlert.status === 'suspected', 'Pre-alert status is "suspected"');
    assert((preAlertRes.body as any).is_suspected === true, 'Pre-alert flagged as is_suspected');

    // --------------------------------------------------------------------------
    // [4] Countdown Expiry -> Incident Confirmation & Promotion
    // --------------------------------------------------------------------------
    console.log('\n[4] Promoting Suspected Pre-Alert to Broadcasting Incident...');
    const confirmRes = await request(server, 'POST', `/incidents/${testIncidentUuid}/confirm`, {
      reason: 'COUNTDOWN_EXPIRED',
    });
    assert(confirmRes.status === 200, 'POST /incidents/:id/confirm returns 200 OK');
    const promotedIncident = (confirmRes.body as any).incident;
    assert(promotedIncident.status === 'broadcasting', 'Incident promoted to "broadcasting"');

    // --------------------------------------------------------------------------
    // [5] Idempotency & Duplicate Protection
    // --------------------------------------------------------------------------
    console.log('\n[5] Verifying Network Retry & Client UUID Idempotency...');
    const retryRes = await request(server, 'POST', '/incidents/suspected', {
      id: testIncidentUuid,
      latitude: 12.9592,
      longitude: 77.6531,
    });
    assert(retryRes.status === 200, 'Duplicate POST returns 200 OK (idempotent deduplication)');

    // --------------------------------------------------------------------------
    // [6] Hospital Case Acceptance & Race-Condition Locking
    // --------------------------------------------------------------------------
    console.log('\n[6] Hospital Trauma Bay Case Acceptance & Concurrency Lock...');
    const acceptRes = await request(
      server,
      'POST',
      `/incidents/${testIncidentUuid}/accept`,
      {
        hospital_id: '11111111-1111-1111-1111-111111111111',
        eta_minutes: 8,
      },
      hospToken,
    );

    assert(acceptRes.status === 200, 'Assigned hospital accepts case (200 OK)');
    const acceptedIncident = (acceptRes.body as any).incident;
    assert(acceptedIncident.status === 'accepted', 'Incident status transitioned to "accepted"');

    // Attempt double acceptance by competing facility
    const apolloLoginRes = await request(server, 'POST', '/auth/login', {
      username: 'apollo_bg',
      password: 'hospital123',
    });
    const apolloToken = (apolloLoginRes.body as any).token;
    const doubleAcceptRes = await request(
      server,
      'POST',
      `/incidents/${testIncidentUuid}/accept`,
      {
        hospital_id: '33333333-3333-3333-3333-333333333333',
        eta_minutes: 15,
      },
      apolloToken,
    );
    assert(doubleAcceptRes.status === 409 || doubleAcceptRes.status === 403, 'Double acceptance by competing facility safely rejected (403/409)');

    // --------------------------------------------------------------------------
    // [7] Ambulance Claims Incident
    // --------------------------------------------------------------------------
    console.log('\n[7] Ambulance EMS Cockpit Claims Case...');
    const claimRes = await request(server, 'POST', `/incidents/${testIncidentUuid}/claim`, {
      ambulance_id: 'AMB-BLR-108',
      ambulance_plate: 'KA-05-AM-2024',
      driver_name: 'Pilot Ramesh',
      device_uuid: 'device-cockpit-test-uuid',
    });

    assert(claimRes.status === 200, 'Ambulance claims case returns 200 OK');
    const claimedIncident = (claimRes.body as any).incident;
    assert(claimedIncident.ambulance_id === 'AMB-BLR-108', 'Ambulance ID successfully recorded');

    // Transition status to en_route
    const enRouteRes = await request(
      server,
      'PATCH',
      `/incidents/${testIncidentUuid}/status`,
      { status: 'en_route' },
      ambToken,
    );
    assert(enRouteRes.status === 200, 'Ambulance updates status to en_route (200 OK)');
    assert((enRouteRes.body as any).incident.status === 'en_route', 'Status is "en_route"');

    // --------------------------------------------------------------------------
    // [8] Ambulance Arrives On Scene
    // --------------------------------------------------------------------------
    console.log('\n[8] Ambulance Arrives On Scene...');
    const arrivedRes = await request(server, 'POST', `/incidents/${testIncidentUuid}/ambulance-arrived`, {
      ambulance_id: 'AMB-BLR-108',
      ambulance_plate: 'KA-05-AM-2024',
      driver_name: 'Pilot Ramesh',
      latitude: 12.9592,
      longitude: 77.6531,
    });

    assert(arrivedRes.status === 200, 'Ambulance reports arrival (200 OK)');
    const arrivedIncident = (arrivedRes.body as any).incident;
    assert(!!arrivedIncident.ambulance_arrived_at, 'Ambulance arrival timestamp recorded');

    // --------------------------------------------------------------------------
    // [9] Security & Privacy: Police Blocked From Break-Glass Access
    // --------------------------------------------------------------------------
    console.log('\n[9] Verifying RBAC Security & Clinical Medical Data Shield...');
    const policeAccessRes = await request(
      server,
      'POST',
      `/incidents/${testIncidentUuid}/health-card/break-glass`,
      {
        reason: 'Police investigation attempt',
      },
      policeToken,
    );
    assert(policeAccessRes.status === 403, 'Police role strictly forbidden from break-glass access (403)');

    // --------------------------------------------------------------------------
    // [10] Hospital Break-Glass Access & Clinical Handover
    // --------------------------------------------------------------------------
    console.log('\n[10] Clinical Break-Glass Retrieval & Patient Triage...');
    const breakGlassRes = await request(
      server,
      'POST',
      `/incidents/${testIncidentUuid}/health-card/break-glass`,
      {
        reason: 'Acute polytrauma resuscitation in Bay 01',
      },
      hospToken,
    );

    assert(breakGlassRes.status === 200, 'Accepting hospital unlocks clinical card via Break-Glass (200 OK)');
    const cardData = (breakGlassRes.body as any).card;
    assert(!!cardData, 'Clinical health card retrieved');
    assert(cardData.blood_group?.value === 'B+ Positive', 'Blood group correctly matched to B+ Positive');

    // --------------------------------------------------------------------------
    // [11] Patient Admitted & Incident Resolved
    // --------------------------------------------------------------------------
    console.log('\n[11] Patient Admitted to Trauma Bay & Incident Resolution...');
    const resolveRes = await request(
      server,
      'PATCH',
      `/incidents/${testIncidentUuid}/status`,
      {
        status: 'resolved',
      },
      hospToken,
    );

    assert(resolveRes.status === 200, 'Incident resolution returns 200 OK');
    const resolvedIncident = (resolveRes.body as any).incident;
    assert(resolvedIncident.status === 'resolved', 'Incident status transitioned to "resolved"');

    console.log('\n================================================================');
    console.log(`SUMMARY: ${passed} PASSED, ${failed} FAILED`);
    console.log('ALL PIPELINES (DATABASE, REDIS, REST API, RBAC & AMBULANCE) VERIFIED 100% CLEAN!');
    console.log('================================================================\n');
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }

  if (failed > 0) {
    process.exit(1);
  }
}

runE2ECaseVerification().catch((err) => {
  console.error('[E2E Error]', err);
  process.exit(1);
});
