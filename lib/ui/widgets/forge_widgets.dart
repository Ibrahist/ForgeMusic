import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/waveform.dart';
import '../../data/models/track.dart';
import '../../state/providers.dart';
import '../theme/forge_theme.dart';

void showForgeMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Row(
        children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.headlineSmall)),
          ?trailing,
        ],
      ),
    );
  }
}

class EmptyShelves extends StatelessWidget {
  const EmptyShelves({super.key, required this.onScan, required this.onYouTube});

  final VoidCallback onScan;
  final VoidCallback onYouTube;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DiscMark(size: 92),
          const SizedBox(height: 22),
          Text('Your shelves are quiet', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Pick a folder and Forgemusic will line the songs up, skipping duplicates.',
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: onScan, child: const Text('Scan this phone')),
          const SizedBox(height: 8),
          TextButton(onPressed: onYouTube, child: const Text('Browse YouTube')),
        ],
      ),
    );
  }
}

class DiscMark extends StatelessWidget {
  const DiscMark({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [ForgeColors.gold, accent, ForgeColors.night],
            stops: const [0.12, 0.55, 0.58],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.8), width: size * 0.06),
        ),
      ),
    );
  }
}

class ArtworkView extends StatelessWidget {
  const ArtworkView({
    super.key,
    this.path,
    this.url,
    this.size = 56,
    this.radius = 16,
    this.expand = false,
  });

  final String? path;
  final String? url;
  final double size;
  final double radius;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final file = path;
    final side = expand ? null : size;
    Widget child = DiscMark(size: (side ?? 72) * 0.62);
    if (file != null && file.isNotEmpty && File(file).existsSync()) {
      child = Image.file(File(file), width: side, height: side, fit: BoxFit.cover);
    } else if (url != null && url!.startsWith('http')) {
      child = CachedNetworkImage(
        imageUrl: url!,
        width: side,
        height: side,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => DiscMark(size: (side ?? 72) * 0.62),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: expand ? double.infinity : size,
        height: expand ? double.infinity : size,
        color: ForgeColors.card(context),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class SongTile extends ConsumerWidget {
  const SongTile({
    super.key,
    required this.track,
    required this.onTap,
    this.subtitle,
    this.onMore,
    this.artPath,
  });

  final Track track;
  final String? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final String? artPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveId = ref.watch(playbackProvider.select((async) => async.valueOrNull?.track?.id));
    final livePlaying = ref.watch(playbackProvider.select((async) => async.valueOrNull?.playing));
    final fallback = ref.read(playerProvider).snapshot;
    final currentId = liveId ?? fallback.track?.id;
    final playing = livePlaying ?? fallback.playing;
    final current = currentId == track.id;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: ArtworkView(
        path: track.artworkPath ?? artPath,
        url: track.thumbnailUrl,
        radius: 14,
      ),
      title: Row(
        children: [
          if (current) ...[
            PlayingBars(playing: playing, height: 14),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: current ? Theme.of(context).colorScheme.primary : onSurface,
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        subtitle ??
            '${track.artist} · ${formatDuration(track.duration)}${track.downloaded ? ' · On this phone' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (current)
            PlayToggleButton(
              playing: playing,
              size: 44,
              onPressed: () {
                final player = ref.read(playerProvider);
                if (playing) {
                  player.pause();
                } else {
                  player.play();
                }
              },
            ),
          if (onMore != null) IconButton(onPressed: onMore, icon: const Icon(Icons.more_horiz)),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Three bars that mark the song that is actually playing.
class PlayingBars extends StatefulWidget {
  const PlayingBars({super.key, required this.playing, this.height = 16, this.color});

  final bool playing;
  final double height;
  final Color? color;

  @override
  State<PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<PlayingBars> with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    if (widget.playing) _motion.repeat();
  }

  @override
  void didUpdateWidget(PlayingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !_motion.isAnimating) {
      _motion.repeat();
    } else if (!widget.playing && _motion.isAnimating) {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  double _barFactor(int index) {
    if (!widget.playing) return 0.28;
    final wave = 0.5 + 0.5 * math.sin((_motion.value + index * 0.22) * math.pi * 2);
    return 0.3 + 0.7 * wave;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: widget.height,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: widget.height * _barFactor(i),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A filled play control. The icon stays on the accent color while a song plays.
class PlayToggleButton extends StatelessWidget {
  const PlayToggleButton({
    super.key,
    required this.playing,
    required this.onPressed,
    this.size = 52,
  });

  final bool playing;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: playing ? 'Pause' : 'Play',
      child: Material(
        color: scheme.primary,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: scheme.onPrimary,
              size: size * 0.62,
            ),
          ),
        ),
      ),
    );
  }
}

class WaveformSeekBar extends StatelessWidget {
  const WaveformSeekBar({
    super.key,
    required this.seed,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final String seed;
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final peaks = syntheticPeaks(seed, 56);
    final total = duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
    final progress = (position.inMilliseconds / total).clamp(0, 1).toDouble();
    final accent = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        void seek(double dx) {
          final ratio = (dx / constraints.maxWidth).clamp(0, 1).toDouble();
          onSeek(Duration(milliseconds: (duration.inMilliseconds * ratio).round()));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => seek(details.localPosition.dx),
          onHorizontalDragUpdate: (details) => seek(details.localPosition.dx),
          child: SizedBox(
            height: 72,
            width: constraints.maxWidth,
            child: CustomPaint(
              painter: _WavePainter(
                peaks: peaks,
                progress: progress,
                active: accent,
                idle: ForgeColors.mist.withValues(alpha: 0.45),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.peaks,
    required this.progress,
    required this.active,
    required this.idle,
  });

  final List<double> peaks;
  final double progress;
  final Color active;
  final Color idle;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty) return;
    final slot = size.width / peaks.length;
    final paint = Paint();
    for (var i = 0; i < peaks.length; i++) {
      paint.color = (i + 0.5) / peaks.length <= progress ? active : idle;
      final height = (peaks[i] * (size.height - 8)).clamp(6.0, size.height);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * slot + 1.2, (size.height - height) / 2, slot - 2.4, height),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.active != active;
  }
}

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(playbackProvider).valueOrNull ?? ref.read(playerProvider).snapshot;
    final track = snapshot.track;
    if (track == null) return const SizedBox.shrink();
    final total = snapshot.duration?.inMilliseconds ?? track.durationMs;
    final progress = total <= 0 ? 0.0 : (snapshot.position.inMilliseconds / total).clamp(0, 1).toDouble();
    final accent = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Material(
        color: ForgeColors.card(context),
        elevation: 6,
        shadowColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: accent.withValues(alpha: 0.55)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/player'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                color: accent,
                backgroundColor: ForgeColors.mist.withValues(alpha: 0.28),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                child: Row(
                  children: [
                    ArtworkView(path: track.artworkPath, url: track.thumbnailUrl, size: 48, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: onSurface,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    PlayingBars(playing: snapshot.playing, height: 18),
                    IconButton(
                      tooltip: 'Previous',
                      onPressed: () => ref.read(playerProvider).skipToPrevious(),
                      icon: const Icon(Icons.skip_previous_rounded),
                    ),
                    PlayToggleButton(
                      playing: snapshot.playing,
                      size: 44,
                      onPressed: () {
                        final player = ref.read(playerProvider);
                        if (snapshot.playing) {
                          player.pause();
                        } else {
                          player.play();
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Next',
                      onPressed: () => ref.read(playerProvider).skipToNext(),
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
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
