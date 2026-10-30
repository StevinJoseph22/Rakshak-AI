import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized Theme & Visual Identity Management Service for Rakshak-AI.
/// Supports seamless switching between Executive Dark and Crisp Executive Light themes.
class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const String _prefKey = 'rakshak_theme_mode';

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);

  bool get isDarkMode => themeMode.value == ThemeMode.dark;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_prefKey);
      if (savedMode == 'light') {
        themeMode.value = ThemeMode.light;
      } else {
        themeMode.value = ThemeMode.dark;
      }
    } catch (_) {
      themeMode.value = ThemeMode.dark;
    }
  }

  Future<void> toggleTheme() async {
    final next = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    themeMode.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, next == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  Future<void> setDarkMode(bool enableDark) async {
    final next = enableDark ? ThemeMode.dark : ThemeMode.light;
    themeMode.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, enableDark ? 'dark' : 'light');
    } catch (_) {}
  }

  // ==========================================
  // UNIFIED THEME DATA DEFINITIONS
  // ==========================================

  ThemeData get darkTheme => ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFEF4444),
          secondary: Color(0xFF38BDF8),
          surface: Color(0xFF111827),
          error: Color(0xFFEF4444),
        ),
        scaffoldBackgroundColor: const Color(0xFF090D16),
        canvasColor: const Color(0xFF090D16),
        cardColor: const Color(0xFF111827),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF090D16),
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.3,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0D1322),
          selectedItemColor: Color(0xFFEF4444),
          unselectedItemColor: Color(0xFF64748B),
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: TextStyle(fontSize: 10.5),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
      );

  ThemeData get lightTheme => ThemeData.light().copyWith(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFDC2626),
          secondary: Color(0xFF0284C7),
          surface: Colors.white,
          error: Color(0xFFDC2626),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        canvasColor: const Color(0xFFF8FAFC),
        cardColor: Colors.white,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0.5,
          scrolledUnderElevation: 0.5,
          iconTheme: IconThemeData(color: Color(0xFF0F172A)),
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.3,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFFDC2626),
          unselectedItemColor: Color(0xFF64748B),
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: TextStyle(fontSize: 10.5),
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
      );
}
