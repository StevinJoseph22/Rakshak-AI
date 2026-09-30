import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakshak_mobile/screens/simulated_lock_screen.dart';

void main() {
  testWidgets('SimulatedLockScreen renders bystander banner and triggers override',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SimulatedLockScreen(),
      ),
    );
    await tester.pump();

    // Verify lock screen visuals
    expect(find.text('DEVICE LOCKED • DEMO BYSTANDER VIEW'), findsOneWidget);
    expect(find.text('Phone in Pocket / Locked Screen'), findsOneWidget);
    expect(find.text('SIMULATE CRASH IMPACT NOW'), findsOneWidget);

    // Tap simulate impact
    await tester.tap(find.text('SIMULATE CRASH IMPACT NOW'));
    await tester.pump();

    // Wait for the 500ms transition
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify override transitioned to LockedScreenAlertScreen
    expect(find.text('CRASH DETECTED'), findsOneWidget);
    expect(find.text('TAP TO ALERT AMBULANCE & POLICE'), findsOneWidget);
  });
}
