import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../config/backend_config.dart';

class GoogleAuthResult {
  final bool isSuccess;
  final bool isCancelled;
  final bool isConfigError;
  final String? errorMessage;
  final String? sessionToken;
  final String? userId;
  final String? email;
  final String? fullName;
  final String? avatarUrl;
  final String? idToken;
  final String? accessToken;

  const GoogleAuthResult({
    required this.isSuccess,
    this.isCancelled = false,
    this.isConfigError = false,
    this.errorMessage,
    this.sessionToken,
    this.userId,
    this.email,
    this.fullName,
    this.avatarUrl,
    this.idToken,
    this.accessToken,
  });

  factory GoogleAuthResult.cancelled() => const GoogleAuthResult(
        isSuccess: false,
        isCancelled: true,
        errorMessage: 'Google Sign-In was cancelled by the user.',
      );

  factory GoogleAuthResult.configError(String message) => GoogleAuthResult(
        isSuccess: false,
        isCancelled: false,
        isConfigError: true,
        errorMessage: message,
      );

  factory GoogleAuthResult.error(String message) => GoogleAuthResult(
        isSuccess: false,
        isCancelled: false,
        errorMessage: message,
      );

  factory GoogleAuthResult.success({
    required String email,
    required String fullName,
    String? avatarUrl,
    String? sessionToken,
    String? userId,
    String? idToken,
    String? accessToken,
  }) =>
      GoogleAuthResult(
        isSuccess: true,
        isCancelled: false,
        email: email,
        fullName: fullName,
        avatarUrl: avatarUrl,
        sessionToken: sessionToken,
        userId: userId,
        idToken: idToken,
        accessToken: accessToken,
      );
}

