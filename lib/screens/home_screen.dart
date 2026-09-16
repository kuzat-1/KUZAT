import 'package:flutter/material.dart';

import '../services/vk_service.dart';
import 'library_screen.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import 'vk_player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _urlController = TextEditingController();
  int _tab = 0;
  int _bottom = 0;

  void _open() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    final screen = VkService.isVkUrl(url) ? VkPlayerScreen(url: url) : PlayerScreen(url: url);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _bottom,
        children: [
          _homePage(),
          const LibraryScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottom,
        onDestinationSelected: (value) => setState(() => _bottom = value),
        backgroundColor: const Color(0xFF0D0D0D),
        indicatorColor: const Color(0x22FFC107),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Главная'),
          NavigationDestination(icon: Icon(Icons.video_library_outlined), selectedIcon: Icon(Icons.video_library), label: 'Библиотека'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Настройки'),
        ],
      ),
    );
  }

  Widget _homePage() {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(children: [_topTab('Поиск', 0), _topTab('YouTube', 1), _topTab('VK Видео', 2)]),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('KUZAT', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, letterSpacing: 2)),
                      const SizedBox(height: 28),
                      Container(
                        height: 58,
                        decoration: BoxDecoration(color: const Color(0xFF171717), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
                        child: Row(
                          children: [
                            const Padding(padding: EdgeInsets.only(left: 18, right: 10), child: Icon(Icons.link_rounded, color: Colors.white54)),
                            Expanded(
                              child: TextField(
                                controller: _urlController,
                                onSubmitted: (_) => _open(),
                                decoration: const InputDecoration(hintText: 'Вставьте ссылку на видео', border: InputBorder.none),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: IconButton.filled(
                                onPressed: _open,
                                icon: const Icon(Icons.search_rounded),
                                style: IconButton.styleFrom(backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('YouTube • VK Видео • MP4 • HLS / M3U8', style: TextStyle(color: Colors.white38, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topTab(String text, int index) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Text(text, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
              const SizedBox(height: 7),
              AnimatedContainer(duration: const Duration(milliseconds: 180), height: 2, width: selected ? 28 : 0, decoration: BoxDecoration(color: const Color(0xFFFFC107), borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
      ),
    );
  }
}
