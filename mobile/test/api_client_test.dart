import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rakshak_mobile/services/api_client.dart';

void main() {
  group('ApiClient Tests', () {
    test('reportIncident returns success on 201 Created from backend', () async {
      final mockResponse = {
        "message": "Incident reported and nearby trauma centers matched successfully",
        "incident": {
          "id": "test-id-123",
          "status": "detected",
          "latitude": 12.9716,
          "longitude": 77.5946,
        },
        "search_radius_km": 8.0,
        "matched_hospitals_count": 1,
        "matched_hospitals": [
          {
            "id": "h-1",
            "name": "NIMHANS Hospital",
            "phone": "+91-80-2699-5000",
            "address": "Hosur Rd, Bangalore",
            "has_trauma_center": true,
            "has_icu_capacity": true,
            "latitude": 12.9432,
            "longitude": 77.5969,
            "distance_meters": 3150.0,
            "distance_km": 3.15,
          }
        ]
      };

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/incidents');
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['latitude'], 12.9716);
        expect(body['longitude'], 77.5946);

        return http.Response(
          jsonEncode(mockResponse),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(
        baseUrl: 'http://10.0.2.2:5000',
        httpClient: mockClient,
      );

      final result = await client.reportIncident(
        latitude: 12.9716,
        longitude: 77.5946,
      );

      expect(result.isSuccess, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!.incident.id, 'test-id-123');
      expect(result.data!.matchedHospitalsCount, 1);
      expect(result.data!.matchedHospitals.first.name, 'NIMHANS Hospital');
    });

    test('reportIncident returns failure on 400 Bad Request without throwing', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({"error": "Latitude and longitude must be valid coordinates"}),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(
        baseUrl: 'http://10.0.2.2:5000',
        httpClient: mockClient,
      );

      final result = await client.reportIncident(
        latitude: 999.0,
        longitude: 999.0,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('valid coordinates'));
      expect(result.statusCode, 400);
      expect(result.data, isNull);
    });

    test('reportIncident handles network exceptions gracefully without throwing', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final client = ApiClient(
        baseUrl: 'http://10.0.2.2:5000',
        httpClient: mockClient,
      );

      final result = await client.reportIncident(
        latitude: 12.9716,
        longitude: 77.5946,
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Connection refused'));
      expect(result.data, isNull);
    });
  });
}
