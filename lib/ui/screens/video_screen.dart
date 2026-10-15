import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_failure.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/skip_window.dart';
import '../../state/providers.dart';
import '../theme/forge_theme.dart';

class VideoScreen extends ConsumerStatefulWidget {
  const VideoScreen({super.key});

  @override
  ConsumerState<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends ConsumerState<VideoScreen> {
  VideoPlayerController? _controller;
  String? _message;
  bool _controls = true;
  bool _fullscreen = false;
  double _volume = 0.5;
  bool _showVolume = false;
  String? _seekHint;
  double _doubleTapX = 0;
  List<SkipSegment> _segments = const [];
  Duration? _skipUntil;
  Duration? _previous;
  String? _votes;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_open);
  }

  Future<void> _open() async {
    await ref.read(playerProvider).pause();
    await ref.read(deviceProvider).keepScreenOn(true);
    _volume = await ref.read(deviceProvider).volume();
    final launch = ref.read(videoLaunchProvider);
    if (launch == null) {
      setState(() => _message = 'There is no video to open.');
      return;
    }
    try {
      final VideoPlayerController controller;
      final local = launch.video;
      if (local != null) {
        controller = VideoPlayerController.contentUri(Uri.parse(local.uri));
      } else {
        final resolved = await ref.read(resolverProvider).resolveVideo(
          videoId: launch.youtubeId!,
          dataSaver: launch.dataSaver,
        );
        final file = resolved.filePath;
        controller = file != null
            ? VideoPlayerController.file(File(file))
            : VideoPlayerController.networkUrl(resolved.uri, httpHeaders: resolved.headers ?? const {});
      }
      await controller.initialize();
      await controller.play();
      controller.addListener(_onTick);
      final youtubeId = launch.youtubeId;
      if (youtubeId != null) {
        unawaited(_loadExtras(youtubeId));
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error is AppFailure ? error.message : 'This video would not play.';
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    ref.read(deviceProvider).keepScreenOn(false);
    super.dispose();
  }

  Future<void> _loadExtras(String videoId) async {
    final votes = await ref.read(dislikeProvider).votes(videoId);
    final segments = await ref.read(sponsorProvider).segments(videoId);
    if (!mounted) return;
    setState(() {
      _segments = segments;
      if (votes != null) {
        _votes = '${formatCount(votes.likes)} likes · ${formatCount(votes.dislikes)} dislikes';
      }
    });
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final position = controller.value.position;
    final skip = ref.read(settingsProvider).sponsorBlock;
    if (skip && _segments.isNotEmpty) {
      final previous = _previous;
      final jumpedBack = previous != null && position + const Duration(seconds: 1) < previous;
      _previous = position;
      if (jumpedBack) _skipUntil = null;
      if (_skipUntil != null && position < _skipUntil!) {
        setState(() {});
        return;
      }
      _skipUntil = null;
      final jump = nextSkip(_segments, position);
      if (jump != null) {
        _skipUntil = jump;
        controller.seekTo(jump);
        _seekHint = 'Skipped';
      }
    } else {
      _previous = position;
    }
    setState(() {});
  }

  void _seekBy(int seconds) {
    final controller = _controller;
    if (controller == null) return;
    final next = controller.value.position + Duration(seconds: seconds);
    final duration = controller.value.duration;
    final clamped = next < Duration.zero
        ? Duration.zero
        : (next > duration ? duration : next);
    controller.seekTo(clamped);
    setState(() => _seekHint = seconds < 0 ? '${seconds}s' : '+${seconds}s');
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _seekHint = null);
    });
  }

  Future<void> _fullscreenToggle() async {
    final next = !_fullscreen;
    if (next) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (mounted) setState(() => _fullscreen = next);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final launch = ref.watch(videoLaunchProvider);
    final title = launch?.video?.title ?? launch?.title ?? 'Video';
    return Scaffold(
      backgroundColor: Colors.black,
      body: controller == null
          ? Center(child: _message == null ? const CircularProgressIndicator() : Text(_message!))
          : LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _controls = !_controls),
                  onDoubleTapDown: (details) => _doubleTapX = details.localPosition.dx,
                  onDoubleTap: () {
                    final width = constraints.maxWidth;
                    if (_doubleTapX < width * 0.4) {
                      _seekBy(-10);
                    } else if (_doubleTapX > width * 0.6) {
                      _seekBy(10);
                    } else {
                      setState(() => _controls = !_controls);
                    }
                  },
                  onVerticalDragUpdate: (details) async {
                    if (details.localPosition.dx < constraints.maxWidth * 0.55) return;
                    final delta = -details.delta.dy / constraints.maxHeight;
                    _volume = (_volume + delta).clamp(0, 1);
                    await ref.read(deviceProvider).setVolume(_volume);
                    if (mounted) setState(() => _showVolume = true);
                  },
                  onVerticalDragEnd: (_) {
                    Future<void>.delayed(const Duration(milliseconds: 600), () {
                      if (mounted) setState(() => _showVolume = false);
                    });
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio,
                          child: VideoPlayer(controller),
                        ),
                      ),
                      if (_seekHint != null)
                        Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                            child: Padding(padding: const EdgeInsets.all(16), child: Text(_seekHint!, style: const TextStyle(color: Colors.white, fontSize: 22))),
                          ),
                        ),
                      if (_showVolume)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 24),
                            child: _VolumePill(volume: _volume),
                          ),
                        ),
                      if (_controls) _bar(controller, title),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _bar(VideoPlayerController controller, String title) {
    final value = controller.value;
    final youtube = ref.read(videoLaunchProvider)?.youtubeId != null;
    return Align(
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black87],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white)),
                  ),
                  IconButton(
                    onPressed: _fullscreenToggle,
                    icon: Icon(_fullscreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
                  ),
                ],
              ),
              VideoProgressIndicator(controller, allowScrubbing: true, colors: const VideoProgressColors(playedColor: ForgeColors.ember)),
              Row(
                children: [
                  IconButton(
                    onPressed: () => value.isPlaying ? controller.pause() : controller.play(),
                    icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                  ),
                  Text(
                    '${formatDuration(value.position)} / ${formatDuration(value.duration)}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Spacer(),
                  if (_votes != null)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          _votes!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
              if (youtube)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Dislike counts are estimates from Return YouTube Dislike.',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VolumePill extends StatelessWidget {
  const _VolumePill({required this.volume});

  final double volume;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 140,
      alignment: Alignment.bottomCenter,
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(18)),
      child: FractionallySizedBox(
        heightFactor: volume.clamp(0.05, 1),
        child: Container(
          decoration: BoxDecoration(color: ForgeColors.ember, borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}
