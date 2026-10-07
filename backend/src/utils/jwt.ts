import jwt from 'jsonwebtoken';
import { AuthUser } from '../types';

const JWT_SECRET = process.env.JWT_SECRET || 'rakshak-ai-super-secret-jwt-key-2026';
const JWT_EXPIRES_IN = '8h'; // 8-hour expiry long enough for full demo & judging sessions

export function signToken(payload: AuthUser): string {
  return jwt.sign(
    {
      id: payload.id,
      username: payload.username,
      role: payload.role,
      hospital_id: payload.hospital_id,
    },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );
}

export function verifyToken(token: string): AuthUser | null {
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as {
      id: string;
      username: string;
      role: AuthUser['role'];
      hospital_id?: string | null;
    };

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
