-- Migration: 002_create_incident_rejections.sql
-- Description: Track hospital rejections with reasons for triage audits and escalation

CREATE TABLE IF NOT EXISTS incident_rejections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    incident_id UUID NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
    hospital_id UUID NOT NULL REFERENCES hospitals(id) ON DELETE CASCADE,
    reason VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_incident_hospital_rejection UNIQUE (incident_id, hospital_id)
);

CREATE INDEX IF NOT EXISTS idx_incident_rejections_incident ON incident_rejections (incident_id);
CREATE INDEX IF NOT EXISTS idx_incident_rejections_hospital ON incident_rejections (hospital_id);
