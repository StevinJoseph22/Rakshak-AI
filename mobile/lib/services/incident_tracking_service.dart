import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_client.dart';
import 'emergency_sms_service.dart';

enum TriageState {
  idle,
  broadcasting,
  accepted,
  escalated,
  unmatched,
}

class TriageStatus {
  final TriageState state;
  final String? incidentId;
  final String? hospitalName;
  final String? hospitalAddress;
  final String? hospitalPhone;
  final double? hospitalLat;
  final double? hospitalLng;
  final String? searchRadius;
  final String? message;
  final bool isConnected;

  const TriageStatus({
    this.state = TriageState.idle,
    this.incidentId,
    this.hospitalName,
    this.hospitalAddress,
    this.hospitalPhone,
    this.hospitalLat,
    this.hospitalLng,
    this.searchRadius,
    this.message,
    this.isConnected = true,
  });

  TriageStatus copyWith({
    TriageState? state,
    String? incidentId,
    String? hospitalName,
    String? hospitalAddress,
    String? hospitalPhone,
    double? hospitalLat,
    double? hospitalLng,
    String? searchRadius,
    String? message,
    bool? isConnected,
  }) {
    return TriageStatus(
      state: state ?? this.state,
      incidentId: incidentId ?? this.incidentId,
      hospitalName: hospitalName ?? this.hospitalName,
      hospitalAddress: hospitalAddress ?? this.hospitalAddress,
      hospitalPhone: hospitalPhone ?? this.hospitalPhone,
      hospitalLat: hospitalLat ?? this.hospitalLat,
      hospitalLng: hospitalLng ?? this.hospitalLng,
      searchRadius: searchRadius ?? this.searchRadius,
      message: message ?? this.message,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

class IncidentTrackingService {
  IncidentTrackingService._internal();
  static final IncidentTrackingService _instance = IncidentTrackingService._internal();
  static IncidentTrackingService get instance => _instance;

  io.Socket? _socket;
  String? _trackedIncidentId;

  final ValueNotifier<TriageStatus> statusNotifier =
      ValueNotifier<TriageStatus>(const TriageStatus());

  bool isEnabled = true;

  bool get _isTestEnvironment {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  /// Connects to Socket.io backend and joins room `incident:<incidentId>`
  void trackIncident(String incidentId, {List<String>? candidateUrls}) {
    _trackedIncidentId = incidentId;
    statusNotifier.value = TriageStatus(
      state: TriageState.broadcasting,
      incidentId: incidentId,
      message: 'Broadcasting dispatch to nearest trauma facilities...',
    );

    if (!isEnabled || _isTestEnvironment) {
      return;
    }

    if (_socket != null && _socket!.connected) {
      debugPrint('[IncidentTrackingService] Socket already connected, emitting join_incident:$incidentId');
      _socket!.emit('join_incident', incidentId);
      return;
    }

    final candidates = candidateUrls ?? getBackendCandidates();
    _connectToSocket(incidentId, candidates);
  }

  Future<void> _connectToSocket(String incidentId, List<String> candidates) async {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    final workingUrl = await resolveReachableBackendUrl();
    debugPrint('[IncidentTrackingService] Connecting socket to $workingUrl for incident:$incidentId');

    try {
      final socket = io.io(
        workingUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .setReconnectionAttempts(10)
            .setReconnectionDelay(1000)
            .build(),
      );

      socket.onConnect((_) {
        debugPrint('[IncidentTrackingService] Connected to $workingUrl, joining incident:$incidentId');
        statusNotifier.value = statusNotifier.value.copyWith(isConnected: true);
        if (_trackedIncidentId != null) {
          socket.emit('join_incident', _trackedIncidentId);
        }
      });

      socket.on('reconnect', (_) {
        debugPrint('[IncidentTrackingService] Reconnected to $workingUrl, rejoining incident:$_trackedIncidentId');
        statusNotifier.value = statusNotifier.value.copyWith(isConnected: true);
        if (_trackedIncidentId != null) {
          socket.emit('join_incident', _trackedIncidentId);
        }
      });

      socket.onDisconnect((_) {
        debugPrint('[IncidentTrackingService] Disconnected from socket');
        statusNotifier.value = statusNotifier.value.copyWith(isConnected: false);
      });

      socket.onConnectError((err) {
        debugPrint('[IncidentTrackingService] Connection error: $err');
        statusNotifier.value = statusNotifier.value.copyWith(isConnected: false);
      });

      socket.on('case_accepted', (data) {
        debugPrint('[IncidentTrackingService] case_accepted received: $data');
        if (data is Map) {
          final incId = data['incident_id']?.toString().toLowerCase().trim();
          final trackedId = _trackedIncidentId?.toLowerCase().trim();
          if (incId == null || trackedId == null || incId == trackedId) {
            final hosp = data['hospital'] as Map?;
            final hospName = hosp?['name']?.toString() ?? 'Trauma Center';
            final hospAddress = hosp?['address']?.toString() ?? 'Emergency Bay';
            final hospPhone = hosp?['phone']?.toString() ?? '108';

            statusNotifier.value = TriageStatus(
              state: TriageState.accepted,
              incidentId: _trackedIncidentId ?? incId,
              hospitalName: hospName,
              hospitalAddress: hospAddress,
              hospitalPhone: hospPhone,
              hospitalLat: (hosp?['latitude'] as num?)?.toDouble(),
              hospitalLng: (hosp?['longitude'] as num?)?.toDouble(),
              message: 'Emergency accepted by $hospName. Trauma bay ready.',
            );

            // Privacy note: Emergency contact data is stored locally on-device and only sent
            // alongside an actual confirmed incident dispatch via victim_metadata.
            // Dispatch follow-up update SMS: "UPDATE: [victim] has been accepted by [hospital]..."
            EmergencySmsService.instance.sendHospitalAcceptedAlert(
              incidentId: _trackedIncidentId ?? incId,
              hospitalName: hospName,
              hospitalAddress: hospAddress,
              hospitalPhone: hospPhone,
            );
          }
        }
      });

      socket.on('incident_claimed', (data) {
        debugPrint('[IncidentTrackingService] incident_claimed received: $data');
        if (data is Map) {
          final incId = data['incident_id']?.toString().toLowerCase().trim();
          final trackedId = _trackedIncidentId?.toLowerCase().trim();
          final ambId = data['ambulance_id']?.toString() ?? '108 Unit';
          if (incId == null || trackedId == null || incId == trackedId) {
            statusNotifier.value = statusNotifier.value.copyWith(
              message: 'Ambulance $ambId is dispatched and en route.',
            );

            // Dispatch follow-up update SMS: "UPDATE: Ambulance [ambId] has been dispatched..."
            EmergencySmsService.instance.sendAmbulanceDispatchedAlert(
              incidentId: _trackedIncidentId ?? incId,
              ambulanceId: ambId,
            );
          }
        }
      });

      socket.on('incident_escalated', (data) {
        debugPrint('[IncidentTrackingService] incident_escalated received: $data');
        if (data is Map) {
          final incId = data['incident_id']?.toString().toLowerCase().trim();
          final trackedId = _trackedIncidentId?.toLowerCase().trim();
          if (incId == null || trackedId == null || incId == trackedId) {
            final radius = data['search_radius']?.toString() ?? '20km';
            statusNotifier.value = statusNotifier.value.copyWith(
              state: TriageState.escalated,
              searchRadius: radius,
              message: 'Searching wider trauma network ($radius)...',
            );
          }
        }
      });

      socket.on('incident_unmatched', (data) {
        debugPrint('[IncidentTrackingService] incident_unmatched received: $data');
        if (data is Map) {
          final incId = data['incident_id']?.toString().toLowerCase().trim();
          final trackedId = _trackedIncidentId?.toLowerCase().trim();
          if (incId == null || trackedId == null || incId == trackedId) {
            statusNotifier.value = statusNotifier.value.copyWith(
              state: TriageState.unmatched,
              message: 'No immediate trauma centers available. Central emergency dispatch notified.',
            );
          }
        }
      });

      _socket = socket;
    } catch (err) {
      debugPrint('[IncidentTrackingService] Error attempting connection: $err');
    }
  }

  void leaveIncident() {
    try {
      _socket?.disconnect();
      _socket?.destroy();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
    _trackedIncidentId = null;
    statusNotifier.value = const TriageStatus();
  }
}
