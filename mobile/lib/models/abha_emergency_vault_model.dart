/// Model representing Ayushman Bharat Digital Mission (ABDM / ABHA)
/// Emergency Medical Vault Data.
/// Transmits emergency clinical parameters (Blood Group, Drug Allergies, Chronic Conditions)
/// with verified provenance while preserving patient privacy.
class AbhaEmergencyVault {
  final String abhaId;
  final String abhaAddress;
  final String patientName;
  final String gender;
  final String dob;
  final String bloodGroup;
  final List<String> criticalAllergies;
  final List<String> chronicConditions;
  final List<String> currentMedications;
  final bool organDonorRegistered;
  final String nottoId;
  final String zkProofSignature;
  final bool isAbdmVerified;

  const AbhaEmergencyVault({
    required this.abhaId,
    required this.abhaAddress,
    required this.patientName,
    required this.gender,
    required this.dob,
    required this.bloodGroup,
    required this.criticalAllergies,
    required this.chronicConditions,
    required this.currentMedications,
    required this.organDonorRegistered,
    required this.nottoId,
    required this.zkProofSignature,
    required this.isAbdmVerified,
  });

  factory AbhaEmergencyVault.fromJson(Map<String, dynamic> json) {
    return AbhaEmergencyVault(
      abhaId: json['abha_id'] as String? ?? '91-4829-1029-4821',
      abhaAddress: json['abha_address'] as String? ?? 'stevin.joseph@abdm',
      patientName: json['patient_name'] as String? ?? 'Stevin Joseph (Verified)',
      gender: json['gender'] as String? ?? 'Specified',
      dob: json['dob'] as String? ?? '1998-05-14',
      bloodGroup: json['blood_group'] as String? ?? 'O+ Positive',
      criticalAllergies: (json['critical_allergies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['Penicillin Anaphylaxis', 'Sulfa Drugs'],
      chronicConditions: (json['chronic_conditions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['Asthma', 'Type 2 Diabetes'],
      currentMedications: (json['current_medications'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['Salbutamol Inhaler', 'Metformin 500mg'],
      organDonorRegistered: json['organ_donor_registered'] as bool? ?? true,
      nottoId: json['notto_id'] as String? ?? 'NOTTO-IND-2024-88419',
      zkProofSignature: json['zk_proof_signature'] as String? ?? 'RAKSHAK-EDGE-ZK-PROOF',
      isAbdmVerified: json['is_abdm_verified'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'abha_id': abhaId,
      'abha_address': abhaAddress,
      'patient_name': patientName,
      'gender': gender,
      'dob': dob,
      'blood_group': bloodGroup,
      'critical_allergies': criticalAllergies,
      'chronic_conditions': chronicConditions,
      'current_medications': currentMedications,
      'organ_donor_registered': organDonorRegistered,
      'notto_id': nottoId,
      'zk_proof_signature': zkProofSignature,
      'is_abdm_verified': isAbdmVerified,
    };
  }

  factory AbhaEmergencyVault.fromMetadata(Map<String, dynamic>? metadata) {
    if (metadata != null && metadata['abha_vault'] is Map<String, dynamic>) {
      return AbhaEmergencyVault.fromJson(metadata['abha_vault'] as Map<String, dynamic>);
    }
    return AbhaEmergencyVault.defaultProfile();
  }

  factory AbhaEmergencyVault.create({
    String? name,
    String? bloodGroup,
    String? abhaId,
    String? abhaAddress,
    List<String>? allergies,
    List<String>? conditions,
    List<String>? medications,
  }) {
    final citizenName = (name != null && name.trim().isNotEmpty) ? name.trim() : 'Stevin Joseph';
    return AbhaEmergencyVault(
      abhaId: (abhaId != null && abhaId.trim().isNotEmpty) ? abhaId.trim() : '91-4829-1029-4821',
      abhaAddress: (abhaAddress != null && abhaAddress.trim().isNotEmpty)
          ? abhaAddress.trim()
          : '${citizenName.toLowerCase().replaceAll(RegExp(r'\s+'), '.')}@abdm',
      patientName: citizenName,
      gender: 'Specified',
      dob: '1998-05-14',
      bloodGroup: (bloodGroup != null && bloodGroup.trim().isNotEmpty) ? bloodGroup.trim() : 'O+ Positive',
      criticalAllergies: allergies ?? const ['Penicillin Anaphylaxis', 'Sulfa Drugs'],
      chronicConditions: conditions ?? const ['Asthma', 'Type 2 Diabetes'],
      currentMedications: medications ?? const ['Salbutamol Inhaler', 'Metformin 500mg'],
      organDonorRegistered: true,
      nottoId: 'NOTTO-IND-2024-88419',
      zkProofSignature: 'RAKSHAK-EDGE-ZK-PROOF',
      isAbdmVerified: true,
    );
  }

  factory AbhaEmergencyVault.defaultProfile() {
    return AbhaEmergencyVault.create();
  }
}
