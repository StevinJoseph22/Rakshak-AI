// Privacy note: Emergency contact data is the victim's own chosen contact,
// stored locally on-device and only sent alongside an actual confirmed incident dispatch
// via victim_metadata. It is never stored in a standalone contacts table or cached
// in Redis alongside temporary photos.

import 'package:flutter/material.dart';
import '../models/emergency_contact_model.dart';
import '../services/emergency_contact_service.dart';
import '../services/emergency_sms_service.dart';
import 'emergency_sms_preview_screen.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final _victimNameController = TextEditingController();
  List<EmergencyContact> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final contacts = await EmergencyContactService.instance.getContacts();
    final name = await EmergencyContactService.instance.getVictimName();
    if (mounted) {
      setState(() {
        _contacts = List.from(contacts);
        _victimNameController.text = name;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveVictimName() async {
    await EmergencyContactService.instance.setVictimName(_victimNameController.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rider profile name saved successfully')),
      );
    }
  }

  Future<void> _addOrEditContact({EmergencyContact? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    String relationship = existing?.relationship ?? 'Family';
    bool isPrimary = existing?.isPrimary ?? (_contacts.isEmpty);

    const relationshipOptions = [
      'Family',
      'Parent',
      'Father',
      'Mother',
      'Spouse',
      'Sibling',
      'Sister',
      'Brother',
      'Child',
      'Friend',
      'Guardian',
      'Other',
    ];

    if (!relationshipOptions.contains(relationship)) {
      relationship = 'Family';
    }

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(existing == null ? 'Add Emergency Contact' : 'Edit Contact'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'e.g. Priya Sharma',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number (with +91 or 10 digits)',
                      hintText: '+919876543210',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Please enter a phone number';
                      if (val.replaceAll(RegExp(r'[^0-9]'), '').length < 10) {
                        return 'Enter a valid 10-digit number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: relationshipOptions.contains(relationship) ? relationship : 'Family',
                    decoration: const InputDecoration(
                      labelText: 'Relationship',
                      prefixIcon: Icon(Icons.group),
                    ),
                    items: relationshipOptions
                        .map((rel) => DropdownMenuItem(value: rel, child: Text(rel)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDlgState(() => relationship = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Designate as Primary SOS Contact', style: TextStyle(fontSize: 13)),
                    value: isPrimary,
                    onChanged: (val) => setDlgState(() => isPrimary = val ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final newContact = EmergencyContact(
                    id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    relationship: relationship,
                    isPrimary: isPrimary,
                  );

                  List<EmergencyContact> updated = List.from(_contacts);
                  if (existing != null) {
                    final idx = updated.indexWhere((c) => c.id == existing.id);
                    if (idx != -1) updated[idx] = newContact;
                  } else {
                    updated.add(newContact);
                  }

                  // If this contact is primary, unmark others
                  if (isPrimary) {
                    updated = updated.map((c) => c.id == newContact.id ? c : c.copyWith(isPrimary: false)).toList();
                  }

                  await EmergencyContactService.instance.saveContacts(updated);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  _loadData();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteContact(String id) async {
    await EmergencyContactService.instance.deleteContact(id);
    _loadData();
  }

  void _triggerTestSmsPreview() {
    final message = EmergencySmsService.instance.buildCrashAlertMessage(
      victimName: _victimNameController.text.trim().isEmpty ? 'Rahul Verma' : _victimNameController.text.trim(),
      lat: 12.97160,
      lng: 77.59460,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EmergencySmsPreviewScreen(
          contacts: _contacts,
          message: message,
          alertType: 'CRASH_ALERT',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _victimNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_contacts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.preview_outlined),
              tooltip: 'Preview Test SMS',
              onPressed: _triggerTestSmsPreview,
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
                  // Privacy Shield Card
                  Container(
                    padding: const EdgeInsets.all(14.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'On-Device Privacy Protection',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF166534),
                                  fontSize: 13.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Emergency contacts are saved locally on this phone. They are never sent to third-party databases. When a crash is detected, your phone automatically notifies them via SIM SMS peer-to-peer and shares primary contact details with alerted trauma centers.',
                                style: TextStyle(color: Color(0xFF15803D), fontSize: 12, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Rider Profile Header
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rider Profile',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _victimNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Victim / Rider Name',
                                    hintText: 'e.g. Rahul Verma',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: _saveVictimName,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Contacts Section Title & Add Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Stored Contacts (${_contacts.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                      ),
                      TextButton.icon(
                        onPressed: () => _addOrEditContact(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Contact'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_contacts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 40, color: Colors.red.shade700),
                          const SizedBox(height: 10),
                          const Text(
                            'No Emergency Contacts Set Up',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Crash Guard requires at least one emergency contact to send SMS alerts during an accident. Please add a contact now.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _addOrEditContact(),
                            icon: const Icon(Icons.person_add),
                            label: const Text('Add First Contact'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._contacts.map((contact) => Card(
                          margin: const EdgeInsets.only(bottom: 10.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: contact.isPrimary ? Colors.red.shade300 : Colors.grey.shade200,
                              width: contact.isPrimary ? 1.5 : 1.0,
                            ),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: contact.isPrimary ? Colors.red.shade100 : Colors.grey.shade200,
                              foregroundColor: contact.isPrimary ? Colors.red.shade800 : Colors.grey.shade700,
                              child: const Icon(Icons.person),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    contact.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (contact.isPrimary) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Text(
                                      'PRIMARY',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.red.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              '${contact.relationship} • ${contact.phone}',
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 19),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _addOrEditContact(existing: contact),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 19, color: Colors.redAccent),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _deleteContact(contact.id),
                                ),
                              ],
                            ),
                          ),
                        )),

                  const SizedBox(height: 16),

                  // Test Preview Button
                  if (_contacts.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: _triggerTestSmsPreview,
                      icon: const Icon(Icons.message_outlined),
                      label: const Text('Test SMS / WhatsApp Preview'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
