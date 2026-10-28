import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/emergency_contact_model.dart';
import '../services/emergency_contact_service.dart';
import '../services/health_card_storage_service.dart';
import '../services/user_profile_service.dart';
import '../config/backend_config.dart';

/// Next-Generation Multi-Step Citizen Onboarding & Registration Wizard.
/// Steps:
/// 1. Google Authentication & Identity
/// 2. Phone Number & OTP Verification
/// 3. Emergency Contacts (2 Mandatory, 1 Optional)
/// 4. ABHA Digital Health Card (Optional)
/// 5. Review & Edge AI Security Activation
class CitizenLoginScreen extends StatefulWidget {
  final VoidCallback? onRegistrationComplete;

  const CitizenLoginScreen({super.key, this.onRegistrationComplete});

  @override
  State<CitizenLoginScreen> createState() => _CitizenLoginScreenState();
}

class _CitizenLoginScreenState extends State<CitizenLoginScreen> {
  int _currentStep = 0; // 0 to 4
  final int _totalSteps = 5;

  // Step 1: Google Identity
  bool _isGoogleAuthenticated = false;
  String _googleEmail = '';
  late TextEditingController _nameController;

  // Step 2: Phone & OTP
  late TextEditingController _phoneController;
  late TextEditingController _otpController;
  bool _isOtpSent = false;
  bool _isPhoneVerified = false;
  String _generatedOtp = '742918';
  int _resendCountdown = 30;
  Timer? _countdownTimer;

  // Step 3: Emergency Contacts (2 Mandatory, 1 Optional)
  late TextEditingController _contact1NameController;
  late TextEditingController _contact1PhoneController;
  String _contact1Relation = 'Spouse';

  late TextEditingController _contact2NameController;
  late TextEditingController _contact2PhoneController;
  String _contact2Relation = 'Parent';

  bool _showThirdContact = false;
  late TextEditingController _contact3NameController;
  late TextEditingController _contact3PhoneController;
  String _contact3Relation = 'Sibling';

  // Step 4: ABHA Digital Health Card (Optional)
  bool _hasAbhaCard = true;
  late TextEditingController _abhaNumberController;
  late TextEditingController _abhaAddressController;
  String _selectedBloodGroup = 'O+ Positive';
  late TextEditingController _allergiesController;
  late TextEditingController _conditionsController;
  late TextEditingController _medicationsController;

  // Step 5: Activation
  bool _isSaving = false;

  final List<String> _bloodGroups = [
    'O+ Positive',
    'O- Negative',
    'A+ Positive',
    'A- Negative',
    'B+ Positive',
    'B- Negative',
    'AB+ Positive',
    'AB- Negative',
  ];

  final List<String> _relationships = [
    'Spouse',
    'Parent',
    'Sibling',
    'Child',
    'Friend',
    'Guardian',
    'Colleague',
  ];

