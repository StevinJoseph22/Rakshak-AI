import 'package:flutter_test/flutter_test.dart';
import 'package:rakshak_mobile/config/lock_screen_config.dart';

void main() {
  group('LockScreenConfig Tests', () {
    test('default configuration selects real full-screen intent (A)', () {
      expect(kUseRealFullScreenIntent, isTrue,
          reason: 'Default mode must be real full-screen intent (A) per user decision');
      expect(kLockScreenMethodChannel, 'com.rakshak.mobile/lock_screen');
      expect(kEmergencyNotificationChannelId, 'rakshak_emergency_sos');
    });
  });
}
