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
  Duration get position => Duration(milliseconds: positionMs);
  Duration get duration => Duration(milliseconds: durationMs);

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
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final items = <PlaybackEntry>[];
      for (final value in decoded) {
        if (value is! Map) continue;
        final item = PlaybackEntry.fromJson(Map<String, dynamic>.from(value));
        if (item.url.trim().isEmpty) continue;
        items.add(item);
      }

      items.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
      return items.take(_maxItems).toList(growable: true);
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(PlaybackEntry entry) async {
    final url = entry.url.trim();
    if (url.isEmpty) return;

    final items = await load();
    final safePosition = entry.positionMs.clamp(0, 2147483647).toInt();
    final safeDuration = entry.durationMs.clamp(0, 2147483647).toInt();
    final safeTitle = entry.title.trim().isEmpty ? 'Видео' : entry.title.trim();
    final updated = PlaybackEntry(
      url: url,
      title: safeTitle,
      positionMs: safePosition,
      durationMs: safeDuration,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    items.removeWhere((item) => item.url == url);
    items.insert(0, updated);
    if (items.length > _maxItems) items.removeRange(_maxItems, items.length);
    await _write(items);
  }

  static Future<PlaybackEntry?> find(String url) async {
    final normalized = url.trim();
    if (normalized.isEmpty) return null;
    final items = await load();
    for (final item in items) {
      if (item.url == normalized) return item;
    }
    return null;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> remove(String url) async {
    final normalized = url.trim();
    if (normalized.isEmpty) return;
    final items = await load();
    items.removeWhere((item) => item.url == normalized);
    await _write(items);
  }

  static Future<void> _write(List<PlaybackEntry> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.map((item) => item.toJson()).toList()));
  }
}
