import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/backend_config.dart';
import '../models/incident_model.dart';

export '../config/backend_config.dart' show kDefaultBackendUrl, getBackendCandidates, kDemoWorkstationIp, resolveReachableBackendUrl, gActiveBackendUrl;

/// Generic result wrapper for API calls that never crashes on network failure.
class ApiResult<T> {
  final bool isSuccess;
  final T? data;
  final String? errorMessage;
  final int? statusCode;

  const ApiResult.success(this.data, {this.statusCode = 200})
      : isSuccess = true,
        errorMessage = null;

  const ApiResult.failure(this.errorMessage, {this.statusCode})
      : isSuccess = false,
        data = null;

  @override
  String toString() {
    return isSuccess
        ? 'ApiResult.success(data: $data, statusCode: $statusCode)'
        : 'ApiResult.failure(error: $errorMessage, statusCode: $statusCode)';
  }
}

/// HTTP API Client for Rakshak-AI backend.
/// Default baseUrl uses 10.0.2.2 (Android Emulator host loopback) or BACKEND_URL define.
class ApiClient {
  /// Stores the most recent verified responsive backend URL across network candidates
  static String? get activeBackendUrl => gActiveBackendUrl;
  static set activeBackendUrl(String? val) => gActiveBackendUrl = val;

  final String baseUrl;
  final http.Client _httpClient;

  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
  })  : baseUrl = baseUrl ?? kDefaultBackendUrl,
        _httpClient = httpClient ?? http.Client();

  /// Reports a new crash incident with GPS coordinates and optional victim metadata.
  /// Matches Phase 1: POST /incidents
  /// Body: { "latitude": double, "longitude": double, "victim_metadata": {...} }
  Future<ApiResult<IncidentResponse>> reportIncident({
    required double latitude,
    required double longitude,
    Map<String, dynamic>? victimMetadata,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final payload = {
      'latitude': latitude,
      'longitude': longitude,
      if (victimMetadata != null) 'victim_metadata': victimMetadata,
    };

    final candidates = getBackendCandidates(baseUrl);
    String? lastError;

    for (final candidateUrl in candidates) {
      final uri = Uri.parse('$candidateUrl/incidents');
      try {
        final response = await _httpClient
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(timeout);

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;

        if (response.statusCode >= 200 && response.statusCode < 300) {
          activeBackendUrl = candidateUrl;
          final incidentResponse = IncidentResponse.fromJson(decoded);
          return ApiResult.success(incidentResponse, statusCode: response.statusCode);
        } else {
          final errorMsg = decoded['error']?.toString() ??
              decoded['message']?.toString() ??
              'Server responded with status code ${response.statusCode}';
          return ApiResult.failure(errorMsg, statusCode: response.statusCode);
        }
      } on SocketException catch (e) {
        lastError = 'Connection failed ($candidateUrl): ${e.message}';
        continue;
      } on TimeoutException {
        lastError = 'Connection timeout ($candidateUrl)';
        continue;
      } on FormatException catch (e) {
        return ApiResult.failure('Invalid JSON response format: ${e.message}');
      } catch (e) {
        lastError = 'Error ($candidateUrl): $e';
        continue;
      }
    }

    return ApiResult.failure(
      'Network error: Unable to reach backend server ($baseUrl). $lastError',
    );
  }

  /// Fetches active incidents within radiusKm of given ambulance coordinates.
  /// Matches Phase 8: GET /incidents/nearby?lat=&lng=&radius_km=
  Future<ApiResult<List<NearbyIncident>>> fetchNearbyIncidents({
    required double latitude,
    required double longitude,
    double radiusKm = 15.0,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final candidates = getBackendCandidates(baseUrl);
    String? lastError;
    for (final candidateUrl in candidates) {
      final uri = Uri.parse(
        '$candidateUrl/incidents/nearby?lat=$latitude&lng=$longitude&radius_km=$radiusKm',
      );
      try {
        final response = await _httpClient.get(
          uri,
          headers: {'Accept': 'application/json'},
        ).timeout(timeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          activeBackendUrl = candidateUrl;
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final list = (decoded['incidents'] as List<dynamic>? ?? [])
              .map((item) => NearbyIncident.fromJson(item as Map<String, dynamic>))
              .toList();
          return ApiResult.success(list, statusCode: response.statusCode);
        } else {
          return ApiResult.failure('Failed to fetch nearby incidents', statusCode: response.statusCode);
        }
      } catch (e) {
        lastError = 'Error ($candidateUrl): $e';
        continue;
      }
    }
    return ApiResult.failure('Unable to reach backend: $lastError');
  }

  /// Claims an incident for the ambulance unit.
  /// Matches Phase 8: POST /incidents/:id/claim
  Future<ApiResult<bool>> claimIncident({
    required String incidentId,
    required String ambulanceId,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final candidates = getBackendCandidates(baseUrl);
    String? lastError;
    for (final candidateUrl in candidates) {
      final uri = Uri.parse('$candidateUrl/incidents/$incidentId/claim');
      try {
        final response = await _httpClient.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'ambulance_id': ambulanceId}),
        ).timeout(timeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          activeBackendUrl = candidateUrl;
          return const ApiResult.success(true);
        } else if (response.statusCode == 409) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          return ApiResult.failure(
            decoded['message']?.toString() ?? 'Already claimed by another ambulance',
            statusCode: 409,
          );
        } else {
          return ApiResult.failure('Claim failed with status ${response.statusCode}');
        }
      } catch (e) {
        lastError = 'Error ($candidateUrl): $e';
        continue;
      }
    }
    return ApiResult.failure('Unable to reach backend: $lastError');
  }

  /// Closes client resources.
  void dispose() {
    _httpClient.close();
  }
}

