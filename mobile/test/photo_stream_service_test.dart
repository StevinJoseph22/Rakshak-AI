import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:rakshak_mobile/services/photo_stream_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhotoStreamService Tests', () {
    test('singleton instance is non-null and accessible', () {
      final service1 = PhotoStreamService.instance;
      final service2 = PhotoStreamService.instance;
      expect(service1, isNotNull);
      expect(service1, same(service2));
    });

    test('streamIncidentPhoto handles unreachable endpoints gracefully without throwing', () async {
      final service = PhotoStreamService.instance;
      final testBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]); // minimal JPEG header

      // Calling with an unreachable candidate URL and short timeout
      final result = await service.streamIncidentPhoto(
        incidentId: 'test-incident-uuid',
        imageBytes: testBytes,
        candidateUrls: ['http://127.0.0.1:59999'],
        timeout: const Duration(milliseconds: 300),
      );

      // Should return false gracefully without throwing unhandled exceptions
      expect(result, isFalse);
    });
  });
}
