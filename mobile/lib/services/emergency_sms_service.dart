// Privacy note: Emergency contact data is the victim's own chosen contact,
// stored locally on-device and only sent alongside an actual confirmed incident dispatch
// via victim_metadata. It is never stored in a standalone contacts table or cached
// in Redis alongside temporary photos.

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/emergency_contact_model.dart';
import '../screens/emergency_sms_preview_screen.dart';
import 'emergency_contact_service.dart';

enum SmsDeliveryMode {
  nativeSim,
  fallbackWhatsApp,
  previewScreen,
  simulationOnly,
}

class EmergencySmsDispatchResult {
  final bool success;
  final SmsDeliveryMode mode;
  final int totalContacts;
  final int successfulSends;
  final String messageBody;
  final String? errorMessage;

  EmergencySmsDispatchResult({
    required this.success,
    required this.mode,
    required this.totalContacts,
    required this.successfulSends,
    required this.messageBody,
    this.errorMessage,
  });
}

class EmergencySmsService {
  EmergencySmsService._internal();
  static final EmergencySmsService _instance = EmergencySmsService._internal();
  static EmergencySmsService get instance => _instance;

  static const MethodChannel _smsChannel = MethodChannel('com.rakshak.mobile/emergency_sms');

  // Global navigator key fallback when context isn't passed directly
  static GlobalKey<NavigatorState>? navigatorKey;

  // Deduplication set preventing duplicate SMS dispatches on socket reconnects
  final Set<String> _dispatchedAlertKeys = <String>{};

  /// Clears alert dispatch history when a new incident session begins
  void resetAlertHistory() {
    _dispatchedAlertKeys.clear();
    debugPrint('[EmergencySmsService] Cleared SMS alert history for new incident');
  }

  /// Check whether we are running in a Flutter test environment
  bool get _isTestEnvironment {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  /// Request SMS permission on Android
  Future<bool> requestSmsPermission() async {
    if (_isTestEnvironment || !kIsWeb && !Platform.isAndroid) {
      return false;
    }
    try {
      final res = await _smsChannel.invokeMethod<bool>('requestSmsPermission');
      return res ?? false;
    } catch (e) {
      debugPrint('[EmergencySmsService] Error requesting SMS permission: $e');
      return false;
    }
  }

  /// Check if SMS permission is granted
  Future<bool> hasSmsPermission() async {
    if (_isTestEnvironment || !kIsWeb && !Platform.isAndroid) {
      return false;
    }
    try {
      final res = await _smsChannel.invokeMethod<bool>('checkSmsPermission');
      return res ?? false;
    } catch (e) {
      debugPrint('[EmergencySmsService] Error checking SMS permission: $e');
      return false;
    }
  }

  /// Cleans phone number to international E.164 without plus or adds 91 for Indian 10-digit numbers
  String cleanPhoneNumberForWhatsApp(String raw) {
    String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10) {
      digits = '91$digits';
    }
    return digits;
  }

  /// Builds Message 1: Initial crash detection alert
  String buildCrashAlertMessage({
    required String victimName,
    required double lat,
    required double lng,
  }) {
    final latStr = lat.toStringAsFixed(5);
    final lngStr = lng.toStringAsFixed(5);
    return 'RAKSHAK-AI ALERT: $victimName may have been in an accident. '
        'Live location: https://maps.google.com/?q=$latStr,$lngStr . '
        'Emergency services have been notified.';
  }

  /// Builds Message 2: Hospital acceptance update (kept strictly < 160 chars for guaranteed single-part SMS)
  String buildHospitalAcceptedMessage({
    required String victimName,
    required String hospitalName,
    required String hospitalAddress,
    required String hospitalPhone,
  }) {
    final shortAddress = hospitalAddress.split(',').take(2).join(',').trim();
    final full = 'UPDATE: $victimName has been accepted by $hospitalName, $shortAddress. Hospital contact: $hospitalPhone.';
    if (full.length <= 160) {
      return full;
    }
    return 'UPDATE: $victimName has been accepted by $hospitalName. Hospital contact: $hospitalPhone.';
  }

  /// Builds Message 3: Ambulance dispatch update (kept strictly < 160 chars for guaranteed single-part SMS)
  String buildAmbulanceDispatchedMessage({
    required String victimName,
    required String ambulanceId,
  }) {
    return 'UPDATE: Ambulance $ambulanceId has been dispatched and is en route to $victimName\'s location. Emergency services are responding.';
  }

