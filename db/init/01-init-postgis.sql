-- Rakshak-AI Database Initialization Script
-- Enables PostGIS and UUID generation extensions

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- Verification table for DB healthcheck during scaffolding
CREATE TABLE IF NOT EXISTS _scaffold_health (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_name VARCHAR(100) NOT NULL,
    postgis_version TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO _scaffold_health (service_name, postgis_version)
VALUES ('Rakshak-AI Database Scaffolding', PostGIS_Full_Version())
ON CONFLICT DO NOTHING;
