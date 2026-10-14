import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/backend_config.dart';

class AbdmVerificationStartResult {
  final String status; // 'OTP_SENT' | 'NOT_FOUND' | 'ABDM_UNAVAILABLE' | 'RATE_LIMITED'
  final String? txnId;
  final String message;
  final String mode;

  const AbdmVerificationStartResult({
    required this.status,
    this.txnId,
    required this.message,
    this.mode = 'MOCK',
  });
}

class AbdmVerificationConfirmResult {
  final String status; // 'VERIFIED' | 'OTP_FAILED' | 'ABDM_UNAVAILABLE' | 'RATE_LIMITED'
  final String? sessionToken;
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? records;
  final String message;
  final String mode;

  const AbdmVerificationConfirmResult({
    required this.status,
    this.sessionToken,
    this.profile,
    this.records,
    required this.message,
    this.mode = 'MOCK',
  });
}

class AbdmMobileService {
  AbdmMobileService._();
  static final AbdmMobileService instance = AbdmMobileService._();

  final http.Client _client = http.Client();

  Future<String> _getBaseUrl() async {
    return await resolveReachableBackendUrl();
  }

  /// Queries current active ABDM gateway mode (SANDBOX or MOCK)
  Future<String> getGatewayMode() async {
    try {
      final baseUrl = await _getBaseUrl();
      final res = await _client
          .get(Uri.parse('$baseUrl/abha/status'))
          .timeout(const Duration(milliseconds: 1500));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['mode'] as String? ?? 'MOCK';
      }
    } catch (_) {}
    return 'MOCK';
  }

  /// Initiates ABHA address verification via OTP dispatch
  Future<AbdmVerificationStartResult> startVerification(String abhaAddress) async {
    try {
      final baseUrl = await _getBaseUrl();
      final res = await _client
          .post(
            Uri.parse('$baseUrl/abha/verify/start'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'abha_address': abhaAddress.trim()}),
          )
          .timeout(const Duration(seconds: 4));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) {
        return AbdmVerificationStartResult(
          status: data['status'] as String? ?? 'OTP_SENT',
          txnId: data['txn_id'] as String?,
          message: data['message'] as String? ?? 'OTP sent successfully',
          mode: data['mode'] as String? ?? 'MOCK',
        );
      } else if (res.statusCode == 404) {
        return AbdmVerificationStartResult(
          status: 'NOT_FOUND',
          message: data['message'] as String? ?? 'ABHA address not found',
        );
      } else if (res.statusCode == 429) {
        return AbdmVerificationStartResult(
          status: 'RATE_LIMITED',
          message: data['message'] as String? ?? 'Too many OTP requests. Please wait.',
        );
      } else {
        return AbdmVerificationStartResult(
          status: 'ABDM_UNAVAILABLE',
          message: data['message'] as String? ?? 'ABDM service unavailable',
        );
      }
    } catch (e) {
      return const AbdmVerificationStartResult(
        status: 'ABDM_UNAVAILABLE',
        message: 'ABDM gateway unreachable. You can continue onboarding and link later in Settings.',
      );
    }
  }

  /// Confirms OTP and receives verified identity & health record metadata
  Future<AbdmVerificationConfirmResult> confirmVerification({
    required String txnId,
    required String otp,
  }) async {
    try {
      final baseUrl = await _getBaseUrl();
      final res = await _client
          .post(
            Uri.parse('$baseUrl/abha/verify/confirm'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'txn_id': txnId,
              'otp': otp.trim(),
            }),
          )
          .timeout(const Duration(seconds: 4));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200) {
        return AbdmVerificationConfirmResult(
          status: 'VERIFIED',
          sessionToken: data['session_token'] as String?,
          profile: data['profile'] as Map<String, dynamic>?,
          records: data['records'] as Map<String, dynamic>?,
          message: data['message'] as String? ?? 'ABHA verified',
          mode: data['mode'] as String? ?? 'MOCK',
        );
      } else if (res.statusCode == 400) {
        return AbdmVerificationConfirmResult(
          status: 'OTP_FAILED',
          message: data['message'] as String? ?? 'Invalid OTP entered',
        );
      } else {
        return AbdmVerificationConfirmResult(
          status: 'ABDM_UNAVAILABLE',
          message: data['message'] as String? ?? 'ABDM confirmation service unavailable',
        );
      }
    } catch (e) {
      return const AbdmVerificationConfirmResult(
        status: 'ABDM_UNAVAILABLE',
        message: 'Network error communicating with ABDM backend proxy.',
      );
    }
  }

  /// Unlinks ABHA and purges active session on backend
  Future<void> unlinkAbha(String? sessionToken) async {
    if (sessionToken == null || sessionToken.isEmpty) return;
    try {
      final baseUrl = await _getBaseUrl();
      await _client
          .delete(
            Uri.parse('$baseUrl/abha/link'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $sessionToken',
            },
          )
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {}
  }
}
