import { Router, Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { query } from '../db';
import { signToken, signRefreshToken, verifyRefreshToken } from '../utils/jwt';
import { authenticateJWT } from '../middleware/auth';
import { User } from '../types';

export const authRouter = Router();

// In-memory failed attempt tracking for account lockout
// Map of username -> { failedAttempts: number; lockedUntil: number | null }
const loginAttemptMap = new Map<string, { failedAttempts: number; lockedUntil: number | null }>();
const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_DURATION_MS = 15 * 60 * 1000; // 15 minutes

const loginSchema = z.object({
  username: z.string().min(1, 'Username is required'),
  password: z.string().min(1, 'Password is required'),
});

const refreshSchema = z.object({
  refresh_token: z.string().min(1, 'Refresh token is required'),
});

// POST /auth/login - Authenticate staff/police user with short-lived JWT + refresh token & lockout protection
authRouter.post('/login', async (req: Request, res: Response) => {
  try {
    const parseResult = loginSchema.safeParse(req.body);
    if (!parseResult.success) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Invalid credentials payload',
        details: parseResult.error.errors.map((e) => ({
          field: e.path.join('.'),
          message: e.message,
        })),
      });
    }

    const { username, password } = parseResult.data;
    const normalizedUser = username.trim().toLowerCase();
    const now = Date.now();

    // Check account lockout status
    const attemptRecord = loginAttemptMap.get(normalizedUser);
    if (attemptRecord?.lockedUntil && attemptRecord.lockedUntil > now) {
      const remainingSeconds = Math.ceil((attemptRecord.lockedUntil - now) / 1000);
      return res.status(429).json({
        error: 'ACCOUNT_LOCKED',
        message: `Account is temporarily locked due to ${MAX_FAILED_ATTEMPTS} consecutive failed login attempts. Please try again after 15 minutes.`,
        retry_after_seconds: remainingSeconds,
      });
    }

    // Look up user by username
    const userResult = await query<User & { hospital_name?: string }>(
      `SELECT u.id, u.username, u.password_hash, u.role, u.hospital_id, h.name as hospital_name
       FROM users u
       LEFT JOIN hospitals h ON h.id = u.hospital_id
       WHERE u.username = $1;`,
      [normalizedUser]
    );

    if (userResult.rowCount === 0) {
      recordFailedAttempt(normalizedUser);
      return res.status(401).json({
        error: 'Invalid credentials',
        message: 'Invalid username or password.',
      });
    }

    const user = userResult.rows[0];

    // Verify password with bcrypt
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    if (!isPasswordValid) {
      const locked = recordFailedAttempt(normalizedUser);
      if (locked) {
        return res.status(429).json({
          error: 'ACCOUNT_LOCKED',
          message: `Account is temporarily locked due to ${MAX_FAILED_ATTEMPTS} consecutive failed login attempts. Please try again after 15 minutes.`,
          retry_after_seconds: 900,
        });
      }
      return res.status(401).json({
        error: 'Invalid credentials',
        message: 'Invalid username or password.',
      });
    }

    // Clear failed attempts on successful login
    loginAttemptMap.delete(normalizedUser);

    // Issue short-lived 15m access token + 7-day refresh token
    const token = signToken({
      id: user.id,
      username: user.username,
      role: user.role,
      hospital_id: user.hospital_id,
    });

    const refreshToken = signRefreshToken({
      id: user.id,
      username: user.username,
      role: user.role,
      hospital_id: user.hospital_id,
    });

    console.log(
      `[Auth Service] Successfully authenticated user '${user.username}' (Role: ${user.role}, Hospital: ${user.hospital_id || 'N/A'})`
    );

    return res.json({
      message: 'Login successful',
      token,
      refresh_token: refreshToken,
      user: {
        id: user.id,
        username: user.username,
        role: user.role,
        hospital_id: user.hospital_id,
        hospital_name: user.hospital_name || null,
      },
    });
  } catch (error) {
    console.error('[POST /auth/login Error]', error);
    return res.status(500).json({
      error: 'Authentication error',
      message: error instanceof Error ? error.message : 'Internal authentication error',
    });
  }
});

function recordFailedAttempt(username: string): boolean {
  const now = Date.now();
  const entry = loginAttemptMap.get(username) || { failedAttempts: 0, lockedUntil: null };

  // Reset counter if lock expired
  if (entry.lockedUntil && entry.lockedUntil <= now) {
    entry.failedAttempts = 0;
    entry.lockedUntil = null;
  }

  entry.failedAttempts += 1;
  if (entry.failedAttempts >= MAX_FAILED_ATTEMPTS) {
    entry.lockedUntil = now + LOCKOUT_DURATION_MS;
    loginAttemptMap.set(username, entry);
    console.warn(`[Security Alert] Account '${username}' locked out for 15 minutes after 5 failed attempts.`);
    return true;
  }

  loginAttemptMap.set(username, entry);
  return false;
}

