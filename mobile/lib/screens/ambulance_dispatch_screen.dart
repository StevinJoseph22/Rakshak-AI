import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/incident_model.dart';
import '../services/api_client.dart';
import '../services/crash_detector_service.dart';
import '../services/incident_tracking_service.dart';
import 'intake_screen.dart';

/// Traffic segment model representing a partitioned polyline with speed-based traffic color
class TrafficSegment {
  final List<LatLng> points;
  final Color color;
  final String label;

  TrafficSegment({
    required this.points,
    required this.color,
    this.label = 'Clear',
  });
}

/// Detailed dispatch view for paramedics responding to an emergency.
/// Includes interactive FlutterMap real roadway routing (OSRM) with live traffic coloring,
/// live ambulance GPS beacon, hospital rejection/acceptance triage audit radar, and on-scene photo capture.
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

  // Real OSRM Roadway Navigation & Live Traffic State
  List<LatLng> _roadwayPoints = [];
  List<TrafficSegment> _trafficSegments = [];
  double? _roadDistanceKm;
  int? _roadDurationMinutes;
  int? _trafficDelayMinutes;
  String _trafficCondition = 'Clear';
  bool _isLoadingRoute = false;

  // Hospital Triage Matrix (Rejections & Status)
  final List<Map<String, String>> _rejections = [];
  bool _showTriageMatrix = false;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _initAmbulanceLocation();

    // Join the incident socket room via IncidentTrackingService
    IncidentTrackingService.instance.trackIncident(widget.incident.id);

    // Auto-claim the incident for this ambulance unit
    _claimIncident();

    // Start periodic ambulance GPS beacon (emits to incident socket room)
    _startTelemetryBeacon();

    // If already accepted, fetch real roadway route immediately
    if (widget.incident.acceptedHospital != null) {
      final hosp = widget.incident.acceptedHospital!;
      _fetchRoadRoute(
        LatLng(widget.incident.latitude, widget.incident.longitude),
        LatLng(hosp.latitude, hosp.longitude),
      );
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

  Future<void> _claimIncident() async {
    final result = await _apiClient.claimIncident(
      incidentId: widget.incident.id,
      ambulanceId: widget.ambulanceId,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _isClaimed = true;
        _claimMessage = 'Assigned to Unit ${widget.ambulanceId}';
      });
    } else {
      setState(() {
        _claimMessage = result.errorMessage;
      });
    }
  }

  void _startTelemetryBeacon() {
    final candidates = [
      'http://127.0.0.1:5000',
      'http://192.168.1.21:5000',
      kDefaultBackendUrl,
    ];

    for (final url in candidates) {
      try {
        final socket = io.io(
          url,
          io.OptionBuilder()
              .setTransports(['websocket'])
              .enableAutoConnect()
              .build(),
        );

        socket.onConnect((_) {
          _beaconSocket = socket;
          socket.emit('join_incident', widget.incident.id);
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
              if (hLat != null && hLng != null) {
                _fetchRoadRoute(
                  LatLng(widget.incident.latitude, widget.incident.longitude),
                  LatLng(hLat, hLng),
                );
              }
            }
          }
        });

        break;
      } catch (_) {
        continue;
      }
    }

    _telemetryTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _emitAmbulanceTelemetry();
    });
  }

  void _emitAmbulanceTelemetry() {
    if (_beaconSocket != null && _beaconSocket!.connected) {
      _beaconSocket!.emit('ambulance_location', {
        'incident_id': widget.incident.id,
        'ambulance_id': widget.ambulanceId,
        'latitude': _ambulanceLat,
        'longitude': _ambulanceLng,
        'speed_kmh': 48.5,
        'heading': 135.0,
      });
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

          Color getColorForSpeed(double speedMps) {
            if (speedMps < 4.5) {
              heavyCount++;
              return const Color(0xFFEF4444); // Red: Congested (< 16 km/h)
            } else if (speedMps < 8.5) {
              moderateCount++;
              return const Color(0xFFF59E0B); // Orange: Moderate (16-30 km/h)
            } else {
              return const Color(0xFF2563EB); // Blue: Clear Flow (> 30 km/h)
            }
          }

          if (rawSpeeds != null && rawSpeeds.length == pts.length - 1 && pts.length > 1) {
            Color currentColor = getColorForSpeed((rawSpeeds[0] as num).toDouble());
            List<LatLng> currentPts = [pts[0]];

            for (int i = 0; i < rawSpeeds.length; i++) {
              final speed = (rawSpeeds[i] as num).toDouble();
              final segColor = getColorForSpeed(speed);
              currentPts.add(pts[i + 1]);

              if (segColor != currentColor || i == rawSpeeds.length - 1) {
                segments.add(TrafficSegment(
                  points: List.from(currentPts),
                  color: currentColor,
                  label: currentColor == const Color(0xFFEF4444)
                      ? 'Congested'
                      : currentColor == const Color(0xFFF59E0B)
                          ? 'Moderate'
                          : 'Clear',
                ));
                currentColor = segColor;
                currentPts = [pts[i + 1]];
              }
            }
          } else {
            segments.add(TrafficSegment(
              points: pts,
              color: const Color(0xFF2563EB),
              label: 'Clear',
            ));
          }

          // Estimate traffic delay: urban free-flow is ~45 km/h (12.5 m/s)
          final freeFlowSecs = distMeters / 12.5;
          final diffSecs = durationSecs - freeFlowSecs;
          final delayMin = diffSecs > 60 ? (diffSecs / 60.0).round() : null;

          String condition = 'Clear Flow';
          if (heavyCount > 0) {
            condition = 'Heavy Congestion';
          } else if (moderateCount > 2) {
            condition = 'Moderate Traffic';
          }

          if (mounted) {
            setState(() {
              _roadwayPoints = pts;
              _trafficSegments = segments;
              _roadDistanceKm = distMeters / 1000.0;
              _roadDurationMinutes = (durationSecs / 60.0).round();
              _trafficDelayMinutes = delayMin;
              _trafficCondition = condition;
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
      appBar: AppBar(
        title: Text('Dispatch: ${widget.incident.id.substring(0, 8)}'),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.ambulanceId,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade900,
              ),
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

          // Trigger route fetch if accepted and points not yet loaded
          if (hospitalLocation != null && _roadwayPoints.isEmpty && !_isLoadingRoute) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fetchRoadRoute(incidentLocation, hospitalLocation!);
            });
          }

          return Column(
            children: [
              // Top Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: isAccepted ? Colors.green.shade50 : Colors.amber.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isAccepted ? Icons.check_circle : Icons.access_time,
                          color: isAccepted ? Colors.green.shade700 : Colors.amber.shade800,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAccepted ? 'DESTINATION: $hospitalName' : 'TRIAGE STATUS: BROADCASTING',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isAccepted ? Colors.green.shade900 : Colors.amber.shade900,
                                ),
                              ),
                              if (hospitalAddress.isNotEmpty)
                                Text(
                                  hospitalAddress,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        // Toggle Triage Details Button
                        IconButton(
                          icon: Icon(
                            _showTriageMatrix ? Icons.keyboard_arrow_up : Icons.info_outline,
                            color: isAccepted ? Colors.green.shade800 : Colors.amber.shade900,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() => _showTriageMatrix = !_showTriageMatrix);
                          },
                          tooltip: 'View Hospital Triage Audit',
                        ),
                      ],
                    ),

                    // Roadway Routing & Live Traffic Banner
                    if (_roadDistanceKm != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.alt_route, size: 16, color: Color(0xFF1D4ED8)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${_roadDistanceKm!.toStringAsFixed(1)} km  •  ~${_roadDurationMinutes ?? 12} mins ETA',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ),
                            if (_trafficDelayMinutes != null && _trafficDelayMinutes! > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _trafficCondition == 'Heavy Congestion'
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '+${_trafficDelayMinutes}m Traffic Delay',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: _trafficCondition == 'Heavy Congestion'
                                        ? const Color(0xFF991B1B)
                                        : const Color(0xFF92400E),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    // Expandable Triage Matrix Drawer
                    if (_showTriageMatrix) ...[
                      const Divider(height: 16),
                      const Text(
                        'HOSPITAL NETWORK RADAR (8km Triage Ring)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 4),
                      if (isAccepted)
                        Padding(
                           padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '✅ $hospitalName: Emergency Accepted & Trauma Team Ready',
                            style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                          ),
                        ),
                      if (_rejections.isNotEmpty)
                        ..._rejections.map(
                          (r) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1.5),
                            child: Text(
                              '❌ ${r['hospital_name']}: ${r['reason']}',
                              style: TextStyle(fontSize: 10.5, color: Colors.red.shade700),
                            ),
                          ),
                        )
                      else if (!isAccepted)
                        const Text(
                          '⚡ Triage signals dispatched. Listening for acceptance...',
                          style: TextStyle(fontSize: 10.5, color: Colors.amber),
                        ),
                    ],
                  ],
                ),
              ),

              // Interactive Real Roadway FlutterMap with Traffic Overlay
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
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

                        // Real OSRM Roadway Polyline Layer with Traffic Colors
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
                                  color: Colors.blue.shade700,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.directions_car,
                                  color: Colors.white,
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
                                    color: Colors.green.shade700,
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
                          ],
                        ),
                      ],
                    ),

                    // Floating Live Traffic Legend (Google Maps Style)
                    if (_trafficSegments.isNotEmpty)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTrafficDot(const Color(0xFF2563EB), 'Clear'),
                              const SizedBox(width: 8),
                              _buildTrafficDot(const Color(0xFFF59E0B), 'Moderate'),
                              const SizedBox(width: 8),
                              _buildTrafficDot(const Color(0xFFEF4444), 'Congested'),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Bottom Action Bar: Camera On-Scene & Hospital Call
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      // Capture On-Scene Photo (Phase 6 Zero-Gallery Camera Flow)
                      Expanded(
                        child: ElevatedButton.icon(
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
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Capture Scene Photo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      if (hospitalPhone.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Emergency Contact: $hospitalPhone'),
                                backgroundColor: Colors.green.shade800,
                              ),
                            );
                          },
                          icon: const Icon(Icons.phone),
                          label: const Text('Call ER'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade800,
                            side: BorderSide(color: Colors.green.shade800),
                            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
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
}
