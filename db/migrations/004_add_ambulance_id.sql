-- 004_add_ambulance_id.sql
-- Adds ambulance_id column to track which ambulance unit has opened/claimed the emergency

ALTER TABLE incidents
ADD COLUMN IF NOT EXISTS ambulance_id VARCHAR(100);

CREATE INDEX IF NOT EXISTS idx_incidents_ambulance_id ON incidents (ambulance_id);
