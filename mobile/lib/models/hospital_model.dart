import 'dart:math';

/// Authentic hospital & emergency trauma bay facility model
class HospitalFacility {
  final String id;
  final String name;
  final String phone;
  final String address;
  final double latitude;
  final double longitude;
  final bool hasTraumaCenter;
  final bool hasIcuCapacity;
  final String traumaTier;
  final int icuBedsAvailable;
  final String bloodBankStatus;
  final bool isCtMriActive;
  double? distanceKm;

  HospitalFacility({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.hasTraumaCenter = true,
    this.hasIcuCapacity = true,
    this.traumaTier = 'Level-1 Apex Trauma Center',
    this.icuBedsAvailable = 4,
    this.bloodBankStatus = 'Universal O-Negative In-Stock',
    this.isCtMriActive = true,
    this.distanceKm,
  });

  int get estimatedDriveMinutes => distanceKm != null ? (distanceKm! * 1.8).round().clamp(1, 180) : 5;

  /// Calculates Haversine distance from given coordinates in Kilometers
  double computeDistanceTo(double fromLat, double fromLng) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((latitude - fromLat) * p) / 2 +
        cos(fromLat * p) * cos(latitude * p) * (1 - cos((longitude - fromLng) * p)) / 2;
    final d = 12742 * asin(sqrt(a)); // 2 * R * asin...
    distanceKm = double.parse(d.toStringAsFixed(1));
    return distanceKm!;
  }

  factory HospitalFacility.fromJson(Map<String, dynamic> json) {
    return HospitalFacility(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Emergency Facility',
      phone: json['phone'] as String? ?? '+91 80 2502 4444',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 12.9716,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 77.5946,
      hasTraumaCenter: json['has_trauma_center'] as bool? ?? true,
      hasIcuCapacity: json['has_icu_capacity'] as bool? ?? true,
      traumaTier: json['trauma_tier'] as String? ?? 'Level-1 Apex Trauma Center',
      icuBedsAvailable: (json['icu_beds_available'] as num?)?.toInt() ?? 4,
      bloodBankStatus: json['blood_bank_status'] as String? ?? 'Universal O-Negative In-Stock',
      isCtMriActive: json['is_ct_mri_active'] as bool? ?? true,
    );
  }
}
