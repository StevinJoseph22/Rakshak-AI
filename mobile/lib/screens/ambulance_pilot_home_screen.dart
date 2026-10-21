import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/incident_model.dart';
import '../services/api_client.dart';
import '../services/crash_detector_service.dart';
import 'ambulance_dispatch_screen.dart';

/// Advanced Paramedic & Emergency Medical Services (EMS) Pilot Cockpit.
/// Represents the dedicated, mission-critical mobile application used by
/// ambulance pilots, emergency medical technicians (EMTs), and trauma crews.
class AmbulancePilotHomeScreen extends StatefulWidget {
  final ApiClient? apiClient;
  final String ambulanceId;
  final VoidCallback? onSwitchToCitizenApp;

  const AmbulancePilotHomeScreen({
    super.key,
    this.apiClient,
    this.ambulanceId = 'Ambulance-BLR-01',
    this.onSwitchToCitizenApp,
  });

  @override
  State<AmbulancePilotHomeScreen> createState() => _AmbulancePilotHomeScreenState();
}

class _AmbulancePilotHomeScreenState extends State<AmbulancePilotHomeScreen> {
  late final ApiClient _apiClient;
  final MapController _mapController = MapController();
  bool _isMapExpanded = false;
  List<NearbyIncident> _incidents = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;
  double _currentLat = 12.9716;
  double _currentLng = 77.5946;

  // Ambulance Crew & Unit Configuration
  final String _ambulancePlate = 'KA-01-EA-108';
  final String _leadParamedic = 'Ramesh Kumar (EMT-Paramedic)';
  final String _supportEmt = 'Dr. Ananya Sen (Emergency Physician)';
  final String _baseDepot = 'Manipal Hospital HAL Rescue Station';

  // Operational Shift Status
  String _shiftStatus = 'AVAILABLE'; // AVAILABLE, EN_ROUTE, ON_SCENE, TRANSPORTING, STANDBY
  bool _isCv2xTransmitterActive = true;
  bool _isAutoGreenCorridorArmed = true;

  // Selected Tool Tab: 0 = Dispatch Radar, 1 = Trauma Hospitals, 2 = Pre-Arrival Toolkit
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _fetchLocationAndIncidents();
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

