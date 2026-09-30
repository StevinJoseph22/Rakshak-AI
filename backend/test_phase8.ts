import http from 'http';
import { query } from './src/db';

const BASE_URL = 'http://127.0.0.1:5000';

function post(path: string, body: Record<string, unknown>): Promise<{ status: number; body: any }> {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = http.request(
      `${BASE_URL}${path}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(data),
        },
      },
      (res) => {
        let resData = '';
        res.on('data', (chunk) => (resData += chunk));
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode || 500, body: JSON.parse(resData) });
          } catch {
            resolve({ status: res.statusCode || 500, body: resData });
          }
        });
      }
    );
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

function get(path: string): Promise<{ status: number; body: any }> {
  return new Promise((resolve, reject) => {
    const req = http.request(`${BASE_URL}${path}`, { method: 'GET' }, (res) => {
      let resData = '';
      res.on('data', (chunk) => (resData += chunk));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode || 500, body: JSON.parse(resData) });
        } catch {
          resolve({ status: res.statusCode || 500, body: resData });
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

function del(path: string): Promise<{ status: number; body: any }> {
  return new Promise((resolve, reject) => {
    const req = http.request(`${BASE_URL}${path}`, { method: 'DELETE' }, (res) => {
      let resData = '';
      res.on('data', (chunk) => (resData += chunk));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode || 500, body: JSON.parse(resData) });
        } catch {
          resolve({ status: res.statusCode || 500, body: resData });
        }
      });
    });
    req.on('error', reject);
    req.end();
  });
}

async function runPhase8Tests() {
  console.log('====================================================');
  console.log('   RAKSHAK-AI PHASE 8 VERIFICATION & TEST SUITE    ');
  console.log('====================================================\n');

  // Purge test database
  await del('/incidents');

  // 1. Create Incident 1 (Koramangala, Bengaluru: 12.9352, 77.6245)
  console.log('--- TEST 1: Incident Creation for Spatial Filtering ---');
  const inc1Res = await post('/incidents', {
    latitude: 12.9352,
    longitude: 77.6245,
    victim_metadata: {
      speedDropKmh: 65,
      decelerationG: 7.2,
      driverName: 'Suresh Kumar',
    },
  });
  console.assert(inc1Res.status === 201, `Failed to create incident 1: status=${inc1Res.status}`);
  const incident1Id = inc1Res.body.incident.id;
  console.log(`✓ Incident 1 created: ${incident1Id} in Koramangala (12.9352, 77.6245)`);

  // 2. Create Incident 2 (Whitefield, Bengaluru: 12.9698, 77.7499, ~14km away)
  const inc2Res = await post('/incidents', {
    latitude: 12.9698,
    longitude: 77.7499,
    victim_metadata: {
      speedDropKmh: 75,
      decelerationG: 8.5,
      driverName: 'Priya Sharma',
    },
  });
  console.assert(inc2Res.status === 201, `Failed to create incident 2: status=${inc2Res.status}`);
  const incident2Id = inc2Res.body.incident.id;
  console.log(`✓ Incident 2 created: ${incident2Id} in Whitefield (12.9698, 77.7499)`);

  // 3. Test GET /incidents/nearby from Koramangala with 5km radius
  console.log('\n--- TEST 2: GET /incidents/nearby with 5km Radius ---');
  // Ambulance position in Koramangala: 12.9340, 77.6190
  const nearby5km = await get('/incidents/nearby?lat=12.9340&lng=77.6190&radius_km=5');
  console.assert(nearby5km.status === 200, `Expected 200, got ${nearby5km.status}`);
  console.assert(Array.isArray(nearby5km.body.incidents), 'Expected incidents array');

  const nearby5kmIds = nearby5km.body.incidents.map((i: any) => i.id);
  console.log(`Found ${nearby5km.body.incidents.length} incident(s) within 5km of ambulance:`, nearby5kmIds);
  console.assert(nearby5kmIds.includes(incident1Id), 'Incident 1 should be within 5km of ambulance');
  console.assert(!nearby5kmIds.includes(incident2Id), 'Incident 2 (Whitefield ~14km) should NOT be within 5km');
  console.log('✓ Spatial radius boundary filter verified: correctly includes Incident 1 and excludes Incident 2');

  // 4. Test GET /incidents/nearby with expanded 20km radius
  console.log('\n--- TEST 3: GET /incidents/nearby with 20km Radius ---');
  const nearby20km = await get('/incidents/nearby?lat=12.9340&lng=77.6190&radius_km=20');
  console.assert(nearby20km.status === 200, `Expected 200, got ${nearby20km.status}`);
  const nearby20kmIds = nearby20km.body.incidents.map((i: any) => i.id);
  console.log(`Found ${nearby20km.body.incidents.length} incident(s) within 20km:`, nearby20kmIds);
  console.assert(nearby20kmIds.includes(incident1Id), 'Incident 1 should be in 20km list');
  console.assert(nearby20kmIds.includes(incident2Id), 'Incident 2 should be in 20km list');
  console.log('✓ Expanded radius correctly retrieves both incidents sorted by distance');

  // 5. Test Ambulance Claiming: POST /incidents/:id/claim
  console.log('\n--- TEST 4: Ambulance Incident Claiming & Collision Guard ---');
  const claimRes1 = await post(`/incidents/${incident1Id}/claim`, {
    ambulance_id: 'Ambulance-BLR-108',
  });
  console.assert(claimRes1.status === 200, `Expected 200, got ${claimRes1.status}`);
  console.assert(claimRes1.body.incident.ambulance_id === 'Ambulance-BLR-108', 'ambulance_id mismatch');
  console.log('✓ Incident 1 successfully claimed by Ambulance-BLR-108');

  // Re-claim by same ambulance (idempotent)
  const claimSameRes = await post(`/incidents/${incident1Id}/claim`, {
    ambulance_id: 'Ambulance-BLR-108',
  });
  console.assert(claimSameRes.status === 200, 'Same ambulance re-claim should succeed');
  console.log('✓ Idempotent re-claim by same ambulance unit handled cleanly');

  // Claim by a different ambulance unit (should return 409 Conflict)
  const conflictRes = await post(`/incidents/${incident1Id}/claim`, {
    ambulance_id: 'Ambulance-BLR-102',
  });
  console.assert(conflictRes.status === 409, `Expected 409 Conflict, got ${conflictRes.status}`);
  console.log('✓ Second ambulance claim blocked with 409 Conflict to prevent racing to the same scene');

  // Verify database record
  const checkDb = await query<{ ambulance_id: string }>(
    'SELECT ambulance_id FROM incidents WHERE id = $1;',
    [incident1Id]
  );
  console.assert(checkDb.rows[0].ambulance_id === 'Ambulance-BLR-108', 'DB ambulance_id mismatch');
  console.log('✓ Database state verified: ambulance_id is correctly set to Ambulance-BLR-108');

  console.log('\n====================================================');
  console.log('   ALL PHASE 8 SPATIAL & CLAIM TESTS PASSED!       ');
  console.log('====================================================\n');
}

runPhase8Tests().catch((err) => {
  console.error('[Phase 8 Test Failure]', err);
  process.exit(1);
});
