import 'package:flutter/material.dart';
import '../models/emergency_contact_model.dart';
import '../services/emergency_contact_service.dart';
import '../services/user_profile_service.dart';
import 'emergency_contacts_screen.dart';
import 'settings_screen.dart';

class CitizenSettingsScreen extends StatefulWidget {
  const CitizenSettingsScreen({super.key});

  @override
  State<CitizenSettingsScreen> createState() => _CitizenSettingsScreenState();
}

class _CitizenSettingsScreenState extends State<CitizenSettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _modelController;
  late TextEditingController _plateController;
  late String _vehicleType;
  late String _bloodGroup;

  List<EmergencyContact> _contacts = [];
  bool _isLoadingContacts = true;

  final List<String> _bloodGroups = [
    'A+ Positive',
    'A- Negative',
    'B+ Positive',
    'B- Negative',
    'O+ Positive',
    'O- Negative',
    'AB+ Positive',
    'AB- Negative',
  ];

  @override
  void initState() {
    super.initState();
    final p = UserProfileService.instance.profile;
    _nameController = TextEditingController(text: p.userName);
    _phoneController = TextEditingController(text: p.phone);
    _modelController = TextEditingController(text: p.vehicleModel);
    _plateController = TextEditingController(text: p.vehiclePlate);
    _vehicleType = p.vehicleType;
    _bloodGroup = _bloodGroups.contains(p.bloodGroup) ? p.bloodGroup : 'B+ Positive';
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final list = await EmergencyContactService.instance.getContacts();
    if (mounted) {
      setState(() {
        _contacts = list;
        _isLoadingContacts = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _saveAndExit() async {
    final current = UserProfileService.instance.profile;
    final updated = current.copyWith(
      userName: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Stevin Joseph',
      phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : '+91 90743 38964',
      vehicleType: _vehicleType,
      vehicleModel: _modelController.text.trim().isNotEmpty ? _modelController.text.trim() : 'Yamaha MT-15',
      vehiclePlate: _plateController.text.trim().isNotEmpty ? _plateController.text.trim().toUpperCase() : 'KA-05-AB-1234',
      bloodGroup: _bloodGroup,
    );

    await UserProfileService.instance.saveProfile(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rider Profile & Vehicle settings saved successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Citizen App & Vehicle Settings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: _saveAndExit,
            child: const Text(
              'SAVE',
              style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF38BDF8), fontSize: 14),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Rider Identity
            _buildSectionHeader('RIDER & COMMUTER IDENTITY', Icons.person_outline),
            const SizedBox(height: 10),
            _buildCard(
              children: [
                _buildTextField(
                  label: 'Full Name',
                  controller: _nameController,
                  icon: Icons.badge_outlined,
                  hint: 'Enter your name (e.g. Stevin Joseph)',
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  label: 'Phone Number',
                  controller: _phoneController,
                  icon: Icons.phone_outlined,
                  hint: '+91 98765 43210',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                // Blood Group Dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Blood Group (Emergency Priority)', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _bloodGroup,
                          dropdownColor: const Color(0xFF1E293B),
                          isExpanded: true,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          items: _bloodGroups.map((bg) {
                            return DropdownMenuItem<String>(
                              value: bg,
                              child: Text(bg),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _bloodGroup = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 2: Connected Vehicle Configuration (Two-Wheeler vs Four-Wheeler)
            _buildSectionHeader('CONNECTED VEHICLE CONFIGURATION', Icons.directions_car_outlined),
            const SizedBox(height: 10),
            _buildCard(
              children: [
                const Text('Vehicle Classification', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildVehicleCategoryCard(
                        type: 'Two-Wheeler',
                        label: 'Two-Wheeler',
                        sub: 'Bike / Scooter',
                        icon: Icons.two_wheeler,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildVehicleCategoryCard(
                        type: 'Four-Wheeler',
                        label: 'Four-Wheeler',
                        sub: 'Car / Cab / SUV',
                        icon: Icons.directions_car,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  label: 'Vehicle Model / Brand',
                  controller: _modelController,
                  icon: Icons.commute_outlined,
                  hint: _vehicleType == 'Two-Wheeler' ? 'e.g. Yamaha MT-15 / Royal Enfield' : 'e.g. Hyundai Creta / Swift',
                ),
                const SizedBox(height: 14),
                _buildTextField(
                  label: 'Registration License Plate',
                  controller: _plateController,
                  icon: Icons.credit_card_outlined,
                  hint: 'e.g. KA-05-AB-1234',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 3: Emergency Contacts Quick Hub
            _buildSectionHeader('EMERGENCY SOS CONTACTS', Icons.sos),
            const SizedBox(height: 10),
            _buildCard(
              children: [
                Row(
                  children: [
                    const Icon(Icons.contact_phone, color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isLoadingContacts
                            ? 'Loading contacts...'
                            : '${_contacts.length} Registered Emergency Contacts',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Rakshak-AI automatically sends GSM emergency SMS with your live coordinates to these contacts upon high-G impact.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()),
                      );
                      _loadContacts();
                    },
                    icon: const Icon(Icons.edit, size: 16, color: Color(0xFF38BDF8)),
                    label: const Text(
                      'MANAGE EMERGENCY CONTACTS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF38BDF8)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 4: ABHA Medical ID & Health Card
            _buildSectionHeader('ABHA (AYUSHMAN BHARAT) HEALTH SETTINGS', Icons.health_and_safety),
            const SizedBox(height: 10),
            _buildCard(
              children: [
                Row(
                  children: [
                    const Icon(Icons.medical_information, color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'ABHA Emergency Health Vault',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage your verified ABDM profile, drug allergies (Penicillin, etc.), chronic conditions, and organ donation registry.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                    icon: const Icon(Icons.badge, size: 16, color: Color(0xFF10B981)),
                    label: const Text(
                      'OPEN ABHA HEALTH SETTINGS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF10B981)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF10B981)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saveAndExit,
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text(
                  'SAVE PROFILE & VEHICLE DETAILS',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF38BDF8), size: 18),
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF38BDF8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleCategoryCard({
    required String type,
    required String label,
    required String sub,
    required IconData icon,
  }) {
    final isSelected = _vehicleType == type;
    return InkWell(
      onTap: () => setState(() => _vehicleType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDC2626).withOpacity(0.18) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF334155),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 26, color: isSelected ? const Color(0xFFEF4444) : const Color(0xFF94A3B8)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
              ),
            ),
            Text(
              sub,
              style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
