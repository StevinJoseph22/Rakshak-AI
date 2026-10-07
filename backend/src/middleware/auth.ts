import { Request, Response, NextFunction } from 'express';
import { verifyToken } from '../utils/jwt';
import { UserRole } from '../types';

/**
 * Extracts and verifies the Bearer JWT token from the Authorization header.
 * Attaches decoded AuthUser to req.user.
 */
export function authenticateJWT(req: Request, res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({
      error: 'Unauthorized',
      message: 'Authentication token is required. Please log in.',
    });
    return;
  }

  const token = authHeader.substring(7).trim();
  const user = verifyToken(token);
  if (!user) {
    res.status(401).json({
      error: 'Unauthorized',
      message: 'Invalid or expired session token. Please log in again.',
    });
    return;
  }
  req.user = user;
  next();
}

/**
 * Optional authentication: decodes token if provided, but does not block if omitted.
 * Useful for mobile telemetry / device UUID endpoints that support both token and anonymous fallback.
 */
export function optionalAuth(req: Request, _res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.substring(7).trim();
    const user = verifyToken(token);
    if (user) {
      req.user = user;
    }
  }
  next();
}

/**
 * Enforces Role-Based Access Control (RBAC).
 * Caller must possess one of the allowed roles.
 */
export function requireRole(...roles: UserRole[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user) {
      res.status(401).json({
        error: 'Unauthorized',
        message: 'Authentication required.',
      });
      return;
    }

    if (!roles.includes(req.user.role)) {
      res.status(403).json({
        error: 'Forbidden',
        message: `Role '${req.user.role}' is not permitted to perform this action. Required: ${roles.join(', ')}.`,
      });
      return;
    }

    next();
  };
}

/**
 * Helper to verify that hospital_staff is only acting on behalf of their assigned hospital.
 * Returns true if authorized, or false if forbidden.
 */
export function isAuthorizedForHospital(req: Request, targetHospitalId: string): boolean {
  if (!req.user) return false;
  // If hospital_staff, strict matching to their assigned hospital_id
  if (req.user.role === 'hospital_staff') {
    return req.user.hospital_id === targetHospitalId;
  }
  return false;
}
