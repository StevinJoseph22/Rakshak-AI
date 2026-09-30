// Privacy note: Emergency contact data is the victim's own chosen contact,
// stored locally on-device and only sent alongside an actual confirmed incident dispatch
// via victim_metadata. It is never stored in a standalone contacts table or cached
// in Redis alongside temporary photos.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/emergency_contact_model.dart';
import '../services/emergency_sms_service.dart';

class EmergencySmsPreviewScreen extends StatefulWidget {
  final List<EmergencyContact> contacts;
  final String message;
  final String alertType;

  const EmergencySmsPreviewScreen({
    super.key,
    required this.contacts,
    required this.message,
    this.alertType = 'CRASH_ALERT',
  });

  @override
  State<EmergencySmsPreviewScreen> createState() => _EmergencySmsPreviewScreenState();
}

class _EmergencySmsPreviewScreenState extends State<EmergencySmsPreviewScreen> {
  final Set<String> _sentViaWhatsApp = {};
  final Set<String> _simulatedDelivered = {};

  @override
  Widget build(BuildContext context) {
    final isCrash = widget.alertType == 'CRASH_ALERT';

    return Scaffold(
      appBar: AppBar(
        title: Text(isCrash ? 'SOS Crash SMS Preview' : 'Hospital Acceptance Update'),
        backgroundColor: isCrash ? Colors.red.shade900 : Colors.teal.shade900,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Informational Fallback Banner
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade400, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade900, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'P2P Alert Preview (Demo / Fallback)',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'On physical devices with active SIM cards, this alert is sent directly in the background using Android SmsManager (no DLT gateway needed). On emulators without a SIM, tap "Send via WhatsApp" to verify live message delivery.',
                    style: TextStyle(color: Colors.amber.shade900, fontSize: 12.5, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Recipients (${widget.contacts.length} Contact${widget.contacts.length == 1 ? '' : 's'})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),

            ...widget.contacts.map((contact) {
              final isWaSent = _sentViaWhatsApp.contains(contact.id);
              final isSimDelivered = _simulatedDelivered.contains(contact.id);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isWaSent || isSimDelivered ? Colors.green.shade300 : Colors.grey.shade300,
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: isCrash ? Colors.red.shade100 : Colors.teal.shade100,
                            foregroundColor: isCrash ? Colors.red.shade800 : Colors.teal.shade800,
                            radius: 18,
                            child: const Icon(Icons.person, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      contact.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    if (contact.isPrimary) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.red.shade200),
                                        ),
                                        child: Text(
                                          'PRIMARY',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.red.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  '${contact.relationship} • ${contact.phone}',
                                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                          if (isWaSent || isSimDelivered)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    isWaSent ? 'WA Sent' : 'Delivered',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // SMS Bubble
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.sms_outlined, size: 14, color: Colors.blueGrey.shade700),
                                const SizedBox(width: 5),
                                Text(
                                  'OUTGOING SMS BODY (${widget.message.length} chars)',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blueGrey.shade700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              widget.message,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                fontFamily: 'monospace',
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final launched = await EmergencySmsService.instance.launchWhatsAppMessage(
                                  phoneNumber: contact.phone,
                                  message: widget.message,
                                );
                                if (launched && mounted) {
                                  setState(() {
                                    _sentViaWhatsApp.add(contact.id);
                                  });
                                }
                              },
                              icon: const Icon(Icons.send_rounded, size: 16),
                              label: const Text('Send via WhatsApp', style: TextStyle(fontSize: 12.5)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: widget.message));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Message copied to clipboard'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                              setState(() {
                                _simulatedDelivered.add(contact.id);
                              });
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Close Preview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
