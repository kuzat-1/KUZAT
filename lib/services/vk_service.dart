import 'dart:convert';

import 'package:http/http.dart' as http;

class VkVideoResult {
  final String id;
  final String title;
  final String thumbnail;
  final Duration duration;
  final Map<String, String> qualities;

  const VkVideoResult({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.duration,
    required this.qualities,
  });

  bool get hasVideo => qualities.isNotEmpty;
}

/// Resolves public VK Video pages on the user's device.
/// This service is intentionally viewer-only: it returns playback URLs and
/// never exposes a download action in the KUZAT UI.
class VkService {
  static const _headers = <String, String>{
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'ru,en;q=0.8',
  };

  static bool isVkUrl(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host == 'vk.com' ||
        host.endsWith('.vk.com') ||
        host == 'vkvideo.ru' ||
        host.endsWith('.vkvideo.ru');
  }

  static String? normalizeId(String input) {
    final value = input.trim();
    final direct = RegExp(r'video(-?\d+)_(\d+)').firstMatch(value);
    if (direct != null) return '${direct.group(1)}_${direct.group(2)}';
    final slug = RegExp(r'video(\d{10,})').firstMatch(value);
    if (slug != null) return slug.group(1);
    final plain = RegExp(r'^(-?\d+)_(\d+)$').firstMatch(value);
    if (plain != null) return value;
    return null;
  }

  static Future<VkVideoResult> resolve(String input) async {
    final id = normalizeId(input);
    final candidates = <String>[input.trim()];

    if (id != null && !input.contains('://')) {
      candidates.add('https://vk.com/video$id');
      candidates.add('https://vkvideo.ru/video$id');
    }

    if (id != null && id.contains('_')) {
      final parts = id.split('_');
      candidates.add('https://vk.com/video_ext.php?oid=${parts[0]}&id=${parts[1]}');
      candidates.add('https://vk.com/al_video.php?act=show&al=1&video=$id');
    }

    Object? lastError;
    for (final url in candidates.toSet()) {
      try {
        final response = await http
            .get(Uri.parse(url), headers: _headers)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode < 200 || response.statusCode >= 400) continue;
        final result = _parse(response.body, id ?? normalizeId(url) ?? url);
        if (result.hasVideo) return result;
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception(lastError == null
        ? 'VK не предоставил доступный поток для этого видео.'
        : 'Не удалось получить VK Video. Проверьте ссылку и доступность видео.');
  }

  static VkVideoResult _parse(String body, String id) {
    final qualities = <String, String>{};

    // VK pages commonly expose urlXXX fields for MP4 renditions.
    final urlPattern = RegExp(
      r'url(\d{3,4})\\?"\s*:\s*\\?"(https:[^"\\]+)',
      caseSensitive: false,
    );
    for (final match in urlPattern.allMatches(body)) {
      final quality = match.group(1)!;
      final url = _unescape(match.group(2)!);
      if (url.startsWith('http')) qualities[quality] = url;
    }

    // Fallback for direct MP4 strings embedded in JSON/HTML.
    final mp4Pattern = RegExp(
      r'https:(?:\\?/){1,2}[^"\\\s]{10,500}?\.mp4[^"\\\s]{0,100}',
      caseSensitive: false,
    );
    for (final match in mp4Pattern.allMatches(body)) {
      final url = _unescape(match.group(0)!);
      if (!url.startsWith('http')) continue;
      final quality = RegExp(r'[_\-/](\d{3,4})(?:\.mp4|[?&])', caseSensitive: false)
              .firstMatch(url)
              ?.group(1) ??
          'src${qualities.length + 1}';
      qualities.putIfAbsent(quality, () => url);
    }

    final title = _stringField(body, 'title') ?? 'Видео VK';
    final thumbnail =
        _stringField(body, 'jpg') ?? _stringField(body, 'thumb') ?? _stringField(body, 'first_frame') ?? '';
    final seconds = int.tryParse(_numberField(body, 'duration') ?? '') ?? 0;

    return VkVideoResult(
      id: id,
      title: title,
      thumbnail: thumbnail,
      duration: Duration(seconds: seconds),
      qualities: qualities,
    );
  }

  static String? _stringField(String body, String key) {
    final pattern = RegExp(
      '"${RegExp.escape(key)}"\\s*:\\s*\\\\?"((?:[^"\\\\]|\\\\.)*)',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(body);
    return match == null ? null : _unescape(match.group(1)!);
  }

  static String? _numberField(String body, String key) {
    final match = RegExp('"${RegExp.escape(key)}"\\s*:\\s*(\\d+)', caseSensitive: false)
        .firstMatch(body);
    return match?.group(1);
  }

  static String _unescape(String value) {
    try {
      return jsonDecode('"${value.replaceAll('"', '\\"')}"') as String;
    } catch (_) {
      return value.replaceAll(r'\/', '/').replaceAll(r'\u0026', '&');
    }
  }
}
