import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PlaybackEntry {
  final String url;
  final String title;
  final int positionMs;
  final int durationMs;
  final int updatedAtMs;

  const PlaybackEntry({
    required this.url,
    required this.title,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAtMs,
  });

  double get progress => durationMs <= 0 ? 0 : (positionMs / durationMs).clamp(0, 1).toDouble();

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'updatedAtMs': updatedAtMs,
      };

  factory PlaybackEntry.fromJson(Map<String, dynamic> json) => PlaybackEntry(
        url: json['url'] as String? ?? '',
        title: json['title'] as String? ?? 'Видео',
        positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
      );
}

class PlaybackStore {
  static const _key = 'kuzat_playback_history_v1';
  static const _maxItems = 50;

  static Future<List<PlaybackEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PlaybackEntry.fromJson)
          .where((item) => item.url.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save({
    required String url,
    required String title,
    required Duration position,
    required Duration duration,
  }) async {
    if (url.trim().isEmpty) return;
    final items = await load();
    final entry = PlaybackEntry(
      url: url,
      title: title.trim().isEmpty ? 'Видео' : title.trim(),
      positionMs: position.inMilliseconds.clamp(0, 2147483647),
      durationMs: duration.inMilliseconds.clamp(0, 2147483647),
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    items.removeWhere((item) => item.url == url);
    items.insert(0, entry);
    if (items.length > _maxItems) items.removeRange(_maxItems, items.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.map((item) => item.toJson()).toList()));
  }

  static Future<PlaybackEntry?> find(String url) async {
    final items = await load();
    for (final item in items) {
      if (item.url == url) return item;
    }
    return null;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> remove(String url) async {
    final items = await load();
    items.removeWhere((item) => item.url == url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.map((item) => item.toJson()).toList()));
  }
}