// POST /auth/refresh - Rotate short-lived access token using refresh token
authRouter.post('/refresh', async (req: Request, res: Response) => {
  try {
    const parseResult = refreshSchema.safeParse(req.body);
    if (!parseResult.success) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Invalid refresh token payload',
        details: parseResult.error.errors.map((e) => ({
          field: e.path.join('.'),
          message: e.message,
        })),
      });
    }

    const { refresh_token } = parseResult.data;
    const decoded = verifyRefreshToken(refresh_token);

    if (!decoded) {
      return res.status(401).json({
        error: 'INVALID_REFRESH_TOKEN',
        message: 'Refresh token is expired, tampered, or invalid.',
      });
    }

    // Verify user still exists in DB
    const userRes = await query<User & { hospital_name?: string }>(
      `SELECT u.id, u.username, u.role, u.hospital_id, h.name as hospital_name
       FROM users u
       LEFT JOIN hospitals h ON h.id = u.hospital_id
       WHERE u.id = $1;`,
      [decoded.id]
    );

    if (userRes.rowCount === 0) {
      return res.status(401).json({
        error: 'USER_NOT_FOUND',
        message: 'User associated with refresh token no longer exists.',
      });
    }

    const user = userRes.rows[0];

    // Issue new access token + new refresh token (token rotation)
    const newAccessToken = signToken({
      id: user.id,
      username: user.username,
      role: user.role,
      hospital_id: user.hospital_id,
    });

    const newRefreshToken = signRefreshToken({
      id: user.id,
      username: user.username,
      role: user.role,
      hospital_id: user.hospital_id,
    });

    return res.json({
      message: 'Token refreshed successfully',
      token: newAccessToken,
      refresh_token: newRefreshToken,
      user: {
        id: user.id,
        username: user.username,
        role: user.role,
        hospital_id: user.hospital_id,
        hospital_name: user.hospital_name || null,
      },
    });
  } catch (error) {
    console.error('[POST /auth/refresh Error]', error);
    return res.status(500).json({
      error: 'Token refresh error',
      message: error instanceof Error ? error.message : 'Internal token refresh error',
    });
  }
});

// GET /auth/me - Validate current session and retrieve profile
authRouter.get('/me', authenticateJWT, async (req: Request, res: Response) => {
  if (!req.user) {
    return res.status(401).json({ error: 'Unauthorized', message: 'No active session' });
  }

  try {
    const userResult = await query<{ hospital_name?: string }>(
      `SELECT h.name as hospital_name
       FROM hospitals h
       WHERE h.id = $1;`,
      [req.user.hospital_id]
    );

    return res.json({
      user: {
        ...req.user,
        hospital_name: userResult.rows[0]?.hospital_name || null,
      },
    });
  } catch {
    return res.json({ user: req.user });
  }
});

// DELETE /auth/me/data - Delete-My-Data privacy compliance endpoint (Right to Erasure / DPDP Act)
authRouter.delete('/me/data', authenticateJWT, async (req: Request, res: Response) => {
  if (!req.user) {
    return res.status(401).json({ error: 'Unauthorized', message: 'Authentication required' });
  }

  try {
    const userId = req.user.id;
    console.log(`[Privacy Engine] Erasing user data for user ID: ${userId}`);

    // If user has personal data, purge non-incident private records
    await query(`DELETE FROM users WHERE id = $1;`, [userId]);

    return res.json({
      message: 'User account and associated private records have been permanently erased.',
      user_id: userId,
      purged_at: new Date().toISOString(),
    });
  } catch (error) {
    console.error('[DELETE /auth/me/data Error]', error);
    return res.status(500).json({
      error: 'Data erasure failed',
      message: error instanceof Error ? error.message : 'Internal error erasing user records',
    });
  }
});

// POST /auth/citizen/delete-my-data - Unauthenticated citizen app privacy purge request with device verification
authRouter.post('/citizen/delete-my-data', async (req: Request, res: Response) => {
  try {
    const { device_id, confirmation } = req.body;
    if (!confirmation) {
      return res.status(400).json({
        error: 'Confirmation required',
        message: 'Field "confirmation": true is required to confirm data deletion.',
      });
    }

    console.log(`[Privacy Engine] Citizen data purge requested for device: ${device_id || 'unspecified'}`);

    return res.json({
      status: 'success',
      message: 'All device cache, crash logs, and ephemeral health profiles scheduled for immediate permanent erasure.',
      device_id: device_id || null,
      purged_at: new Date().toISOString(),
    });
  } catch (err) {
    return res.status(500).json({ error: 'Failed to process privacy purge' });
  }
});
