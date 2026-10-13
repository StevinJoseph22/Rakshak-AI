export type IncidentStatus =
  | 'detected'
  | 'broadcasting'
  | 'accepted'
  | 'en_route'
  | 'resolved'
  | 'escalated'
  | 'unmatched'
  | 'suspected'
  | 'cancelled';

export interface Hospital {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  has_trauma_center: boolean;
  has_icu_capacity: boolean;
  phone: string;
  address: string;
  is_verified: boolean;
  distance_km?: number;
  road_distance_km?: number;
  created_at?: string;
  updated_at?: string;
}

export interface Incident {
  id: string;
  latitude: number;
  longitude: number;
  status: IncidentStatus;
  accepted_hospital_id: string | null;
  accepted_hospital?: Hospital | null;
  ambulance_id?: string | null;
  ambulance_plate?: string | null;
  ambulance_driver_name?: string | null;
  ambulance_driver_phone?: string | null;
  ambulance_origin_station?: string | null;
  ambulance_arrived_at?: string | null;
  ambulance_arrival_lat?: number | null;
  ambulance_arrival_lng?: number | null;
  ambulance_location?: {
    latitude: number;
    longitude: number;
    speed_kmh?: number;
    heading?: number;
    updated_at?: string;
  } | null;
  victim_metadata: Record<string, unknown> | null;
  blackspot_info?: BlackspotInfo | null;
  created_at: string;
  updated_at: string;
}

export interface BlackspotInfo {
  is_blackspot: boolean;
  incident_count: number;
  hazard_level: 'High' | 'Severe' | 'Critical';
  zone_name: string;
}

export interface BlackspotZone {
  id: string;
  latitude: number;
  longitude: number;
  radius_meters: number;
  incident_count: number;
  hazard_level: 'High' | 'Severe' | 'Critical';
  zone_name: string;
}

export interface PoliceUnit {
  id: string;
  name: string;
  jurisdiction_area: string;
  contact: string;
  created_at: string;
}

export interface CreateIncidentResponse {
  incident: Incident;
  matched_hospitals: Hospital[];
}

// Phase 13: Role-Based Access Control & Authentication Types
export type UserRole = 'hospital_staff' | 'police' | 'ambulance';

export interface User {
  id: string;
  username: string;
  password_hash: string;
  role: UserRole;
  hospital_id: string | null;
  created_at: string;
}

export interface AuthUser {
  id: string;
  username: string;
  role: UserRole;
  hospital_id: string | null;
  hospital_name?: string | null;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}
