import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../services/playback_preferences.dart';
import '../services/playback_store.dart';
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
  Timer? _saveTimer;
  bool _loading = true;
  String? _error;
  bool _fullscreen = false;
  double _speedValue = 1;
  String? _quality;
  Duration _resume = Duration.zero;
  PlaybackPreferences _preferences = PlaybackPreferences.defaults();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? quality, Duration? resume}) async {
    _saveTimer?.cancel();
    final old = _controller;
    _controller = null;
    await old?.dispose();
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });

    try {
      _preferences = await PlaybackPreferences.load();
      final oldHistory = await PlaybackStore.find(widget.url);
      if (resume == null) _resume = oldHistory?.position ?? Duration.zero;

      final result = _result ?? await VkService.resolve(widget.url);
      final qualities = result.qualities;
      if (qualities.isEmpty) throw Exception('Нет доступного потока');

      final selected = quality ?? _quality ?? _preferredQuality(qualities);
      final url = qualities[selected] ?? qualities.values.first;
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      final start = resume ?? _resume;
      if (start > Duration.zero && start < controller.value.duration) await controller.seekTo(start);
      await controller.setPlaybackSpeed(_speedValue);
      if (_preferences.autoplay) await controller.play();
      if (!mounted) { await controller.dispose(); return; }
      setState(() { _result = result; _controller = controller; _quality = selected; _loading = false; });
      controller.addListener(_refresh);
      _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Не удалось открыть VK Video. Проверьте ссылку или доступность видео.'; _loading = false; });
    }
  }

  String _preferredQuality(Map<String, String> qualities) {
    if (_preferences.defaultQuality != 'Авто' && qualities.containsKey(_preferences.defaultQuality)) {
      return _preferences.defaultQuality;
    }
    return _bestQuality(qualities);
  }

  String _bestQuality(Map<String, String> qualities) {
    int value(String key) => int.tryParse(key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return qualities.keys.reduce((a, b) => value(a) >= value(b) ? a : b);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _saveProgress() async {
    final c = _controller;
    final r = _result;
    if (c == null || r == null || !c.value.isInitialized) return;
    final position = c.value.position;
    final duration = c.value.duration;
    if (position <= Duration.zero) return;
    if (duration > Duration.zero && position >= duration - const Duration(seconds: 10)) {
      await PlaybackStore.remove(widget.url);
      return;
    }
    await PlaybackStore.save(PlaybackEntry(
      url: widget.url,
      title: r.title.isEmpty ? 'VK Видео' : r.title,
      positionMs: position.inMilliseconds,
      durationMs: duration.inMilliseconds,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_saveProgress());
    _controller?.removeListener(_refresh);
    _controller?.dispose();
    unawaited(_restoreSystemUi());
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
    if (c == null || quality == _quality) { if (mounted) Navigator.pop(context); return; }
    final position = c.value.position;
    await _load(quality: quality, resume: position);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _setSpeed(double value) async {
    _speedValue = value;
    await _controller?.setPlaybackSpeed(value);
    if (mounted) { Navigator.pop(context); setState(() {}); }
  }

  String _time(Duration value) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = value.inHours, m = value.inMinutes.remainder(60), s = value.inSeconds.remainder(60);
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
        title: Text(result?.title.isNotEmpty == true ? result!.title : 'VK Видео', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [IconButton(onPressed: _showSpeed, icon: const Icon(Icons.speed_rounded)), IconButton(onPressed: _fullscreenToggle, icon: const Icon(Icons.fullscreen_rounded))],
      ),
      body: SafeArea(
        top: !_fullscreen,
        bottom: !_fullscreen,
        child: Column(children: [Expanded(child: _buildVideo()), if (!_loading && _error == null && _controller != null) _controls()]),
      ),
    );
  }

  Widget _buildVideo() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 48),
      const SizedBox(height: 12), Text('$_error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 18), OutlinedButton.icon(onPressed: () => _load(), icon: const Icon(Icons.refresh_rounded), label: const Text('Повторить')),
    ])));
    final c = _controller;
    if (c == null || !c.value.isInitialized) return const SizedBox.shrink();
    return Center(child: AspectRatio(aspectRatio: c.value.aspectRatio, child: Stack(alignment: Alignment.center, children: [VideoPlayer(c), if (c.value.isBuffering) const CircularProgressIndicator()])));
  }

  Widget _controls() {
    final c = _controller!;
    final v = c.value;
    return Material(color: const Color(0xFF0D0D0D), child: Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 12), child: Column(children: [
      VideoProgressIndicator(c, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Color(0xFFFFC107), bufferedColor: Colors.white38, backgroundColor: Colors.white12), padding: const EdgeInsets.symmetric(vertical: 8)),
      Row(children: [
        IconButton(onPressed: () => _seek(const Duration(seconds: -10)), icon: const Icon(Icons.replay_10_rounded)),
        IconButton(onPressed: () => v.isPlaying ? c.pause() : c.play(), icon: Icon(v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded)),
        IconButton(onPressed: () => _seek(const Duration(seconds: 10)), icon: const Icon(Icons.forward_10_rounded)),
        Text('${_time(v.position)} / ${_time(v.duration)}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const Spacer(),
        IconButton(onPressed: () => c.setVolume(v.volume == 0 ? 1 : 0), icon: Icon(v.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded)),
        IconButton(onPressed: _showSpeed, icon: Text('${_speedValue}x', style: const TextStyle(fontSize: 12))),
        IconButton(onPressed: _showQuality, icon: const Icon(Icons.high_quality_rounded)),
        IconButton(onPressed: _fullscreenToggle, icon: const Icon(Icons.fullscreen_rounded)),
      ]),
    ])));
  }

  void _showQuality() {
    final result = _result;
    if (result == null) return;
    final keys = result.qualities.keys.toList()..sort((a, b) => (int.tryParse(b) ?? 0).compareTo(int.tryParse(a) ?? 0));
    showModalBottomSheet<void>(context: context, backgroundColor: const Color(0xFF171717), builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Качество VK Видео', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      for (final key in keys) ListTile(leading: const Icon(Icons.hd_outlined), title: Text(key.startsWith('src') ? 'Источник' : '${key}p'), trailing: key == _quality ? const Icon(Icons.check_rounded, color: Color(0xFFFFC107)) : null, onTap: () => _changeQuality(key)),
    ]))));
  }

  void _showSpeed() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet<void>(context: context, backgroundColor: const Color(0xFF171717), builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Скорость', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      for (final speed in speeds) ListTile(title: Text('${speed}x'), trailing: _speedValue == speed ? const Icon(Icons.check_rounded) : null, onTap: () => _setSpeed(speed)),
    ]))));
  }
}
