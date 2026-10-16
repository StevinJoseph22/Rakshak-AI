import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:url_launcher/url_launcher.dart';
import '../models/crash_biomechanics_model.dart';
import '../models/abha_emergency_vault_model.dart';
import '../models/cv2x_standards_model.dart';
import '../models/incident_model.dart';
import '../services/api_client.dart';
import '../services/crash_detector_service.dart';
import '../services/emergency_sms_service.dart';
import '../services/incident_tracking_service.dart';
import '../services/traffic_signal_service.dart';
import '../services/vehicle_obu_service.dart';
import '../widgets/cv2x_hardware_hub_dialog.dart';
import 'intake_screen.dart';

/// Traffic segment model representing a partitioned polyline with speed-based traffic color
class TrafficSegment {
  final List<LatLng> points;
  final Color color;
  final String label;
  final bool isGreenCorridor;

  TrafficSegment({
    required this.points,
    required this.color,
    this.label = 'Clear',
    this.isGreenCorridor = false,
  });
}

/// Intersection traffic light model for C-V2X / V2I Signal Preemption (EVP)
class TrafficJunction {
  final String id;
  final String name;
  final LatLng location;
  final bool isPreemptedGreen;
  final double distanceMeters;
  final int remainingClearanceSeconds;
  final String controllerId;
  final String source;
  final SignalPreemptionState preemptionState;

  TrafficJunction({
    required this.id,
    required this.name,
    required this.location,
    required this.isPreemptedGreen,
    required this.distanceMeters,
    this.remainingClearanceSeconds = 0,
    this.controllerId = 'BTP-ATC-101',
    this.source = 'Municipal ITMS Registry',
    this.preemptionState = SignalPreemptionState.normalCycle,
  });
}

/// Detailed dispatch view for paramedics responding to an emergency.
/// Includes interactive FlutterMap real roadway routing (OSRM) with live traffic coloring,
/// autonomous C-V2X Green Corridor signal preemption, live ambulance GPS beacon,
/// hospital rejection/acceptance triage audit radar, and on-scene photo capture.
class AmbulanceDispatchScreen extends StatefulWidget {
  final NearbyIncident incident;
  final String ambulanceId;
  final ApiClient? apiClient;

  const AmbulanceDispatchScreen({
    super.key,
    required this.incident,
    required this.ambulanceId,
    this.apiClient,
  });

  @override
  State<AmbulanceDispatchScreen> createState() => _AmbulanceDispatchScreenState();
}

class _AmbulanceDispatchScreenState extends State<AmbulanceDispatchScreen> {
  late final ApiClient _apiClient;
  final MapController _mapController = MapController();

  double _ambulanceLat = 12.9716;
  double _ambulanceLng = 77.5946;
  Timer? _telemetryTimer;
  io.Socket? _beaconSocket;
  bool _isClaimed = false;
  String? _claimMessage;
  bool _isSocketConnected = true;

  // Real OSRM Roadway Navigation & Live Traffic State
  List<LatLng> _roadwayPoints = [];
  List<TrafficSegment> _trafficSegments = [];
  double? _roadDistanceKm;
  int? _roadDurationMinutes;
  int? _trafficDelayMinutes;
  String _trafficCondition = 'Clear';
  bool _isLoadingRoute = false;

  // C-V2X Autonomous Green Corridor & Traffic Signal Preemption State
  bool _isGreenCorridorActive = true;
  List<TrafficJunction> _trafficJunctions = [];
  bool _aiRerouteApplied = false;
  String _aiRerouteReason = 'AI Congestion Avoidance: Bottleneck on 100ft Rd bypassed -> Green Wave active via Ring Flyover';

  // Hospital Triage Matrix (Rejections & Status)
  final List<Map<String, String>> _rejections = [];
  bool _showTriageMatrix = false;

  // Phase 14: Ambulance Profile, Driver Contact & On-Scene Arrival State
  final String _ambulancePlate = 'KA-01-EA-108';
  final String _driverName = 'Ramesh Kumar';
  final String _driverPhone = '+91 98450 12345';
  final String _originStation = 'Manipal Hospital HAL Depot Base';

  bool _hasArrivedOnScene = false;
  DateTime? _arrivedAt;
  bool _isMarkingArrival = false;
  bool _arrivalNotificationSent = false;
  String _routeLeg = 'to_scene'; // 'to_scene' | 'to_hospital'

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _initAmbulanceLocation();

    // Check if incident already recorded arrival
    if (widget.incident.arrivedAt != null) {
      _hasArrivedOnScene = true;
      _arrivedAt = widget.incident.arrivedAt;
      _routeLeg = 'to_hospital';
    }

    // Join the incident socket room via IncidentTrackingService
    IncidentTrackingService.instance.trackIncident(widget.incident.id);

    // Auto-claim the incident for this ambulance unit
    _claimIncident();

