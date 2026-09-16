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

  String _time(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
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
              onPressed: () async {
                await PlaybackStore.clear();
                _load();
              },
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.video_library_outlined, size: 52, color: Colors.white38),
                        SizedBox(height: 14),
                        Text('Библиотека пока пустая', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        SizedBox(height: 8),
                        Text('Открытые видео будут автоматически появляться здесь.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final position = Duration(milliseconds: item.positionMs);
                      final duration = Duration(milliseconds: item.durationMs);
                      return Dismissible(
                        key: ValueKey(item.url),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.delete_outline_rounded),
                        ),
                        onDismissed: (_) => PlaybackStore.remove(item.url),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0x22FFC107),
                              child: Icon(VkService.isVkUrl(item.url) ? Icons.play_circle_outline : Icons.ondemand_video_outlined, color: const Color(0xFFFFC107)),
                            ),
                            title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              duration > Duration.zero && position > Duration.zero
                                  ? '${_time(position)} / ${_time(duration)}'
                                  : 'Начать просмотр',
                              style: const TextStyle(color: Colors.white54),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _open(item),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
