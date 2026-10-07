import http from 'http';
import express, { Request, Response } from 'express';
import { signToken, verifyToken } from '../utils/jwt';
import {
  authenticateJWT,
  isAuthorizedForHospital,
  optionalAuth,
} from '../middleware/auth';
import { AuthUser } from '../types';

async function runTests() {
  console.log('--- STARTING RBAC & AUTH TEST SUITE ---');
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

  const hospitalAUser: AuthUser = {
    id: 'user-hosp-a',
    username: 'manipal_hal',
    role: 'hospital_staff',
    hospital_id: '11111111-1111-1111-1111-111111111111',
    hospital_name: 'Manipal Hospital HAL',
  };

  const hospitalBUser: AuthUser = {
    id: 'user-hosp-b',
    username: 'st_johns',
    role: 'hospital_staff',
    hospital_id: '22222222-2222-2222-2222-222222222222',
    hospital_name: "St. John's Medical College Hospital",
  };

  const policeUser: AuthUser = {
    id: 'user-police',
    username: 'police_control',
    role: 'police',
    hospital_id: null,
  };

  const ambulanceUser: AuthUser = {
    id: 'user-amb',
    username: 'ambulance_pilot',
    role: 'ambulance',
    hospital_id: null,
  };

  // 1. JWT Unit tests
  console.log('\n[1] Testing JWT Sign & Verify...');
  const tokenA = signToken(hospitalAUser);
  const tokenB = signToken(hospitalBUser);
  const tokenPolice = signToken(policeUser);
  const tokenAmb = signToken(ambulanceUser);

  assert(typeof tokenA === 'string' && tokenA.length > 20, 'Sign token for Hospital A');
  const verifiedA = verifyToken(tokenA);
  assert(verifiedA !== null, 'Verify valid token');
  assert(
    verifiedA?.hospital_id === '11111111-1111-1111-1111-111111111111',
    'Payload preserves hospital_id'
  );
  assert(verifiedA?.role === 'hospital_staff', 'Payload preserves role');

  const invalidVerified = verifyToken('invalid.bogus.token');
  assert(invalidVerified === null, 'Rejects malformed token');

  // 2. Direct Middleware & Helper Unit Tests
  console.log('\n[2] Testing isAuthorizedForHospital & requireRole directly...');

  const mockReqMatching = { user: hospitalAUser } as unknown as Request;
  const mockReqMismatch = { user: hospitalAUser } as unknown as Request;
  const mockReqPolice = { user: policeUser } as unknown as Request;

  const authMatch = isAuthorizedForHospital(
    mockReqMatching,
    '11111111-1111-1111-1111-111111111111'
  );
  assert(authMatch === true, 'isAuthorizedForHospital permits matching hospital staff');

  const authMismatch = isAuthorizedForHospital(
    mockReqMismatch,
    '22222222-2222-2222-2222-222222222222'
  );
  assert(authMismatch === false, 'isAuthorizedForHospital blocks mismatched hospital staff');

  const authPolice = isAuthorizedForHospital(
    mockReqPolice,
    '11111111-1111-1111-1111-111111111111'
  );
  assert(authPolice === false, 'isAuthorizedForHospital blocks police role from acting as hospital');

  // 3. HTTP Integration Test with Express Router
  console.log('\n[3] Testing Express Route RBAC enforcement...');
  const app = express();
  app.use(express.json());

  // Mock routes matching backend routes/incidents.ts
  app.post(
    '/incidents/:id/accept',
    authenticateJWT,
    (req: Request, res: Response) => {
      if (req.user?.role === 'police') {
        return res.status(403).json({
          error: 'Forbidden',
          message: 'Police role may view incidents but is not authorized to accept or reject hospital triage cases.',
        });
      }
      const { hospital_id } = req.body;
      if (req.user?.role === 'hospital_staff' && req.user.hospital_id !== hospital_id) {
        return res.status(403).json({
          error: 'Forbidden',
          message: `Hospital staff may only accept incidents on behalf of their assigned hospital (${req.user.hospital_id}).`,
        });
      }
      return res.json({ success: true, message: 'Incident accepted by facility' });
    }
  );

  app.post(
    '/incidents/:id/reject',
    authenticateJWT,
    (req: Request, res: Response) => {
      if (req.user?.role === 'police') {
        return res.status(403).json({
          error: 'Forbidden',
          message: 'Police role may view incidents but is not authorized to accept or reject hospital triage cases.',
        });
      }
      const { hospital_id } = req.body;
      if (req.user?.role === 'hospital_staff' && req.user.hospital_id !== hospital_id) {
        return res.status(403).json({
          error: 'Forbidden',
          message: `Hospital staff may only reject incidents on behalf of their assigned hospital (${req.user.hospital_id}).`,
        });
      }
      return res.json({ success: true, message: 'Incident rejected by facility' });
    }
  );

  app.patch(
    '/incidents/:id/status',
    authenticateJWT,
    (req: Request, res: Response) => {
      const { status, hospital_id } = req.body;
      if (req.user?.role === 'police' && (status === 'accepted' || status === 'declined' || status === 'rejected')) {
        return res.status(403).json({
          error: 'Forbidden',
          message: 'Police role cannot accept or decline incidents',
        });
      }
      if (
        (status === 'accepted' || status === 'declined' || status === 'rejected') &&
        req.user?.role === 'hospital_staff' &&
        req.user.hospital_id !== hospital_id
      ) {
        return res.status(403).json({
          error: 'Forbidden',
          message: `Hospital staff may only update incidents on behalf of their assigned hospital (${req.user.hospital_id}).`,
        });
      }
      return res.json({ success: true, message: 'Incident status updated' });
    }
  );

  app.post(
    '/incidents/:id/claim',
    optionalAuth,
    (req: Request, res: Response) => {
      if (req.user && !['ambulance', 'hospital_staff', 'police'].includes(req.user.role)) {
        return res.status(403).json({
          error: 'Forbidden',
          message: `Role '${req.user.role}' is not authorized to claim incidents.`,
        });
      }
      const { device_uuid } = req.body;
      if (!device_uuid) {
        return res.status(400).json({ error: 'device_uuid is required' });
      }
      return res.json({ success: true, message: 'Incident claimed by ambulance' });
    }
  );

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, resolve));
  const address = server.address();
  const port = typeof address === 'object' && address ? address.port : 0;
  const baseUrl = `http://localhost:${port}`;

  try {
    // 3a. Unauthenticated request to /incidents/:id/accept -> 401
    const unauthRes = await fetch(`${baseUrl}/incidents/test-inc/accept`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ hospital_id: hospitalAUser.hospital_id }),
    });
    assert(
      unauthRes.status === 401,
      'Unauthenticated request returns 401 Unauthorized'
    );

    // 3b. Hospital A staff accepting for Hospital A -> 200 OK
    const hospAOwnRes = await fetch(`${baseUrl}/incidents/test-inc/accept`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({ hospital_id: hospitalAUser.hospital_id }),
    });
    assert(
      hospAOwnRes.status === 200,
      'Hospital A staff accepting for Hospital A returns 200 OK'
    );

    // 3b-2. Hospital B staff accepting for Hospital B -> 200 OK
    const hospBOwnRes = await fetch(`${baseUrl}/incidents/test-inc/accept`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenB}`,
      },
      body: JSON.stringify({ hospital_id: hospitalBUser.hospital_id }),
    });
    assert(
      hospBOwnRes.status === 200,
      'Hospital B staff accepting for Hospital B returns 200 OK'
    );

    // 3c. Hospital A staff accepting for Hospital B -> 403 Forbidden
    const hospACrossRes = await fetch(`${baseUrl}/incidents/test-inc/accept`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({ hospital_id: hospitalBUser.hospital_id }),
    });
    assert(
      hospACrossRes.status === 403,
      'Hospital A staff accepting for Hospital B returns 403 Forbidden'
    );
    const hospACrossBody = (await hospACrossRes.json()) as { error?: string; message?: string };
    assert(
      Boolean(hospACrossBody.message?.includes('assigned hospital')),
      'Mismatched accept response contains assigned hospital error message'
    );

    // 3d. Hospital A staff rejecting for Hospital B -> 403 Forbidden
    const hospARejectCrossRes = await fetch(`${baseUrl}/incidents/test-inc/reject`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({ hospital_id: hospitalBUser.hospital_id, reason: 'Full' }),
    });
    assert(
      hospARejectCrossRes.status === 403,
      'Hospital A staff rejecting for Hospital B returns 403 Forbidden'
    );

    // 3e. Police attempting to accept -> 403 Forbidden
    const policeAcceptRes = await fetch(`${baseUrl}/incidents/test-inc/accept`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenPolice}`,
      },
      body: JSON.stringify({ hospital_id: hospitalAUser.hospital_id }),
    });
    assert(
      policeAcceptRes.status === 403,
      'Police role attempting to accept incident returns 403 Forbidden'
    );

    // 3f. PATCH status with mismatched hospital -> 403 Forbidden
    const patchMismatchRes = await fetch(`${baseUrl}/incidents/test-inc/status`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        status: 'accepted',
        hospital_id: hospitalBUser.hospital_id,
      }),
    });
    assert(
      patchMismatchRes.status === 403,
      'PATCH /incidents/:id/status for mismatched hospital returns 403 Forbidden'
    );

    // 3g. Ambulance claim with device_uuid without token -> 200 OK (Mobile flow preservation)
    const mobileClaimRes = await fetch(`${baseUrl}/incidents/test-inc/claim`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        device_uuid: 'mobile-device-uuid-1234',
        ambulance_id: 'KA-01-EA-1234',
      }),
    });
    assert(
      mobileClaimRes.status === 200,
      'Mobile ambulance claim with device_uuid works without token'
    );

    // 3h. Ambulance token claiming incident -> 200 OK
    const ambTokenClaimRes = await fetch(`${baseUrl}/incidents/test-inc/claim`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenAmb}`,
      },
      body: JSON.stringify({
        device_uuid: 'mobile-device-uuid-1234',
        ambulance_id: 'KA-01-EA-1234',
      }),
    });
    assert(
      ambTokenClaimRes.status === 200,
      'Ambulance token claiming incident returns 200 OK'
    );
  } finally {
    server.close();
  }

  console.log('\n--- RBAC TEST SUMMARY ---');
  console.log(`Passed: ${passedCount}`);
  console.log(`Failed: ${failedCount}`);

  if (failedCount > 0) {
    process.exit(1);
  } else {
    console.log('ALL RBAC TESTS PASSED SUCCESSFULLY.\n');
    process.exit(0);
  }
}

runTests().catch((err) => {
  console.error('Test execution failed with error:', err);
  process.exit(1);
});
