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

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Globally tracked active backend URL confirmed by HTTP response or /health check
String? gActiveBackendUrl;

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
    if (gActiveBackendUrl != null) gActiveBackendUrl!,
    kDemoWorkstationIp,      // 1. Laptop Wi-Fi / Hotspot LAN IP (fastest for physical device on Wi-Fi)
    'http://127.0.0.1:5000', // 2. Fast path: active when `adb reverse tcp:5000 tcp:5000` is run
    if (kDefaultBackendUrl != 'http://10.0.2.2:5000') kDefaultBackendUrl,
    if (overrideBaseUrl != null && overrideBaseUrl != kDefaultBackendUrl) overrideBaseUrl,
    'http://10.0.2.2:5000',  // 3. Android Emulator host loopback
  ].toSet().toList();
}

/// Fast concurrent / sequential health-check to discover the active backend URL for WebSockets
Future<String> resolveReachableBackendUrl({
  Duration timeout = const Duration(milliseconds: 1200),
}) async {
  if (gActiveBackendUrl != null) {
    return gActiveBackendUrl!;
  }
  final candidates = getBackendCandidates();
  final client = http.Client();
  try {
    for (final url in candidates) {
      try {
        final res = await client.get(Uri.parse('$url/health')).timeout(timeout);
        if (res.statusCode == 200) {
          gActiveBackendUrl = url;
          debugPrint('[BackendConfig] Discovered active backend at: $url');
          return url;
        }
      } catch (_) {
        // Continue to next candidate
      }
    }
  } finally {
    client.close();
  }
  return candidates.isNotEmpty ? candidates.first : kDemoWorkstationIp;
}
