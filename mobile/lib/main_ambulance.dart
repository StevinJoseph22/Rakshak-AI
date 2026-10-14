import 'package:flutter/material.dart';
import 'screens/ambulance_pilot_home_screen.dart';
import 'main.dart';

void main() {
  runApp(const RakshakAmbulanceApp());
}

/// Standalone Emergency Medical Services (EMS) Application for Ambulance Pilots & Paramedics.
/// Can be executed independently via:
/// `flutter run -t lib/main_ambulance.dart`
class RakshakAmbulanceApp extends StatelessWidget {
  const RakshakAmbulanceApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: RakshakAmbulanceApp.navigatorKey,
      title: 'Rakshak ResQ Pilot - EMS Tactical Cockpit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070D1F),
        primaryColor: const Color(0xFF00E5FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFF1744),
          surface: Color(0xFF0E1A38),
          background: Color(0xFF070D1F),
        ),
        useMaterial3: true,
      ),
      home: AmbulancePilotHomeScreen(
        onSwitchToCitizenApp: () {
          Navigator.of(RakshakAmbulanceApp.navigatorKey.currentContext!).pushReplacement(
            MaterialPageRoute(builder: (_) => const RakshakApp()),
          );
        },
      ),
    );
  }
}
