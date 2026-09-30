-- Seed: 001_hospitals_bengaluru.sql
-- Description: 10 realistic hospitals in Bengaluru with authentic neighborhoods, coordinates, and trauma capability mix.

INSERT INTO hospitals (id, name, location, has_trauma_center, has_icu_capacity, phone, address, is_verified)
VALUES
    -- 1. Indiranagar / Kodihalli (Level 1 Trauma, Full ICU)
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
    -- 2. Koramangala (Level 1 Trauma, Full ICU)
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
    -- 3. Jayanagar / Bannerghatta Road (Level 1 Trauma, Full ICU)
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
    -- 4. MG Road / Cunningham Road (Trauma, Full ICU)
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
    -- 5. Whitefield (Trauma, Full ICU)
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
    -- 6. Jayanagar (Specialty Maternity/Pediatric - NO TRAUMA, NO GENERAL ICU)
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
    -- 7. Indiranagar (Secondary Care / General - NO TRAUMA, HAS ICU)
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
    -- 8. HSR Layout (Trauma Center, Full ICU)
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
    -- 9. Banashankari / Kumaraswamy Layout (Secondary Care - NO TRAUMA, HAS ICU)
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
    -- 10. Hebbal / North Bengaluru (Major Level 1 Trauma, Full ICU)
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