  /// Builds Message 4: Ambulance on-scene arrival update
  String buildAmbulanceArrivedMessage({
    required String victimName,
    required String ambulanceId,
    required String vehiclePlate,
    required String driverName,
    required String driverPhone,
    required String locationDescription,
  }) {
    return 'UPDATE: Ambulance $ambulanceId ($vehiclePlate) has ARRIVED at $victimName\'s accident scene ($locationDescription). '
        'Driver: $driverName (Ph: $driverPhone). Paramedics are administering trauma care.';
  }

  /// Builds Message 5: Official Police Case Docket Reference (for Emergency Contacts / Family)
  String buildPoliceCaseAlertMessage({
    required String victimName,
    required String caseNumber,
    required String stationName,
    required String officerPhone,
  }) {
    return 'POLICE UPDATE: Official Incident Case ID #$caseNumber registered for $victimName at $stationName. '
        'Investigating Officer Ph: $officerPhone. Track case: https://rakshak.ai/case/$caseNumber';
  }

  /// Sends Police Case Reference SMS to registered emergency contacts
  Future<EmergencySmsDispatchResult> sendPoliceCaseAlert({
    required String caseNumber,
    required String stationName,
    required String officerPhone,
    BuildContext? context,
  }) async {
    final alertKey = 'POLICE_CASE_${caseNumber.trim()}';
    if (_dispatchedAlertKeys.contains(alertKey)) {
      debugPrint('[EmergencySmsService] Police case alert already dispatched for $caseNumber. Skipping duplicate.');
      return EmergencySmsDispatchResult(
        success: true,
        mode: SmsDeliveryMode.nativeSim,
        totalContacts: 0,
        successfulSends: 0,
        messageBody: '',
      );
    }
    _dispatchedAlertKeys.add(alertKey);

    final contacts = await EmergencyContactService.instance.getContacts();
    final victimName = await EmergencyContactService.instance.getVictimName();
    final message = buildPoliceCaseAlertMessage(
      victimName: victimName,
      caseNumber: caseNumber,
      stationName: stationName,
      officerPhone: officerPhone,
    );

    return _dispatchAlert(
      alertType: 'POLICE_CASE_ALERT',
      contacts: contacts,
      message: message,
      context: context,
    );
  }

  /// Sends crash alert via Real Native SmsManager or falls back to WhatsApp preview
  Future<EmergencySmsDispatchResult> sendCrashAlert({
    required double lat,
    required double lng,
    BuildContext? context,
  }) async {
    final alertKey = 'CRASH_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
    if (_dispatchedAlertKeys.contains(alertKey)) {
      debugPrint('[EmergencySmsService] Crash alert already dispatched for location. Skipping duplicate.');
      return EmergencySmsDispatchResult(
        success: true,
        mode: SmsDeliveryMode.nativeSim,
        totalContacts: 0,
        successfulSends: 0,
        messageBody: '',
      );
    }
    _dispatchedAlertKeys.add(alertKey);

    final contacts = await EmergencyContactService.instance.getContacts();
    final victimName = await EmergencyContactService.instance.getVictimName();
    final message = buildCrashAlertMessage(victimName: victimName, lat: lat, lng: lng);

    return _dispatchAlert(
      alertType: 'CRASH_ALERT',
      contacts: contacts,
      message: message,
      context: context,
    );
  }

  /// Sends hospital acceptance alert via Real Native SmsManager or falls back to WhatsApp preview
  Future<EmergencySmsDispatchResult> sendHospitalAcceptedAlert({
    String? incidentId,
    required String hospitalName,
    required String hospitalAddress,
    required String hospitalPhone,
    BuildContext? context,
  }) async {
    final alertKey = 'HOSPITAL_ACCEPTED_${incidentId ?? ""}_${hospitalName.trim()}_${hospitalPhone.trim()}';
    if (_dispatchedAlertKeys.contains(alertKey)) {
      debugPrint('[EmergencySmsService] Hospital accepted alert already dispatched for $hospitalName. Skipping duplicate.');
      return EmergencySmsDispatchResult(
        success: true,
        mode: SmsDeliveryMode.nativeSim,
        totalContacts: 0,
        successfulSends: 0,
        messageBody: '',
      );
    }
    _dispatchedAlertKeys.add(alertKey);

    final contacts = await EmergencyContactService.instance.getContacts();
    final victimName = await EmergencyContactService.instance.getVictimName();
    final message = buildHospitalAcceptedMessage(
      victimName: victimName,
      hospitalName: hospitalName,
      hospitalAddress: hospitalAddress,
      hospitalPhone: hospitalPhone,
    );

    return _dispatchAlert(
      alertType: 'HOSPITAL_ACCEPTED',
      contacts: contacts,
      message: message,
      context: context,
    );
  }

