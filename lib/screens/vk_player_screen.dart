import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../services/vk_service.dart';

class VkPlayerScreen extends StatefulWidget {
  final String url;
  const VkPlayerScreen({super.key, required this.url});

  @override
  State<VkPlayerScreen> createState() => _VkPlayerScreenState();
}

class _VkPlayerScreenState extends State<VkPlayerScreen> {
  VideoPlayerController? _controller;
  VkVideoResult? _result;
  bool _loading = true;
  String? _error;
  bool _fullscreen = false;
  double _speedValue = 1;
  String? _quality;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? quality, Duration? resume}) async {
    final old = _controller;
    _controller = null;
    await old?.dispose();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = _result ?? await VkService.resolve(widget.url);
      final qualities = result.qualities;
      if (qualities.isEmpty) throw Exception('Нет доступного потока');
      final selected = quality ?? _quality ?? _bestQuality(qualities);
      final url = qualities[selected] ?? qualities.values.first;
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      await controller.setPlaybackSpeed(_speedValue);
      if (resume != null && resume > Duration.zero && resume < controller.value.duration) {
        await controller.seekTo(resume);
      }
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _result = result;
        _controller = controller;
        _quality = selected;
        _loading = false;
      });
      controller.addListener(_refresh);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось открыть VK Video. Проверьте ссылку или доступность видео.';
        _loading = false;
      });
    }
  }

  String _bestQuality(Map<String, String> qualities) {
    int value(String key) => int.tryParse(key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return qualities.keys.reduce((a, b) => value(a) >= value(b) ? a : b);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_refresh);
    _controller?.dispose();
    _restoreSystemUi();
    super.dispose();
  }

  Future<void> _restoreSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  }

  Future<void> _fullscreenToggle() async {
    final next = !_fullscreen;
    setState(() => _fullscreen = next);
    if (next) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations(const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      await _restoreSystemUi();
    }
  }

  Future<void> _seek(Duration delta) async {
    final c = _controller;
    if (c == null) return;
    final v = c.value;
    var target = v.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > v.duration) target = v.duration;
    await c.seekTo(target);
  }

  Future<void> _changeQuality(String quality) async {
    final c = _controller;
    if (c == null || quality == _quality) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final position = c.value.position;
    await _load(quality: quality, resume: position);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _setSpeed(double value) async {
    _speedValue = value;
    await _controller?.setPlaybackSpeed(value);
    if (mounted) Navigator.pop(context);
    if (mounted) setState(() {});
  }

  String _time(Duration value) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = value.inHours;
    final m = value.inMinutes.remainder(60);
    final s = value.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _fullscreen ? null : AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('VK Видео', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(onPressed: _showSpeed, icon: const Icon(Icons.speed_rounded)),
          IconButton(onPressed: _fullscreenToggle, icon: const Icon(Icons.fullscreen_rounded)),
        ],
      ),
      body: SafeArea(
        top: !_fullscreen,
        bottom: !_fullscreen,
        child: Column(
          children: [
            Expanded(child: _buildVideo()),
            if (!_loading && _error == null && _controller != null) _controls(),
            if (result != null && !_fullscreen)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(result.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 18),
              OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Повторить')),
            ],
          ),
        ),
      );
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) return const SizedBox.shrink();
    return Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [VideoPlayer(c), if (c.value.isBuffering) const CircularProgressIndicator()],
        ),
      ),
    );
  }

  Widget _controls() {
    final c = _controller!;
    final value = c.value;
    return Material(
      color: const Color(0xFF0D0D0D),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          children: [
            VideoProgressIndicator(c, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Color(0xFFFFC107), bufferedColor: Colors.white38, backgroundColor: Colors.white12), padding: const EdgeInsets.symmetric(vertical: 8)),
            Row(
              children: [
                IconButton(onPressed: () => _seek(const Duration(seconds: -10)), icon: const Icon(Icons.replay_10_rounded)),
                IconButton(onPressed: () => value.isPlaying ? c.pause() : c.play(), icon: Icon(value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded)),
                IconButton(onPressed: () => _seek(const Duration(seconds: 10)), icon: const Icon(Icons.forward_10_rounded)),
                Text('${_time(value.position)} / ${_time(value.duration)}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const Spacer(),
                IconButton(onPressed: () => c.setVolume(value.volume == 0 ? 1 : 0), icon: Icon(value.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded)),
                IconButton(onPressed: _showSpeed, icon: Text('${_speedValue}x', style: const TextStyle(fontSize: 12))),
                IconButton(onPressed: _showQuality, icon: const Icon(Icons.high_quality_rounded)),
                IconButton(onPressed: _fullscreenToggle, icon: const Icon(Icons.fullscreen_rounded)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQuality() {
    final result = _result;
    if (result == null) return;
    final keys = result.qualities.keys.toList()..sort((a, b) => (int.tryParse(b) ?? 0).compareTo(int.tryParse(a) ?? 0));
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171717),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Качество VK Видео', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final key in keys)
                ListTile(
                  leading: const Icon(Icons.hd_outlined),
                  title: Text(key.startsWith('src') ? 'Источник' : '${key}p'),
                  trailing: key == _quality ? const Icon(Icons.check_rounded, color: Color(0xFFFFC107)) : null,
                  onTap: () => _changeQuality(key),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSpeed() {
    const values = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171717),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.all(18), child: Align(alignment: Alignment.centerLeft, child: Text('Скорость', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)))),
            for (final value in values)
              ListTile(
                title: Text('${value}x'),
                trailing: value == _speedValue ? const Icon(Icons.check_rounded, color: Color(0xFFFFC107)) : null,
                onTap: () => _setSpeed(value),
              ),
          ],
        ),
      ),
    );
  }
}
