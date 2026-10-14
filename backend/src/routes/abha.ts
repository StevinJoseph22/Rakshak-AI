import { Router, Request, Response } from 'express';
import { getAbdmClient, getAbdmMode } from '../services/abdm';

export const abhaRouter = Router();

// In-memory rate limiting map: identifier -> timestamps array
const rateLimitMap = new Map<string, number[]>();

function checkRateLimit(key: string, maxAttempts = 3, windowMs = 5 * 60 * 1000): boolean {
  const now = Date.now();
  const timestamps = (rateLimitMap.get(key) || []).filter((t) => now - t < windowMs);
  if (timestamps.length >= maxAttempts) {
    return false; // Exceeded
  }
  timestamps.push(now);
  rateLimitMap.set(key, timestamps);
  return true; // Allowed
}

// GET /abha/status - Return current ABDM operational mode (SANDBOX or MOCK)
abhaRouter.get('/status', (_req: Request, res: Response) => {
  const mode = getAbdmMode().toUpperCase();
  res.status(200).json({
    mode,
    timestamp: new Date().toISOString(),
  });
});

// POST /abha/verify/start - Initiate ABHA verification via OTP
abhaRouter.post('/verify/start', async (req: Request, res: Response) => {
  try {
    const { abha_address } = req.body;
    if (!abha_address || typeof abha_address !== 'string' || abha_address.trim().length === 0) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Valid abha_address is required',
      });
    }

    const cleanAddress = abha_address.trim().toLowerCase();
    const clientIp = req.ip || 'anonymous';
    const rateLimitKey = `start_${clientIp}_${cleanAddress}`;

    if (!checkRateLimit(rateLimitKey, 5, 5 * 60 * 1000)) {
      return res.status(429).json({
        status: 'RATE_LIMITED',
        error: 'Too many OTP requests',
        message: 'Too many OTP requests. Please wait 5 minutes before trying again.',
      });
    }

    const client = getAbdmClient();
    const result = await client.startVerification(cleanAddress);

    if (result.status === 'NOT_FOUND') {
      return res.status(404).json({
        status: 'NOT_FOUND',
        message: result.message,
      });
    }

    if (result.status === 'ABDM_UNAVAILABLE') {
      return res.status(503).json({
        status: 'ABDM_UNAVAILABLE',
        message: result.message,
      });
    }

    return res.status(200).json({
      status: 'OTP_SENT',
      txn_id: result.txnId,
      message: result.message,
      mode: getAbdmMode().toUpperCase(),
    });
  } catch (err: unknown) {
    console.error('[POST /abha/verify/start Error]', (err as Error).message);
    return res.status(500).json({
      status: 'ABDM_UNAVAILABLE',
      error: 'Internal server error during verification start',
    });
  }
});

// POST /abha/verify/confirm - Verify OTP & acquire ephemeral session token
abhaRouter.post('/verify/confirm', async (req: Request, res: Response) => {
  try {
    const { txn_id, otp } = req.body;
    if (!txn_id || !otp || typeof txn_id !== 'string' || typeof otp !== 'string') {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'txn_id and otp are required',
      });
    }

    const clientIp = req.ip || 'anonymous';
    const rateLimitKey = `confirm_${clientIp}_${txn_id}`;

    if (!checkRateLimit(rateLimitKey, 5, 5 * 60 * 1000)) {
      return res.status(429).json({
        status: 'RATE_LIMITED',
        error: 'Too many OTP verification attempts',
        message: 'Too many invalid OTP attempts. Please wait 5 minutes before retrying.',
      });
    }

    const client = getAbdmClient();
    // Intentionally NEVER log the otp variable!
    const result = await client.confirmVerification(txn_id, otp);

    if (result.status === 'OTP_FAILED') {
      return res.status(400).json({
        status: 'OTP_FAILED',
        message: result.message,
      });
    }

    if (result.status === 'ABDM_UNAVAILABLE') {
      return res.status(503).json({
        status: 'ABDM_UNAVAILABLE',
        message: result.message,
      });
    }

    return res.status(200).json({
      status: 'VERIFIED',
      session_token: result.sessionToken,
      profile: result.profile,
      records: result.records,
      message: result.message,
      mode: getAbdmMode().toUpperCase(),
    });
  } catch (err: unknown) {
    console.error('[POST /abha/verify/confirm Error]', (err as Error).message);
    return res.status(500).json({
      status: 'ABDM_UNAVAILABLE',
      error: 'Internal server error during OTP confirmation',
    });
  }
});

// Helper to extract session token from Authorization or X-Abha-Session header
function extractSessionToken(req: Request): string | null {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7).trim();
  }
  const customHeader = req.headers['x-abha-session'];
  if (typeof customHeader === 'string' && customHeader.trim()) {
    return customHeader.trim();
  }
  return null;
}

// GET /abha/profile - Retrieve profile for active verified session
abhaRouter.get('/profile', async (req: Request, res: Response) => {
  try {
    const sessionToken = extractSessionToken(req);
    if (!sessionToken) {
      return res.status(401).json({
        status: 'NOT_LINKED',
        error: 'Session token required',
        message: 'No active ABHA session token provided.',
      });
    }

    const client = getAbdmClient();
    const result = await client.getProfile(sessionToken);

    if (result.status === 'NOT_LINKED') {
      return res.status(404).json({
        status: 'NOT_LINKED',
        message: result.message || 'No linked ABHA profile found for this session.',
      });
    }

    if (result.status === 'ABDM_UNAVAILABLE') {
      return res.status(503).json({
        status: 'ABDM_UNAVAILABLE',
        message: result.message || 'ABDM service currently unavailable.',
      });
    }

    return res.status(200).json({
      status: 'VERIFIED',
      profile: result.profile,
      records: result.records,
      mode: getAbdmMode().toUpperCase(),
    });
  } catch (err: unknown) {
    console.error('[GET /abha/profile Error]', (err as Error).message);
    return res.status(500).json({
      status: 'ABDM_UNAVAILABLE',
      error: 'Internal server error retrieving ABHA profile',
    });
  }
});

// DELETE /abha/link - Remove linking and purge session
abhaRouter.delete('/link', async (req: Request, res: Response) => {
  try {
    const sessionToken = extractSessionToken(req);
    if (sessionToken) {
      const client = getAbdmClient();
      await client.unlink(sessionToken);
    }

    return res.status(200).json({
      status: 'NOT_LINKED',
      message: 'ABHA linking successfully removed and server session purged',
    });
  } catch (err: unknown) {
    console.error('[DELETE /abha/link Error]', (err as Error).message);
    return res.status(500).json({
      error: 'Internal server error unlinking ABHA',
    });
  }
});
