-- 006_add_ambulance_arrival_metadata.sql
-- Adds ambulance origin, vehicle license plate, driver contact details, and on-scene arrival telemetry

ALTER TABLE incidents
ADD COLUMN IF NOT EXISTS ambulance_plate VARCHAR(50) DEFAULT 'KA-01-EA-108',
ADD COLUMN IF NOT EXISTS ambulance_driver_name VARCHAR(100) DEFAULT 'Ramesh Kumar',
ADD COLUMN IF NOT EXISTS ambulance_driver_phone VARCHAR(30) DEFAULT '+91 98450 12345',
ADD COLUMN IF NOT EXISTS ambulance_origin_station VARCHAR(200) DEFAULT 'Manipal Hospital HAL Depot Base',
ADD COLUMN IF NOT EXISTS ambulance_arrived_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS ambulance_arrival_lat NUMERIC,
ADD COLUMN IF NOT EXISTS ambulance_arrival_lng NUMERIC;

CREATE INDEX IF NOT EXISTS idx_incidents_ambulance_arrived_at ON incidents (ambulance_arrived_at);
