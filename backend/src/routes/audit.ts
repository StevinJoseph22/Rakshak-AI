import { Router, Request, Response } from 'express';
import { verifyAuditChain } from '../services/auditService';
import { query } from '../db';

export const auditRouter = Router();

/**
 * GET /api/audit/verify-chain
 * Validates the entire cryptographic SHA-256 hash chain from genesis block to current head.
 * Discloses whether audit logs are 100% intact or whether tampering was detected.
 */
auditRouter.get('/verify-chain', async (_req: Request, res: Response) => {
  try {
    const result = await verifyAuditChain();
    return res.status(result.valid ? 200 : 409).json(result);
  } catch (error) {
    console.error('[GET /audit/verify-chain Error]', error);
    return res.status(500).json({
      valid: false,
      error: 'Failed to verify audit chain',
      message: error instanceof Error ? error.message : 'Unknown audit verification error',
      verified_at: new Date().toISOString(),
    });
  }
});

/**
 * GET /api/audit/records
 * Returns recent audit log records for the police tactical dashboard & oversight view.
 */
auditRouter.get('/records', async (req: Request, res: Response) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 25, 100);
    const result = await query(
      `SELECT id, sequence_number, action, entity_type, entity_id, actor_id, actor_role,
              prev_hash, record_hash, created_at_iso, created_at
       FROM audit_log
       ORDER BY sequence_number DESC
       LIMIT $1`,
      [limit]
    );

    return res.status(200).json({
      count: result.rowCount,
      records: result.rows,
    });
  } catch (error) {
    console.error('[GET /audit/records Error]', error);
    return res.status(500).json({
      error: 'Failed to retrieve audit records',
    });
  }
});