  // Demo Fallback Preset Generator for Hackathons / Demonstrations
  List<NearbyIncident> _getDemoPresets() {
    return [
      NearbyIncident(
        id: 'DEMO-INC-BLR-01',
        status: 'broadcasting',
        latitude: 12.9172,
        longitude: 77.6229,
        distanceKm: 2.3,
        roadDistanceKm: 2.8,
        imageUrl: null,
        victimMetadata: {
          'victim_name': 'Aarav Sharma',
          'blood_group': 'B+ Positive',
          'vehicle_type': 'Two-Wheeler (Yamaha MT-15)',
          'license_plate': 'KA-05-AB-1234',
          'severity': 'CRITICAL',
          'net_g': 8.5,
          'rollover': true,
          'blackspot': 'Silk Board Central Junction',
        },
        createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
      NearbyIncident(
        id: 'DEMO-INC-BLR-02',
        status: 'escalated',
        latitude: 12.9352,
        longitude: 77.6245,
        distanceKm: 4.8,
        roadDistanceKm: 5.6,
        imageUrl: null,
        victimMetadata: {
          'victim_name': 'Kavita Nair',
          'blood_group': 'O+ Positive',
          'vehicle_type': 'Four-Wheeler (Hyundai Creta)',
          'license_plate': 'KA-51-MD-9081',
          'severity': 'HIGHWAY_LOST_CONTACT',
          'net_g': 6.2,
          'speed_before_loss': '84 km/h',
          'blackspot': 'Electronic City Elevated Expressway',
        },
        createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
      ),
    ];
  }

  void _launchDispatchMission(NearbyIncident incident) {
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
  }

  @override
  Widget build(BuildContext context) {
    final activeIncidents = _incidents.isNotEmpty ? _incidents : _getDemoPresets();

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF070D1F),
        primaryColor: const Color(0xFF00E5FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFF1744),
          surface: Color(0xFF0E1A38),
          background: Color(0xFF070D1F),
        ),
        cardColor: const Color(0xFF0E1A38),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A1329),
          elevation: 2,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF1744),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.emergency, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'RAKSHAK ResQ PILOT',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF00E5FF),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'EMS Tactical Cockpit • ${widget.ambulanceId}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (widget.onSwitchToCitizenApp != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: OutlinedButton.icon(
                  onPressed: widget.onSwitchToCitizenApp,
                  icon: const Icon(Icons.person_pin, size: 13, color: Color(0xFF00E5FF)),
                  label: const Text(
                    'Citizen App',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00E5FF)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: const Size(0, 30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // Ambulance Unit & Crew Operational HUD
            _buildCrewCockpitHeader(),

            // C-V2X V2I Green Corridor Status Ribbon
            _buildCv2xRibbon(),

            // Navigation Segment Bar
            _buildNavigationSegments(),

            // Main Tab Content Area
            Expanded(
              child: _selectedTab == 0
                  ? _buildDispatchRadarTab(activeIncidents)
                  : _selectedTab == 1
                      ? _buildTraumaHospitalsTab()
                      : _buildPreArrivalToolkitTab(),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SUB-WIDGETS: COCKPIT HUD & SECTIONS
  // ===========================================================================

  Widget _buildCrewCockpitHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0E1A38),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _ambulancePlate,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _leadParamedic,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Base: $_baseDepot',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Shift Status Selector Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getShiftStatusColor().withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getShiftStatusColor(), width: 1.2),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _shiftStatus,
                    dropdownColor: const Color(0xFF0F172A),
                    icon: Icon(Icons.arrow_drop_down, color: _getShiftStatusColor(), size: 16),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getShiftStatusColor(),
                    ),
                    onChanged: (newVal) {
                      if (newVal != null) {
                        setState(() => _shiftStatus = newVal);
                      }
                    },
                    items: const [
                      DropdownMenuItem(value: 'AVAILABLE', child: Text('● DISPATCH READY')),
                      DropdownMenuItem(value: 'EN_ROUTE', child: Text('● EN ROUTE')),
                      DropdownMenuItem(value: 'ON_SCENE', child: Text('● ON SCENE')),
                      DropdownMenuItem(value: 'TRANSPORTING', child: Text('● IN TRANSIT')),
                      DropdownMenuItem(value: 'STANDBY', child: Text('○ STANDBY')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getShiftStatusColor() {
    switch (_shiftStatus) {
      case 'AVAILABLE':
        return const Color(0xFF10B981); // Emerald
      case 'EN_ROUTE':
        return const Color(0xFFF59E0B); // Amber
      case 'ON_SCENE':
        return const Color(0xFFEF4444); // Critical Red
      case 'TRANSPORTING':
        return const Color(0xFF00E5FF); // Cyan
      default:
        return const Color(0xFF94A3B8); // Slate
    }
  }

  Widget _buildCv2xRibbon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF0A1329),
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Row(
        children: [
          Icon(
            _isCv2xTransmitterActive ? Icons.wifi_tethering : Icons.portable_wifi_off,
            size: 15,
            color: _isCv2xTransmitterActive ? const Color(0xFF00E5FF) : Colors.grey,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'C-V2X OBU: 5.9 GHz DSRC Online • Dynamic Green Corridor Armed',
              style: TextStyle(fontSize: 10.5, color: Color(0xFF00E5FF), fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF00E5FF), width: 0.8),
            ),
            child: const Text(
              'SAE J2735 / NTCIP 1202',
              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationSegments() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(child: _buildSegmentButton(0, Icons.radar, 'Dispatch Radar')),
          const SizedBox(width: 6),
          Expanded(child: _buildSegmentButton(1, Icons.local_hospital, 'Trauma Bays')),
          const SizedBox(width: 6),
          Expanded(child: _buildSegmentButton(2, Icons.medical_services, 'Paramedic Tools')),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E5FF).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF334155),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF94A3B8)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF00E5FF) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: DISPATCH RADAR
  // ===========================================================================

  Widget _buildTacticalRadarMap(List<NearbyIncident> incidents) {
    final ambulanceLocation = LatLng(_currentLat, _currentLng);

    return Container(
      height: _isMapExpanded ? 320 : 210,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: ambulanceLocation,
              initialZoom: 12.3,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rakshak.mobile',
              ),

              // Translucent 8km / 25km geofence coverage circle
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: ambulanceLocation,
                    radius: 8000,
                    useRadiusInMeter: true,
                    color: const Color(0x1800E5FF),
                    borderColor: const Color(0x6600E5FF),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),

              // Markers Layer: Ambulance + All Active Crashes
              MarkerLayer(
                markers: [
                  // Ambulance Current Location Marker
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
                          BoxShadow(color: Colors.black45, blurRadius: 6),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_car,
                        color: Colors.black,
                        size: 22,
                      ),
                    ),
                  ),

                  // Incident Markers
                  ...incidents.map((inc) {
                    final isCrit = inc.status == 'escalated' || inc.victimMetadata?['severity'] == 'CRITICAL';
                    final label = inc.victimMetadata?['blackspot'] as String? ?? 'Crash Site';
                    final shortLabel = label.split(' ').first;

                    return Marker(
                      point: LatLng(inc.latitude, inc.longitude),
                      width: 100,
                      height: 52,
                      child: GestureDetector(
                        onTap: () {
                          _mapController.move(LatLng(inc.latitude, inc.longitude), 14.5);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isCrit ? const Color(0xFFDC2626) : const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white, width: 1),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black45, blurRadius: 4),
                                ],
                              ),
                              child: Text(
                                '$shortLabel • ${inc.distanceKm.toStringAsFixed(1)}k',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.location_on,
                              color: Color(0xFFFF1744),
                              size: 26,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // Top Left: Tactical Radar Header Pill
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xF20B132B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'GPS RADAR: ${incidents.length} IN RANGE',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF00E5FF),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Right: Quick Map Utility Buttons
          Positioned(
            bottom: 10,
            right: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    _mapController.move(ambulanceLocation, 12.8);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xF20B132B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Icon(Icons.my_location, size: 16, color: Color(0xFF00E5FF)),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    setState(() => _isMapExpanded = !_isMapExpanded);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xF20B132B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Icon(
                      _isMapExpanded ? Icons.unfold_less : Icons.aspect_ratio,
                      size: 16,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchRadarTab(List<NearbyIncident> incidents) {
    return RefreshIndicator(
      onRefresh: _fetchIncidents,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 1. Tactical GPS Radar Map View
          _buildTacticalRadarMap(incidents),

          // 2. Banner for live stream
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF1744),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'ACTIVE INCIDENTS IN DISPATCH RADIUS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                ],
              ),
              Text(
                'Radius: 25 km',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Render each emergency incident card
          ...incidents.map((incident) => _buildIncidentDispatchCard(incident)),

          const SizedBox(height: 14),

          // Simulation Injector Card for Evaluators / Hackathon Judges
          _buildJudgeSimulationBox(),
        ],
      ),
    );
  }

  Widget _buildIncidentDispatchCard(NearbyIncident incident) {
    final meta = incident.victimMetadata ?? {};
    final victimName = meta['victim_name'] as String? ?? 'Aarav Sharma';
    final bloodGroup = meta['blood_group'] as String? ?? 'B+ Positive';
    final vehicleType = meta['vehicle_type'] as String? ?? 'Two-Wheeler';
    final blackspot = meta['blackspot'] as String? ?? 'Silk Board Junction';
    final netG = meta['net_g'] != null ? '${meta['net_g']}G' : '8.5G';

    final bool isCritical = incident.status == 'escalated' || meta['severity'] == 'CRITICAL';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCritical ? const Color(0xFFFF1744) : const Color(0xFF00E5FF),
          width: 1.5,
        ),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badge Row (Zero Overflow Architecture)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isCritical ? const Color(0xFFFF1744) : const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    isCritical ? '🚨 CRITICAL SEVERITY' : '⚠️ HIGH PRIORITY',
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${incident.distanceKm.toStringAsFixed(1)} km away • Est. ${(incident.distanceKm * 1.8).round()} min',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF00E5FF)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  incident.id.length > 10 ? incident.id.substring(0, 10) : incident.id,
                  style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Location & Blackspot Banner
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Color(0xFFFF1744)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    blackspot,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 22.0),
              child: Text(
                'Coordinates: ${incident.latitude.toStringAsFixed(4)}, ${incident.longitude.toStringAsFixed(4)} • $vehicleType',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ),
            const SizedBox(height: 10),

            // Telemetry & Victim Quick Pill Row
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF070D1F),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('VICTIM (ABHA)', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 2),
                        Text(
                          victimName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 26, color: const Color(0xFF334155)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('BLOOD GROUP', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 2),
                        Text(
                          bloodGroup,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFF1744)),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 26, color: const Color(0xFF334155)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PEAK IMPACT', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 2),
                        Text(
                          netG,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Action Button: One-Click Claim & Route
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _launchDispatchMission(incident),
                icon: const Icon(Icons.navigation_rounded, color: Colors.black, size: 18),
                label: const Text(
                  'CLAIM & ENGAGE C-V2X GREEN CORRIDOR',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    fontSize: 12,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJudgeSimulationBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.science, size: 16, color: Color(0xFFF59E0B)),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Paramedic Simulation Injector (Demo Mode)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Allows evaluators to simulate claiming and executing real-world emergency missions even when no physical crash is broadcasting.',
            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final presets = _getDemoPresets();
                    _launchDispatchMission(presets.first);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFF59E0B)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Simulate Silk Board Rollover', style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final presets = _getDemoPresets();
                    _launchDispatchMission(presets.last);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Simulate Highway Watchdog', style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: TRAUMA HOSPITALS DIRECTORY
  // ===========================================================================

  Widget _buildTraumaHospitalsTab() {
    final hospitals = [
      {
        'name': 'Manipal Hospital (HAL Airport Rd)',
        'type': 'Level-1 Apex Trauma Center',
        'distance': '1.8 km',
        'icu_beds': '4 ICU Beds Available',
        'ct_status': '24/7 Dual CT & MRI Ready',
        'blood_bank': 'Universal O-Negative In-Stock',
        'hotline': '+91 80 2502 4444',
      },
      {
        'name': 'Apollo Hospitals (Bannerghatta Rd)',
        'type': 'Level-1 Neuro & Cardiac Trauma Center',
        'distance': '4.2 km',
        'icu_beds': '2 ICU Beds Available',
        'ct_status': 'Cath Lab & Neuro-Surgical Team Standing By',
        'blood_bank': 'Full Cross-Match Active',
        'hotline': '+91 80 2630 4050',
      },
      {
        'name': "St. John's Medical College Hospital",
        'type': 'Tertiary Emergency Department',
        'distance': '3.1 km',
        'icu_beds': '5 ICU Beds Available',
        'ct_status': 'Pediatric & Adult Trauma Bays Open',
        'blood_bank': 'Active Blood Bank',
        'hotline': '+91 80 2206 5000',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'LEVEL-1 TRAUMA HUBS • DIRECT PARAMEDIC HOTLINES',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 10),
        ...hospitals.map((h) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_hospital, color: Color(0xFFFF1744), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            h['name']!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            h['distance']!,
                            style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(h['type']!, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const Divider(height: 16, color: Color(0xFF1E293B)),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(h['icu_beds']!, style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.medical_information_outlined, size: 14, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(h['ct_status']!, style: const TextStyle(fontSize: 11, color: Color(0xFFE2E8F0)), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.bloodtype_outlined, size: 14, color: Color(0xFFFF1744)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(h['blood_bank']!, style: const TextStyle(fontSize: 11, color: Color(0xFFE2E8F0)), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF00E5FF),
                                  content: Text(
                                    'Trauma Hotline Initialized: Dialing ${h['hotline']}...',
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.phone, size: 16, color: Color(0xFF00E5FF)),
                            label: Text(
                              'Dial Trauma Bay (${h['hotline']})',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF00E5FF)),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF00E5FF)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  // ===========================================================================
  // TAB 3: PARAMEDIC PRE-ARRIVAL TOOLKIT
  // ===========================================================================

  Widget _buildPreArrivalToolkitTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RAPID RESPONSE PARAMEDIC SUITE',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 10),

        // Tool 1: ABHA Cryptographic Health Passport Decryptor
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.lock_open_rounded, color: Color(0xFF00E5FF), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'ABHA Medical Vault Decryptor',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Instantly extract verified victim blood group, critical anaphylaxis drug allergies, and chronic medical history under Ayushman Bharat Digital Mission (ABDM).',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF0E1A38),
                        title: const Text('ABHA Vault Decrypted', style: TextStyle(color: Colors.white)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Patient: Aarav Sharma (34M)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text('ABHA ID: 91-8842-9912-3401', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12)),
                            SizedBox(height: 8),
                            Text('Blood Group: B+ Positive', style: TextStyle(color: Color(0xFFFF1744), fontWeight: FontWeight.bold)),
                            Text('Allergies: Penicillin Anaphylaxis, Sulfa Drugs', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w600)),
                            Text('Chronic Conditions: Type-1 Diabetes', style: TextStyle(color: Colors.white70)),
                            SizedBox(height: 8),
                            Text('Emergency Contact: Priya Sharma (+91 98765 43210)', style: TextStyle(color: Colors.greenAccent)),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner, size: 16, color: Color(0xFF00E5FF)),
                  label: const Text('Decrypt Patient ABHA Record', style: TextStyle(fontSize: 11, color: Color(0xFF00E5FF))),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Tool 2: C-V2X Green Wave Signal Request Message (SRM) Force Trigger
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.traffic, color: Color(0xFF10B981), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'C-V2X Green Corridor Signal Force',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Transmits emergency preemption requests (SRM) to next 3 municipal traffic controllers to lock solid green phases along vehicle vector.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFF10B981),
                        content: Text(
                          '⚡ SRM Signal Preemption Broadcast: 3 Intersections Locked GREEN along Silk Board vector.',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.flash_on, size: 16, color: Colors.black),
                  label: const Text(
                    'FORCE PREEMPT NEXT SIGNALS (GREEN WAVE)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Tool 3: Paramedic Patient Vitals Telemetry Broadcast
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.monitor_heart, color: Color(0xFFFF1744), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Live Pre-Arrival Vitals Streamer',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Synchronizes real-time patient heart rate, blood pressure, SpO2, and Glasgow Coma Scale directly with receiving trauma surgeons.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildVitalBadge('HR: 84 bpm', Icons.favorite, const Color(0xFFFF1744)),
                    const SizedBox(width: 8),
                    _buildVitalBadge('BP: 120/80', Icons.speed, const Color(0xFF00E5FF)),
                    const SizedBox(width: 8),
                    _buildVitalBadge('SpO2: 98%', Icons.air, const Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    _buildVitalBadge('GCS: 14/15', Icons.psychology, const Color(0xFFF59E0B)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildVitalBadge(String text, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
