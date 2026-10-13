import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Bounded, versioned cache for optional AI assistance.
///
/// The key never contains credentials. Entries carry a template/content
/// version so old generated text can be invalidated without changing the
/// learning event log.
class AiExplanationCache {
  static const String _indexKey = 'ai_explanation_cache_index_v2';
  static const int defaultMaxEntries = 80;
  static const int defaultMaxBytes = 1024 * 1024;

  final SharedPreferences preferences;
  final int maxEntries;
  final int maxBytes;

  const AiExplanationCache(
    this.preferences, {
    this.maxEntries = defaultMaxEntries,
    this.maxBytes = defaultMaxBytes,
  });

  String? get(String key) {
    final raw = preferences.getString(_entryKey(key));
    if (raw == null || raw.isEmpty) return null;
    try {
      final envelope = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final payload = envelope['payload'] as String?;
      if (payload == null) return null;
      _touch(key, envelope);
      return payload;
    } catch (_) {
      return null;
    }
  }

  Future<void> put({
    required String key,
    required String payload,
    required String contentVersion,
    required String templateVersion,
    required String provider,
    required String model,
  }) async {
    final now = DateTime.now().toIso8601String();
    final envelope = {
      'key': key,
      'payload': payload,
      'contentVersion': contentVersion,
      'templateVersion': templateVersion,
      'provider': provider,
      'model': model,
      'createdAt': now,
      'lastAccessAt': now,
    };
    await preferences.setString(_entryKey(key), jsonEncode(envelope));
    _touch(key, envelope);
    await _evictIfNeeded();
  }

  Future<void> clear() async {
    final index = _index();
    for (final key in index.keys) {
      await preferences.remove(_entryKey(key));
    }
    await preferences.remove(_indexKey);
  }

  Map<String, dynamic> _index() {
    final raw = preferences.getString(_indexKey);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  void _touch(String key, Map<String, dynamic> envelope) {
    final index = _index();
    index[key] = {
      'lastAccessAt':
          envelope['lastAccessAt'] ?? DateTime.now().toIso8601String(),
      'size': utf8.encode(jsonEncode(envelope)).length,
    };
    // Index writes are intentionally best effort. The payload is already
    // available; a stale index is rebuilt by the next cache write.
    preferences.setString(_indexKey, jsonEncode(index));
  }

  Future<void> _evictIfNeeded() async {
    final index = _index();
    var totalBytes = index.values.fold<int>(
      0,
      (sum, value) => sum + ((value as Map)['size'] as num? ?? 0).toInt(),
    );
    final entries = index.entries.toList()
      ..sort((a, b) {
        final aDate =
            DateTime.tryParse(
              (a.value as Map)['lastAccessAt'] as String? ?? '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            DateTime.tryParse(
              (b.value as Map)['lastAccessAt'] as String? ?? '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });
    while (entries.length > maxEntries || totalBytes > maxBytes) {
      final oldest = entries.removeAt(0);
      final size = ((oldest.value as Map)['size'] as num? ?? 0).toInt();
      totalBytes -= size;
      index.remove(oldest.key);
      await preferences.remove(_entryKey(oldest.key));
    }
    await preferences.setString(_indexKey, jsonEncode(index));
  }

  String _entryKey(String key) => 'ai_explanation_cache_entry_v2:$key';
}
