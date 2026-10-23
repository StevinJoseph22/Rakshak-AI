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
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        primaryColor: const Color(0xFFDC2626),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFDC2626),
          secondary: Color(0xFFF59E0B),
          surface: Color(0xFF1E293B),
          background: Color(0xFF0B0F19),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E293B),
          elevation: 2,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          elevation: 0,
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
