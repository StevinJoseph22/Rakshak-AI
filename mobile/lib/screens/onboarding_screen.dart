import 'package:flutter/material.dart';
import '../services/abdm_mobile_service.dart';
import '../services/health_card_storage_service.dart';
import '../services/emergency_contact_service.dart';
import '../models/emergency_contact_model.dart';
import '../models/emergency_health_card_model.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 2: Emergency Contact
  final TextEditingController _contactNameController = TextEditingController(text: 'Vikram Sharma');
  final TextEditingController _contactPhoneController = TextEditingController(text: '+91 98450 12345');
  String _contactRelation = 'Parent';

  // Step 3: ABHA Link
  final TextEditingController _abhaAddressController = TextEditingController(text: 'aarav.sharma@abdm');
  final TextEditingController _otpController = TextEditingController();
  bool _isRequestingOtp = false;
  bool _isVerifyingOtp = false;
  String? _txnId;
  String? _abhaMessage;
  bool _abhaLinkedSuccess = false;
  String _abdmMode = 'MOCK';

  // Step 4: Self-Declared Health Info
  final TextEditingController _bloodGroupController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _conditionsController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  bool _isOrganDonor = false;

  @override
  void initState() {
    super.initState();
    AbdmMobileService.instance.getGatewayMode().then((mode) {
      if (mounted) setState(() => _abdmMode = mode);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _abhaAddressController.dispose();
    _otpController.dispose();
    _bloodGroupController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    _medicationsController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentStep < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _startAbhaVerification() async {
    final address = _abhaAddressController.text.trim();
    if (address.isEmpty) {
      setState(() => _abhaMessage = 'Please enter an ABHA address.');
      return;
    }

    setState(() {
      _isRequestingOtp = true;
      _abhaMessage = null;
    });

    final res = await AbdmMobileService.instance.startVerification(address);
    if (!mounted) return;

    setState(() {
      _isRequestingOtp = false;
      _txnId = res.txnId;
      _abhaMessage = res.message;
      _abdmMode = res.mode;
    });

    if (res.status == 'OTP_SENT') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: Colors.green.shade800,
        ),
      );
    } else if (res.status == 'ABDM_UNAVAILABLE') {
      // Graceful non-blocking error guidance
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: Colors.amber.shade900,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _confirmAbhaOtp() async {
    if (_txnId == null) {
      setState(() => _abhaMessage = 'Please request an OTP first.');
      return;
    }
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      setState(() => _abhaMessage = 'Please enter the 6-digit OTP.');
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _abhaMessage = null;
    });

    final res = await AbdmMobileService.instance.confirmVerification(
      txnId: _txnId!,
      otp: otp,
    );
    if (!mounted) return;

    setState(() {
      _isVerifyingOtp = false;
      _abhaMessage = res.message;
      _abdmMode = res.mode;
    });

    if (res.status == 'VERIFIED' && res.profile != null) {
      await HealthCardStorageService.instance.saveAbdmVerifiedData(
        profile: res.profile!,
        records: res.records,
        sessionToken: res.sessionToken,
        mode: res.mode,
      );

      setState(() => _abhaLinkedSuccess = true);

      // Pre-fill self-declared fields if returned from ABDM records
      if (res.records != null && res.records!['status'] == 'AVAILABLE') {
        if (res.records!['blood_group'] != null) {
          _bloodGroupController.text = res.records!['blood_group'].toString();
        }
        if (res.records!['allergies'] is List) {
          _allergiesController.text = (res.records!['allergies'] as List).join(', ');
        }
        if (res.records!['chronic_conditions'] is List) {
          _conditionsController.text = (res.records!['chronic_conditions'] as List).join(', ');
        }
        if (res.records!['current_medications'] is List) {
          _medicationsController.text = (res.records!['current_medications'] as List).join(', ');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ABHA successfully linked with verified profile!'),
          backgroundColor: Colors.green,
        ),
      );

      // Automatically proceed to next step after brief pause
      Future.delayed(const Duration(milliseconds: 700), _nextPage);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _saveHealthInfoAndProceed() async {
    final blood = _bloodGroupController.text.trim();
    final allergies = _allergiesController.text
        .split(',')
        .map((s) => s.trim())
        .filterNotEmpty();
    final conditions = _conditionsController.text
        .split(',')
        .map((s) => s.trim())
        .filterNotEmpty();
    final medications = _medicationsController.text
        .split(',')
        .map((s) => s.trim())
        .filterNotEmpty();

    if (blood.isNotEmpty || allergies.isNotEmpty || conditions.isNotEmpty || medications.isNotEmpty) {
      await HealthCardStorageService.instance.saveSelfDeclaredData(
        bloodGroup: blood.isNotEmpty ? blood : null,
        allergies: allergies.isNotEmpty ? allergies : null,
        conditions: conditions.isNotEmpty ? conditions : null,
        medications: medications.isNotEmpty ? medications : null,
        organDonor: _isOrganDonor ? 'Registered Organ Donor (Self-Declared)' : null,
      );
    }
    _nextPage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Rakshak-AI Onboarding', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _abdmMode == 'SANDBOX' ? Colors.green.shade900 : Colors.blueGrey.shade800,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _abdmMode == 'SANDBOX' ? Colors.greenAccent : Colors.grey),
            ),
            child: Text(
              'ABDM: $_abdmMode',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            LinearProgressIndicator(
              value: (_currentStep + 1) / 5.0,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentStep = idx),
                children: [
                  _buildPermissionsStep(),
                  _buildEmergencyContactStep(),
                  _buildAbhaLinkStep(),
                  _buildHealthInfoStep(),
                  _buildConsentSummaryStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 1: System Permissions
  Widget _buildPermissionsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.security, size: 64, color: Color(0xFF38BDF8)),
          const SizedBox(height: 16),
          const Text(
            'Emergency Sensing Permissions',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'To protect you on highways and city corridors, Rakshak-AI requires high-frequency sensor and critical alert permissions.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          const SizedBox(height: 24),
          _buildPermissionTile(
            icon: Icons.location_on,
            title: 'High-Precision GPS Location',
            subtitle: 'Determines crash coordinates for nearest 8km Level-1 trauma centers.',
          ),
          const SizedBox(height: 12),
          _buildPermissionTile(
            icon: Icons.screen_lock_portrait,
            title: 'Full-Screen Alert Override',
            subtitle: 'Wakes up locked screen with 10-second cancel button before SOS broadcast.',
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            key: const Key('permissions_continue_button'),
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Grant & Continue', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // STEP 2: Emergency Contacts
  Widget _buildEmergencyContactStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.contact_phone, size: 64, color: Colors.amberAccent),
          const SizedBox(height: 16),
          const Text(
            'Primary Emergency Contact',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Will receive instant multi-stage SMS notifications: (1) Crash detected, (2) Ambulance dispatch, (3) Hospital admission.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('contact_name_field'),
            controller: _contactNameController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Contact Full Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('contact_phone_field'),
            controller: _contactPhoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Mobile Number (+91)'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            key: const Key('contact_continue_button'),
            onPressed: () async {
              final name = _contactNameController.text.trim();
              final phone = _contactPhoneController.text.trim();
              if (name.isNotEmpty && phone.isNotEmpty) {
                await EmergencyContactService.instance.addContact(
                  EmergencyContact(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    phone: phone,
                    relationship: _contactRelation,
                    isPrimary: true,
                  ),
                );
              }
              _nextPage();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save Contact & Continue', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // STEP 3: (Optional) Link ABHA
  Widget _buildAbhaLinkStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.health_and_safety, size: 64, color: Color(0xFF10B981)),
          const SizedBox(height: 16),
          const Text(
            'Link Ayushman Bharat (ABHA)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'OPTIONAL & SKIPPABLE. Links verified identity from National Health Authority. Health records remain self-declared unless linked via ABDM.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('abha_address_field'),
            controller: _abhaAddressController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('ABHA Address (e.g. name@abdm)'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            key: const Key('request_otp_button'),
            onPressed: _isRequestingOtp ? null : _startAbhaVerification,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF334155),
              foregroundColor: Colors.white,
            ),
            child: _isRequestingOtp
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Request Verification OTP'),
          ),
          if (_txnId != null) ...[
            const SizedBox(height: 16),
            TextField(
              key: const Key('abha_otp_field'),
              controller: _otpController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, letterSpacing: 4, fontWeight: FontWeight.bold),
              decoration: _inputDecoration('Enter 6-digit OTP (Mock: 123456)'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              key: const Key('confirm_otp_button'),
              onPressed: _isVerifyingOtp ? null : _confirmAbhaOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              child: _isVerifyingOtp
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm OTP & Verify ABHA'),
            ),
          ],
          if (_abhaMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _abhaMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _abhaLinkedSuccess ? Colors.greenAccent : Colors.amberAccent,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 28),
          TextButton(
            key: const Key('skip_abha_button'),
            onPressed: _nextPage,
            child: const Text('Skip ABHA Linking for now', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
        ],
      ),
    );
  }

  // STEP 4: (Optional) Emergency Health Info
  Widget _buildHealthInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.medical_information, size: 64, color: Color(0xFF38BDF8)),
          const SizedBox(height: 16),
          const Text(
            'Emergency Health Information',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'OPTIONAL. Self-declared data is clearly labelled "not verified". Shared with trauma doctors strictly upon crash claim.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('blood_group_field'),
            controller: _bloodGroupController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Blood Group (e.g. O+, B+, A-)'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('allergies_field'),
            controller: _allergiesController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Drug Allergies (e.g. Penicillin, Sulfa)'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('conditions_field'),
            controller: _conditionsController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Chronic Conditions (e.g. Type-1 Diabetes, Asthma)'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('medications_field'),
            controller: _medicationsController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Current Medications (e.g. Warfarin, Insulin)'),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            key: const Key('organ_donor_switch'),
            title: const Text('NOTTO Organ Donor', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('Consent to display donor status on emergency card', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
            value: _isOrganDonor,
            activeColor: const Color(0xFF38BDF8),
            onChanged: (val) => setState(() => _isOrganDonor = val),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            key: const Key('save_health_info_button'),
            onPressed: _saveHealthInfoAndProceed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save & Continue', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          TextButton(
            key: const Key('skip_health_info_button'),
            onPressed: _nextPage,
            child: const Text('Skip Health Info', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
        ],
      ),
    );
  }

  // STEP 5: Consent Summary & Unlink Option
  Widget _buildConsentSummaryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.verified_user, size: 64, color: Colors.greenAccent),
          const SizedBox(height: 16),
          const Text(
            'Emergency Data Sharing Consent',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ConsentItem(
                  title: 'WHAT IS SHARED',
                  description: 'Emergency Health Card containing verified identity and declared medical fields.',
                ),
                Divider(color: Color(0xFF334155)),
                _ConsentItem(
                  title: 'WITH WHOM',
                  description: 'ONLY the authorized clinical team of the hospital that officially claims/accepts your emergency case.',
                ),
                Divider(color: Color(0xFF334155)),
                _ConsentItem(
                  title: 'WHEN',
                  description: 'ONLY after a high-severity physical crash is confirmed by Rakshak-AI. Never during normal commutes or daily travel.',
                ),
                Divider(color: Color(0xFF334155)),
                _ConsentItem(
                  title: 'FOR HOW LONG',
                  description: 'Held in volatile Redis RAM for a strict 2-hour TTL. Automatically purged. Never written to permanent databases.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            key: const Key('finish_onboarding_button'),
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Accept & Activate Rakshak Sentinel', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('onboarding_unlink_button'),
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 18),
            label: const Text('One-Tap Unlink & Wipe All Data', style: TextStyle(color: Colors.redAccent)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () async {
              await HealthCardStorageService.instance.unlinkAndDelete();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All local health profiles and server sessions wiped.'),
                    backgroundColor: Colors.red,
                  ),
                );
                setState(() {
                  _abhaLinkedSuccess = false;
                  _txnId = null;
                  _otpController.clear();
                  _bloodGroupController.clear();
                  _allergiesController.clear();
                  _conditionsController.clear();
                  _medicationsController.clear();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF38BDF8), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
    );
  }
}

class _ConsentItem extends StatelessWidget {
  final String title;
  final String description;

  const _ConsentItem({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 2),
          Text(description, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

extension _IterableExt<T> on Iterable<T> {
  List<T> filterNotEmpty() {
    return where((element) {
      if (element is String) return element.trim().isNotEmpty;
      return true;
    }).toList();
  }
}
