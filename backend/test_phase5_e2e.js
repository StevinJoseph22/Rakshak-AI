const { io } = require('../dashboard/node_modules/socket.io-client');
const http = require('http');

const BACKEND_URL = 'http://localhost:5000';
const MANIPAL_HOSPITAL_ID = '11111111-1111-1111-1111-111111111111'; // Old Airport Rd (Near 12.9592, 77.6499)
const ASTER_CMI_HOSPITAL_ID = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; // Hebbal (>12km away, outside 8km radius)

async function runTest() {
  console.log('=== [Phase 5 WebSocket Triage Broadcast E2E Test] ===');

  let manipalReceived = null;
  let policeReceived = null;
  let asterReceived = null;

  // 1. Connect Client 1: Manipal Hospital ER
  console.log('[Test] Connecting Hospital 1 (Manipal - Target Room)...');
  const manipalSocket = io(BACKEND_URL, { transports: ['websocket'] });

  // 2. Connect Client 2: Aster CMI Hospital ER (Non-target Room)
  console.log('[Test] Connecting Hospital 2 (Aster CMI - Non-target Room)...');
  const asterSocket = io(BACKEND_URL, { transports: ['websocket'] });

  // 3. Connect Client 3: Police Control Room
  console.log('[Test] Connecting Police Control Room (all_incidents)...');
  const policeSocket = io(BACKEND_URL, { transports: ['websocket'] });

  await new Promise((resolve) => setTimeout(resolve, 1000));

  // Join rooms
  manipalSocket.emit('join_hospital', MANIPAL_HOSPITAL_ID);
  asterSocket.emit('join_hospital', ASTER_CMI_HOSPITAL_ID);
  policeSocket.emit('join_police');

  manipalSocket.on('new_incident', (data) => {
    console.log('>>> [Manipal Hospital] Received new_incident:', JSON.stringify(data));
    manipalReceived = data;
  });

  asterSocket.on('new_incident', (data) => {
    console.error('>>> [Aster CMI Hospital] UNEXPECTED new_incident received:', JSON.stringify(data));
    asterReceived = data;
  });

  policeSocket.on('new_incident', (data) => {
    console.log('>>> [Police Control Room] Received new_incident:', JSON.stringify(data));
    policeReceived = data;
  });

  await new Promise((resolve) => setTimeout(resolve, 1000));

  // 4. Trigger incident near Manipal Hospital (12.9592, 77.6499)
  console.log('[Test] Sending POST /incidents near Manipal Hospital (12.9592, 77.6499)...');
  const incidentPayload = JSON.stringify({
    latitude: 12.9592,
    longitude: 77.6499,
    victim_metadata: {
      collision_force_g: 6.8,
      vehicle_type: 'Two-Wheeler',
      rider_status: 'Unresponsive',
    },
  });

  const postReq = http.request(
    `${BACKEND_URL}/incidents`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(incidentPayload),
      },
    },
    (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        console.log(`[Test] POST /incidents response status: ${res.statusCode}`);
        const parsed = JSON.parse(body);
        console.log(`[Test] Matched hospitals count: ${parsed.matched_hospitals_count}`);
      });
    }
  );

  postReq.write(incidentPayload);
  postReq.end();

  // Wait 3 seconds for WebSocket propagation
  console.log('[Test] Awaiting socket events for 3 seconds...');
  await new Promise((resolve) => setTimeout(resolve, 3000));

  // Disconnect sockets
  manipalSocket.disconnect();
  asterSocket.disconnect();
  policeSocket.disconnect();

  // 5. Assertions
  console.log('\n--- Assertion Checks ---');
  let passed = true;

  if (manipalReceived) {
    console.log('PASS: Manipal Hospital received incident broadcast.');
    if (manipalReceived.imageUrl === null) {
      console.log('PASS: imageUrl is null (Phase 6 placeholder present).');
    } else {
      console.error('FAIL: imageUrl should be null.');
      passed = false;
    }
    if (manipalReceived.distance_km !== null && manipalReceived.distance_km < 1.0) {
      console.log(`PASS: distance_km is accurate (${manipalReceived.distance_km} km).`);
    } else {
      console.error(`FAIL: Unexpected distance_km: ${manipalReceived.distance_km}`);
      passed = false;
    }
  } else {
    console.error('FAIL: Manipal Hospital did NOT receive new_incident event!');
    passed = false;
  }

  if (policeReceived) {
    console.log('PASS: Police Control Room received all_incidents broadcast.');
    if (policeReceived.matched_hospitals_count > 0) {
      console.log(`PASS: Police received matched_hospitals_count: ${policeReceived.matched_hospitals_count}`);
    } else {
      console.error('FAIL: Police matched_hospitals_count is 0.');
      passed = false;
    }
  } else {
    console.error('FAIL: Police Control Room did NOT receive new_incident event!');
    passed = false;
  }

  if (asterReceived === null) {
    console.log('PASS: Aster CMI Hospital (>12km away, outside 8km) did NOT receive the event (Room isolation verified).');
  } else {
    console.error('FAIL: Aster CMI Hospital incorrectly received the incident event!');
    passed = false;
  }

  if (passed) {
    console.log('\n>>> ALL PHASE 5 BROADCAST VERIFICATION TESTS PASSED SUCCESSFULLY! <<<');
    process.exit(0);
  } else {
    console.error('\n>>> PHASE 5 VERIFICATION FAILED! <<<');
    process.exit(1);
  }
}

runTest().catch((err) => {
  console.error('[Test Error]', err);
  process.exit(1);
});
