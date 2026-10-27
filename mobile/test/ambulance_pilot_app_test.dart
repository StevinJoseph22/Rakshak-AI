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

    // Verify Automatic Shift Status Badge (Manual Dropdown removed!)
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.textContaining('DISPATCH READY'), findsOneWidget);
    expect(find.text('AUTOMATIC EMS SYNC'), findsOneWidget);

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

    // Verify Clean Card details: Prominent Blood Group & Location
    expect(find.text('B+ Positive'), findsWidgets);
    expect(find.text('Silk Board Central Junction'), findsOneWidget);

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
    expect(find.text('C-V2X Green Corridor Signal Force [SIMULATED]'), findsOneWidget);

    final vitalsFinder = find.text('Live Pre-Arrival Vitals Streamer');
    await tester.ensureVisible(vitalsFinder);
    await tester.pumpAndSettle();
    expect(vitalsFinder, findsOneWidget);

    // Tap Citizen App switcher button
    await tester.tap(find.text('Citizen App'));
    await tester.pumpAndSettle();
    expect(find.text('Rakshak-AI Guard'), findsOneWidget);
  });

  testWidgets('Ambulance app multi-language switcher updates UI to Indian languages',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RakshakAmbulanceApp());
    await tester.pump();

    // Default language button shows 'English'
    final langBtn = find.text('English');
    expect(langBtn, findsOneWidget);

    // Tap language selector
    await tester.tap(langBtn);
    await tester.pumpAndSettle();

    // Modal sheet opens with Indian languages
    expect(find.text('Select Ambulance Pilot Language'), findsOneWidget);
    expect(find.text('हिन्दी'), findsOneWidget);
    expect(find.text('ಕನ್ನಡ'), findsOneWidget);
    expect(find.text('தமிழ்'), findsOneWidget);

    final teluguFinder = find.text('తెలుగు');
    await tester.ensureVisible(teluguFinder);
    await tester.pumpAndSettle();
    expect(teluguFinder, findsOneWidget);

    // Select Kannada (local Karnataka/Bengaluru deployment)
    await tester.tap(find.text('ಕನ್ನಡ'));
    await tester.pumpAndSettle();

    // Verify UI has updated dynamically to Kannada
    expect(find.text('ಕನ್ನಡ'), findsOneWidget);
    expect(find.text('ಡಿಸ್ಪ್ಯಾಚ್ ರಾಡಾರ್'), findsOneWidget);
    expect(find.text('ಟ್ರಾಮಾ ಆಸ್ಪತ್ರೆಗಳು'), findsOneWidget);
    expect(find.text('ಪ್ಯಾರಾಮೆಡಿಕ್ ಪರಿಕರಗಳು'), findsOneWidget);
    expect(find.textContaining('ನಿಯೋಜನೆಗೆ ಸಿದ್ಧ'), findsOneWidget);
    expect(find.text('ಸ್ವಯಂಚಾಲಿತ ಇಎಂಎಸ್ ಸಿಂಕ್'), findsOneWidget);
    expect(find.text('ಸ್ವೀಕರಿಸಿ & ಗ್ರೀನ್ ಕಾರಿಡಾರ್ ಸಕ್ರಿಯಗೊಳಿಸಿ'), findsWidgets);

    // Switch to Hindi
    await tester.tap(find.text('ಕನ್ನಡ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();

    // Verify UI has updated dynamically to Hindi
    expect(find.text('हिन्दी'), findsOneWidget);
    expect(find.text('डिस्पैच रडार'), findsOneWidget);
    expect(find.text('ट्रॉमा अस्पताल'), findsOneWidget);
    expect(find.text('पैरामेडिक टूल्स'), findsOneWidget);
    expect(find.textContaining('तैनात / तैयार'), findsOneWidget);
    expect(find.text('स्वचालित ईएमएस सिंक'), findsOneWidget);
    expect(find.text('स्वीकारें और ग्रीन कॉरिडोर शुरू करें'), findsWidgets);
  });
}
