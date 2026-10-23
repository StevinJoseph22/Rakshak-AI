-- Seed: 001_hospitals_bengaluru.sql
-- Description: 25 authentic hospitals across Bengaluru and highway corridors (Central, North, South, East, West, Outskirts).

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
    ),
    -- 11. Hebbal / Kempapura (Trauma, Full ICU)
    (
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        'Columbia Asia Hospital, Hebbal',
        ST_SetSRID(ST_MakePoint(77.5935, 13.0487), 4326)::geography,
        true,
        true,
        '+91-80-4042-0100',
        'No. 26/4, Pipeline Rd, Hebbal Kempapura, Hebbal, Bengaluru, Karnataka 560024',
        true
    ),
    -- 12. Nagarbhavi / West Bengaluru (Level 1 Trauma, Full ICU)
    (
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        'Fortis Hospital, Nagarbhavi',
        ST_SetSRID(ST_MakePoint(77.5126, 12.9851), 4326)::geography,
        true,
        true,
        '+91-80-4969-4969',
        'No. 154/9 Outer Ring Rd, Nagarbhavi, Bengaluru, Karnataka 560072',
        true
    ),
    -- 13. Kengeri / Southwest Corridor (Level 1 Trauma, Full ICU)
    (
        'dddddddd-dddd-dddd-dddd-dddddddddddd',
        'BGS Gleneagles Global Hospital, Kengeri',
        ST_SetSRID(ST_MakePoint(77.4830, 12.9113), 4326)::geography,
        true,
        true,
        '+91-80-6122-9000',
        'No. 67 Uttarahalli Main Rd, Kengeri, Bengaluru, Karnataka 560060',
        true
    ),
    -- 14. Yeshwanthpur / Northwest Bengaluru (Level 1 Trauma, Full ICU)
    (
        'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
        'Manipal Hospital, Yeshwanthpur',
        ST_SetSRID(ST_MakePoint(77.5500, 13.0272), 4326)::geography,
        true,
        true,
        '+91-80-2344-3377',
        'No. 9/1 Rustum Bagh Main Rd, Yeshwanthpur, Bengaluru, Karnataka 560022',
        true
    ),
    -- 15. Yelahanka New Town / North Corridor (Trauma, ICU)
    (
        'ffffffff-ffff-ffff-ffff-ffffffffffff',
        'Sparsh Hospital, Yelahanka',
        ST_SetSRID(ST_MakePoint(77.5960, 13.1020), 4326)::geography,
        true,
        true,
        '+91-80-4353-5353',
        'No. 29/P2 NT Road, Yelahanka New Town, Bengaluru, Karnataka 560064',
        true
    ),
    -- 16. Marathahalli / Bellandur (Level 1 Trauma, ICU)
    (
        'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'Sakra World Hospital, Marathahalli Ext.',
        ST_SetSRID(ST_MakePoint(77.6850, 12.9260), 4326)::geography,
        true,
        true,
        '+91-80-4969-4000',
        'No. 52/2 Devarabisanahalli, Outer Ring Road, Bengaluru, Karnataka 560103',
        true
    ),
    -- 17. Kothanur / Hennur Main Road (Trauma, ICU)
    (
        'b1000001-0000-0000-0000-000000000001',
        'Cratis Hospital, Hennur / Kothanur',
        ST_SetSRID(ST_MakePoint(77.6480, 13.0583), 4326)::geography,
        true,
        true,
        '+91-80-4567-8901',
        'Hennur Bagalur Main Rd, Kothanur, Bengaluru, Karnataka 560077',
        true
    ),
    -- 18. Bellary Road / Hebbal (Trauma, ICU)
    (
        'b1000002-0000-0000-0000-000000000002',
        'Bangalore Baptist Hospital, Bellary Road',
        ST_SetSRID(ST_MakePoint(77.5898, 13.0298), 4326)::geography,
        true,
        true,
        '+91-80-2202-4444',
        'Bellary Rd, Vinayakanagar, Hebbal, Bengaluru, Karnataka 560024',
        true
    ),
    -- 19. Mathikere / MS Ramaiah Nagar (Level 1 Trauma, ICU)
    (
        'b1000003-0000-0000-0000-000000000003',
        'Ramaiah Memorial Hospital, MS Ramaiah Nagar',
        ST_SetSRID(ST_MakePoint(77.5645, 13.0315), 4326)::geography,
        true,
        true,
        '+91-80-2360-8888',
        'M S Ramaiah Nagar, Mathikere, Bengaluru, Karnataka 560054',
        true
    ),
    -- 20. KR Market / Kalasipalya (BMCRI Level 1 Apex Trauma Center)
    (
        'b1000004-0000-0000-0000-000000000004',
        'Victoria Hospital (BMCRI Trauma Center)',
        ST_SetSRID(ST_MakePoint(77.5744, 12.9634), 4326)::geography,
        true,
        true,
        '+91-80-2670-1150',
        'Fort Rd, near City Market, Kalasipalya, Bengaluru, Karnataka 560002',
        true
    ),
    -- 21. Shivaji Nagar / Cantonment (Trauma, ICU)
    (
        'b1000005-0000-0000-0000-000000000005',
        'Bowring and Lady Curzon Hospital, Shivaji Nagar',
        ST_SetSRID(ST_MakePoint(77.6033, 12.9839), 4326)::geography,
        true,
        true,
        '+91-80-2559-1362',
        'Hospital Rd, Shivaji Nagar, Bengaluru, Karnataka 560001',
        true
    ),
    -- 22. JP Nagar / South Bengaluru (Trauma, ICU)
    (
        'b1000006-0000-0000-0000-000000000006',
        'Aster RV Hospital, JP Nagar',
        ST_SetSRID(ST_MakePoint(77.5888, 12.9121), 4326)::geography,
        true,
        true,
        '+91-80-6604-0400',
        'CA-37, 24th Main Rd, ITI Layout, JP Nagar 1st Phase, Bengaluru, Karnataka 560078',
        true
    ),
    -- 23. Electronic City / Bommasandra (Trauma, ICU)
    (
        'b1000007-0000-0000-0000-000000000007',
        'Sparsh Hospital, Hosur Road / Electronic City',
        ST_SetSRID(ST_MakePoint(77.6601, 12.8452), 4326)::geography,
        true,
        true,
        '+91-80-6190-6190',
        'Plot No. 258/A, Hosur Rd, Bommasandra Industrial Area, Bengaluru, Karnataka 560099',
        true
    ),
    -- 24. Devanahalli / NH-44 Airport Corridor (Outskirts North Trauma Center)
    (
        'b1000008-0000-0000-0000-000000000008',
        'Akash Hospital & Trauma Care, Devanahalli',
        ST_SetSRID(ST_MakePoint(77.7120, 13.2450), 4326)::geography,
        true,
        true,
        '+91-80-7110-7000',
        'Prasannahalli Main Rd, Devanahalli, near Kempegowda Intl Airport, Bengaluru, Karnataka 562110',
        true
    ),
    -- 25. Nelamangala / NH-48 Kunigal Bypass (Outskirts West Trauma Center)
    (
        'b1000009-0000-0000-0000-000000000009',
        'Nelamangala General Hospital & Trauma Center',
        ST_SetSRID(ST_MakePoint(77.3871, 13.0982), 4326)::geography,
        true,
        true,
        '+91-80-2772-2233',
        'NH-48 Kunigal Bypass, Subhash Nagar, Nelamangala Town, Karnataka 562123',
        true
    ),
    -- 26. Banaswadi / HRBR Layout (North-East Level 1 Emergency Trauma Hub)
    (
        'b1000010-0000-0000-0000-000000000010',
        'Specialist Hospital, Banaswadi / HRBR Layout',
        ST_SetSRID(ST_MakePoint(77.6450, 13.0180), 4326)::geography,
        true,
        true,
        '+91-80-4344-4444',
        '216, 7th Main Rd, HRBR Layout 1st Block, Banaswadi, Bengaluru, Karnataka 560043',
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