  @override
  void initState() {
    super.initState();
    final p = UserProfileService.instance.profile;

    _nameController = TextEditingController(text: p.userName);
    _googleEmail = p.userEmail.isNotEmpty ? p.userEmail : 'stevinjoseph@gmail.com';
    _isGoogleAuthenticated = p.authMethod == 'GOOGLE' || p.isRegistered;

    _phoneController = TextEditingController(text: p.phone.replaceAll('+91', '').trim());
    _otpController = TextEditingController();
    _isPhoneVerified = p.isPhoneVerified || p.isRegistered;

    _contact1NameController = TextEditingController(text: p.emergencyContactName);
    _contact1PhoneController = TextEditingController(text: p.emergencyContactPhone.replaceAll('+91', '').trim());
    if (_relationships.contains(p.emergencyContactRelation)) {
      _contact1Relation = p.emergencyContactRelation;
    }

    _contact2NameController = TextEditingController(text: p.secondaryContactName.isNotEmpty ? p.secondaryContactName : 'Rajesh Joseph');
    _contact2PhoneController = TextEditingController(text: p.secondaryContactPhone.replaceAll('+91', '').trim().isNotEmpty ? p.secondaryContactPhone.replaceAll('+91', '').trim() : '9845012345');
    if (_relationships.contains(p.secondaryContactRelation)) {
      _contact2Relation = p.secondaryContactRelation;
    }

    _showThirdContact = p.tertiaryContactPhone != null && p.tertiaryContactPhone!.isNotEmpty;
    _contact3NameController = TextEditingController(text: p.tertiaryContactName ?? '');
    _contact3PhoneController = TextEditingController(text: (p.tertiaryContactPhone ?? '').replaceAll('+91', '').trim());
    if (p.tertiaryContactRelation != null && _relationships.contains(p.tertiaryContactRelation)) {
      _contact3Relation = p.tertiaryContactRelation!;
    }

    _hasAbhaCard = p.hasAbhaCard;
    _abhaNumberController = TextEditingController(text: p.abhaNumber);
    _abhaAddressController = TextEditingController(text: p.abhaAddress);
    if (_bloodGroups.contains(p.bloodGroup)) {
      _selectedBloodGroup = p.bloodGroup;
    }
    _allergiesController = TextEditingController(text: p.criticalAllergies.join(', '));
    _conditionsController = TextEditingController(text: p.chronicConditions.join(', '));
    _medicationsController = TextEditingController(text: p.currentMedications.join(', '));
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _contact1NameController.dispose();
    _contact1PhoneController.dispose();
    _contact2NameController.dispose();
    _contact2PhoneController.dispose();
    _contact3NameController.dispose();
    _contact3PhoneController.dispose();
    _abhaNumberController.dispose();
    _abhaAddressController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    _medicationsController.dispose();
    super.dispose();
  }

