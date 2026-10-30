import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'config/lock_screen_config.dart';
import 'models/emergency_contact_model.dart';
import 'screens/ambulance_pilot_home_screen.dart';
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
import 'services/trip_sentinel_client_service.dart';
import 'services/pre_crash_microburst_service.dart';
import 'services/offline_dispatch_queue.dart';
import 'screens/detection_lab_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/citizen_settings_screen.dart';
import 'screens/hospital_radar_screen.dart';
import 'screens/welcome_splash_screen.dart';
import 'screens/citizen_login_screen.dart';
import 'screens/india_emergency_directory_screen.dart';
import 'services/user_profile_service.dart';
import 'services/theme_service.dart';
import 'services/live_telemetry_stream_service.dart';
import 'widgets/cloud_watchdog_simulation_dialog.dart';
import 'widgets/about_system_dialog.dart';
import 'widgets/backend_relay_dialog.dart';
import 'widgets/test_mode_qr_scanner_dialog.dart';
import 'config/backend_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initBackendConfig();
  await UserProfileService.instance.init();
  await ThemeService.instance.init();
  // Start continuous edge kinematics blackbox & live telemetry streaming
  LiveTelemetryStreamService.instance.start();
  final seen = await UserProfileService.instance.hasSeenWelcomeScreen();
  final isRegistered = UserProfileService.instance.profile.isRegistered;
  runApp(RakshakApp(
    startWithWelcome: !seen,
    startWithLogin: !isRegistered,
  ));
}

/// Primary Citizen Life-Guard Application for Riders, Commuters, and Citizens.
class RakshakApp extends StatefulWidget {
  final bool startWithWelcome;
  final bool startWithLogin;

  const RakshakApp({
    super.key,
    this.startWithWelcome = false,
    this.startWithLogin = false,
  });

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<RakshakApp> createState() => _RakshakAppState();
}

class _RakshakAppState extends State<RakshakApp> {
  late bool _showWelcome;
  late bool _showLogin;

