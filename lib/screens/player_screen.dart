import 'package:flutter/material.dart';
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
  bool _loading = true;
  String? _error;
  bool _isYoutube = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  String? _youtubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    if (uri.host.contains('youtube.com')) {
      if (uri.path == '/watch') return uri.queryParameters['v'];
      if (uri.pathSegments.length >= 2 && (uri.pathSegments.first == 'shorts' || uri.pathSegments.first == 'embed')) {
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
        ),
      );
      if (mounted) setState(() => _loading = false);
      return;
    }

    final uri = Uri.tryParse(widget.url);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      setState(() { _error = 'Неверная ссылка на видео'; _loading = false; });
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(uri);
      await controller.initialize();
      await controller.play();
      if (!mounted) return;
      setState(() { _video = controller; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Не удалось открыть видео'; _loading = false; });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    _youtube?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('KUZAT', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: _showQuality, icon: const Icon(Icons.tune_rounded)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.fullscreen_rounded)),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: Center(child: _buildPlayer())),
          _controls(),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    if (_loading) return const CircularProgressIndicator();
    if (_error != null) return Text(_error!, style: const TextStyle(color: Colors.white70));
    if (_isYoutube && _youtube != null) {
      return YoutubePlayer(controller: _youtube!, aspectRatio: 16 / 9);
    }
    if (_video != null) {
      return AspectRatio(aspectRatio: _video!.value.aspectRatio, child: VideoPlayer(_video!));
    }
    return const SizedBox.shrink();
  }

  Widget _controls() {
    if (_isYoutube) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
        child: Row(children: [
          const Icon(Icons.info_outline, size: 18, color: Colors.white54),
          const SizedBox(width: 8),
          const Expanded(child: Text('Качество для YouTube выбирается самим YouTube', style: TextStyle(color: Colors.white54, fontSize: 12))),
          IconButton(onPressed: _showQuality, icon: const Icon(Icons.settings_rounded)),
        ]),
      );
    }
    final v = _video;
    if (v == null) return const SizedBox(height: 24);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: Column(children: [
        VideoProgressIndicator(v, allowScrubbing: true, padding: const EdgeInsets.symmetric(vertical: 8)),
        Row(children: [
          IconButton(onPressed: () => setState(() => v.value.isPlaying ? v.pause() : v.play()), icon: Icon(v.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded)),
          IconButton(onPressed: () => v.setVolume(v.value.volume == 0 ? 1 : 0), icon: Icon(v.value.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded)),
          const Spacer(),
          IconButton(onPressed: _showQuality, icon: const Icon(Icons.settings_rounded)),
        ]),
      ]),
    );
  }

  void _showQuality() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171717),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Качество', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            if (_isYoutube)
              const ListTile(leading: Icon(Icons.auto_awesome), title: Text('Авто'), subtitle: Text('YouTube автоматически выбирает качество'))
            else ...[
              for (final q in const ['Авто', '1080p', '720p', '480p', '360p', '240p', '144p'])
                ListTile(leading: Icon(q == 'Авто' ? Icons.auto_awesome : Icons.hd_outlined), title: Text(q), onTap: () => Navigator.pop(context)),
            ],
          ]),
        ),
      ),
    );
  }
}
