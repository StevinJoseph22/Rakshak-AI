-- 003_add_unmatched_status.sql
-- Add 'unmatched' to incident_status enum for auto-escalation when no trauma center is available

ALTER TYPE incident_status ADD VALUE IF NOT EXISTS 'unmatched';
