import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/backend_config.dart';

/// Service for streaming emergency crash visual triage telemetry directly
/// from volatile device RAM to receiving hospital dashboards via WebRTC DataChannel
/// with automatic dual-channel WebSocket and HTTP fallbacks.
///
/// STRICT ZERO-STORAGE PRIVACY GUARANTEE:
/// No image is ever written to device disk, SQLite, or gallery.
class PhotoStreamService {
  PhotoStreamService._internal();
  static final PhotoStreamService _instance = PhotoStreamService._internal();
  static PhotoStreamService get instance => _instance;

  /// Tracks which transport was used for the most recent photo stream.
  @visibleForTesting
  static String lastUsedTransport = 'none';

  /// Test hook to simulate WebRTC negotiation failure/timeout.
  @visibleForTesting
  static bool forceWebRtcTimeoutForTesting = false;

  /// Streams raw in-memory image bytes over WebRTC DataChannel, with automatic
  /// fallback to binary WebSocket frames or HTTP POST.
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

      // =======================================================================
      // PHASE 12: PRIMARY TRANSPORT - WebRTC PEER-TO-PEER DATACHANNEL
      // -----------------------------------------------------------------------
      // Attempts direct P2P streaming over an RTCDataChannel via Google STUN.
      // If peer connection or negotiation exceeds 5 seconds, it automatically
      // falls back to the Phase 6 WebSocket binary stream without user disruption.
      // =======================================================================
      if (!forceWebRtcTimeoutForTesting) {
        final webrtcSuccess = await _tryWebRtcStream(
          candidateUrl: candidateUrl,
          incidentId: incidentId,
          base64Image: base64Image,
          timeout: timeout,
        );

        if (webrtcSuccess) {
          lastUsedTransport = 'webrtc';
          debugPrint(
            '[PhotoStreamService] Transport verdict: WebRTC P2P DataChannel succeeded to $candidateUrl',
          );
          gActiveBackendUrl = candidateUrl;
          return true;
        }
      }

      debugPrint(
        '[PhotoStreamService] WebRTC negotiation failed/timed out. Automatically falling back to Phase 6 WebSocket binary path.',
      );

      // Attempt Channel A: Socket.IO binary/base64 event with ack (WebSocket Fallback)
      final wsSuccess = await _tryWebSocketStream(
        candidateUrl: candidateUrl,
        incidentId: incidentId,
        base64Image: base64Image,
        timeout: timeout,
      );

      if (wsSuccess) {
        lastUsedTransport = 'websocket';
        debugPrint(
          '[PhotoStreamService] Transport verdict: WebSocket fallback succeeded to $candidateUrl',
        );
        gActiveBackendUrl = candidateUrl;
        return true;
      }

      // Attempt Channel B: Dual-channel HTTP fallback for mobile networks
      debugPrint(
        '[PhotoStreamService] WebSocket stream failed/timed out. Attempting HTTP POST fallback to $candidateUrl...',
      );
      final httpSuccess = await _tryHttpStream(
        candidateUrl: candidateUrl,
        incidentId: incidentId,
        base64Image: base64Image,
        timeout: timeout,
      );

