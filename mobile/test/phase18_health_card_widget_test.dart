import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rakshak_mobile/models/emergency_health_card_model.dart';
import 'package:rakshak_mobile/services/health_card_storage_service.dart';
import 'package:rakshak_mobile/screens/onboarding_screen.dart';
import 'package:rakshak_mobile/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 18: Emergency Health Card Model & Provenance Tests', () {
    test('HealthCardField model serializes and deserializes with provenance', () {
      final field = HealthCardField<String>(
        value: 'B+ Positive',
        source: 'ABDM_VERIFIED',
        status: 'AVAILABLE',
      );

      final json = field.toJson();
      expect(json['value'], 'B+ Positive');
      expect(json['source'], 'ABDM_VERIFIED');
      expect(json['status'], 'AVAILABLE');

      final parsed = HealthCardField<String>.fromJson(
        json,
        (v) => v as String?,
      );
      expect(parsed.value, 'B+ Positive');
      expect(parsed.source, 'ABDM_VERIFIED');
      expect(parsed.status, 'AVAILABLE');
      expect(parsed.isVerified, isTrue);
      expect(parsed.isAbdmVerified, isTrue);
      expect(parsed.isSelfDeclared, isFalse);
    });

    test('EmergencyHealthCard masking helper masks ABHA address safely', () {
      expect(
        EmergencyHealthCard.maskAbhaAddress('aarav.sharma@abdm'),
        'aa***@abdm',
      );
      expect(
        EmergencyHealthCard.maskAbhaAddress('rohit@abdm'),
        'ro***@abdm',
      );
      expect(
        EmergencyHealthCard.maskAbhaAddress(null),
        null,
      );
    });

    test('EmergencyHealthCard creates unlinked empty card with reasons', () {
      final empty = EmergencyHealthCard.empty();
      expect(empty.isLinked, isFalse);
      expect(empty.bloodGroup.status, 'NOT_AVAILABLE');
      expect(empty.bloodGroup.reason, 'Not provided');
      expect(empty.allergies.value, isEmpty);
    });
  });

  group('Phase 18: Onboarding Screen Widget Tests', () {
    testWidgets('Onboarding skip path completes without ABHA or health info',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Permissions
      expect(find.text('Emergency Sensing Permissions'), findsOneWidget);
      final allowButton = find.byKey(const Key('permissions_continue_button'));
      expect(allowButton, findsOneWidget);
      await tester.ensureVisible(allowButton);
      await tester.tap(allowButton);
      await tester.pumpAndSettle();

      // Step 2: Emergency Contacts
      expect(find.text('Primary Emergency Contact'), findsOneWidget);
      final contactButton = find.byKey(const Key('contact_continue_button'));
      expect(contactButton, findsOneWidget);
      await tester.ensureVisible(contactButton);
      await tester.tap(contactButton);
      await tester.pumpAndSettle();

      // Step 3: Link ABHA (Optional & Skippable)
      expect(find.text('Link Ayushman Bharat (ABHA)'), findsOneWidget);
      final skipAbhaButton = find.byKey(const Key('skip_abha_button'));
      expect(skipAbhaButton, findsOneWidget);
      await tester.ensureVisible(skipAbhaButton);
      await tester.tap(skipAbhaButton);
      await tester.pumpAndSettle();

      // Step 4: Emergency Health Info (Optional & Skippable)
      expect(find.text('Emergency Health Information'), findsOneWidget);
      final skipHealthButton = find.byKey(const Key('skip_health_info_button'));
      expect(skipHealthButton, findsOneWidget);
      await tester.ensureVisible(skipHealthButton);
      await tester.tap(skipHealthButton);
      await tester.pumpAndSettle();

      // Step 5: Summary & Explicit Consent
      expect(find.text('Emergency Data Sharing Consent'), findsOneWidget);
      expect(find.text('WHAT IS SHARED'), findsOneWidget);
      expect(find.text('WITH WHOM'), findsOneWidget);
      expect(find.text('WHEN'), findsOneWidget);
      expect(find.text('FOR HOW LONG'), findsOneWidget);

      final finishButton = find.byKey(const Key('finish_onboarding_button'));
      expect(finishButton, findsOneWidget);
      await tester.ensureVisible(finishButton);
      await tester.tap(finishButton);
      await tester.pumpAndSettle();

      // Verify stored card is unlinked and contains no fabricated records
      final savedCard = await HealthCardStorageService.instance.getHealthCard();
      expect(savedCard.isLinked, isFalse);
      expect(savedCard.bloodGroup.status, 'NOT_AVAILABLE');
      expect(savedCard.allergies.value, isEmpty);
    });
  });

  group('Phase 18: Settings Screen & Unlink/Delete Widget Tests', () {
    testWidgets('Settings screen shows unlinked state and navigates correctly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Emergency Health Settings'), findsOneWidget);
      expect(find.text('ABHA Not Linked (Optional)'), findsOneWidget);
      expect(find.byKey(const Key('settings_unlink_button')), findsOneWidget);
    });

    testWidgets('Unlink and wipe button clears stored card and resets UI',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Pre-seed a linked card using HealthCardStorageService
      await HealthCardStorageService.instance.saveAbdmVerifiedData(
        profile: {
          'abhaAddress': 'priya.sharma@abdm',
          'abhaNumber': '91-1234-5678-9012',
          'name': 'Priya Sharma',
          'gender': 'Female',
          'age': 29,
        },
        records: {
          'status': 'AVAILABLE',
          'blood_group': 'O+ Positive',
          'allergies': ['Sulfa Drugs'],
          'chronic_conditions': <String>[],
          'current_medications': <String>[],
          'organ_donor_status': 'NOTTO Registered Organ Donor',
        },
        sessionToken: 'test_session_token_123',
        mode: 'MOCK',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Card is currently linked with masked address
      expect(find.text('ABHA Linked & Active'), findsOneWidget);
      expect(find.text('Address: pr***@abdm'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('O+ Positive'), findsOneWidget);

      // Tap Unlink ABHA & Wipe button
      final unlinkButton = find.byKey(const Key('settings_unlink_button'));
      expect(unlinkButton, findsOneWidget);
      await tester.ensureVisible(unlinkButton);
      await tester.tap(unlinkButton);
      await tester.pumpAndSettle();

      // Confirmation dialog opens
      expect(find.text('Unlink & Wipe Health Data?'), findsOneWidget);
      final confirmUnlinkButton = find.byKey(const Key('confirm_dialog_unlink_button'));
      expect(confirmUnlinkButton, findsOneWidget);
      await tester.tap(confirmUnlinkButton);
      await tester.pumpAndSettle();

      // Storage has been wiped
      final wipedCard = await HealthCardStorageService.instance.getHealthCard();
      expect(wipedCard.isLinked, isFalse);
      expect(wipedCard.name.status, 'NOT_AVAILABLE');

      // UI returns to unlinked status
      expect(find.text('ABHA Not Linked (Optional)'), findsOneWidget);
    });
  });
}
