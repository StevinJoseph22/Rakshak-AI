import { Router, Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { z } from 'zod';
import { query } from '../db';
import { signToken } from '../utils/jwt';
import { authenticateJWT } from '../middleware/auth';
import { User } from '../types';

export const authRouter = Router();

const loginSchema = z.object({
  username: z.string().min(1, 'Username is required'),
  password: z.string().min(1, 'Password is required'),
});

// POST /auth/login - Authenticate staff/police user and issue 8-hour JWT
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

    // Look up user by username
    const userResult = await query<User & { hospital_name?: string }>(
      `SELECT u.id, u.username, u.password_hash, u.role, u.hospital_id, h.name as hospital_name
       FROM users u
       LEFT JOIN hospitals h ON h.id = u.hospital_id
       WHERE u.username = $1;`,
      [username.trim().toLowerCase()]
    );

    if (userResult.rowCount === 0) {
      return res.status(401).json({
        error: 'Invalid credentials',
        message: 'Invalid username or password.',
      });
    }

    const user = userResult.rows[0];

    // Verify password with bcrypt
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    if (!isPasswordValid) {
      return res.status(401).json({
        error: 'Invalid credentials',
        message: 'Invalid username or password.',
      });
    }

    // Sign 8-hour session token
    const token = signToken({
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
