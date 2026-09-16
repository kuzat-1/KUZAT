import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../services/playback_preferences.dart';
import '../services/playback_store.dart';

class PlayerScreen extends StatefulWidget {
  final String url;
  const PlayerScreen({super.key, required this.url});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _video;
  YoutubePlayerController? _youtube;
  List<VideoTrack> _tracks = const [];
  Timer? _saveTimer;
  Timer? _controlsTimer;
  bool _loading = true;
  bool _isYoutube = false;
  bool _fullscreen = false;
  bool _controlsVisible = true;
  bool _retrying = false;
  String? _error;
  double _speed = 1.0;
  String _qualityLabel = 'Авто';
  Duration _resume = Duration.zero;
  String _title = 'Видео';
  PlaybackPreferences _preferences = PlaybackPreferences.defaults();

  @override
  void initState() {
    super.initState();
    _start();
  }

  String? _youtubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    if (uri.host.contains('youtube.com') || uri.host.contains('youtube-nocookie.com')) {
      if (uri.path == '/watch') return uri.queryParameters['v'];
      if (uri.pathSegments.length >= 2 && (uri.pathSegments.first == 'shorts' || uri.pathSegments.first == 'embed')) return uri.pathSegments[1];
    }
    return null;
  }

  Future<void> _start() async {
    _saveTimer?.cancel();
    _controlsTimer?.cancel();
    final oldVideo = _video;
    final oldYoutube = _youtube;
    _video = null;
    _youtube = null;
    _tracks = const [];
    await oldVideo?.dispose();
    oldYoutube?.close();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _retrying = false;
      _controlsVisible = true;
      _isYoutube = false;
    });

    try {
      final previous = await PlaybackStore.find(widget.url);
      _resume = previous?.position ?? Duration.zero;
      _preferences = await PlaybackPreferences.load();
      final yt = _youtubeId(widget.url);

      if (yt != null && yt.isNotEmpty) {
        _isYoutube = true;
        _title = previous?.title ?? 'YouTube • $yt';
        final controller = YoutubePlayerController.fromVideoId(
          videoId: yt,
          autoPlay: _preferences.autoplay,
          startSeconds: _resume.inMilliseconds > 0 ? _resume.inMilliseconds / 1000 : null,
          params: const YoutubePlayerParams(showControls: false, showFullscreenButton: false, strictRelatedVideos: true, privacyEnhancedMode: true, playsInline: true),
        );
        _youtube = controller;
        _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());
        if (mounted) {
          setState(() => _loading = false);
          _scheduleControlsHide();
        }
        return;
      }

      final uri = Uri.tryParse(widget.url);
      if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
        throw const FormatException('Неверная ссылка');
      }

      final controller = VideoPlayerController.networkUrl(uri);
      await controller.initialize().timeout(const Duration(seconds: 20));
      _video = controller;
      if (_resume > Duration.zero && _resume < controller.value.duration) await controller.seekTo(_resume);
      if (controller.isVideoTrackSupportAvailable()) {
        try {
          _tracks = await controller.getVideoTracks();
          _tracks = [..._tracks]..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
          final selected = _tracks.where((t) => t.isSelected).firstOrNull;
          if (selected != null) _qualityLabel = _trackLabel(selected);
          await _applyDefaultQuality(controller);
        } catch (_) {
          _tracks = const [];
        }
      }
      controller.addListener(_videoChanged);
      if (_preferences.autoplay) await controller.play();
      _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveProgress());
      if (!mounted) return;
      setState(() => _loading = false);
      _scheduleControlsHide();
    } on TimeoutException {
      _setError('Источник отвечает слишком долго. Проверьте интернет-соединение и попробуйте ещё раз.');
    } on FormatException {
      _setError('Ссылка на видео некорректна. Вернитесь назад и вставьте правильную ссылку.');
    } catch (_) {
      if (_isYoutube) {
        _setError('YouTube не удалось загрузить. Видео может быть недоступно, удалено или ограничено для просмотра.');
      } else {
        _setError('Не удалось открыть видео. Источник может быть недоступен, ссылка устарела или формат не поддерживается.');
      }
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _loading = false;
      _retrying = false;
    });
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    await _start();
  }

  Future<void> _applyDefaultQuality(VideoPlayerController controller) async {
    final wanted = _preferences.defaultQuality;
    if (wanted == 'Авто' || _tracks.isEmpty) return;
    final match = _tracks.where((track) => _trackLabel(track) == wanted || '${track.height}p' == wanted).firstOrNull;
    if (match == null) return;
    await controller.selectVideoTrack(match);
    if (mounted) setState(() => _qualityLabel = _trackLabel(match));
  }

  void _videoChanged() {
    if (!mounted) return;
    setState(() {});
    if (_video?.value.isPlaying == true && _controlsVisible) _scheduleControlsHide();
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    final playing = _isYoutube ? _youtube != null : _video?.value.isPlaying == true;
    if (!playing) return;
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
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
    if (_isYoutube && _youtube != null) {
      final state = await _youtube!.playerState;
      if (state == PlayerState.playing) {
        await _youtube!.pauseVideo();
        _controlsTimer?.cancel();
        if (mounted) setState(() => _controlsVisible = true);
      } else {
        await _youtube!.playVideo();
        _showControls();
      }
      return;
    }
    final c = _video;
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
    Duration position = Duration.zero;
    Duration duration = Duration.zero;
    if (_video != null && _video!.value.isInitialized) {
      position = _video!.value.position;
      duration = _video!.value.duration;
    } else if (_youtube != null) {
      final seconds = await _youtube!.currentTime;
      final total = await _youtube!.duration;
      position = Duration(milliseconds: (seconds * 1000).round());
      duration = Duration(milliseconds: (total * 1000).round());
    }
    if (position <= Duration.zero) return;
    if (duration > Duration.zero && position >= duration - const Duration(seconds: 10)) {
      await PlaybackStore.remove(widget.url);
      return;
    }
    await PlaybackStore.save(PlaybackEntry(url: widget.url, title: _title, positionMs: position.inMilliseconds, durationMs: duration.inMilliseconds, updatedAtMs: DateTime.now().millisecondsSinceEpoch));
  }

  String _trackLabel(VideoTrack track) {
    if (track.label != null && track.label!.trim().isNotEmpty) return track.label!;
    if (track.height != null) return '${track.height}p';
    if (track.bitrate != null) return '${(track.bitrate! / 1000).round()} kbps';
    return 'Качество';
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _controlsTimer?.cancel();
    unawaited(_saveProgress());
    _video?.removeListener(_videoChanged);
    _video?.dispose();
    _youtube?.close();
    unawaited(_restoreSystemUi());
    super.dispose();
  }

  Future<void> _restoreSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  }

  Future<void> _toggleFullscreen() async {
    if (_isYoutube) {
      _youtube?.toggleFullScreen();
      _showControls();
      return;
    }
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

  Future<void> _seekBy(Duration delta) async {
    final c = _video;
    if (c == null) return;
    final v = c.value;
    var target = v.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > v.duration) target = v.duration;
    await c.seekTo(target);
    _showControls();
  }

  Future<void> _youtubeSeekBy(double delta) async {
    final c = _youtube;
    if (c == null) return;
    final position = await c.currentTime;
    final duration = await c.duration;
    await c.seekTo(seconds: (position + delta).clamp(0.0, duration).toDouble());
    _showControls();
  }

  Future<void> _selectTrack(VideoTrack? track) async {
    final c = _video;
    if (c == null) return;
    final playing = c.value.isPlaying;
    final position = c.value.position;
    await c.selectVideoTrack(track);
    await c.seekTo(position);
    if (playing) await c.play();
    if (!mounted) return;
    setState(() => _qualityLabel = track == null ? 'Авто' : _trackLabel(track));
    Navigator.pop(context);
    _showControls();
  }

  Future<void> _setSpeed(double speed) async {
    _speed = speed;
    await _video?.setPlaybackSpeed(speed);
    await _youtube?.setPlaybackRate(speed);
    if (mounted) {
      setState(() {});
      Navigator.pop(context);
      _showControls();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _fullscreen ? null : AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
      body: SafeArea(top: !_fullscreen, bottom: !_fullscreen, child: _buildPlayer()),
    );
  }

  Widget _buildPlayer() {
    if (_loading) return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Загрузка видео…', style: TextStyle(color: Colors.white60))]));
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 48),
      const SizedBox(height: 14),
      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.4)),
      const SizedBox(height: 18),
      OutlinedButton.icon(onPressed: _retrying ? null : _retry, icon: _retrying ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded), label: Text(_retrying ? 'Повторная попытка…' : 'Повторить')),
    ])));

    final player = _isYoutube && _youtube != null ? YoutubePlayer(controller: _youtube!) : (_video != null && _video!.value.isInitialized ? VideoPlayer(_video!) : const SizedBox.shrink());
    final aspect = _isYoutube ? 16 / 9 : (_video?.value.aspectRatio ?? 16 / 9);
    return Center(child: AspectRatio(aspectRatio: aspect, child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: Stack(children: [
        Positioned.fill(child: player),
        if (!_isYoutube && _video?.value.isBuffering == true) const Center(child: CircularProgressIndicator()),
        _overlayControls(),
      ]),
    )));
  }

  Widget _overlayControls() {
    return AnimatedOpacity(
      opacity: _controlsVisible ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      child: IgnorePointer(ignoring: !_controlsVisible, child: Stack(children: [
        Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent, Colors.black87], stops: const [0, .42, 1])))),
        Positioned(top: 10, left: 10, right: 10, child: Row(children: [
          Expanded(child: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
          IconButton(onPressed: _showSpeed, color: Colors.white, icon: const Icon(Icons.speed_rounded)),
          IconButton(onPressed: _toggleFullscreen, color: Colors.white, icon: Icon(_fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded)),
        ])),
        Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          _roundButton(Icons.replay_10_rounded, () => _isYoutube ? _youtubeSeekBy(-10) : _seekBy(const Duration(seconds: -10))),
          const SizedBox(width: 18),
          _roundButton(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, _togglePlay, large: true),
          const SizedBox(width: 18),
          _roundButton(Icons.forward_10_rounded, () => _isYoutube ? _youtubeSeekBy(10) : _seekBy(const Duration(seconds: 10))),
        ])),
        Positioned(left: 10, right: 10, bottom: 8, child: _bottomControls()),
      ])),
    );
  }

  bool get _playing => _video?.value.isPlaying == true;

  Widget _bottomControls() {
    if (_isYoutube && _youtube != null) {
      return YoutubeValueBuilder(controller: _youtube!, builder: (context, value) {
        final duration = value.metaData.duration;
        return Column(children: [
          StreamBuilder<Duration>(stream: _youtube!.getCurrentPositionStream(period: const Duration(milliseconds: 500)), builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final max = duration <= 0 ? 1.0 : duration;
            final current = (position.inMilliseconds / 1000).clamp(0.0, max).toDouble();
            return Slider(value: current, max: max, onChanged: (s) => _youtube!.seekTo(seconds: s), activeColor: const Color(0xFFFFC107), inactiveColor: Colors.white30);
          }),
          Row(children: [
            Text(_format(value.metaData.duration), style: const TextStyle(color: Colors.white, fontSize: 11)),
            const Spacer(),
            Text('${_speed}x', style: const TextStyle(color: Colors.white, fontSize: 12)),
            IconButton(onPressed: _showSpeed, color: Colors.white, icon: const Icon(Icons.speed_rounded)),
            IconButton(onPressed: _showQuality, color: Colors.white, icon: const Icon(Icons.high_quality_rounded)),
          ]),
          const Align(alignment: Alignment.centerLeft, child: Text('YouTube: качество выбирается автоматически', style: TextStyle(color: Colors.white54, fontSize: 10))),
        ]);
      });
    }
    final c = _video;
    if (c == null) return const SizedBox.shrink();
    final v = c.value;
    return Column(children: [
      VideoProgressIndicator(c, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Color(0xFFFFC107), bufferedColor: Colors.white54, backgroundColor: Colors.white30), padding: const EdgeInsets.symmetric(vertical: 8)),
      Row(children: [
        Text('${_format(v.position)} / ${_format(v.duration)}', style: const TextStyle(color: Colors.white, fontSize: 11)),
        const Spacer(),
        IconButton(onPressed: () { c.setVolume(c.value.volume == 0 ? 1 : 0); _showControls(); }, color: Colors.white, icon: Icon(c.value.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded)),
        Text(_qualityLabel, style: const TextStyle(color: Colors.white, fontSize: 11)),
        IconButton(onPressed: _showSpeed, color: Colors.white, icon: const Icon(Icons.speed_rounded)),
        IconButton(onPressed: _showQuality, color: Colors.white, icon: const Icon(Icons.high_quality_rounded)),
      ]),
    ]);
  }

  String _format(Duration value) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = value.inHours, m = value.inMinutes.remainder(60), s = value.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  Widget _roundButton(IconData icon, VoidCallback onPressed, {bool large = false}) {
    return Material(color: Colors.black.withOpacity(.45), shape: const CircleBorder(), child: InkWell(onTap: onPressed, customBorder: const CircleBorder(), child: Padding(padding: EdgeInsets.all(large ? 18 : 12), child: Icon(icon, color: Colors.white, size: large ? 34 : 25))));
  }

  void _showQuality() {
    if (_isYoutube) return;
    final tracks = _tracks;
    if (tracks.isEmpty) return;
    showModalBottomSheet<void>(context: context, backgroundColor: const Color(0xFF171717), builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Качество', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      ListTile(title: const Text('Авто'), trailing: _qualityLabel == 'Авто' ? const Icon(Icons.check_rounded, color: Color(0xFFFFC107)) : null, onTap: () => _selectTrack(null)),
      for (final track in tracks) ListTile(title: Text(_trackLabel(track)), trailing: _qualityLabel == _trackLabel(track) ? const Icon(Icons.check_rounded, color: Color(0xFFFFC107)) : null, onTap: () => _selectTrack(track)),
    ]))));
  }

  void _showSpeed() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet<void>(context: context, backgroundColor: const Color(0xFF171717), builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Скорость', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      for (final speed in speeds) ListTile(title: Text('${speed}x'), trailing: _speed == speed ? const Icon(Icons.check_rounded) : null, onTap: () => _setSpeed(speed)),
    ]))));
  }
}
