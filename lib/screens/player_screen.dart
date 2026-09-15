import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

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
  bool _loading = true;
  bool _isYoutube = false;
  bool _fullscreen = false;
  String? _error;
  double _speed = 1.0;
  String _qualityLabel = 'Авто';

  @override
  void initState() {
    super.initState();
    _init();
  }

  String? _youtubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    }
    if (uri.host.contains('youtube.com') || uri.host.contains('youtube-nocookie.com')) {
      if (uri.path == '/watch') return uri.queryParameters['v'];
      if (uri.pathSegments.length >= 2 &&
          (uri.pathSegments.first == 'shorts' || uri.pathSegments.first == 'embed')) {
        return uri.pathSegments[1];
      }
    }
    return null;
  }

  Future<void> _init() async {
    final yt = _youtubeId(widget.url);
    if (yt != null && yt.isNotEmpty) {
      _isYoutube = true;
      _youtube = YoutubePlayerController.fromVideoId(
        videoId: yt,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: false,
          showFullscreenButton: false,
          strictRelatedVideos: true,
          privacyEnhancedMode: true,
          playsInline: true,
        ),
      );
      if (mounted) setState(() => _loading = false);
      return;
    }

    final uri = Uri.tryParse(widget.url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      if (mounted) {
        setState(() {
          _error = 'Неверная ссылка на видео';
          _loading = false;
        });
      }
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(uri);
      await controller.initialize();
      _video = controller;
      if (controller.isVideoTrackSupportAvailable()) {
        try {
          _tracks = await controller.getVideoTracks();
          _tracks = [..._tracks]..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
          final selected = _tracks.where((t) => t.isSelected).firstOrNull;
          if (selected != null) _qualityLabel = _trackLabel(selected);
        } catch (_) {
          _tracks = const [];
        }
      }
      controller.addListener(_videoChanged);
      await controller.play();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось открыть видео. Проверьте ссылку или доступность источника.';
        _loading = false;
      });
    }
  }

  void _videoChanged() {
    if (mounted) setState(() {});
  }

  String _trackLabel(VideoTrack track) {
    if (track.label != null && track.label!.trim().isNotEmpty) return track.label!;
    if (track.height != null) return '${track.height}p';
    if (track.bitrate != null) return '${(track.bitrate! / 1000).round()} kbps';
    return 'Качество';
  }

  @override
  void dispose() {
    _video?.removeListener(_videoChanged);
    _video?.dispose();
    _youtube?.close();
    _restoreSystemUi();
    super.dispose();
  }

  Future<void> _restoreSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> _toggleFullscreen() async {
    if (_isYoutube) {
      _youtube?.toggleFullScreen();
      return;
    }
    final next = !_fullscreen;
    setState(() => _fullscreen = next);
    if (next) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await _restoreSystemUi();
    }
  }

  Future<void> _seekBy(Duration delta) async {
    final controller = _video;
    if (controller == null) return;
    final value = controller.value;
    final target = value.position + delta;
    final duration = value.duration;
    final clamped = target < Duration.zero
        ? Duration.zero
        : target > duration
            ? duration
            : target;
    await controller.seekTo(clamped);
  }

  Future<void> _selectTrack(VideoTrack? track) async {
    final controller = _video;
    if (controller == null) return;
    final wasPlaying = controller.value.isPlaying;
    final position = controller.value.position;
    await controller.selectVideoTrack(track);
    await controller.seekTo(position);
    if (wasPlaying) await controller.play();
    if (!mounted) return;
    setState(() => _qualityLabel = track == null ? 'Авто' : _trackLabel(track));
    Navigator.of(context).pop();
  }

  Future<void> _setSpeed(double speed) async {
    _speed = speed;
    if (_video != null) await _video!.setPlaybackSpeed(speed);
    if (_youtube != null) await _youtube!.setPlaybackRate(speed);
    if (mounted) {
      setState(() {});
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _fullscreen
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: const Text('KUZAT', style: TextStyle(fontWeight: FontWeight.w800)),
              actions: [
                IconButton(
                  tooltip: 'Скорость',
                  onPressed: _showSpeed,
                  icon: const Icon(Icons.speed_rounded),
                ),
                IconButton(
                  tooltip: 'Полный экран',
                  onPressed: _toggleFullscreen,
                  icon: const Icon(Icons.fullscreen_rounded),
                ),
              ],
            ),
      body: SafeArea(
        top: !_fullscreen,
        bottom: !_fullscreen,
        child: Column(
          children: [
            Expanded(child: Center(child: _buildPlayer())),
            if (!_loading && _error == null) _controls(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    if (_loading) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('Загрузка видео…', style: TextStyle(color: Colors.white60)),
        ],
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 48),
            const SizedBox(height: 14),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _init();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    if (_isYoutube && _youtube != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: YoutubePlayer(controller: _youtube!),
      );
    }
    final video = _video;
    if (video != null && video.value.isInitialized) {
      return AspectRatio(
        aspectRatio: video.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(video),
            if (video.value.isBuffering)
              const IgnorePointer(child: CircularProgressIndicator()),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _controls() {
    if (_isYoutube && _youtube != null) return _youtubeControls(_youtube!);
    final video = _video;
    if (video == null) return const SizedBox.shrink();
    final value = video.value;
    return Material(
      color: const Color(0xFF0D0D0D),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          children: [
            VideoProgressIndicator(
              video,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Color(0xFFFFC107),
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white12,
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Назад 10 секунд',
                  onPressed: () => _seekBy(const Duration(seconds: -10)),
                  icon: const Icon(Icons.replay_10_rounded),
                ),
                IconButton(
                  tooltip: value.isPlaying ? 'Пауза' : 'Воспроизвести',
                  onPressed: () => value.isPlaying ? video.pause() : video.play(),
                  icon: Icon(value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
                IconButton(
                  tooltip: 'Вперёд 10 секунд',
                  onPressed: () => _seekBy(const Duration(seconds: 10)),
                  icon: const Icon(Icons.forward_10_rounded),
                ),
                Text('${_format(value.position)} / ${_format(value.duration)}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const Spacer(),
                IconButton(
                  tooltip: value.volume == 0 ? 'Включить звук' : 'Выключить звук',
                  onPressed: () => video.setVolume(value.volume == 0 ? 1 : 0),
                  icon: Icon(value.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                ),
                IconButton(
                  tooltip: 'Скорость',
                  onPressed: _showSpeed,
                  icon: const Icon(Icons.speed_rounded),
                ),
                IconButton(
                  tooltip: 'Качество',
                  onPressed: _showQuality,
                  icon: const Icon(Icons.high_quality_rounded),
                ),
                IconButton(
                  tooltip: 'Полный экран',
                  onPressed: _toggleFullscreen,
                  icon: const Icon(Icons.fullscreen_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _youtubeControls(YoutubePlayerController controller) {
    return Material(
      color: const Color(0xFF0D0D0D),
      child: YoutubeValueBuilder(
        controller: controller,
        builder: (context, value) {
          final duration = value.metaData.duration;
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: [
                StreamBuilder<Duration>(
                  stream: controller.getCurrentPositionStream(period: const Duration(milliseconds: 500)),
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final max = duration <= 0 ? 1.0 : duration;
                    return Slider(
                      value: position.inMilliseconds.clamp(0, duration > 0 ? duration * 1000 : 1000) / 1000,
                      max: max,
                      onChanged: (seconds) => controller.seekTo(seconds: seconds),
                    );
                  },
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Назад 10 секунд',
                      onPressed: () async {
                        final p = await controller.currentTime;
                        await controller.seekTo(seconds: (p - 10).clamp(0, duration));
                      },
                      icon: const Icon(Icons.replay_10_rounded),
                    ),
                    IconButton(
                      tooltip: 'Воспроизведение',
                      onPressed: () => value.playerState == PlayerState.playing ? controller.pauseVideo() : controller.playVideo(),
                      icon: Icon(value.playerState == PlayerState.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    ),
                    IconButton(
                      tooltip: 'Вперёд 10 секунд',
                      onPressed: () async {
                        final p = await controller.currentTime;
                        await controller.seekTo(seconds: (p + 10).clamp(0, duration));
                      },
                      icon: const Icon(Icons.forward_10_rounded),
                    ),
                    const Spacer(),
                    Text('${_speed}x', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    IconButton(onPressed: _showSpeed, icon: const Icon(Icons.speed_rounded)),
                    IconButton(onPressed: _toggleFullscreen, icon: const Icon(Icons.fullscreen_rounded)),
                  ],
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Качество: Auto — качество выбирает YouTube', style: TextStyle(color: Colors.white45, fontSize: 11)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  void _showQuality() {
    final video = _video;
    if (_isYoutube || video == null) {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF171717),
        builder: (_) => const SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Качество', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              SizedBox(height: 12),
              ListTile(leading: Icon(Icons.auto_awesome), title: Text('Авто'), subtitle: Text('YouTube автоматически выбирает качество')),
            ]),
          ),
        ),
      );
      return;
    }

    final canSelect = video.isVideoTrackSupportAvailable() && _tracks.isNotEmpty;
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
              const Text('Качество', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (!canSelect)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Источник не предоставляет отдельные варианты качества.', style: TextStyle(color: Colors.white60)),
                )
              else ...[
                ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: const Text('Авто'),
                  trailing: _qualityLabel == 'Авто' ? const Icon(Icons.check_rounded) : null,
                  onTap: () => _selectTrack(null),
                ),
                for (final track in _tracks)
                  ListTile(
                    leading: const Icon(Icons.hd_outlined),
                    title: Text(_trackLabel(track)),
                    subtitle: track.bitrate == null ? null : Text('${(track.bitrate! / 1000000).toStringAsFixed(1)} Mbps'),
                    trailing: _qualityLabel == _trackLabel(track) ? const Icon(Icons.check_rounded) : null,
                    onTap: () => _selectTrack(track),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showSpeed() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
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
              const Text('Скорость', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final speed in speeds)
                ListTile(
                  title: Text('${speed}x'),
                  trailing: _speed == speed ? const Icon(Icons.check_rounded) : null,
                  onTap: () => _setSpeed(speed),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
