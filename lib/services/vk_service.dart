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

/// Resolves publicly accessible VK Video pages for playback.
/// Viewer-only: no download action or download URL is exposed by the UI.
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
    final direct = RegExp(r'(?:video|clip)(-?\d+)_(\d+)', caseSensitive: false).firstMatch(value);
    if (direct != null) return '${direct.group(1)}_${direct.group(2)}';

    final slug = RegExp(r'(?:video|clip)(\d{8,})', caseSensitive: false).firstMatch(value);
    if (slug != null) return slug.group(1);

    final plain = RegExp(r'^(-?\d+)_(\d+)$').firstMatch(value);
    if (plain != null) return value;
    return null;
  }

  static Future<VkVideoResult> resolve(String input) async {
    final normalized = normalizeId(input);
    final candidates = <String>[input.trim()];

    // Keep the original URL first, but also add canonical VK fallbacks even
    // when the user pasted a full URL. A redirect/error on one endpoint must
    // not prevent trying the other public VK representations.
    if (normalized != null) {
      candidates.add('https://vk.com/video$normalized');
      candidates.add('https://vkvideo.ru/video$normalized');

      if (normalized.contains('_')) {
        final parts = normalized.split('_');
        candidates.add('https://vk.com/video_ext.php?oid=${parts[0]}&id=${parts[1]}');
        candidates.add('https://vk.com/al_video.php?act=show&al=1&video=$normalized');
      }
    }

    Object? lastError;
    for (final url in candidates.toSet()) {
      try {
        final uri = Uri.tryParse(url);
        if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) continue;
        final response = await http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode < 200 || response.statusCode >= 400) continue;

        final result = _parse(response.body, normalized ?? normalizeId(url) ?? url);
        if (result.hasVideo) return result;
      } catch (error) {
        lastError = error;
      }
    }

    throw Exception(
      lastError == null
          ? 'VK не предоставил доступный поток для этого видео.'
          : 'Не удалось получить VK Video. Проверьте ссылку и доступность видео.',
    );
  }

  static VkVideoResult _parse(String body, String id) {
    final qualities = <String, String>{};

    // VK commonly exposes escaped JSON fields such as url720, url1080, etc.
    final urlPattern = RegExp(
      r'\\?"url(\d{3,4})\\?"\s*:\s*\\?"((?:[^"\\]|\\.)+)\\?"',
      caseSensitive: false,
    );
    for (final match in urlPattern.allMatches(body)) {
      final quality = match.group(1)!;
      final url = _unescape(match.group(2)!);
      if (_isPlayableUrl(url)) qualities[quality] = url;
    }

    // Some VK responses use url_720/url_1080 or similar names.
    final namedPattern = RegExp(
      r'\\?"url[_-]?(\d{3,4})p?\\?"\s*:\s*\\?"((?:[^"\\]|\\.)+)\\?"',
      caseSensitive: false,
    );
    for (final match in namedPattern.allMatches(body)) {
      final quality = match.group(1)!;
      final url = _unescape(match.group(2)!);
      if (_isPlayableUrl(url)) qualities[quality] = url;
    }

    // Also accept direct HLS/DASH/MP4 URLs when VK embeds them under another field.
    final mediaPattern = RegExp(
      r'https?:\\?/\\?/[^"\s\\<>]+?(?:\.mp4|\.m3u8|\.mpd)(?:\?[^"\s\\<>]*)?',
      caseSensitive: false,
    );
    for (final match in mediaPattern.allMatches(body)) {
      final url = _unescape(match.group(0)!);
      if (!_isPlayableUrl(url)) continue;
      final quality = _qualityFromUrl(url) ?? 'src${qualities.length + 1}';
      qualities.putIfAbsent(quality, () => url);
    }

    final title = _stringField(body, 'title') ?? 'Видео VK';
    final thumbnail = _stringField(body, 'jpg') ??
        _stringField(body, 'thumb') ??
        _stringField(body, 'first_frame') ??
        '';
    final seconds = int.tryParse(_numberField(body, 'duration') ?? '') ?? 0;

    return VkVideoResult(
      id: id,
      title: title,
      thumbnail: thumbnail,
      duration: Duration(seconds: seconds),
      qualities: qualities,
    );
  }

  static bool _isPlayableUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) return false;
    final lower = url.toLowerCase();
    return lower.contains('.mp4') || lower.contains('.m3u8') || lower.contains('.mpd');
  }

  static String? _qualityFromUrl(String url) {
    final match = RegExp(
      r'(?:_|-|/)(\d{3,4})(?:p)?(?:[._/?-]|$)',
      caseSensitive: false,
    ).firstMatch(url);
    return match?.group(1);
  }

  static String? _stringField(String body, String key) {
    final pattern = RegExp(
      '\\\\?"${RegExp.escape(key)}\\\\?"\\s*:\\s*\\\\?"((?:[^"\\\\]|\\\\.)*)',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(body);
    return match == null ? null : _unescape(match.group(1)!);
  }

  static String? _numberField(String body, String key) {
    final pattern = RegExp(
      '\\\\?"${RegExp.escape(key)}\\\\?"\\s*:\\s*(\\d+)',
      caseSensitive: false,
    );
    return pattern.firstMatch(body)?.group(1);
  }

  static String _unescape(String value) {
    return value
        .replaceAll(r'\/', '/')
        .replaceAll(r'\u002F', '/')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\u003D', '=')
        .replaceAll(r'\u003F', '?')
        .replaceAll('&amp;', '&');
  }
}