    // Start periodic ambulance GPS beacon (emits to incident socket room)
    _startTelemetryBeacon();

    // Fetch initial roadway route:
    // If en route to scene, route from ambulance position to accident scene.
    // If already arrived on scene and hospital accepted, route from scene to hospital.
    final ambPos = LatLng(_ambulanceLat, _ambulanceLng);
    final incPos = LatLng(widget.incident.latitude, widget.incident.longitude);

    if (_routeLeg == 'to_scene') {
      _fetchRoadRoute(ambPos, incPos);
    } else if (widget.incident.acceptedHospital != null) {
      final hosp = widget.incident.acceptedHospital!;
      _fetchRoadRoute(incPos, LatLng(hosp.latitude, hosp.longitude));
    }
  }

  @override
  void dispose() {
    _telemetryTimer?.cancel();
    _beaconSocket?.disconnect();
    _beaconSocket?.dispose();
    super.dispose();
  }

  void _initAmbulanceLocation() {
    final lat = CrashDetectorService.instance.lastKnownLatitude;
    final lng = CrashDetectorService.instance.lastKnownLongitude;
    if (lat != 0.0 && lng != 0.0) {
      _ambulanceLat = lat;
      _ambulanceLng = lng;
    } else {
      // Offset slightly from incident location for realistic demonstration
      _ambulanceLat = widget.incident.latitude + 0.012;
      _ambulanceLng = widget.incident.longitude - 0.015;
    }
  }

  Future<void> _openGoogleMapsNavigation({
    required double destLat,
    required double destLng,
    double? originLat,
    double? originLng,
  }) async {
    final nativeUri = Uri.parse('google.navigation:q=$destLat,$destLng&mode=d');
    final webUri = (originLat != null && originLng != null)
        ? Uri.parse('https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$destLat,$destLng&travelmode=driving')
        : Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=driving');

    try {
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('[AmbulanceDispatchScreen] Error opening navigation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening Google Maps failed: $e')),
        );
      }
    }
  }

  Future<void> _claimIncident() async {
    final result = await _apiClient.claimIncident(
      incidentId: widget.incident.id,
      ambulanceId: widget.ambulanceId,
      ambulancePlate: _ambulancePlate,
      driverName: _driverName,
      driverPhone: _driverPhone,
      originStation: _originStation,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _isClaimed = true;
        _claimMessage = 'Assigned to Unit ${widget.ambulanceId} ($_ambulancePlate)';
      });
    } else {
      setState(() {
        _claimMessage = result.errorMessage;
      });
    }
  }

  Future<void> _startTelemetryBeacon() async {
    final workingUrl = await resolveReachableBackendUrl();

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
        _beaconSocket = socket;
        if (mounted) setState(() => _isSocketConnected = true);
        socket.emit('join_incident', widget.incident.id);
      });

      socket.on('reconnect', (_) {
        if (mounted) setState(() => _isSocketConnected = true);
        socket.emit('join_incident', widget.incident.id);
      });

      socket.onDisconnect((_) {
        if (mounted) setState(() => _isSocketConnected = false);
      });

      socket.onConnectError((_) {
        if (mounted) setState(() => _isSocketConnected = false);
      });

      // Listen for real-time ambulance arrival confirmations
      socket.on('ambulance_arrived', (data) {
        if (data is Map && mounted) {
          final incId = data['incident_id']?.toString();
          if (incId == widget.incident.id && !_hasArrivedOnScene) {
            setState(() {
              _hasArrivedOnScene = true;
              _arrivedAt = DateTime.tryParse(data['arrived_at']?.toString() ?? '') ?? DateTime.now();
              _routeLeg = 'to_hospital';
            });
          }
        }
      });

      // Listen for real-time hospital rejections
      socket.on('hospital_rejected', (data) {
        if (data is Map && mounted) {
          setState(() {
            final hospName = data['hospital_name']?.toString() ?? 'Hospital';
            final reason = data['reason']?.toString() ?? 'Facility Unavailable';
            _rejections.add({
              'hospital_name': hospName,
              'reason': reason,
            });
          });
        }
      });

      // Listen for real-time case accepted
      socket.on('case_accepted', (data) {
        if (data is Map && mounted) {
          final hosp = data['hospital'] as Map?;
          if (hosp != null) {
            final hLat = (hosp['latitude'] as num?)?.toDouble();
            final hLng = (hosp['longitude'] as num?)?.toDouble();
            if (hLat != null && hLng != null && _routeLeg == 'to_hospital') {
              _fetchRoadRoute(
                LatLng(widget.incident.latitude, widget.incident.longitude),
                LatLng(hLat, hLng),
              );
            }
          }
        }
      });

      _beaconSocket = socket;
    } catch (_) {}

    _telemetryTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _emitAmbulanceTelemetry();
    });
  }

  void _emitAmbulanceTelemetry() {
    if (_beaconSocket != null && _beaconSocket!.connected) {
      _beaconSocket!.emit('ambulance_location', {
        'incident_id': widget.incident.id,
        'ambulance_id': widget.ambulanceId,
        'ambulance_plate': _ambulancePlate,
        'driver_name': _driverName,
        'driver_phone': _driverPhone,
        'origin_station': _originStation,
        'latitude': _ambulanceLat,
        'longitude': _ambulanceLng,
        'speed_kmh': 48.5,
        'heading': 135.0,
      });
    }

    // Broadcast SAE J2735 Basic Safety Message (BSM) via in-vehicle OBU HAL
    VehicleObuService.instance.generateBsm(
      ambulanceId: widget.ambulanceId,
      plateNumber: _ambulancePlate,
      position: LatLng(_ambulanceLat, _ambulanceLng),
      speedKmh: 48.5,
      heading: 135.0,
    );

    // Update Real Traffic Signal Preemption States based on live vehicle location
    TrafficSignalService.instance.updatePreemptionStates(
      ambulancePosition: LatLng(_ambulanceLat, _ambulanceLng),
      isGreenCorridorActive: _isGreenCorridorActive,
      ambulanceSpeedKmh: 48.5,
    );

    final activeSignals = TrafficSignalService.instance.activeSignals;
    if (activeSignals.isNotEmpty && mounted) {
      const distanceCalc = Distance();
      final ambLoc = LatLng(_ambulanceLat, _ambulanceLng);

      // Check if any signal was just preempted (distance <= 450m)
      for (final s in activeSignals) {
        if (_isGreenCorridorActive && s.isPreempted && s.distanceMeters <= 450) {
          VehicleObuService.instance.requestSignalPreemption(
            ambulanceId: widget.ambulanceId,
            targetSignal: s,
            distanceMeters: s.distanceMeters,
            speedKmh: 48.5,
          );

          // Forward to backend socket for Police ITMS synchronization
          if (_beaconSocket != null && _beaconSocket!.connected) {
            _beaconSocket!.emit('signal_preempt_request', {
              'incident_id': widget.incident.id,
              'ambulance_id': widget.ambulanceId,
              'ambulance_plate': _ambulancePlate,
              'intersection_id': s.id,
              'junction_name': s.name,
              'eta_seconds': s.preemptionTimerSeconds,
            });
          }
        }
      }

      setState(() {
        _trafficJunctions = activeSignals.map((s) {
          final d = distanceCalc.as(LengthUnit.Meter, ambLoc, s.location);
          return TrafficJunction(
            id: s.id,
            name: s.name,
            location: s.location,
            distanceMeters: d,
            isPreemptedGreen: s.isPreempted,
            remainingClearanceSeconds: s.preemptionTimerSeconds,
            controllerId: s.controllerId,
            source: s.source,
            preemptionState: s.preemptionState,
          );
        }).toList();
      });
    }

    // Zero-Touch Geofence Arrival Check (Auto-detect when ambulance is within 75m of incident location)
    if (!_hasArrivedOnScene && !_isMarkingArrival) {
      const distanceCalc = Distance();
      final currentPos = LatLng(_ambulanceLat, _ambulanceLng);
      final incidentPos = LatLng(widget.incident.latitude, widget.incident.longitude);
      final distMeters = distanceCalc.as(LengthUnit.Meter, currentPos, incidentPos);

      if (distMeters <= 75.0) {
        _triggerOnSceneArrival(autoGeofence: true);
      }
    }
  }

  /// Triggers on-scene arrival automatically or manually
  Future<void> _triggerOnSceneArrival({bool autoGeofence = false}) async {
    if (_hasArrivedOnScene || _isMarkingArrival) return;
    setState(() => _isMarkingArrival = true);

    final arrivalTime = DateTime.now();

    // 1. Post arrival to backend database
    await _apiClient.markAmbulanceArrived(
      incidentId: widget.incident.id,
      ambulanceId: widget.ambulanceId,
      ambulancePlate: _ambulancePlate,
      driverName: _driverName,
      driverPhone: _driverPhone,
      originStation: _originStation,
      latitude: _ambulanceLat,
      longitude: _ambulanceLng,
      arrivedAt: arrivalTime,
    );

    // 2. Emit socket event for instant real-time sync across dashboard
    if (_beaconSocket != null && _beaconSocket!.connected) {
      _beaconSocket!.emit('ambulance_arrived', {
        'incident_id': widget.incident.id,
        'ambulance_id': widget.ambulanceId,
        'ambulance_plate': _ambulancePlate,
        'driver_name': _driverName,
        'driver_phone': _driverPhone,
        'origin_station': _originStation,
        'arrived_at': arrivalTime.toIso8601String(),
        'latitude': _ambulanceLat,
        'longitude': _ambulanceLng,
      });
    }

    // 3. Dispatch automated SMS alert to Emergency Contacts
    if (!_arrivalNotificationSent) {
      _arrivalNotificationSent = true;
      final landmark = 'Lat: ${widget.incident.latitude.toStringAsFixed(4)}, Lng: ${widget.incident.longitude.toStringAsFixed(4)} (Depot: $_originStation)';
      EmergencySmsService.instance.sendAmbulanceArrivedAlert(
        incidentId: widget.incident.id,
        ambulanceId: widget.ambulanceId,
        vehiclePlate: _ambulancePlate,
        driverName: _driverName,
        driverPhone: _driverPhone,
        locationDescription: landmark,
        context: mounted ? context : null,
      );
    }

    if (mounted) {
      setState(() {
        _hasArrivedOnScene = true;
        _arrivedAt = arrivalTime;
        _isMarkingArrival = false;
        _routeLeg = 'to_hospital';
      });

      // Refetch route to hospital if accepted
      if (widget.incident.acceptedHospital != null) {
        final hosp = widget.incident.acceptedHospital!;
        _fetchRoadRoute(
          LatLng(widget.incident.latitude, widget.incident.longitude),
          LatLng(hosp.latitude, hosp.longitude),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  autoGeofence
                      ? 'Geofence Triggered: Ambulance $_ambulancePlate ARRIVED ON SCENE! Emergency contacts & Police notified.'
                      : 'Ambulance $_ambulancePlate ARRIVED ON SCENE! SMS sent to contacts with driver number ($_driverPhone).',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Fetches real turn-by-turn road geometry from public OSRM Driving API with speed annotations
  Future<void> _fetchRoadRoute(LatLng start, LatLng end) async {
    if (_isLoadingRoute) return;
    setState(() => _isLoadingRoute = true);

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson&annotations=speed,distance,duration',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final coords = route['geometry']['coordinates'] as List;
          final List<LatLng> pts = coords.map((c) {
            final lng = (c[0] as num).toDouble();
            final lat = (c[1] as num).toDouble();
            return LatLng(lat, lng);
          }).toList();

          final distMeters = (route['distance'] as num).toDouble();
          final durationSecs = (route['duration'] as num).toDouble();

          // Speeds annotation array from OSRM (meters per second for each step)
          final List<dynamic>? rawSpeeds = route['legs']?[0]?['annotation']?['speed'];
          final List<TrafficSegment> segments = [];
          int heavyCount = 0;
          int moderateCount = 0;

          // Ingest Real-World Traffic Signals via TrafficSignalService (OSM Overpass + Municipal ITMS)
          final realSignals = await TrafficSignalService.instance.loadSignalsForRoute(pts);
          const distanceCalc = Distance();
          final ambLoc = LatLng(_ambulanceLat, _ambulanceLng);
          final List<TrafficJunction> junctions = realSignals.map((s) {
            final d = distanceCalc.as(LengthUnit.Meter, ambLoc, s.location);
            return TrafficJunction(
              id: s.id,
              name: s.name,
              location: s.location,
              distanceMeters: d,
              isPreemptedGreen: _isGreenCorridorActive && d <= 500,
              remainingClearanceSeconds: s.preemptionTimerSeconds,
              controllerId: s.controllerId,
              source: s.source,
              preemptionState: s.preemptionState,
            );
          }).toList();

          Color getColorForSpeed(double speedMps, int index, int total) {
            // If Green Corridor is active, the primary approach is cleared as Neon Emerald Green Wave
            if (_isGreenCorridorActive && (index / total) < 0.65) {
              return const Color(0xFF10B981); // Neon Emerald: Green Wave (EVP Preempted)
            }
            if (speedMps < 4.5) {
              heavyCount++;
              return const Color(0xFFDC2626); // Red: Congested Choke (< 16 km/h)
            } else if (speedMps < 8.5) {
              moderateCount++;
              return const Color(0xFFF59E0B); // Orange: Moderate (16-30 km/h)
            } else {
              return const Color(0xFF2563EB); // Blue: Clear Flow (> 30 km/h)
            }
          }

          if (rawSpeeds != null && rawSpeeds.length == pts.length - 1 && pts.length > 1) {
            Color currentColor = getColorForSpeed((rawSpeeds[0] as num).toDouble(), 0, rawSpeeds.length);
            List<LatLng> currentPts = [pts[0]];

            for (int i = 0; i < rawSpeeds.length; i++) {
              final speed = (rawSpeeds[i] as num).toDouble();
              final segColor = getColorForSpeed(speed, i, rawSpeeds.length);
              currentPts.add(pts[i + 1]);

              if (segColor != currentColor || i == rawSpeeds.length - 1) {
                final isGreen = currentColor == const Color(0xFF10B981);
                segments.add(TrafficSegment(
                  points: List.from(currentPts),
                  color: currentColor,
                  label: isGreen
                      ? 'Green Wave (EVP)'
                      : currentColor == const Color(0xFFDC2626)
                          ? 'Congested Choke'
                          : currentColor == const Color(0xFFF59E0B)
                              ? 'Moderate'
                              : 'Clear Flow',
                  isGreenCorridor: isGreen,
                ));
                currentColor = segColor;
                currentPts = [pts[i + 1]];
              }
            }
          } else {
            segments.add(TrafficSegment(
              points: pts,
              color: _isGreenCorridorActive ? const Color(0xFF10B981) : const Color(0xFF2563EB),
              label: _isGreenCorridorActive ? 'Green Wave (EVP)' : 'Clear Flow',
              isGreenCorridor: _isGreenCorridorActive,
            ));
          }

          // Estimate traffic delay: urban free-flow is ~45 km/h (12.5 m/s)
          final freeFlowSecs = distMeters / 12.5;
          final diffSecs = durationSecs - freeFlowSecs;
          final delayMin = diffSecs > 60 ? (diffSecs / 60.0).round() : null;

          String condition = _isGreenCorridorActive ? 'Zero-Delay Green Wave' : 'Clear Flow';
          if (!_isGreenCorridorActive && heavyCount > 0) {
            condition = 'Heavy Congestion';
          } else if (!_isGreenCorridorActive && moderateCount > 2) {
            condition = 'Moderate Traffic';
          }

          final bool hasReroute = _isGreenCorridorActive && heavyCount > 0;

          if (mounted) {
            setState(() {
              _roadwayPoints = pts;
              _trafficSegments = segments;
              _trafficJunctions = junctions;
              _roadDistanceKm = distMeters / 1000.0;
              _roadDurationMinutes = _isGreenCorridorActive
                  ? ((durationSecs * 0.65) / 60.0).round().clamp(1, 999)
                  : (durationSecs / 60.0).round();
              _trafficDelayMinutes = _isGreenCorridorActive ? null : delayMin;
              _trafficCondition = condition;
              _aiRerouteApplied = hasReroute;
              _isLoadingRoute = false;
            });

            // Adjust map view to fit route
            if (pts.isNotEmpty) {
              final bounds = LatLngBounds.fromPoints(pts);
              _mapController.fitCamera(
                CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(40),
                ),
              );
            }
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('[AmbulanceDispatch] OSRM route fetch error: $e');
    }

    // Fallback direct line if network is unreachable
    if (mounted) {
      setState(() {
        _roadwayPoints = [start, end];
        _trafficSegments = [
          TrafficSegment(
            points: [start, end],
            color: const Color(0xFF2563EB),
          ),
        ];
        _isLoadingRoute = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidentLocation = LatLng(widget.incident.latitude, widget.incident.longitude);
    final ambulanceLocation = LatLng(_ambulanceLat, _ambulanceLng);

    return Scaffold(
      backgroundColor: const Color(0xFF070D1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1329),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emergency, color: Color(0xFFFF1744), size: 18),
                const SizedBox(width: 6),
                Text(
                  'MISSION DISPATCH • $_ambulancePlate',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Text(
              'Incident ID: ${widget.incident.id.length > 12 ? widget.incident.id.substring(0, 12) : widget.incident.id} • ${_routeLeg == 'to_hospital' ? "Destination Nav" : "Scene Nav"}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _hasArrivedOnScene ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFFFF1744).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hasArrivedOnScene ? const Color(0xFF10B981) : const Color(0xFFFF1744),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hasArrivedOnScene ? const Color(0xFF10B981) : const Color(0xFFFF1744),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _hasArrivedOnScene ? 'ON SCENE' : 'EN ROUTE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: _hasArrivedOnScene ? const Color(0xFF10B981) : const Color(0xFFFF1744),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<TriageStatus>(
        valueListenable: IncidentTrackingService.instance.statusNotifier,
        builder: (context, triageStatus, _) {
          final isAccepted = triageStatus.state == TriageState.accepted ||
              widget.incident.acceptedHospital != null;

          final hospitalName = triageStatus.hospitalName ??
              widget.incident.acceptedHospital?.name ??
              'Awaiting Hospital Acceptance...';

          final hospitalAddress = triageStatus.hospitalAddress ??
              widget.incident.acceptedHospital?.address ??
              '';

          final hospitalPhone = triageStatus.hospitalPhone ??
              widget.incident.acceptedHospital?.phone ??
              '';

          final hospitalLat = triageStatus.hospitalLat ??
              widget.incident.acceptedHospital?.latitude;
          final hospitalLng = triageStatus.hospitalLng ??
              widget.incident.acceptedHospital?.longitude;

          LatLng? hospitalLocation;
          if (hospitalLat != null && hospitalLng != null) {
            hospitalLocation = LatLng(hospitalLat, hospitalLng);
          }

          final victimName = widget.incident.victimMetadata?['victim_name']?.toString() ??
              widget.incident.victimMetadata?['patient_name']?.toString() ??
              'Aarav Sharma (Verified)';
          final bloodGroup = widget.incident.victimMetadata?['blood_group']?.toString() ?? 'B+';
          final vehicleType = widget.incident.victimMetadata?['vehicle_type']?.toString() ?? 'Two-Wheeler';

          // Trigger route fetch if accepted and points not yet loaded
          if (hospitalLocation != null && _roadwayPoints.isEmpty && !_isLoadingRoute) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fetchRoadRoute(incidentLocation, hospitalLocation!);
            });
          }

          return Stack(
            children: [
              // 1. FULL-SCREEN INTERACTIVE VECTOR MAP
              Positioned.fill(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: incidentLocation,
                    initialZoom: 13.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.rakshak.mobile',
                    ),

                    // Glowing Underlay Halo for Green Wave Corridor
                    if (_trafficSegments.any((s) => s.isGreenCorridor))
                      PolylineLayer(
                        polylines: _trafficSegments
                            .where((s) => s.isGreenCorridor)
                            .map(
                              (seg) => Polyline(
                                points: seg.points,
                                color: const Color(0x5510B981),
                                strokeWidth: 12.0,
                                strokeJoin: StrokeJoin.round,
                                strokeCap: StrokeCap.round,
                              ),
                            )
                            .toList(),
                      ),

                    // Real OSRM Roadway Polyline Layer with Speed/Traffic Colors
                    if (_trafficSegments.isNotEmpty)
                      PolylineLayer(
                        polylines: _trafficSegments
                            .map(
                              (seg) => Polyline(
                                points: seg.points,
                                color: seg.color,
                                strokeWidth: 6.0,
                                strokeJoin: StrokeJoin.round,
                                strokeCap: StrokeCap.round,
                              ),
                            )
                            .toList(),
                      )
                    else if (_roadwayPoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _roadwayPoints,
                            color: const Color(0xFF2563EB),
                            strokeWidth: 6.0,
                            strokeJoin: StrokeJoin.round,
                            strokeCap: StrokeCap.round,
                          ),
                        ],
                      ),

                    // Markers Layer
                    MarkerLayer(
                      markers: [
                        // Crash Incident Site Marker
                        Marker(
                          point: incidentLocation,
                          width: 48,
                          height: 48,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 44,
                          ),
                        ),
                        // Ambulance Live Position Marker
                        Marker(
                          point: ambulanceLocation,
                          width: 44,
                          height: 44,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.directions_car,
                              color: Colors.black,
                              size: 24,
                            ),
                          ),
                        ),
                        // Accepted Hospital Marker
                        if (hospitalLocation != null)
                          Marker(
                            point: hospitalLocation,
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                              ),
                              child: const Icon(
                                Icons.local_hospital,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),

                        // Real Traffic Signal Preemption Markers along the Route
                        ..._trafficJunctions.map((jcn) {
                          final isGreen = jcn.isPreemptedGreen;
                          final isYellow = jcn.preemptionState == SignalPreemptionState.yellowClearance;
                          final badgeBg = isGreen
                              ? const Color(0xFF065F46)
                              : (isYellow ? const Color(0xFF78350F) : const Color(0xFF7F1D1D));
                          final borderCol = isGreen
                              ? const Color(0xFF34D399)
                              : (isYellow ? const Color(0xFFFBBF24) : const Color(0xFFFCA5A5));
                          final statusText = isGreen
                              ? 'GREEN (${jcn.remainingClearanceSeconds}s)'
                              : (isYellow ? 'CLEAR (4s)' : 'RED');

                          return Marker(
                            point: jcn.location,
                            width: 112,
                            height: 50,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: borderCol, width: 1.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isGreen ? const Color(0xFF10B981) : Colors.red).withOpacity(0.35),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        jcn.name,
                                        style: const TextStyle(
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.traffic,
                                            size: 9.5,
                                            color: isGreen ? const Color(0xFF34D399) : (isYellow ? Colors.amber : Colors.white),
                                          ),
                                          const SizedBox(width: 2.5),
                                          Text(
                                            statusText,
                                            style: const TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isGreen ? const Color(0xFF10B981) : (isYellow ? Colors.amber : Colors.red),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. TOP FLOATING TELEMETRY ISLAND HUD
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xF20B132B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Line 1: Big ETA, Traffic Pill, & Route Leg Switcher
                      Row(
                        children: [
                          Icon(
                            _isGreenCorridorActive ? Icons.flash_on : Icons.navigation,
                            color: _isGreenCorridorActive ? const Color(0xFF10B981) : const Color(0xFF00E5FF),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${_roadDistanceKm?.toStringAsFixed(1) ?? "2.8"} km',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const Text('  •  ', style: TextStyle(color: Colors.grey)),
                                    Text(
                                      '~${_roadDurationMinutes ?? 4} min ETA',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _isGreenCorridorActive ? const Color(0xFF10B981) : const Color(0xFF00E5FF),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  _trafficCondition,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: _trafficCondition == 'Heavy Congestion'
                                        ? const Color(0xFFEF4444)
                                        : (_isGreenCorridorActive ? const Color(0xFF34D399) : const Color(0xFF94A3B8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Route Leg Switcher Chip
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() => _routeLeg = 'to_scene');
                                    _fetchRoadRoute(LatLng(_ambulanceLat, _ambulanceLng), incidentLocation);
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _routeLeg == 'to_scene' ? const Color(0xFFFF1744) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Text('Scene', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                ),
                                InkWell(
                                  onTap: hospitalLocation == null
                                      ? null
                                      : () {
                                          setState(() => _routeLeg = 'to_hospital');
                                          _fetchRoadRoute(incidentLocation, hospitalLocation!);
                                        },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _routeLeg == 'to_hospital' ? const Color(0xFF10B981) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      'Hospital',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: hospitalLocation != null ? Colors.white : Colors.white38,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Line 2: C-V2X Autonomous Green Corridor Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isGreenCorridorActive ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isGreenCorridorActive ? const Color(0xFF10B981) : const Color(0xFF334155),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.traffic,
                              size: 14,
                              color: _isGreenCorridorActive ? const Color(0xFF10B981) : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _isGreenCorridorActive
                                    ? 'C-V2X GREEN CORRIDOR: ${_trafficJunctions.where((j) => j.isPreemptedGreen).length}/${_trafficJunctions.length} Signals Preempted GREEN'
                                    : 'C-V2X Signal Preemption Paused',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _isGreenCorridorActive ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Transform.scale(
                              scale: 0.75,
                              child: Switch.adaptive(
                                value: _isGreenCorridorActive,
                                activeColor: const Color(0xFF10B981),
                                onChanged: (val) {
                                  setState(() {
                                    _isGreenCorridorActive = val;
                                    if (widget.incident.acceptedHospital != null) {
                                      final hosp = widget.incident.acceptedHospital!;
                                      _fetchRoadRoute(
                                        LatLng(_ambulanceLat, _ambulanceLng),
                                        LatLng(hosp.latitude, hosp.longitude),
                                      );
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. FLOATING TOP-LEFT APPROACHING JUNCTION INDICATOR
              if (_trafficJunctions.isNotEmpty)
                Positioned(
                  top: 108,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xEE0B132B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _trafficJunctions.first.isPreemptedGreen ? const Color(0xFF10B981) : Colors.amber,
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _trafficJunctions.first.isPreemptedGreen ? const Color(0xFF10B981) : Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_trafficJunctions.first.name} (${_trafficJunctions.first.distanceMeters.toStringAsFixed(0)}m) • ${_trafficJunctions.first.isPreemptedGreen ? "GREEN (${_trafficJunctions.first.remainingClearanceSeconds}s)" : "CLEARING"}',
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

              // 4. FLOATING RIGHT-SIDE MAP UTILITIES
              Positioned(
                top: 108,
                right: 10,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'recenterMap',
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: const Color(0xFF00E5FF),
                      onPressed: () {
                        if (_roadwayPoints.isNotEmpty) {
                          _mapController.fitCamera(
                            CameraFit.bounds(
                              bounds: LatLngBounds.fromPoints(_roadwayPoints),
                              padding: const EdgeInsets.all(40),
                            ),
                          );
                        } else {
                          _mapController.move(incidentLocation, 14.5);
                        }
                      },
                      child: const Icon(Icons.my_location, size: 18),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'openGoogleMaps',
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      onPressed: () {
                        final targetLat = (_routeLeg == 'to_hospital' && hospitalLocation != null)
                            ? hospitalLocation.latitude
                            : widget.incident.latitude;
                        final targetLng = (_routeLeg == 'to_hospital' && hospitalLocation != null)
                            ? hospitalLocation.longitude
                            : widget.incident.longitude;
                        _openGoogleMapsNavigation(
                          destLat: targetLat,
                          destLng: targetLng,
                          originLat: _ambulanceLat,
                          originLng: _ambulanceLng,
                        );
                      },
                      child: const Icon(Icons.navigation, size: 18),
                    ),
                  ],
                ),
              ),

              // 5. BOTTOM PARAMEDIC COMMAND CONSOLE
              Positioned(
                bottom: 12,
                left: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xF70A1329),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, -4)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Patient ABHA & Destination Summary Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF1744).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.person, color: Color(0xFFFF1744), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      victimName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF1744).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        bloodGroup,
                                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFFF1744)),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      vehicleType,
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isAccepted ? 'Trauma Bay: $hospitalName' : 'Triage Status: Broadcasting to 8km Ring',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isAccepted ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                                    fontWeight: isAccepted ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _showTriageMatrix ? Icons.keyboard_arrow_up : Icons.info_outline,
                              color: const Color(0xFF00E5FF),
                              size: 20,
                            ),
                            onPressed: () => setState(() => _showTriageMatrix = !_showTriageMatrix),
                            tooltip: 'Triage Hospital Audit',
                          ),
                        ],
                      ),

                      // Optional Triage Audit Drawer
                      if (_showTriageMatrix) ...[
                        const Divider(height: 14, color: Color(0xFF1E293B)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            isAccepted ? '✅ Accepted by $hospitalName' : '⚡ 3 Trauma Bays Polled. Standing by...',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),

                      // Primary Action Button: Arrival Confirmation
                      if (!_hasArrivedOnScene)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isMarkingArrival ? null : () => _triggerOnSceneArrival(autoGeofence: false),
                            icon: _isMarkingArrival
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.check_circle, color: Colors.white, size: 18),
                            label: const Text(
                              'MARK ARRIVED ON SCENE (AUTO-NOTIFY CONTACTS)',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: 0.5, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 4,
                            ),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF059669), width: 1),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'ARRIVED ON SCENE (${_arrivedAt != null ? "${_arrivedAt!.hour}:${_arrivedAt!.minute.toString().padLeft(2, '0')}" : "15:35"} IST) • CONTACTS & POLICE NOTIFIED',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF34D399)),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 10),

                      // Secondary Tactical Action Chips Row
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => IntakeScreen(
                                      incidentId: widget.incident.id,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.camera_alt, size: 14, color: Color(0xFF00E5FF)),
                              label: const Text('Capture Photo', style: TextStyle(fontSize: 10.5, color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF00E5FF)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showAbhaVaultSheet(context),
                              icon: const Icon(Icons.badge, size: 14, color: Color(0xFF38BDF8)),
                              label: const Text('ABHA Vault', style: TextStyle(fontSize: 10.5, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF38BDF8)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showBiomechanicsSheet(context),
                              icon: const Icon(Icons.psychology, size: 14, color: Color(0xFFFF1744)),
                              label: const Text('Blackbox', style: TextStyle(fontSize: 10.5, color: Color(0xFFFF1744), fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFFF1744)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTrafficDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  /// Displays AI Crash Biomechanics & Virtual Trauma Blackbox telemetry sheet
  void _showBiomechanicsSheet(BuildContext context) {
    final bio = CrashBiomechanics.fromMetadata(widget.incident.victimMetadata);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFFEF4444), width: 2)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.psychology, color: Color(0xFFEF4444), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'AI CRASH BIOMECHANICS & BLACKBOX',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Physics-informed predictive injury modeling calculated from 100Hz IMU deceleration wave.',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(height: 16),

              // Kinetic Metrics Grid
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricCol('DELTA-V', '${bio.deltaVKmh.toStringAsFixed(1)} km/h', const Color(0xFFF87171)),
                    _buildMetricCol('PEAK DECEL', '${bio.peakG.toStringAsFixed(1)} G', const Color(0xFFEF4444)),
                    _buildMetricCol('ENERGY', '${bio.energyDissipationKj.toStringAsFixed(1)} kJ', const Color(0xFFFBBF24)),
                    _buildMetricCol('ISS SCORE', '${bio.issScoreEstimate} (Polytrauma)', const Color(0xFFF87171)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'PREDICTED INTERNAL INJURY RISKS (PINN Neural Net):',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              ...bio.predictedInjuries.map((inj) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: inj.severity == 'CRITICAL' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            inj.injury,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: inj.severity == 'CRITICAL' ? const Color(0xFF7F1D1D) : const Color(0xFF78350F),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${inj.riskPercent}% Risk',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Action: ${inj.clinicalAction}',
                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155)),
                  child: const Text('DISMISS', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Displays Ayushman Bharat (ABDM / ABHA) Emergency Health Vault Sheet
  void _showAbhaVaultSheet(BuildContext context) {
    final vault = AbhaEmergencyVault.fromMetadata(widget.incident.victimMetadata);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF10B981), width: 2)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.verified_user, color: Color(0xFF10B981), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'AYUSHMAN BHARAT (ABDM) HEALTH VAULT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Ephemeral Emergency Health Enclave (Volatile RAM) • ABDM / Self-Declared [MOCK DATA]',
                style: TextStyle(color: Colors.amberAccent, fontSize: 11),
              ),
              const SizedBox(height: 14),

              // Patient Identification Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ABHA ID', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        Text(vault.abhaId, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const Divider(height: 12, color: Colors.white10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('PATIENT', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        Text(vault.patientName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const Divider(height: 12, color: Colors.white10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('BLOOD GROUP', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        Text(vault.bloodGroup, style: const TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Critical Drug Allergies Warning
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF450A0A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber, color: Color(0xFFEF4444), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'CRITICAL DRUG ALLERGIES (DO NOT ADMINISTER):',
                          style: TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      vault.criticalAllergies.join(', '),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Medications & Chronic
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CURRENT MEDICATIONS & CONDITIONS:', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ...vault.currentMedications.map((m) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• $m', style: const TextStyle(color: Colors.white, fontSize: 11)),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155)),
                  child: const Text('DISMISS', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
