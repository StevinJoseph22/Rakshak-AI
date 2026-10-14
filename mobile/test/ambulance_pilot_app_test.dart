import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakshak_mobile/main_ambulance.dart';
import 'package:rakshak_mobile/screens/ambulance_pilot_home_screen.dart';

void main() {
  testWidgets('RakshakAmbulanceApp builds and renders EMS tactical cockpit',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RakshakAmbulanceApp());
    await tester.pump();

    // Verify header branding
    expect(find.text('RAKSHAK ResQ PILOT'), findsOneWidget);
    expect(find.textContaining('Ambulance-BLR-01'), findsWidgets);
    expect(find.text('KA-01-EA-108'), findsOneWidget);
    expect(find.textContaining('Ramesh Kumar'), findsOneWidget);

    // Verify C-V2X Green Corridor Ribbon
    expect(
      find.textContaining('5.9 GHz DSRC Online'),
      findsOneWidget,
    );
    expect(find.text('SAE J2735 / NTCIP 1202'), findsOneWidget);

    // Verify Dispatch Radar tab (default)
    expect(find.text('Dispatch Radar'), findsOneWidget);
    expect(find.text('Trauma Bays'), findsOneWidget);
    expect(find.text('Paramedic Tools'), findsOneWidget);

    // Verify Claim Mission Action Button is present
    expect(find.text('CLAIM & ENGAGE C-V2X GREEN CORRIDOR'), findsWidgets);

    // Switch to Trauma Bays tab
    await tester.tap(find.text('Trauma Bays'));
    await tester.pumpAndSettle();
    expect(find.textContaining('LEVEL-1 TRAUMA HUBS'), findsOneWidget);
    expect(find.textContaining('Manipal Hospital'), findsWidgets);

    // Switch to Paramedic Tools tab
    await tester.tap(find.text('Paramedic Tools'));
    await tester.pumpAndSettle();
    expect(find.text('RAPID RESPONSE PARAMEDIC SUITE'), findsOneWidget);
    expect(find.text('ABHA Medical Vault Decryptor'), findsOneWidget);
    expect(find.text('C-V2X Green Corridor Signal Force'), findsOneWidget);

    final vitalsFinder = find.text('Live Pre-Arrival Vitals Streamer');
    await tester.ensureVisible(vitalsFinder);
    await tester.pumpAndSettle();
    expect(vitalsFinder, findsOneWidget);

    // Tap Citizen App switcher button
    await tester.tap(find.text('Citizen App'));
    await tester.pumpAndSettle();
    expect(find.text('Rakshak-AI Guard'), findsOneWidget);
  });
}
