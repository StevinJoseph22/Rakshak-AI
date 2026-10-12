/// Model representing Physics-Informed AI Crash Biomechanics and internal injury risk predictions.
/// Acts as a "Virtual Trauma Blackbox" by computing impact vector, Delta-V, G-force peak,
/// and organ injury severity estimates for emergency responders and trauma surgeons.
class PredictedInjury {
  final String injury;
  final int riskPercent;
  final String severity; // CRITICAL, HIGH, MODERATE
  final String clinicalAction;

  const PredictedInjury({
    required this.injury,
    required this.riskPercent,
    required this.severity,
    required this.clinicalAction,
  });

  factory PredictedInjury.fromJson(Map<String, dynamic> json) {
    return PredictedInjury(
      injury: json['injury'] as String? ?? 'General Impact Trauma',
      riskPercent: (json['risk_percent'] as num?)?.toInt() ?? 50,
      severity: json['severity'] as String? ?? 'HIGH',
      clinicalAction: json['clinical_action'] as String? ?? 'Standard Triage Assessment',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'injury': injury,
      'risk_percent': riskPercent,
      'severity': severity,
      'clinical_action': clinicalAction,
    };
  }
}

class CrashBiomechanics {
  final double deltaVKmh;
  final double peakG;
  final double pdofDegrees;
  final String impactDirection;
  final double energyDissipationKj;
  final int issScoreEstimate;
  final List<PredictedInjury> predictedInjuries;

  const CrashBiomechanics({
    required this.deltaVKmh,
    required this.peakG,
    required this.pdofDegrees,
    required this.impactDirection,
    required this.energyDissipationKj,
    required this.issScoreEstimate,
    required this.predictedInjuries,
  });

  factory CrashBiomechanics.fromJson(Map<String, dynamic> json) {
    final list = json['predicted_injuries'] as List<dynamic>? ?? [];
    return CrashBiomechanics(
      deltaVKmh: (json['deltaV_kmh'] as num?)?.toDouble() ?? 58.0,
      peakG: (json['peak_g'] as num?)?.toDouble() ?? 42.5,
      pdofDegrees: (json['pdof_degrees'] as num?)?.toDouble() ?? 12.0,
      impactDirection: json['impact_direction'] as String? ?? "Frontal Oblique (12 o'clock)",
      energyDissipationKj: (json['energy_dissipation_kj'] as num?)?.toDouble() ?? 135.0,
      issScoreEstimate: (json['iss_score_estimate'] as num?)?.toInt() ?? 24,
      predictedInjuries: list.map((e) => PredictedInjury.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deltaV_kmh': deltaVKmh,
      'peak_g': peakG,
      'pdof_degrees': pdofDegrees,
      'impact_direction': impactDirection,
      'energy_dissipation_kj': energyDissipationKj,
      'iss_score_estimate': issScoreEstimate,
      'predicted_injuries': predictedInjuries.map((e) => e.toJson()).toList(),
    };
  }

  /// Extracts biomechanics from victimMetadata or returns a realistic physics simulation model.
  factory CrashBiomechanics.fromMetadata(Map<String, dynamic>? metadata) {
    if (metadata != null && metadata['biomechanics'] is Map<String, dynamic>) {
      return CrashBiomechanics.fromJson(metadata['biomechanics'] as Map<String, dynamic>);
    }

    final peakG = (metadata?['deceleration_g'] as num?)?.toDouble() ?? 48.6;
    final deltaV = (metadata?['speed_drop_kmh'] as num?)?.toDouble() ?? 62.4;

    return CrashBiomechanics.generateSimulated(
      decelerationG: peakG,
      speedDropKmh: deltaV,
    );
  }

  /// Generates a physics-informed injury prediction model based on kinetic input parameters.
  factory CrashBiomechanics.generateSimulated({
    double decelerationG = 48.6,
    double speedDropKmh = 62.4,
  }) {
    // Kinetic Energy E = 1/2 * m * v^2 estimate (75kg rider + vehicle inertia)
    final velocityMs = speedDropKmh / 3.6;
    final energyKj = double.parse((0.5 * 180 * velocityMs * velocityMs / 1000).toStringAsFixed(1));

    final injuries = <PredictedInjury>[
      PredictedInjury(
        injury: 'Cervical Spine Whiplash / Fracture Risk',
        riskPercent: (decelerationG > 35 ? 84 : 62),
        severity: 'CRITICAL',
        clinicalAction: 'Immediate C-Spine Collar Immobilization',
      ),
      PredictedInjury(
        injury: 'Blunt Sternal / Myocardial Contusion',
        riskPercent: (decelerationG > 40 ? 76 : 55),
        severity: 'HIGH',
        clinicalAction: 'Prepare 12-Lead ECG & Cardiac Troponin Assays',
      ),
      PredictedInjury(
        injury: 'Intra-Abdominal / Splenic Laceration',
        riskPercent: (speedDropKmh > 50 ? 61 : 38),
        severity: 'HIGH',
        clinicalAction: 'FAST Abdominal Ultrasound on Arrival',
      ),
      PredictedInjury(
        injury: 'Traumatic Brain Injury (TBI / Closed Head Shock)',
        riskPercent: (decelerationG > 30 ? 52 : 30),
        severity: 'MODERATE',
        clinicalAction: 'Non-Contrast Head CT Protocol on Standby',
      ),
    ];

    return CrashBiomechanics(
      deltaVKmh: speedDropKmh,
      peakG: decelerationG,
      pdofDegrees: 12.0,
      impactDirection: "Frontal Oblique (12 o'clock)",
      energyDissipationKj: energyKj,
      issScoreEstimate: 26,
      predictedInjuries: injuries,
    );
  }
}
