import 'package:shared_preferences/shared_preferences.dart';

class PlaybackPreferences {
  static const autoplayKey = 'kuzat_autoplay_v1';
  static const qualityKey = 'kuzat_default_quality_v1';

  final bool autoplay;
  final String defaultQuality;

  const PlaybackPreferences({
    required this.autoplay,
    required this.defaultQuality,
  });

  factory PlaybackPreferences.defaults() => const PlaybackPreferences(
        autoplay: true,
        defaultQuality: 'Авто',
      );

  PlaybackPreferences copyWith({bool? autoplay, String? defaultQuality}) => PlaybackPreferences(
        autoplay: autoplay ?? this.autoplay,
        defaultQuality: defaultQuality ?? this.defaultQuality,
      );

  static Future<PlaybackPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PlaybackPreferences(
      autoplay: prefs.getBool(autoplayKey) ?? true,
      defaultQuality: prefs.getString(qualityKey) ?? 'Авто',
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(autoplayKey, autoplay);
    await prefs.setString(qualityKey, defaultQuality);
  }
}
