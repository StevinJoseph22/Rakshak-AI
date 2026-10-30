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
  final String? caseNumber;
  final String? policeStationName;
  final String? policeOfficerName;
  final String? policeOfficerPhone;
  final bool? gridlockDetected;
  final String? reassignedFromAmbulanceId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const IncidentDetail({
    required this.id,
    required this.status,
    this.acceptedHospitalId,
    this.victimMetadata,
    required this.latitude,
    required this.longitude,
    this.caseNumber,
    this.policeStationName,
    this.policeOfficerName,
    this.policeOfficerPhone,
    this.gridlockDetected,
    this.reassignedFromAmbulanceId,
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
      caseNumber: json['case_number'] as String?,
      policeStationName: json['police_station_name'] as String?,
      policeOfficerName: json['police_officer_name'] as String?,
      policeOfficerPhone: json['police_officer_phone'] as String?,
      gridlockDetected: json['gridlock_detected'] as bool?,
      reassignedFromAmbulanceId: json['reassigned_from_ambulance_id'] as String?,
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
      'case_number': caseNumber,
      'police_station_name': policeStationName,
      'police_officer_name': policeOfficerName,
      'police_officer_phone': policeOfficerPhone,
      'gridlock_detected': gridlockDetected,
      'reassigned_from_ambulance_id': reassignedFromAmbulanceId,
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

/// Nearby incident model returned from GET /incidents/nearby (Ambulance Console).
class NearbyIncident {
  final String id;
  final String status;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final double? roadDistanceKm;
  final String? acceptedHospitalId;
  final MatchedHospital? acceptedHospital;
  final String? ambulanceId;
  final String? ambulancePlate;
  final String? driverName;
  final String? driverPhone;
  final String? originStation;
  final DateTime? arrivedAt;
  final double? arrivalLat;
  final double? arrivalLng;
  final String? imageUrl;
  final Map<String, dynamic>? victimMetadata;
  final DateTime? createdAt;

  const NearbyIncident({
    required this.id,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.roadDistanceKm,
    this.acceptedHospitalId,
    this.acceptedHospital,
    this.ambulanceId,
    this.ambulancePlate,
    this.driverName,
    this.driverPhone,
    this.originStation,
    this.arrivedAt,
    this.arrivalLat,
    this.arrivalLng,
    this.imageUrl,
    this.victimMetadata,
    this.createdAt,
  });

  factory NearbyIncident.fromJson(Map<String, dynamic> json) {
    return NearbyIncident(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? 'broadcasting',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      distanceKm: _parseDouble(json['distance_km']),
      roadDistanceKm: json['road_distance_km'] != null ? _parseDouble(json['road_distance_km']) : null,
      acceptedHospitalId: json['accepted_hospital_id'] as String?,
      acceptedHospital: json['accepted_hospital'] != null && json['accepted_hospital'] is Map<String, dynamic>
          ? MatchedHospital.fromJson(json['accepted_hospital'] as Map<String, dynamic>)
          : null,
      ambulanceId: json['ambulance_id'] as String?,
      ambulancePlate: json['ambulance_plate'] as String?,
      driverName: json['ambulance_driver_name'] as String?,
      driverPhone: json['ambulance_driver_phone'] as String?,
      originStation: json['ambulance_origin_station'] as String?,
      arrivedAt: json['ambulance_arrived_at'] != null
          ? DateTime.tryParse(json['ambulance_arrived_at'].toString())
          : null,
      arrivalLat: json['ambulance_arrival_lat'] != null
          ? _parseDouble(json['ambulance_arrival_lat'])
          : null,
      arrivalLng: json['ambulance_arrival_lng'] != null
          ? _parseDouble(json['ambulance_arrival_lng'])
          : null,
      imageUrl: json['imageUrl'] as String?,
      victimMetadata: json['victim_metadata'] is Map<String, dynamic>
          ? json['victim_metadata'] as Map<String, dynamic>
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

