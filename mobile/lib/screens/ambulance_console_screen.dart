import 'dart:async';
import 'package:flutter/material.dart';
import '../models/incident_model.dart';
import '../services/api_client.dart';
import '../services/crash_detector_service.dart';
import 'ambulance_dispatch_screen.dart';

/// Ambulance Console for EMS crews and paramedics.
/// Discovers nearby active emergencies in 'broadcasting' or 'escalated' state,
/// displays proximity distance, and allows paramedics to claim and navigate to scenes.
class AmbulanceConsoleScreen extends StatefulWidget {
  final ApiClient? apiClient;
  final String ambulanceId;

  const AmbulanceConsoleScreen({
    super.key,
    this.apiClient,
    this.ambulanceId = 'Ambulance-BLR-01',
  });

  @override
  State<AmbulanceConsoleScreen> createState() => _AmbulanceConsoleScreenState();
}

class _AmbulanceConsoleScreenState extends State<AmbulanceConsoleScreen> {
  late final ApiClient _apiClient;
  List<NearbyIncident> _incidents = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;
  double _currentLat = 12.9716;
  double _currentLng = 77.5946;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _fetchLocationAndIncidents();
    // Auto-refresh nearby incident feed every 6 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _fetchIncidents();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _fetchLocationAndIncidents() {
    // Read cached or current device location from CrashDetectorService
    final lat = CrashDetectorService.instance.lastKnownLatitude;
    final lng = CrashDetectorService.instance.lastKnownLongitude;
    if (lat != 0.0 && lng != 0.0) {
      _currentLat = lat;
      _currentLng = lng;
    }
    _fetchIncidents();
  }

  Future<void> _fetchIncidents() async {
    final result = await _apiClient.fetchNearbyIncidents(
      latitude: _currentLat,
      longitude: _currentLng,
      radiusKm: 25.0,
    );

    if (!mounted) return;

    if (result.isSuccess && result.data != null) {
      setState(() {
        _incidents = result.data!;
        _isLoading = false;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoading = false;
        if (_incidents.isEmpty) {
          _errorMessage = result.errorMessage ?? 'Unable to connect to dispatch server';
        }
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'broadcasting':
        return Colors.orange;
      case 'escalated':
        return Colors.deepOrange;
      case 'accepted':
        return Colors.green;
      case 'unmatched':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.emergency, color: Colors.redAccent),
            const SizedBox(width: 8),
            const Text('Ambulance Console'),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300),
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
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchIncidents,
        child: _isLoading && _incidents.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null && _incidents.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() => _isLoading = true);
                              _fetchIncidents();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry Connection'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _incidents.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'No Active Emergencies Nearby',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ambulance Unit ${widget.ambulanceId} is on standby. Monitoring within 25 km radius...',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _incidents.length,
                        itemBuilder: (context, index) {
                          final incident = _incidents[index];
                          final isClaimedByMe = incident.ambulanceId == widget.ambulanceId;
                          final isClaimedByOther = incident.ambulanceId != null && !isClaimedByMe;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isClaimedByMe
                                    ? Colors.green.shade400
                                    : Colors.grey.shade300,
                                width: isClaimedByMe ? 2 : 1,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AmbulanceDispatchScreen(
                                      incident: incident,
                                      ambulanceId: widget.ambulanceId,
                                      apiClient: _apiClient,
                                    ),
                                  ),
                                ).then((_) => _fetchIncidents());
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(incident.status).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            incident.status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: _getStatusColor(incident.status),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${incident.distanceKm.toStringAsFixed(1)} km away',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blueGrey,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (isClaimedByMe)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Assigned to You',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade800,
                                              ),
                                            ),
                                          )
                                        else if (isClaimedByOther)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Claimed: ${incident.ambulanceId}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange.shade900,
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Unclaimed',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Emergency ID: ${incident.id.substring(0, 8)}...',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'GPS: ${incident.latitude.toStringAsFixed(4)}, ${incident.longitude.toStringAsFixed(4)}',
                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                    ),
                                    if (incident.acceptedHospital != null) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.local_hospital, size: 16, color: Colors.green),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Accepted by: ${incident.acceptedHospital!.name}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (incident.imageUrl != null)
                                          Row(
                                            children: const [
                                              Icon(Icons.photo_camera, size: 16, color: Colors.blue),
                                              SizedBox(width: 4),
                                              Text('Photo Available', style: TextStyle(fontSize: 12, color: Colors.blue)),
                                            ],
                                          )
                                        else
                                          Row(
                                            children: const [
                                              Icon(Icons.add_a_photo, size: 16, color: Colors.amber),
                                              SizedBox(width: 4),
                                              Text('No Photo Attached', style: TextStyle(fontSize: 12, color: Colors.amber)),
                                            ],
                                          ),
                                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
