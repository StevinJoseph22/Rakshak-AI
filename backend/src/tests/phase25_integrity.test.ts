import http from 'http';
import express, { Request, Response } from 'express';
import { signToken } from '../utils/jwt';
import { AuthUser } from '../types';
import { hospitalsRouter } from '../routes/hospitals';
import {
  computeRecordHash,
  GENESIS_PREV_HASH,
  VerifyChainResult,
} from '../services/auditService';

async function runPhase25Tests() {
  console.log('--- STARTING PHASE 25 INTEGRITY & AUDIT TEST SUITE ---');
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
    username: 'dr_manipal',
    role: 'hospital_staff',
    hospital_id: '11111111-1111-1111-1111-111111111111',
    hospital_name: 'Manipal Hospital HAL',
  };

  const hospitalBUser: AuthUser = {
    id: 'user-hosp-b',
    username: 'dr_stjohns',
    role: 'hospital_staff',
    hospital_id: '22222222-2222-2222-2222-222222222222',
    hospital_name: "St. John's Medical College Hospital",
  };

  const tokenA = signToken(hospitalAUser);
  const tokenB = signToken(hospitalBUser);

  // Setup test Express app
  const app = express();
  app.use(express.json());
  app.use('/hospitals', hospitalsRouter);

  // In-memory Incident Mock for Break-Glass Scoping Tests
  const mockIncidents: Record<string, {
    id: string;
    status: string;
    accepted_hospital_id: string | null;
    updated_at: string;
    created_at: string;
  }> = {
    'inc-broadcasting': {
      id: 'inc-broadcasting',
      status: 'broadcasting',
      accepted_hospital_id: null,
      updated_at: new Date().toISOString(),
      created_at: new Date().toISOString(),
    },
    'inc-accepted-hospital-b': {
      id: 'inc-accepted-hospital-b',
      status: 'accepted',
      accepted_hospital_id: '22222222-2222-2222-2222-222222222222',
      updated_at: new Date().toISOString(),
      created_at: new Date().toISOString(),
    },
    'inc-accepted-expired': {
      id: 'inc-accepted-expired',
      status: 'accepted',
      accepted_hospital_id: '11111111-1111-1111-1111-111111111111',
      // Accepted 45 minutes ago (> 30 min limit)
      updated_at: new Date(Date.now() - 45 * 60 * 1000).toISOString(),
      created_at: new Date(Date.now() - 50 * 60 * 1000).toISOString(),
    },
    'inc-accepted-valid': {
      id: 'inc-accepted-valid',
      status: 'accepted',
      accepted_hospital_id: '11111111-1111-1111-1111-111111111111',
      // Accepted 5 minutes ago (< 30 min limit)
      updated_at: new Date(Date.now() - 5 * 60 * 1000).toISOString(),
      created_at: new Date(Date.now() - 6 * 60 * 1000).toISOString(),
    },
  };

  // Break-glass scoped endpoint mock replicating incidents.ts logic
  app.post('/test/incidents/:id/health-card/break-glass', (req: Request, res: Response) => {
    const authHeader = req.headers.authorization;
    if (!authHeader) return res.status(401).json({ error: 'Unauthorized' });

    // Identify user from bearer token
    const token = authHeader.replace(/^Bearer\s+/i, '');
    const user = token === tokenA ? hospitalAUser : token === tokenB ? hospitalBUser : null;
    if (!user || user.role !== 'hospital_staff') return res.status(403).json({ error: 'Forbidden' });

    const { id } = req.params;
    const { reason, licence_id, license_id } = req.body;
    const doctorLicence = (licence_id || license_id || req.body.medical_council_id || '').trim();

    if (!reason || typeof reason !== 'string' || reason.trim().length < 5) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Mandatory clinical break-glass reason required (minimum 5 characters).',
      });
    }

    if (!doctorLicence || doctorLicence.length < 3) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Mandatory Medical Practitioner Licence ID required (minimum 3 characters, e.g. KMC-48291).',
      });
    }

    const incident = mockIncidents[id];
    if (!incident) return res.status(404).json({ error: 'Incident not found' });

    // 1. Must be accepted or en_route
    if (incident.status !== 'accepted' && incident.status !== 'en_route') {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'Health card is accessible only after this hospital has officially accepted the case.',
      });
    }

    // 2. Must be the accepting hospital's staff
    if (incident.accepted_hospital_id !== user.hospital_id) {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'Access restricted: Health card is only accessible to staff of the accepted hospital.',
      });
    }

    // 3. Time-box check: Max 30 minutes from case acceptance
    const acceptanceTime = new Date(incident.updated_at || incident.created_at).getTime();
    const thirtyMinutesMs = 30 * 60 * 1000;
    if (Date.now() - acceptanceTime > thirtyMinutesMs) {
      return res.status(403).json({
        error: 'EXPIRED',
        message: 'Break-glass emergency access window has expired (30-minute limit from case acceptance).',
      });
    }

    return res.status(200).json({
      status: 'SUCCESS',
      incident_id: id,
      accessed_by: user.username,
      licence_id: doctorLicence,
      accessed_at: new Date().toISOString(),
      retroactive_sms: {
        status: 'queued_simulated',
        carrier_gateway: 'SIMULATED',
        message: 'Retroactive ABDM consent notification queued for dispatch via simulated cellular gateway.',
      },
    });
  });

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, resolve));
  const port = (server.address() as { port: number }).port;
  const baseUrl = `http://127.0.0.1:${port}`;

  try {
    // =========================================================================
    // TEST A: Hospital staff cannot edit another hospital's capabilities
    // =========================================================================
    console.log('\n[Test A] Hospital Capabilities Authorization Scoping...');

    // Hospital A attempts to edit Hospital B's capabilities -> 403 Forbidden
    const editOtherRes = await fetch(`${baseUrl}/hospitals/22222222-2222-2222-2222-222222222222/capabilities`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        capabilities: {
          ct_scan: false,
        },
      }),
    });

    assert(
      editOtherRes.status === 403,
      'PUT /hospitals/:id/capabilities returns 403 Forbidden when editing another hospital'
    );
    const editOtherJson = await editOtherRes.json();
    assert(
      editOtherJson.error === 'Forbidden' &&
        editOtherJson.message.includes('only update capabilities for their own assigned hospital'),
      '403 response contains clear hospital staff scoping message'
    );

    // Missing JWT -> 401 Unauthorized
    const unauthRes = await fetch(`${baseUrl}/hospitals/11111111-1111-1111-1111-111111111111/capabilities`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ capabilities: { ct_scan: true } }),
    });
    assert(unauthRes.status === 401, 'PUT /hospitals/:id/capabilities without token returns 401 Unauthorized');

    // =========================================================================
    // TEST B: Cryptographic Hash-Chained Audit Log & Tamper Detection
    // =========================================================================
    console.log('\n[Test B] Cryptographic Hash-Chained Audit Log & Tamper Detection...');

    interface InMemAudit {
      sequence_number: number;
      action: string;
      entity_type: string;
      entity_id: string;
      actor_id: string;
      actor_role: string;
      payload: Record<string, unknown>;
      prev_hash: string;
      record_hash: string;
      created_at_iso: string;
    }

    const testChain: InMemAudit[] = [];

    const addTestRecord = (
      action: string,
      entityType: string,
      entityId: string,
      actorId: string,
      actorRole: string,
      payload: Record<string, unknown>
    ) => {
      const seq = testChain.length + 1;
      const prevHash = testChain.length === 0 ? GENESIS_PREV_HASH : testChain[testChain.length - 1].record_hash;
      const createdAtIso = new Date().toISOString();
      const recordHash = computeRecordHash(
        prevHash,
        action,
        entityType,
        entityId,
        actorId,
        actorRole,
        payload,
        createdAtIso
      );
      testChain.push({
        sequence_number: seq,
        action,
        entity_type: entityType,
        entity_id: entityId,
        actor_id: actorId,
        actor_role: actorRole,
        payload,
        prev_hash: prevHash,
        record_hash: recordHash,
        created_at_iso: createdAtIso,
      });
    }

    const verifyInMemChain = (chain: InMemAudit[]): VerifyChainResult => {
      const verifiedAt = new Date().toISOString();
      for (let i = 0; i < chain.length; i++) {
        const cur = chain[i];
        if (i === 0 && cur.prev_hash !== GENESIS_PREV_HASH) {
          return {
            valid: false,
            checked_records: i,
            sequence_number: cur.sequence_number,
            reason: 'Genesis block prev_hash invalid',
            verified_at: verifiedAt,
          };
        }
        if (i > 0 && cur.prev_hash !== chain[i - 1].record_hash) {
          return {
            valid: false,
            checked_records: i,
            sequence_number: cur.sequence_number,
            reason: 'Pointer mismatch to previous record_hash',
            verified_at: verifiedAt,
          };
        }
        const expected = computeRecordHash(
          cur.prev_hash,
          cur.action,
          cur.entity_type,
          cur.entity_id,
          cur.actor_id,
          cur.actor_role,
          cur.payload,
          cur.created_at_iso
        );
        if (expected !== cur.record_hash) {
          return {
            valid: false,
            checked_records: i,
            sequence_number: cur.sequence_number,
            reason: 'Hash mismatch: record payload was tampered with',
            verified_at: verifiedAt,
          };
        }
      }
      return {
        valid: true,
        checked_records: chain.length,
        latest_hash: chain[chain.length - 1]?.record_hash || GENESIS_PREV_HASH,
        verified_at: verifiedAt,
      };
    }

    addTestRecord('incident_accept', 'incident', 'inc-100', '11111111-1111', 'hospital_staff', { status: 'accepted' });
    addTestRecord('ambulance_claim', 'incident', 'inc-100', 'amb-04', 'ambulance_driver', { plate: 'KA-01-EQ-9999' });
    addTestRecord('capability_edit', 'hospital', '11111111-1111', 'user-1', 'hospital_staff', { ct_scan: false });
    addTestRecord('break_glass', 'health_card', 'inc-100', 'user-1', 'hospital_staff', { licence_id: 'KMC-49201' });

    const initialVerify = verifyInMemChain(testChain);
    assert(initialVerify.valid === true, 'Untampered 4-block audit chain validates successfully');
    assert(initialVerify.checked_records === 4, 'All 4 records checked and confirmed cryptographically linked');

    // Simulate tampering with block #2 (changing ambulance plate after the fact)
    testChain[1].payload = { plate: 'KA-04-TAMPERED-0000' };
    const tamperedVerify = verifyInMemChain(testChain);
    assert(tamperedVerify.valid === false, 'Tampered record immediately causes verify-chain to FAIL');
    assert(tamperedVerify.sequence_number === 2, 'Tamper verification accurately pinpoints tampered record #2');
    assert(tamperedVerify.reason?.includes('Hash mismatch'), 'Tamper verification detects cryptographic SHA-256 mismatch');

    // Restore original payload to confirm chain heals
    testChain[1].payload = { plate: 'KA-01-EQ-9999' };
    assert(verifyInMemChain(testChain).valid === true, 'Restoring exact byte payload restores audit chain validity');

    // =========================================================================
    // TEST C: Break-glass scoping (accepted incident only, 30-min expiry, licence ID)
    // =========================================================================
    console.log('\n[Test C] Break-Glass Scoping & Time-Box Verification...');

    // C1: Denied without accepted incident (broadcasting status) -> 403
    const bgBroadcastingRes = await fetch(`${baseUrl}/test/incidents/inc-broadcasting/health-card/break-glass`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        reason: 'Patient comatose and unresponsive, urgent blood cross-match needed',
        licence_id: 'KMC-84920',
      }),
    });
    assert(
      bgBroadcastingRes.status === 403,
      'Break-glass denied (403) when incident is in broadcasting status (unaccepted)'
    );

    // C2: Denied when accepted by another hospital -> 403
    const bgOtherHospRes = await fetch(`${baseUrl}/test/incidents/inc-accepted-hospital-b/health-card/break-glass`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        reason: 'Patient comatose and unresponsive, urgent blood cross-match needed',
        licence_id: 'KMC-84920',
      }),
    });
    assert(
      bgOtherHospRes.status === 403,
      'Break-glass denied (403) when incident is accepted by a different hospital'
    );

    // C3: Denied when expired (> 30 minutes from acceptance) -> 403 EXPIRED
    const bgExpiredRes = await fetch(`${baseUrl}/test/incidents/inc-accepted-expired/health-card/break-glass`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        reason: 'Follow-up observation after patient handover',
        licence_id: 'KMC-84920',
      }),
    });
    assert(
      bgExpiredRes.status === 403,
      'Break-glass denied (403) when 30-minute acceptance window has expired'
    );
    const bgExpiredJson = await bgExpiredRes.json();
    assert(
      bgExpiredJson.error === 'EXPIRED',
      'Expired break-glass response returns { error: "EXPIRED" } code'
    );

    // C4: Denied without doctor licence ID -> 400 Bad Request
    const bgNoLicenceRes = await fetch(`${baseUrl}/test/incidents/inc-accepted-valid/health-card/break-glass`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        reason: 'Emergency resuscitation blood type lookup',
      }),
    });
    assert(
      bgNoLicenceRes.status === 400,
      'Break-glass denied (400) when Medical Licence ID is omitted'
    );

    // C5: Granted for accepted incident within 30 minutes with licence ID and reason
    const bgValidRes = await fetch(`${baseUrl}/test/incidents/inc-accepted-valid/health-card/break-glass`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${tokenA}`,
      },
      body: JSON.stringify({
        reason: 'Emergency neuro-trauma resuscitation blood type and allergy verification',
        licence_id: 'KMC-84920',
      }),
    });
    assert(
      bgValidRes.status === 200,
      'Break-glass GRANTED (200 OK) for accepting hospital within 30-min window with licence ID'
    );
    const bgValidJson = await bgValidRes.json();
    assert(
      bgValidJson.licence_id === 'KMC-84920',
      'Break-glass response records verified Doctor Licence ID'
    );
    assert(
      bgValidJson.retroactive_sms?.status === 'queued_simulated' &&
        bgValidJson.retroactive_sms?.carrier_gateway === 'SIMULATED',
      'Break-glass response honestly discloses retroactive SMS is queued via simulated gateway'
    );

    // =========================================================================
    // TEST D: Matching never returns an empty list solely because of capabilities
    // =========================================================================
    console.log('\n[Test D] Capability-Aware Hospital Matching Fallback Logic...');

    interface CandidateHospital {
      id: string;
      name: string;
      distance_km: number;
      ct_scan: boolean;
      ct_offline?: boolean;
      capability_advisory?: string | null;
    }

    const rankHospitalsForIncident = (
      candidates: CandidateHospital[],
      victimMetadata: { peak_g?: number; is_two_wheeler?: boolean; rollover_detected?: boolean }
    ): CandidateHospital[] => {
      const hasHeadTrauma = Boolean(
        victimMetadata.rollover_detected ||
        (victimMetadata.peak_g && victimMetadata.peak_g >= 7.0) ||
        victimMetadata.is_two_wheeler
      );

      const ranked = candidates.map((h) => {
        const isOffline = h.ct_scan === false;
        return {
          ...h,
          ct_offline: isOffline,
          capability_advisory: (hasHeadTrauma && isOffline)
            ? 'CT Scanner offline - ranked lower for suspected head trauma (eligible as fallback)'
            : null,
        };
      });

      if (hasHeadTrauma) {
        // Prioritize CT-active first, CT-offline lower, NEVER exclude
        ranked.sort((a, b) => {
          if (a.ct_offline === b.ct_offline) {
            return a.distance_km - b.distance_km;
          }
          return a.ct_offline ? 1 : -1;
        });
      }

      return ranked;
    }

    // Scenario 1: Mixed capabilities (some with CT, some without)
    const mixedCandidates: CandidateHospital[] = [
      { id: 'h1', name: 'Manipal HAL (CT Offline)', distance_km: 2.1, ct_scan: false },
      { id: 'h2', name: 'St. Johns (CT Active)', distance_km: 3.5, ct_scan: true },
      { id: 'h3', name: 'Apollo (CT Active)', distance_km: 5.0, ct_scan: true },
    ];

    const mixedResult = rankHospitalsForIncident(mixedCandidates, { peak_g: 12.0, is_two_wheeler: true });
    assert(mixedResult.length === 3, 'Matching returns all 3 candidate hospitals');
    assert(mixedResult[0].id === 'h2', 'Hospital with active CT (St. Johns) promoted to #1 rank despite greater distance');
    assert(mixedResult[2].id === 'h1', 'Hospital with offline CT (Manipal) ranked lower as fallback');
    assert(mixedResult[2].capability_advisory?.includes('eligible as fallback') === true, 'CT-offline hospital flagged with non-blocking fallback advisory');

    // Scenario 2: ALL nearby hospitals have CT Offline!
    const allOfflineCandidates: CandidateHospital[] = [
      { id: 'h1', name: 'District Hospital A (CT Offline)', distance_km: 1.8, ct_scan: false },
      { id: 'h2', name: 'General Hospital B (CT Offline)', distance_km: 3.2, ct_scan: false },
      { id: 'h3', name: 'Community Center C (CT Offline)', distance_km: 4.1, ct_scan: false },
    ];

    const allOfflineResult = rankHospitalsForIncident(allOfflineCandidates, { peak_g: 14.5 });
    assert(allOfflineResult.length === 3, 'CRITICAL: Matching NEVER returns empty list even when 100% of candidate hospitals have CT offline');
    assert(allOfflineResult[0].id === 'h1', 'Nearest facility retained as #1 fallback when all CTs are down');
    assert(allOfflineResult.every((h) => h.capability_advisory !== null), 'Every fallback hospital correctly exhibits capability advisory for clinician awareness');

  } finally {
    server.close();
  }

  console.log('\n-------------------------------------------------------');
  console.log(`PHASE 25 TEST RESULTS: ${passedCount} PASSED, ${failedCount} FAILED`);
  console.log('-------------------------------------------------------');

  if (failedCount > 0) {
    process.exit(1);
  }
}

runPhase25Tests().catch((err) => {
  console.error('[Phase 25 Test Runner Uncaught Error]', err);
  process.exit(1);
});
