import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_health_card_model.dart';
import 'abdm_mobile_service.dart';

class HealthCardStorageService {
  HealthCardStorageService._();
  static final HealthCardStorageService instance = HealthCardStorageService._();

  static const _kIsLinked = 'rakshak_abha_is_linked';
  static const _kAbhaAddress = 'rakshak_abha_address';
  static const _kAbhaNumber = 'rakshak_abha_number';
  static const _kAbhaName = 'rakshak_abha_name';
  static const _kAbhaGender = 'rakshak_abha_gender';
  static const _kAbhaAge = 'rakshak_abha_age';
  static const _kAbhaSessionToken = 'rakshak_abha_session_token';
  static const _kAbdmMode = 'rakshak_abdm_mode';

  static const _kAbdmRecordsAvailable = 'rakshak_abdm_records_available';
  static const _kAbdmRecordsReason = 'rakshak_abdm_records_reason';
  static const _kAbdmBloodGroup = 'rakshak_abdm_blood_group';
  static const _kAbdmAllergies = 'rakshak_abdm_allergies';
  static const _kAbdmConditions = 'rakshak_abdm_conditions';
  static const _kAbdmMedications = 'rakshak_abdm_medications';
  static const _kAbdmOrganDonor = 'rakshak_abdm_organ_donor';

  static const _kSelfBloodGroup = 'rakshak_self_blood_group';
  static const _kSelfAllergies = 'rakshak_self_allergies';
  static const _kSelfConditions = 'rakshak_self_conditions';
  static const _kSelfMedications = 'rakshak_self_medications';
  static const _kSelfOrganDonor = 'rakshak_self_organ_donor';
  static const _kSelfName = 'rakshak_self_name';
  static const _kSelfHasData = 'rakshak_self_has_data';

  /// Saves verified ABDM profile and associated consent-based health records
  Future<void> saveAbdmVerifiedData({
    required Map<String, dynamic> profile,
    Map<String, dynamic>? records,
    String? sessionToken,
    String mode = 'MOCK',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsLinked, true);
    await prefs.setString(_kAbhaAddress, profile['abhaAddress']?.toString() ?? '');
    await prefs.setString(_kAbhaNumber, profile['abhaNumber']?.toString() ?? '');
    await prefs.setString(_kAbhaName, profile['name']?.toString() ?? 'ABDM Verified Citizen');
    await prefs.setString(_kAbhaGender, profile['gender']?.toString() ?? 'Unspecified');
    if (profile['age'] != null) {
      await prefs.setInt(_kAbhaAge, int.tryParse(profile['age'].toString()) ?? 0);
    }
    if (sessionToken != null) {
      await prefs.setString(_kAbhaSessionToken, sessionToken);
    }
    await prefs.setString(_kAbdmMode, mode);

    final bool recordsAvailable = records != null && records['status'] == 'AVAILABLE';
    await prefs.setBool(_kAbdmRecordsAvailable, recordsAvailable);
    if (!recordsAvailable && records?['reason'] != null) {
      await prefs.setString(_kAbdmRecordsReason, records!['reason'].toString());
    } else {
      await prefs.remove(_kAbdmRecordsReason);
    }

    if (recordsAvailable) {
      if (records['blood_group'] != null) {
        await prefs.setString(_kAbdmBloodGroup, records['blood_group'].toString());
      }
      if (records['allergies'] is List) {
        final list = (records['allergies'] as List).map((e) => e.toString()).toList();
        await prefs.setString(_kAbdmAllergies, jsonEncode(list));
      }
      if (records['chronic_conditions'] is List) {
        final list = (records['chronic_conditions'] as List).map((e) => e.toString()).toList();
        await prefs.setString(_kAbdmConditions, jsonEncode(list));
      }
      if (records['current_medications'] is List) {
        final list = (records['current_medications'] as List).map((e) => e.toString()).toList();
        await prefs.setString(_kAbdmMedications, jsonEncode(list));
      }
      if (records['organ_donor_status'] != null) {
        await prefs.setString(_kAbdmOrganDonor, records['organ_donor_status'].toString());
      }
    }
  }

  /// Saves self-declared emergency medical info entered by user
  Future<void> saveSelfDeclaredData({
    String? name,
    String? bloodGroup,
    List<String>? allergies,
    List<String>? conditions,
    List<String>? medications,
    String? organDonor,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSelfHasData, true);
    if (name != null) await prefs.setString(_kSelfName, name.trim());
    if (bloodGroup != null) await prefs.setString(_kSelfBloodGroup, bloodGroup.trim());
    if (allergies != null) await prefs.setString(_kSelfAllergies, jsonEncode(allergies));
    if (conditions != null) await prefs.setString(_kSelfConditions, jsonEncode(conditions));
    if (medications != null) await prefs.setString(_kSelfMedications, jsonEncode(medications));
    if (organDonor != null) await prefs.setString(_kSelfOrganDonor, organDonor.trim());
  }

