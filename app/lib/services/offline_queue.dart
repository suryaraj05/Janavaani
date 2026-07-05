import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

/// Offline-first submission queue (§3, §1.1). Voice/text drafts captured while
/// offline are persisted to disk and flushed to intake-api once connectivity
/// returns. The citizen sees "queued — will send when online" and never loses a
/// submission on a spotty rural connection.
class OfflineQueue {
  OfflineQueue._();
  static final OfflineQueue instance = OfflineQueue._();

  static const _queueKey = 'pp_offline_queue_v1';
  final _connectivity = Connectivity();

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_queueKey)?.length ?? 0;
  }

  /// Enqueue a draft (+ optional base64 media). Returns after persisting.
  Future<void> enqueue({
    required Map<String, dynamic> draft,
    String? audioBase64,
    List<String>? imagesBase64,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? <String>[];
    queue.add(jsonEncode({
      'draft': draft,
      'audioBase64': audioBase64,
      'imagesBase64': imagesBase64,
      'queued_at': DateTime.now().toIso8601String(),
    }));
    await prefs.setStringList(_queueKey, queue);
  }

  /// Attempt to submit a draft immediately; on failure or offline, enqueue it.
  /// Returns true if it was sent, false if it was queued for later.
  Future<bool> submitOrQueue({
    required Map<String, dynamic> draft,
    String? audioBase64,
    List<String>? imagesBase64,
  }) async {
    if (!await isOnline()) {
      await enqueue(draft: draft, audioBase64: audioBase64, imagesBase64: imagesBase64);
      return false;
    }
    try {
      await ApiService().createSubmission(
        draft: draft,
        audioBase64: audioBase64,
        imagesBase64: imagesBase64,
      );
      return true;
    } catch (_) {
      await enqueue(draft: draft, audioBase64: audioBase64, imagesBase64: imagesBase64);
      return false;
    }
  }

  /// Flush all queued drafts. Returns the number successfully sent.
  Future<int> flush() async {
    if (!await isOnline()) return 0;
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? <String>[];
    if (queue.isEmpty) return 0;

    final remaining = <String>[];
    var sent = 0;
    for (final raw in queue) {
      final item = jsonDecode(raw) as Map<String, dynamic>;
      try {
        await ApiService().createSubmission(
          draft: Map<String, dynamic>.from(item['draft'] as Map),
          audioBase64: item['audioBase64'] as String?,
          imagesBase64: (item['imagesBase64'] as List?)?.map((e) => e.toString()).toList(),
        );
        sent++;
      } catch (_) {
        remaining.add(raw);
      }
    }
    await prefs.setStringList(_queueKey, remaining);
    return sent;
  }
}
