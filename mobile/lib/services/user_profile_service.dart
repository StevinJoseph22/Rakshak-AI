import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_contact_model.dart';
import 'emergency_contact_service.dart';
import 'health_card_storage_service.dart';

/// Data model representing the citizen's personalized profile and registered vehicle
class UserProfile {
  final String userName;
  final String userEmail;
  final String phone;
  final bool isPhoneVerified;
  final String vehicleType; // 'Two-Wheeler' or 'Four-Wheeler'
  final String vehicleModel;
  final String vehiclePlate;
  final String bloodGroup;
  final double todayDistanceKm;
  final int safetyDrivingScore;
  final int overSpeedingCount;
  final int suddenBrakingCount;

  // Citizen Registration & Emergency Vault metadata
  final bool isRegistered;
  final String authMethod; // 'GOOGLE', 'MANUAL', 'DEMO_SANDBOX'

  // Contact 1 (Mandatory Primary)
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String emergencyContactRelation;

  // Contact 2 (Mandatory Secondary)
  final String secondaryContactName;
  final String secondaryContactPhone;
  final String secondaryContactRelation;

  // Contact 3 (Optional)
  final String? tertiaryContactName;
  final String? tertiaryContactPhone;
  final String? tertiaryContactRelation;

  // ABHA Health Card (Optional)
  final bool hasAbhaCard;
  final String abhaNumber;
  final String abhaAddress;
  final List<String> criticalAllergies;
  final List<String> chronicConditions;
  final List<String> currentMedications;

  const UserProfile({
    this.userName = '',
    this.userEmail = '',
    this.phone = '',
    this.isPhoneVerified = false,
    this.vehicleType = 'Two-Wheeler',
    this.vehicleModel = 'Two-Wheeler',
    this.vehiclePlate = '',
    this.bloodGroup = 'O+ Positive',
    this.todayDistanceKm = 0.0,
    this.safetyDrivingScore = 100,
    this.overSpeedingCount = 0,
    this.suddenBrakingCount = 0,
    this.isRegistered = false,
    this.authMethod = 'NONE',
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    this.emergencyContactRelation = 'Spouse',
    this.secondaryContactName = '',
    this.secondaryContactPhone = '',
    this.secondaryContactRelation = 'Parent',
    this.tertiaryContactName,
    this.tertiaryContactPhone,
    this.tertiaryContactRelation,
    this.hasAbhaCard = false,
    this.abhaNumber = '',
    this.abhaAddress = '',
    this.criticalAllergies = const [],
    this.chronicConditions = const [],
    this.currentMedications = const [],
  });

  bool get isTwoWheeler => vehicleType == 'Two-Wheeler';
  String get fullName => userName;

