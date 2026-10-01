import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'config/lock_screen_config.dart';
import 'models/emergency_contact_model.dart';
import 'screens/ambulance_console_screen.dart';
import 'screens/emergency_contacts_screen.dart';
import 'screens/intake_screen.dart';
import 'screens/locked_screen_alert_screen.dart';
import 'screens/permission_rationale_screen.dart';
import 'screens/simulated_lock_screen.dart';
import 'services/crash_detector_service.dart';
import 'services/crash_event_service.dart';
import 'services/emergency_contact_service.dart';
import 'services/emergency_sms_service.dart';
import 'services/lock_screen_service.dart';

void main() {
  runApp(const RakshakApp());
}

class RakshakApp extends StatelessWidget {
  const RakshakApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: RakshakApp.navigatorKey,
      title: 'Rakshak-AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
        useMaterial3: true,
      ),
      home: const CrashDetectionScreen(),
    );
  }
}

class CrashDetectionScreen extends StatefulWidget {
  const CrashDetectionScreen({super.key});

  @override
  State<CrashDetectionScreen> createState() => _CrashDetectionScreenState();
}

class _CrashDetectionScreenState extends State<CrashDetectionScreen> {
  // Phase 0 Guard State
  bool _isMonitoring = true;
  bool _isTestMode = false;

  // Phase 2 Simulation Harness State
  double _simulatedDecelerationG = 6.5;
  double _simulatedSpeedDropKmh = 65.0;
  bool _useLiveDeviceLocation = true;

  // Sensor Diagnostics
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<CrashEvent>? _crashSubscription;

  double _accelX = 0.0, _accelY = 0.0, _accelZ = 0.0;
  double _gyroX = 0.0, _gyroY = 0.0, _gyroZ = 0.0;
  bool _hasReceivedSensorData = false;

  EmergencyContact? _primaryContact;
  int _contactCount = 0;

  @override
  void initState() {
    super.initState();
    EmergencySmsService.navigatorKey = RakshakApp.navigatorKey;
    _loadEmergencyContacts();
    _initSensors();
    _initCrashListener();
    if (_isMonitoring) {
      CrashDetectorService.instance.start();
    }
  }

  Future<void> _loadEmergencyContacts() async {
    final contacts = await EmergencyContactService.instance.getContacts();
    final primary = await EmergencyContactService.instance.getPrimaryContact();
    if (mounted) {
      setState(() {
        _contactCount = contacts.length;
        _primaryContact = primary;
      });
    }
  }

  void _initSensors() {
    try {
      _accelSubscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          if (mounted && _isMonitoring) {
            setState(() {
              _accelX = event.x;
              _accelY = event.y;
              _accelZ = event.z;
              _hasReceivedSensorData = true;
            });
            // Feed live accelerometer stream to CrashDetectorService without opening a second subscription
            CrashDetectorService.instance.processAccelerometer(event);
          }
        },
        onError: (_) {
          // Gracefully ignore missing hardware sensors on some emulators
        },
      );

