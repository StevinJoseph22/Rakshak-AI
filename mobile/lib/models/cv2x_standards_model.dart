import 'package:latlong2/latlong.dart';

/// SAE J2735 Standard Vehicle Role
enum VehicleRole {
  emergencyAmbulance,
  policeEscort,
  fireApparatus,
  transitBus,
}

/// SAE J2735 Signal Request Priority Level
enum PriorityLevel {
  criticalTraumaLevel1, // Preempts all other traffic and lower priority vehicles
  urgentEmergencyLevel2,
  routineTransferLevel3,
}

/// Signal Preemption State Machine
enum SignalPreemptionState {
  normalCycle,        // Red/Green according to default city timer
  yellowClearance,    // 3-4s yellow phase stopping cross traffic
  allRedSafetyBuffer, // 1-2s all-red clearing cars stuck in intersection
  preemptedGreen,     // Locked green wave for the emergency vehicle
  departedHandback,   // Vehicle crossed; returning to normal cycle
}

/// SAE J2735 Basic Safety Message (BSM)
/// Standardized telemetry broadcast by in-vehicle On-Board Units (OBU)
class BasicSafetyMessage {
  final String vehicleId;
  final String plateNumber;
  final LatLng position;
  final double speedKmh;
  final double headingDegrees;
  final double elevationMeters;
  final bool sirenActive;
  final bool emergencyLightsActive;
  final DateTime timestamp;

  BasicSafetyMessage({
    required this.vehicleId,
    required this.plateNumber,
    required this.position,
    required this.speedKmh,
    required this.headingDegrees,
    this.elevationMeters = 920.0,
    required this.sirenActive,
    required this.emergencyLightsActive,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'msg_type': 'BSM_SAE_J2735',
        'vehicle_id': vehicleId,
        'plate_number': plateNumber,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed_kmh': speedKmh,
        'heading': headingDegrees,
        'elevation_m': elevationMeters,
        'siren_active': sirenActive,
        'lights_active': emergencyLightsActive,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// SAE J2735 Signal Request Message (SRM)
/// Broadcast by the ambulance to Roadside Units (RSU) to request signal preemption
class SignalRequestMessage {
  final String requestId;
  final String vehicleId;
  final String intersectionId;
  final String junctionName;
  final PriorityLevel priority;
  final int etaSeconds;
  final double distanceMeters;
  final String inboundApproachDirection; // N, S, E, W, NE, NW, etc.
  final DateTime requestedAt;

  SignalRequestMessage({
    required this.requestId,
    required this.vehicleId,
    required this.intersectionId,
    required this.junctionName,
    required this.priority,
    required this.etaSeconds,
    required this.distanceMeters,
    required this.inboundApproachDirection,
    required this.requestedAt,
  });

  Map<String, dynamic> toJson() => {
        'msg_type': 'SRM_SAE_J2735',
        'request_id': requestId,
        'vehicle_id': vehicleId,
        'intersection_id': intersectionId,
        'junction_name': junctionName,
        'priority': priority.name,
        'eta_seconds': etaSeconds,
        'distance_m': distanceMeters,
        'approach_dir': inboundApproachDirection,
        'requested_at': requestedAt.toIso8601String(),
      };
}

/// SAE J2735 Signal Status Message (SSM)
/// Broadcast back by the Roadside Unit (RSU) / Traffic Controller confirming preemption
class SignalStatusMessage {
  final String intersectionId;
  final String junctionName;
  final String requestId;
  final SignalPreemptionState state;
  final int activeGreenHoldSeconds;
  final bool queueClearanceActive;
  final String controllerModel; // e.g. "ATC-NEMA-TS2-ITMS"
  final DateTime confirmedAt;

  SignalStatusMessage({
    required this.intersectionId,
    required this.junctionName,
    required this.requestId,
    required this.state,
    required this.activeGreenHoldSeconds,
    this.queueClearanceActive = true,
    this.controllerModel = 'ATC-NEMA-TS2 / ITMS',
    required this.confirmedAt,
  });

  Map<String, dynamic> toJson() => {
        'msg_type': 'SSM_SAE_J2735',
        'intersection_id': intersectionId,
        'junction_name': junctionName,
        'request_id': requestId,
        'state': state.name,
        'green_hold_s': activeGreenHoldSeconds,
        'queue_clearance': queueClearanceActive,
        'controller_model': controllerModel,
        'confirmed_at': confirmedAt.toIso8601String(),
      };
}

/// Real-world traffic signal node representation
class RealTrafficSignalNode {
  final String id;
  final String name;
  final LatLng location;
  final String controllerId;
  final int defaultCycleSeconds;
  SignalPreemptionState preemptionState;
  int preemptionTimerSeconds;
  double distanceMeters;
  bool isPreempted;
  final String source; // 'OpenStreetMap Overpass' | 'Municipal ITMS Registry'

  RealTrafficSignalNode({
    required this.id,
    required this.name,
    required this.location,
    required this.controllerId,
    this.defaultCycleSeconds = 90,
    this.preemptionState = SignalPreemptionState.normalCycle,
    this.preemptionTimerSeconds = 0,
    this.distanceMeters = 9999.0,
    this.isPreempted = false,
    this.source = 'Municipal ITMS Registry',
  });
}
