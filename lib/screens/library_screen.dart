import 'package:flutter/material.dart';

import '../services/playback_store.dart';
import 'player_screen.dart';
import 'vk_player_screen.dart';
import '../services/vk_service.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<PlaybackEntry> _items = const [];
  bool _loading = true;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await PlaybackStore.load();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  void _open(PlaybackEntry item) {
    final screen = VkService.isVkUrl(item.url)
        ? VkPlayerScreen(url: item.url)
        : PlayerScreen(url: item.url);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)).then((_) => _load());
  }

  Future<void> _clearHistory() async {
    if (_clearing || _items.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить библиотеку?'),
        content: const Text('Вся история просмотра будет удалена с этого устройства.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Очистить')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _clearing = true);
    await PlaybackStore.clear();
    if (!mounted) return;
    setState(() {
      _items = const [];
      _clearing = false;
    });
  }

  Future<void> _remove(PlaybackEntry item) async {
    await PlaybackStore.remove(item.url);
    if (!mounted) return;
    setState(() => _items.removeWhere((e) => e.url == item.url));
  }

  String _time(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  double _progress(PlaybackEntry item) {
    if (item.durationMs <= 0) return 0;
    return (item.positionMs / item.durationMs).clamp(0.0, 1.0);
  }

  String _sourceLabel(String url) {
    if (VkService.isVkUrl(url)) return 'VK Видео';
    if (url.contains('youtube.com') || url.contains('youtu.be')) return 'YouTube';
    return 'Видео';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Библиотека', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              tooltip: 'Очистить историю',
              onPressed: _clearing ? null : _clearHistory,
              icon: _clearing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _itemCard(_items[index]),
                  ),
                ),
    );
  }

  Widget _emptyState() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 150),
          Icon(Icons.video_library_outlined, size: 64, color: Colors.white30),
          SizedBox(height: 16),
          Center(child: Text('Библиотека пока пустая', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
          SizedBox(height: 8),
          Padding(padding: EdgeInsets.symmetric(horizontal: 42), child: Text('Откройте видео через поиск или вставьте ссылку на главном экране. История появится здесь автоматически.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, height: 1.4))),
        ],
      ),
    );
  }

  Widget _itemCard(PlaybackEntry item) {
    final progress = _progress(item);
    final position = Duration(milliseconds: item.positionMs);
    final duration = Duration(milliseconds: item.durationMs);
    return Dismissible(
      key: ValueKey(item.url),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _remove(item);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Material(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _open(item),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sourceIcon(item.url),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(item.title.trim().isEmpty ? 'Видео без названия' : item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                    ]),
                    const SizedBox(height: 7),
                    Text(_sourceLabel(item.url), style: const TextStyle(color: Color(0xFFFFC107), fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 7),
                    if (duration > Duration.zero && position > Duration.zero) ...[
                      Text('${_time(position)} / ${_time(duration)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 7),
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Color(0xFFFFC107)))),
                      const SizedBox(height: 4),
                      Text('${(progress * 100).round()}% просмотрено', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    ] else const Text('Начать просмотр', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sourceIcon(String url) {
    final vk = VkService.isVkUrl(url);
    final youtube = url.contains('youtube.com') || url.contains('youtu.be');
    final icon = youtube ? Icons.smart_display_rounded : vk ? Icons.play_circle_outline_rounded : Icons.ondemand_video_rounded;
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(color: const Color(0x22FFC107), borderRadius: BorderRadius.circular(16)),
      child: Icon(icon, color: const Color(0xFFFFC107), size: 29),
    );
  }
}