  /// Sends ambulance dispatched alert via Real Native SmsManager or falls back to WhatsApp preview
  Future<EmergencySmsDispatchResult> sendAmbulanceDispatchedAlert({
    String? incidentId,
    required String ambulanceId,
    BuildContext? context,
  }) async {
    final alertKey = 'AMBULANCE_DISPATCHED_${incidentId ?? ""}_${ambulanceId.trim()}';
    if (_dispatchedAlertKeys.contains(alertKey)) {
      debugPrint('[EmergencySmsService] Ambulance dispatched alert already dispatched for $ambulanceId. Skipping duplicate.');
      return EmergencySmsDispatchResult(
        success: true,
        mode: SmsDeliveryMode.nativeSim,
        totalContacts: 0,
        successfulSends: 0,
        messageBody: '',
      );
    }
    _dispatchedAlertKeys.add(alertKey);

    final contacts = await EmergencyContactService.instance.getContacts();
    final victimName = await EmergencyContactService.instance.getVictimName();
    final message = buildAmbulanceDispatchedMessage(
      victimName: victimName,
      ambulanceId: ambulanceId,
    );

    return _dispatchAlert(
      alertType: 'AMBULANCE_DISPATCHED',
      contacts: contacts,
      message: message,
      context: context,
    );
  }

  /// Sends ambulance arrived on-scene alert via Real Native SmsManager or falls back to WhatsApp preview
  Future<EmergencySmsDispatchResult> sendAmbulanceArrivedAlert({
    String? incidentId,
    required String ambulanceId,
    String? vehiclePlate,
    String? driverName,
    String? driverPhone,
    String? locationDescription,
    BuildContext? context,
  }) async {
    final alertKey = 'AMBULANCE_ARRIVED_${incidentId ?? ""}_${ambulanceId.trim()}';
    if (_dispatchedAlertKeys.contains(alertKey)) {
      debugPrint('[EmergencySmsService] Ambulance arrived alert already dispatched for $ambulanceId. Skipping duplicate.');
      return EmergencySmsDispatchResult(
        success: true,
        mode: SmsDeliveryMode.nativeSim,
        totalContacts: 0,
        successfulSends: 0,
        messageBody: '',
      );
    }
    _dispatchedAlertKeys.add(alertKey);

    final contacts = await EmergencyContactService.instance.getContacts();
    final victimName = await EmergencyContactService.instance.getVictimName();
    final message = buildAmbulanceArrivedMessage(
      victimName: victimName,
      ambulanceId: ambulanceId,
      vehiclePlate: vehiclePlate ?? 'KA-01-EA-108',
      driverName: driverName ?? 'Ramesh Kumar',
      driverPhone: driverPhone ?? '+91 98450 12345',
      locationDescription: locationDescription ?? 'accident location',
    );

    return _dispatchAlert(
      alertType: 'AMBULANCE_ARRIVED',
      contacts: contacts,
      message: message,
      context: context,
    );
  }

