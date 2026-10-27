-- Migration 009: Hospital Capabilities, Source/Verification metadata, and Hash-Chained Audit Log

-- 1. Add Source & Verification fields to hospitals
ALTER TABLE hospitals ADD COLUMN IF NOT EXISTS source VARCHAR(255) DEFAULT 'KMC Registry / BBMP Public Directory (sample data, verify before real use)';
ALTER TABLE hospitals ADD COLUMN IF NOT EXISTS last_verified DATE DEFAULT CURRENT_DATE;

-- 2. Create Hospital Capabilities Table
CREATE TABLE IF NOT EXISTS hospital_capabilities (
    hospital_id UUID PRIMARY KEY REFERENCES hospitals(id) ON DELETE CASCADE,
    ct_scan BOOLEAN NOT NULL DEFAULT true,
    mri BOOLEAN NOT NULL DEFAULT true,
    neuro_icu BOOLEAN NOT NULL DEFAULT true,
    blood_bank BOOLEAN NOT NULL DEFAULT true,
    ortho_ot BOOLEAN NOT NULL DEFAULT true,
    fast_ultrasound BOOLEAN NOT NULL DEFAULT true,
    ventilators BOOLEAN NOT NULL DEFAULT true,
    general_surgery BOOLEAN NOT NULL DEFAULT true,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(100) NOT NULL DEFAULT 'system_seed'
);

-- Seed hospital_capabilities from all existing hospitals
INSERT INTO hospital_capabilities (hospital_id, updated_by)
SELECT id, 'system_seed' FROM hospitals
ON CONFLICT (hospital_id) DO NOTHING;

-- 3. Create Hash-Chained Audit Log Table
CREATE TABLE IF NOT EXISTS audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sequence_number BIGSERIAL UNIQUE,
    action VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(100) NOT NULL,
    actor_id VARCHAR(100) NOT NULL,
    actor_role VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    prev_hash VARCHAR(64) NOT NULL,
    record_hash VARCHAR(64) NOT NULL,
    created_at_iso VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_log_seq ON audit_log(sequence_number);
CREATE INDEX IF NOT EXISTS idx_audit_log_entity ON audit_log(entity_type, entity_id);

-- 4. Database Engine Trigger enforcing Append-Only on audit_log (blocks UPDATE and DELETE)
CREATE OR REPLACE FUNCTION prevent_audit_tampering()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Audit log is append-only. UPDATE and DELETE operations are strictly prohibited.';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_audit_update_delete ON audit_log;
CREATE TRIGGER trg_prevent_audit_update_delete
BEFORE UPDATE OR DELETE ON audit_log
FOR EACH ROW EXECUTE FUNCTION prevent_audit_tampering();

-- 5. Revoke UPDATE and DELETE privileges for general database roles
DO $$
BEGIN
    REVOKE UPDATE, DELETE ON audit_log FROM PUBLIC;
EXCEPTION
    WHEN OTHERS THEN null;
END $$;
