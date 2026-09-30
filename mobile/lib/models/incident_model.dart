double _parseDouble(dynamic val, [double defaultValue = 0.0]) {
  if (val == null) return defaultValue;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? defaultValue;
  return defaultValue;
}

int _parseInt(dynamic val, [int defaultValue = 0]) {
  if (val == null) return defaultValue;
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val) ?? defaultValue;
  return defaultValue;
}

/// Matched trauma center / hospital model.
class MatchedHospital {
  final String id;
  final String name;
  final String phone;
  final String address;
  final bool hasTraumaCenter;
  final bool hasIcuCapacity;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final double distanceKm;

  const MatchedHospital({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.hasTraumaCenter,
    required this.hasIcuCapacity,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.distanceKm,
  });

  factory MatchedHospital.fromJson(Map<String, dynamic> json) {
    return MatchedHospital(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Hospital',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
      hasTraumaCenter: json['has_trauma_center'] as bool? ?? false,
      hasIcuCapacity: json['has_icu_capacity'] as bool? ?? false,
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      distanceMeters: _parseDouble(json['distance_meters']),
      distanceKm: _parseDouble(json['distance_km']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'has_trauma_center': hasTraumaCenter,
      'has_icu_capacity': hasIcuCapacity,
      'latitude': latitude,
      'longitude': longitude,
      'distance_meters': distanceMeters,
      'distance_km': distanceKm,
    };
  }
}

/// Incident details model returned from Phase 1 backend.
class IncidentDetail {
  final String id;
  final String status;
  final String? acceptedHospitalId;
  final Map<String, dynamic>? victimMetadata;
  final double latitude;
  final double longitude;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const IncidentDetail({
    required this.id,
    required this.status,
    this.acceptedHospitalId,
    this.victimMetadata,
    required this.latitude,
    required this.longitude,
    this.createdAt,
    this.updatedAt,
  });

  factory IncidentDetail.fromJson(Map<String, dynamic> json) {
    return IncidentDetail(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'detected',
      acceptedHospitalId: json['accepted_hospital_id'] as String?,
      victimMetadata: json['victim_metadata'] is Map<String, dynamic>
          ? json['victim_metadata'] as Map<String, dynamic>
          : null,
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'accepted_hospital_id': acceptedHospitalId,
      'victim_metadata': victimMetadata,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// Complete response model from POST /incidents.
class IncidentResponse {
  final String message;
  final IncidentDetail incident;
  final double searchRadiusKm;
  final int matchedHospitalsCount;
  final List<MatchedHospital> matchedHospitals;

  const IncidentResponse({
    required this.message,
    required this.incident,
    required this.searchRadiusKm,
    required this.matchedHospitalsCount,
    required this.matchedHospitals,
  });

  factory IncidentResponse.fromJson(Map<String, dynamic> json) {
    final hospitalsList = json['matched_hospitals'] as List<dynamic>? ?? [];
    return IncidentResponse(
      message: json['message'] as String? ?? '',
      incident: json['incident'] != null
          ? IncidentDetail.fromJson(json['incident'] as Map<String, dynamic>)
          : const IncidentDetail(id: '', status: 'unknown', latitude: 0, longitude: 0),
      searchRadiusKm: _parseDouble(json['search_radius_km'], 8.0),
      matchedHospitalsCount: _parseInt(json['matched_hospitals_count'], hospitalsList.length),
      matchedHospitals: hospitalsList
          .map((e) => MatchedHospital.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'incident': incident.toJson(),
      'search_radius_km': searchRadiusKm,
      'matched_hospitals_count': matchedHospitalsCount,
      'matched_hospitals': matchedHospitals.map((e) => e.toJson()).toList(),
    };
  }
}
