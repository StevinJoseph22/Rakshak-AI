import 'package:flutter/material.dart';
import '../config/backend_config.dart';

/// Interactive Cloud Relay & Multi-Network Backend Configuration Dialog.
/// Allows testers and competition evaluators to connect the physical smartphone
/// from ANY cellular network (Jio / Airtel 4G/5G, outside Wi-Fi, etc.) to the
/// Rakshak-AI backend via localtunnel, ngrok, Cloudflare Tunnel, or LAN IP.
class BackendRelayDialog extends StatefulWidget {
  const BackendRelayDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const BackendRelayDialog(),
    );
  }

  @override
  State<BackendRelayDialog> createState() => _BackendRelayDialogState();
}

class _BackendRelayDialogState extends State<BackendRelayDialog> {
  final TextEditingController _urlController = TextEditingController();
  bool _isTesting = false;
  String? _statusMessage;
  bool? _isHealthy;
  List<String> _candidates = [];

  @override
  void initState() {
    super.initState();
    _urlController.text = gCustomConfiguredUrl ?? '';
    _candidates = getBackendCandidates();
    _testActiveConnection();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testActiveConnection() async {
    setState(() {
      _isTesting = true;
      _statusMessage = 'Testing active backend connectivity...';
    });

    final targetUrl = _urlController.text.trim().isNotEmpty
        ? _urlController.text.trim()
        : (gActiveBackendUrl ?? getBackendCandidates().first);

    final ok = await testBackendHealth(targetUrl);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _isHealthy = ok;
        _statusMessage = ok
            ? '✅ Connected to $targetUrl (Zero-Latency Link Active)'
            : '⚠️ Unreachable: $targetUrl\nEnsure device is on same Wi-Fi, or enter a public tunnel URL.';
      });
    }
  }

  Future<void> _saveAndApply() async {
    final text = _urlController.text.trim();
    await setCustomBackendUrl(text.isNotEmpty ? text : null);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text.isNotEmpty
              ? 'Saved custom backend: $text'
              : 'Reset to auto-discovery candidate list',
        ),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _autoDetectFastest() async {
    setState(() {
      _isTesting = true;
      _statusMessage = 'Scanning all candidate endpoints...';
    });

    String? workingUrl;
    for (final c in _candidates) {
      final ok = await testBackendHealth(c, timeout: const Duration(milliseconds: 1500));
      if (ok) {
        workingUrl = c;
        break;
      }
    }

    if (!mounted) return;

    if (workingUrl != null) {
      gActiveBackendUrl = workingUrl;
      setState(() {
        _isTesting = false;
        _isHealthy = true;
        _statusMessage = '🎯 Auto-detected working backend: $workingUrl';
      });
    } else {
      setState(() {
        _isTesting = false;
        _isHealthy = false;
        _statusMessage = '❌ No local candidate reachable. Please launch start_public_tunnel.bat and paste the URL here.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      title: const Row(
        children: [
          Icon(Icons.hub_outlined, color: Color(0xFF38BDF8), size: 22),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Backend Relay & Network Hub',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
              'To connect from ANY mobile network (4G/5G mobile data, different Wi-Fi, or public cellular):',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Text(
                '1. Run start_public_tunnel.bat on laptop.\n'
                '2. Paste the generated public HTTPS URL below.',
                style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 14),

            // URL input field
            const Text(
              'CUSTOM CLOUD / TUNNEL URL',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'https://rakshak-ai.loca.lt or http://IP:5000',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            const SizedBox(height: 10),

            // Live status display
            if (_statusMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isHealthy == true
                      ? const Color(0xFF10B981).withOpacity(0.15)
                      : _isHealthy == false
                          ? const Color(0xFFEF4444).withOpacity(0.15)
                          : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isHealthy == true
                        ? const Color(0xFF10B981)
                        : _isHealthy == false
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF334155),
                  ),
                ),
                child: Row(
                  children: [
                    if (_isTesting)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                      )
                    else
                      Icon(
                        _isHealthy == true ? Icons.check_circle : Icons.warning_amber,
                        size: 16,
                        color: _isHealthy == true ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _isHealthy == true ? const Color(0xFF6EE7B7) : const Color(0xFFFCA5A5),
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // Auto-detect button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isTesting ? null : _autoDetectFastest,
                icon: const Icon(Icons.radar, size: 14, color: Color(0xFF38BDF8)),
                label: const Text('Auto-Detect Working Server', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF38BDF8)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _saveAndApply,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
          child: const Text('SAVE & APPLY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
