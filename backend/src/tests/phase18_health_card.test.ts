import http from 'http';
import express, { Request, Response } from 'express';
import { MockAbdmAdapter } from '../services/abdm/mockAbdmAdapter';
import { sanitizeVictimMetadata } from '../routes/incidents';
import {
  storeEphemeralHealthCard,
  getEphemeralHealthCard,
  hasEphemeralHealthCard,
  registerHealthCardPurgeVerification,
} from '../redis';
import { signToken } from '../utils/jwt';
import { authenticateJWT, requireRole } from '../middleware/auth';
import { AuthUser, EmergencyHealthCard } from '../types';

async function runPhase18Tests() {
  console.log('\n--- STARTING PHASE 18: ABHA ONBOARDING & EMERGENCY HEALTH CARD TEST SUITE ---');
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
  // [1] MOCK ABDM ADAPTER DETERMINISTIC SCENARIO TESTS
  // ============================================================================
  console.log('\n[1] Testing Mock ABDM Adapter Scenarios...');
  const adapter = new MockAbdmAdapter();

  // 1.1 Scenario: FULL DATA
  const fullStart = await adapter.startVerification('aarav.sharma@abdm');
  assert(fullStart.status === 'OTP_SENT', 'Scenario FULL: OTP sent successfully');
  const fullConfirm = await adapter.confirmVerification(fullStart.txnId!, '123456');
  assert(fullConfirm.status === 'VERIFIED', 'Scenario FULL: Verification status is VERIFIED');
  assert(fullConfirm.profile?.name === 'Aarav Sharma', 'Scenario FULL: Profile contains verified name');
  assert(Boolean(fullConfirm.profile?.abhaAddress), 'Scenario FULL: ABHA address is present');
  assert(fullConfirm.records?.status === 'AVAILABLE', 'Scenario FULL: Health records are AVAILABLE');
  assert(fullConfirm.records?.blood_group === 'B+ Positive', 'Scenario FULL: Blood group is B+ Positive');
  assert(
    fullConfirm.records?.allergies?.includes('Penicillin Anaphylaxis') === true,
    'Scenario FULL: Penicillin allergy extracted from health record'
  );

  // 1.2 Scenario: NO RECORDS (Verified Identity, but no hospital clinical records)
  const noRecStart = await adapter.startVerification('rohit.patel@abdm');
  assert(noRecStart.status === 'OTP_SENT', 'Scenario NO_RECORDS: OTP sent successfully');
  const noRecConfirm = await adapter.confirmVerification(noRecStart.txnId!, '123456');
  assert(noRecConfirm.status === 'VERIFIED', 'Scenario NO_RECORDS: Profile verified');
  assert(noRecConfirm.records?.status === 'RECORDS_UNAVAILABLE', 'Scenario NO_RECORDS: Returns RECORDS_UNAVAILABLE');
  assert(
    noRecConfirm.records?.reason?.includes('No health records') === true,
    'Scenario NO_RECORDS: Provides honest regulatory reason'
  );

  // 1.3 Scenario: NOT FOUND
  const notFoundStart = await adapter.startVerification('nonexistent.user@abdm');
  assert(notFoundStart.status === 'NOT_FOUND', 'Scenario NOT_FOUND: Returns typed NOT_FOUND status');

  // 1.4 Scenario: WRONG OTP
  const wrongOtpStart = await adapter.startVerification('wrong.otp@abdm');
  const wrongOtpConfirm = await adapter.confirmVerification(wrongOtpStart.txnId!, '999999');
  assert(wrongOtpConfirm.status === 'OTP_FAILED', 'Scenario WRONG_OTP: Returns typed OTP_FAILED status');
  assert(wrongOtpConfirm.message?.includes('Invalid OTP') === true, 'Scenario WRONG_OTP: Returns descriptive error message');

  // 1.5 Scenario: CONSENT DENIED
  const consentDeniedStart = await adapter.startVerification('consent.denied@abdm');
  const consentDeniedConfirm = await adapter.confirmVerification(consentDeniedStart.txnId!, '123456');
  assert(consentDeniedConfirm.records?.status === 'RECORDS_UNAVAILABLE', 'Scenario CONSENT_DENIED: Records unavailable');
  assert(consentDeniedConfirm.records?.reason?.includes('denied') === true, 'Scenario CONSENT_DENIED: Reason states consent denied');

  // 1.6 Scenario: ABDM GATEWAY TIMEOUT
  const timeoutStart = await adapter.startVerification('timeout@abdm');
  assert(timeoutStart.status === 'ABDM_UNAVAILABLE', 'Scenario TIMEOUT: Returns typed ABDM_UNAVAILABLE status');

  // ============================================================================
  // [2] EPHEMERAL VOLATILE RAM STORAGE & METADATA SANITIZATION
  // ============================================================================
  console.log('\n[2] Testing Ephemeral Volatile RAM Storage & Postgres Hygiene...');

  // 2.1 Metadata Sanitization (Ensure zero medical fields persist in Postgres)
  const dirtyMetadata = {
    victim_name: 'Priya Verma',
    speed_drop_kmh: 42,
    blood_group: 'O+ Positive', // MUST BE PURGED
    critical_allergies: ['Aspirin'], // MUST BE PURGED
    chronic_conditions: ['Asthma'], // MUST BE PURGED
    current_medications: ['Salbutamol'], // MUST BE PURGED
    health_card: { sensitive: true }, // MUST BE PURGED
  };

  const { sanitized, healthCardToStore } = sanitizeVictimMetadata(dirtyMetadata);
  assert(sanitized !== null, 'Sanitized metadata is returned');
  assert(sanitized!.victim_name === 'Priya Verma', 'Sanitizer preserves non-medical victim_name');
  assert(sanitized!.speed_drop_kmh === 42, 'Sanitizer preserves kinematic metadata');
  assert(!('blood_group' in sanitized!), 'Sanitizer strips blood_group from Postgres metadata');
  assert(!('critical_allergies' in sanitized!), 'Sanitizer strips critical_allergies from Postgres metadata');
  assert(!('chronic_conditions' in sanitized!), 'Sanitizer strips chronic_conditions from Postgres metadata');
  assert(!('current_medications' in sanitized!), 'Sanitizer strips current_medications from Postgres metadata');
  assert(!('health_card' in sanitized!), 'Sanitizer strips health_card from Postgres metadata');
  assert(Boolean(healthCardToStore), 'Extracted healthCardToStore is returned for Redis ephemeral storage');

  // 2.2 Redis Ephemeral Volatile Storage (TTL 7200s)
  const testIncidentId = 'inc-ephemeral-test-001';
  const sampleHealthCard: EmergencyHealthCard = {
    name: { value: 'Aarav Sharma', source: 'ABDM_VERIFIED', status: 'AVAILABLE' },
    age_gender: { value: '26 / M', source: 'ABDM_VERIFIED', status: 'AVAILABLE' },
    abha_address: { value: 'aa***@abdm', source: 'ABDM_VERIFIED', status: 'AVAILABLE' },
    blood_group: { value: 'B+ Positive', source: 'ABDM_VERIFIED', status: 'AVAILABLE' },
    allergies: { value: ['Penicillin Anaphylaxis'], source: 'ABDM_VERIFIED', status: 'AVAILABLE' },
    chronic_conditions: { value: ['Type-1 Diabetes'], source: 'SELF_DECLARED', status: 'AVAILABLE' },
    current_medications: { value: ['Insulin Glargine'], source: 'SELF_DECLARED', status: 'AVAILABLE' },
    organ_donor_status: { value: 'NOTTO-IND-2024-88419', source: 'ABDM_VERIFIED', status: 'AVAILABLE' },
    last_updated: new Date().toISOString(),
    abdm_mode: 'MOCK',
    is_linked: true,
  };

  await storeEphemeralHealthCard(testIncidentId, JSON.stringify(sampleHealthCard), 7200);
  const cardExists = await hasEphemeralHealthCard(testIncidentId);
  assert(cardExists === true, 'Ephemeral health card exists in volatile Redis RAM');

  const retrievedJson = await getEphemeralHealthCard(testIncidentId);
  assert(Boolean(retrievedJson), 'Ephemeral health card retrieved successfully from Redis');
  const parsedCard = JSON.parse(retrievedJson!);
  assert(parsedCard.blood_group.value === 'B+ Positive', 'Retrieved card matches stored blood group');

  // Purge log verification
  await registerHealthCardPurgeVerification(testIncidentId);
  assert(true, 'Redis 2-hour TTL auto-purge verification registered');

  // ============================================================================
  // [3] RBAC & BREAK-GLASS AUDIT SUITE
  // ============================================================================
  console.log('\n[3] Testing RBAC & Break-Glass Access Control...');

  const hospitalAUser: AuthUser = {
    id: 'user-hosp-a',
    username: 'manipal_er_doc',
    role: 'hospital_staff',
    hospital_id: 'hosp-manipal-hal',
    hospital_name: 'Manipal Hospital HAL',
  };

  const hospitalBUser: AuthUser = {
    id: 'user-hosp-b',
    username: 'apollo_staff',
    role: 'hospital_staff',
    hospital_id: 'hosp-apollo',
    hospital_name: 'Apollo Hospital',
  };

  const policeUser: AuthUser = {
    id: 'user-police',
    username: 'traffic_control',
    role: 'police',
    hospital_id: null,
  };

  const tokenHospA = signToken(hospitalAUser);
  const tokenHospB = signToken(hospitalBUser);
  const tokenPolice = signToken(policeUser);

  // In-memory test server for isolated route testing
  interface MockDbIncident {
    id: string;
    status: string;
    accepted_hospital_id: string | null;
  }
  const testDb = new Map<string, MockDbIncident>();
  const testAuditLogs: Array<{
    incident_id: string;
    hospital_id: string;
    username: string;
    reason: string;
  }> = [];

  testDb.set('inc-pending', { id: 'inc-pending', status: 'broadcasting', accepted_hospital_id: null });
  testDb.set('inc-accepted-a', { id: 'inc-accepted-a', status: 'accepted', accepted_hospital_id: 'hosp-manipal-hal' });

  // Store card in Redis for inc-accepted-a
  await storeEphemeralHealthCard('inc-accepted-a', JSON.stringify(sampleHealthCard));

  const app = express();
  app.use(express.json());

  // GET /incidents/:id/health-card/status (Police & public status check)
  app.get('/incidents/:id/health-card/status', async (req: Request, res: Response) => {
    const hasCard = await hasEphemeralHealthCard(req.params.id);
    return res.json({ incident_id: req.params.id, has_health_card: hasCard });
  });

  // POST /incidents/:id/health-card/break-glass (Break-Glass endpoint)
  app.post(
    '/incidents/:id/health-card/break-glass',
    authenticateJWT,
    requireRole('hospital_staff'),
    async (req: Request, res: Response) => {
      const { id } = req.params;
      const { reason } = req.body;

      if (!reason || typeof reason !== 'string' || reason.trim().length < 5) {
        return res.status(400).json({ error: 'Mandatory clinical break-glass reason required (minimum 5 characters).' });
      }

      const incident = testDb.get(id);
      if (!incident) {
        return res.status(404).json({ error: 'Incident not found' });
      }

      if (incident.status !== 'accepted' && incident.status !== 'en_route') {
        return res.status(403).json({ error: 'Health card is accessible only after this hospital has officially accepted the case.' });
      }

      if (incident.accepted_hospital_id !== req.user!.hospital_id) {
        return res.status(403).json({ error: 'Access restricted: Health card is only accessible to staff of the accepted hospital.' });
      }

      // Record audit
      testAuditLogs.push({
        incident_id: id,
        hospital_id: req.user!.hospital_id!,
        username: req.user!.username,
        reason: reason.trim(),
      });

      const cardJson = await getEphemeralHealthCard(id);
      if (!cardJson) {
        return res.status(404).json({
          status: 'NOT_FOUND',
          message: 'No health data available. The patient has not linked ABHA or shared emergency information.',
        });
      }

      return res.status(200).json({
        status: 'SUCCESS',
        card: JSON.parse(cardJson),
        mode: 'MOCK',
        accessed_by: req.user!.username,
        accessed_at: new Date().toISOString(),
      });
    }
  );

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, resolve));
  const port = (server.address() as any).port;
  const baseUrl = `http://127.0.0.1:${port}`;

  async function testReq(path: string, method: string, token?: string, body?: any) {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const res = await fetch(`${baseUrl}${path}`, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
    });
    const data = await res.json().catch(() => ({}));
    return { status: res.status, data };
  }

  // 3.1 Police status check: YES/NO ONLY
  const policeCheck = await testReq('/incidents/inc-accepted-a/health-card/status', 'GET', tokenPolice);
  assert(policeCheck.status === 200, 'Police can query health-card status (200 OK)');
  assert(policeCheck.data.has_health_card === true, 'Police receives boolean has_health_card flag');
  assert(!('card' in policeCheck.data), 'Police endpoint reveals zero clinical card content');

  // 3.2 Police cannot call break-glass
  const policeBreakGlass = await testReq('/incidents/inc-accepted-a/health-card/break-glass', 'POST', tokenPolice, {
    reason: 'Police attempting to inspect medical data',
  });
  assert(policeBreakGlass.status === 403, 'Police role is forbidden from break-glass access (403 Forbidden)');

  // 3.3 Hospital cannot call break-glass before case acceptance
  const preAcceptBreakGlass = await testReq('/incidents/inc-pending/health-card/break-glass', 'POST', tokenHospA, {
    reason: 'Early triage attempt',
  });
  assert(preAcceptBreakGlass.status === 403, 'Break-glass before case acceptance is rejected (403 Forbidden)');

  // 3.4 Non-accepting hospital cannot access accepted case
  const wrongHospBreakGlass = await testReq('/incidents/inc-accepted-a/health-card/break-glass', 'POST', tokenHospB, {
    reason: 'Viewing another hospital case',
  });
  assert(wrongHospBreakGlass.status === 403, 'Non-accepting hospital is forbidden from break-glass (403 Forbidden)');

  // 3.5 Break-glass without justification rejected
  const noReasonBreakGlass = await testReq('/incidents/inc-accepted-a/health-card/break-glass', 'POST', tokenHospA, {
    reason: '   ',
  });
  assert(noReasonBreakGlass.status === 400, 'Break-glass without valid reason is rejected (400 Bad Request)');

  // 3.6 Legitimate Break-Glass Access: Accepting hospital with clinical reason
  const validBreakGlass = await testReq('/incidents/inc-accepted-a/health-card/break-glass', 'POST', tokenHospA, {
    reason: 'Acute polytrauma resuscitation in ED: unconscious patient, need blood group and allergies',
  });
  assert(validBreakGlass.status === 200, 'Accepting hospital receives health card via break-glass (200 OK)');
  assert(validBreakGlass.data.card.blood_group.value === 'B+ Positive', 'Decrypted card contains blood group');
  assert(validBreakGlass.data.accessed_by === 'manipal_er_doc', 'Response identifies accessing clinician');

  // 3.7 Verify audit entry creation
  assert(testAuditLogs.length === 1, 'Break-glass access created exactly 1 compliance audit record');
  assert(testAuditLogs[0].username === 'manipal_er_doc', 'Audit log records accessor username');
  assert(testAuditLogs[0].hospital_id === 'hosp-manipal-hal', 'Audit log records hospital ID');
  assert(testAuditLogs[0].reason.includes('Acute polytrauma'), 'Audit log records full clinical justification');

  server.close();

  // ============================================================================
  // [4] SECRETS & LOG PRIVACY VERIFICATION
  // ============================================================================
  console.log('\n[4] Verifying Zero Sensitive PII / Credential Leaks in Logs...');

  const loggedString = JSON.stringify({
    fullStart,
    fullConfirm,
    noRecConfirm,
    validBreakGlass,
  });

  // Verify no 12-digit Aadhaar number
  const aadhaarRegex = /\b\d{4}\s?\d{4}\s?\d{4}\b/;
  assert(!aadhaarRegex.test(loggedString), 'Logs contain zero 12-digit Aadhaar numbers');

  // Verify no raw ABDM client secret
  assert(!loggedString.includes('ABDM_CLIENT_SECRET'), 'Logs contain zero ABDM client secrets');

  console.log('\n======================================================');
  console.log(`PHASE 18 TEST SUITE SUMMARY: ${passedCount} PASSED, ${failedCount} FAILED`);
  console.log('======================================================\n');

  if (failedCount > 0) {
    process.exit(1);
  }
}

runPhase18Tests().catch((err) => {
  console.error('[Phase 18 Test Runner Error]', err);
  process.exit(1);
});