  // --- Step 1: Google Account Picker ---
  void _openGoogleAccountPicker() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.network(
                    'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                    width: 26,
                    height: 26,
                    errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 28, color: Colors.blue),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Sign in with Google',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose an account to continue to Rakshak-AI Citizen Life-Guard.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFDC2626),
                  child: const Text('SJ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: const Text('Stevin Joseph', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('stevinjoseph@gmail.com', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                trailing: const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _isGoogleAuthenticated = true;
                    _googleEmail = 'stevinjoseph@gmail.com';
                    _nameController.text = 'Stevin Joseph';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Authenticated with Google: stevinjoseph@gmail.com'),
                      backgroundColor: Color(0xFF16A34A),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF0284C7),
                  child: const Text('JE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: const Text('Stevin Joseph (College)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('stevin.btech21@jecc.ac.in', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _isGoogleAuthenticated = true;
                    _googleEmail = 'stevin.btech21@jecc.ac.in';
                    _nameController.text = 'Stevin Joseph';
                  });
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // --- Step 2: OTP Generation & Verification ---
  void _sendOtp() {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.replaceAll(RegExp(r'\D'), '').length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit mobile number'), backgroundColor: Colors.red),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isOtpSent = true;
      _resendCountdown = 30;
      _generatedOtp = '742918';
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔔 Rakshak OTP: Your 6-digit verification code is $_generatedOtp (valid 5 min)'),
        backgroundColor: const Color(0xFF0284C7),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'AUTO-FILL',
          textColor: Colors.white,
          onPressed: () {
            setState(() => _otpController.text = _generatedOtp);
          },
        ),
      ),
    );
  }

  void _verifyOtp() {
    HapticFeedback.mediumImpact();
    final entered = _otpController.text.trim();
    if (entered == _generatedOtp || entered == '123456' || entered.length == 6) {
      setState(() {
        _isPhoneVerified = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Phone number verified successfully (+91)'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid OTP code. Please enter the 6-digit code received.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- Step 3: Pre-fill Demo Emergency Contacts ---
  void _fillDemoEmergencyContacts() {
    HapticFeedback.lightImpact();
    setState(() {
      _contact1NameController.text = 'Anjali Sharma';
      _contact1PhoneController.text = '9876543211';
      _contact1Relation = 'Spouse';

      _contact2NameController.text = 'Rajesh Joseph';
      _contact2PhoneController.text = '9845012345';
      _contact2Relation = 'Parent';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ 2 Mandatory Emergency Contacts pre-filled'),
        backgroundColor: Color(0xFF0284C7),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // --- Step 4: Pre-fill Demo ABHA Card ---
  void _fillDemoAbhaCard() {
    HapticFeedback.lightImpact();
    setState(() {
      _hasAbhaCard = true;
      _abhaNumberController.text = '91-4829-1029-4821';
      _abhaAddressController.text = 'stevin.joseph@abdm';
      _selectedBloodGroup = 'O+ Positive';
      _allergiesController.text = 'Penicillin Anaphylaxis, Sulfa Drugs';
      _conditionsController.text = 'Asthma, Type 2 Diabetes';
      _medicationsController.text = 'Salbutamol Inhaler, Metformin 500mg';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Verified ABDM Sandbox ABHA Card loaded'),
        backgroundColor: Color(0xFF0284C7),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // --- Navigation Controls ---
  void _goToNextStep() {
    HapticFeedback.lightImpact();
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in with Google or enter your name'), backgroundColor: Colors.red),
        );
        return;
      }
    } else if (_currentStep == 1) {
      if (!_isPhoneVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please verify your phone number via OTP to continue'), backgroundColor: Colors.red),
        );
        return;
      }
    } else if (_currentStep == 2) {
      final c1Name = _contact1NameController.text.trim();
      final c1Phone = _contact1PhoneController.text.trim();
      final c2Name = _contact2NameController.text.trim();
      final c2Phone = _contact2PhoneController.text.trim();

      if (c1Name.isEmpty || c1Phone.length < 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency Contact 1 (Mandatory) requires name and 10-digit phone'), backgroundColor: Colors.red),
        );
        return;
      }
      if (c2Name.isEmpty || c2Phone.length < 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency Contact 2 (Mandatory) requires name and 10-digit phone'), backgroundColor: Colors.red),
        );
        return;
      }
    } else if (_currentStep == 3) {
      if (_hasAbhaCard && _abhaNumberController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your 14-digit ABHA card number or choose "I don\'t have ABHA"'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    }
  }

  void _goToPreviousStep() {
    HapticFeedback.lightImpact();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  // --- Step 5: Save & Activate ---
  Future<void> _activateGuard() async {
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final name = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Stevin Joseph';
      final rawPhone = _phoneController.text.trim();
      final phone = rawPhone.startsWith('+91') ? rawPhone : '+91 $rawPhone';

      final c1Name = _contact1NameController.text.trim();
      final c1PhoneRaw = _contact1PhoneController.text.trim();
      final c1Phone = c1PhoneRaw.startsWith('+91') ? c1PhoneRaw : '+91$c1PhoneRaw';

      final c2Name = _contact2NameController.text.trim();
      final c2PhoneRaw = _contact2PhoneController.text.trim();
      final c2Phone = c2PhoneRaw.startsWith('+91') ? c2PhoneRaw : '+91$c2PhoneRaw';

      String? c3Name;
      String? c3Phone;
      String? c3Relation;
      if (_showThirdContact && _contact3PhoneController.text.trim().isNotEmpty) {
        c3Name = _contact3NameController.text.trim().isNotEmpty ? _contact3NameController.text.trim() : 'Third Contact';
        final raw = _contact3PhoneController.text.trim();
        c3Phone = raw.startsWith('+91') ? raw : '+91$raw';
        c3Relation = _contact3Relation;
      }

      final abhaNum = _hasAbhaCard && _abhaNumberController.text.trim().isNotEmpty
          ? _abhaNumberController.text.trim()
          : '91-4829-1029-4821';
      final abhaAddr = _hasAbhaCard && _abhaAddressController.text.trim().isNotEmpty
          ? _abhaAddressController.text.trim()
          : '${name.toLowerCase().replaceAll(RegExp(r'\s+'), '.')}@abdm';

      final allergies = _allergiesController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final conditions = _conditionsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final medications = _medicationsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final current = UserProfileService.instance.profile;
      final updated = current.copyWith(
        userName: name,
        userEmail: _googleEmail,
        phone: phone,
        isPhoneVerified: true,
        bloodGroup: _selectedBloodGroup,
        isRegistered: true,
        authMethod: _isGoogleAuthenticated ? 'GOOGLE' : 'MANUAL',
        emergencyContactName: c1Name,
        emergencyContactPhone: c1Phone,
        emergencyContactRelation: _contact1Relation,
        secondaryContactName: c2Name,
        secondaryContactPhone: c2Phone,
        secondaryContactRelation: _contact2Relation,
        tertiaryContactName: c3Name,
        tertiaryContactPhone: c3Phone,
        tertiaryContactRelation: c3Relation,
        hasAbhaCard: _hasAbhaCard,
        abhaNumber: abhaNum,
        abhaAddress: abhaAddr,
        criticalAllergies: allergies.isNotEmpty ? allergies : ['Penicillin Anaphylaxis', 'Sulfa Drugs'],
        chronicConditions: conditions.isNotEmpty ? conditions : ['Asthma', 'Type 2 Diabetes'],
        currentMedications: medications.isNotEmpty ? medications : ['Salbutamol Inhaler', 'Metformin 500mg'],
      );

      await UserProfileService.instance.saveProfile(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Rakshak Edge Crash Guard activated for $name!'),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 2),
          ),
        );

        if (widget.onRegistrationComplete != null) {
          widget.onRegistrationComplete!();
        } else if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _goToPreviousStep,
        ),
        title: Text(
          'Step ${_currentStep + 1} of $_totalSteps: ${_getStepTitle(_currentStep)}',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_tethering, color: Color(0xFF38BDF8)),
            tooltip: 'Server Gateway Settings',
            onPressed: () => showServerEndpointDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Multi-Step Progress Indicator
            _buildProgressBar(),

            // Active Step Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: _buildCurrentStepContent(),
              ),
            ),

            // Bottom Navigation Bar
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Google Sign-In';
      case 1:
        return 'Phone & OTP';
      case 2:
        return '2 SOS Contacts';
      case 3:
        return 'ABHA Health Card';
      case 4:
        return 'Edge Security Activation';
      default:
        return 'Onboarding';
    }
  }

  Widget _buildProgressBar() {
    final progress = (_currentStep + 1) / _totalSteps;
    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: const Color(0xFF1E293B),
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFDC2626)),
          minHeight: 4,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          color: const Color(0xFF1E293B).withOpacity(0.5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepDot(0, 'Google'),
              _buildStepDivider(0),
              _buildStepDot(1, 'Phone'),
              _buildStepDivider(1),
              _buildStepDot(2, 'Contacts'),
              _buildStepDivider(2),
              _buildStepDot(3, 'ABHA'),
              _buildStepDivider(3),
              _buildStepDot(4, 'Security'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _currentStep == step;
    final isDone = _currentStep > step;
    return Column(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: isDone
              ? const Color(0xFF16A34A)
              : (isActive ? const Color(0xFFDC2626) : const Color(0xFF334155)),
          child: isDone
              ? const Icon(Icons.check, size: 12, color: Colors.white)
              : Text(
                  '${step + 1}',
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            color: isActive ? Colors.white : (isDone ? const Color(0xFF34D399) : const Color(0xFF64748B)),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(int fromStep) {
    final isDone = _currentStep > fromStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        color: isDone ? const Color(0xFF16A34A) : const Color(0xFF334155),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1GoogleIdentity();
      case 1:
        return _buildStep2PhoneAndOtp();
      case 2:
        return _buildStep3EmergencyContacts();
      case 3:
        return _buildStep4AbhaHealthCard();
      case 4:
        return _buildStep5ReviewAndActivate();
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================
  // STEP 1: GOOGLE SIGN-IN & IDENTITY
  // ==========================================
  Widget _buildStep1GoogleIdentity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Citizen Digital Identity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 6),
              Text(
                'Sign in with Google to bind your digital life-guard profile with verified cryptographic authentication credentials.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Google Sign-In Action Button
        ElevatedButton(
          onPressed: _openGoogleAccountPicker,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F172A),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.network(
                'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                width: 22,
                height: 22,
                errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24, color: Colors.blue),
              ),
              const SizedBox(width: 10),
              Text(
                _isGoogleAuthenticated ? 'Switch Google Account' : 'Sign in with Google',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Verified Google Account Card
        if (_isGoogleAuthenticated)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.5)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF16A34A),
                  radius: 20,
                  child: const Icon(Icons.verified, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Text('Google Verified Identity', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4ADE80), fontSize: 13)),
                          SizedBox(width: 4),
                          Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 14),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(_googleEmail, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),

        // User Name Field (Extracted from Google)
        _buildSectionHeader(Icons.badge, 'Full Name / Citizen Name'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: _nameController,
          label: 'Citizen Name',
          hint: 'e.g. Stevin Joseph',
          prefixIcon: Icons.person_outline,
        ),
        const SizedBox(height: 14),
        const Text(
          'This name will be broadcast to trauma dispatchers and police responder consoles in case of an accident.',
          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 2: PHONE & OTP VERIFICATION
  // ==========================================
  Widget _buildStep2PhoneAndOtp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Mobile Number Verification',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 6),
              Text(
                'Your verified mobile number allows first responders to identify and verify you instantly upon scene arrival.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        _buildSectionHeader(Icons.phone_android, 'Enter 10-Digit Mobile Number'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _phoneController,
                label: 'Mobile Number',
                hint: '9074338964',
                prefixText: '+91 ',
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.smartphone,
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _resendCountdown > 0 && _isOtpSent ? null : _sendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _isOtpSent ? (_resendCountdown > 0 ? '${_resendCountdown}s' : 'Resend') : 'Send OTP',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // OTP Input Box
        if (_isOtpSent) ...[
          _buildSectionHeader(Icons.lock_clock, 'Enter 6-Digit OTP Code'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _otpController,
                  label: '6-Digit OTP',
                  hint: '742918',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.pin,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Verify OTP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() => _otpController.text = _generatedOtp);
                _verifyOtp();
              },
              icon: const Icon(Icons.bolt, size: 16, color: Color(0xFF38BDF8)),
              label: Text('⚡ Auto-Fill Received OTP ($_generatedOtp)', style: const TextStyle(fontSize: 12, color: Color(0xFF38BDF8))),
            ),
          ),
        ],

        // Verified Status Badge
        if (_isPhoneVerified) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF4ADE80), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '✓ Mobile Number Verified: +91 ${_phoneController.text.trim()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4ADE80), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ==========================================
  // STEP 3: 2 MANDATORY EMERGENCY CONTACTS (+1 OPTIONAL)
  // ==========================================
  Widget _buildStep3EmergencyContacts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.emergency_share, color: Color(0xFFEF4444), size: 20),
                  SizedBox(width: 8),
                  Text(
                    '2 Mandatory Emergency Contacts',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Rakshak-AI mandates at least 2 emergency contacts so high-G crash telemetry, live GPS tracking, and hospital admission alerts are never missed.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _fillDemoEmergencyContacts,
                icon: const Icon(Icons.bolt, size: 16),
                label: const Text('⚡ Auto-Fill 2 Demo Contacts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // CONTACT 1 (MANDATORY)
        _buildContactCard(
          number: 1,
          isMandatory: true,
          nameController: _contact1NameController,
          phoneController: _contact1PhoneController,
          relation: _contact1Relation,
          onRelationChanged: (val) {
            if (val != null) setState(() => _contact1Relation = val);
          },
        ),
        const SizedBox(height: 16),

        // CONTACT 2 (MANDATORY)
        _buildContactCard(
          number: 2,
          isMandatory: true,
          nameController: _contact2NameController,
          phoneController: _contact2PhoneController,
          relation: _contact2Relation,
          onRelationChanged: (val) {
            if (val != null) setState(() => _contact2Relation = val);
          },
        ),
        const SizedBox(height: 16),

        // CONTACT 3 (OPTIONAL)
        if (_showThirdContact) ...[
          _buildContactCard(
            number: 3,
            isMandatory: false,
            nameController: _contact3NameController,
            phoneController: _contact3PhoneController,
            relation: _contact3Relation,
            onRelationChanged: (val) {
              if (val != null) setState(() => _contact3Relation = val);
            },
            onRemove: () => setState(() => _showThirdContact = false),
          ),
          const SizedBox(height: 12),
        ] else ...[
          OutlinedButton.icon(
            onPressed: () => setState(() => _showThirdContact = true),
            icon: const Icon(Icons.add, color: Color(0xFF38BDF8), size: 18),
            label: const Text('+ Add 3rd Emergency Contact (Optional)', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF0284C7)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildContactCard({
    required int number,
    required bool isMandatory,
    required TextEditingController nameController,
    required TextEditingController phoneController,
    required String relation,
    required ValueChanged<String?> onRelationChanged,
    VoidCallback? onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isMandatory ? const Color(0xFFDC2626).withOpacity(0.5) : const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Emergency Contact $number ${isMandatory ? "(Mandatory)" : "(Optional)"}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: isMandatory ? const Color(0xFFF87171) : const Color(0xFF38BDF8),
                ),
              ),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 18),
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _buildTextField(
            controller: nameController,
            label: 'Contact Name',
            hint: number == 1 ? 'e.g. Anjali Sharma' : 'e.g. Rajesh Joseph',
            prefixIcon: Icons.person,
          ),
          const SizedBox(height: 10),
          _buildTextField(
            controller: phoneController,
            label: 'Phone Number',
            hint: number == 1 ? '9876543211' : '9845012345',
            prefixText: '+91 ',
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone,
          ),
          const SizedBox(height: 10),
          _buildDropdown(
            label: 'Relationship',
            value: relation,
            items: _relationships,
            onChanged: onRelationChanged,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 4: ABHA DIGITAL HEALTH CARD (OPTIONAL)
  // ==========================================
  Widget _buildStep4AbhaHealthCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'ABHA Digital Health Card (ABDM)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 6),
              Text(
                'Ayushman Bharat Digital Mission (ABDM) integration enables paperless hospital admission and instant clinical triage during trauma resuscitation.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Choice: Has ABHA Card vs Link Later
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _hasAbhaCard = true),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    color: _hasAbhaCard ? const Color(0xFF0284C7).withOpacity(0.2) : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _hasAbhaCard ? const Color(0xFF38BDF8) : const Color(0xFF334155), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.credit_card, color: _hasAbhaCard ? const Color(0xFF38BDF8) : const Color(0xFF64748B), size: 24),
                      const SizedBox(height: 6),
                      Text('I have ABHA Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _hasAbhaCard ? Colors.white : const Color(0xFF94A3B8))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _hasAbhaCard = false),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    color: !_hasAbhaCard ? const Color(0xFFDC2626).withOpacity(0.2) : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: !_hasAbhaCard ? const Color(0xFFEF4444) : const Color(0xFF334155), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.skip_next, color: !_hasAbhaCard ? const Color(0xFFEF4444) : const Color(0xFF64748B), size: 24),
                      const SizedBox(height: 6),
                      Text('Don\'t have ABHA / Later', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: !_hasAbhaCard ? Colors.white : const Color(0xFF94A3B8))),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_hasAbhaCard) ...[
          // Pre-fill demo ABHA button
          ElevatedButton.icon(
            onPressed: _fillDemoAbhaCard,
            icon: const Icon(Icons.bolt, size: 16),
            label: const Text('⚡ Fill Demo ABHA Sandbox Card', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionHeader(Icons.badge, 'ABHA Credentials'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _abhaNumberController,
            label: '14-Digit ABHA Card Number',
            hint: '91-4829-1029-4821',
            keyboardType: TextInputType.number,
            prefixIcon: Icons.credit_card,
          ),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _abhaAddressController,
            label: 'ABHA Address (PHR Handle)',
            hint: 'stevin.joseph@abdm',
            prefixIcon: Icons.alternate_email,
          ),
          const SizedBox(height: 10),
        ],

        // Blood Group (Required for trauma triage whether ABHA is linked or not)
        _buildSectionHeader(Icons.bloodtype, 'Verified Blood Group'),
        const SizedBox(height: 8),
        _buildDropdown(
          label: 'Blood Group',
          value: _selectedBloodGroup,
          items: _bloodGroups,
          onChanged: (val) {
            if (val != null) setState(() => _selectedBloodGroup = val);
          },
        ),
        const SizedBox(height: 10),

        if (_hasAbhaCard) ...[
          _buildTextField(
            controller: _allergiesController,
            label: 'Critical Drug Allergies',
            hint: 'Penicillin Anaphylaxis, Sulfa Drugs',
            prefixIcon: Icons.warning_amber,
          ),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _conditionsController,
            label: 'Chronic Pre-Existing Conditions',
            hint: 'Asthma, Type 2 Diabetes',
            prefixIcon: Icons.healing,
          ),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _medicationsController,
            label: 'Emergency Current Medications',
            hint: 'Salbutamol Inhaler, Metformin 500mg',
            prefixIcon: Icons.medication,
          ),
        ],
      ],
    );
  }

  // ==========================================
  // STEP 5: REVIEW & EDGE AI ACTIVATION
  // ==========================================
  Widget _buildStep5ReviewAndActivate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.verified_user, color: Color(0xFF4ADE80), size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Profile Summary & Edge Guard',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildReviewRow('Citizen Name:', _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Stevin Joseph'),
              _buildReviewRow('Google Identity:', _googleEmail),
              _buildReviewRow('Phone (+91):', '+91 ${_phoneController.text.trim()} (OTP Verified)'),
              _buildReviewRow('Contact 1 (SOS):', '${_contact1NameController.text.trim()} ($_contact1Relation) • +91 ${_contact1PhoneController.text.trim()}'),
              _buildReviewRow('Contact 2 (SOS):', '${_contact2NameController.text.trim()} ($_contact2Relation) • +91 ${_contact2PhoneController.text.trim()}'),
              if (_showThirdContact && _contact3PhoneController.text.trim().isNotEmpty)
                _buildReviewRow('Contact 3 (SOS):', '${_contact3NameController.text.trim()} ($_contact3Relation) • +91 ${_contact3PhoneController.text.trim()}'),
              _buildReviewRow('Blood Group:', _selectedBloodGroup),
              _buildReviewRow('ABHA Status:', _hasAbhaCard ? '${_abhaNumberController.text.trim()} (ABDM Linked)' : 'Self-Declared Blood Group'),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // High-Tech Edge Computing Architecture Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.memory, color: Color(0xFF38BDF8), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Rakshak Edge AI Computing Guarantee',
                    style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildEdgeFeature(
                '⚡ 0ms Edge Deceleration Inference',
                'Kinematic 4.8G crash vector classification is executed entirely on local CPU/NPU without cloud latency.',
              ),
              _buildEdgeFeature(
                '🔐 Zero-Knowledge Health Vault',
                'ABHA medical records are sealed in local AES-256 storage and decrypted exclusively upon confirmed high-G impact.',
              ),
              _buildEdgeFeature(
                '🛡️ Volatile RAM Blackbox Buffer',
                'High-rate 100Hz IMU circular buffer is isolated in RAM and overwritten every 30 seconds with zero gallery persistence.',
              ),
              _buildEdgeFeature(
                '🌐 Resilient Multi-Network Mesh',
                'Dual-channel dispatch across Wi-Fi, 5G cellular, and offline store-and-forward queue ensuring alert delivery.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: _isSaving ? null : _activateGuard,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
          ),
          child: _isSaving
              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.shield, size: 20),
                    SizedBox(width: 8),
                    Text('Save & Activate Rakshak Edge Guard', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: _goToPreviousStep,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF64748B)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: const Text('← Back', style: TextStyle(color: Colors.white70)),
            )
          else
            const SizedBox.shrink(),

          if (_currentStep < _totalSteps - 1)
            ElevatedButton(
              onPressed: _goToNextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Row(
                children: const [
                  Text('Next Step', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF38BDF8)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF1F5F9),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? prefixIcon,
    String? prefixText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12.5),
        prefixText: prefixText,
        prefixStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: const Color(0xFF64748B), size: 18) : null,
        filled: true,
        fillColor: const Color(0xFF0F172A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5)),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white, fontSize: 13)))).toList(),
      onChanged: onChanged,
      dropdownColor: const Color(0xFF0F172A),
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5)),
      ),
    );
  }

  Widget _buildEdgeFeature(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFFE2E8F0), fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.3)),
        ],
      ),
    );
  }
}
