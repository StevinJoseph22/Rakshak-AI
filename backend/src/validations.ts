import { z } from 'zod';

export const createIncidentSchema = z.object({
  latitude: z
    .number({
      required_error: 'Latitude is required',
      invalid_type_error: 'Latitude must be a valid number',
    })
    .min(-90, 'Latitude must be >= -90')
    .max(90, 'Latitude must be <= 90'),
  longitude: z
    .number({
      required_error: 'Longitude is required',
      invalid_type_error: 'Longitude must be a valid number',
    })
    .min(-180, 'Longitude must be >= -180')
    .max(180, 'Longitude must be <= 180'),
  victim_metadata: z.record(z.unknown()).optional().nullable(),
});

export const incidentIdParamsSchema = z.object({
  id: z.string().uuid({ message: 'Incident ID must be a valid UUID' }),
});

export const updateIncidentStatusSchema = z
  .object({
    status: z.enum(
      [
        'detected',
        'broadcasting',
        'accepted',
        'en_route',
        'resolved',
        'escalated',
        'unmatched',
      ],
      {
        errorMap: () => ({
          message:
            "Status must be one of: 'detected', 'broadcasting', 'accepted', 'en_route', 'resolved', 'escalated', 'unmatched'",
        }),
      },
    ),
    accepted_hospital_id: z
      .string()
      .uuid({ message: 'accepted_hospital_id must be a valid UUID' })
      .optional()
      .nullable(),
  })
  .superRefine((data, ctx) => {
    if (data.status === 'accepted' && !data.accepted_hospital_id) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message:
          "Field 'accepted_hospital_id' (valid UUID) is strictly required when transitioning status to 'accepted'.",
        path: ['accepted_hospital_id'],
      });
    }
  });

export const listHospitalsQuerySchema = z.object({
  near: z
    .string()
    .regex(
      /^-?\d+(\.\d+)?,-?\d+(\.\d+)?$/,
      "Query parameter 'near' must be formatted as 'latitude,longitude' (e.g., '12.9343,77.6190')",
    )
    .optional(),
  radius_km: z
    .string()
    .regex(/^\d+(\.\d+)?$/, "'radius_km' must be a positive number")
    .transform(Number)
    .optional(),
});

export const rejectIncidentSchema = z.object({
  hospital_id: z.string().uuid({ message: 'hospital_id must be a valid UUID' }),
  reason: z.string().min(1, { message: 'Rejection reason cannot be empty' }),
});

export const nearbyIncidentsQuerySchema = z.object({
  lat: z
    .string({ required_error: "'lat' is required" })
    .regex(/^-?\d+(\.\d+)?$/, "'lat' must be a valid number")
    .transform(Number)
    .refine((val) => val >= -90 && val <= 90, "'lat' must be between -90 and 90"),
  lng: z
    .string({ required_error: "'lng' is required" })
    .regex(/^-?\d+(\.\d+)?$/, "'lng' must be a valid number")
    .transform(Number)
    .refine((val) => val >= -180 && val <= 180, "'lng' must be between -180 and 180"),
  radius_km: z
    .string()
    .regex(/^\d+(\.\d+)?$/, "'radius_km' must be a positive number")
    .transform(Number)
    .optional()
    .default('15'),
});

export const claimIncidentSchema = z.object({
  ambulance_id: z.string().min(1, { message: 'ambulance_id cannot be empty' }),
});

export const ambulanceLocationSchema = z.object({
  incident_id: z.string().uuid({ message: 'incident_id must be a valid UUID' }),
  ambulance_id: z.string().min(1, { message: 'ambulance_id cannot be empty' }),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  speed_kmh: z.number().optional(),
  heading: z.number().optional(),
});

