import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// Represents a queued offline crash incident waiting for store-and-forward delivery.
class OfflineIncidentItem {
  final String id;
  final double latitude;
  final double longitude;
  final Map<String, dynamic> victimMetadata;
  final Map<String, dynamic>? healthCard;
  final String originalTimestamp;
  int retryCount;
  DateTime nextRetryTime;

  OfflineIncidentItem({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.victimMetadata,
    this.healthCard,
    required this.originalTimestamp,
    this.retryCount = 0,
    DateTime? nextRetryTime,
  }) : nextRetryTime = nextRetryTime ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'victimMetadata': victimMetadata,
    if (healthCard != null) 'healthCard': healthCard,
    'originalTimestamp': originalTimestamp,
    'retryCount': retryCount,
    'nextRetryTime': nextRetryTime.toIso8601String(),
  };

  factory OfflineIncidentItem.fromJson(Map<String, dynamic> json) {
    return OfflineIncidentItem(
      id: json['id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      victimMetadata: Map<String, dynamic>.from(json['victimMetadata'] as Map),
      healthCard: json['healthCard'] != null
          ? Map<String, dynamic>.from(json['healthCard'] as Map)
          : null,
      originalTimestamp: json['originalTimestamp'] as String,
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      nextRetryTime: json['nextRetryTime'] != null
          ? DateTime.tryParse(json['nextRetryTime'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Service managing persistent on-device store-and-forward queue with exponential backoff.
/// Ensures crash incidents are never lost during cell dead-zones, tunnel blackouts, or total offline conditions.
class OfflineDispatchQueue {
  OfflineDispatchQueue._internal();
  static final OfflineDispatchQueue _instance = OfflineDispatchQueue._internal();
  static OfflineDispatchQueue get instance => _instance;

  static const String _storageKey = 'rakshak_offline_incident_queue_v1';
  final List<OfflineIncidentItem> _queue = [];
  Timer? _retryTimer;
  ApiClient? _apiClient;
  bool _isProcessing = false;

  List<OfflineIncidentItem> get pendingItems => List.unmodifiable(_queue);

  /// Initializes the queue, loads pending items from persistent storage, and starts retry watchdog.
  Future<void> initialize({ApiClient? apiClient}) async {
    _apiClient = apiClient ?? ApiClient();
    await _loadFromDisk();
    _startWatchdog();
  }

  /// Enqueues an un-dispatched incident into persistent storage.
  Future<void> enqueue({
    required String id,
    required double latitude,
    required double longitude,
    required Map<String, dynamic> victimMetadata,
    Map<String, dynamic>? healthCard,
    required String originalTimestamp,
  }) async {
    // Avoid duplicate queuing of same client UUID
    if (_queue.any((item) => item.id == id)) return;

    final item = OfflineIncidentItem(
      id: id,
      latitude: latitude,
      longitude: longitude,
      victimMetadata: victimMetadata,
      healthCard: healthCard,
      originalTimestamp: originalTimestamp,
    );

    _queue.add(item);
    await _saveToDisk();
    debugPrint('[OfflineDispatchQueue] Enqueued incident $id for store-and-forward retry.');
    
    // Attempt immediate drain in case connectivity just recovered
    triggerDrain();
  }

  /// Triggers an immediate retry attempt for all ready items in the queue.
  void triggerDrain() {
    if (_isProcessing) return;
    _processQueue();
  }

  void _startWatchdog() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _processQueue();
    });
  }

  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;

    try {
      final now = DateTime.now();
      final readyItems = _queue.where((item) => item.nextRetryTime.isBefore(now)).toList();

      for (final item in readyItems) {
        final client = _apiClient ?? ApiClient();
        
        // Tag with delayed delivery flag if gap > 15 seconds
        final origTime = DateTime.tryParse(item.originalTimestamp) ?? now;
        final delaySeconds = now.difference(origTime).inSeconds;
        final bool isDelayed = delaySeconds > 15;

        final metadataToSend = Map<String, dynamic>.from(item.victimMetadata);
        if (isDelayed) {
          metadataToSend['delayed_delivery'] = true;
          metadataToSend['delivery_delay_seconds'] = delaySeconds;
          metadataToSend['original_event_timestamp'] = item.originalTimestamp;
          metadataToSend['store_and_forward_delivered_at'] = now.toIso8601String();
        }

        final result = await client.reportIncident(
          id: item.id,
          status: 'broadcasting',
          latitude: item.latitude,
          longitude: item.longitude,
          victimMetadata: metadataToSend,
          healthCard: item.healthCard,
        );

        if (result.isSuccess) {
          debugPrint('[OfflineDispatchQueue] Successfully delivered queued incident ${item.id} after ${item.retryCount} retries!');
          _queue.removeWhere((i) => i.id == item.id);
          await _saveToDisk();
        } else {
          item.retryCount++;
          // Exponential backoff: 2s, 4s, 8s, 16s, 32s, max 60s
          final backoffSeconds = min(pow(2, item.retryCount).toInt(), 60);
          item.nextRetryTime = now.add(Duration(seconds: backoffSeconds));
          debugPrint('[OfflineDispatchQueue] Retry failed for ${item.id}. Backoff: ${backoffSeconds}s (Retry #${item.retryCount})');
          await _saveToDisk();
        }
      }
    } catch (e) {
      debugPrint('[OfflineDispatchQueue] Error processing retry queue: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _queue.clear();
        for (final item in list) {
          _queue.add(OfflineIncidentItem.fromJson(Map<String, dynamic>.from(item as Map)));
        }
        debugPrint('[OfflineDispatchQueue] Loaded ${_queue.length} stored incidents from disk.');
      }
    } catch (e) {
      debugPrint('[OfflineDispatchQueue] Failed to load queue from disk: $e');
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_queue.map((i) => i.toJson()).toList());
      await prefs.setString(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('[OfflineDispatchQueue] Failed to save queue to disk: $e');
    }
  }

  void dispose() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}
