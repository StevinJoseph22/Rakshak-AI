import 'package:flutter/material.dart';

class TestModeQrScannerDialog extends StatefulWidget {
  final String? initialUrl;
  final ValueChanged<String> onUrlScanned;

  const TestModeQrScannerDialog({
    super.key,
    this.initialUrl,
    required this.onUrlScanned,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialUrl,
    required ValueChanged<String> onUrlScanned,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => TestModeQrScannerDialog(
        initialUrl: initialUrl,
        onUrlScanned: onUrlScanned,
      ),
    );
  }

  @override
  State<TestModeQrScannerDialog> createState() => _TestModeQrScannerDialogState();
}

class _TestModeQrScannerDialogState extends State<TestModeQrScannerDialog> {
  late final TextEditingController _payloadController;
  bool _isValidating = false;
  String? _parseError;

  @override
  void initState() {
    super.initState();
    _payloadController = TextEditingController(text: widget.initialUrl ?? '');
  }

  @override
  void dispose() {
    _payloadController.dispose();
    super.dispose();
  }

  String? _extractUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('rakshak://backend?url=')) {
      final uri = Uri.tryParse(trimmed);
      return uri?.queryParameters['url'];
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    // Default to http prefix if IP:port given
    if (RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?$').hasMatch(trimmed)) {
      return 'http://$trimmed';
    }

    return null;
  }

  void _applyUrl(String raw) {
    setState(() {
      _parseError = null;
      _isValidating = true;
    });

    final extracted = _extractUrl(raw);
    if (extracted == null || extracted.isEmpty) {
      setState(() {
        _isValidating = false;
        _parseError = 'Invalid QR payload. Must be a valid HTTP(S) URL or rakshak://backend QR format.';
      });
      return;
    }

    widget.onUrlScanned(extracted);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.qr_code_scanner, color: Colors.purple.shade800, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test Mode QR Code Scanner',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Scan pairing QR on dashboard or paste QR payload',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),

            // Simulated Camera Viewfinder Frame
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade400, width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _QrCornerPainter(color: Colors.purple.shade300),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_outlined, color: Colors.purple.shade200, size: 36),
                      const SizedBox(height: 6),
                      Text(
                        'Align Pairing QR Code within Frame',
                        style: TextStyle(color: Colors.purple.shade100, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Camera viewfinder active (Test Mode Only)',
                        style: TextStyle(color: Colors.purple.shade300, fontSize: 9.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // QR Payload input
            TextField(
              controller: _payloadController,
              decoration: InputDecoration(
                labelText: 'Decoded QR Payload or URL',
                hintText: 'rakshak://backend?url=http://192.168.1.100:5000',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.link, size: 18),
                errorText: _parseError,
              ),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),

            // Quick Venue Presets
            const Text(
              'Quick Venue Presets for Testing:',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildPresetChip('Windows Hotspot', 'http://192.168.137.1:5000'),
                _buildPresetChip('Venue Wi-Fi 100', 'http://192.168.1.100:5000'),
                _buildPresetChip('Venue Wi-Fi 105', 'http://192.168.1.105:5000'),
                _buildPresetChip('Cloud API (SSL)', 'https://api.rakshak-ai.org'),
              ],
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _payloadController.clear();
                      widget.onUrlScanned('');
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('RESET AUTO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isValidating ? null : () => _applyUrl(_payloadController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: _isValidating
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('APPLY SCANNED QR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String url) {
    return InkWell(
      onTap: () {
        _payloadController.text = url;
        _applyUrl(url);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.purple.shade900),
        ),
      ),
    );
  }
}

class _QrCornerPainter extends CustomPainter {
  final Color color;
  _QrCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const cornerLength = 16.0;
    const margin = 12.0;

    // Top-left
    canvas.drawLine(const Offset(margin, margin), const Offset(margin + cornerLength, margin), paint);
    canvas.drawLine(const Offset(margin, margin), const Offset(margin, margin + cornerLength), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - margin, margin), Offset(size.width - margin - cornerLength, margin), paint);
    canvas.drawLine(Offset(size.width - margin, margin), Offset(size.width - margin, margin + cornerLength), paint);

    // Bottom-left
    canvas.drawLine(Offset(margin, size.height - margin), Offset(margin + cornerLength, size.height - margin), paint);
    canvas.drawLine(Offset(margin, size.height - margin), Offset(margin, size.height - margin - cornerLength), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - margin, size.height - margin), Offset(size.width - margin - cornerLength, size.height - margin), paint);
    canvas.drawLine(Offset(size.width - margin, size.height - margin), Offset(size.width - margin, size.height - margin - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
