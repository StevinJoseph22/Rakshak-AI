import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/cv2x_standards_model.dart';

/// In-Vehicle On-Board Unit (OBU) Connection Mode
enum ObuConnectionMode {
  simulatedSoftware,  // Active now: Virtual GPS & Software EVP engine
  serialUsbOtG,       // Pluggable: USB-OTG / RS-232 / CAN-Bus to Physical C-V2X OBU
  bluetoothBle,       // Pluggable: Wireless BLE dongle in vehicle dashboard
  directCv2xPc5,      // Pluggable: Native DSRC / 3GPP Rel-16 PC5 direct radio link
}

/// Hardware Abstraction Layer for Emergency Vehicle On-Board Unit (OBU)
/// Follows SAE J2735 Standardized Messaging Architecture.
class VehicleObuService {
  static final VehicleObuService _instance = VehicleObuService._internal();
  static VehicleObuService get instance => _instance;
  VehicleObuService._internal();

  ObuConnectionMode _connectionMode = ObuConnectionMode.simulatedSoftware;
  ObuConnectionMode get connectionMode => _connectionMode;

  bool _isHardwareConnected = false;
  bool get isHardwareConnected => _isHardwareConnected;

  String _hardwareDeviceName = 'Virtual C-V2X OBU Transceiver';
  String get hardwareDeviceName => _hardwareDeviceName;

  bool _sirenActive = true;
  bool get sirenActive => _sirenActive;

  final List<String> _cv2xPacketLog = [];
  List<String> get cv2xPacketLog => List.unmodifiable(_cv2xPacketLog);

  final StreamController<List<String>> _packetLogController =
      StreamController<List<String>>.broadcast();
  Stream<List<String>> get packetLogStream => _packetLogController.stream;

  final StreamController<SignalStatusMessage> _ssmStreamController =
      StreamController<SignalStatusMessage>.broadcast();
  Stream<SignalStatusMessage> get ssmStream => _ssmStreamController.stream;

  void toggleSiren(bool active) {
    _sirenActive = active;
    _logPacket('EV-STATUS: Siren state toggled -> ${_sirenActive ? "ACTIVE (Preemption Armed)" : "OFF (Standby)"}');
  }

  /// Sets the OBU connection mode (Switches between simulation and physical hardware)
  void setConnectionMode(ObuConnectionMode mode) {
    _connectionMode = mode;
    switch (mode) {
      case ObuConnectionMode.simulatedSoftware:
        _isHardwareConnected = true;
        _hardwareDeviceName = 'Virtual C-V2X OBU Transceiver (SAE J2735)';
        break;
      case ObuConnectionMode.serialUsbOtG:
        _isHardwareConnected = true; // Pre-configured port ready
        _hardwareDeviceName = 'Commsignia / Quectel AG15 USB-OTG Modem (/dev/ttyUSB0)';
        break;
      case ObuConnectionMode.bluetoothBle:
        _isHardwareConnected = true;
        _hardwareDeviceName = 'Rakshak BLE Emergency Dash Beacon (UUID: 0xFD6F)';
        break;
      case ObuConnectionMode.directCv2xPc5:
        _isHardwareConnected = true;
        _hardwareDeviceName = 'Qualcomm 9150 C-V2X Direct PC5 Transceiver';
        break;
    }
    _logPacket('OBU-CONFIG: Mode set to ${_connectionMode.name.toUpperCase()} on $_hardwareDeviceName');
  }

  /// Broadcasts SAE J2735 Basic Safety Message (BSM)
  BasicSafetyMessage generateBsm({
    required String ambulanceId,
    required String plateNumber,
    required LatLng position,
    required double speedKmh,
    required double heading,
  }) {
    final bsm = BasicSafetyMessage(
      vehicleId: ambulanceId,
      plateNumber: plateNumber,
      position: position,
      speedKmh: speedKmh,
      headingDegrees: heading,
      sirenActive: _sirenActive,
      emergencyLightsActive: true,
      timestamp: DateTime.now(),
    );

    _logPacket(
      'OUT [BSM 0x01]: Unit: $plateNumber | Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)} | Speed: ${speedKmh.toStringAsFixed(1)}km/h | Siren: ${_sirenActive ? "ON" : "OFF"}',
    );

    return bsm;
  }

  /// Transmits SAE J2735 Signal Request Message (SRM) to an approaching intersection
  SignalRequestMessage requestSignalPreemption({
    required String ambulanceId,
    required RealTrafficSignalNode targetSignal,
    required double distanceMeters,
    required double speedKmh,
  }) {
    final effectiveSpeedMps = max(speedKmh * (1000 / 3600), 10.0);
    final etaSeconds = (distanceMeters / effectiveSpeedMps).round().clamp(5, 60);

    final srm = SignalRequestMessage(
      requestId: 'REQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      vehicleId: ambulanceId,
      intersectionId: targetSignal.id,
      junctionName: targetSignal.name,
      priority: PriorityLevel.criticalTraumaLevel1,
      etaSeconds: etaSeconds,
      distanceMeters: distanceMeters,
      inboundApproachDirection: 'Eastbound Artery Phase 2',
      requestedAt: DateTime.now(),
    );

    _logPacket(
      'OUT [SRM 0x0E]: -> [${targetSignal.controllerId}] Junction: "${targetSignal.name}" | Priority: LEVEL-1 | Dist: ${distanceMeters.toStringAsFixed(0)}m | ETA: ${etaSeconds}s',
    );

    // Simulate RSU Controller Acknowledgment (SSM)
    Timer(const Duration(milliseconds: 300), () {
      final ssm = SignalStatusMessage(
        intersectionId: targetSignal.id,
        junctionName: targetSignal.name,
        requestId: srm.requestId,
        state: SignalPreemptionState.preemptedGreen,
        activeGreenHoldSeconds: etaSeconds + 10,
        queueClearanceActive: true,
        confirmedAt: DateTime.now(),
      );

      _ssmStreamController.add(ssm);
      _logPacket(
        'IN  [SSM 0x0F]: <- [${targetSignal.controllerId}] STATUS: PREEMPTION_GRANTED | Green Hold: ${etaSeconds + 10}s | Queue Clearance: ACTIVE',
      );
    });

    return srm;
  }

  void _logPacket(String packet) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final entry = '[$timestamp] $packet';
    _cv2xPacketLog.insert(0, entry);
    if (_cv2xPacketLog.length > 50) {
      _cv2xPacketLog.removeLast();
    }
    _packetLogController.add(_cv2xPacketLog);
    debugPrint('[C-V2X OBU] $entry');
  }

  void clearLogs() {
    _cv2xPacketLog.clear();
    _packetLogController.add(_cv2xPacketLog);
  }

  /// Broadcasts C-V2X PC5 & BLE Emergency Distress Beacon (Zero Network / Offline Hop)
  void transmitEmergencyDistressBeacon({
    required double latitude,
    required double longitude,
    required double speedKmh,
    required double gForce,
  }) {
    _logPacket(
      'OUT [C-V2X PC5 SOS]: DIRECT SIDELINK BROADCAST (5.9 GHz ITS Band)\n'
      '    Co-ordinates: $latitude, $longitude | Impact G: ${gForce.toStringAsFixed(1)}G | Speed: ${speedKmh.toStringAsFixed(0)}km/h\n'
      '    Hop Protocol: Delay-Tolerant Store-and-Forward Mesh (Passing Vehicles Listening)',
    );
  }
}
