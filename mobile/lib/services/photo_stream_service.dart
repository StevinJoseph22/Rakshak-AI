import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/backend_config.dart';

/// Service for streaming emergency crash visual triage telemetry directly
/// from volatile device RAM to the Rakshak-AI backend via WebSockets
/// with automatic dual-channel HTTP fallback.
///
/// STRICT ZERO-STORAGE PRIVACY GUARANTEE:
/// No image is ever written to device disk, SQLite, or gallery.
class PhotoStreamService {
  PhotoStreamService._internal();
  static final PhotoStreamService _instance = PhotoStreamService._internal();
  static PhotoStreamService get instance => _instance;

  /// Streams raw in-memory image bytes over a binary WebSocket frame or HTTP fallback.
  Future<bool> streamIncidentPhoto({
    required String incidentId,
    required Uint8List imageBytes,
    List<String>? candidateUrls,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    // 1. Resolve primary active backend URL
    final primaryUrl = await resolveReachableBackendUrl();
    final candidates = candidateUrls ?? <String>[
      primaryUrl,
      ...getBackendCandidates().where((u) => u != primaryUrl),
    ];

    final base64Image = base64Encode(imageBytes);

    for (final candidateUrl in candidates) {
      debugPrint(
        '[PhotoStreamService] Attempting photo stream via $candidateUrl for incident $incidentId...',
      );

      // Attempt Channel A: Socket.IO binary/base64 event with ack
      final wsSuccess = await _tryWebSocketStream(
        candidateUrl: candidateUrl,
        incidentId: incidentId,
        base64Image: base64Image,
        timeout: timeout,
      );

      if (wsSuccess) {
        debugPrint('[PhotoStreamService] Successfully streamed volatile photo via WebSocket to $candidateUrl');
        gActiveBackendUrl = candidateUrl;
        return true;
      }

      // Attempt Channel B: Dual-channel HTTP fallback for mobile networks
      debugPrint('[PhotoStreamService] WebSocket stream failed/timed out. Attempting HTTP POST fallback to $candidateUrl...');
      final httpSuccess = await _tryHttpStream(
        candidateUrl: candidateUrl,
        incidentId: incidentId,
        base64Image: base64Image,
        timeout: timeout,
      );

      if (httpSuccess) {
        debugPrint('[PhotoStreamService] Successfully streamed volatile photo via HTTP fallback to $candidateUrl');
        gActiveBackendUrl = candidateUrl;
        return true;
      }
    }

    debugPrint('[PhotoStreamService] Failed to stream photo across all candidate URLs.');
    return false;
  }

  Future<bool> _tryWebSocketStream({
    required String candidateUrl,
    required String incidentId,
    required String base64Image,
    required Duration timeout,
  }) async {
    final completer = Completer<bool>();
    io.Socket? socket;

    try {
      socket = io.io(
        candidateUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .setTimeout(timeout.inMilliseconds)
            .build(),
      );

      socket.onConnect((_) {
        debugPrint('[PhotoStreamService] Connected to $candidateUrl, emitting incident_image...');
        socket?.emitWithAck(
          'incident_image',
          {
            'incident_id': incidentId,
            'image': base64Image,
          },
          ack: (response) {
            debugPrint('[PhotoStreamService] Server acknowledged incident_image: $response');
            if (!completer.isCompleted) {
              completer.complete(true);
            }
            socket?.disconnect();
            socket?.dispose();
          },
        );
      });

      socket.onConnectError((err) {
        debugPrint('[PhotoStreamService] Connection error on $candidateUrl: $err');
        if (!completer.isCompleted) completer.complete(false);
        socket?.disconnect();
        socket?.dispose();
      });

      socket.onError((err) {
        debugPrint('[PhotoStreamService] Socket error on $candidateUrl: $err');
        if (!completer.isCompleted) completer.complete(false);
        socket?.disconnect();
        socket?.dispose();
      });

      socket.connect();

      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          debugPrint('[PhotoStreamService] Timed out waiting for WebSocket ack from $candidateUrl');
          socket?.disconnect();
          socket?.dispose();
          return false;
        },
      );
    } catch (e) {
      debugPrint('[PhotoStreamService] WebSocket exception on $candidateUrl: $e');
      socket?.disconnect();
      socket?.dispose();
      return false;
    }
  }

  Future<bool> _tryHttpStream({
    required String candidateUrl,
    required String incidentId,
    required String base64Image,
    required Duration timeout,
  }) async {
    final client = http.Client();
    try {
      final uri = Uri.parse('$candidateUrl/incidents/$incidentId/image');
      final response = await client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'image': base64Image}),
          )
          .timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }
      debugPrint('[PhotoStreamService] HTTP POST failed with status ${response.statusCode}: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('[PhotoStreamService] HTTP POST error to $candidateUrl: $e');
      return false;
    } finally {
      client.close();
    }
  }
}
