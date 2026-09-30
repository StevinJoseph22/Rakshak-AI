-- 02-schema-and-seeds.sql
-- Core schema and Bengaluru mock hospital seeds for Docker PostGIS initialization

-- 1. Create Incident Status Enum
DO $$ BEGIN
    CREATE TYPE incident_status AS ENUM (
        'detected',
        'broadcasting',
        'accepted',
        'en_route',
        'resolved',
        'escalated',
        'unmatched'
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
CREATE INDEX IF NOT EXISTS idx_incidents_status ON incidents (status);
CREATE INDEX IF NOT EXISTS idx_incidents_created_at ON incidents (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_hospitals_trauma ON hospitals (has_trauma_center);

-- 6. Create Incident Rejections Table (Phase 7)
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

-- 7. Seed 10 Realistic Bengaluru Hospitals
INSERT INTO hospitals (id, name, location, has_trauma_center, has_icu_capacity, phone, address, is_verified)
VALUES
    (
        '11111111-1111-1111-1111-111111111111',
        'Manipal Hospital, Old Airport Road',
        ST_SetSRID(ST_MakePoint(77.6499, 12.9592), 4326)::geography,
        true,
        true,
        '+91-80-2502-4444',
        '98 HAL Old Airport Rd, Kodihalli, Bengaluru, Karnataka 560017',
        true
    ),
    (
        '22222222-2222-2222-2222-222222222222',
        'St. John''s Medical College Hospital',
        ST_SetSRID(ST_MakePoint(77.6190, 12.9343), 4326)::geography,
        true,
        true,
        '+91-80-2206-5000',
        'Sarjapur - Marathahalli Rd, John Nagar, Koramangala, Bengaluru, Karnataka 560034',
        true
    ),
    (
        '33333333-3333-3333-3333-333333333333',
        'Apollo Hospitals, Bannerghatta Road',
        ST_SetSRID(ST_MakePoint(77.5976, 12.8938), 4326)::geography,
        true,
        true,
        '+91-80-2630-4050',
        '154/11 Bannerghatta Main Rd, Opp. IIM-B, Bengaluru, Karnataka 560076',
        true
    ),
    (
        '44444444-4444-4444-4444-444444444444',
        'Fortis Hospital, Cunningham Road',
        ST_SetSRID(ST_MakePoint(77.5949, 12.9868), 4326)::geography,
        true,
        true,
        '+91-80-4199-4444',
        '14 Cunningham Rd, Vasanth Nagar, near MG Road, Bengaluru, Karnataka 560052',
        true
    ),
    (
        '55555555-5555-5555-5555-555555555555',
        'Manipal Hospital, Whitefield',
        ST_SetSRID(ST_MakePoint(77.7317, 12.9880), 4326)::geography,
        true,
        true,
        '+91-80-6165-6666',
        'ITPL Main Rd, KIADB Export Promotion Industrial Area, Whitefield, Bengaluru, Karnataka 560066',
        true
    ),
    (
        '66666666-6666-6666-6666-666666666666',
        'Cloudnine Hospital, Jayanagar',
        ST_SetSRID(ST_MakePoint(77.5834, 12.9298), 4326)::geography,
        false,
        false,
        '+91-80-6792-9999',
        '1533 9th Main Rd, 3rd Block, Jayanagar, Bengaluru, Karnataka 560011',
        true
    ),
    (
        '77777777-7777-7777-7777-777777777777',
        'Chinmaya Mission Hospital',
        ST_SetSRID(ST_MakePoint(77.6441, 12.9772), 4326)::geography,
        false,
        true,
        '+91-80-2528-0461',
        'CMH Rd, Indiranagar, Bengaluru, Karnataka 560038',
        true
    ),
    (
        '88888888-8888-8888-8888-888888888888',
        'Narayana Multispeciality Hospital, HSR Layout',
        ST_SetSRID(ST_MakePoint(77.6387, 12.9112), 4326)::geography,
        true,
        true,
        '+91-80-6750-5000',
        '3/2 Sector 3, HSR Layout, Outer Ring Road, Bengaluru, Karnataka 560102',
        true
    ),
    (
        '99999999-9999-9999-9999-999999999999',
        'Sagar Hospitals, DSI Campus',
        ST_SetSRID(ST_MakePoint(77.5601, 12.9080), 4326)::geography,
        false,
        true,
        '+91-80-4299-9999',
        'Shavige Malleshwara Hills, Kumaraswamy Layout, Bengaluru, Karnataka 560078',
        true
    ),
    (
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'Aster CMI Hospital, Hebbal',
        ST_SetSRID(ST_MakePoint(77.5925, 13.0560), 4326)::geography,
        true,
        true,
        '+91-80-4342-0100',
        'No. 43/42 NH 44, Sahakar Nagar, Hebbal, Bengaluru, Karnataka 560092',
        true
    )
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    location = EXCLUDED.location,
    has_trauma_center = EXCLUDED.has_trauma_center,
    has_icu_capacity = EXCLUDED.has_icu_capacity,
    phone = EXCLUDED.phone,
    address = EXCLUDED.address,
    is_verified = EXCLUDED.is_verified,
    updated_at = CURRENT_TIMESTAMP;
