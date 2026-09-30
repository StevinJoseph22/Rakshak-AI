// Privacy note: Emergency contact data is the victim's own chosen contact,
// stored locally on-device and only sent alongside an actual confirmed incident dispatch
// via victim_metadata. It is never stored in a standalone contacts table or cached
// in Redis alongside temporary photos.

class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relationship;
  final bool isPrimary;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    this.relationship = 'Family',
    this.isPrimary = false,
  });

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? relationship,
    bool? isPrimary,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'relationship': relationship,
      'is_primary': isPrimary,
    };
  }

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      relationship: json['relationship'] as String? ?? 'Family',
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
}
