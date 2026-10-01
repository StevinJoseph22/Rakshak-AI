import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakshak_mobile/main.dart';
import 'package:rakshak_mobile/screens/intake_screen.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.rakshak.mobile/lock_screen'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'canUseFullScreenIntent':
            return true;
          case 'enableLockScreenDisplay':
            return true;
          case 'triggerFullScreenAlert':
            return true;
          default:
            return null;
        }
      },
    );
  });
  testWidgets('CrashDetectionScreen builds and toggles guard status',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RakshakApp());
    await tester.pump();

    // Verify initial active state
    expect(find.text('Rakshak-AI Guard'), findsOneWidget);
    expect(find.text('Crash Guard Active: Monitoring Telemetry'), findsOneWidget);

    // Toggle to Pause
    await tester.tap(find.text('Pause Guard'));
    await tester.pump();
    expect(find.text('Monitoring Paused'), findsOneWidget);

    // Toggle back to Activate
    await tester.tap(find.text('Activate Guard'));
    await tester.pump();
    expect(find.text('Crash Guard Active: Monitoring Telemetry'), findsOneWidget);

    // Verify professional presentation dashboard is rendered by default
    expect(find.text('Protection Telemetry'), findsOneWidget);
    expect(find.text('Speed Monitor'), findsOneWidget);
    expect(find.text('ONE-TOUCH EMERGENCY SOS'), findsOneWidget);
  });

  testWidgets('Simulation harness renders sliders and trigger button in Test Lab',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RakshakApp());
    await tester.pumpAndSettle();

    // Switch to Test Lab mode
    await tester.tap(find.text('Test Lab').first);
    await tester.pumpAndSettle();

    expect(find.text('Crash Simulation Harness'), findsOneWidget);
    expect(find.text('Deceleration:'), findsOneWidget);
    expect(find.text('Speed Drop:'), findsOneWidget);

    final triggerFinder = find.text('TRIGGER IMPACT SIGNATURE');
    await tester.ensureVisible(triggerFinder);
    expect(triggerFinder, findsOneWidget);
  });

  testWidgets('Triggering impact signature navigates to LockedScreenAlertScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RakshakApp());
    await tester.pumpAndSettle();

    // Switch to Test Lab mode
    await tester.tap(find.text('Test Lab').first);
    await tester.pumpAndSettle();

    // Scroll until trigger button is visible in the viewport
    final triggerFinder = find.text('TRIGGER IMPACT SIGNATURE');
    await tester.ensureVisible(triggerFinder);
    await tester.pumpAndSettle();

    await tester.tap(triggerFinder);
    // Allow async permission checks and method channel calls to resolve
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // Complete route transition

    // Verify on LockedScreenAlertScreen
    expect(find.text('CRASH DETECTED'), findsOneWidget);
    expect(find.text('TAP TO ALERT AMBULANCE & POLICE'), findsOneWidget);
    expect(find.text('CONFIRM & DISPATCH HELP NOW'), findsOneWidget);
    expect(find.text("I'm Okay — Cancel SOS"), findsOneWidget);

    // Tap cancel to return
    await tester.tap(find.text("I'm Okay — Cancel SOS"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Rakshak-AI Guard'), findsOneWidget);
  });

  testWidgets('IntakeScreen displays Zero-Gallery Privacy banner and camera prompt',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: IntakeScreen(),
      ),
    );
    await tester.pump();

    // Verify Zero-Gallery Privacy Guarantee
    expect(find.text('Zero-Gallery Privacy Guarantee'), findsOneWidget);
    expect(find.textContaining('volatile RAM memory'), findsOneWidget);
    expect(find.text('Capture Incident / Injury Photo'), findsOneWidget);
    expect(find.text('Skip Photo & Return to Guard'), findsOneWidget);
  });
}
