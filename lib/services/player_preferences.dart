import 'package:shared_preferences/shared_preferences.dart';

class PlayerPreferences {
  static const autoplayKey = 'kuzat_autoplay_v1';
  static const qualityKey = 'kuzat_default_quality_v1';

  static Future<bool> autoplay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(autoplayKey) ?? true;
  }

  static Future<String> quality() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(qualityKey) ?? 'Авто';
  }
}
