# Rakshak-AI Database Architecture & Schema

This directory manages the PostgreSQL + PostGIS schema, migrations, and seeds.

## Extensions Enabled
- **postgis**: Provides spatial geometry, indexing (`GIST`), distance calculations (`ST_DWithin`, `ST_Distance`), and geocoding capabilities.
- **uuid-ossp**: Provides RFC 4122 compliant UUID generation (`uuid_generate_v4()`).

## Directory Structure
- `init/`: Initialization SQL scripts mounted into `/docker-entrypoint-initdb.d` inside the PostgreSQL container. Automatically executed on initial container creation.
- `migrations/`: Future incremental database migrations (e.g. Prisma, Flyway, or node-pg-migrate).
- `seeds/`: Initial test data for hospitals, emergency response units, and trauma centers.
