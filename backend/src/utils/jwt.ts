import jwt from 'jsonwebtoken';
import { AuthUser } from '../types';

const JWT_SECRET = process.env.JWT_SECRET || 'rakshak-ai-super-secret-jwt-key-2026';
const JWT_REFRESH_SECRET =
  process.env.JWT_REFRESH_SECRET || 'rakshak-ai-refresh-secret-jwt-key-2026-v1';

// Phase 26 Hardened Token Lifespans: 15 minutes access token, 7 days refresh token
const JWT_ACCESS_EXPIRES_IN = '15m';
const JWT_REFRESH_EXPIRES_IN = '7d';

export function signToken(payload: AuthUser): string {
  return jwt.sign(
    {
      id: payload.id,
      username: payload.username,
      role: payload.role,
      hospital_id: payload.hospital_id,
      token_type: 'access',
    },
    JWT_SECRET,
    { expiresIn: JWT_ACCESS_EXPIRES_IN }
  );
}

export function signRefreshToken(payload: AuthUser): string {
  return jwt.sign(
    {
      id: payload.id,
      username: payload.username,
      role: payload.role,
      hospital_id: payload.hospital_id,
      token_type: 'refresh',
    },
    JWT_REFRESH_SECRET,
    { expiresIn: JWT_REFRESH_EXPIRES_IN }
  );
}

export function verifyToken(token: string): AuthUser | null {
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as {
      id: string;
      username: string;
      role: AuthUser['role'];
      hospital_id?: string | null;
      token_type?: string;
    };

    if (decoded.token_type && decoded.token_type !== 'access') {
      return null;
    }

    return {
      id: decoded.id,
      username: decoded.username,
      role: decoded.role,
      hospital_id: decoded.hospital_id ?? null,
    };
  } catch {
    return null;
  }
}

export function verifyRefreshToken(token: string): AuthUser | null {
  try {
    const decoded = jwt.verify(token, JWT_REFRESH_SECRET) as {
      id: string;
      username: string;
      role: AuthUser['role'];
      hospital_id?: string | null;
      token_type?: string;
    };

    if (decoded.token_type && decoded.token_type !== 'refresh') {
      return null;
    }

    return {
      id: decoded.id,
      username: decoded.username,
      role: decoded.role,
      hospital_id: decoded.hospital_id ?? null,
    };
  } catch {
    return null;
  }
}
