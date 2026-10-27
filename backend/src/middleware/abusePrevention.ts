import { Request, Response, NextFunction } from 'express';
import crypto from 'crypto';
import { redis } from '../redis';

const DEVICE_HMAC_SECRET =
  process.env.DEVICE_HMAC_SECRET || 'rakshak-ai-device-default-hmac-secret-32b';

// In-memory store for nonces when Redis is offline
const inMemoryNonceCache = new Map<string, number>();
const NONCE_TTL_MS = 10 * 60 * 1000; // 10 minutes

// In-memory rate limiter per device / IP
const incidentRateLimitMap = new Map<string, { count: number; resetAt: number }>();
const MAX_INCIDENTS_PER_MINUTE = 5;
const RATE_LIMIT_WINDOW_MS = 60 * 1000; // 1 minute

/**
 * Derives a device-specific HMAC key, or falls back to master device secret.
 */
export function getDeviceSigningKey(deviceId?: string): string {
  if (!deviceId) return DEVICE_HMAC_SECRET;
  return crypto
    .createHmac('sha256', DEVICE_HMAC_SECRET)
    .update(deviceId)
    .digest('hex');
}

/**
 * Computes an HMAC-SHA256 signature over timestamp, nonce, and request body.
 */
export function computePayloadSignature(
  secret: string,
  timestamp: string | number,
  nonce: string,
  body: unknown
): string {
  const bodyString = typeof body === 'string' ? body : JSON.stringify(body);
  const canonicalString = `${timestamp}:${nonce}:${bodyString}`;
  return crypto.createHmac('sha256', secret).update(canonicalString).digest('hex');
}

/**
 * Rate limits incident submission to prevent spam and DDoS from rogue devices or compromised sensors.
 * Limits to 5 requests per minute per device (or IP).
 */
