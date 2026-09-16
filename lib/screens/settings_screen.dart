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
  bool _loading = true;
  bool _savingAutoplay = false;
  bool _clearingHistory = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await PlaybackPreferences.load();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _loading = false;
    });
  }

  Future<void> _setAutoplay(bool value) async {
    if (_savingAutoplay) return;
    setState(() => _savingAutoplay = true);
    try {
      final next = _prefs.copyWith(autoplay: value);
      await next.save();
      if (!mounted) return;
      setState(() => _prefs = next);
    } finally {
      if (mounted) setState(() => _savingAutoplay = false);
    }
  }

  Future<void> _setQuality(String value) async {
    final next = _prefs.copyWith(defaultQuality: value);
    await next.save();
    if (mounted) setState(() => _prefs = next);
  }

  Future<void> _clearHistory() async {
    if (_clearingHistory) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text('Все сохранённые позиции просмотра будут удалены из библиотеки.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Очистить')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _clearingHistory = true);
    await PlaybackStore.clear();
    if (!mounted) return;
    setState(() => _clearingHistory = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('История просмотра очищена')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки', style: TextStyle(fontWeight: FontWeight.w800))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              children: [
                const _SectionTitle('Воспроизведение'),
                _SettingsCard(
                  children: [
                    SwitchListTile.adaptive(
                      secondary: const Icon(Icons.play_circle_outline_rounded),
                      title: const Text('Автовоспроизведение'),
                      subtitle: const Text('Запускать видео сразу после загрузки'),
                      value: _prefs.autoplay,
                      onChanged: _savingAutoplay ? null : _setAutoplay,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.high_quality_outlined),
                      title: const Text('Качество по умолчанию'),
                      subtitle: Text(_prefs.defaultQuality),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: _showQuality,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const _SectionTitle('Данные'),
                _SettingsCard(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.history_rounded),
                      title: const Text('Очистить историю просмотра'),
                      subtitle: const Text('Удалить сохранённые позиции и видео из библиотеки'),
                      trailing: _clearingHistory
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: _clearingHistory ? null : _clearHistory,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const _SectionTitle('О KUZAT'),
                const _SettingsCard(
                  children: [
                    ListTile(
                      leading: Icon(Icons.play_circle_outline_rounded, color: Color(0xFFFFC107), size: 30),
                      title: Text('KUZAT', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('Универсальный видеоплеер • просмотр без загрузки'),
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.info_outline_rounded),
                      title: Text('Версия'),
                      subtitle: Text('1.0.0'),
                    ),
                  ],
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
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 8, 10),
                child: Align(alignment: Alignment.centerLeft, child: Text('Качество по умолчанию', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
              ),
              for (final item in values)
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  title: Text(item),
                  trailing: item == _prefs.defaultQuality ? const Icon(Icons.check_rounded, color: Color(0xFFFFC107)) : null,
                  onTap: () => Navigator.pop(context, item),
                ),
              const SizedBox(height: 4),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Align(alignment: Alignment.centerLeft, child: Text('Для YouTube качество выбирается автоматически.', style: TextStyle(color: Colors.white54, fontSize: 12)))),
            ],
          ),
        ),
      ),
    );
    if (value != null) await _setQuality(value);
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
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
