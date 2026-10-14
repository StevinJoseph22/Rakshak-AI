/// Phase 18: Emergency Health Card Model
/// Implements strict per-field source provenance:
/// - Source: ABDM_VERIFIED | SELF_DECLARED | NONE
/// - Status: AVAILABLE | NOT_AVAILABLE
/// - Reason: when not available (e.g. not linked, consent not given, no records found, ABDM unreachable)

class HealthCardField<T> {
  final T? value;
  final String source; // 'ABDM_VERIFIED' | 'SELF_DECLARED' | 'NONE'
  final String status; // 'AVAILABLE' | 'NOT_AVAILABLE'
  final String? reason;

  const HealthCardField({
    required this.value,
    required this.source,
    required this.status,
    this.reason,
  });

  bool get isAvailable => status == 'AVAILABLE';
  bool get isAbdmVerified => source == 'ABDM_VERIFIED';
  bool get isVerified => source == 'ABDM_VERIFIED';
  bool get isSelfDeclared => source == 'SELF_DECLARED';

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'source': source,
      'status': status,
      if (reason != null) 'reason': reason,
    };
  }

  factory HealthCardField.fromJson(
    Map<String, dynamic>? json,
    T? Function(dynamic) parser,
  ) {
    if (json == null) {
      return HealthCardField<T>(
        value: null,
        source: 'NONE',
        status: 'NOT_AVAILABLE',
        reason: 'Not provided',
      );
    }
    return HealthCardField<T>(
      value: parser(json['value']),
      source: json['source'] as String? ?? 'NONE',
      status: json['status'] as String? ?? 'NOT_AVAILABLE',
      reason: json['reason'] as String?,
    );
  }
}

class EmergencyHealthCard {
  final HealthCardField<String> name;
  final HealthCardField<String> ageGender;
  final HealthCardField<String> abhaAddress;
  final HealthCardField<String> bloodGroup;
  final HealthCardField<List<String>> allergies;
  final HealthCardField<List<String>> chronicConditions;
  final HealthCardField<List<String>> currentMedications;
  final HealthCardField<String> organDonorStatus;
  final String lastUpdated;
  final String abdmMode; // 'SANDBOX' | 'MOCK'
  final bool isLinked;

  const EmergencyHealthCard({
    required this.name,
    required this.ageGender,
    required this.abhaAddress,
    required this.bloodGroup,
    required this.allergies,
    required this.chronicConditions,
    required this.currentMedications,
    required this.organDonorStatus,
    required this.lastUpdated,
    this.abdmMode = 'MOCK',
    this.isLinked = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name.toJson(),
      'age_gender': ageGender.toJson(),
      'abha_address': abhaAddress.toJson(),
      'blood_group': bloodGroup.toJson(),
      'allergies': allergies.toJson(),
      'chronic_conditions': chronicConditions.toJson(),
      'current_medications': currentMedications.toJson(),
      'organ_donor_status': organDonorStatus.toJson(),
      'last_updated': lastUpdated,
      'abdm_mode': abdmMode,
      'is_linked': isLinked,
    };
  }

  factory EmergencyHealthCard.fromJson(Map<String, dynamic> json) {
    return EmergencyHealthCard(
      name: HealthCardField<String>.fromJson(
        json['name'] as Map<String, dynamic>?,
        (v) => v as String?,
      ),
      ageGender: HealthCardField<String>.fromJson(
        json['age_gender'] as Map<String, dynamic>?,
        (v) => v as String?,
      ),
      abhaAddress: HealthCardField<String>.fromJson(
        json['abha_address'] as Map<String, dynamic>?,
        (v) => v as String?,
      ),
      bloodGroup: HealthCardField<String>.fromJson(
        json['blood_group'] as Map<String, dynamic>?,
        (v) => v as String?,
      ),
      allergies: HealthCardField<List<String>>.fromJson(
        json['allergies'] as Map<String, dynamic>?,
        (v) => (v as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[],
      ),
      chronicConditions: HealthCardField<List<String>>.fromJson(
        json['chronic_conditions'] as Map<String, dynamic>?,
        (v) => (v as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[],
      ),
      currentMedications: HealthCardField<List<String>>.fromJson(
        json['current_medications'] as Map<String, dynamic>?,
        (v) => (v as List<dynamic>?)?.map((e) => e.toString()).toList() ?? <String>[],
      ),
      organDonorStatus: HealthCardField<String>.fromJson(
        json['organ_donor_status'] as Map<String, dynamic>?,
        (v) => v as String?,
      ),
      lastUpdated: json['last_updated'] as String? ?? DateTime.now().toIso8601String(),
      abdmMode: json['abdm_mode'] as String? ?? 'MOCK',
      isLinked: json['is_linked'] as bool? ?? false,
    );
  }

  /// Default empty card when user has neither linked ABHA nor self-declared health data
  factory EmergencyHealthCard.empty() {
    return EmergencyHealthCard(
      name: const HealthCardField<String>(
        value: null,
        source: 'NONE',
        status: 'NOT_AVAILABLE',
        reason: 'Not provided',
      ),
      ageGender: const HealthCardField<String>(
        value: null,
        source: 'NONE',
        status: 'NOT_AVAILABLE',
        reason: 'Not provided',
      ),
      abhaAddress: const HealthCardField<String>(
        value: null,
        source: 'NONE',
        status: 'NOT_AVAILABLE',
        reason: 'ABHA not linked',
      ),
      bloodGroup: const HealthCardField<String>(
        value: null,
        source: 'NONE',
        status: 'NOT_AVAILABLE',
        reason: 'Not provided',
      ),
      allergies: const HealthCardField<List<String>>(
        value: <String>[],
        source: 'NONE',
        status: 'NOT_AVAILABLE',
        reason: 'Not provided',
      ),
      chronicConditions: const HealthCardField<List<String>>(
        value: <String>[],
        source: 'NONE',
        status: 'NOT_AVAILABLE',
        reason: 'Not provided',
      ),
      currentMedications: const HealthCardField<List<String>>(
        value: <String>[],
        source: 'NONE',
        status: 'NOT_AVAILABLE',
        reason: 'Not provided',
      ),
      organDonorStatus: const HealthCardField<String>(
        value: null,
        source: 'NONE',
        status: 'NOT_AVAILABLE',
        reason: 'Not provided',
      ),
      lastUpdated: DateTime.now().toIso8601String(),
      isLinked: false,
    );
  }

  /// Helper to mask an ABHA address (e.g. "aarav.sharma@abdm" -> "aa***@abdm")
  static String? maskAbhaAddress(String? address) {
    if (address == null) return null;
    if (!address.contains('@')) return address;
    final parts = address.split('@');
    final handle = parts[0];
    final domain = parts[1];
    if (handle.length <= 2) {
      return '$handle***@$domain';
    }
    return '${handle.substring(0, 2)}***@$domain';
  }
}