  /// Builds the consolidated Emergency Health Card according to strict provenance rules
  Future<EmergencyHealthCard> getHealthCard() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isLinked = prefs.getBool(_kIsLinked) ?? false;
    final String mode = prefs.getString(_kAbdmMode) ?? 'MOCK';

    // 1. Identity Fields
    HealthCardField<String> nameField;
    HealthCardField<String> ageGenderField;
    HealthCardField<String> abhaAddressField;

    if (isLinked) {
      final name = prefs.getString(_kAbhaName);
      final gender = prefs.getString(_kAbhaGender) ?? 'Unspecified';
      final age = prefs.getInt(_kAbhaAge);
      final address = prefs.getString(_kAbhaAddress) ?? '';

      nameField = HealthCardField<String>(
        value: name,
        source: 'ABDM_VERIFIED',
        status: name != null && name.isNotEmpty ? 'AVAILABLE' : 'NOT_AVAILABLE',
        reason: name == null ? 'No name in ABDM profile' : null,
      );

      final ageGenderStr = age != null && age > 0 ? '$age Y / $gender' : gender;
      ageGenderField = HealthCardField<String>(
        value: ageGenderStr,
        source: 'ABDM_VERIFIED',
        status: 'AVAILABLE',
      );

      abhaAddressField = HealthCardField<String>(
        value: EmergencyHealthCard.maskAbhaAddress(address),
        source: 'ABDM_VERIFIED',
        status: address.isNotEmpty ? 'AVAILABLE' : 'NOT_AVAILABLE',
      );
    } else {
      final selfName = prefs.getString(_kSelfName);
      nameField = HealthCardField<String>(
        value: selfName,
        source: selfName != null && selfName.isNotEmpty ? 'SELF_DECLARED' : 'NONE',
        status: selfName != null && selfName.isNotEmpty ? 'AVAILABLE' : 'NOT_AVAILABLE',
        reason: selfName == null ? 'Not linked or declared' : null,
      );

      ageGenderField = const HealthCardField<String>(
        value: null,
        source: 'NONE',
        status: 'NOT_AVAILABLE',
        reason: 'Not provided',
      );

      abhaAddressField = const HealthCardField<String>(
        value: null,
        source: 'NONE',
        status: 'NOT_AVAILABLE',
        reason: 'ABHA not linked',
      );
    }

    // 2. Medical Fields
    final bool abdmRecordsAvailable = prefs.getBool(_kAbdmRecordsAvailable) ?? false;
    final String? abdmReason = prefs.getString(_kAbdmRecordsReason);

    // Blood Group
    HealthCardField<String> bloodField;
    final String? abdmBlood = prefs.getString(_kAbdmBloodGroup);
    final String? selfBlood = prefs.getString(_kSelfBloodGroup);

    if (isLinked && abdmRecordsAvailable && abdmBlood != null && abdmBlood.isNotEmpty) {
      bloodField = HealthCardField<String>(
        value: abdmBlood,
        source: 'ABDM_VERIFIED',
        status: 'AVAILABLE',
      );
    } else if (selfBlood != null && selfBlood.isNotEmpty) {
      bloodField = HealthCardField<String>(
        value: selfBlood,
        source: 'SELF_DECLARED',
        status: 'AVAILABLE',
      );
    } else {
      bloodField = HealthCardField<String>(
        value: null,
        source: 'NONE',
        status: 'NOT_AVAILABLE',
        reason: isLinked
            ? (abdmReason ?? 'No records found in ABDM repository')
            : 'ABHA not linked and no emergency health data entered',
      );
    }

    // Allergies
    HealthCardField<List<String>> allergiesField;
    final String? abdmAllergiesJson = prefs.getString(_kAbdmAllergies);
    final String? selfAllergiesJson = prefs.getString(_kSelfAllergies);

    if (isLinked && abdmRecordsAvailable && abdmAllergiesJson != null) {
      final list = (jsonDecode(abdmAllergiesJson) as List).map((e) => e.toString()).toList();
      allergiesField = HealthCardField<List<String>>(
        value: list,
        source: 'ABDM_VERIFIED',
        status: 'AVAILABLE',
      );
    } else if (selfAllergiesJson != null) {
      final list = (jsonDecode(selfAllergiesJson) as List).map((e) => e.toString()).toList();
      allergiesField = HealthCardField<List<String>>(
        value: list,
        source: 'SELF_DECLARED',
        status: 'AVAILABLE',
      );
    } else {
      allergiesField = HealthCardField<List<String>>(
        value: const [],
        source: 'NONE',
        status: 'NOT_AVAILABLE',
        reason: isLinked
            ? (abdmReason ?? 'No records found in ABDM repository')
            : 'Not provided',
      );
    }

    // Chronic Conditions
    HealthCardField<List<String>> conditionsField;
    final String? abdmConditionsJson = prefs.getString(_kAbdmConditions);
    final String? selfConditionsJson = prefs.getString(_kSelfConditions);

