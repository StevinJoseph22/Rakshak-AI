import { Router, Request, Response } from 'express';
import { query } from '../db';
import { listHospitalsQuerySchema } from '../validations';
import { Hospital } from '../types';

export const hospitalsRouter = Router();

// GET /hospitals (Optional: ?near=lat,long&radius_km=10)
hospitalsRouter.get('/', async (req: Request, res: Response) => {
  try {
    const parseResult = listHospitalsQuerySchema.safeParse(req.query);
    if (!parseResult.success) {
      return res.status(400).json({
        error: 'Validation failed',
        message: 'Invalid query parameters supplied',
        details: parseResult.error.errors.map((e) => ({
          field: e.path.join('.'),
          message: e.message,
        })),
      });
    }

    const { near, radius_km } = parseResult.data;

    if (near) {
      const [latStr, lngStr] = near.split(',');
      const lat = parseFloat(latStr);
      const lng = parseFloat(lngStr);
      const radiusKm = radius_km || 10;
      const radiusMeters = radiusKm * 1000;

      // PostGIS spatial query ordered by distance
      const sql = `
        SELECT 
          id,
          name,
          phone,
          address,
          has_trauma_center,
          has_icu_capacity,
          is_verified,
          ST_Y(location::geometry) AS latitude,
          ST_X(location::geometry) AS longitude,
          ROUND((ST_Distance(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography) / 1000)::numeric, 2) AS distance_km,
          created_at,
          updated_at
        FROM hospitals
        WHERE ST_DWithin(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $3)
        ORDER BY distance_km ASC;
      `;

      const result = await query<Hospital>(sql, [lng, lat, radiusMeters]);

      return res.json({
        count: result.rowCount,
        center: { latitude: lat, longitude: lng },
        radius_km: radiusKm,
        hospitals: result.rows,
      });
    }

    // Default: Return all hospitals
    const sql = `
      SELECT 
        id,
        name,
        phone,
        address,
        has_trauma_center,
        has_icu_capacity,
        is_verified,
        ST_Y(location::geometry) AS latitude,
        ST_X(location::geometry) AS longitude,
        created_at,
        updated_at
      FROM hospitals
      ORDER BY name ASC;
    `;

    const result = await query<Hospital>(sql);

    return res.json({
      count: result.rowCount,
      hospitals: result.rows,
    });
  } catch (error) {
    console.error('[GET /hospitals Error]', error);
    return res.status(500).json({
      error: 'Database query failed',
      message:
        error instanceof Error
          ? error.message
          : 'Unable to retrieve hospitals at this time.',
    });
  }
});
