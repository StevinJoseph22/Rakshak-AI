import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/hospital_model.dart';
import '../services/crash_detector_service.dart';
import '../services/hospital_directory_service.dart';

class HospitalRadarScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const HospitalRadarScreen({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<HospitalRadarScreen> createState() => _HospitalRadarScreenState();
}

class _HospitalRadarScreenState extends State<HospitalRadarScreen> {
  double _userLat = 13.0130; // Default to Banaswadi center
  double _userLng = 77.6490;
  bool _filterWithin5Km = true;
  HospitalSearchResult? _searchResult;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _resolveLocation();
  }

  void _resolveLocation() {
    setState(() => _isLoading = true);

    // Pick live coordinates if available, otherwise fallback to Banaswadi
    final lastLat = CrashDetectorService.instance.lastKnownLatitude;
    final lastLng = CrashDetectorService.instance.lastKnownLongitude;

    if (widget.initialLat != null && widget.initialLng != null) {
      _userLat = widget.initialLat!;
      _userLng = widget.initialLng!;
    } else if (lastLat != 0.0 && lastLng != 0.0) {
      _userLat = lastLat;
      _userLng = lastLng;
    } else {
      // Banaswadi, Bengaluru
      _userLat = 13.0130;
      _userLng = 77.6490;
    }

    _refreshHospitalSearch();
  }

  void _refreshHospitalSearch() {
    final result = HospitalDirectoryService.instance.searchNearbyHospitals(
      userLat: _userLat,
      userLng: _userLng,
      maxRadiusKm: 5.0,
    );

    setState(() {
      _searchResult = result;
      _isLoading = false;
    });
  }

  String _getLocationLocalityLabel() {
    // If coordinates match Banaswadi
    if ((_userLat - 13.013).abs() < 0.05 && (_userLng - 77.649).abs() < 0.05) {
      return 'Banaswadi / Kalyan Nagar, Bengaluru';
    } else if ((_userLat - 12.971).abs() < 0.05 && (_userLng - 77.594).abs() < 0.05) {
      return 'Central Bengaluru (MG Road)';
    } else {
      return 'GPS: ${_userLat.toStringAsFixed(4)}, ${_userLng.toStringAsFixed(4)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = _searchResult;
    final displayList = _filterWithin5Km
        ? (res != null ? res.hospitals : [])
        : HospitalDirectoryService.instance.allHospitals;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.radar, color: Color(0xFFDC2626), size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nearby Trauma Centers Radar',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '5km Radius Emergency Geo-Search & Navigation',
                    style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFDC2626)))
          : Column(
              children: [
                // Top Live Location Bar
                _buildLocationBar(),

                // Filter Pill Selector (Within 5 km vs All 26)
                _buildFilterBar(res),

                // Main Hospitals List
                Expanded(
                  child: displayList.isEmpty && res != null && !res.isWithinRadius
                      ? _buildNoHospitalsWithin5KmState(res)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          itemCount: displayList.length + (_filterWithin5Km && res != null && !res.isWithinRadius ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_filterWithin5Km && res != null && !res.isWithinRadius && index == 0) {
                              return _buildFallbackAlertBanner(res);
                            }
                            final hospIndex = (_filterWithin5Km && res != null && !res.isWithinRadius) ? index - 1 : index;
                            final hosp = displayList[hospIndex];
                            return _buildHospitalCard(hosp);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildLocationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location, color: Color(0xFF38BDF8), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CURRENT GPS RADAR FIX', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                Text(
                  _getLocationLocalityLabel(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF38BDF8), size: 20),
            tooltip: 'Re-scan GPS Location',
            onPressed: _resolveLocation,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(HospitalSearchResult? res) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ChoiceChip(
              label: Text(
                'Within 5.0 km (${res != null && res.isWithinRadius ? res.hospitals.length : 0} Found)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: _filterWithin5Km ? FontWeight.bold : FontWeight.normal,
                  color: _filterWithin5Km ? Colors.white : const Color(0xFF94A3B8),
                ),
              ),
              selected: _filterWithin5Km,
              selectedColor: const Color(0xFFDC2626),
              backgroundColor: const Color(0xFF1E293B),
              side: BorderSide(color: _filterWithin5Km ? const Color(0xFFDC2626) : const Color(0xFF334155)),
              onSelected: (val) {
                if (val) setState(() => _filterWithin5Km = true);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ChoiceChip(
              label: Text(
                'All Hospitals (${HospitalDirectoryService.instance.allHospitals.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: !_filterWithin5Km ? FontWeight.bold : FontWeight.normal,
                  color: !_filterWithin5Km ? Colors.white : const Color(0xFF94A3B8),
                ),
              ),
              selected: !_filterWithin5Km,
              selectedColor: const Color(0xFF0284C7),
              backgroundColor: const Color(0xFF1E293B),
              side: BorderSide(color: !_filterWithin5Km ? const Color(0xFF0284C7) : const Color(0xFF334155)),
              onSelected: (val) {
                if (val) setState(() => _filterWithin5Km = false);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackAlertBanner(HospitalSearchResult res) {
    final next = res.nearestFallback;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF451A03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 18),
              SizedBox(width: 6),
              Text(
                'No Trauma Hub within 5.0 km',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFCD34D)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            next != null
                ? 'No certified Level-1 emergency trauma center was located within 5 km of ${_getLocationLocalityLabel()}. Showing nearest next available emergency facility: ${next.name} (${next.distanceKm} km away).'
                : 'Searching all extended emergency networks across Bengaluru...',
            style: const TextStyle(fontSize: 11, color: Color(0xFFFEF3C7)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoHospitalsWithin5KmState(HospitalSearchResult res) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_rounded, size: 48, color: Color(0xFFF59E0B)),
            const SizedBox(height: 12),
            const Text(
              'No Hospital Found within 5 km',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'No facility is currently listed within 5.0 km of your coordinates. Nearest emergency center is ${res.nearestFallback?.name ?? "Regional Apex Center"} (${res.nearestFallback?.distanceKm ?? "X"} km away).',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() => _filterWithin5Km = false),
              icon: const Icon(Icons.list, color: Colors.white),
              label: const Text('View All Hospitals in Greater Bengaluru', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHospitalCard(HospitalFacility hosp) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      color: const Color(0xFF1E293B),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Hospital Name & Distance Pill
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_hospital, color: Color(0xFFDC2626), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hosp.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hosp.traumaTier,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF38BDF8)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${hosp.distanceKm ?? 0.0} km',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8)),
                      ),
                      Text(
                        '~${hosp.estimatedDriveMinutes} min',
                        style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Address
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 13, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    hosp.address,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 16, color: Color(0xFF334155)),

            // Medical Capability Indicators
            Row(
              children: [
                _buildCapabilityBadge(Icons.hotel, '${hosp.icuBedsAvailable} ICU Beds Open', const Color(0xFF10B981)),
                const SizedBox(width: 6),
                _buildCapabilityBadge(Icons.biotech, '24/7 CT & MRI Ready', const Color(0xFF38BDF8)),
              ],
            ),
            const SizedBox(height: 12),

            // Action Buttons: Real Directions & Call Hotline
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: () => _openMapsAndDirections(hosp),
                    icon: const Icon(Icons.directions, color: Colors.white, size: 16),
                    label: const Text(
                      'MAPS & DIRECTIONS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () => _callHotline(hosp.phone),
                    icon: const Icon(Icons.phone, color: Color(0xFF38BDF8), size: 15),
                    label: const Text(
                      'CALL DESK',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF38BDF8)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapabilityBadge(IconData icon, String text, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMapsAndDirections(HospitalFacility hosp) async {
    final launched = await HospitalDirectoryService.instance.launchMapsDirections(
      hosp.latitude,
      hosp.longitude,
      hosp.name,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Navigating to ${hosp.name} (${hosp.latitude}, ${hosp.longitude})...'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _callHotline(String phone) async {
    final dialed = await HospitalDirectoryService.instance.callHotline(phone);
    if (!dialed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Emergency Casualty Phone: $phone'),
          backgroundColor: const Color(0xFF0284C7),
        ),
      );
    }
  }
}