    if (isLinked && abdmRecordsAvailable && abdmConditionsJson != null) {
      final list = (jsonDecode(abdmConditionsJson) as List).map((e) => e.toString()).toList();
      conditionsField = HealthCardField<List<String>>(
        value: list,
        source: 'ABDM_VERIFIED',
        status: 'AVAILABLE',
      );
    } else if (selfConditionsJson != null) {
      final list = (jsonDecode(selfConditionsJson) as List).map((e) => e.toString()).toList();
      conditionsField = HealthCardField<List<String>>(
        value: list,
        source: 'SELF_DECLARED',
        status: 'AVAILABLE',
      );
    } else {
      conditionsField = HealthCardField<List<String>>(
        value: const [],
        source: 'NONE',
        status: 'NOT_AVAILABLE',
        reason: isLinked
            ? (abdmReason ?? 'No records found in ABDM repository')
            : 'Not provided',
      );
    }

    // Current Medications
    HealthCardField<List<String>> medicationsField;
    final String? abdmMedsJson = prefs.getString(_kAbdmMedications);
    final String? selfMedsJson = prefs.getString(_kSelfMedications);

    if (isLinked && abdmRecordsAvailable && abdmMedsJson != null) {
      final list = (jsonDecode(abdmMedsJson) as List).map((e) => e.toString()).toList();
      medicationsField = HealthCardField<List<String>>(
        value: list,
        source: 'ABDM_VERIFIED',
        status: 'AVAILABLE',
      );
    } else if (selfMedsJson != null) {
      final list = (jsonDecode(selfMedsJson) as List).map((e) => e.toString()).toList();
      medicationsField = HealthCardField<List<String>>(
        value: list,
        source: 'SELF_DECLARED',
        status: 'AVAILABLE',
      );
    } else {
      medicationsField = HealthCardField<List<String>>(
        value: const [],
        source: 'NONE',
        status: 'NOT_AVAILABLE',
        reason: isLinked
            ? (abdmReason ?? 'No records found in ABDM repository')
            : 'Not provided',
      );
    }

    // Organ Donor Status
    HealthCardField<String> donorField;
    final String? abdmDonor = prefs.getString(_kAbdmOrganDonor);
    final String? selfDonor = prefs.getString(_kSelfOrganDonor);

    if (isLinked && abdmRecordsAvailable && abdmDonor != null && abdmDonor.isNotEmpty) {
      donorField = HealthCardField<String>(
        value: abdmDonor,
        source: 'ABDM_VERIFIED',
        status: 'AVAILABLE',
      );
    } else if (selfDonor != null && selfDonor.isNotEmpty) {
      donorField = HealthCardField<String>(
        value: selfDonor,
        source: 'SELF_DECLARED',
        status: 'AVAILABLE',
      );
    } else {
      donorField = HealthCardField<String>(
        value: null,
        source: 'NONE',
        status: 'NOT_AVAILABLE',
        reason: 'Not provided',
      );
    }

    return EmergencyHealthCard(
      name: nameField,
      ageGender: ageGenderField,
      abhaAddress: abhaAddressField,
      bloodGroup: bloodField,
      allergies: allergiesField,
      chronicConditions: conditionsField,
      currentMedications: medicationsField,
      organDonorStatus: donorField,
      lastUpdated: DateTime.now().toIso8601String(),
      abdmMode: mode,
      isLinked: isLinked,
    );
  }

  /// One-tap Unlink & Wipe that deletes both server session and local preferences
  Future<void> unlinkAndDelete() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionToken = prefs.getString(_kAbhaSessionToken);

    // 1. Notify backend proxy to purge session
    await AbdmMobileService.instance.unlinkAbha(sessionToken);

    // 2. Wipe all local ABHA and health preferences
    await prefs.remove(_kIsLinked);
    await prefs.remove(_kAbhaAddress);
    await prefs.remove(_kAbhaNumber);
    await prefs.remove(_kAbhaName);
    await prefs.remove(_kAbhaGender);
    await prefs.remove(_kAbhaAge);
    await prefs.remove(_kAbhaSessionToken);
    await prefs.remove(_kAbdmMode);
    await prefs.remove(_kAbdmRecordsAvailable);
    await prefs.remove(_kAbdmRecordsReason);
    await prefs.remove(_kAbdmBloodGroup);
    await prefs.remove(_kAbdmAllergies);
    await prefs.remove(_kAbdmConditions);
    await prefs.remove(_kAbdmMedications);
    await prefs.remove(_kAbdmOrganDonor);
    await prefs.remove(_kSelfBloodGroup);
    await prefs.remove(_kSelfAllergies);
    await prefs.remove(_kSelfConditions);
    await prefs.remove(_kSelfMedications);
    await prefs.remove(_kSelfOrganDonor);
    await prefs.remove(_kSelfName);
    await prefs.remove(_kSelfHasData);
  }

  /// Checks if ABHA is currently linked
  Future<bool> isAbhaLinked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIsLinked) ?? false;
  }
}
