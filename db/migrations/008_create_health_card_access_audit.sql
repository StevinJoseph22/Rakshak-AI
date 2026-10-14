-- Migration 008: Create Health Card Break-Glass Access Audit Table
CREATE TABLE IF NOT EXISTS health_card_access_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id VARCHAR(100) NOT NULL,
    hospital_id VARCHAR(100) NOT NULL,
    user_id VARCHAR(100),
    username VARCHAR(100) NOT NULL,
    reason TEXT NOT NULL,
    accessed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_health_card_audit_incident ON health_card_access_audit(incident_id);
CREATE INDEX IF NOT EXISTS idx_health_card_audit_hospital ON health_card_access_audit(hospital_id);
