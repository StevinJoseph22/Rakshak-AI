export type ConnectionStatus = 'connected' | 'reconnecting' | 'disconnected';

export interface Hospital {
  id: string;
  name: string;
  phone: string;
  address: string;
  has_trauma_center: boolean;
  has_icu_capacity: boolean;
  is_verified: boolean;
  latitude: number;
  longitude: number;
  distance_km?: number;
  road_distance_km?: number;
}

export interface RejectionRecord {
  hospital_id: string;
  hospital_name: string;
  reason: string;
  created_at: string;
}

export interface IncidentPayload {
  id: string;
  latitude: number;
  longitude: number;
  distance_km: number | null;
  road_distance_km?: number | null;
  created_at: string | Date;
  imageUrl: string | null;
  hospital_id?: string;
  hospital_name?: string;
  matched_hospitals_count?: number;
  matched_hospitals?: Hospital[];
  victim_metadata?: Record<string, unknown> | null;
  status?: 'detected' | 'broadcasting' | 'accepted' | 'en_route' | 'resolved' | 'escalated' | 'unmatched';
  accepted_hospital_id?: string | null;
  accepted_hospital_name?: string;
  escalated?: boolean;
  case_locked?: boolean;
  rejections?: RejectionRecord[];
}

