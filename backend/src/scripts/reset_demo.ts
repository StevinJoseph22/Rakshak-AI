import { pool, closePool } from '../db';
import { redis } from '../redis';

async function resetDemoState() {
  console.log('=====================================================');
  console.log('  RAKSHAK-AI: RESET DEMO STATE (PRE-PITCH CLEANUP)  ');
  console.log('=====================================================');

  try {
    // 1. Clear PostgreSQL Incidents & Rejections
    console.log('[1/3] Purging database incidents and rejection history...');
    const client = await pool.connect();
    try {
      await client.query('BEGIN;');
      await client.query('DELETE FROM incident_rejections;');
      await client.query('DELETE FROM incidents;');
      await client.query('COMMIT;');
      console.log('  -> Postgres: All incidents and rejections cleared.');
    } catch (dbErr) {
      await client.query('ROLLBACK;');
      console.warn('  -> Postgres cleanup warning:', dbErr);
    } finally {
      client.release();
    }

    // 2. Clear volatile Redis keys (ephemeral images, hospital caches, GPS beacons)
    console.log('[2/3] Purging Redis ephemeral RAM keys...');
    try {
      const keys = await redis.keys('*incident*');
      const ambKeys = await redis.keys('ambulance_loc:*');
      const allKeys = [...keys, ...ambKeys];

      if (allKeys.length > 0) {
        await redis.del(...allKeys);
        console.log(`  -> Redis: Purged ${allKeys.length} active demo keys.`);
      } else {
        console.log('  -> Redis: No active demo keys found (already clean).');
      }
    } catch (redisErr) {
      console.warn('  -> Redis cleanup warning:', redisErr);
    }

    // 3. Verify clean hospital network
    console.log('[3/4] Verifying trauma hospital capacity...');
    const hospRes = await pool.query('SELECT COUNT(*) as count FROM hospitals WHERE has_trauma_center = true;');
    console.log(`  -> Trauma centers online & ready: ${hospRes.rows[0].count}`);

    // 4. Signal live backend to broadcast 'feed_cleared' so mobile apps and dashboards clear UI & dedup history
    console.log('[4/4] Broadcasting feed_cleared signal to live mobile apps and dashboards...');
    try {
      const res = await fetch('http://127.0.0.1:5000/incidents', {
        method: 'DELETE',
        signal: AbortSignal.timeout(1500),
      });
      if (res.ok) {
        console.log('  -> Live backend notified: feed_cleared broadcast to mobile & dashboards.');
      }
    } catch {
      console.log('  -> Note: Standalone server process not reachable via HTTP; database & Redis cleared directly.');
    }

    console.log('\nDEMO STATE RESET COMPLETE: System is 100% clean and ready for judges.\n');
  } catch (error) {
    console.error('Reset demo state encountered error:', error);
  } finally {
    try {
      await redis.quit();
    } catch {
      // ignore
    }
    await closePool();
  }
}

resetDemoState();
