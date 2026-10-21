-- Migration: 005_create_users_and_auth.sql
-- Description: Create RBAC users table and seed pre-configured logins for all 25 hospitals, police, and ambulance.

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL CHECK (role IN ('hospital_staff', 'police', 'ambulance')),
    hospital_id UUID REFERENCES hospitals(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS hospital_id UUID REFERENCES hospitals(id) ON DELETE SET NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;

CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_hospital_id ON users(hospital_id);

-- Seed hospital staff accounts for all 25 trauma centers + police & ambulance
-- Default password:
-- Hospital Staff: hospital123 ($2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO)
-- Police Control: police123 ($2b$10$8V9LitbF8Crn0quecd3o3u6YNXEHoLi6YlIORmh.XjR.UHeiu7OqO)
-- Ambulance Pilot: ambulance123 ($2b$10$fkI4gnuT0qsFiAF6hBW0MedzBrjs.1L5Fj5d3n.12LlYjy2GGxZ/y)

INSERT INTO users (username, password_hash, role, hospital_id)
VALUES
    -- 1. Manipal Hospital, Old Airport Road
    ('manipal_hal', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', '11111111-1111-1111-1111-111111111111'),
    -- 2. St. John's Medical College Hospital
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
    -- 11. Columbia Asia Hospital, Hebbal
    ('columbia_hebbal', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
    -- 12. Fortis Hospital, Nagarbhavi
    ('fortis_nagarbhavi', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
    -- 13. BGS Gleneagles Global Hospital, Kengeri
    ('bgs_kengeri', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'dddddddd-dddd-dddd-dddd-dddddddddddd'),
    -- 14. Manipal Hospital, Yeshwanthpur
    ('manipal_yeshwanthpur', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'),
    -- 15. Sparsh Hospital, Yelahanka
    ('sparsh_yelahanka', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'ffffffff-ffff-ffff-ffff-ffffffffffff'),
    -- 16. Sakra World Hospital, Marathahalli Ext.
    ('sakra_marathahalli', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'),
    -- 17. Cratis Hospital, Hennur / Kothanur
    ('cratis_kothanur', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000001-0000-0000-0000-000000000001'),
    -- 18. Bangalore Baptist Hospital, Bellary Road
    ('baptist_hebbal', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000002-0000-0000-0000-000000000002'),
    -- 19. Ramaiah Memorial Hospital, MS Ramaiah Nagar
    ('ramaiah_memorial', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000003-0000-0000-0000-000000000003'),
    -- 20. Victoria Hospital (BMCRI Trauma Center)
    ('victoria_trauma', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000004-0000-0000-0000-000000000004'),
    -- 21. Bowring and Lady Curzon Hospital, Shivaji Nagar
    ('bowring_curzon', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000005-0000-0000-0000-000000000005'),
    -- 22. Aster RV Hospital, JP Nagar
    ('aster_jpnagar', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000006-0000-0000-0000-000000000006'),
    -- 23. Sparsh Hospital, Hosur Road / Electronic City
    ('sparsh_ecity', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000007-0000-0000-0000-000000000007'),
    -- 24. Akash Hospital & Trauma Care, Devanahalli
    ('akash_devanahalli', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000008-0000-0000-0000-000000000008'),
    -- 25. Nelamangala General Hospital & Trauma Center
    ('nelamangala_trauma', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000009-0000-0000-0000-000000000009'),
    -- Police Control Room Account
    ('police_control', '$2b$10$8V9LitbF8Crn0quecd3o3u6YNXEHoLi6YlIORmh.XjR.UHeiu7OqO', 'police', NULL),
    -- Ambulance Pilot Account
    ('ambulance_pilot', '$2b$10$fkI4gnuT0qsFiAF6hBW0MedzBrjs.1L5Fj5d3n.12LlYjy2GGxZ/y', 'ambulance', NULL)
ON CONFLICT (username) DO UPDATE SET
    hospital_id = EXCLUDED.hospital_id,
    role = EXCLUDED.role,
    password_hash = EXCLUDED.password_hash;