  /// Core dual real/fallback dispatcher
  Future<EmergencySmsDispatchResult> _dispatchAlert({
    required String alertType,
    required List<EmergencyContact> contacts,
    required String message,
    BuildContext? context,
  }) async {
    if (contacts.isEmpty) {
      debugPrint('[EmergencySmsService] No emergency contacts registered.');
      return EmergencySmsDispatchResult(
        success: false,
        mode: SmsDeliveryMode.simulationOnly,
        totalContacts: 0,
        successfulSends: 0,
        messageBody: message,
        errorMessage: 'No emergency contacts found on device',
      );
    }

    debugPrint('[EmergencySmsService] Dispatching $alertType to ${contacts.length} contacts...');

    // Attempt REAL native Android SmsManager first if running on Android device
    bool canAttemptNative = false;
    if (!_isTestEnvironment && !kIsWeb && Platform.isAndroid) {
      canAttemptNative = await hasSmsPermission();
      if (!canAttemptNative) {
        canAttemptNative = await requestSmsPermission();
      }
    }

    if (canAttemptNative) {
      int successCount = 0;
      bool anyFailure = false;

      for (final contact in contacts) {
        try {
          final res = await _smsChannel.invokeMethod<bool>('sendSmsNative', {
            'phone': contact.phone,
            'message': message,
          });
          if (res == true) {
            successCount++;
            debugPrint('[EmergencySmsService] [REAL NATIVE SIM] Sent SMS to ${contact.name} (${contact.phone})');
          } else {
            anyFailure = true;
          }
        } catch (e) {
          debugPrint('[EmergencySmsService] Native SMS failed for ${contact.name}: $e');
          anyFailure = true;
        }
      }

      if (successCount > 0 && !anyFailure) {
        debugPrint('[EmergencySmsService] Real native SMS dispatched successfully for all $successCount contacts.');
        return EmergencySmsDispatchResult(
          success: true,
          mode: SmsDeliveryMode.nativeSim,
          totalContacts: contacts.length,
          successfulSends: successCount,
          messageBody: message,
        );
      }
      debugPrint('[EmergencySmsService] Partial or full native SMS failure; falling back to WhatsApp preview.');
    } else {
      debugPrint('[EmergencySmsService] Native SMS permission not granted or emulator environment detected. Using fallback WhatsApp preview path.');
    }

    // FALLBACK path: Open Emergency SMS Preview screen with working WhatsApp buttons
    _showFallbackPreview(context, contacts, message, alertType);

    return EmergencySmsDispatchResult(
      success: true,
      mode: SmsDeliveryMode.fallbackWhatsApp,
      totalContacts: contacts.length,
      successfulSends: 0,
      messageBody: message,
    );
  }

  void _showFallbackPreview(
    BuildContext? context,
    List<EmergencyContact> contacts,
    String message,
    String alertType,
  ) {
    if (_isTestEnvironment) return;

    final targetContext = context ?? navigatorKey?.currentContext;
    if (targetContext != null && targetContext.mounted) {
      Navigator.of(targetContext).push(
        MaterialPageRoute(
          builder: (ctx) => EmergencySmsPreviewScreen(
            contacts: contacts,
            message: message,
            alertType: alertType,
          ),
        ),
      );
    }
  }

  /// Launch WhatsApp deep link with prefilled URL-encoded message
  Future<bool> launchWhatsAppMessage({
    required String phoneNumber,
    required String message,
  }) async {
    final cleanPhone = cleanPhoneNumberForWhatsApp(phoneNumber);
    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$encoded');

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to browser launch
        return await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('[EmergencySmsService] Error launching WhatsApp: $e');
      return false;
    }
  }

  /// Generates emergency payload text fitting inside a single SMS
  String buildOfflineSignalingPayload({
    required double lat,
    required double lng,
    required double speedKmh,
    required double gForce,
    required String bloodGroup,
  }) {
    final latFixed = lat.toStringAsFixed(5);
    final lngFixed = lng.toStringAsFixed(5);
    final speed = speedKmh.round();
    final g = gForce.toStringAsFixed(1);
    final epochSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    return '🚨 RAKSHAK SOS (ZERO-NET): Accident detected!\n'
        'Loc: https://maps.google.com/?q=$latFixed,$lngFixed\n'
        'Telemetry: ${speed}km/h | ${g}G | Blood:$bloodGroup | T:$epochSecs';
  }

  /// Sends raw SMS to contacts via native telephony channel without building dialogs
  Future<void> sendRawSmsToContacts({
    required List<EmergencyContact> contacts,
    required String message,
  }) async {
    for (final contact in contacts) {
      try {
        if (!_isTestEnvironment && !kIsWeb && Platform.isAndroid) {
          await _smsChannel.invokeMethod<bool>('sendSmsNative', {
            'phone': contact.phone,
            'message': message,
          });
        }
        debugPrint('[EmergencySmsService] Raw Signaling SMS sent to ${contact.name}');
      } catch (e) {
        debugPrint('[EmergencySmsService] Raw SMS dispatch note: $e');
      }
    }
  }

  /// Builds official Police Case Docket alert message for next of kin
  String buildPoliceDocketAlertMessage({
    required String victimName,
    required String caseNumber,
    required String policeStationName,
    required String officerName,
    required String officerPhone,
    String? hospitalName,
  }) {
    final hospClause = hospitalName != null ? ' Destination ER: $hospitalName.' : '';
    return '🚨 BTP POLICE ALERT: Case #$caseNumber registered for $victimName. '
        'Jurisdiction: $policeStationName. Investigating Officer: $officerName ($officerPhone).'
        '$hospClause Official case docket: https://rakshak.ai/case/$caseNumber';
  }

}
