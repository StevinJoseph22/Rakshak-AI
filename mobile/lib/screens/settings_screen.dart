import 'package:flutter/material.dart';
import '../models/emergency_health_card_model.dart';
import '../services/health_card_storage_service.dart';
import '../services/abdm_mobile_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  EmergencyHealthCard? _card;
  bool _isLoading = true;
  String _abdmMode = 'MOCK';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bloodController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _conditionsController = TextEditingController();
  final TextEditingController _medicationsController = TextEditingController();
  bool _isOrganDonor = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bloodController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    _medicationsController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final card = await HealthCardStorageService.instance.getHealthCard();
    final mode = await AbdmMobileService.instance.getGatewayMode();

    if (mounted) {
      setState(() {
        _card = card;
        _abdmMode = mode;
        _isLoading = false;

        // Pre-fill editable fields if self-declared
        if (card.name.isSelfDeclared && card.name.value != null) {
          _nameController.text = card.name.value!;
        }
        if (card.bloodGroup.isSelfDeclared && card.bloodGroup.value != null) {
          _bloodController.text = card.bloodGroup.value!;
        }
        if (card.allergies.isSelfDeclared && card.allergies.value != null) {
          _allergiesController.text = card.allergies.value!.join(', ');
        }
        if (card.chronicConditions.isSelfDeclared && card.chronicConditions.value != null) {
          _conditionsController.text = card.chronicConditions.value!.join(', ');
        }
        if (card.currentMedications.isSelfDeclared && card.currentMedications.value != null) {
          _medicationsController.text = card.currentMedications.value!.join(', ');
        }
        if (card.organDonorStatus.isSelfDeclared && card.organDonorStatus.value != null) {
          _isOrganDonor = true;
        }
      });
    }
  }

  Future<void> _saveSelfDeclared() async {
    final name = _nameController.text.trim();
    final blood = _bloodController.text.trim();
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

    await HealthCardStorageService.instance.saveSelfDeclaredData(
      name: name.isNotEmpty ? name : null,
      bloodGroup: blood.isNotEmpty ? blood : null,
      allergies: allergies.isNotEmpty ? allergies : null,
      conditions: conditions.isNotEmpty ? conditions : null,
      medications: medications.isNotEmpty ? medications : null,
      organDonor: _isOrganDonor ? 'Registered Organ Donor (Self-Declared)' : null,
    );

    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Self-declared health data updated (labelled "not verified").'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _confirmUnlink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Unlink & Wipe Health Data?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will purge all local emergency health records and unlink your ABHA address from this device and the backend server.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            key: const Key('confirm_dialog_unlink_button'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Unlink & Wipe', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await HealthCardStorageService.instance.unlinkAndDelete();
      _nameController.clear();
      _bloodController.clear();
      _allergiesController.clear();
      _conditionsController.clear();
      _medicationsController.clear();
      _isOrganDonor = false;
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ABHA unlinked and all emergency health data wiped.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Emergency Health Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Header Card
                  _buildStatusCard(),
                  const SizedBox(height: 20),

                  // Health Card Field Provenance Overview
                  _buildFieldProvenanceOverview(),
                  const SizedBox(height: 24),

                  // Self-Declared Entry Form
                  _buildSelfDeclaredForm(),
                  const SizedBox(height: 24),

                  // One-Tap Unlink Button
                  OutlinedButton.icon(
                    key: const Key('settings_unlink_button'),
                    icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                    label: const Text('One-Tap Unlink & Wipe Health Data', style: TextStyle(color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _confirmUnlink,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final bool isLinked = _card?.isLinked ?? false;
    final String? address = _card?.abhaAddress.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isLinked ? Colors.green.shade700 : const Color(0xFF334155)),
      ),
      child: Row(
        children: [
          Icon(
            isLinked ? Icons.verified : Icons.link_off,
            color: isLinked ? Colors.greenAccent : Colors.amberAccent,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLinked ? 'ABHA Linked & Active' : 'ABHA Not Linked (Optional)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  isLinked
                      ? 'Address: $address'
                      : 'Emergency triage will rely on self-declared data or hospital trauma diagnostics.',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldProvenanceOverview() {
    if (_card == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EMERGENCY HEALTH CARD PROVENANCE',
            style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _provenanceRow('Full Name', _card!.name),
          _provenanceRow('Age & Gender', _card!.ageGender),
          _provenanceRow('ABHA Address', _card!.abhaAddress),
          _provenanceRow('Blood Group', _card!.bloodGroup),
          _provenanceListRow('Drug Allergies', _card!.allergies),
          _provenanceListRow('Chronic Conditions', _card!.chronicConditions),
          _provenanceListRow('Current Medications', _card!.currentMedications),
          _provenanceRow('Organ Donor', _card!.organDonorStatus),
        ],
      ),
    );
  }

  Widget _provenanceRow(String label, HealthCardField<String> field) {
    final displayValue = field.isAvailable ? (field.value ?? '—') : (field.reason ?? 'Not available');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(
                color: field.isAvailable ? Colors.white : const Color(0xFF64748B),
                fontSize: 12,
                fontWeight: field.isAvailable ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _buildChip(field.source, field.status),
        ],
      ),
    );
  }

  Widget _provenanceListRow(String label, HealthCardField<List<String>> field) {
    final displayValue = field.isAvailable
        ? ((field.value != null && field.value!.isNotEmpty) ? field.value!.join(', ') : 'None')
        : (field.reason ?? 'Not available');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(
                color: field.isAvailable ? Colors.white : const Color(0xFF64748B),
                fontSize: 12,
                fontWeight: field.isAvailable ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _buildChip(field.source, field.status),
        ],
      ),
    );
  }

  Widget _buildChip(String source, String status) {
    if (status == 'NOT_AVAILABLE') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF334155),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Not Available',
          style: TextStyle(color: Colors.white70, fontSize: 9),
        ),
      );
    }

    if (source == 'ABDM_VERIFIED') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.shade900,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.greenAccent, width: 0.5),
        ),
        child: const Text('ABDM Verified', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.amber.shade900,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.amberAccent, width: 0.5),
      ),
      child: const Text('Self-Declared', style: TextStyle(color: Colors.amberAccent, fontSize: 9)),
    );
  }

  Widget _buildSelfDeclaredForm() {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'SELF-DECLARED EMERGENCY HEALTH INFO',
            style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),
          const Text(
            'Fields updated here will be marked "Self-Declared (Not Verified)" and dispatched only during crash emergencies.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('settings_name_field'),
            controller: _nameController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDecoration('Preferred / Legal Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('settings_blood_field'),
            controller: _bloodController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDecoration('Blood Group (e.g. O+, B+)'),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('settings_allergies_field'),
            controller: _allergiesController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDecoration('Critical Drug Allergies (comma-separated)'),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('settings_conditions_field'),
            controller: _conditionsController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDecoration('Chronic Medical Conditions'),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('settings_medications_field'),
            controller: _medicationsController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: _inputDecoration('Current Medications (e.g. Blood Thinners)'),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            key: const Key('settings_donor_switch'),
            title: const Text('Registered NOTTO Organ Donor', style: TextStyle(color: Colors.white, fontSize: 13)),
            value: _isOrganDonor,
            activeColor: const Color(0xFF38BDF8),
            onChanged: (val) => setState(() => _isOrganDonor = val),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            key: const Key('settings_save_button'),
            onPressed: _saveSelfDeclared,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Save Health Profile', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ),
  );
}

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF38BDF8))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }
}
