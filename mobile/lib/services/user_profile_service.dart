import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Data model representing the citizen's personalized profile and registered vehicle
class UserProfile {
  final String userName;
  final String phone;
  final String vehicleType; // 'Two-Wheeler' or 'Four-Wheeler'
  final String vehicleModel;
  final String vehiclePlate;
  final String bloodGroup;
  final double todayDistanceKm;
  final int safetyDrivingScore;
  final int overSpeedingCount;
  final int suddenBrakingCount;

  const UserProfile({
    this.userName = 'Stevin Joseph',
    this.phone = '+91 90743 38964',
    this.vehicleType = 'Two-Wheeler',
    this.vehicleModel = 'Yamaha MT-15',
    this.vehiclePlate = 'KA-05-AB-1234',
    this.bloodGroup = 'B+ Positive',
    this.todayDistanceKm = 14.8,
    this.safetyDrivingScore = 98,
    this.overSpeedingCount = 0,
    this.suddenBrakingCount = 0,
  });

  bool get isTwoWheeler => vehicleType == 'Two-Wheeler';

  UserProfile copyWith({
    String? userName,
    String? phone,
    String? vehicleType,
    String? vehicleModel,
    String? vehiclePlate,
    String? bloodGroup,
    double? todayDistanceKm,
    int? safetyDrivingScore,
    int? overSpeedingCount,
    int? suddenBrakingCount,
  }) {
    return UserProfile(
      userName: userName ?? this.userName,
      phone: phone ?? this.phone,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      todayDistanceKm: todayDistanceKm ?? this.todayDistanceKm,
      safetyDrivingScore: safetyDrivingScore ?? this.safetyDrivingScore,
      overSpeedingCount: overSpeedingCount ?? this.overSpeedingCount,
      suddenBrakingCount: suddenBrakingCount ?? this.suddenBrakingCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'phone': phone,
        'vehicleType': vehicleType,
        'vehicleModel': vehicleModel,
        'vehiclePlate': vehiclePlate,
        'bloodGroup': bloodGroup,
        'todayDistanceKm': todayDistanceKm,
        'safetyDrivingScore': safetyDrivingScore,
        'overSpeedingCount': overSpeedingCount,
        'suddenBrakingCount': suddenBrakingCount,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userName: json['userName'] as String? ?? 'Stevin Joseph',
      phone: json['phone'] as String? ?? '+91 90743 38964',
      vehicleType: json['vehicleType'] as String? ?? 'Two-Wheeler',
      vehicleModel: json['vehicleModel'] as String? ?? 'Yamaha MT-15',
      vehiclePlate: json['vehiclePlate'] as String? ?? 'KA-05-AB-1234',
      bloodGroup: json['bloodGroup'] as String? ?? 'B+ Positive',
      todayDistanceKm: (json['todayDistanceKm'] as num?)?.toDouble() ?? 14.8,
      safetyDrivingScore: (json['safetyDrivingScore'] as num?)?.toInt() ?? 98,
      overSpeedingCount: (json['overSpeedingCount'] as num?)?.toInt() ?? 0,
      suddenBrakingCount: (json['suddenBrakingCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Service managing persistent user profile, connected vehicle details, and driving stats
class UserProfileService {
  UserProfileService._internal();
  static final UserProfileService _instance = UserProfileService._internal();
  static UserProfileService get instance => _instance;

  static const String _storageKey = 'rakshak_citizen_user_profile';
  static const String _welcomeShownKey = 'rakshak_welcome_screen_shown';

  UserProfile _profile = const UserProfile();
  final ValueNotifier<UserProfile> profileNotifier = ValueNotifier<UserProfile>(const UserProfile());

  UserProfile get profile => _profile;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString(_storageKey);
      if (dataStr != null) {
        final Map<String, dynamic> decoded = jsonDecode(dataStr);
        _profile = UserProfile.fromJson(decoded);
        profileNotifier.value = _profile;
      }
    } catch (e) {
      debugPrint('[UserProfileService] Init note: $e');
    }
  }

  Future<bool> hasSeenWelcomeScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_welcomeShownKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setWelcomeScreenSeen(bool seen) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_welcomeShownKey, seen);
    } catch (_) {}
  }

  Future<void> saveProfile(UserProfile updated) async {
    _profile = updated;
    profileNotifier.value = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(updated.toJson()));
    } catch (e) {
      debugPrint('[UserProfileService] Save error: $e');
    }
  }
}