  @override
  void initState() {
    super.initState();
    _showWelcome = widget.startWithWelcome;
    _showLogin = widget.startWithLogin;
    UserProfileService.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.themeMode,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          navigatorKey: RakshakApp.navigatorKey,
          title: 'Rakshak-AI Guard',
          debugShowCheckedModeBanner: false,
          theme: ThemeService.instance.lightTheme,
          darkTheme: ThemeService.instance.darkTheme,
          themeMode: currentThemeMode,
          home: _showWelcome
          ? WelcomeSplashScreen(
              onContinue: () {
                setState(() => _showWelcome = false);
              },
            )
          : (_showLogin
              ? CitizenLoginScreen(
                  onRegistrationComplete: () {
                    setState(() => _showLogin = false);
                  },
                )
              : const CrashDetectionScreen()),
        );
      },
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
  int _selectedNavIndex = 0;

  // Phase 2 Simulation Harness State
  double _simulatedDecelerationG = 4.8;
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
  final TextEditingController _testModeBackendUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _testModeBackendUrlController.text = gCustomConfiguredUrl ?? '';
    EmergencySmsService.navigatorKey = RakshakApp.navigatorKey;
    OfflineDispatchQueue.instance.initialize().catchError((_) {});
    _loadEmergencyContacts();
    _initSensors();
    _initCrashListener();
    if (_isMonitoring) {
      CrashDetectorService.instance.start();
      LockScreenService.instance.startBackgroundCrashGuard();
    }
    _checkPendingBackgroundCrash();
  }

  Future<void> _checkPendingBackgroundCrash() async {
    final pending = await LockScreenService.instance.getPendingCrashEvent();
    if (pending != null && mounted) {
      if (CrashEventService.instance.isAlertActive) {
        debugPrint('[MainActivity] 🛡️ Pending background crash suppressed: active alert screen already visible.');
        return;
      }
      final peakG = (pending['deceleration_g'] as num?)?.toDouble() ?? 4.8;
      debugPrint('[MainActivity] 🚨 Recovered pending background crash event (peak: ${peakG}G). Dispatching...');
      final crashEvent = CrashEvent(
        source: 'native_background_guard',
        decelerationG: peakG,
        speedDropKmh: 45.0,
        rolloverSuspected: false,
        confidenceScore: 92,
        timestamp: DateTime.now(),
      );
      CrashEventService.instance.publishCrashEvent(crashEvent);
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
            CrashDetectorService.instance.processAccelerometer(event);
          }
        },
        onError: (_) {},
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
            CrashDetectorService.instance.processGyroscope(event);
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _initCrashListener() {
    _crashSubscription =
        CrashEventService.instance.onCrashDetected.listen((CrashEvent event) async {
      if (!mounted) return;

      if (kUseRealFullScreenIntent) {
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

  Future<void> _simulateDeadManSwitch() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CloudWatchdogSimulationDialog(
        onDismiss: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.purple,
              content: Text('💥 Phone Destruction Simulated! Heartbeat cut. Cloud Watchdog triggering emergency response in 12s...'),
            ),
          );
        },
      ),
    );
  }

  Future<void> _simulatePreCrashMicroBurst() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.deepPurple,
        content: Text('⚡ Pre-Alert Dispatched: Soft impact_suspected marker sent to police room pending rider confirmation.'),
      ),
    );
    await PreCrashMicroBurstService.instance.fireMicroBurst(
      latitude: _useLiveDeviceLocation ? CrashDetectorService.instance.lastKnownLatitude : 12.9716,
      longitude: _useLiveDeviceLocation ? CrashDetectorService.instance.lastKnownLongitude : 77.5946,
      speedKmh: 92.4,
      netG: 8.5,
    );
  }

  @override
  void dispose() {
    _testModeBackendUrlController.dispose();
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
        LockScreenService.instance.startBackgroundCrashGuard();
      } else {
        CrashDetectorService.instance.stop();
        LockScreenService.instance.stopBackgroundCrashGuard();
      }
    });
  }

  bool _isTriggeringSimulatedCrash = false;

  void _triggerSimulatedCrash() {
    if (_isTriggeringSimulatedCrash) {
      debugPrint('[Harness] Suppressed rapid repeated tap on TRIGGER IMPACT SIGNATURE.');
      return;
    }
    _isTriggeringSimulatedCrash = true;
    Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _isTriggeringSimulatedCrash = false);
    });
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

    CrashEventService.instance.triggerCrash(event);
  }

  void _openAmbulanceApp() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AmbulancePilotHomeScreen(
          onSwitchToCitizenApp: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _showSafetyRadarDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.radar, color: Color(0xFFDC2626), size: 24),
                SizedBox(width: 8),
                Text('Real-Time Safety & Blackspot Radar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            const ListTile(
              leading: Icon(Icons.warning, color: Colors.amber),
              title: Text('Silk Board Central Junction (1.2 km)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('4 historical collisions • MoRTH iRAD high-caution zone'),
            ),
            const ListTile(
              leading: Icon(Icons.local_hospital, color: Colors.green),
              title: Text('Manipal Hospital HAL Trauma Center (1.8 km)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Level-1 Apex Trauma Department • 4 ICU Beds open'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close Radar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.instance.isDarkMode;
    final titleTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleTextColor = _isMonitoring
        ? const Color(0xFF10B981)
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6.5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.shield, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rakshak AI',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.2,
                      color: titleTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5.5,
                        height: 5.5,
                        decoration: BoxDecoration(
                          color: _isMonitoring ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _isMonitoring ? 'SENTINEL ACTIVE' : 'PAUSED',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: subtitleTextColor,
                            letterSpacing: 0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
          // 1. Direct Emergency Helpline Button (Red Pill)
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const IndiaEmergencyDirectoryScreen()),
                );
              },
              icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 13),
              label: const Text(
                '112 SOS',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                minimumSize: const Size(0, 30),
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),

          // 2. Citizen Profile / Identity Button
          IconButton(
            icon: Icon(
              Icons.account_circle_outlined,
              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
              size: 22,
            ),
            tooltip: 'Citizen Profile & ABHA Identity',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const CitizenLoginScreen()),
              );
              _loadEmergencyContacts();
              setState(() {});
            },
          ),

          // 2.5 Backend Connection & Cloud Relay Hub
          IconButton(
            icon: Icon(
              Icons.hub_outlined,
              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
              size: 20,
            ),
            tooltip: 'Backend Connection & Public Cloud Relay',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => BackendRelayDialog.show(context),
          ),

          // 3. Theme Toggle Button (Dark / Light Mode)
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.instance.themeMode,
            builder: (ctx, mode, _) {
              final isThemeDark = mode == ThemeMode.dark;
              return IconButton(
                icon: Icon(
                  isThemeDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: isThemeDark ? const Color(0xFFFBBF24) : const Color(0xFF475569),
                  size: 20,
                ),
                tooltip: isThemeDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => ThemeService.instance.toggleTheme(),
              );
            },
          ),

          // 4. Clean Overflow Menu (Ambulance, Test Lab, Settings, Gateway, About)
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              size: 21,
            ),
            color: isDark ? const Color(0xFF111827) : Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
            ),
            onSelected: (val) {
              if (val == 'ambulance') {
                _openAmbulanceApp();
              } else if (val == 'test_lab') {
                setState(() {
                  _isTestMode = !_isTestMode;
                  _selectedNavIndex = _isTestMode ? 3 : 0;
                });
              } else if (val == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CitizenSettingsScreen()),
                ).then((_) => _loadEmergencyContacts());
              } else if (val == 'gateway') {
                showServerEndpointDialog(context);
              } else if (val == 'about') {
                AboutSystemDialog.show(context);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'ambulance',
                child: Row(
                  children: [
                    const Icon(Icons.emergency_rounded, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Ambulance Pilot App',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'test_lab',
                child: Row(
                  children: [
                    Icon(
                      _isTestMode ? Icons.shield_outlined : Icons.science_outlined,
                      color: const Color(0xFFF59E0B),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isTestMode ? 'Exit Test Lab' : 'Enter Test Lab',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Citizen Settings & Vehicle',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'gateway',
                child: Row(
                  children: [
                    const Icon(Icons.wifi_tethering, color: Color(0xFF38BDF8), size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Server Gateway',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'About Rakshak-AI',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        child: Column(
          children: <Widget>[
            // 1. Executive Master Sentinel Command Center (Hero Card)
            _buildUnifiedSentinelCommandCard(),
            const SizedBox(height: 14),

            // 2. High-Priority Emergency & Dispatch Action Grid (2x2 Balanced Modern Tiles)
            _buildRapidActionGrid(context),
            const SizedBox(height: 14),

            // 3. Trip Sentinel Highway Safeguard (Executive Glass)
            _buildTripSentinelCard(),
            const SizedBox(height: 14),

            if (!_isTestMode) ...[
              // 4. Live Sensor Telemetry (Executive Dark Gauges)
              _buildProfessionalTelemetryCard(context),
              const SizedBox(height: 14),

              // 5. ABHA Emergency Health Passport (Executive Dark Glass)
              _buildAbhaMedicalPassportCard(context),
              const SizedBox(height: 14),
            ] else ...[
              // DEMO / TEST LAB SIMULATION VIEW
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
        selectedItemColor: const Color(0xFFEF4444),
        unselectedItemColor: const Color(0xFF64748B),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _selectedNavIndex = index;
            if (index == 0) {
              _isTestMode = false;
            } else if (index == 1) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const HospitalRadarScreen(),
                ),
              );
            } else if (index == 2) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const IndiaEmergencyDirectoryScreen()),
              );
            } else if (index == 3) {
              _isTestMode = true;
            }
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shield),
            label: 'Guardian',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.radar),
            label: 'Radar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.phone_in_talk_rounded),
            label: 'Helplines',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.science),
            label: 'Test Lab',
          ),
        ],
      ),
    );
  }


  // ===========================================================================
  // UI SUB-COMPONENTS: WORLD-CLASS UNIFIED SENTINEL COMMAND ARCHITECTURE
  // ===========================================================================

  Widget _buildUnifiedSentinelCommandCard() {
    return ValueListenableBuilder<UserProfile>(
      valueListenable: UserProfileService.instance.profileNotifier,
      builder: (context, profile, _) {
        final isDark = ThemeService.instance.isDarkMode;
        final vehicleIcon = profile.isTwoWheeler ? Icons.two_wheeler : Icons.directions_car;
        final vehicleLabel = profile.isTwoWheeler ? 'Two-Wheeler (4.8G Threshold)' : 'Four-Wheeler (4.8G Threshold)';
        final riderName = profile.userName.isNotEmpty ? profile.userName : 'Registered Citizen';
        final bloodGroup = profile.bloodGroup.isNotEmpty ? profile.bloodGroup : 'O+';
        final speed = _useLiveDeviceLocation ? (CrashDetectorService.instance.currentSpeedKmh.toStringAsFixed(0)) : '0';

        final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
        final cardBorder = _isMonitoring
            ? const Color(0xFF10B981)
            : (isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0));
        final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final subtitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final stripBg = isDark ? const Color(0xFF0D1322) : const Color(0xFFF1F5F9);
        final dividerColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: cardBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _isMonitoring ? const Color(0xFF10B981).withOpacity(0.08) : Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Rider Profile Info + Vehicle Mode Pill + Edit Shortcut
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Icon(vehicleIcon, color: const Color(0xFF0284C7), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                riderName,
                                style: TextStyle(
                                  color: titleColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.4)),
                                ),
                                child: Text(
                                  bloodGroup,
                                  style: const TextStyle(
                                    color: Color(0xFFFCA5A5),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            vehicleLabel,
                            style: TextStyle(color: subtitleColor, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    // Quick Activate / Pause switch
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: _isMonitoring,
                        activeColor: const Color(0xFF10B981),
                        activeTrackColor: const Color(0xFF064E3B),
                        inactiveThumbColor: const Color(0xFF94A3B8),
                        inactiveTrackColor: const Color(0xFF1E293B),
                        onChanged: (val) => _toggleMonitoring(),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: dividerColor),

              // Center Hero Sentinel Visual
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isMonitoring
                            ? const Color(0xFF064E3B).withOpacity(isDark ? 0.4 : 0.15)
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isMonitoring
                              ? const Color(0xFF10B981).withOpacity(0.5)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _isMonitoring ? Icons.shield : Icons.shield_outlined,
                        size: 32,
                        color: _isMonitoring ? const Color(0xFF10B981) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isMonitoring ? 'SENTINEL GUARD ACTIVE' : 'PROTECTION PAUSED',
                            style: TextStyle(
                              color: _isMonitoring
                                  ? const Color(0xFF10B981)
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _isMonitoring
                                ? '50Hz Edge IMU running • 4.8G Impact Trigger • Cloud watchdog armed'
                                : 'Sensors suspended. Flip switch to re-arm life protection.',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Real-time Telemetry Metrics Strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: stripBg,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetricPill(Icons.speed, 'SPEED', '$speed km/h', const Color(0xFF38BDF8)),
                    _buildMetricDivider(),
                    _buildMetricPill(Icons.bolt, 'TRIGGER', '4.8 G', const Color(0xFFF59E0B)),
                    _buildMetricDivider(),
                    _buildMetricPill(Icons.contact_phone, 'CONTACTS', '$_contactCount Active', const Color(0xFF10B981)),
                    _buildMetricDivider(),
                    _buildMetricPill(Icons.location_on, 'GPS', 'Active Fix', const Color(0xFFEC4899)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricPill(IconData icon, String label, String value, Color color) {
    final isDark = ThemeService.instance.isDarkMode;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricDivider() {
    final isDark = ThemeService.instance.isDarkMode;
    return Container(
      width: 1,
      height: 22,
      color: isDark ? const Color(0xFF1F2937) : const Color(0xFFCBD5E1),
    );
  }

  Widget _buildRapidActionGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            'EMERGENCY & RAPID DISPATCH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Tile 1: Broadcast SOS
            Expanded(
              child: _buildActionTile(
                title: 'Broadcast SOS',
                subtitle: 'Alerts EMS in 10s',
                icon: Icons.sos_rounded,
                isPrimarySos: true,
                onTap: _triggerManualSosAlert,
              ),
            ),
            const SizedBox(width: 10),
            // Tile 2: India Helplines
            Expanded(
              child: _buildActionTile(
                title: 'All Helplines',
                subtitle: '112, 108, Police, NHAI',
                icon: Icons.phone_in_talk_rounded,
                badgeText: '1-TAP CALL',
                accentColor: const Color(0xFFEF4444),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const IndiaEmergencyDirectoryScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Tile 3: Bystander Report
            Expanded(
              child: _buildActionTile(
                title: 'Bystander Intake',
                subtitle: 'Photo scene triage',
                icon: Icons.camera_alt_rounded,
                accentColor: const Color(0xFF38BDF8),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const IntakeScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            // Tile 4: Trauma Radar
            Expanded(
              child: _buildActionTile(
                title: 'Trauma Radar',
                subtitle: 'Nearby ICU beds',
                icon: Icons.radar_rounded,
                accentColor: const Color(0xFF10B981),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HospitalRadarScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color accentColor = const Color(0xFFEF4444),
    String? badgeText,
    bool isPrimarySos = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          height: 98,
          decoration: BoxDecoration(
            gradient: isPrimarySos
                ? const LinearGradient(
                    colors: [Color(0xFF991B1B), Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isPrimarySos
                ? null
                : (ThemeService.instance.isDarkMode ? const Color(0xFF111827) : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPrimarySos
                  ? const Color(0xFFEF4444)
                  : (ThemeService.instance.isDarkMode ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isPrimarySos ? const Color(0xFFDC2626).withOpacity(0.25) : Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isPrimarySos ? Colors.white.withOpacity(0.2) : accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: isPrimarySos ? Colors.white : accentColor, size: 20),
                  ),
                  if (badgeText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: accentColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(color: accentColor, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isPrimarySos
                          ? Colors.white
                          : (ThemeService.instance.isDarkMode ? Colors.white : const Color(0xFF0F172A)),
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isPrimarySos ? Colors.white70 : const Color(0xFF94A3B8),
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // UI SUB-COMPONENTS: PRODUCTION DEPLOYED CITIZEN GUARDIAN
  // ===========================================================================

  Widget _buildRiderVehicleCard() {
    return ValueListenableBuilder<UserProfile>(
      valueListenable: UserProfileService.instance.profileNotifier,
      builder: (context, profile, _) {
        final icon = profile.isTwoWheeler ? Icons.two_wheeler : Icons.directions_car;
        final iconBg = profile.isTwoWheeler ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7);
        final iconColor = profile.isTwoWheeler ? const Color(0xFF2563EB) : const Color(0xFFD97706);

        return InkWell(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const CitizenSettingsScreen()),
            );
            _loadEmergencyContacts();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${profile.userName} • ${profile.vehicleModel}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF94A3B8)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${profile.vehiclePlate} • ${profile.vehicleType} • Safe Score ${profile.safetyDrivingScore}/100',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle, size: 11, color: Color(0xFF16A34A)),
                      SizedBox(width: 4),
                      Text(
                        'PROTECTED',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRideSafetyInsightsCard() {
    return ValueListenableBuilder<UserProfile>(
      valueListenable: UserProfileService.instance.profileNotifier,
      builder: (context, profile, _) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.insights, size: 18, color: Color(0xFF0284C7)),
                      SizedBox(width: 6),
                      Text(
                        'Recent Travels & Driving Insights',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: const Text('SAFE RIDE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInsightTile(
                      label: 'TODAY TRAVEL',
                      val: '${profile.todayDistanceKm} km',
                      sub: 'Logged via GPS',
                      icon: Icons.alt_route,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInsightTile(
                      label: 'SAFETY SCORE',
                      val: '${profile.safetyDrivingScore}/100',
                      sub: 'Smooth Vector',
                      icon: Icons.verified_user_outlined,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInsightTile(
                      label: 'OVERSPEEDING',
                      val: '${profile.overSpeedingCount}',
                      sub: 'Zero Violations',
                      icon: Icons.speed,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInsightTile({
    required String label,
    required String val,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A)),
          ),
          Text(
            sub,
            style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isMonitoring
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFF475569), const Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _isMonitoring ? Colors.black.withOpacity(0.18) : Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            _isMonitoring ? Icons.shield : Icons.shield_outlined,
            size: 48,
            color: _isMonitoring ? const Color(0xFF10B981) : Colors.grey.shade400,
          ),
          const SizedBox(height: 6),
          Text(
            _isMonitoring ? 'Crash Guard Active: Monitoring Telemetry' : 'Monitoring Paused',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _isMonitoring
                ? '50Hz IMU Edge Sensing • Free-Fall Filter • Microburst Alert Active'
                : 'Sensor telemetry suspended. Tap Activate Guard to protect ride.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _toggleMonitoring,
            icon: Icon(_isMonitoring ? Icons.pause : Icons.play_arrow, size: 16),
            label: Text(
              _isMonitoring ? 'Pause Guard' : 'Activate Guard',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isMonitoring ? Colors.white : const Color(0xFF10B981),
              foregroundColor: _isMonitoring ? const Color(0xFF0F172A) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 6),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _contactCount > 0 ? Icons.check_circle : Icons.warning_amber_rounded,
                    size: 12,
                    color: _contactCount > 0 ? const Color(0xFF86EFAC) : Colors.amber,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _contactCount > 0
                        ? 'SOS Contact: ${_primaryContact?.name ?? "Priya Sharma"} (${_primaryContact?.phone ?? "+919876543210"})'
                        : 'No Emergency Contacts Configured — Tap to Setup',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _contactCount > 0 ? Colors.white : Colors.amber.shade200,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 12, color: Colors.white70),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripSentinelCard() {
    final isArmed = TripSentinelClientService.instance.isConsentEnabled;
    final isDark = ThemeService.instance.isDarkMode;
    return Material(
      color: isDark ? const Color(0xFF111827) : Colors.white,
      elevation: isDark ? 0 : 1.5,
      shadowColor: Colors.black.withOpacity(0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isArmed ? const Color(0xFF38BDF8) : (isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            'Trip Sentinel (Highway Contact-Loss Safeguard)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          subtitle: Text(
            'Privacy Protected: Armed strictly for highway speeds (>60 km/h). Cloud watchdog detects sudden collision incapacitation.',
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          value: TripSentinelClientService.instance.isConsentEnabled,
          onChanged: (val) async {
            if (val) {
              final consented = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      const Icon(Icons.security, color: Color(0xFF0284C7), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Trip Sentinel Consent',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    'In compliance with DPDP Act Section 7(f), Trip Sentinel streams anonymized GPS heartbeat telemetry to the secure watchdog server ONLY when travelling at highway speeds (>60 km/h).\n\nTelemetry resides strictly in volatile RAM and is permanently purged once you reach your destination. If communication drops abruptly during high speed, responders are alerted to check for silent roadside accidents.\n\nDo you grant explicit consent for journey telemetry monitoring?',
                    style: TextStyle(
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Decline', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('I Consent & Enable', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );

              if (consented == true) {
                setState(() {
                  TripSentinelClientService.instance.setMonitoringConsent(true);
                });
              }
            } else {
              setState(() {
                TripSentinelClientService.instance.setMonitoringConsent(false);
              });
            }
          },
        ),
      ),
    );
  }

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
    final isDark = ThemeService.instance.isDarkMode;

    return Card(
      elevation: isDark ? 0 : 1.5,
      shadowColor: Colors.black.withOpacity(0.04),
      color: isDark ? const Color(0xFF111827) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
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
                    color: isDark ? const Color(0xFF064E3B).withOpacity(0.4) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(isDark ? 0.3 : 0.4)),
                  ),
                  child: const Icon(Icons.speed_rounded, color: Color(0xFF10B981), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Protection Telemetry',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        _isMonitoring ? 'Continuous IMU & GPS Analysis Active' : 'Protection Paused',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isMonitoring
                        ? (isDark ? const Color(0xFF064E3B).withOpacity(0.4) : const Color(0xFFF0FDF4))
                        : (isDark ? const Color(0xFF450A0A).withOpacity(0.4) : const Color(0xFFFEF2F2)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isMonitoring
                          ? (isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC))
                          : (isDark ? const Color(0xFFDC2626) : const Color(0xFFFECACA)),
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
                          color: _isMonitoring
                              ? (isDark ? const Color(0xFF34D399) : const Color(0xFF166534))
                              : (isDark ? const Color(0xFFF87171) : const Color(0xFF991B1B)),
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
    final isDark = ThemeService.instance.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? color.shade900.withOpacity(0.22) : color.shade50.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? color.shade700.withOpacity(0.35) : color.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: isDark ? color.shade300 : color.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : color.shade900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? const Color(0xFF64748B) : Colors.grey.shade600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBlackspotRadarBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'HIGH-RISK ACCIDENT BLACKSPOT NEARBY',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF991B1B)),
                ),
                SizedBox(height: 2),
                Text(
                  'Silk Board Central Junction (1.2 km ahead • 4 historical collisions • Learned from Rakshak demo data)',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF7F1D1D)),
                ),
                SizedBox(height: 2),
                Text(
                  '* Production roadmap: Seeding from MoRTH iRAD / eDAR open accident database.',
                  style: TextStyle(fontSize: 9.5, fontStyle: FontStyle.italic, color: Color(0xFF991B1B)),
                ),
              ],
            ),
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
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const IndiaEmergencyDirectoryScreen()),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.35)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withOpacity(0.06),
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
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFFDC2626), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'India Emergency Helplines',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '1-TAP CALL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Direct calling for 112, 108 Ambulance, Highway, Police & Women helplines',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFFDC2626)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAbhaMedicalPassportCard(BuildContext context) {
    final isDark = ThemeService.instance.isDarkMode;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge, color: Color(0xFF0284C7), size: 18),
              const SizedBox(width: 8),
              Text(
                'ABHA Emergency Health Passport',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ABDM Verified',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D1E38) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BLOOD TYPE',
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('B+ Positive', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFDC2626))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D1515) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CRITICAL ALLERGY',
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Penicillin Anaphylaxis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFB91C1C))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Icon(Icons.tune, size: 13, color: Color(0xFF0284C7)),
                SizedBox(width: 4),
                Text(
                  'Manage ABHA Health Card & Allergies →',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbulanceAppPromoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1A38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00E5FF), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF1744),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.emergency, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'RAKSHAK ResQ PILOT (AMBULANCE APP)',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF00E5FF)),
                ),
                SizedBox(height: 2),
                Text(
                  'Dedicated Paramedic Cockpit with C-V2X Green Corridor preemption & ABHA triage.',
                  style: TextStyle(fontSize: 10.5, color: Colors.white70),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _openAmbulanceApp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            child: const Text('Launch', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
          ),
        ],
      ),
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
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.satellite_alt_rounded, size: 18, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Hardware Destruction & Zero-Network Defense',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.purple.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Demonstrates survival if phone breaks down in <100ms or cellular IP connection is unavailable.',
              style: TextStyle(fontSize: 11, color: Colors.purple.shade800),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _simulateDeadManSwitch,
                icon: const Icon(Icons.flash_off, color: Colors.white),
                label: const Text(
                  '[SIMULATED] PHONE BREAKDOWN (CLOUD WATCHDOG)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _simulatePreCrashMicroBurst,
                icon: const Icon(Icons.bolt, color: Colors.deepPurple),
                label: const Text(
                  'FIRE PRE-ALERT (SUSPECTED IMPACT MARKER)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                  side: const BorderSide(color: Colors.deepPurple, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const DetectionLabScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.biotech_rounded, color: Colors.white),
                label: const Text(
                  'OPEN DETECTION LAB (7 SCENARIO VERIFICATION)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const Divider(height: 24),
            Text(
              'VENUE / TEST NETWORK OVERRIDE (PERSISTED)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.purple.shade900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Configure custom laptop or venue backend URL for testing. Normal citizen UI stays zero-configuration.',
              style: TextStyle(fontSize: 10, color: Colors.purple.shade700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _testModeBackendUrlController,
                    decoration: InputDecoration(
                      hintText: 'http://192.168.x.x:5000',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: () {
                    TestModeQrScannerDialog.show(
                      context,
                      initialUrl: _testModeBackendUrlController.text,
                      onUrlScanned: (scannedUrl) async {
                        _testModeBackendUrlController.text = scannedUrl;
                        await setCustomBackendUrl(scannedUrl.isEmpty ? null : scannedUrl);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(scannedUrl.isEmpty
                                  ? 'Reset to automatic zero-config candidate discovery'
                                  : 'Custom backend override saved via QR: $scannedUrl'),
                            ),
                          );
                        }
                      },
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner, size: 14),
                  label: const Text('SCAN QR', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple.shade900,
                    side: BorderSide(color: Colors.purple.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  onPressed: () async {
                    final text = _testModeBackendUrlController.text.trim();
                    await setCustomBackendUrl(text.isEmpty ? null : text);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(text.isEmpty
                              ? 'Reset to automatic zero-config candidate discovery'
                              : 'Custom backend override saved: $text'),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('SAVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
