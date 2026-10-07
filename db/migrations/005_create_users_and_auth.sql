-- Migration 005: Create users table and seed initial demo accounts
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('hospital_staff', 'police', 'ambulance')),
    hospital_id UUID REFERENCES hospitals(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_hospital_id ON users(hospital_id);

-- Seed Demo Users for all 10 hospitals, police control room, and emergency ambulance
-- Password for all hospital demo accounts: 'hospital123'
-- Password for police demo account: 'police123'
-- Password for ambulance demo account: 'ambulance123'

INSERT INTO users (username, password_hash, role, hospital_id)
VALUES
    -- 1. Manipal Hospital, Old Airport Road
    ('manipal_hal', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', '11111111-1111-1111-1111-111111111111'),
    -- 2. St. John''s Medical College Hospital
    ('st_johns', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', '22222222-2222-2222-2222-222222222222'),
    -- 3. Apollo Hospitals, Bannerghatta Road
    ('apollo_bg', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', '33333333-3333-3333-3333-333333333333'),
    -- 4. Fortis Hospital, Cunningham Road
    ('fortis_cunningham', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', '44444444-4444-4444-4444-444444444444'),
    -- 5. Manipal Hospital, Whitefield
    ('manipal_whitefield', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', '55555555-5555-5555-5555-555555555555'),
    -- 6. Cloudnine Hospital, Jayanagar
    ('cloudnine_jayanagar', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', '66666666-6666-6666-6666-666666666666'),
    -- 7. Chinmaya Mission Hospital
    ('chinmaya_mission', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', '77777777-7777-7777-7777-777777777777'),
    -- 8. Narayana Multispeciality Hospital, HSR Layout
    ('narayana_hsr', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', '88888888-8888-8888-8888-888888888888'),
    -- 9. Sagar Hospitals, DSI Campus
    ('sagar_dsi', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', '99999999-9999-9999-9999-999999999999'),
    -- 10. Aster CMI Hospital, Hebbal
    ('aster_hebbal', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
    -- Police Control Room Account
    ('police_control', '$2b$10$8V9LitbF8Crn0quecd3o3u6YNXEHoLi6YlIORmh.XjR.UHeiu7OqO', 'police', NULL),
    -- Ambulance Pilot Account
    ('ambulance_pilot', '$2b$10$fkI4gnuT0qsFiAF6hBW0MedzBrjs.1L5Fj5d3n.12LlYjy2GGxZ/y', 'ambulance', NULL)
ON CONFLICT (username) DO NOTHING;
