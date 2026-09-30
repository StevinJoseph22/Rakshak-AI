export type IncidentStatus =
  | 'detected'
  | 'broadcasting'
  | 'accepted'
  | 'en_route'
  | 'resolved'
  | 'escalated'
  | 'unmatched';

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
  ambulance_location?: {
    latitude: number;
    longitude: number;
    speed_kmh?: number;
    heading?: number;
    updated_at?: string;
  } | null;
  victim_metadata: Record<string, unknown> | null;
  created_at: string;
  updated_at: string;
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
