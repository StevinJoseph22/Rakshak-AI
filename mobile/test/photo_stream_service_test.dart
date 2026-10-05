import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:rakshak_mobile/services/photo_stream_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

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

    test('simulates WebRTC negotiation timeout and confirms fallback path delivers image correctly', () async {
      final service = PhotoStreamService.instance;
      final testBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);

      // Spin up local mock HTTP server to simulate backend fallback endpoint
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) async {
        try {
          if (request.uri.path.contains('/image') && request.method == 'POST') {
            await request.drain();
            request.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'status': 'ok'}));
            await request.response.close();
          } else {
            request.response
              ..statusCode = HttpStatus.notFound;
            await request.response.close();
          }
        } catch (_) {
          try {
            request.response.statusCode = HttpStatus.internalServerError;
            await request.response.close();
          } catch (_) {}
        }
      });

      final localUrl = 'http://${server.address.host}:${server.port}';

      try {
        // Force WebRTC timeout, verifying fallback path delivers image seamlessly
        PhotoStreamService.forceWebRtcTimeoutForTesting = true;
        PhotoStreamService.lastUsedTransport = 'none';

        final result = await service.streamIncidentPhoto(
          incidentId: 'test-fallback-incident',
          imageBytes: testBytes,
          candidateUrls: [localUrl],
          timeout: const Duration(milliseconds: 400),
        );

        expect(result, isTrue);
        expect(PhotoStreamService.lastUsedTransport, isNot(equals('webrtc')));
        expect(PhotoStreamService.lastUsedTransport, equals('http'));
      } finally {
        PhotoStreamService.forceWebRtcTimeoutForTesting = false;
        await server.close(force: true);
      }
    });
  });
}