  UserProfile copyWith({
    String? userName,
    String? userEmail,
    String? phone,
    bool? isPhoneVerified,
    String? vehicleType,
    String? vehicleModel,
    String? vehiclePlate,
    String? bloodGroup,
    double? todayDistanceKm,
    int? safetyDrivingScore,
    int? overSpeedingCount,
    int? suddenBrakingCount,
    bool? isRegistered,
    String? authMethod,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
    String? secondaryContactName,
    String? secondaryContactPhone,
    String? secondaryContactRelation,
    String? tertiaryContactName,
    String? tertiaryContactPhone,
    String? tertiaryContactRelation,
    bool? hasAbhaCard,
    String? abhaNumber,
    String? abhaAddress,
    List<String>? criticalAllergies,
    List<String>? chronicConditions,
    List<String>? currentMedications,
  }) {
    return UserProfile(
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      phone: phone ?? this.phone,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      todayDistanceKm: todayDistanceKm ?? this.todayDistanceKm,
      safetyDrivingScore: safetyDrivingScore ?? this.safetyDrivingScore,
      overSpeedingCount: overSpeedingCount ?? this.overSpeedingCount,
      suddenBrakingCount: suddenBrakingCount ?? this.suddenBrakingCount,
      isRegistered: isRegistered ?? this.isRegistered,
      authMethod: authMethod ?? this.authMethod,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      emergencyContactRelation: emergencyContactRelation ?? this.emergencyContactRelation,
      secondaryContactName: secondaryContactName ?? this.secondaryContactName,
      secondaryContactPhone: secondaryContactPhone ?? this.secondaryContactPhone,
      secondaryContactRelation: secondaryContactRelation ?? this.secondaryContactRelation,
      tertiaryContactName: tertiaryContactName ?? this.tertiaryContactName,
      tertiaryContactPhone: tertiaryContactPhone ?? this.tertiaryContactPhone,
      tertiaryContactRelation: tertiaryContactRelation ?? this.tertiaryContactRelation,
      hasAbhaCard: hasAbhaCard ?? this.hasAbhaCard,
      abhaNumber: abhaNumber ?? this.abhaNumber,
      abhaAddress: abhaAddress ?? this.abhaAddress,
      criticalAllergies: criticalAllergies ?? this.criticalAllergies,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      currentMedications: currentMedications ?? this.currentMedications,
    );
  }

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'userEmail': userEmail,
        'phone': phone,
        'isPhoneVerified': isPhoneVerified,
        'vehicleType': vehicleType,
        'vehicleModel': vehicleModel,
        'vehiclePlate': vehiclePlate,
        'bloodGroup': bloodGroup,
        'todayDistanceKm': todayDistanceKm,
        'safetyDrivingScore': safetyDrivingScore,
        'overSpeedingCount': overSpeedingCount,
        'suddenBrakingCount': suddenBrakingCount,
        'isRegistered': isRegistered,
        'authMethod': authMethod,
        'emergencyContactName': emergencyContactName,
        'emergencyContactPhone': emergencyContactPhone,
        'emergencyContactRelation': emergencyContactRelation,
        'secondaryContactName': secondaryContactName,
        'secondaryContactPhone': secondaryContactPhone,
        'secondaryContactRelation': secondaryContactRelation,
        'tertiaryContactName': tertiaryContactName,
        'tertiaryContactPhone': tertiaryContactPhone,
        'tertiaryContactRelation': tertiaryContactRelation,
        'hasAbhaCard': hasAbhaCard,
        'abhaNumber': abhaNumber,
        'abhaAddress': abhaAddress,
        'criticalAllergies': criticalAllergies,
        'chronicConditions': chronicConditions,
        'currentMedications': currentMedications,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userName: json['userName'] as String? ?? 'Stevin Joseph',
      userEmail: json['userEmail'] as String? ?? 'stevinjoseph@gmail.com',
      phone: json['phone'] as String? ?? '+91 90743 38964',
      isPhoneVerified: json['isPhoneVerified'] as bool? ?? true,
      vehicleType: json['vehicleType'] as String? ?? 'Two-Wheeler',
      vehicleModel: json['vehicleModel'] as String? ?? 'Yamaha MT-15',
      vehiclePlate: json['vehiclePlate'] as String? ?? 'KA-05-AB-1234',
      bloodGroup: json['bloodGroup'] as String? ?? 'O+ Positive',
      todayDistanceKm: (json['todayDistanceKm'] as num?)?.toDouble() ?? 14.8,
      safetyDrivingScore: (json['safetyDrivingScore'] as num?)?.toInt() ?? 98,
      overSpeedingCount: (json['overSpeedingCount'] as num?)?.toInt() ?? 0,
      suddenBrakingCount: (json['suddenBrakingCount'] as num?)?.toInt() ?? 0,
      isRegistered: json['isRegistered'] as bool? ?? false,
      authMethod: json['authMethod'] as String? ?? 'GOOGLE',
      emergencyContactName: json['emergencyContactName'] as String? ?? 'Anjali Sharma',
      emergencyContactPhone: json['emergencyContactPhone'] as String? ?? '+91 98765 43211',
      emergencyContactRelation: json['emergencyContactRelation'] as String? ?? 'Spouse',
      secondaryContactName: json['secondaryContactName'] as String? ?? 'Rajesh Joseph',
      secondaryContactPhone: json['secondaryContactPhone'] as String? ?? '+91 98450 12345',
      secondaryContactRelation: json['secondaryContactRelation'] as String? ?? 'Parent',
      tertiaryContactName: json['tertiaryContactName'] as String?,
      tertiaryContactPhone: json['tertiaryContactPhone'] as String?,
      tertiaryContactRelation: json['tertiaryContactRelation'] as String?,
      hasAbhaCard: json['hasAbhaCard'] as bool? ?? true,
      abhaNumber: json['abhaNumber'] as String? ?? '91-4829-1029-4821',
      abhaAddress: json['abhaAddress'] as String? ?? 'stevin.joseph@abdm',
      criticalAllergies: (json['criticalAllergies'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const ['Penicillin Anaphylaxis', 'Sulfa Drugs'],
      chronicConditions: (json['chronicConditions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const ['Asthma', 'Type 2 Diabetes'],
      currentMedications: (json['currentMedications'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const ['Salbutamol Inhaler', 'Metformin 500mg'],
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

  /// Saves updated profile and cross-syncs with EmergencyContactService and HealthCardStorageService
  Future<void> saveProfile(UserProfile updated) async {
    _profile = updated;
    profileNotifier.value = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(updated.toJson()));

      // 1. Cross-sync victim name with EmergencyContactService
      await EmergencyContactService.instance.setVictimName(updated.userName);

      // 2. Cross-sync mandatory 2 emergency contacts (+ optional 3rd)
      final contacts = <EmergencyContact>[];
      if (updated.emergencyContactPhone.isNotEmpty) {
        contacts.add(EmergencyContact(
          id: 'primary-registered',
          name: updated.emergencyContactName.isNotEmpty ? updated.emergencyContactName : 'Primary Contact',
          phone: updated.emergencyContactPhone,
          relationship: updated.emergencyContactRelation.isNotEmpty ? updated.emergencyContactRelation : 'Spouse',
          isPrimary: true,
        ));
      }
      if (updated.secondaryContactPhone.isNotEmpty) {
        contacts.add(EmergencyContact(
          id: 'secondary-registered',
          name: updated.secondaryContactName.isNotEmpty ? updated.secondaryContactName : 'Secondary Contact',
          phone: updated.secondaryContactPhone,
          relationship: updated.secondaryContactRelation.isNotEmpty ? updated.secondaryContactRelation : 'Parent',
          isPrimary: false,
        ));
      }
      if (updated.tertiaryContactPhone != null && updated.tertiaryContactPhone!.isNotEmpty) {
        contacts.add(EmergencyContact(
          id: 'tertiary-registered',
          name: updated.tertiaryContactName ?? 'Emergency Contact 3',
          phone: updated.tertiaryContactPhone!,
          relationship: updated.tertiaryContactRelation ?? 'Family',
          isPrimary: false,
        ));
      }
      if (contacts.isNotEmpty) {
        await EmergencyContactService.instance.saveContacts(contacts);
      }

      // 3. Cross-sync verified ABDM Health Card storage
      if (updated.hasAbhaCard) {
        await HealthCardStorageService.instance.saveAbdmVerifiedData(
          profile: {
            'name': updated.userName,
            'abhaNumber': updated.abhaNumber,
            'abhaAddress': updated.abhaAddress,
            'gender': 'Specified',
            'age': 28,
          },
          records: {
            'status': 'AVAILABLE',
            'blood_group': updated.bloodGroup,
            'allergies': updated.criticalAllergies,
            'chronic_conditions': updated.chronicConditions,
            'current_medications': updated.currentMedications,
            'organ_donor_status': 'Registered Organ Donor',
          },
          sessionToken: 'ABDM-SESSION-VERIFIED',
          mode: 'MOCK',
        );
      } else {
        await HealthCardStorageService.instance.saveSelfDeclaredData(
          name: updated.userName,
          bloodGroup: updated.bloodGroup,
          allergies: updated.criticalAllergies,
          conditions: updated.chronicConditions,
          medications: updated.currentMedications,
        );
      }

      debugPrint('[UserProfileService] Synchronized multi-contact profile & ABHA vault across Edge Guard');
    } catch (e) {
      debugPrint('[UserProfileService] Save error: $e');
    }
  }

  Future<void> clearProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      _profile = const UserProfile(
        userName: '',
        userEmail: '',
        phone: '',
        vehicleModel: '',
        vehiclePlate: '',
        bloodGroup: '',
        todayDistanceKm: 0,
        safetyDrivingScore: 100,
        overSpeedingCount: 0,
        suddenBrakingCount: 0,
        isRegistered: false,
        isPhoneVerified: false,
        emergencyContactName: '',
        emergencyContactPhone: '',
        emergencyContactRelation: '',
        secondaryContactName: '',
        secondaryContactPhone: '',
        secondaryContactRelation: '',
        hasAbhaCard: false,
        abhaNumber: '',
        abhaAddress: '',
        criticalAllergies: [],
        chronicConditions: [],
        currentMedications: [],
      );
      profileNotifier.value = _profile;
    } catch (e) {
      debugPrint('[UserProfileService] Clear profile error: $e');
    }
  }
}
