
export interface PreCrashDataPoint {
  relative_second: number; // -30 to 0
  speed_kmh: number;
  accel_g: number;
  heading_deg?: number;
  timestamp_ms?: number;
}
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
  username?: string;
  password?: string;
  trauma_tier?: string;
  icu_beds?: number;
  blood_bank?: string;
  ct_mri?: boolean;
  zone?: string;
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
  status?: 'detected' | 'broadcasting' | 'accepted' | 'en_route' | 'resolved' | 'escalated' | 'unmatched' | 'suspected' | 'cancelled';
  accepted_hospital_id?: string | null;
  accepted_hospital_name?: string;
  accepted_hospital?: Hospital | null;
  ambulance_id?: string | null;
  ambulance_location?: {
    latitude: number;
    longitude: number;
    speed_kmh?: number;
    heading?: number;
    timestamp?: string;
  } | null;
  escalated?: boolean;
  search_radius?: string;
  case_locked?: boolean;
  rejections?: RejectionRecord[];
  ambulance_plate?: string | null;
  ambulance_driver_name?: string | null;
  ambulance_driver_phone?: string | null;
  ambulance_origin_station?: string | null;
  ambulance_arrived_at?: string | null;
  ambulance_arrival_lat?: number | null;
  ambulance_arrival_lng?: number | null;
    blackspot_info?: BlackspotInfo | null;
  case_number?: string | null;
  police_station_name?: string | null;
  police_officer_name?: string | null;
  police_officer_phone?: string | null;
  pre_crash_telemetry?: PreCrashDataPoint[] | null;
  gridlock_detected?: boolean;
  reassigned_from_ambulance_id?: string | null;
  reassigned_at?: string | null;
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

export interface PreemptedSignalPayload {
  request_id: string;
  intersection_id: string;
  junction_name?: string;
  controller_oid: string;
  status: 'GRANTED' | 'QUEUED' | 'ACTIVE';
  granted_phase: number;
  hold_seconds: number;
  queue_clearance_seconds: number;
  timestamp: string;
  incident_id: string;
  ambulance_id: string;
  ambulance_plate?: string;
  latitude?: number;
  longitude?: number;
}

// Phase 18: Emergency Health Card & ABDM Types
export type HealthCardFieldSource = 'ABDM_VERIFIED' | 'SELF_DECLARED' | 'NONE';
export type HealthCardFieldStatus = 'AVAILABLE' | 'NOT_AVAILABLE';

export interface HealthCardField<T> {
  value: T;
  source: HealthCardFieldSource;
  status: HealthCardFieldStatus;
  reason?: string;
}

export interface EmergencyHealthCard {
  name: HealthCardField<string | null>;
  age_gender: HealthCardField<string | null>;
  abha_address: HealthCardField<string | null>;
  blood_group: HealthCardField<string | null>;
  allergies: HealthCardField<string[]>;
  chronic_conditions: HealthCardField<string[]>;
  current_medications: HealthCardField<string[]>;
  organ_donor_status: HealthCardField<string | null>;
  last_updated: string;
  abdm_mode?: 'SANDBOX' | 'MOCK';
  is_linked?: boolean;
}



// Trauma Facility Capabilities & Clinical Triage Matching
export interface HospitalCapabilities {
  ct_scan: boolean;
  mri: boolean;
  neuro_icu: boolean;
  blood_bank: boolean;
  ortho_ot: boolean;
  fast_ultrasound: boolean;
  ventilators: boolean;
  general_surgery: boolean;
}

export interface CapabilityMatchResult {
  hasMismatch: boolean;
  severity: 'CRITICAL' | 'WARNING' | 'MATCHED';
  suspectedInjuryTitle: string;
  suspectedInjuryDescription: string;
  missingEquipmentNames: string[];
  advisoryText: string;
  recommendedAction: string;
}