      _gyroSubscription = gyroscopeEventStream().listen(
        (GyroscopeEvent event) {
          if (mounted && _isMonitoring) {
            setState(() {
              _gyroX = event.x;
              _gyroY = event.y;
              _gyroZ = event.z;
              _hasReceivedSensorData = true;
            });
            // Feed live gyroscope stream to CrashDetectorService without opening a second subscription
            CrashDetectorService.instance.processGyroscope(event);
          }
        },
        onError: (_) {
          // Gracefully ignore missing hardware sensors on some emulators
        },
      );
    } catch (_) {
      // Hardware sensors unavailable
    }
  }

  void _initCrashListener() {
    _crashSubscription =
        CrashEventService.instance.onCrashDetected.listen((CrashEvent event) async {
      if (!mounted) return;

      if (kUseRealFullScreenIntent) {
        // Mode A: Real Android USE_FULL_SCREEN_INTENT
        final hasPermission = await LockScreenService.instance.canUseFullScreenIntent();
        if (!mounted) return;

        if (hasPermission) {
          await LockScreenService.instance.triggerRealFullScreenAlert(event);
          await LockScreenService.instance.enableLockScreenDisplay();
          if (!mounted) return;
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PermissionRationaleScreen()),
          );
          return;
        }
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => LockedScreenAlertScreen(crashEvent: event),
        ),
      );
    });
  }

  void _openSimulatedLockScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SimulatedLockScreen(),
      ),
    );
  }

  @override
  void dispose() {
    CrashDetectorService.instance.stop();
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _crashSubscription?.cancel();
    super.dispose();
  }

  void _toggleMonitoring() {
    if (!_isMonitoring) {
      final hasContacts = EmergencyContactService.instance.hasContactsSync;
      if (!hasContacts) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Emergency Contacts Required'),
              content: const Text(
                'Rakshak-AI Crash Guard requires at least one registered emergency contact to dispatch automated SMS alerts during an impact.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const EmergencyContactsScreen(),
                      ),
                    ).then((_) => _loadEmergencyContacts());
                  },
                  child: const Text('Set Up Contacts'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }

    setState(() {
      _isMonitoring = !_isMonitoring;
      if (_isMonitoring) {
        CrashDetectorService.instance.start();
      } else {
        CrashDetectorService.instance.stop();
      }
    });
  }

  void _triggerSimulatedCrash() {
    EmergencySmsService.instance.resetAlertHistory();
    CrashEventService.instance.beginNewIncidentDispatch();

    double lat = 12.9716;
    double lng = 77.5946;

    if (_useLiveDeviceLocation) {
      lat = CrashDetectorService.instance.lastKnownLatitude;
      lng = CrashDetectorService.instance.lastKnownLongitude;
    }

    final event = CrashEvent(
      timestamp: DateTime.now(),
      decelerationG: _simulatedDecelerationG,
      speedDropKmh: _simulatedSpeedDropKmh,
      source: _useLiveDeviceLocation ? 'live_device_gps' : 'simulation_harness',
      latitude: lat,
      longitude: lng,
    );

    CrashEventService.instance.triggerCrash(event);
  }

  void _triggerManualSosAlert() {
    EmergencySmsService.instance.resetAlertHistory();
    CrashEventService.instance.beginNewIncidentDispatch();

    final event = CrashEvent(
      timestamp: DateTime.now(),
      decelerationG: 8.0,
      speedDropKmh: 60.0,
      source: 'manual_sos',
      latitude: CrashDetectorService.instance.lastKnownLatitude,
      longitude: CrashDetectorService.instance.lastKnownLongitude,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LockedScreenAlertScreen(crashEvent: event),
      ),
    );
  }

  int _selectedNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (_selectedNavIndex == 1) {
      return Scaffold(
        body: const AmbulanceConsoleScreen(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedNavIndex,
          onTap: (index) {
            setState(() {
              _selectedNavIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.shield),
              label: 'Bystander Mode',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emergency),
              label: 'Ambulance Mode',
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rakshak-AI Guard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.quick_contacts_dialer_rounded, color: Colors.blueAccent),
            tooltip: 'Emergency Contacts & Profile',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const EmergencyContactsScreen(),
                ),
              );
              _loadEmergencyContacts();
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              avatar: Icon(
                _isTestMode ? Icons.shield_outlined : Icons.science_outlined,
                size: 16,
                color: _isTestMode ? Colors.white : Colors.amber.shade900,
              ),
              label: Text(
                _isTestMode ? 'Live Guard' : 'Test Lab',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _isTestMode ? Colors.white : Colors.amber.shade900,
                ),
              ),
              backgroundColor: _isTestMode ? Colors.red.shade700 : Colors.amber.shade100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onPressed: () {
                setState(() {
                  _isTestMode = !_isTestMode;
                });
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: <Widget>[
            // Phase 0: Guard Status Indicator
            Icon(
              _isMonitoring ? Icons.shield : Icons.shield_outlined,
              size: 80,
              color: _isMonitoring ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _isMonitoring
                  ? 'Crash Guard Active: Monitoring Telemetry'
                  : 'Monitoring Paused',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const EmergencyContactsScreen(),
                  ),
                );
                _loadEmergencyContacts();
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _contactCount > 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _contactCount > 0 ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _contactCount > 0 ? Icons.check_circle : Icons.warning_amber_rounded,
                      size: 14,
                      color: _contactCount > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _contactCount > 0
                          ? 'SOS Contact: ${_primaryContact?.name ?? "Priya Sharma"} (${_primaryContact?.phone ?? "+919876543210"})'
                          : 'No Emergency Contacts Configured — Tap to Setup',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _contactCount > 0 ? const Color(0xFF166534) : const Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: _contactCount > 0 ? const Color(0xFF166534) : const Color(0xFF991B1B),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Real-time IMU sensor monitoring & crash simulation engine active.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _toggleMonitoring,
              icon: Icon(_isMonitoring ? Icons.pause : Icons.play_arrow),
              label: Text(_isMonitoring ? 'Pause Guard' : 'Activate Guard'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Segmented Mode Selector
            _buildModeSelector(),
            const SizedBox(height: 14),

            if (!_isTestMode) ...[
              // Production Presentation View
              _buildProfessionalTelemetryCard(context),
              const SizedBox(height: 14),
              _buildEmergencyQuickActions(context),
              const SizedBox(height: 14),
              _buildPlatformTrustCard(context),
              const SizedBox(height: 14),
              _buildTestLabPromptCard(context),
            ] else ...[
              // Demo / Test Lab Simulation View
              _buildTestLabBanner(context),
              const SizedBox(height: 14),
              _buildLiveDiagnosticsCard(context),
              const SizedBox(height: 16),
              _buildSimulationHarnessCard(context),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: (index) {
          setState(() {
            _selectedNavIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shield),
            label: 'Bystander Mode',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emergency),
            label: 'Ambulance Mode',
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // UI HELPER BUILDERS: PRESENTATION-READY LIVE GUARD & TEST LAB
  // ===========================================================================

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _isTestMode = false),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_isTestMode ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: !_isTestMode
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield,
                        size: 16,
                        color: !_isTestMode ? Colors.green.shade700 : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Live Guard',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: !_isTestMode ? Colors.green.shade900 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _isTestMode = true),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _isTestMode ? Colors.amber.shade700 : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _isTestMode
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.science,
                        size: 16,
                        color: _isTestMode ? Colors.white : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Test Lab',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _isTestMode ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalTelemetryCard(BuildContext context) {
    final lat = CrashDetectorService.instance.lastKnownLatitude;
    final lng = CrashDetectorService.instance.lastKnownLongitude;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.speed_rounded, color: Colors.green.shade700, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Protection Telemetry',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        _isMonitoring ? 'Continuous IMU & GPS Analysis Active' : 'Protection Paused',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isMonitoring ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isMonitoring ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
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
                          color: _isMonitoring ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isMonitoring ? 'ONLINE' : 'PAUSED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _isMonitoring ? const Color(0xFF166534) : const Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTelemetryTile(
                    icon: Icons.navigation_rounded,
                    title: 'Speed Monitor',
                    value: _isMonitoring ? '0.0 km/h' : '--',
                    subtext: 'Auto Speed-Drop Sync',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTelemetryTile(
                    icon: Icons.psychology_rounded,
                    title: 'AI Classifier',
                    value: 'TFLite 1D-CNN',
                    subtext: 'Online (Secondary)',
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildTelemetryTile(
                    icon: Icons.filter_alt_rounded,
                    title: 'Pothole Filter',
                    value: 'Active (<4.0G)',
                    subtext: 'Road Noise Rejection',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTelemetryTile(
                    icon: Icons.pin_drop_rounded,
                    title: 'GPS Position',
                    value: 'Fix Acquired',
                    subtext: '${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}',
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryTile({
    required IconData icon,
    required String title,
    required String value,
    required String subtext,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color.shade900),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyQuickActions(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _triggerManualSosAlert,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade700, Colors.red.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sos_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ONE-TOUCH EMERGENCY SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tap if you are in distress to alert ambulance & family',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white70),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const IntakeScreen()),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.camera_alt_rounded, color: Colors.blue.shade700, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Report Accident as Bystander',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Witnessed a crash? Stream live photo to hospital triage',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.blue.shade400),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformTrustCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Text(
                'Rakshak Safety Guarantees',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildTrustItem(
            icon: Icons.memory,
            title: 'Zero-Gallery Privacy',
            description: 'Incident photos stream into backend RAM, zero local disk or gallery storage.',
          ),
          const SizedBox(height: 8),
          _buildTrustItem(
            icon: Icons.sms_outlined,
            title: 'Native SIM Peer-to-Peer SMS',
            description: 'Direct SMS to family via device SIM; immune to bulk gateway delays & DLT locks.',
          ),
          const SizedBox(height: 8),
          _buildTrustItem(
            icon: Icons.local_hospital_outlined,
            title: 'Golden-Hour Spatial Allocation',
            description: 'Instant PostGIS multi-agency routing to nearest Level-1 emergency department.',
          ),
        ],
      ),
    );
  }

  Widget _buildTrustItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.green.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              Text(
                description,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTestLabPromptCard(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _isTestMode = true),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50.withOpacity(0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.science_rounded, color: Colors.amber.shade900, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Demo & Crash Simulation Lab',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  Text(
                    'Presenting to judges? Tap to open IMU diagnostics & crash triggers.',
                    style: TextStyle(color: Colors.amber.shade800, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.amber.shade800),
          ],
        ),
      ),
    );
  }

  Widget _buildTestLabBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade400),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TEST & SIMULATION LAB ACTIVE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.amber.shade900,
                  ),
                ),
                Text(
                  'Showing raw IMU telemetry & impact triggers for evaluation.',
                  style: TextStyle(fontSize: 10, color: Colors.amber.shade900),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _isTestMode = false),
            child: const Text('Exit Lab', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveDiagnosticsCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sensors, color: Colors.blueAccent),
                const SizedBox(width: 8),
                Text(
                  'Live IMU Sensor Diagnostics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_hasReceivedSensorData)
              const Text(
                'Awaiting sensor events (move emulator or physical device)...',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              )
            else ...[
              Text(
                'Accelerometer (m/s²):',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 4),
              Text(
                'X: ${_accelX.toStringAsFixed(2)}   Y: ${_accelY.toStringAsFixed(2)}   Z: ${_accelZ.toStringAsFixed(2)}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'Gyroscope (rad/s):',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 4),
              Text(
                'X: ${_gyroX.toStringAsFixed(2)}   Y: ${_gyroY.toStringAsFixed(2)}   Z: ${_gyroZ.toStringAsFixed(2)}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSimulationHarnessCard(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.amber.shade400),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Colors.amber.shade900),
                const SizedBox(width: 8),
                Text(
                  'Crash Simulation Harness',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Simulate extreme impact telemetry parameters to test emergency SOS & dispatch trigger flow.',
              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Deceleration:', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${_simulatedDecelerationG.toStringAsFixed(1)} G',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            Slider(
              value: _simulatedDecelerationG,
              min: 0.0,
              max: 10.0,
              divisions: 100,
              activeColor: Colors.redAccent,
              label: '${_simulatedDecelerationG.toStringAsFixed(1)} G',
              onChanged: (val) {
                setState(() {
                  _simulatedDecelerationG = val;
                });
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Speed Drop:', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${_simulatedSpeedDropKmh.toStringAsFixed(0)} km/h',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            Slider(
              value: _simulatedSpeedDropKmh,
              min: 0.0,
              max: 150.0,
              divisions: 150,
              activeColor: Colors.deepOrange,
              label: '${_simulatedSpeedDropKmh.toStringAsFixed(0)} km/h',
              onChanged: (val) {
                setState(() {
                  _simulatedSpeedDropKmh = val;
                });
              },
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.my_location, size: 18, color: Colors.blue.shade700),
                          const SizedBox(width: 6),
                          Text(
                            'Use Phone Live GPS',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _useLiveDeviceLocation,
                        activeTrackColor: Colors.blue.shade700,
                        onChanged: (val) {
                          setState(() {
                            _useLiveDeviceLocation = val;
                          });
                        },
                      ),
                    ],
                  ),
                  Text(
                    _useLiveDeviceLocation
                        ? 'Device GPS: ${CrashDetectorService.instance.lastKnownLatitude.toStringAsFixed(5)}, ${CrashDetectorService.instance.lastKnownLongitude.toStringAsFixed(5)}'
                        : 'Demo Preset: 12.9716, 77.5946 (Bengaluru seeded hospitals)',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blueGrey.shade800,
                      fontFamily: _useLiveDeviceLocation ? 'monospace' : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _triggerSimulatedCrash,
                icon: const Icon(Icons.flash_on, color: Colors.white),
                label: const Text(
                  'TRIGGER IMPACT SIGNATURE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.security, size: 18, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text(
                  'Phase 4: Bystander Override',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.blueGrey.shade800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: kUseRealFullScreenIntent ? Colors.green.shade100 : Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    kUseRealFullScreenIntent ? 'REAL (A)' : 'DEMO-SAFE (B)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: kUseRealFullScreenIntent ? Colors.green.shade900 : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openSimulatedLockScreen,
                icon: const Icon(Icons.lock_clock),
                label: const Text('Lock Screen & Simulate Bystander View'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.brown.shade800,
                  side: BorderSide(color: Colors.brown.shade400, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
