-- 007_add_suspected_and_cancelled_status.sql
-- Add 'suspected' and 'cancelled' to incident_status enum for Phase 17 pre-alert lifecycle

ALTER TYPE incident_status ADD VALUE IF NOT EXISTS 'suspected';
ALTER TYPE incident_status ADD VALUE IF NOT EXISTS 'cancelled';
