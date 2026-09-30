import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rakshak_mobile/services/emergency_sms_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EmergencySmsService Tests', () {
    test('Crash alert message formatting contains victim name, location, and Google Maps link', () {
      final service = EmergencySmsService.instance;
      final msg = service.buildCrashAlertMessage(
        victimName: 'Rahul Verma',
        lat: 12.97160,
        lng: 77.59460,
      );

      expect(msg.contains('RAKSHAK-AI ALERT: Rahul Verma may have been in an accident.'), isTrue);
      expect(msg.contains('https://maps.google.com/?q=12.97160,77.59460'), isTrue);
      expect(msg.contains('Emergency services have been notified.'), isTrue);
    });

    test('Hospital accepted update message formatting contains hospital details', () {
      final service = EmergencySmsService.instance;
      final msg = service.buildHospitalAcceptedMessage(
        victimName: 'Rahul Verma',
        hospitalName: 'Apollo Trauma Bay',
        hospitalAddress: 'Bannerghatta Road, Bengaluru',
        hospitalPhone: '+91-80-26304050',
      );

      expect(msg.contains('UPDATE: Rahul Verma has been accepted by Apollo Trauma Bay, Bannerghatta Road, Bengaluru.'), isTrue);
      expect(msg.contains('Hospital contact: +91-80-26304050.'), isTrue);
    });

    test('Phone number cleaning handles 10-digit, plus signs, and spaces for WhatsApp', () {
      final service = EmergencySmsService.instance;
      expect(service.cleanPhoneNumberForWhatsApp('9876543210'), '919876543210');
      expect(service.cleanPhoneNumberForWhatsApp('+91 98765 43210'), '919876543210');
      expect(service.cleanPhoneNumberForWhatsApp('+91-9876543210'), '919876543210');
    });

    test('sendCrashAlert executes in test environment without throwing and returns dispatch result', () async {
      final service = EmergencySmsService.instance;
      final result = await service.sendCrashAlert(lat: 12.9716, lng: 77.5946);

      expect(result.success, isTrue);
      expect(result.totalContacts, greaterThanOrEqualTo(1));
      expect(result.messageBody.contains('RAKSHAK-AI ALERT'), isTrue);
    });

    test('sendHospitalAcceptedAlert executes in test environment without throwing', () async {
      final service = EmergencySmsService.instance;
      final result = await service.sendHospitalAcceptedAlert(
        hospitalName: 'Manipal Emergency Care',
        hospitalAddress: 'HAL Old Airport Rd',
        hospitalPhone: '080-25024444',
      );

      expect(result.success, isTrue);
      expect(result.totalContacts, greaterThanOrEqualTo(1));
      expect(result.messageBody.contains('UPDATE:'), isTrue);
    });
  });
}