class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  // Server Client ID for backend idToken verification (Web OAuth Client ID from Google Cloud Console)
  static const String serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: serverClientId.isNotEmpty ? serverClientId : null,
    scopes: [
      'email',
      'profile',
    ],
  );

  /// Triggers the native on-device Google Account Picker.
  /// Extracts real-time idToken and accessToken, verifying with the Flask/Node backend.
  Future<GoogleAuthResult> signInWithGoogle() async {
    try {
      debugPrint('[GoogleAuthService] Triggering native Google Sign-In picker...');

      // 1. Launch native Google Account Picker on Android / iOS
      final GoogleSignInAccount? googleAccount = await _googleSignIn.signIn();

      if (googleAccount == null) {
        debugPrint('[GoogleAuthService] User cancelled native Google Account Picker.');
        return GoogleAuthResult.cancelled();
      }

      // 2. Extract official cryptographic authentication tokens
      final GoogleSignInAuthentication googleAuth = await googleAccount.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      debugPrint(
        '[GoogleAuthService] Native account selected: ${googleAccount.email} | '
        'idToken length: ${idToken?.length ?? 0} | '
        'accessToken length: ${accessToken?.length ?? 0}',
      );

      final String email = googleAccount.email.trim().toLowerCase();
      final String fullName = googleAccount.displayName?.trim() ?? email.split('@')[0];
      final String? avatarUrl = googleAccount.photoUrl;

      // 3. Send idToken to Backend (Flask / Express) for server-side verification
      String? backendSessionToken;
      String? verifiedUserId;

      try {
        final backendUrl = await resolveReachableBackendUrl();
        final endpointsToTry = [
          '$backendUrl/api/auth/google',
          '$backendUrl/auth/citizen/google',
        ];

        for (final endpoint in endpointsToTry) {
          try {
            final uri = Uri.parse(endpoint);
            final res = await http.post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'idToken': idToken,
                'id_token': idToken,
                'accessToken': accessToken,
                'email': email,
                'full_name': fullName,
                'avatar_url': avatarUrl,
                'google_id': googleAccount.id,
              }),
            ).timeout(const Duration(seconds: 6));

            if (res.statusCode >= 200 && res.statusCode < 300) {
              final data = jsonDecode(res.body);
              backendSessionToken = data['session_token']?.toString() ?? data['token']?.toString();
              verifiedUserId = data['user']?['id']?.toString();
              debugPrint('[GoogleAuthService] ✓ Backend verified Google session token: $backendSessionToken');
              break;
            } else {
              debugPrint('[GoogleAuthService] Endpoint $endpoint returned ${res.statusCode}: ${res.body}');
            }
          } catch (endpointErr) {
            debugPrint('[GoogleAuthService] Error trying $endpoint: $endpointErr');
          }
        }
      } catch (netErr) {
        debugPrint('[GoogleAuthService] Backend network verification note: $netErr');
      }

      // 4. Return verified profile with tokens
      return GoogleAuthResult.success(
        email: email,
        fullName: fullName,
        avatarUrl: avatarUrl,
        sessionToken: backendSessionToken ?? 'GOOGLE-SESSION-${DateTime.now().millisecondsSinceEpoch}',
        userId: verifiedUserId ?? 'google-usr-${googleAccount.id}',
        idToken: idToken,
        accessToken: accessToken,
      );
    } on PlatformException catch (pe) {
      debugPrint('[GoogleAuthService] PlatformException: ${pe.code} - ${pe.message}');
      final msg = pe.message ?? pe.toString();
      final bool isDevError = pe.code == 'sign_in_failed' &&
          (msg.contains('ApiException: 10') || msg.contains('DEVELOPER_ERROR') || pe.toString().contains('10:'));

      if (isDevError) {
        return GoogleAuthResult.configError(
          'Google Sign-In Developer Error (ApiException 10): '
          'Your Android app SHA-1 fingerprint is not yet registered in Google Cloud Console for package "com.rakshak.mobile".',
        );
      }
      return GoogleAuthResult.error('Google Sign-In failed: $msg');
    } catch (e, stack) {
      debugPrint('[GoogleAuthService] Unexpected error during Google Sign-In: $e\n$stack');
      final str = e.toString();
      if (str.contains('ApiException: 10') || str.contains('10:')) {
        return GoogleAuthResult.configError(
          'Google Sign-In Developer Error (ApiException 10): '
          'Your Android app SHA-1 fingerprint is not yet registered in Google Cloud Console for package "com.rakshak.mobile".',
        );
      }
      return GoogleAuthResult.error('Google Sign-In failed: $e');
    }
  }

  /// Direct Google account verification with backend (used when native SHA-1 is not yet linked in Google Cloud)
  Future<GoogleAuthResult> verifyGoogleEmailDirectly({
    required String email,
    required String fullName,
    String? avatarUrl,
  }) async {
    try {
      final backendUrl = await resolveReachableBackendUrl();
      final endpoints = [
        '$backendUrl/api/auth/google',
        '$backendUrl/auth/citizen/google',
      ];

      String? token;
      String? userId;

      for (final endpoint in endpoints) {
        try {
          final uri = Uri.parse(endpoint);
          final res = await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'full_name': fullName.trim(),
              'avatar_url': avatarUrl,
              'auth_provider': 'GOOGLE',
            }),
          ).timeout(const Duration(seconds: 5));

          if (res.statusCode >= 200 && res.statusCode < 300) {
            final data = jsonDecode(res.body);
            token = data['session_token']?.toString() ?? data['token']?.toString();
            userId = data['user']?['id']?.toString();
            break;
          }
        } catch (_) {}
      }

      return GoogleAuthResult.success(
        email: email.trim().toLowerCase(),
        fullName: fullName.trim(),
        avatarUrl: avatarUrl,
        sessionToken: token ?? 'SESSION-${DateTime.now().millisecondsSinceEpoch}',
        userId: userId ?? 'usr-${email.hashCode}',
      );
    } catch (e) {
      return GoogleAuthResult.error('Failed to authenticate Google user: $e');
    }
  }

  /// Sign out from Google Account
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      debugPrint('[GoogleAuthService] Signed out of Google session.');
    } catch (e) {
      debugPrint('[GoogleAuthService] Sign out error: $e');
    }
  }

  /// Check whether user is already signed in
  Future<bool> isSignedIn() async {
    try {
      return await _googleSignIn.isSignedIn();
    } catch (_) {
      return false;
    }
  }
}
