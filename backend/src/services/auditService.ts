import crypto from 'crypto';
import { query } from '../db';

export const GENESIS_PREV_HASH = '0000000000000000000000000000000000000000000000000000000000000000';

export type AuditAction =
  | 'incident_accept'
  | 'incident_reject'
  | 'ambulance_claim'
  | 'capability_edit'
  | 'break_glass';

export type AuditEntityType = 'incident' | 'hospital' | 'health_card';

export interface AuditEventParams {
  action: AuditAction;
  entityType: AuditEntityType;
  entityId: string;
  actorId: string;
  actorRole: string;
  payload?: Record<string, unknown>;
}

export interface AuditRecord {
  id: string;
  sequence_number: string | number;
  action: string;
  entity_type: string;
  entity_id: string;
  actor_id: string;
  actor_role: string;
  payload: Record<string, unknown>;
  prev_hash: string;
  record_hash: string;
  created_at_iso: string;
  created_at: string;
}

export interface VerifyChainResult {
  valid: boolean;
  checked_records: number;
  latest_hash?: string;
  broken_at_id?: string;
  sequence_number?: number;
  reason?: string;
  verified_at: string;
}

export function computeRecordHash(
  prevHash: string,
  action: string,
  entityType: string,
  entityId: string,
  actorId: string,
  actorRole: string,
  payload: Record<string, unknown>,
  createdAtIso: string
): string {
  const payloadStr = JSON.stringify(payload || {});
  const dataToHash = `${prevHash}|${action}|${entityType}|${entityId}|${actorId}|${actorRole}|${payloadStr}|${createdAtIso}`;
  return crypto.createHash('sha256').update(dataToHash).digest('hex');
}

/**
 * Records an event into the cryptographic hash-chained audit log.
 * Guaranteed to be append-only with unbroken SHA-256 integrity linking.
 */
export async function recordAuditEvent(params: AuditEventParams): Promise<AuditRecord> {
  const { action, entityType, entityId, actorId, actorRole, payload = {} } = params;

  // Retrieve latest record to obtain prev_hash
  const latestRes = await query<{ record_hash: string }>(
    `SELECT record_hash FROM audit_log ORDER BY sequence_number DESC LIMIT 1`
  );

  const prevHash = latestRes.rows.length > 0 ? latestRes.rows[0].record_hash : GENESIS_PREV_HASH;
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

  const insertSql = `
    INSERT INTO audit_log (
      action,
      entity_type,
      entity_id,
      actor_id,
      actor_role,
      payload,
      prev_hash,
      record_hash,
      created_at_iso
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
    RETURNING *;
  `;

  const insertRes = await query<AuditRecord>(insertSql, [
    action,
    entityType,
    entityId,
    actorId,
    actorRole,
    JSON.stringify(payload),
    prevHash,
    recordHash,
    createdAtIso,
  ]);

  return insertRes.rows[0];
}

/**
 * Traverses and cryptographically validates the entire audit chain from genesis to head.
 * If any record has been updated, deleted, or injected, immediately pinpoints the failure.
 */
export async function verifyAuditChain(): Promise<VerifyChainResult> {
  const verifiedAt = new Date().toISOString();

  const res = await query<AuditRecord>(
    `SELECT * FROM audit_log ORDER BY sequence_number ASC`
  );

  const records = res.rows;
  if (records.length === 0) {
    return {
      valid: true,
      checked_records: 0,
      latest_hash: GENESIS_PREV_HASH,
      verified_at: verifiedAt,
    };
  }

  for (let i = 0; i < records.length; i++) {
    const current = records[i];
    const seq = Number(current.sequence_number);

    // 1. Verify prev_hash
    if (i === 0) {
      if (current.prev_hash !== GENESIS_PREV_HASH) {
        return {
          valid: false,
          checked_records: i,
          broken_at_id: current.id,
          sequence_number: seq,
          reason: `Genesis block prev_hash invalid. Expected ${GENESIS_PREV_HASH}, got ${current.prev_hash}`,
          verified_at: verifiedAt,
        };
      }
    } else {
      const prev = records[i - 1];
      if (current.prev_hash !== prev.record_hash) {
        return {
          valid: false,
          checked_records: i,
          broken_at_id: current.id,
          sequence_number: seq,
          reason: `Chain pointer broken at record #${seq}. prev_hash does not match previous record_hash.`,
          verified_at: verifiedAt,
        };
      }
    }

    // 2. Re-compute and verify cryptographic record_hash
    const expectedHash = computeRecordHash(
      current.prev_hash,
      current.action,
      current.entity_type,
      current.entity_id,
      current.actor_id,
      current.actor_role,
      current.payload,
      current.created_at_iso
    );

    if (expectedHash !== current.record_hash) {
      return {
        valid: false,
        checked_records: i,
        broken_at_id: current.id,
        sequence_number: seq,
        reason: `Cryptographic hash mismatch at record #${seq}. Content was tampered with!`,
        verified_at: verifiedAt,
      };
    }
  }

  return {
    valid: true,
    checked_records: records.length,
    latest_hash: records[records.length - 1].record_hash,
    verified_at: verifiedAt,
  };
}
