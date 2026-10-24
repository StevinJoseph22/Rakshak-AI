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

import 'dart:async';
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
/// Current active Wi-Fi IP on workstation:
const String kDemoWorkstationIp = 'http://172.22.18.71:5000';
const String kDemoWorkstationAltIp = 'http://192.168.1.21:5000';

/// Ordered list of candidate backend URLs attempted during network failover:
List<String> getBackendCandidates([String? overrideBaseUrl]) {
  return <String>[
    if (gActiveBackendUrl != null) gActiveBackendUrl!,
    kDemoWorkstationIp,      // 1. Current Wi-Fi LAN IP (172.22.18.71:5000)
    'http://127.0.0.1:5000', // 2. Fast path: 0ms latency when `adb reverse tcp:5000 tcp:5000` is active
    'http://192.168.56.1:5000', // 3. Host-only / Virtual adapter
    kDemoWorkstationAltIp,   // 4. Alternate Wi-Fi LAN IP (192.168.1.21:5000)
    'http://10.137.61.149:5000',
    'http://10.167.12.149:5000',
    'http://10.215.58.149:5000',
    'http://192.168.43.149:5000', // Common Android hotspot range
    'http://192.168.1.149:5000',
    if (kDefaultBackendUrl != 'http://10.0.2.2:5000') kDefaultBackendUrl,
    if (overrideBaseUrl != null && overrideBaseUrl != kDefaultBackendUrl) overrideBaseUrl,
    'http://10.0.2.2:5000',  // Android Emulator host loopback
  ].toSet().toList();
}

/// Fast concurrent health-check to discover the active backend URL in parallel
Future<String> resolveReachableBackendUrl({
  Duration timeout = const Duration(milliseconds: 1500),
}) async {
  if (gActiveBackendUrl != null) {
    return gActiveBackendUrl!;
  }
  final candidates = getBackendCandidates();
  final client = http.Client();
  final completer = Completer<String>();
  int remaining = candidates.length;

  for (final url in candidates) {
    client.get(Uri.parse('$url/health')).timeout(timeout).then((res) {
      if (res.statusCode == 200 && !completer.isCompleted) {
        gActiveBackendUrl = url;
        debugPrint('[BackendConfig] Fast concurrent discovery reached active backend at: $url');
        completer.complete(url);
      }
    }).catchError((_) {}).whenComplete(() {
      remaining--;
      if (remaining == 0 && !completer.isCompleted) {
        completer.complete(kDemoWorkstationIp);
      }
    });
  }

  try {
    return await completer.future.timeout(
      timeout + const Duration(milliseconds: 200),
      onTimeout: () => kDemoWorkstationIp,
    );
  } finally {
    client.close();
  }
}

/// Helper class providing clean access to active base HTTP URL
class BackendConfig {
  static String get baseHttpUrl =>
      gActiveBackendUrl ??
      (kDefaultBackendUrl != 'http://10.0.2.2:5000'
          ? kDefaultBackendUrl
          : kDemoWorkstationIp);

  static Future<String> getResolvedUrl() => resolveReachableBackendUrl();
}
