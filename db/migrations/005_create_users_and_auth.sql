-- Migration: 005_create_users_and_auth.sql
-- Description: Create RBAC users table and seed pre-configured logins for all 81 hospitals, police, and ambulance.

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

-- Pre-hashed bcrypt hashes:
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
    -- 7. Chinmaya Mission Hospital, Indiranagar
    ('chinmaya_mission', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', '77777777-7777-7777-7777-777777777777'),
    -- 8. Narayana Multispeciality Hospital, HSR Layout
    ('narayana_hsr', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', '88888888-8888-8888-8888-888888888888'),
    -- 9. Sagar Hospitals, DSI Campus
    ('sagar_dsi', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', '99999999-9999-9999-9999-999999999999'),
    -- 10. Fortis Hospital, Bannerghatta Road
    ('fortis_bg', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
    -- 11. Columbia Asia Hospital, Hebbal
    ('columbia_hebbal', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
    -- 12. Columbia Asia Hospital, Whitefield
    ('columbia_whitefield', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
    -- 13. Sakra World Hospital, Marathahalli
    ('sakra_marathahalli', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'dddddddd-dddd-dddd-dddd-dddddddddddd'),
    -- 14. BGS Gleneagles Global Hospitals, Kengeri
    ('bgs_kengeri', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'),
    -- 15. Sparsh Super Speciality Hospital, Yeshwanthpur
    ('sparsh_yeshwanthpur', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'ffffffff-ffff-ffff-ffff-ffffffffffff'),
    -- 16. Vydehi Hospital, Whitefield
    ('vydehi_whitefield', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'a1000001-0000-0000-0000-000000000001'),
    -- 17. Baptist Hospital, Hebbal
    ('baptist_hebbal', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'a1000002-0000-0000-0000-000000000002'),
    -- 18. Aster CMI Hospital, Hebbal
    ('aster_hebbal', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000002-0000-0000-0000-000000000002'),
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
    -- 26. Specialist Hospital, Banaswadi / HRBR Layout
    ('specialist_banaswadi', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000010-0000-0000-0000-000000000010'),
    -- 27. Cratis Hospital, Hennur / Kothanur
    ('cratis_kothanur', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000011-0000-0000-0000-000000000011'),
    -- 28. NIMHANS Neuro-Trauma Center, Hosur Road
    ('nimhans_trauma', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000012-0000-0000-0000-000000000012'),
    -- 29. Sri Jayadeva Institute of Cardiovascular Sciences, Jayanagar
    ('jayadeva_cardiac', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000013-0000-0000-0000-000000000013'),
    -- 30. Narayana Health City (Mazumdar Shaw Medical Center), Bommasandra
    ('narayana_bommasandra', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000014-0000-0000-0000-000000000014'),
    -- 31. Kauvery Hospital, Electronic City Phase 1
    ('kauvery_ecity', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000015-0000-0000-0000-000000000015'),
    -- 32. Manipal Hospital, Sarjapur Road
    ('manipal_sarjapur', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000016-0000-0000-0000-000000000016'),
    -- 33. Manipal Hospital, Jayanagar
    ('manipal_jayanagar', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000017-0000-0000-0000-000000000017'),
    -- 34. Manipal Hospital, Malleshwaram
    ('manipal_malleshwaram', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000018-0000-0000-0000-000000000018'),
    -- 35. Manipal Hospital, Yeshwanthpur
    ('manipal_yeshwanthpur_brigade', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000019-0000-0000-0000-000000000019'),
    -- 36. KC General Hospital, Malleshwaram
    ('kc_general', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000020-0000-0000-0000-000000000020'),
    -- 37. St. Martha's Hospital, Nrupathunga Road
    ('st_marthas', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000021-0000-0000-0000-000000000021'),
    -- 38. Mallya Hospital, Vittal Mallya Road
    ('mallya_hospital', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000022-0000-0000-0000-000000000022'),
    -- 39. Bhagwan Mahaveer Jain Hospital, Vasanth Nagar
    ('jain_hospital', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000023-0000-0000-0000-000000000023'),
    -- 40. Sparsh Hospital, Infantry Road
    ('sparsh_infantry', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000024-0000-0000-0000-000000000024'),
    -- 41. St. Philomena's Hospital, Viveka Nagar
    ('philomenas_vivekanagar', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000025-0000-0000-0000-000000000025'),
    -- 42. Santosh Hospital, Frazer Town
    ('santosh_frazertown', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000026-0000-0000-0000-000000000026'),
    -- 43. Sagar Hospitals, Tilak Nagar (Jayanagar)
    ('sagar_tilaknagar', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000027-0000-0000-0000-000000000027'),
    -- 44. Vasavi Hospital, Kumaraswamy Layout
    ('vasavi_kumaraswamy', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000028-0000-0000-0000-000000000028'),
    -- 45. Sevakshetra Hospital, Banashankari 2nd Stage
    ('sevakshetra_bsk', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000029-0000-0000-0000-000000000029'),
    -- 46. Astra Super Speciality Hospital, Kanakapura Road
    ('astra_kanakapura', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000030-0000-0000-0000-000000000030'),
    -- 47. TR Hospital, BTM Layout
    ('tr_hospital_btm', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000031-0000-0000-0000-000000000031'),
    -- 48. Gangothri Hospital, BTM 2nd Stage
    ('gangothri_btm', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000032-0000-0000-0000-000000000032'),
    -- 49. Greenview Medical Center, HSR Layout
    ('greenview_hsr', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000033-0000-0000-0000-000000000033'),
    -- 50. Live 100 Hospital, Singasandra (Hosur Road)
    ('live100_singasandra', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000034-0000-0000-0000-000000000034'),
    -- 51. Prashanth Hospital, Bommanahalli
    ('prashanth_bommanahalli', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000035-0000-0000-0000-000000000035'),
    -- 52. Springleaf Hospital, Electronic City Phase 2
    ('springleaf_ecity', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000036-0000-0000-0000-000000000036'),
    -- 53. Vimalalaya Hospital, Electronic City Phase 1
    ('vimalalaya_ecity', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000037-0000-0000-0000-000000000037'),
    -- 54. Oxford Medical College Hospital & Research Centre, Attibele
    ('oxford_attibele', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000038-0000-0000-0000-000000000038'),
    -- 55. Sri Sathya Sai Super Speciality Hospital, Whitefield
    ('sathyasai_whitefield', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000039-0000-0000-0000-000000000039'),
    -- 56. Brookefield Hospital, Kundalahalli / ITPL Road
    ('brookefield_hospital', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000040-0000-0000-0000-000000000040'),
    -- 57. RxDX Healthcare, Whitefield
    ('rxdx_whitefield', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000041-0000-0000-0000-000000000041'),
    -- 58. Motherhood Hospital, Sarjapur Road
    ('motherhood_sarjapur', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000042-0000-0000-0000-000000000042'),
    -- 59. Rainbow Children's Hospital & BirthRight, Marathahalli
    ('rainbow_marathahalli', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000043-0000-0000-0000-000000000043'),
    -- 60. Hope Hospital, KR Puram
    ('hope_krpuram', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000044-0000-0000-0000-000000000044'),
    -- 61. Silicon City Hospital, KR Puram / Hosakote Road
    ('siliconcity_krpuram', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000045-0000-0000-0000-000000000045'),
    -- 62. Cytecare Cancer & Trauma Hospital, Yelahanka
    ('cytecare_yelahanka', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000046-0000-0000-0000-000000000046'),
    -- 63. Navachethana Hospital, Yelahanka New Town
    ('navachethana_yelahanka', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000047-0000-0000-0000-000000000047'),
    -- 64. Omega Multispeciality Hospital, Yelahanka
    ('omega_yelahanka', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000048-0000-0000-0000-000000000048'),
    -- 65. Prolife Multispeciality Hospital, Thanisandra
    ('prolife_thanisandra', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000049-0000-0000-0000-000000000049'),
    -- 66. Regal Hospital, Chokkanahalli (Thanisandra)
    ('regal_thanisandra', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000050-0000-0000-0000-000000000050'),
    -- 67. Chaya Super Speciality Hospital, Kasturi Nagar
    ('chaya_kasturinagar', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000051-0000-0000-0000-000000000051'),
    -- 68. Zion Hospital, Kammanahalli
    ('zion_kammanahalli', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000052-0000-0000-0000-000000000052'),
    -- 69. Fortis Hospital, Rajajinagar
    ('fortis_rajajinagar', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000053-0000-0000-0000-000000000053'),
    -- 70. ESI Post Graduate Institute of Medical Sciences & Hospital, Rajajinagar
    ('esi_rajajinagar', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000054-0000-0000-0000-000000000054'),
    -- 71. NU Hospitals, Rajajinagar
    ('nu_rajajinagar', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000055-0000-0000-0000-000000000055'),
    -- 72. People Tree Hospitals, Yeshwanthpur
    ('peopletree_yeshwanthpur', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000056-0000-0000-0000-000000000056'),
    -- 73. Peenya Government Hospital, Peenya Industrial Area
    ('peenya_govt_hospital', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000057-0000-0000-0000-000000000057'),
    -- 74. Rajarajeshwari Medical College & Hospital, Mysore Road
    ('rajarajeshwari_mysorerd', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000058-0000-0000-0000-000000000058'),
    -- 75. Panacea Hospital, Nagarbhavi
    ('panacea_nagarbhavi', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000059-0000-0000-0000-000000000059'),
    -- 76. Chord Road Hospital, Basaveshwaranagar
    ('chordroad_basaveshwaranagar', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000060-0000-0000-0000-000000000060'),
    -- 77. Harsha Hospital, Nelamangala (NH-48 Corridor)
    ('harsha_nelamangala', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000061-0000-0000-0000-000000000061'),
    -- 78. MVJ Medical College & Research Hospital, Hosakote
    ('mvj_hosakote', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000062-0000-0000-0000-000000000062'),
    -- 79. Vijayashree Hospital, Bidadi Industrial Area (Mysore Expressway)
    ('vijayashree_bidadi', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000063-0000-0000-0000-000000000063'),
    -- 80. BGS GIMS Hospital, Kengeri (Bangalore-Mysore Corridor)
    ('bgs_gims_kengeri', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000064-0000-0000-0000-000000000064'),
    -- 81. Sri Chamundeshwari Medical College & Hospital, Channapatna Corridor
    ('chamundeshwari_channapatna', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000065-0000-0000-0000-000000000065'),
    -- 82. Athreya Hospital, Chandapura (Alliance University Corridor)
    ('athreya_chandapura', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000066-0000-0000-0000-000000000066'),
    -- 83. Sri Sai Hospital, Chandapura-Anekal Road (Alliance University Campus Gate)
    ('srisai_anekal', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000067-0000-0000-0000-000000000067'),
    -- 84. General Hospital Anekal (Taluk Trauma Care Unit)
    ('gh_anekal', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000068-0000-0000-0000-000000000068'),
    -- 85. Kauvery Hospital, Hosur (NH-44 Highway Trauma Hub)
    ('kauvery_hosur', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000069-0000-0000-0000-000000000069'),
    -- 86. Gunam Super Speciality Hospital, Hosur
    ('gunam_hosur', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000070-0000-0000-0000-000000000070'),
    -- 87. Government District Headquarters Hospital, Hosur
    ('hosur_gh', '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', 'b1000071-0000-0000-0000-000000000071'),
    -- Police Control Room Account
    ('police_control', '$2b$10$8V9LitbF8Crn0quecd3o3u6YNXEHoLi6YlIORmh.XjR.UHeiu7OqO', 'police', NULL),
    -- Ambulance Pilot Account
    ('ambulance_pilot', '$2b$10$fkI4gnuT0qsFiAF6hBW0MedzBrjs.1L5Fj5d3n.12LlYjy2GGxZ/y', 'ambulance', NULL)
ON CONFLICT (username) DO UPDATE SET
    hospital_id = EXCLUDED.hospital_id,
    role = EXCLUDED.role,
    password_hash = EXCLUDED.password_hash;
