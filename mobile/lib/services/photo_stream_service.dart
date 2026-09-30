import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/backend_config.dart';
import 'api_client.dart';

/// Service for streaming emergency crash visual triage telemetry directly
/// from volatile device RAM to the Rakshak-AI backend via WebSockets.
///
/// STRICT ZERO-STORAGE PRIVACY GUARANTEE:
/// No image is ever written to device disk, SQLite, or gallery.
///
/// ARCHITECTURAL NOTE:
/// In production, this encrypted WebSocket frame would be upgraded to a
/// WebRTC data channel per Rakshak's low-latency zero-storage specification.
class PhotoStreamService {
  PhotoStreamService._internal();
  static final PhotoStreamService _instance = PhotoStreamService._internal();
  static PhotoStreamService get instance => _instance;

  /// Streams raw in-memory image bytes over a binary WebSocket frame.
  /// Emits the 'incident_image' event tagged with the incident ID.
  Future<bool> streamIncidentPhoto({
    required String incidentId,
    required Uint8List imageBytes,
    List<String>? candidateUrls,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    // Production Upgrade Note: In production this encrypted WebSocket frame
    // would be upgraded to a WebRTC data channel per Rakshak's low-latency
    // zero-storage specification.

    // Candidate base URLs matching ApiClient routing
    final candidates = candidateUrls ?? getBackendCandidates();

    for (final candidateUrl in candidates) {
      debugPrint(
        '[PhotoStreamService] Attempting photo stream via $candidateUrl for incident $incidentId...',
      );
      final completer = Completer<bool>();
      io.Socket? socket;

      try {
        socket = io.io(
          candidateUrl,
          io.OptionBuilder()
              .setTransports(['websocket'])
              .disableAutoConnect()
              .setTimeout(timeout.inMilliseconds)
              .build(),
        );

        socket.onConnect((_) {
          debugPrint(
            '[PhotoStreamService] Connected to $candidateUrl, emitting incident_image (${imageBytes.lengthInBytes} bytes)...',
          );
          // Emit binary payload with incident_id tag
          socket?.emitWithAck(
            'incident_image',
            {
              'incident_id': incidentId,
              'image': imageBytes,
            },
            ack: (response) {
              debugPrint(
                '[PhotoStreamService] Server acknowledged incident_image: $response',
              );
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
          if (!completer.isCompleted) {
            completer.complete(false);
          }
          socket?.disconnect();
          socket?.dispose();
        });

        socket.onError((err) {
          debugPrint('[PhotoStreamService] Socket error on $candidateUrl: $err');
          if (!completer.isCompleted) {
            completer.complete(false);
          }
          socket?.disconnect();
          socket?.dispose();
        });

        socket.connect();

        final success = await completer.future.timeout(
          timeout,
          onTimeout: () {
            debugPrint('[PhotoStreamService] Timed out waiting for ack from $candidateUrl');
            socket?.disconnect();
            socket?.dispose();
            return false;
          },
        );

        if (success) {
          debugPrint('[PhotoStreamService] Successfully streamed volatile photo to $candidateUrl');
          return true;
        }
      } catch (e) {
        debugPrint('[PhotoStreamService] Exception while streaming to $candidateUrl: $e');
        try {
          socket?.disconnect();
          socket?.dispose();
        } catch (_) {}
      }
    }

    debugPrint('[PhotoStreamService] Failed to stream photo across all candidate URLs.');
    return false;
  }
}
