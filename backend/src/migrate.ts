import fs from 'fs';
import path from 'path';
import { pool, closePool } from './db';

export const ensureMigrations = async (): Promise<void> => {
  const client = await pool.connect();
  try {
    const migrationsDir = path.resolve(__dirname, '../../db/migrations');
    if (!fs.existsSync(migrationsDir)) return;
    const files = fs
      .readdirSync(migrationsDir)
      .filter((f) => f.endsWith('.sql'))
      .sort();

    for (const file of files) {
      const filePath = path.join(migrationsDir, file);
      const migrationSql = fs.readFileSync(filePath, 'utf8');
      await client.query(migrationSql);
    }
    console.log('[Auto-Migration] Verified all database tables and auth schemas.');
  } catch (error) {
    console.warn('[Auto-Migration Warning] Database sync deferred:', error);
  } finally {
    client.release();
  }
};

const runMigrations = async (): Promise<void> => {
  const isSeed = process.argv.includes('--seed');
  const client = await pool.connect();

  try {
    console.log('[Migration Runner] Connecting to database...');

    // 1. Run schema migrations in order
    const migrationsDir = path.resolve(__dirname, '../../db/migrations');
    const files = fs
      .readdirSync(migrationsDir)
      .filter((f) => f.endsWith('.sql'))
      .sort();

    for (const file of files) {
      const filePath = path.join(migrationsDir, file);
      console.log(`[Migration Runner] Executing migration: ${file}`);
      const migrationSql = fs.readFileSync(filePath, 'utf8');
      await client.query(migrationSql);
      console.log(`[Migration Runner] Migration ${file} applied successfully.`);
    }

    // 2. Run seed if requested
    if (isSeed) {
      const seedPath = path.resolve(
        __dirname,
        '../../db/seeds/001_hospitals_bengaluru.sql',
      );
      console.log(`[Migration Runner] Executing seed: ${seedPath}`);
      const seedSql = fs.readFileSync(seedPath, 'utf8');
      await client.query(seedSql);
      console.log('[Migration Runner] Seed data populated successfully.');
    }
  } catch (error) {
    console.error('[Migration Runner Error] Migration failed:', error);
    process.exit(1);
  } finally {
    client.release();
    await closePool();
    console.log('[Migration Runner] Finished.');
  }
};

if (process.argv[1]?.includes('migrate')) {
  runMigrations();
}
