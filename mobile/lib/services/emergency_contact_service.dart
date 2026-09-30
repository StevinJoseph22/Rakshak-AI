// Privacy note: Emergency contact data is the victim's own chosen contact,
// stored locally on-device and only sent alongside an actual confirmed incident dispatch
// via victim_metadata. It is never stored in a standalone contacts table or cached
// in Redis alongside temporary photos.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_contact_model.dart';

class EmergencyContactService {
  EmergencyContactService._internal();
  static final EmergencyContactService _instance = EmergencyContactService._internal();
  static EmergencyContactService get instance => _instance;

  static const String _keyContacts = 'rakshak_emergency_contacts_v1';
  static const String _keyVictimName = 'rakshak_victim_name_v1';

  // In-memory cache pre-seeded with defaults for instant synchronous access
  List<EmergencyContact> _cachedContacts = List.from(defaultDemoContacts);
  String _cachedVictimName = defaultDemoVictimName;

  /// Synchronous accessors for UI and test stability
  bool get hasContactsSync => _cachedContacts.isNotEmpty;
  EmergencyContact? get primaryContactSync =>
      _cachedContacts.isEmpty ? null : _cachedContacts.firstWhere((c) => c.isPrimary, orElse: () => _cachedContacts.first);
  String get victimNameSync => _cachedVictimName;

  /// Default demo seed if user hasn't configured any contacts yet
  static final List<EmergencyContact> defaultDemoContacts = [
    const EmergencyContact(
      id: 'default-1',
      name: 'Priya Sharma',
      phone: '+919876543210',
      relationship: 'Sister',
      isPrimary: true,
    ),
    const EmergencyContact(
      id: 'default-2',
      name: 'Rajesh Verma',
      phone: '+919812345678',
      relationship: 'Father',
      isPrimary: false,
    ),
  ];

  static const String defaultDemoVictimName = 'Rahul Verma';

  /// Loads emergency contacts from SharedPreferences (or seeds defaults on first run)
  Future<List<EmergencyContact>> getContacts() async {
    if (_cachedContacts != null) {
      return List.unmodifiable(_cachedContacts!);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_keyContacts);
      if (rawJson != null && rawJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(rawJson) as List<dynamic>;
        _cachedContacts = decoded
            .map((item) => EmergencyContact.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        // First run: seed demo contacts
        _cachedContacts = List.from(defaultDemoContacts);
        await saveContacts(_cachedContacts!);
      }
    } catch (e) {
      debugPrint('[EmergencyContactService] Error reading contacts: $e');
      _cachedContacts = List.from(defaultDemoContacts);
    }

    return List.unmodifiable(_cachedContacts!);
  }

  /// Saves contacts list to SharedPreferences
  Future<void> saveContacts(List<EmergencyContact> contacts) async {
    _cachedContacts = List.from(contacts);
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = jsonEncode(contacts.map((c) => c.toJson()).toList());
      await prefs.setString(_keyContacts, rawJson);
      debugPrint('[EmergencyContactService] Saved ${contacts.length} emergency contacts locally');
    } catch (e) {
      debugPrint('[EmergencyContactService] Error saving contacts: $e');
    }
  }

  /// Adds a new contact
  Future<void> addContact(EmergencyContact contact) async {
    final current = List<EmergencyContact>.from(await getContacts());
    current.add(contact);
    await saveContacts(current);
  }

  /// Deletes a contact by ID
  Future<void> deleteContact(String id) async {
    final current = List<EmergencyContact>.from(await getContacts());
    current.removeWhere((c) => c.id == id);
    await saveContacts(current);
  }

  /// Gets the registered device owner/victim's name
  Future<String> getVictimName() async {
    if (_cachedVictimName != null) {
      return _cachedVictimName!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_keyVictimName);
      _cachedVictimName = (name != null && name.trim().isNotEmpty) ? name.trim() : defaultDemoVictimName;
    } catch (e) {
      _cachedVictimName = defaultDemoVictimName;
    }
    return _cachedVictimName!;
  }

  /// Updates the registered device owner/victim's name
  Future<void> setVictimName(String name) async {
    _cachedVictimName = name.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyVictimName, _cachedVictimName!);
    } catch (e) {
      debugPrint('[EmergencyContactService] Error saving victim name: $e');
    }
  }

  /// Quick check whether at least 1 contact is configured
  Future<bool> hasContacts() async {
    final contacts = await getContacts();
    return contacts.isNotEmpty;
  }

  /// Returns primary contact (or first contact)
  Future<EmergencyContact?> getPrimaryContact() async {
    final contacts = await getContacts();
    if (contacts.isEmpty) return null;
    return contacts.firstWhere((c) => c.isPrimary, orElse: () => contacts.first);
  }
}
