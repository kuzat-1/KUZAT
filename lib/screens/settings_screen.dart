import 'package:flutter/material.dart';

import '../services/playback_preferences.dart';
import '../services/playback_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PlaybackPreferences _prefs = PlaybackPreferences.defaults();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await PlaybackPreferences.load();
    if (mounted) setState(() => _prefs = prefs);
  }

  Future<void> _setAutoplay(bool value) async {
    final next = _prefs.copyWith(autoplay: value);
    await next.save();
    if (mounted) setState(() => _prefs = next);
  }

  Future<void> _setQuality(String value) async {
    final next = _prefs.copyWith(defaultQuality: value);
    await next.save();
    if (mounted) setState(() => _prefs = next);
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
                  value: _prefs.autoplay,
                  onChanged: _setAutoplay,
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Качество по умолчанию'),
                  subtitle: Text(_prefs.defaultQuality),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showQuality,
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

  Future<void> _showQuality() async {
    const values = ['Авто', '1080p', '720p', '480p', '360p'];
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF171717),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: Align(alignment: Alignment.centerLeft, child: Text('Качество по умолчанию', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
            ),
            for (final item in values)
              ListTile(
                title: Text(item),
                trailing: item == _prefs.defaultQuality ? const Icon(Icons.check_rounded, color: Color(0xFFFFC107)) : null,
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );
    if (value != null) await _setQuality(value);
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
