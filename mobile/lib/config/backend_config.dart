// ==============================================================================
// RAKSHAK-AI PHASE 9: CENTRALIZED BACKEND & FAILOVER CONFIGURATION
// ------------------------------------------------------------------------------
// DEMO DAY INSTRUCTIONS:
// 1. When running on a physical phone connected to your laptop's Wi-Fi or Hotspot:
//    - Run `ipconfig` (Windows) or `ifconfig` (Mac/Linux) on your laptop.
//    - Update `kDemoWorkstationIp` below to your laptop's IPv4 address:
//      e.g., const String kDemoWorkstationIp = 'http://192.168.43.150:5000';
//    - Or build with `--dart-define=BACKEND_URL=http://<YOUR_IP>:5000`
//
// 2. If phone is connected via USB or wireless ADB, run:
//    `adb reverse tcp:5000 tcp:5000`
//    This allows the phone to talk directly to `http://127.0.0.1:5000` with 0ms latency.
// ==============================================================================

/// Default backend URL read from compile-time `--dart-define=BACKEND_URL=...`
const String kDefaultBackendUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://10.0.2.2:5000',
);

/// Workstation Wi-Fi / Hotspot LAN IP for physical device testing without ADB reverse.
/// UPDATE THIS IP FOR VENUE WI-FI ON DEMO DAY:
const String kDemoWorkstationIp = 'http://192.168.1.21:5000';

/// Ordered list of candidate backend URLs attempted during network failover:
List<String> getBackendCandidates([String? overrideBaseUrl]) {
  return <String>[
    'http://127.0.0.1:5000', // 1. Fast path: active when `adb reverse tcp:5000 tcp:5000` is run
    kDemoWorkstationIp,      // 2. Laptop Wi-Fi / Hotspot LAN IP
    if (kDefaultBackendUrl != 'http://10.0.2.2:5000') kDefaultBackendUrl,
    if (overrideBaseUrl != null && overrideBaseUrl != kDefaultBackendUrl) overrideBaseUrl,
    'http://10.0.2.2:5000',  // 3. Android Emulator host loopback
  ].toSet().toList();
}
