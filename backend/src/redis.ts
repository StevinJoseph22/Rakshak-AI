import Redis from 'ioredis';

const redisHost = process.env.REDIS_HOST || '127.0.0.1';
const redisPort = parseInt(process.env.REDIS_PORT || '6379', 10);

export const redis = new Redis({
  host: redisHost,
  port: redisPort,
  retryStrategy(times) {
    const delay = Math.min(times * 100, 3000);
    return delay;
  },
  maxRetriesPerRequest: 3,
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
