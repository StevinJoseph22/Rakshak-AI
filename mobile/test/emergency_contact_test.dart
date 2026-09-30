import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rakshak_mobile/models/emergency_contact_model.dart';
import 'package:rakshak_mobile/services/emergency_contact_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EmergencyContact & EmergencyContactService Tests', () {
    test('EmergencyContact serialization and deserialization', () {
      const contact = EmergencyContact(
        id: 'test-1',
        name: 'Jane Doe',
        phone: '+919999888877',
        relationship: 'Spouse',
        isPrimary: true,
      );

      final json = contact.toJson();
      expect(json['id'], 'test-1');
      expect(json['name'], 'Jane Doe');
      expect(json['phone'], '+919999888877');
      expect(json['relationship'], 'Spouse');
      expect(json['is_primary'], true);

      final parsed = EmergencyContact.fromJson(json);
      expect(parsed.id, contact.id);
      expect(parsed.name, contact.name);
      expect(parsed.phone, contact.phone);
      expect(parsed.relationship, contact.relationship);
      expect(parsed.isPrimary, isTrue);
    });

    test('EmergencyContactService default seeding and synchronous accessors', () async {
      final service = EmergencyContactService.instance;
      expect(service.hasContactsSync, isTrue);
      expect(service.victimNameSync, 'Rahul Verma');
      expect(service.primaryContactSync?.name, 'Priya Sharma');

      final contacts = await service.getContacts();
      expect(contacts.length, greaterThanOrEqualTo(1));
    });

    test('EmergencyContactService add and delete contact', () async {
      final service = EmergencyContactService.instance;
      const newContact = EmergencyContact(
        id: 'unit-test-add',
        name: 'Vikram Singh',
        phone: '+919123456789',
        relationship: 'Brother',
      );

      await service.addContact(newContact);
      var current = await service.getContacts();
      expect(current.any((c) => c.id == 'unit-test-add'), isTrue);

      await service.deleteContact('unit-test-add');
      current = await service.getContacts();
      expect(current.any((c) => c.id == 'unit-test-add'), isFalse);
    });

    test('EmergencyContactService victim name persistence', () async {
      final service = EmergencyContactService.instance;
      await service.setVictimName('Ananya Roy');
      expect(await service.getVictimName(), 'Ananya Roy');
      expect(service.victimNameSync, 'Ananya Roy');

      // Reset
      await service.setVictimName(EmergencyContactService.defaultDemoVictimName);
    });
  });
}
