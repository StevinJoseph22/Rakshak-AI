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
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Globally tracked active backend URL confirmed by HTTP response or /health check
String? gActiveBackendUrl;

/// Custom user-configured Cloud / Tunnel / Public backend URL
const String kPrefCustomBackendUrl = 'rakshak_custom_backend_url';
String? gCustomConfiguredUrl;

/// Initialize backend config from persistent storage
Future<void> initBackendConfig() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(kPrefCustomBackendUrl);
    if (saved != null && saved.trim().isNotEmpty) {
      gCustomConfiguredUrl = saved.trim().replaceAll(RegExp(r'/+$'), '');
      debugPrint('[BackendConfig] Loaded custom backend URL: $gCustomConfiguredUrl');
    }
  } catch (e) {
    debugPrint('[BackendConfig] Failed to load custom backend URL: $e');
  }
}

/// Persist and apply a custom public tunnel or cloud backend URL
Future<void> setCustomBackendUrl(String? url) async {
  final prefs = await SharedPreferences.getInstance();
  if (url == null || url.trim().isEmpty) {
    gCustomConfiguredUrl = null;
    await prefs.remove(kPrefCustomBackendUrl);
  } else {
    final formatted = url.trim().replaceAll(RegExp(r'/+$'), '');
    gCustomConfiguredUrl = formatted;
    await prefs.setString(kPrefCustomBackendUrl, formatted);
  }
  gActiveBackendUrl = null; // force re-verification
}

/// Test whether a candidate backend URL responds to health checks
Future<bool> testBackendHealth(String url, {Duration timeout = const Duration(seconds: 3)}) async {
  try {
    final cleanUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse('$cleanUrl/health');
    final res = await http.get(uri).timeout(timeout);
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}

/// Default backend URL read from compile-time `--dart-define=BACKEND_URL=...`
const String kDefaultBackendUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://10.0.2.2:5000',
);

/// Workstation Wi-Fi / Hotspot LAN IP for physical device testing without ADB reverse.
/// Current active Wi-Fi IP on workstation:
const String kDemoWorkstationIp = 'http://172.22.114.182:5000';
const String kDemoWorkstationAltIp = 'http://172.22.18.71:5000';
const String kDemoWorkstationHomeIp = 'http://192.168.1.21:5000';

/// Ordered list of candidate backend URLs attempted during network failover:
List<String> getBackendCandidates([String? overrideBaseUrl]) {
  return <String>[
    if (gActiveBackendUrl != null) gActiveBackendUrl!,
    if (gCustomConfiguredUrl != null && gCustomConfiguredUrl!.isNotEmpty) gCustomConfiguredUrl!,
    if (overrideBaseUrl != null && overrideBaseUrl != kDefaultBackendUrl) overrideBaseUrl,
    if (kDefaultBackendUrl != 'http://10.0.2.2:5000') kDefaultBackendUrl,
    kDemoWorkstationIp,           // Current Wi-Fi LAN IP (172.22.114.182:5000)
    kDemoWorkstationAltIp,        // Previous Wi-Fi LAN IP (172.22.18.71:5000)
    'http://192.168.137.1:5000', // Windows Mobile Hotspot default gateway
    'http://127.0.0.1:5000',      // Fast path when adb reverse is active
    'http://192.168.43.1:5000',   // Common Android hotspot gateway
    'http://192.168.56.1:5000',   // Host-only / Virtual adapter
    kDemoWorkstationHomeIp,       // Home Wi-Fi LAN IP (192.168.1.21:5000)
    'http://10.137.61.149:5000',
    'http://10.167.12.149:5000',
    'http://10.215.58.149:5000',
    'http://10.0.2.2:5000',       // Android Emulator host loopback
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

/// Interactive dialog for inspecting and switching server gateway endpoints across any network
Future<void> showServerEndpointDialog(BuildContext context) async {
  final controller = TextEditingController(text: gCustomConfiguredUrl ?? BackendConfig.baseHttpUrl);
  bool isTesting = false;
  String? testResult;
  bool isSuccess = false;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.wifi_tethering, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Server Network & Gateway',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rakshak connects across any network (Wi-Fi, Mobile Hotspot, ADB, or Public Cloud / Tunnel URL).',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Backend Server URL',
                    hintText: 'e.g. http://172.22.114.182:5000',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.cloud_queue, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: Color(0xFF0284C7)),
                      tooltip: 'Ping Health Check',
                      onPressed: isTesting
                          ? null
                          : () async {
                              setDialogState(() {
                                isTesting = true;
                                testResult = 'Testing connection...';
                              });
                              final reachable = await testBackendHealth(controller.text);
                              setDialogState(() {
                                isTesting = false;
                                isSuccess = reachable;
                                testResult = reachable
                                    ? '✓ Online & Reachable (HTTP 200 OK)'
                                    : '✗ Unreachable. Ensure backend is running.';
                              });
                            },
                    ),
                  ),
                ),
                if (testResult != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    testResult!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSuccess ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Quick Connect Presets:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('Wi-Fi LAN (172.22.114.182)', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        controller.text = 'http://172.22.114.182:5000';
                        setDialogState(() {
                          testResult = null;
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('Mobile Hotspot (192.168.137.1)', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        controller.text = 'http://192.168.137.1:5000';
                        setDialogState(() {
                          testResult = null;
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('Android Hotspot (192.168.43.1)', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        controller.text = 'http://192.168.43.1:5000';
                        setDialogState(() {
                          testResult = null;
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('ADB Loopback (127.0.0.1)', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        controller.text = 'http://127.0.0.1:5000';
                        setDialogState(() {
                          testResult = null;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final text = controller.text.trim();
                await setCustomBackendUrl(text.isNotEmpty ? text : null);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Target Gateway updated: ${BackendConfig.baseHttpUrl}'),
                      backgroundColor: const Color(0xFF16A34A),
                    ),
                  );
                }
              },
              child: const Text('Save & Connect'),
            ),
          ],
        );
      },
    ),
  );
}
