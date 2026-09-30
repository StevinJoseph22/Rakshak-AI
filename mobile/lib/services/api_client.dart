import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/incident_model.dart';

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

/// Default backend URL. Can be overridden via `--dart-define=BACKEND_URL=http://<YOUR_IP>:5000`
const String kDefaultBackendUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://10.0.2.2:5000',
);

/// HTTP API Client for Rakshak-AI backend.
/// Default baseUrl uses 10.0.2.2 (Android Emulator host loopback) or BACKEND_URL define.
class ApiClient {
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
  ///
  /// TODO: Phase 5/6 will call this from LockedScreenAlertScreen confirm button
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

    // Candidate base URLs to try in order of priority:
    // 1. http://127.0.0.1:5000 (Active if `adb reverse tcp:5000 tcp:5000` is run)
    // 2. http://192.168.1.21:5000 (Current local workstation Wi-Fi IP)
    // 3. Configured baseUrl (from BACKEND_URL dart-define or default)
    // 4. http://10.0.2.2:5000 (Android Emulator host loopback)
    final candidates = <String>[
      'http://127.0.0.1:5000',
      'http://192.168.1.21:5000',
      if (baseUrl != kDefaultBackendUrl) baseUrl,
      'http://10.208.188.149:5000',
      'http://172.22.61.163:5000',
      'http://10.0.2.2:5000',
      baseUrl,
    ].toSet().toList();

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

  /// Closes client resources.
  void dispose() {
    _httpClient.close();
  }
}
