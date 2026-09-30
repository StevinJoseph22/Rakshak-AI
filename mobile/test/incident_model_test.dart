import 'package:flutter_test/flutter_test.dart';
import 'package:rakshak_mobile/models/incident_model.dart';

void main() {
  group('Incident Models JSON Parsing', () {
    test('IncidentResponse parses exact Phase 1 backend JSON payload', () {
      final jsonPayload = {
        "message": "Incident reported and nearby trauma centers matched successfully",
        "incident": {
          "id": "c1f7b764-50b3-4f1e-9764-16a73c1fa187",
          "status": "detected",
          "accepted_hospital_id": null,
          "victim_metadata": {
            "vehicle_type": "car",
            "airbag_deployed": true
          },
          "latitude": 12.9716,
          "longitude": 77.5946,
          "created_at": "2026-09-24T13:45:00.000Z",
          "updated_at": "2026-09-24T13:45:00.000Z"
        },
        "search_radius_km": 8.0,
        "matched_hospitals_count": 2,
        "matched_hospitals": [
          {
            "id": "hosp-1",
            "name": "Manipal Hospital HAL",
            "phone": "+91-80-2502-4444",
            "address": "98 HAL Airport Rd, Bangalore",
            "has_trauma_center": true,
            "has_icu_capacity": true,
            "latitude": 12.9592,
            "longitude": 77.6496,
            "distance_meters": 1340.5,
            "distance_km": 1.34
          },
          {
            "id": "hosp-2",
            "name": "St. John's Medical College Hospital",
            "phone": "+91-80-2206-5000",
            "address": "Sarjapur Rd, Bangalore",
            "has_trauma_center": true,
            "has_icu_capacity": true,
            "latitude": 12.9341,
            "longitude": 77.6186,
            "distance_meters": 4520.0,
            "distance_km": 4.52
          }
        ]
      };

      final response = IncidentResponse.fromJson(jsonPayload);

      expect(response.message, contains('Incident reported'));
      expect(response.searchRadiusKm, 8.0);
      expect(response.matchedHospitalsCount, 2);
      expect(response.incident.id, 'c1f7b764-50b3-4f1e-9764-16a73c1fa187');
      expect(response.incident.status, 'detected');
      expect(response.incident.acceptedHospitalId, isNull);
      expect(response.incident.victimMetadata?['airbag_deployed'], isTrue);
      expect(response.incident.latitude, 12.9716);
      expect(response.incident.longitude, 77.5946);

      expect(response.matchedHospitals.length, 2);
      final first = response.matchedHospitals[0];
      expect(first.name, 'Manipal Hospital HAL');
      expect(first.hasTraumaCenter, isTrue);
      expect(first.hasIcuCapacity, isTrue);
      expect(first.distanceKm, 1.34);

      // Verify serialization round-trip
      final serialized = response.toJson();
      expect(serialized['matched_hospitals_count'], 2);
      expect((serialized['matched_hospitals'] as List).length, 2);
    });

    test('IncidentResponse parses PostgreSQL string-formatted numeric fields without type errors', () {
      final jsonWithStrings = {
        "message": "Incident reported",
        "incident": {
          "id": "c1f7b764-50b3-4f1e-9764-16a73c1fa187",
          "status": "detected",
          "latitude": "12.9716",
          "longitude": "77.5946",
        },
        "search_radius_km": "8",
        "matched_hospitals_count": "1",
        "matched_hospitals": [
          {
            "id": "hosp-1",
            "name": "Manipal Hospital HAL",
            "phone": "+91-80-2502-4444",
            "address": "98 HAL Airport Rd",
            "has_trauma_center": true,
            "has_icu_capacity": true,
            "latitude": "12.9592",
            "longitude": "77.6496",
            "distance_meters": "1340.5",
            "distance_km": "1.34"
          }
        ]
      };

      final response = IncidentResponse.fromJson(jsonWithStrings);
      expect(response.incident.latitude, 12.9716);
      expect(response.incident.longitude, 77.5946);
      expect(response.searchRadiusKm, 8.0);
      expect(response.matchedHospitalsCount, 1);
      expect(response.matchedHospitals[0].distanceKm, 1.34);
      expect(response.matchedHospitals[0].distanceMeters, 1340.5);
    });
  });
}
