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
  Timer? _controlsTimer;
  bool _loading = true;
  String? _error;
  bool _fullscreen = false;
  bool _controlsVisible = true;
  double _speedValue = 1;
  String? _quality;
  Duration _resume = Duration.zero;
  PlaybackPreferences _preferences = PlaybackPreferences.defaults();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _retry() async {
    _result = null;
    _quality = null;
    await _load();
  }

  Future<void> _load({String? quality, Duration? resume}) async {
    _saveTimer?.cancel();
    _controlsTimer?.cancel();
    final old = _controller;
    _controller = null;
    await old?.dispose();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _controlsVisible = true;
    });

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
      _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());
      _scheduleControlsHide();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _vkErrorMessage(error);
        _loading = false;
      });
    }
  }

  String _vkErrorMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('нет доступного потока')) {
      return 'Для этого видео VK не предоставил доступный видеопоток.';
    }
    if (text.contains('timeout') || text.contains('timed out')) {
      return 'Время ожидания истекло. Проверьте интернет и попробуйте ещё раз.';
    }
    return 'Не удалось открыть VK Видео. Видео может быть удалено, ограничено или временно недоступно.';
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
    if (!mounted) return;
    setState(() {});
    if (_controller?.value.isPlaying == true && _controlsVisible) _scheduleControlsHide();
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    if (_controller?.value.isPlaying != true) return;
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller?.value.isPlaying == true) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    if (!mounted) return;
    setState(() => _controlsVisible = true);
    _scheduleControlsHide();
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _controlsTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      await c.pause();
      _controlsTimer?.cancel();
      if (mounted) setState(() => _controlsVisible = true);
    } else {
      await c.play();
      _showControls();
    }
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
    _controlsTimer?.cancel();
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
    _showControls();
  }

  Future<void> _seek(Duration delta) async {
    final c = _controller;
    if (c == null) return;
    final v = c.value;
    var target = v.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > v.duration) target = v.duration;
    await c.seekTo(target);
    _showControls();
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
    if (mounted) {
      Navigator.pop(context);
      setState(() {});
      _showControls();
    }
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
      ),
      body: SafeArea(
        top: !_fullscreen,
        bottom: !_fullscreen,
        child: _buildVideo(),
      ),
    );
  }

  Widget _buildVideo() {
    if (_loading) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Загрузка видео…', style: TextStyle(color: Colors.white60))]));
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 48),
      const SizedBox(height: 12),
      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 18),
      OutlinedButton.icon(onPressed: _retry, icon: const Icon(Icons.refresh_rounded), label: const Text('Повторить')),
    ])));
    final c = _controller;
    if (c == null || !c.value.isInitialized) return const SizedBox.shrink();
    return Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: Stack(children: [
            Positioned.fill(child: VideoPlayer(c)),
            if (c.value.isBuffering) const Center(child: CircularProgressIndicator()),
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Stack(children: [
                  Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(.60), Colors.transparent, Colors.black.withOpacity(.72)], stops: const [0, .42, 1])))),
                  Positioned(top: 10, left: 10, right: 10, child: Row(children: [
                    Expanded(child: Text(_result?.title.isNotEmpty == true ? _result!.title : 'VK Видео', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
                    IconButton(onPressed: _fullscreenToggle, color: Colors.white, icon: Icon(_fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded)),
                  ])),
                  Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _roundButton(Icons.replay_10_rounded, () => _seek(const Duration(seconds: -10))),
                    const SizedBox(width: 18),
                    _roundButton(c.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, _togglePlay, large: true),
                    const SizedBox(width: 18),
                    _roundButton(Icons.forward_10_rounded, () => _seek(const Duration(seconds: 10))),
                  ])),
                  Positioned(left: 10, right: 10, bottom: 8, child: Column(children: [
                    VideoProgressIndicator(c, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Color(0xFFFFC107), bufferedColor: Colors.white54, backgroundColor: Colors.white30), padding: const EdgeInsets.symmetric(vertical: 8)),
                    Row(children: [
                      Text('${_time(c.value.position)} / ${_time(c.value.duration)}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                      const Spacer(),
                      IconButton(onPressed: () { c.setVolume(c.value.volume == 0 ? 1 : 0); _showControls(); }, color: Colors.white, icon: Icon(c.value.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded)),
                      Text('${_speedValue}x', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      IconButton(onPressed: _showSpeed, color: Colors.white, icon: const Icon(Icons.speed_rounded)),
                      IconButton(onPressed: _showQuality, color: Colors.white, icon: const Icon(Icons.high_quality_rounded)),
                    ]),
                  ])),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onPressed, {bool large = false}) {
    return Material(color: Colors.black.withOpacity(.45), shape: const CircleBorder(), child: InkWell(onTap: onPressed, customBorder: const CircleBorder(), child: Padding(padding: EdgeInsets.all(large ? 18 : 12), child: Icon(icon, color: Colors.white, size: large ? 34 : 25))));
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
