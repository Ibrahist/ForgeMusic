import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/lrc.dart';
import '../../data/models/track.dart';
import '../../player/player_snapshot.dart';
import '../../state/providers.dart';
import '../theme/forge_theme.dart';
import '../widgets/forge_widgets.dart';
import '../playback.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  String? _paintedId;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(playbackProvider).valueOrNull;
    final track = snapshot?.track;
    if (track != null && track.id != _paintedId && ref.read(settingsProvider).dynamicColor) {
      _paintedId = track.id;
      Future<void>.microtask(() => _paint(track));
    }
    return Scaffold(
      body: SafeArea(
        child: track == null || snapshot == null
            ? const Center(child: Text('Nothing is playing yet.'))
            : ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
                children: [
                  Row(
                    children: [
                      IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.keyboard_arrow_down_rounded)),
                      const Spacer(),
                      IconButton(onPressed: () => context.push('/queue'), icon: const Icon(Icons.queue_music)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(child: _Cover(track: track)),
                  const SizedBox(height: 26),
                  Text(track.title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(track.artist),
                  const SizedBox(height: 18),
                  WaveformSeekBar(
                    seed: track.id,
                    position: snapshot.position,
                    duration: snapshot.duration ?? track.duration,
                    onSeek: (position) => ref.read(playerProvider).seek(position),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDuration(snapshot.position)),
                      Text(formatRemaining(snapshot.duration ?? track.duration, snapshot.position)),
                    ],
                  ),
                  if (snapshot.message != null) ...[
                    const SizedBox(height: 8),
                    Text(snapshot.message!, style: const TextStyle(color: ForgeColors.danger)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Shuffle',
                        onPressed: () => ref.read(playerProvider).toggleShuffle(),
                        icon: Icon(Icons.shuffle, color: snapshot.shuffle ? Theme.of(context).colorScheme.primary : null),
                      ),
                      IconButton(
                        iconSize: 36,
                        onPressed: () => ref.read(playerProvider).skipToPrevious(),
                        icon: const Icon(Icons.skip_previous_rounded),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(16)),
                        onPressed: () {
                          final player = ref.read(playerProvider);
                          if (snapshot.playing) {
                            player.pause();
                          } else {
                            player.play();
                          }
                        },
                        child: Icon(snapshot.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 36),
                      ),
                      IconButton(
                        iconSize: 36,
                        onPressed: () => ref.read(playerProvider).skipToNext(),
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                      IconButton(
                        tooltip: 'Repeat',
                        onPressed: () => ref.read(playerProvider).cycleRepeat(),
                        icon: Icon(
                          snapshot.repeat == RepeatMode.one ? Icons.repeat_one : Icons.repeat,
                          color: snapshot.repeat == RepeatMode.off ? null : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => _sleep(snapshot.sleepEndOfTrack),
                        icon: const Icon(Icons.bedtime_outlined),
                        label: Text(_sleepLabel(snapshot)),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => fetchLyrics(context, ref, track),
                        icon: const Icon(Icons.lyrics_outlined),
                        label: const Text('Lyrics'),
                      ),
                    ],
                  ),
                  if (snapshot.buffering) const LinearProgressIndicator(),
                  _Lyrics(track: track, position: snapshot.position),
                ],
              ),
      ),
    );
  }

  String _sleepLabel(PlayerSnapshot snapshot) {
    if (snapshot.sleepEndOfTrack) return 'End of track';
    final left = snapshot.sleepRemaining;
    if (left == null) return 'Sleep';
    return 'Sleep ${formatDuration(left)}';
  }

  Future<void> _sleep(bool endOfTrack) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final minutes in [15, 30, 45, 60])
              ListTile(
                title: Text('$minutes minutes'),
                onTap: () => Navigator.pop(sheet, '$minutes'),
              ),
            ListTile(title: const Text('End of this track'), onTap: () => Navigator.pop(sheet, 'end')),
            ListTile(title: const Text('Turn sleep off'), onTap: () => Navigator.pop(sheet, 'off')),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final player = ref.read(playerProvider);
    if (choice == 'off') {
      await player.setSleep(null);
    } else if (choice == 'end') {
      await player.setSleep(null, endOfTrack: true);
    } else {
      await player.setSleep(Duration(minutes: int.parse(choice)));
    }
  }

  Future<void> _paint(Track track) async {
    try {
      ImageProvider? image;
      final file = track.artworkPath;
      if (file != null && File(file).existsSync()) {
        image = FileImage(File(file));
      } else if (track.thumbnailUrl != null) {
        image = CachedNetworkImageProvider(track.thumbnailUrl!);
      }
      if (image == null) {
        ref.read(accentProvider.notifier).reset();
        return;
      }
      final palette = await PaletteGenerator.fromImageProvider(
        image,
        size: const Size(80, 80),
        maximumColorCount: 8,
      );
      final color = palette.vibrantColor?.color ?? palette.dominantColor?.color;
      if (color != null) ref.read(accentProvider.notifier).apply(color);
    } catch (_) {}
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
      child: ArtworkView(path: track.artworkPath, url: track.thumbnailUrl, size: 320, radius: 28),
    );
  }
}

class _Lyrics extends StatelessWidget {
  const _Lyrics({required this.track, required this.position});

  final Track track;
  final Duration position;

  @override
  Widget build(BuildContext context) {
    final synced = track.syncedLyrics;
    if (synced != null && synced.trim().isNotEmpty) {
      final lines = LrcParser.parse(synced);
      if (lines.isNotEmpty) {
        final current = LrcParser.indexAt(lines, position);
        return Column(
          children: [
            for (var i = 0; i < lines.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  lines[i].text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: i == current ? Theme.of(context).colorScheme.primary : ForgeColors.mist,
                  ),
                ),
              ),
          ],
        );
      }
    }
    final plain = track.lyrics;
    if (plain == null || plain.trim().isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text('Lyrics will sit here once they are found.'),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(plain, textAlign: TextAlign.center),
    );
  }
}
