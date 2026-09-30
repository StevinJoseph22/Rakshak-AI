import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'config/lock_screen_config.dart';
import 'models/emergency_contact_model.dart';
import 'screens/ambulance_console_screen.dart';
import 'screens/emergency_contacts_screen.dart';
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
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedNavIndex = 1;
              });
            },
            icon: const Icon(Icons.emergency, color: Colors.redAccent, size: 20),
            label: const Text(
              'Ambulance Mode',
              style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
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
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),

            // Live Sensor Diagnostics
            Card(
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
            ),
            const SizedBox(height: 16),

            // Simulation Harness Controls
            Card(
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

                    // Deceleration Slider
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

                    // Speed Drop Slider
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

                    // GPS Location Mode Selector
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

                    // Phase 4: Bystander Override Section
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
            ),
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
}