      if (httpSuccess) {
        lastUsedTransport = 'http';
        debugPrint(
          '[PhotoStreamService] Transport verdict: HTTP fallback succeeded to $candidateUrl',
        );
        gActiveBackendUrl = candidateUrl;
        return true;
      }
    }

    debugPrint('[PhotoStreamService] Failed to stream photo across all candidate URLs.');
    return false;
  }

  /// Attempts WebRTC P2P DataChannel streaming with Google STUN.
  ///
  /// STUN / NAT TRAVERSAL & TURN ARCHITECTURAL LIMITATION NOTE:
  /// Connects using Google's free public STUN servers (stun:stun.l.google.com:19302)
  /// for standard NAT hole-punching. In symmetric-NAT or highly restrictive
  /// enterprise/hospital Wi-Fi networks, a TURN relay server (e.g. coturn with
  /// credentials) is required for guaranteed peer connectivity.
  /// As external TURN infrastructure is not provisioned for this hackathon, this
  /// is an honest documented limitation: if WebRTC peer negotiation times out (5s),
  /// Rakshak-AI automatically and seamlessly falls back to Phase 6's zero-storage
  /// WebSocket binary streaming pipeline without user-visible interruption.
  Future<bool> _tryWebRtcStream({
    required String candidateUrl,
    required String incidentId,
    required String base64Image,
    required Duration timeout,
  }) async {
    final completer = Completer<bool>();
    io.Socket? socket;
    rtc.RTCPeerConnection? peerConnection;
    rtc.RTCDataChannel? dataChannel;
    Timer? timeoutTimer;

    void cleanup() {
      timeoutTimer?.cancel();
      try {
        dataChannel?.close();
      } catch (_) {}
      try {
        peerConnection?.close();
        peerConnection?.dispose();
      } catch (_) {}
      try {
        socket?.disconnect();
        socket?.dispose();
      } catch (_) {}
    }

    try {
      // 1. Establish lightweight signaling Socket.IO connection
      socket = io.io(
        candidateUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .setTimeout(timeout.inMilliseconds)
            .build(),
      );

      // 2. Configure ICE Servers using public Google STUN for NAT traversal
      final rtcConfiguration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };

      peerConnection = await rtc.createPeerConnection(rtcConfiguration);

      // 3. Create outbound data channel for zero-storage RAM photo streaming
      final dcInit = rtc.RTCDataChannelInit()
        ..ordered = true
        ..maxRetransmits = 30;
      dataChannel = await peerConnection.createDataChannel('photo_stream', dcInit);

      dataChannel.onDataChannelState = (rtc.RTCDataChannelState state) {
        debugPrint('[PhotoStreamService WebRTC] DataChannel state: $state');
        if (state == rtc.RTCDataChannelState.RTCDataChannelOpen) {
          try {
            final fullDataUrl = 'data:image/jpeg;base64,$base64Image';
            const chunkSize = 16384; // 16 KB chunks to safely adhere to SCTP message limits
            final totalChunks = (fullDataUrl.length / chunkSize).ceil();

            if (totalChunks <= 1) {
              final payload = jsonEncode({
                'type': 'photo_data',
                'imageUrl': fullDataUrl,
                'transport': 'webrtc',
                'incident_id': incidentId,
              });
              dataChannel?.send(rtc.RTCDataChannelMessage(payload));
            } else {
              for (var i = 0; i < totalChunks; i++) {
                final start = i * chunkSize;
                final end = (start + chunkSize < fullDataUrl.length)
                    ? start + chunkSize
                    : fullDataUrl.length;
                final chunk = fullDataUrl.substring(start, end);
                final isLast = (i == totalChunks - 1);

                final chunkPayload = jsonEncode({
                  'type': 'photo_chunk',
                  'incident_id': incidentId,
                  'data': chunk,
                  'chunkIndex': i,
                  'totalChunks': totalChunks,
                  'isLast': isLast,
                });
                dataChannel?.send(rtc.RTCDataChannelMessage(chunkPayload));
              }
            }

            debugPrint(
              '[PhotoStreamService WebRTC] Direct P2P photo bytes transferred via DataChannel ($totalChunks chunk(s))',
            );
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          } catch (e) {
            debugPrint('[PhotoStreamService WebRTC] Failed to send over DataChannel: $e');
            if (!completer.isCompleted) completer.complete(false);
          }
        }
      };

      // 4. Handle local ICE candidates
      peerConnection.onIceCandidate = (rtc.RTCIceCandidate? candidate) {
        if (candidate != null && socket?.connected == true) {
          socket?.emit('webrtc_ice_candidate', {
            'incident_id': incidentId,
            'candidate': candidate.toMap(),
          });
        }
      };

      // 5. Connect signaling socket
      socket.onConnect((_) async {
        debugPrint('[PhotoStreamService WebRTC] Connected to signaling server, creating offer...');
        try {
          final offer = await peerConnection!.createOffer({
            'offerToReceiveVideo': 0,
            'offerToReceiveAudio': 0,
          });
          await peerConnection!.setLocalDescription(offer);

          socket?.emit('webrtc_offer', {
            'incident_id': incidentId,
            'sdp': offer.toMap(),
          });

          // Join incident room so direct answers/candidates are routed
          socket?.emit('join_incident', incidentId);
        } catch (e) {
          debugPrint('[PhotoStreamService WebRTC] Error creating offer: $e');
          if (!completer.isCompleted) completer.complete(false);
        }
      });

      final queuedCandidates = <rtc.RTCIceCandidate>[];

      // 6. Handle remote answer
      socket.on('webrtc_answer', (data) async {
        try {
          if (data is Map && data['incident_id'] == incidentId && data['sdp'] != null) {
            debugPrint('[PhotoStreamService WebRTC] Received webrtc_answer from dashboard peer');
            final sdpMap = data['sdp'] as Map<dynamic, dynamic>;
            final remoteDesc = rtc.RTCSessionDescription(
              sdpMap['sdp'] as String?,
              sdpMap['type'] as String?,
            );
            await peerConnection?.setRemoteDescription(remoteDesc);

            // Flush candidates queued before remote description was ready
            for (final queued in queuedCandidates) {
              await peerConnection?.addCandidate(queued);
            }
            queuedCandidates.clear();
          }
        } catch (e) {
          debugPrint('[PhotoStreamService WebRTC] Error setting remote description: $e');
        }
      });

      // 7. Handle remote ICE candidates
      socket.on('webrtc_ice_candidate', (data) async {
        try {
          if (data is Map && data['incident_id'] == incidentId && data['candidate'] != null) {
            final cMap = data['candidate'] as Map<dynamic, dynamic>;
            final candidate = rtc.RTCIceCandidate(
              cMap['candidate'] as String?,
              cMap['sdpMid'] as String?,
              cMap['sdpMLineIndex'] as int?,
            );

            // Queue candidate if remote description not yet set
            final hasRemoteDesc = await peerConnection?.getRemoteDescription() != null;
            if (!hasRemoteDesc) {
              queuedCandidates.add(candidate);
            } else {
              await peerConnection?.addCandidate(candidate);
            }
          }
        } catch (_) {}
      });

      socket.onConnectError((err) {
        debugPrint('[PhotoStreamService WebRTC] Signaling connect error: $err');
        if (!completer.isCompleted) completer.complete(false);
      });

      socket.connect();

      // 8. 5-second negotiation timeout
      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          debugPrint('[PhotoStreamService WebRTC] Negotiation timed out after ${timeout.inSeconds}s');
          completer.complete(false);
        }
      });

      final success = await completer.future;
      cleanup();
      return success;
    } catch (e) {
      debugPrint('[PhotoStreamService WebRTC] WebRTC peer connection exception: $e');
      cleanup();
      return false;
    }
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
