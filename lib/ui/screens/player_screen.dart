import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/track.dart';
import '../../player/player_snapshot.dart';
import '../../state/providers.dart';
import '../theme/forge_theme.dart';
import '../widgets/canvas_stage.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/forge_widgets.dart';
import '../widgets/synced_lyrics.dart';
import '../playback.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  String? _paintedId;
  bool _lyricsOpen = false;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(playbackProvider).valueOrNull ?? ref.read(playerProvider).snapshot;
    final track = snapshot.track;
    if (track != null && track.id != _paintedId && ref.read(settingsProvider).dynamicColor) {
      _paintedId = track.id;
      Future<void>.microtask(() => _paint(track));
    }
    return Scaffold(
      body: SafeArea(
        child: track == null
            ? Center(
                child: Text(
                  'Nothing is playing yet.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
                children: [
                  Row(
                    children: [
                      IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.keyboard_arrow_down_rounded)),
                      const Spacer(),
                      IconButton(onPressed: () => context.push('/queue'), icon: const Icon(Icons.queue_music)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ForgeColors.mist),
                  ),
                  if (snapshot.offline) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Playing from this phone',
                      style: TextStyle(color: Theme.of(context).colorScheme.primary),
                    ),
                  ] else if (snapshot.streamBits != null && snapshot.streamBits! > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${(snapshot.streamBits! / 1000).round()} kbps',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Center(child: CanvasStage(track: track, size: 220)),
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
                    children: [
                      TextButton.icon(
                        onPressed: () => _sleep(snapshot.sleepEndOfTrack),
                        icon: const Icon(Icons.bedtime_outlined),
                        label: Text(_sleepLabel(snapshot)),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          if (track.hasLyrics) {
                            setState(() => _lyricsOpen = !_lyricsOpen);
                          } else {
                            fetchLyrics(context, ref, track);
                          }
                        },
                        icon: const Icon(Icons.lyrics_outlined),
                        label: Text(_lyricsOpen ? 'Hide lyrics' : 'Lyrics'),
                      ),
                      if (track.hasLyrics)
                        IconButton(
                          tooltip: 'Find lyrics',
                          onPressed: () => fetchLyrics(context, ref, track),
                          icon: const Icon(Icons.travel_explore),
                        ),
                    ],
                  ),
                  if (snapshot.buffering) const LinearProgressIndicator(),
                  SyncedLyricsView(
                    synced: track.syncedLyrics,
                    plain: track.lyrics,
                    position: snapshot.position,
                    expanded: _lyricsOpen,
                  ),
                    ],
                  ),
                ),
                _Transport(snapshot: snapshot),
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

/// Shuffle, play, and repeat stay on screen while the cover scrolls.
class _Transport extends ConsumerWidget {
  const _Transport({required this.snapshot});

  final PlayerSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.read(playerProvider);
    final scheme = Theme.of(context).colorScheme;
    final equalizerOn = ref.watch(settingsProvider.select((settings) => settings.equalizer));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ForgeColors.card(context),
        border: Border(top: BorderSide(color: scheme.primary.withValues(alpha: 0.55))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Shuffle',
                  onPressed: player.toggleShuffle,
                  icon: Icon(Icons.shuffle, color: snapshot.shuffle ? scheme.primary : scheme.onSurface),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Previous',
                  iconSize: 34,
                  onPressed: player.skipToPrevious,
                  icon: Icon(Icons.skip_previous_rounded, color: scheme.onSurface),
                ),
                const SizedBox(width: 10),
                PlayToggleButton(
                  playing: snapshot.playing,
                  size: 68,
                  onPressed: () {
                    if (snapshot.playing) {
                      player.pause();
                    } else {
                      player.play();
                    }
                  },
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'Next',
                  iconSize: 34,
                  onPressed: player.skipToNext,
                  icon: Icon(Icons.skip_next_rounded, color: scheme.onSurface),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Repeat',
                  onPressed: player.cycleRepeat,
                  icon: Icon(
                    snapshot.repeat == RepeatMode.one ? Icons.repeat_one : Icons.repeat,
                    color: snapshot.repeat == RepeatMode.off ? scheme.onSurface : scheme.primary,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => showEqualizerSheet(context),
              icon: Icon(Icons.graphic_eq, color: equalizerOn ? scheme.primary : scheme.onSurface),
              label: Text(equalizerOn ? 'Equalizer on' : 'Equalizer'),
            ),
          ],
        ),
      ),
    );
  }
}


