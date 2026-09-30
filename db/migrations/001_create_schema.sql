-- Migration: 001_create_schema.sql
-- Description: Core geospatial schema for Rakshak-AI (hospitals, incidents, police_units)

-- Ensure required extensions exist
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- 1. Create Incident Status Enum
DO $$ BEGIN
    CREATE TYPE incident_status AS ENUM (
        'detected',
        'broadcasting',
        'accepted',
        'en_route',
        'resolved',
        'escalated'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. Create Hospitals Table
CREATE TABLE IF NOT EXISTS hospitals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    has_trauma_center BOOLEAN NOT NULL DEFAULT false,
    has_icu_capacity BOOLEAN NOT NULL DEFAULT true,
    phone VARCHAR(50) NOT NULL,
    address TEXT NOT NULL,
    is_verified BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 3. Create Incidents Table
CREATE TABLE IF NOT EXISTS incidents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    status incident_status NOT NULL DEFAULT 'detected',
    accepted_hospital_id UUID REFERENCES hospitals(id) ON DELETE SET NULL,
    victim_metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Create Police Units Table
CREATE TABLE IF NOT EXISTS police_units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    jurisdiction_area TEXT NOT NULL,
    contact VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 5. Create Spatial GIST Indexes
CREATE INDEX IF NOT EXISTS idx_hospitals_location ON hospitals USING GIST (location);
CREATE INDEX IF NOT EXISTS idx_incidents_location ON incidents USING GIST (location);

-- Additional operational indexes
CREATE INDEX IF NOT EXISTS idx_incidents_status ON incidents (status);
CREATE INDEX IF NOT EXISTS idx_incidents_created_at ON incidents (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_hospitals_trauma ON hospitals (has_trauma_center);
