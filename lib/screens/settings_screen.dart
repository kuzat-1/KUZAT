import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/playback_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _autoplayKey = 'kuzat_autoplay_v1';
  static const _qualityKey = 'kuzat_default_quality_v1';
  bool _autoplay = true;
  String _quality = 'Авто';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoplay = prefs.getBool(_autoplayKey) ?? true;
      _quality = prefs.getString(_qualityKey) ?? 'Авто';
    });
  }

  Future<void> _setAutoplay(bool value) async {
    setState(() => _autoplay = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoplayKey, value);
  }

  Future<void> _setQuality(String value) async {
    setState(() => _quality = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_qualityKey, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          const _SectionTitle('Воспроизведение'),
          Card(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Автовоспроизведение'),
                  subtitle: const Text('Запускать видео сразу после загрузки'),
                  value: _autoplay,
                  onChanged: _setAutoplay,
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Качество по умолчанию'),
                  subtitle: Text(_quality),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: const Color(0xFF171717),
                    builder: (_) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Padding(padding: EdgeInsets.all(18), child: Align(alignment: Alignment.centerLeft, child: Text('Качество по умолчанию', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)))),
                          for (final value in const ['Авто', '1080p', '720p', '480p', '360p'])
                            ListTile(
                              title: Text(value),
                              trailing: value == _quality ? const Icon(Icons.check_rounded, color: Color(0xFFFFC107)) : null,
                              onTap: () {
                                _setQuality(value);
                                Navigator.pop(context);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Данные'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('Очистить историю просмотра'),
              subtitle: const Text('Удалить сохранённые позиции и видео из библиотеки'),
              onTap: () async {
                await PlaybackStore.clear();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('История очищена')));
              },
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('О KUZAT'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.play_circle_outline_rounded, color: Color(0xFFFFC107)),
              title: Text('KUZAT'),
              subtitle: Text('Универсальный видеоплеер • просмотр без загрузки'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(text, style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700)),
      );
}
