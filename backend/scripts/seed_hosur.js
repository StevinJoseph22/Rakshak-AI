const { Pool } = require('pg');
const dotenv = require('dotenv');
dotenv.config({ path: __dirname + '/../.env' });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/rakshak_db'
});

async function run() {
  const hospitals = [
    {
      id: 'b1000066-0000-0000-0000-000000000066',
      name: 'Athreya Hospital, Chandapura (Alliance University Corridor)',
      lon: 77.6985, lat: 12.8021,
      phone: '+91-80-2783-5555',
      address: 'Chandapura Circle, Anekal Main Road, near Alliance University, Bengaluru, Karnataka 560099',
      username: 'athreya_chandapura'
    },
    {
      id: 'b1000067-0000-0000-0000-000000000067',
      name: 'Sri Sai Hospital, Chandapura-Anekal Road (Alliance University Campus Gate)',
      lon: 77.7010, lat: 12.7650,
      phone: '+91-80-2784-2100',
      address: 'Chikkahagade Cross, Chandapura-Anekal Main Road, Opp Alliance University Road, Bengaluru, Karnataka 562106',
      username: 'srisai_anekal'
    },
    {
      id: 'b1000068-0000-0000-0000-000000000068',
      name: 'General Hospital Anekal (Taluk Trauma Care Unit)',
      lon: 77.6965, lat: 12.7118,
      phone: '+91-80-2784-1234',
      address: 'Taluk Hospital Road, Anekal Town, Bengaluru Urban District, Karnataka 562106',
      username: 'gh_anekal'
    },
    {
      id: 'b1000069-0000-0000-0000-000000000069',
      name: 'Kauvery Hospital, Hosur (NH-44 Highway Trauma Hub)',
      lon: 77.8180, lat: 12.7485,
      phone: '+91-4344-272727',
      address: 'NH-44 Bangalore-Hosur Expressway, Sipcot Phase 1, Hosur, Tamil Nadu 635126',
      username: 'kauvery_hosur'
    },
    {
      id: 'b1000070-0000-0000-0000-000000000070',
      name: 'Gunam Super Speciality Hospital, Hosur',
      lon: 77.8250, lat: 12.7320,
      phone: '+91-4344-245555',
      address: 'Denkanikottai Road, Near Railway Station, Hosur, Tamil Nadu 635109',
      username: 'gunam_hosur'
    },
    {
      id: 'b1000071-0000-0000-0000-000000000071',
      name: 'Government District Headquarters Hospital, Hosur',
      lon: 77.8290, lat: 12.7380,
      phone: '+91-4344-222234',
      address: 'Taluk Office Road, Bagalur Road, Hosur, Tamil Nadu 635109',
      username: 'hosur_gh'
    }
  ];

  for (const h of hospitals) {
    await pool.query(
      `INSERT INTO hospitals (id, name, location, has_trauma_center, has_icu_capacity, phone, address, is_verified)
       VALUES ($1, $2, ST_SetSRID(ST_MakePoint($3, $4), 4326)::geography, true, true, $5, $6, true)
       ON CONFLICT (id) DO UPDATE SET
         name = EXCLUDED.name,
         location = EXCLUDED.location,
         phone = EXCLUDED.phone,
         address = EXCLUDED.address,
         updated_at = CURRENT_TIMESTAMP`,
      [h.id, h.name, h.lon, h.lat, h.phone, h.address]
    );

    await pool.query(
      `INSERT INTO users (username, password_hash, role, hospital_id)
       VALUES ($1, '$2b$10$TbU3JaLOFvfExHVV0bYTG.TffLOq/v40KPTpKvb4RvrOZkbPxovXO', 'hospital_staff', $2)
       ON CONFLICT (username) DO UPDATE SET
         hospital_id = EXCLUDED.hospital_id,
         updated_at = CURRENT_TIMESTAMP`,
      [h.username, h.id]
    );
  }

  const countRes = await pool.query('SELECT count(*) FROM hospitals');
  console.log('✅ Total hospitals now registered in live DB:', countRes.rows[0].count);
  await pool.end();
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
