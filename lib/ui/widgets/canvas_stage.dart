import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../data/models/track.dart';
import '../../state/providers.dart';
import '../theme/forge_theme.dart';
import 'forge_widgets.dart';

/// A looping clip the listener attached, or a slow move across the cover.
class CanvasStage extends ConsumerStatefulWidget {
  const CanvasStage({super.key, required this.track, this.size = 320});

  final Track track;
  final double size;

  @override
  ConsumerState<CanvasStage> createState() => _CanvasStageState();
}

class _CanvasStageState extends ConsumerState<CanvasStage> with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  VideoPlayerController? _video;
  String? _path;
  String? _loadedFor;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat(reverse: true);
    _load();
  }

  @override
  void didUpdateWidget(CanvasStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id) _load();
  }

  Future<void> _load() async {
    final id = widget.track.id;
    final path = await ref.read(databaseProvider).canvasPath(id);
    if (!mounted || widget.track.id != id) return;
    if (path == _path && _loadedFor == id && (_video != null || path == null)) {
      setState(() {});
      return;
    }
    await _video?.dispose();
    _video = null;
    _path = path;
    _loadedFor = id;
    if (path != null && File(path).existsSync()) {
      final controller = VideoPlayerController.file(File(path));
      try {
        await controller.initialize();
        await controller.setLooping(true);
        await controller.setVolume(0);
        await controller.play();
        if (!mounted || widget.track.id != id) {
          await controller.dispose();
          return;
        }
        _video = controller;
      } catch (_) {
        await controller.dispose();
        _path = null;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _motion.dispose();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await FilePicker.pickFile(type: FileType.video);
    final source = picked?.path;
    if (source == null) return;
    await ref.read(databaseProvider).setCanvas(widget.track.id, source);
    await _load();
    if (mounted) showForgeMessage(context, 'Canvas clip set for this song.');
  }

  Future<void> _clear() async {
    await ref.read(databaseProvider).clearCanvas(widget.track.id);
    await _video?.dispose();
    _video = null;
    _path = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final motion = ref.watch(settingsProvider).canvasMotion;
    final video = _video;
    final child = video != null && video.value.isInitialized
        ? FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: video.value.size.width,
              height: video.value.size.height,
              child: VideoPlayer(video),
            ),
          )
        : _Still(track: widget.track, motion: motion ? _motion : null, size: widget.size);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.28),
              blurRadius: 36,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              Positioned(
                right: 8,
                bottom: 8,
                child: Row(
                  children: [
                    _Chip(icon: Icons.movie_outlined, label: 'Canvas', onTap: _pick),
                    if (_path != null) ...[
                      const SizedBox(width: 6),
                      _Chip(icon: Icons.close, label: 'Clear', onTap: _clear),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Still extends StatelessWidget {
  const _Still({required this.track, required this.motion, required this.size});

  final Track track;
  final Animation<double>? motion;
  final double size;

  @override
  Widget build(BuildContext context) {
    final art = ArtworkView(path: track.artworkPath, url: track.thumbnailUrl, size: size, radius: 0);
    final animation = motion;
    if (animation == null) return art;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return Transform.scale(
          scale: 1.06 + (t * 0.08),
          child: Transform.translate(offset: Offset((t - 0.5) * 24, (0.5 - t) * 16), child: child),
        );
      },
      child: art,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ForgeColors.night.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: ForgeColors.paper),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: ForgeColors.paper, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
