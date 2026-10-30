-- 010_add_police_case_and_gridlock.sql
-- Adds police case docket ID, territorial station metadata, edge pre-crash telemetry blackbox, and dynamic gridlock reassignment audit fields

ALTER TABLE incidents
ADD COLUMN IF NOT EXISTS case_number VARCHAR(64),
ADD COLUMN IF NOT EXISTS police_station_name VARCHAR(150),
ADD COLUMN IF NOT EXISTS police_officer_name VARCHAR(120),
ADD COLUMN IF NOT EXISTS police_officer_phone VARCHAR(50),
ADD COLUMN IF NOT EXISTS pre_crash_telemetry JSONB,
ADD COLUMN IF NOT EXISTS gridlock_detected BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS reassigned_from_ambulance_id VARCHAR(64),
ADD COLUMN IF NOT EXISTS reassigned_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_incidents_case_number ON incidents (case_number);
CREATE INDEX IF NOT EXISTS idx_incidents_gridlock_detected ON incidents (gridlock_detected);