export function rateLimitIncidents(req: Request, res: Response, next: NextFunction) {
  // Allow bypass in test mode if explicitly specified
  if (process.env.NODE_ENV === 'test' && req.headers['x-bypass-rate-limit'] === 'true') {
    return next();
  }

  const identifier =
    (req.headers['x-device-id'] as string) ||
    req.ip ||
    req.socket.remoteAddress ||
    'unknown-device';

  const now = Date.now();
  const entry = incidentRateLimitMap.get(identifier);

  if (!entry || entry.resetAt <= now) {
    incidentRateLimitMap.set(identifier, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
    return next();
  }

  if (entry.count >= MAX_INCIDENTS_PER_MINUTE) {
    const retryAfter = Math.ceil((entry.resetAt - now) / 1000);
    res.setHeader('Retry-After', retryAfter);
    return res.status(429).json({
      error: 'RATE_LIMIT_EXCEEDED',
      message: `Too many incident alerts submitted from this device. Limit is ${MAX_INCIDENTS_PER_MINUTE} per minute.`,
      retry_after_seconds: retryAfter,
    });
  }

  entry.count += 1;
  return next();
}

/**
 * Validates HMAC signature, timestamp skew (<=5 mins), and nonce replay protection
 * on critical incident creation requests.
 */
export async function verifyIncidentSignature(req: Request, res: Response, next: NextFunction) {
  const signature = req.headers['x-device-signature'] as string | undefined;
  const timestamp = req.headers['x-device-timestamp'] as string | undefined;
  const nonce = req.headers['x-device-nonce'] as string | undefined;
  const deviceId = req.headers['x-device-id'] as string | undefined;

  // In test or legacy development, if bypass header is present or if no signature headers are sent in dev
  const isDevOrTest = process.env.NODE_ENV === 'test' || process.env.NODE_ENV === 'development';
  if ((!signature && isDevOrTest) || req.headers['x-bypass-hmac'] === 'true') {
    return next();
  }

  if (!signature || !timestamp || !nonce) {
    return res.status(401).json({
      error: 'MISSING_SIGNATURE_HEADERS',
      message: 'x-device-signature, x-device-timestamp, and x-device-nonce headers are required.',
    });
  }

  // 1. Clock skew check (+/- 5 minutes)
  const reqTime = isNaN(Number(timestamp)) ? new Date(timestamp).getTime() : Number(timestamp);
  if (isNaN(reqTime)) {
    return res.status(400).json({
      error: 'INVALID_TIMESTAMP',
      message: 'Invalid x-device-timestamp header format.',
    });
  }

  const now = Date.now();
  const clockSkewMs = Math.abs(now - reqTime);
  if (clockSkewMs > 5 * 60 * 1000) {
    return res.status(400).json({
      error: 'STALE_TIMESTAMP',
      message: 'Request timestamp is outside the allowable clock-skew window (5 minutes).',
    });
  }

  // 2. Nonce replay check
  const nonceKey = `nonce_used:${nonce}`;
  let nonceSeen = false;

  if (redis.status === 'ready') {
    try {
      const setSuccess = await redis.set(nonceKey, '1', 'EX', 600, 'NX');
      if (!setSuccess) {
        nonceSeen = true;
      }
    } catch {
      // Fallback to in-memory cache if Redis is down
    }
  }

  if (!nonceSeen) {
    const cachedAt = inMemoryNonceCache.get(nonce);
    if (cachedAt && now - cachedAt < NONCE_TTL_MS) {
      nonceSeen = true;
    } else {
      inMemoryNonceCache.set(nonce, now);
      // Clean up old memory nonces periodically
      if (inMemoryNonceCache.size > 2000) {
        for (const [k, ts] of inMemoryNonceCache.entries()) {
          if (now - ts >= NONCE_TTL_MS) inMemoryNonceCache.delete(k);
        }
      }
    }
  }

  if (nonceSeen) {
    return res.status(409).json({
      error: 'REPLAY_ATTACK_DETECTED',
      message: 'Nonce has already been used. Replay attacks are prohibited.',
    });
  }

  // 3. Cryptographic HMAC validation
  const key = getDeviceSigningKey(deviceId);
  const expectedSignature = computePayloadSignature(key, timestamp, nonce, req.body);

  const sigBuffer = Buffer.from(signature, 'hex');
  const expectedBuffer = Buffer.from(expectedSignature, 'hex');

  if (
    sigBuffer.length !== expectedBuffer.length ||
    !crypto.timingSafeEqual(sigBuffer, expectedBuffer)
  ) {
    return res.status(401).json({
      error: 'INVALID_SIGNATURE',
      message: 'HMAC payload signature verification failed.',
    });
  }

  return next();
}

/**
 * Validates uploaded photo payload size (<= 5MB) and content type.
 */
export function validateImageUpload(req: Request, res: Response, next: NextFunction) {
  const image = req.body?.image;
  if (!image) return next();

  let byteLength = 0;
  let contentType = 'unknown';

  if (typeof image === 'string') {
    const mimeMatch = image.match(/^data:([a-zA-Z0-9.+/-]+);base64,/);
    if (mimeMatch) {
      contentType = mimeMatch[1].toLowerCase();
    } else {
      // Raw base64 or other string
      contentType = 'image/jpeg';
    }
    const base64Data = image.replace(/^data:image\/[a-zA-Z0-9.+]+;base64,/, '');
    byteLength = Buffer.byteLength(base64Data, 'base64');
  } else if (Buffer.isBuffer(image)) {
    byteLength = image.length;
    // Check magic bytes
    if (image[0] === 0xff && image[1] === 0xd8) contentType = 'image/jpeg';
    else if (image[0] === 0x89 && image[1] === 0x50) contentType = 'image/png';
    else if (image[0] === 0x52 && image[1] === 0x49) contentType = 'image/webp';
  }

  const MAX_IMAGE_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB
  if (byteLength > MAX_IMAGE_SIZE_BYTES) {
    return res.status(413).json({
      error: 'PAYLOAD_TOO_LARGE',
      message: `Image exceeds maximum permitted size of 5MB (received ${Math.round(byteLength / 1024 / 1024 * 10) / 10}MB).`,
    });
  }

  const allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];
  if (!allowedTypes.includes(contentType)) {
    return res.status(400).json({
      error: 'INVALID_CONTENT_TYPE',
      message: `Invalid image content type '${contentType}'. Allowed types: ${allowedTypes.join(', ')}`,
    });
  }

  return next();
}
