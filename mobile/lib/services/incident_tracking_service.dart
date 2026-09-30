import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_client.dart';

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
      return;
    }

    final candidates = candidateUrls ??
        <String>[
          'http://127.0.0.1:5000',
          'http://192.168.1.21:5000',
          if (kDefaultBackendUrl != 'http://10.0.2.2:5000') kDefaultBackendUrl,
          'http://10.208.188.149:5000',
          'http://172.22.61.163:5000',
          'http://10.0.2.2:5000',
        ].toSet().toList();

    _connectToSocket(incidentId, candidates);
  }

  void _connectToSocket(String incidentId, List<String> candidates) {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    for (final url in candidates) {
      try {
        final socket = io.io(
          url,
          io.OptionBuilder()
              .setTransports(['websocket'])
              .enableAutoConnect()
              .setReconnectionAttempts(5)
              .build(),
        );

        socket.onConnect((_) {
          debugPrint('[IncidentTrackingService] Connected to $url, joining incident:$incidentId');
          socket.emit('join_incident', incidentId);
        });

        socket.on('case_accepted', (data) {
          debugPrint('[IncidentTrackingService] case_accepted received: $data');
          if (data is Map) {
            final incId = data['incident_id']?.toString();
            if (incId == null || incId == _trackedIncidentId) {
              final hosp = data['hospital'] as Map?;
              statusNotifier.value = TriageStatus(
                state: TriageState.accepted,
                incidentId: _trackedIncidentId,
                hospitalName: hosp?['name']?.toString() ?? 'Trauma Center',
                hospitalAddress: hosp?['address']?.toString() ?? 'Emergency Bay',
                hospitalPhone: hosp?['phone']?.toString() ?? '108',
                hospitalLat: (hosp?['latitude'] as num?)?.toDouble(),
                hospitalLng: (hosp?['longitude'] as num?)?.toDouble(),
                message: 'Emergency accepted by trauma center. Ambulance dispatched.',
              );
            }
          }
        });

        socket.on('incident_escalated', (data) {
          debugPrint('[IncidentTrackingService] incident_escalated received: $data');
          if (data is Map) {
            final incId = data['incident_id']?.toString();
            if (incId == null || incId == _trackedIncidentId) {
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
            final incId = data['incident_id']?.toString();
            if (incId == null || incId == _trackedIncidentId) {
              statusNotifier.value = statusNotifier.value.copyWith(
                state: TriageState.unmatched,
                message: 'No immediate trauma centers available. Central emergency dispatch notified.',
              );
            }
          }
        });

        _socket = socket;
        break;
      } catch (err) {
        debugPrint('[IncidentTrackingService] Error attempting $url: $err');
      }
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
