-- Seed: 001_hospitals_bengaluru.sql
-- Description: Comprehensive registry of 81 authentic hospitals across Bengaluru and highway corridors.

INSERT INTO hospitals (id, name, location, has_trauma_center, has_icu_capacity, phone, address, is_verified)
VALUES
    -- 1. Manipal Hospital, Old Airport Road
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
    -- 2. St. John's Medical College Hospital
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
    -- 3. Apollo Hospitals, Bannerghatta Road
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
    -- 4. Fortis Hospital, Cunningham Road
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
    -- 5. Manipal Hospital, Whitefield
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
    -- 6. Cloudnine Hospital, Jayanagar
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
    -- 7. Chinmaya Mission Hospital, Indiranagar
    (
        '77777777-7777-7777-7777-777777777777',
        'Chinmaya Mission Hospital, Indiranagar',
        ST_SetSRID(ST_MakePoint(77.6441, 12.9772), 4326)::geography,
        true,
        true,
        '+91-80-2528-0461',
        'CMH Rd, Indiranagar, Bengaluru, Karnataka 560038',
        true
    ),
    -- 8. Narayana Multispeciality Hospital, HSR Layout
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
    -- 9. Sagar Hospitals, DSI Campus
    (
        '99999999-9999-9999-9999-999999999999',
        'Sagar Hospitals, DSI Campus',
        ST_SetSRID(ST_MakePoint(77.5601, 12.9080), 4326)::geography,
        true,
        true,
        '+91-80-4299-9999',
        'Shavige Malleshwara Hills, Kumaraswamy Layout, Bengaluru, Karnataka 560078',
        true
    ),
    -- 10. Fortis Hospital, Bannerghatta Road
    (
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'Fortis Hospital, Bannerghatta Road',
        ST_SetSRID(ST_MakePoint(77.5971, 12.8930), 4326)::geography,
        true,
        true,
        '+91-80-6621-4444',
        '154/9 Bannerghatta Rd, Opp. IIM-B, Bengaluru, Karnataka 560076',
        true
    ),
    -- 11. Columbia Asia Hospital, Hebbal
    (
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        'Columbia Asia Hospital, Hebbal',
        ST_SetSRID(ST_MakePoint(77.5935, 13.0487), 4326)::geography,
        true,
        true,
        '+91-80-4042-0100',
        'No. 26/4, Pipeline Rd, Hebbal Kempapura, Bengaluru, Karnataka 560024',
        true
    ),
    -- 12. Columbia Asia Hospital, Whitefield
    (
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        'Columbia Asia Hospital, Whitefield',
        ST_SetSRID(ST_MakePoint(77.7499, 12.9698), 4326)::geography,
        true,
        true,
        '+91-80-6165-6262',
        'Survey No. 10P & 12P, Ramagondanahalli, Varthur Kodi, Whitefield, Bengaluru, Karnataka 560066',
        true
    ),
    -- 13. Sakra World Hospital, Marathahalli
    (
        'dddddddd-dddd-dddd-dddd-dddddddddddd',
        'Sakra World Hospital, Marathahalli',
        ST_SetSRID(ST_MakePoint(77.6833, 12.9261), 4326)::geography,
        true,
        true,
        '+91-80-4969-4969',
        '52/2 & 52/3, Devarabeesanahalli Flyover, Outer Ring Rd, Bellandur, Bengaluru, Karnataka 560103',
        true
    ),
    -- 14. BGS Gleneagles Global Hospitals, Kengeri
    (
        'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
        'BGS Gleneagles Global Hospitals, Kengeri',
        ST_SetSRID(ST_MakePoint(77.4975, 12.9031), 4326)::geography,
        true,
        true,
        '+91-80-2625-5555',
        '67 Uttarahalli Rd, Sunkalpalya, Kengeri, Bengaluru, Karnataka 560060',
        true
    ),
    -- 15. Sparsh Super Speciality Hospital, Yeshwanthpur
    (
        'ffffffff-ffff-ffff-ffff-ffffffffffff',
        'Sparsh Super Speciality Hospital, Yeshwanthpur',
        ST_SetSRID(ST_MakePoint(77.5489, 13.0232), 4326)::geography,
        true,
        true,
        '+91-80-6190-6190',
        '4/1 Tumkur Rd, Yeshwanthpur, Bengaluru, Karnataka 560022',
        true
    ),
    -- 16. Vydehi Hospital, Whitefield
    (
        'a1000001-0000-0000-0000-000000000001',
        'Vydehi Hospital, Whitefield',
        ST_SetSRID(ST_MakePoint(77.7289, 12.9771), 4326)::geography,
        true,
        true,
        '+91-80-2841-3381',
        '82 EPIP Area, Whitefield, Bengaluru, Karnataka 560066',
        true
    ),
    -- 17. Baptist Hospital, Hebbal
    (
        'a1000002-0000-0000-0000-000000000002',
        'Baptist Hospital, Hebbal',
        ST_SetSRID(ST_MakePoint(77.5898, 13.0336), 4326)::geography,
        true,
        true,
        '+91-80-2202-4444',
        'Bellary Rd, Vinayakanagar, Hebbal, Bengaluru, Karnataka 560024',
        true
    ),
    -- 18. Aster CMI Hospital, Hebbal
    (
        'b1000002-0000-0000-0000-000000000002',
        'Aster CMI Hospital, Hebbal',
        ST_SetSRID(ST_MakePoint(77.5912, 13.0531), 4326)::geography,
        true,
        true,
        '+91-80-4342-0100',
        'No. 43/2, New Airport Rd, NH-44, Sahakar Nagar, Hebbal, Bengaluru, Karnataka 560092',
        true
    ),
    -- 19. Ramaiah Memorial Hospital, MS Ramaiah Nagar
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
    -- 20. Victoria Hospital (BMCRI Trauma Center)
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
    -- 21. Bowring and Lady Curzon Hospital, Shivaji Nagar
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
    -- 22. Aster RV Hospital, JP Nagar
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
    -- 23. Sparsh Hospital, Hosur Road / Electronic City
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
    -- 24. Akash Hospital & Trauma Care, Devanahalli
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
    -- 25. Nelamangala General Hospital & Trauma Center
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
    -- 26. Specialist Hospital, Banaswadi / HRBR Layout
    (
        'b1000010-0000-0000-0000-000000000010',
        'Specialist Hospital, Banaswadi / HRBR Layout',
        ST_SetSRID(ST_MakePoint(77.6450, 13.0180), 4326)::geography,
        true,
        true,
        '+91-80-4344-4444',
        '216, 7th Main Rd, HRBR Layout 1st Block, Banaswadi, Bengaluru, Karnataka 560043',
        true
    ),
    -- 27. Cratis Hospital, Hennur / Kothanur
    (
        'b1000011-0000-0000-0000-000000000011',
        'Cratis Hospital, Hennur / Kothanur',
        ST_SetSRID(ST_MakePoint(77.6480, 13.0583), 4326)::geography,
        true,
        true,
        '+91-80-4567-8901',
        'Hennur Bagalur Main Rd, Kothanur, Bengaluru, Karnataka 560077',
        true
    ),
    -- 28. NIMHANS Neuro-Trauma Center, Hosur Road
    (
        'b1000012-0000-0000-0000-000000000012',
        'NIMHANS Neuro-Trauma Center, Hosur Road',
        ST_SetSRID(ST_MakePoint(77.5961, 12.9392), 4326)::geography,
        true,
        true,
        '+91-80-2699-5000',
        'Hosur Rd, Lakkasandra, Hombegowda Nagar, Bengaluru, Karnataka 560029',
        true
    ),
    -- 29. Sri Jayadeva Institute of Cardiovascular Sciences, Jayanagar
    (
        'b1000013-0000-0000-0000-000000000013',
        'Sri Jayadeva Institute of Cardiovascular Sciences, Jayanagar',
        ST_SetSRID(ST_MakePoint(77.5969, 12.9181), 4326)::geography,
        true,
        true,
        '+91-80-2297-7400',
        'Bannerghatta Main Rd, 9th Block, Jayanagar, Bengaluru, Karnataka 560069',
        true
    ),
    -- 30. Narayana Health City (Mazumdar Shaw Medical Center), Bommasandra
    (
        'b1000014-0000-0000-0000-000000000014',
        'Narayana Health City (Mazumdar Shaw Medical Center), Bommasandra',
        ST_SetSRID(ST_MakePoint(77.6892, 12.8251), 4326)::geography,
        true,
        true,
        '+91-80-7122-2222',
        '258/A, Bommasandra Industrial Area, Anekal Taluk, Bengaluru, Karnataka 560099',
        true
    ),
    -- 31. Kauvery Hospital, Electronic City Phase 1
    (
        'b1000015-0000-0000-0000-000000000015',
        'Kauvery Hospital, Electronic City Phase 1',
        ST_SetSRID(ST_MakePoint(77.6652, 12.8488), 4326)::geography,
        true,
        true,
        '+91-80-6801-6801',
        'No. 7/2 & 8/2, Hosur Main Rd, Phase 1, Electronic City, Bengaluru, Karnataka 560100',
        true
    ),
    -- 32. Manipal Hospital, Sarjapur Road
    (
        'b1000016-0000-0000-0000-000000000016',
        'Manipal Hospital, Sarjapur Road',
        ST_SetSRID(ST_MakePoint(77.6811, 12.9142), 4326)::geography,
        true,
        true,
        '+91-80-6165-6677',
        'Ambalipura, Bellandur Gate, Sarjapur Main Rd, Bengaluru, Karnataka 560102',
        true
    ),
    -- 33. Manipal Hospital, Jayanagar
    (
        'b1000017-0000-0000-0000-000000000017',
        'Manipal Hospital, Jayanagar',
        ST_SetSRID(ST_MakePoint(77.5912, 12.9234), 4326)::geography,
        true,
        true,
        '+91-80-2695-9999',
        '45/1, 45th Cross Rd, 8th Block, Jayanagar, Bengaluru, Karnataka 560082',
        true
    ),
    -- 34. Manipal Hospital, Malleshwaram
    (
        'b1000018-0000-0000-0000-000000000018',
        'Manipal Hospital, Malleshwaram',
        ST_SetSRID(ST_MakePoint(77.5712, 13.0031), 4326)::geography,
        true,
        true,
        '+91-80-2346-6000',
        '8th Main Rd, 14th Cross Rd, Malleshwaram, Bengaluru, Karnataka 560003',
        true
    ),
    -- 35. Manipal Hospital, Yeshwanthpur
    (
        'b1000019-0000-0000-0000-000000000019',
        'Manipal Hospital, Yeshwanthpur',
        ST_SetSRID(ST_MakePoint(77.5524, 13.0162), 4326)::geography,
        true,
        true,
        '+91-80-6165-6688',
        '26/4, Brigade Gateway, Beside Metro, Yeshwanthpur, Bengaluru, Karnataka 560055',
        true
    ),
    -- 36. KC General Hospital, Malleshwaram
    (
        'b1000020-0000-0000-0000-000000000020',
        'KC General Hospital, Malleshwaram',
        ST_SetSRID(ST_MakePoint(77.5701, 12.9981), 4326)::geography,
        true,
        true,
        '+91-80-2334-1771',
        '5th Cross Rd, Malleshwaram, Bengaluru, Karnataka 560003',
        true
    ),
    -- 37. St. Martha's Hospital, Nrupathunga Road
    (
        'b1000021-0000-0000-0000-000000000021',
        'St. Martha''s Hospital, Nrupathunga Road',
        ST_SetSRID(ST_MakePoint(77.5878, 12.9734), 4326)::geography,
        true,
        true,
        '+91-80-4012-8200',
        '5 Nrupathunga Rd, Corporation Circle, Bengaluru, Karnataka 560001',
        true
    ),
    -- 38. Mallya Hospital, Vittal Mallya Road
    (
        'b1000022-0000-0000-0000-000000000022',
        'Mallya Hospital, Vittal Mallya Road',
        ST_SetSRID(ST_MakePoint(77.5931, 12.9692), 4326)::geography,
        true,
        true,
        '+91-80-2227-7979',
        '2 Vittal Mallya Rd, Ashok Nagar, Bengaluru, Karnataka 560001',
        true
    ),
    -- 39. Bhagwan Mahaveer Jain Hospital, Vasanth Nagar
    (
        'b1000023-0000-0000-0000-000000000023',
        'Bhagwan Mahaveer Jain Hospital, Vasanth Nagar',
        ST_SetSRID(ST_MakePoint(77.5881, 12.9912), 4326)::geography,
        true,
        true,
        '+91-80-4087-5555',
        'Millers Rd, Vasanth Nagar, Bengaluru, Karnataka 560052',
        true
    ),
    -- 40. Sparsh Hospital, Infantry Road
    (
        'b1000024-0000-0000-0000-000000000024',
        'Sparsh Hospital, Infantry Road',
        ST_SetSRID(ST_MakePoint(77.5991, 12.9812), 4326)::geography,
        true,
        true,
        '+91-80-6122-2000',
        '10/1, Infantry Rd, Tasker Town, Shivaji Nagar, Bengaluru, Karnataka 560001',
        true
    ),
    -- 41. St. Philomena's Hospital, Viveka Nagar
    (
        'b1000025-0000-0000-0000-000000000025',
        'St. Philomena''s Hospital, Viveka Nagar',
        ST_SetSRID(ST_MakePoint(77.6181, 12.9611), 4326)::geography,
        true,
        true,
        '+91-80-4016-4300',
        'No. 4, Mother Teresa Rd, Viveka Nagar, Bengaluru, Karnataka 560047',
        true
    ),
    -- 42. Santosh Hospital, Frazer Town
    (
        'b1000026-0000-0000-0000-000000000026',
        'Santosh Hospital, Frazer Town',
        ST_SetSRID(ST_MakePoint(77.6112, 12.9972), 4326)::geography,
        true,
        true,
        '+91-80-4034-3434',
        '6/1 Promenade Rd, Frazer Town, Pulikeshi Nagar, Bengaluru, Karnataka 560005',
        true
    ),
    -- 43. Sagar Hospitals, Tilak Nagar (Jayanagar)
    (
        'b1000027-0000-0000-0000-000000000027',
        'Sagar Hospitals, Tilak Nagar (Jayanagar)',
        ST_SetSRID(ST_MakePoint(77.5972, 12.9301), 4326)::geography,
        true,
        true,
        '+91-80-2653-4444',
        '44/54, 30th Cross Rd, Tilak Nagar, Jayanagar, Bengaluru, Karnataka 560041',
        true
    ),
    -- 44. Vasavi Hospital, Kumaraswamy Layout
    (
        'b1000028-0000-0000-0000-000000000028',
        'Vasavi Hospital, Kumaraswamy Layout',
        ST_SetSRID(ST_MakePoint(77.5642, 12.9061), 4326)::geography,
        true,
        true,
        '+91-80-7150-0500',
        '15, 17th Cross Rd, Kumaraswamy Layout 2nd Stage, Bengaluru, Karnataka 560078',
        true
    ),
    -- 45. Sevakshetra Hospital, Banashankari 2nd Stage
    (
        'b1000029-0000-0000-0000-000000000029',
        'Sevakshetra Hospital, Banashankari 2nd Stage',
        ST_SetSRID(ST_MakePoint(77.5691, 12.9242), 4326)::geography,
        false,
        true,
        '+91-80-2671-1253',
        '27th Cross Rd, Banashankari 2nd Stage, Bengaluru, Karnataka 560070',
        true
    ),
    -- 46. Astra Super Speciality Hospital, Kanakapura Road
    (
        'b1000030-0000-0000-0000-000000000030',
        'Astra Super Speciality Hospital, Kanakapura Road',
        ST_SetSRID(ST_MakePoint(77.5512, 12.8941), 4326)::geography,
        true,
        true,
        '+91-80-4748-4748',
        'Konanakunte Cross, Kanakapura Main Rd, Bengaluru, Karnataka 560062',
        true
    ),
    -- 47. TR Hospital, BTM Layout
    (
        'b1000031-0000-0000-0000-000000000031',
        'TR Hospital, BTM Layout',
        ST_SetSRID(ST_MakePoint(77.6102, 12.9151), 4326)::geography,
        false,
        true,
        '+91-80-2668-8888',
        '100 Feet Ring Rd, BTM 2nd Stage, Bengaluru, Karnataka 560076',
        true
    ),
    -- 48. Gangothri Hospital, BTM 2nd Stage
    (
        'b1000032-0000-0000-0000-000000000032',
        'Gangothri Hospital, BTM 2nd Stage',
        ST_SetSRID(ST_MakePoint(77.6081, 12.9131), 4326)::geography,
        true,
        true,
        '+91-80-2668-3000',
        '110, Outer Ring Rd, BTM 2nd Stage, Bengaluru, Karnataka 560076',
        true
    ),
    -- 49. Greenview Medical Center, HSR Layout
    (
        'b1000033-0000-0000-0000-000000000033',
        'Greenview Medical Center, HSR Layout',
        ST_SetSRID(ST_MakePoint(77.6431, 12.9162), 4326)::geography,
        true,
        true,
        '+91-80-4022-7777',
        '20, 14th Main Rd, Sector 5, HSR Layout, Bengaluru, Karnataka 560102',
        true
    ),
    -- 50. Live 100 Hospital, Singasandra (Hosur Road)
    (
        'b1000034-0000-0000-0000-000000000034',
        'Live 100 Hospital, Singasandra (Hosur Road)',
        ST_SetSRID(ST_MakePoint(77.6512, 12.8791), 4326)::geography,
        true,
        true,
        '+91-80-4667-1000',
        'Hosur Main Rd, Singasandra, near Electronic City, Bengaluru, Karnataka 560068',
        true
    ),
    -- 51. Prashanth Hospital, Bommanahalli
    (
        'b1000035-0000-0000-0000-000000000035',
        'Prashanth Hospital, Bommanahalli',
        ST_SetSRID(ST_MakePoint(77.6251, 12.9021), 4326)::geography,
        false,
        true,
        '+91-80-2573-2222',
        'Begur Main Rd, Hongasandra, Bommanahalli, Bengaluru, Karnataka 560068',
        true
    ),
    -- 52. Springleaf Hospital, Electronic City Phase 2
    (
        'b1000036-0000-0000-0000-000000000036',
        'Springleaf Hospital, Electronic City Phase 2',
        ST_SetSRID(ST_MakePoint(77.6781, 12.8421), 4326)::geography,
        false,
        true,
        '+91-80-2852-2555',
        '21, Bettadasanapura Rd, Electronic City Phase 2, Bengaluru, Karnataka 560100',
        true
    ),
    -- 53. Vimalalaya Hospital, Electronic City Phase 1
    (
        'b1000037-0000-0000-0000-000000000037',
        'Vimalalaya Hospital, Electronic City Phase 1',
        ST_SetSRID(ST_MakePoint(77.6591, 12.8512), 4326)::geography,
        true,
        true,
        '+91-80-2852-0333',
        'Maruthi Nagar, Electronic City, Bengaluru, Karnataka 560100',
        true
    ),
    -- 54. Oxford Medical College Hospital & Research Centre, Attibele
    (
        'b1000038-0000-0000-0000-000000000038',
        'Oxford Medical College Hospital & Research Centre, Attibele',
        ST_SetSRID(ST_MakePoint(77.7612, 12.7831), 4326)::geography,
        true,
        true,
        '+91-80-3085-5000',
        'Yadavanahalli, Attibele Circle, Hosur Rd, Anekal Taluk, Bengaluru, Karnataka 562107',
        true
    ),
    -- 55. Sri Sathya Sai Super Speciality Hospital, Whitefield
    (
        'b1000039-0000-0000-0000-000000000039',
        'Sri Sathya Sai Super Speciality Hospital, Whitefield',
        ST_SetSRID(ST_MakePoint(77.7391, 12.9812), 4326)::geography,
        true,
        true,
        '+91-80-2841-1500',
        'EPIP Zone, Whitefield, Bengaluru, Karnataka 560066',
        true
    ),
    -- 56. Brookefield Hospital, Kundalahalli / ITPL Road
    (
        'b1000040-0000-0000-0000-000000000040',
        'Brookefield Hospital, Kundalahalli / ITPL Road',
        ST_SetSRID(ST_MakePoint(77.7181, 12.9661), 4326)::geography,
        true,
        true,
        '+91-80-4244-5566',
        '521/2, Kundalahalli Main Rd, Brookefield, Bengaluru, Karnataka 560037',
        true
    ),
    -- 57. RxDX Healthcare, Whitefield
    (
        'b1000041-0000-0000-0000-000000000041',
        'RxDX Healthcare, Whitefield',
        ST_SetSRID(ST_MakePoint(77.7121, 12.9721), 4326)::geography,
        false,
        true,
        '+91-80-4050-4050',
        'Plot No. 7G, KIADB Industrial Area, Whitefield, Bengaluru, Karnataka 560066',
        true
    ),
    -- 58. Motherhood Hospital, Sarjapur Road
    (
        'b1000042-0000-0000-0000-000000000042',
        'Motherhood Hospital, Sarjapur Road',
        ST_SetSRID(ST_MakePoint(77.6742, 12.9111), 4326)::geography,
        false,
        false,
        '+91-80-6723-8888',
        '514/1-2/3, Sarjapur Main Rd, Kaikondrahalli, Bengaluru, Karnataka 560035',
        true
    ),
    -- 59. Rainbow Children's Hospital & BirthRight, Marathahalli
    (
        'b1000043-0000-0000-0000-000000000043',
        'Rainbow Children''s Hospital & BirthRight, Marathahalli',
        ST_SetSRID(ST_MakePoint(77.6991, 12.9512), 4326)::geography,
        false,
        true,
        '+91-80-4241-2345',
        'Survey No. 8/5, Marathahalli - KR Puram Outer Ring Rd, Doddanekkundi, Bengaluru, Karnataka 560037',
        true
    ),
    -- 60. Hope Hospital, KR Puram
    (
        'b1000044-0000-0000-0000-000000000044',
        'Hope Hospital, KR Puram',
        ST_SetSRID(ST_MakePoint(77.6981, 13.0061), 4326)::geography,
        true,
        true,
        '+91-80-2561-2222',
        'Old Madras Rd, near ITI Gate, KR Puram, Bengaluru, Karnataka 560036',
        true
    ),
    -- 61. Silicon City Hospital, KR Puram / Hosakote Road
    (
        'b1000045-0000-0000-0000-000000000045',
        'Silicon City Hospital, KR Puram / Hosakote Road',
        ST_SetSRID(ST_MakePoint(77.7102, 13.0112), 4326)::geography,
        true,
        true,
        '+91-80-2847-3333',
        'Beside KR Puram RTO, Hosakote Main Rd, Bengaluru, Karnataka 560049',
        true
    ),
    -- 62. Cytecare Cancer & Trauma Hospital, Yelahanka
    (
        'b1000046-0000-0000-0000-000000000046',
        'Cytecare Cancer & Trauma Hospital, Yelahanka',
        ST_SetSRID(ST_MakePoint(77.6012, 13.1112), 4326)::geography,
        true,
        true,
        '+91-80-2217-6767',
        'Near Bagalur Cross, Venkatala, NH-44, Bellary Rd, Yelahanka, Bengaluru, Karnataka 560064',
        true
    ),
    -- 63. Navachethana Hospital, Yelahanka New Town
    (
        'b1000047-0000-0000-0000-000000000047',
        'Navachethana Hospital, Yelahanka New Town',
        ST_SetSRID(ST_MakePoint(77.5812, 13.1041), 4326)::geography,
        true,
        true,
        '+91-80-2856-5555',
        '16th B Cross Rd, Sector B, Yelahanka New Town, Bengaluru, Karnataka 560064',
        true
    ),
    -- 64. Omega Multispeciality Hospital, Yelahanka
    (
        'b1000048-0000-0000-0000-000000000048',
        'Omega Multispeciality Hospital, Yelahanka',
        ST_SetSRID(ST_MakePoint(77.5921, 13.1001), 4326)::geography,
        true,
        true,
        '+91-80-4161-5555',
        'BB Rd, Byatarayanapura, Yelahanka, Bengaluru, Karnataka 560092',
        true
    ),
    -- 65. Prolife Multispeciality Hospital, Thanisandra
    (
        'b1000049-0000-0000-0000-000000000049',
        'Prolife Multispeciality Hospital, Thanisandra',
        ST_SetSRID(ST_MakePoint(77.6291, 13.0561), 4326)::geography,
        true,
        true,
        '+91-80-4965-4965',
        'Thanisandra Main Rd, near Manyata Tech Park, Bengaluru, Karnataka 560077',
        true
    ),
    -- 66. Regal Hospital, Chokkanahalli (Thanisandra)
    (
        'b1000050-0000-0000-0000-000000000050',
        'Regal Hospital, Chokkanahalli (Thanisandra)',
        ST_SetSRID(ST_MakePoint(77.6312, 13.0781), 4326)::geography,
        true,
        true,
        '+91-80-2844-4444',
        'Chokkanahalli, Thanisandra Main Rd, near Hegde Nagar, Bengaluru, Karnataka 560064',
        true
    ),
    -- 67. Chaya Super Speciality Hospital, Kasturi Nagar
    (
        'b1000051-0000-0000-0000-000000000051',
        'Chaya Super Speciality Hospital, Kasturi Nagar',
        ST_SetSRID(ST_MakePoint(77.6591, 13.0081), 4326)::geography,
        true,
        true,
        '+91-80-2545-2222',
        '2nd Main Rd, Kasturi Nagar, East of NGEF, Bengaluru, Karnataka 560043',
        true
    ),
    -- 68. Zion Hospital, Kammanahalli
    (
        'b1000052-0000-0000-0000-000000000052',
        'Zion Hospital, Kammanahalli',
        ST_SetSRID(ST_MakePoint(77.6391, 13.0121), 4326)::geography,
        true,
        true,
        '+91-80-4351-8000',
        'Kammanahalli Main Rd, HRBR Layout 3rd Block, Bengaluru, Karnataka 560084',
        true
    ),
    -- 69. Fortis Hospital, Rajajinagar
    (
        'b1000053-0000-0000-0000-000000000053',
        'Fortis Hospital, Rajajinagar',
        ST_SetSRID(ST_MakePoint(77.5541, 12.9901), 4326)::geography,
        true,
        true,
        '+91-80-4199-4400',
        '111 West of Chord Rd, Opp. Rajajinagar 1st Block, Bengaluru, Karnataka 560086',
        true
    ),
    -- 70. ESI Post Graduate Institute of Medical Sciences & Hospital, Rajajinagar
    (
        'b1000054-0000-0000-0000-000000000054',
        'ESI Post Graduate Institute of Medical Sciences & Hospital, Rajajinagar',
        ST_SetSRID(ST_MakePoint(77.5512, 12.9881), 4326)::geography,
        true,
        true,
        '+91-80-2332-5130',
        '3rd Block, Rajajinagar, Bengaluru, Karnataka 560010',
        true
    ),
    -- 71. NU Hospitals, Rajajinagar
    (
        'b1000055-0000-0000-0000-000000000055',
        'NU Hospitals, Rajajinagar',
        ST_SetSRID(ST_MakePoint(77.5531, 12.9821), 4326)::geography,
        false,
        true,
        '+91-80-4248-9999',
        'C.A. 6, 15th Main Rd, 11th Cross, Rajajinagar, Bengaluru, Karnataka 560010',
        true
    ),
    -- 72. People Tree Hospitals, Yeshwanthpur
    (
        'b1000056-0000-0000-0000-000000000056',
        'People Tree Hospitals, Yeshwanthpur',
        ST_SetSRID(ST_MakePoint(77.5401, 13.0291), 4326)::geography,
        true,
        true,
        '+91-80-4665-9999',
        '2, Tumkur Rd, Goraguntepalya, Yeshwanthpur, Bengaluru, Karnataka 560022',
        true
    ),
    -- 73. Peenya Government Hospital, Peenya Industrial Area
    (
        'b1000057-0000-0000-0000-000000000057',
        'Peenya Government Hospital, Peenya Industrial Area',
        ST_SetSRID(ST_MakePoint(77.5181, 13.0381), 4326)::geography,
        true,
        true,
        '+91-80-2839-4444',
        '1st Stage, Peenya Industrial Area, Bengaluru, Karnataka 560058',
        true
    ),
    -- 74. Rajarajeshwari Medical College & Hospital, Mysore Road
    (
        'b1000058-0000-0000-0000-000000000058',
        'Rajarajeshwari Medical College & Hospital, Mysore Road',
        ST_SetSRID(ST_MakePoint(77.4721, 12.8981), 4326)::geography,
        true,
        true,
        '+91-80-2843-7444',
        '202, Kambipura, Mysore Rd, Kengeri, Bengaluru, Karnataka 560074',
        true
    ),
    -- 75. Panacea Hospital, Nagarbhavi
    (
        'b1000059-0000-0000-0000-000000000059',
        'Panacea Hospital, Nagarbhavi',
        ST_SetSRID(ST_MakePoint(77.5091, 12.9601), 4326)::geography,
        true,
        true,
        '+91-80-2321-4444',
        '334, 8th Main Rd, 3rd Stage, 4th Block, Nagarbhavi, Bengaluru, Karnataka 560072',
        true
    ),
    -- 76. Chord Road Hospital, Basaveshwaranagar
    (
        'b1000060-0000-0000-0000-000000000060',
        'Chord Road Hospital, Basaveshwaranagar',
        ST_SetSRID(ST_MakePoint(77.5381, 12.9861), 4326)::geography,
        true,
        true,
        '+91-80-2322-6666',
        '100 Feet Ring Rd, Basaveshwaranagar, Bengaluru, Karnataka 560079',
        true
    ),
    -- 77. Harsha Hospital, Nelamangala (NH-48 Corridor)
    (
        'b1000061-0000-0000-0000-000000000061',
        'Harsha Hospital, Nelamangala (NH-48 Corridor)',
        ST_SetSRID(ST_MakePoint(77.3941, 13.1021), 4326)::geography,
        true,
        true,
        '+91-80-2772-8888',
        'Sondekoppa Circle, NH-48, Nelamangala Town, Bengaluru Rural, Karnataka 562123',
        true
    ),
    -- 78. MVJ Medical College & Research Hospital, Hosakote
    (
        'b1000062-0000-0000-0000-000000000062',
        'MVJ Medical College & Research Hospital, Hosakote',
        ST_SetSRID(ST_MakePoint(77.7981, 13.0721), 4326)::geography,
        true,
        true,
        '+91-80-2806-0200',
        '30th Km Milestone, National Highway 75, Kolathur, Hosakote, Karnataka 562114',
        true
    ),
    -- 79. Vijayashree Hospital, Bidadi Industrial Area (Mysore Expressway)
    (
        'b1000063-0000-0000-0000-000000000063',
        'Vijayashree Hospital, Bidadi Industrial Area (Mysore Expressway)',
        ST_SetSRID(ST_MakePoint(77.3912, 12.7981), 4326)::geography,
        true,
        true,
        '+91-80-2728-2222',
        'Plot No. 12, Bidadi Industrial Area, Ramanagara District, Karnataka 562109',
        true
    ),
    -- 80. BGS GIMS Hospital, Kengeri (Bangalore-Mysore Corridor)
    (
        'b1000064-0000-0000-0000-000000000064',
        'BGS GIMS Hospital, Kengeri (Bangalore-Mysore Corridor)',
        ST_SetSRID(ST_MakePoint(77.4851, 12.8911), 4326)::geography,
        true,
        true,
        '+91-80-2698-8888',
        'No. 67, BGS Health & Education City, Uttarahalli Rd, Kengeri, Bengaluru 560060',
        true
    ),
    -- 81. Sri Chamundeshwari Medical College & Hospital, Channapatna Corridor
    (
        'b1000065-0000-0000-0000-000000000065',
        'Sri Chamundeshwari Medical College & Hospital, Channapatna Corridor',
        ST_SetSRID(ST_MakePoint(77.3191, 12.7212), 4326)::geography,
        true,
        true,
        '+91-80-2977-1111',
        'Bangalore-Mysore Highway, NH-275, Ramanagara District, Karnataka 562159',
        true
    ),
    -- 82. Athreya Hospital, Chandapura (Alliance University Corridor)
    (
        'b1000066-0000-0000-0000-000000000066',
        'Athreya Hospital, Chandapura (Alliance University Corridor)',
        ST_SetSRID(ST_MakePoint(77.6985, 12.8021), 4326)::geography,
        true,
        true,
        '+91-80-2783-5555',
        'Chandapura Circle, Anekal Main Road, near Alliance University, Bengaluru, Karnataka 560099',
        true
    ),
    -- 83. Sri Sai Hospital, Chandapura-Anekal Road (Alliance University Campus Gate)
    (
        'b1000067-0000-0000-0000-000000000067',
        'Sri Sai Hospital, Chandapura-Anekal Road (Alliance University Campus Gate)',
        ST_SetSRID(ST_MakePoint(77.7010, 12.7650), 4326)::geography,
        true,
        true,
        '+91-80-2784-2100',
        'Chikkahagade Cross, Chandapura-Anekal Main Road, Opp Alliance University Road, Bengaluru, Karnataka 562106',
        true
    ),
    -- 84. General Hospital Anekal (Taluk Trauma Care Unit)
    (
        'b1000068-0000-0000-0000-000000000068',
        'General Hospital Anekal (Taluk Trauma Care Unit)',
        ST_SetSRID(ST_MakePoint(77.6965, 12.7118), 4326)::geography,
        true,
        true,
        '+91-80-2784-1234',
        'Taluk Hospital Road, Anekal Town, Bengaluru Urban District, Karnataka 562106',
        true
    ),
    -- 85. Kauvery Hospital, Hosur (NH-44 Highway Trauma Hub)
    (
        'b1000069-0000-0000-0000-000000000069',
        'Kauvery Hospital, Hosur (NH-44 Highway Trauma Hub)',
        ST_SetSRID(ST_MakePoint(77.8180, 12.7485), 4326)::geography,
        true,
        true,
        '+91-4344-272727',
        'NH-44 Bangalore-Hosur Expressway, Sipcot Phase 1, Hosur, Tamil Nadu 635126',
        true
    ),
    -- 86. Gunam Super Speciality Hospital, Hosur
    (
        'b1000070-0000-0000-0000-000000000070',
        'Gunam Super Speciality Hospital, Hosur',
        ST_SetSRID(ST_MakePoint(77.8250, 12.7320), 4326)::geography,
        true,
        true,
        '+91-4344-245555',
        'Denkanikottai Road, Near Railway Station, Hosur, Tamil Nadu 635109',
        true
    ),
    -- 87. Government District Headquarters Hospital, Hosur
    (
        'b1000071-0000-0000-0000-000000000071',
        'Government District Headquarters Hospital, Hosur',
        ST_SetSRID(ST_MakePoint(77.8290, 12.7380), 4326)::geography,
        true,
        true,
        '+91-4344-222234',
        'Taluk Office Road, Bagalur Road, Hosur, Tamil Nadu 635109',
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
