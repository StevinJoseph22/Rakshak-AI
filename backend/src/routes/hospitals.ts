import { Router, Request, Response } from 'express';
import { query } from '../db';
import { listHospitalsQuerySchema } from '../validations';
import { Hospital } from '../types';
import { authenticateJWT, requireRole } from '../middleware/auth';
import { broadcastHospitalCapabilitiesUpdated } from '../socket';
import { recordAuditEvent } from '../services/auditService';

export const hospitalsRouter = Router();

export interface HospitalCapabilitiesRecord {
  hospital_id: string;
  ct_scan: boolean;
  mri: boolean;
  neuro_icu: boolean;
  blood_bank: boolean;
  ortho_ot: boolean;
  fast_ultrasound: boolean;
  ventilators: boolean;
  general_surgery: boolean;
  updated_at: string;
  updated_by: string;
}

const DEFAULT_CAPABILITIES = {
  ct_scan: true,
  mri: true,
  neuro_icu: true,
  blood_bank: true,
  ortho_ot: true,
  fast_ultrasound: true,
  ventilators: true,
  general_surgery: true,
};

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
          h.id,
          h.name,
          h.phone,
          h.address,
          h.has_trauma_center,
          h.has_icu_capacity,
          h.is_verified,
          h.source,
          h.last_verified,
          ST_Y(h.location::geometry) AS latitude,
          ST_X(h.location::geometry) AS longitude,
          ROUND((ST_Distance(h.location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography) / 1000)::numeric, 2) AS distance_km,
          h.created_at,
          h.updated_at,
          COALESCE(hc.ct_scan, true) AS ct_scan,
          COALESCE(hc.mri, true) AS mri,
          COALESCE(hc.neuro_icu, true) AS neuro_icu,
          COALESCE(hc.blood_bank, true) AS blood_bank,
          COALESCE(hc.ortho_ot, true) AS ortho_ot,
          COALESCE(hc.fast_ultrasound, true) AS fast_ultrasound,
          COALESCE(hc.ventilators, true) AS ventilators,
          COALESCE(hc.general_surgery, true) AS general_surgery
        FROM hospitals h
        LEFT JOIN hospital_capabilities hc ON hc.hospital_id = h.id
        WHERE ST_DWithin(h.location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $3)
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
        h.id,
        h.name,
        h.phone,
        h.address,
        h.has_trauma_center,
        h.has_icu_capacity,
        h.is_verified,
        h.source,
        h.last_verified,
        ST_Y(h.location::geometry) AS latitude,
        ST_X(h.location::geometry) AS longitude,
        h.created_at,
        h.updated_at,
        COALESCE(hc.ct_scan, true) AS ct_scan,
        COALESCE(hc.mri, true) AS mri,
        COALESCE(hc.neuro_icu, true) AS neuro_icu,
        COALESCE(hc.blood_bank, true) AS blood_bank,
        COALESCE(hc.ortho_ot, true) AS ortho_ot,
        COALESCE(hc.fast_ultrasound, true) AS fast_ultrasound,
        COALESCE(hc.ventilators, true) AS ventilators,
        COALESCE(hc.general_surgery, true) AS general_surgery
      FROM hospitals h
      LEFT JOIN hospital_capabilities hc ON hc.hospital_id = h.id
      ORDER BY h.name ASC;
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

