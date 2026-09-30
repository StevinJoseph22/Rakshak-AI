import 'package:flutter/material.dart';
import '../services/lock_screen_service.dart';

/// Screen displayed when Android 14+ restricts USE_FULL_SCREEN_INTENT.
/// Gracefully guides users to the exact system settings toggle.
class PermissionRationaleScreen extends StatelessWidget {
  const PermissionRationaleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lock-Screen Alert Permission'),
        backgroundColor: Colors.amber.shade900,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.screen_lock_portrait,
                    size: 56,
                    color: Colors.amber.shade900,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Full-Screen Lock Override Required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'In an emergency, Rakshak-AI must awaken your screen and display the emergency SOS countdown over your lock screen without asking for your PIN or fingerprint.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade800, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Android 14+ / Android 17 Security',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Google requires manual user authorization for apps to display over the lock screen. Tap the button below to allow "Full Screen Intents" in System Settings.',
                      style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  await LockScreenService.instance.openFullScreenIntentSettings();
                },
                icon: const Icon(Icons.settings),
                label: const Text('Open System Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Use Demo-Safe Mode Instead'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
