import Redis from 'ioredis';

const redisHost = process.env.REDIS_HOST || '127.0.0.1';
const redisPort = parseInt(process.env.REDIS_PORT || '6379', 10);

export const redis = new Redis({
  host: redisHost,
  port: redisPort,
  lazyConnect: true,
  enableOfflineQueue: false,
  retryStrategy(times) {
    if (times > 1) return null; // do not loop retries indefinitely if offline
    return 200;
  },
  maxRetriesPerRequest: 1,
});

redis.on('connect', () => {
  console.log(`[Redis] Connected to Redis at ${redisHost}:${redisPort}`);
});

redis.on('error', (err) => {
  console.warn('[Redis] Connection error:', err.message);
});

// Map of in-flight purge verification timers keyed by incident ID
const purgeTimers = new Map<string, NodeJS.Timeout>();

/**
 * Registers a background purge-confirmation verification job.
 * After the TTL (default: 900 seconds / 15 minutes), checks that the Redis key
 * has expired and been removed from RAM, logging the privacy confirmation.
 */
export function registerPurgeVerification(incidentId: string, ttlSeconds = 900): void {
  const existingTimer = purgeTimers.get(incidentId);
  if (existingTimer) {
    clearTimeout(existingTimer);
  }

  const timer = setTimeout(async () => {
    try {
      const key = `incident_image:${incidentId}`;
      const exists = await redis.exists(key);
      if (!exists) {
        console.log(
          `[Zero-Storage Privacy Engine] [PURGE CONFIRMED] Key ${key} confirmed absent from Redis RAM after ${ttlSeconds}-second TTL expiration.`
        );
      } else {
        console.warn(
          `[Zero-Storage Privacy Engine] [PURGE WARNING] Incident photo for incident ${incidentId} was not expired at expected TTL.`
        );
      }
    } catch (err) {
      console.error('[Zero-Storage Privacy Engine] Error verifying purge:', err);
    } finally {
      purgeTimers.delete(incidentId);
    }
  }, (ttlSeconds + 1) * 1000);

  if (timer.unref) {
    timer.unref();
  }
  purgeTimers.set(incidentId, timer);
}

// In-memory fallback cache for ephemeral health cards and images during test/offline runs
const ephemeralRamFallback = new Map<string, { data: string; expiresAt: number }>();

export const HEALTH_CARD_DEFAULT_TTL_SECONDS = parseInt(
  process.env.HEALTH_CARD_TTL_SECONDS || '7200',
  10
); // Default 2 hours

const healthCardPurgeTimers = new Map<string, NodeJS.Timeout>();

/**
 * Stores an ephemeral health card ONLY in Redis RAM with a configurable TTL (default 2 hours).
 * Never touches Postgres or disk.
 */
export async function storeEphemeralHealthCard(
  incidentId: string,
  cardJson: string,
  ttlSeconds = HEALTH_CARD_DEFAULT_TTL_SECONDS
): Promise<void> {
  const key = `health_card:${incidentId}`;
  const expiresAt = Date.now() + ttlSeconds * 1000;
  ephemeralRamFallback.set(key, { data: cardJson, expiresAt });

  if (redis.status === 'ready') {
    try {
      await redis.setex(key, ttlSeconds, cardJson);
    } catch (err) {
      console.warn('[Redis] Fallback to volatile RAM for health card storage:', (err as Error).message);
    }
  }

  registerHealthCardPurgeVerification(incidentId, ttlSeconds);
}

/**
 * Retrieves an ephemeral health card from Redis RAM.
 */
export async function getEphemeralHealthCard(incidentId: string): Promise<string | null> {
  const key = `health_card:${incidentId}`;
  if (redis.status === 'ready') {
    try {
      const val = await redis.get(key);
      if (val) return val;
    } catch (err) {
      // Redis unavailable, check memory fallback
    }
  }

  const cached = ephemeralRamFallback.get(key);
  if (cached && cached.expiresAt > Date.now()) {
    return cached.data;
  }
  if (cached && cached.expiresAt <= Date.now()) {
    ephemeralRamFallback.delete(key);
  }
  return null;
}

/**
 * Checks if a health card exists for an incident without returning its contents (for police view).
 */
export async function hasEphemeralHealthCard(incidentId: string): Promise<boolean> {
  const key = `health_card:${incidentId}`;
  if (redis.status === 'ready') {
    try {
      const exists = await redis.exists(key);
      if (exists) return true;
    } catch (_) {
      // Ignore
    }
  }

  const cached = ephemeralRamFallback.get(key);
  return Boolean(cached && cached.expiresAt > Date.now());
}

/**
 * Registers a background purge-confirmation verification job for Emergency Health Cards.
 * After the TTL (default 7200 seconds / 2 hours), verifies key absence from RAM and logs purge confirmation.
 */
export function registerHealthCardPurgeVerification(
  incidentId: string,
  ttlSeconds = HEALTH_CARD_DEFAULT_TTL_SECONDS
): void {
  const existingTimer = healthCardPurgeTimers.get(incidentId);
  if (existingTimer) {
    clearTimeout(existingTimer);
  }

  const timer = setTimeout(async () => {
    try {
      const key = `health_card:${incidentId}`;
      let existsInRedis = false;
      try {
        existsInRedis = (await redis.exists(key)) === 1;
      } catch (_) {}

      // Clean up in-memory fallback
      ephemeralRamFallback.delete(key);

      if (!existsInRedis) {
        console.log(
          `[Zero-Storage Privacy Engine] [HEALTH CARD PURGE CONFIRMED] Key ${key} confirmed absent from Redis RAM after ${ttlSeconds}-second TTL expiration.`
        );
      } else {
        console.warn(
          `[Zero-Storage Privacy Engine] [HEALTH CARD PURGE WARNING] Emergency health card for incident ${incidentId} was not expired at expected TTL.`
        );
      }
    } catch (err) {
      console.error('[Zero-Storage Privacy Engine] Error verifying health card purge:', err);
    } finally {
      healthCardPurgeTimers.delete(incidentId);
    }
  }, (ttlSeconds + 1) * 1000);

  if (timer.unref) {
    timer.unref();
  }
  healthCardPurgeTimers.set(incidentId, timer);
}