// GET /hospitals/:id/capabilities - Retrieve live capabilities of a hospital
hospitalsRouter.get('/:id/capabilities', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const result = await query<HospitalCapabilitiesRecord>(
      `SELECT * FROM hospital_capabilities WHERE hospital_id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(200).json({
        hospital_id: id,
        capabilities: DEFAULT_CAPABILITIES,
        updated_at: new Date().toISOString(),
        updated_by: 'system_default',
      });
    }

    const row = result.rows[0];
    const capabilities = {
      ct_scan: row.ct_scan,
      mri: row.mri,
      neuro_icu: row.neuro_icu,
      blood_bank: row.blood_bank,
      ortho_ot: row.ortho_ot,
      fast_ultrasound: row.fast_ultrasound,
      ventilators: row.ventilators,
      general_surgery: row.general_surgery,
    };

    return res.status(200).json({
      hospital_id: id,
      capabilities,
      updated_at: row.updated_at,
      updated_by: row.updated_by,
    });
  } catch (error) {
    console.error('[GET /hospitals/:id/capabilities Error]', error);
    return res.status(500).json({
      error: 'Failed to retrieve hospital capabilities',
    });
  }
});

// PUT /hospitals/:id/capabilities - Hospital staff edit their own hospital's capabilities
hospitalsRouter.put(
  '/:id/capabilities',
  authenticateJWT,
  requireRole('hospital_staff', 'admin'),
  async (req: Request, res: Response) => {
    try {
      const { id } = req.params;

      // Hospital Staff Scoping: can edit ONLY their own hospital
      if (req.user!.role === 'hospital_staff' && req.user!.hospital_id !== id) {
        return res.status(403).json({
          error: 'Forbidden',
          message: 'Hospital staff can only update capabilities for their own assigned hospital.',
        });
      }

      const rawCaps = req.body.capabilities || req.body;
      const capabilities = {
        ct_scan: typeof rawCaps.ct_scan === 'boolean' ? rawCaps.ct_scan : true,
        mri: typeof rawCaps.mri === 'boolean' ? rawCaps.mri : true,
        neuro_icu: typeof rawCaps.neuro_icu === 'boolean' ? rawCaps.neuro_icu : true,
        blood_bank: typeof rawCaps.blood_bank === 'boolean' ? rawCaps.blood_bank : true,
        ortho_ot: typeof rawCaps.ortho_ot === 'boolean' ? rawCaps.ortho_ot : true,
        fast_ultrasound: typeof rawCaps.fast_ultrasound === 'boolean' ? rawCaps.fast_ultrasound : true,
        ventilators: typeof rawCaps.ventilators === 'boolean' ? rawCaps.ventilators : true,
        general_surgery: typeof rawCaps.general_surgery === 'boolean' ? rawCaps.general_surgery : true,
      };

      const updatedBy = req.user!.username || req.user!.id;
      const updatedAt = new Date().toISOString();

      const upsertSql = `
        INSERT INTO hospital_capabilities (
          hospital_id,
          ct_scan,
          mri,
          neuro_icu,
          blood_bank,
          ortho_ot,
          fast_ultrasound,
          ventilators,
          general_surgery,
          updated_at,
          updated_by
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, CURRENT_TIMESTAMP, $10)
        ON CONFLICT (hospital_id) DO UPDATE SET
          ct_scan = EXCLUDED.ct_scan,
          mri = EXCLUDED.mri,
          neuro_icu = EXCLUDED.neuro_icu,
          blood_bank = EXCLUDED.blood_bank,
          ortho_ot = EXCLUDED.ortho_ot,
          fast_ultrasound = EXCLUDED.fast_ultrasound,
          ventilators = EXCLUDED.ventilators,
          general_surgery = EXCLUDED.general_surgery,
          updated_at = CURRENT_TIMESTAMP,
          updated_by = EXCLUDED.updated_by
        RETURNING *;
      `;

      await query(upsertSql, [
        id,
        capabilities.ct_scan,
        capabilities.mri,
        capabilities.neuro_icu,
        capabilities.blood_bank,
        capabilities.ortho_ot,
        capabilities.fast_ultrasound,
        capabilities.ventilators,
        capabilities.general_surgery,
        updatedBy,
      ]);

      // 1. Broadcast real-time socket event
      broadcastHospitalCapabilitiesUpdated({
        hospital_id: id,
        capabilities,
        updated_by: updatedBy,
        updated_at: updatedAt,
      });

      // 2. Cryptographic audit log entry
      try {
        await recordAuditEvent({
          action: 'capability_edit',
          entityType: 'hospital',
          entityId: id,
          actorId: req.user!.id,
          actorRole: req.user!.role,
          payload: {
            hospital_id: id,
            capabilities,
            updated_by: updatedBy,
          },
        });
      } catch (auditErr) {
        console.warn('[Audit Log Warning] Audit write deferred:', auditErr);
      }

      return res.status(200).json({
        status: 'SUCCESS',
        hospital_id: id,
        capabilities,
        updated_at: updatedAt,
        updated_by: updatedBy,
      });
    } catch (error) {
      console.error('[PUT /hospitals/:id/capabilities Error]', error);
      return res.status(500).json({
        error: 'Failed to update hospital capabilities',
      });
    }
  }
);
