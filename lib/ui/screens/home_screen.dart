import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/library.dart';
import '../../data/models/playlist.dart';
import '../../data/models/track.dart';
import '../../state/providers.dart';
import '../playback.dart';
import '../theme/forge_theme.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/forge_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

const _windowDays = [1, 3, 7, 14, 30];

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _days = 7;
  int? _year;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final now = DateTime.now();
    final songs = library.index.songs;
    final history = library.history;
    final playingId = ref.watch(playbackProvider.select((async) => async.valueOrNull?.track?.id));
    final currentId = playingId ?? ref.read(playerProvider).snapshot.track?.id;
    final quiet = songs.isEmpty && history.isEmpty && currentId == null;
    final localEmpty = !songs.any((track) => track.source == TrackSource.local);

    final played = [...songs.where((track) => track.playCount > 0)]
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    final fresh = [...songs]..sort((a, b) => b.addedMs.compareTo(a.addedMs));
    final albums = [...library.index.albums]..sort((a, b) => _latest(b.tracks).compareTo(_latest(a.tracks)));
    final artists = [...library.index.artists]..sort((a, b) => _latest(b.tracks).compareTo(_latest(a.tracks)));
    final listens = _uniqueHistory(history);
    final ranked = _topInWindow(history, now, _days);
    final years = _memoryYears(history, now.year);
    final selectedYear = years.contains(_year) ? _year : (years.isEmpty ? null : years.first);
    final remembered = selectedYear == null ? const <Track>[] : _memories(history, selectedYear, now);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _Header(library: library.index),
            if (library.scanning) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Listening through your folders…'),
            ],
            if (library.message != null) ...[
              const SizedBox(height: 12),
              Text(library.message!),
            ],
            if (quiet)
              EmptyShelves(
                onScan: () => ref.read(libraryProvider.notifier).scan(),
                onYouTube: () => context.go('/youtube'),
              )
            else ...[
              if (localEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => ref.read(libraryProvider.notifier).scan(),
                    child: const Text('Scan this phone'),
                  ),
                ),
              const _NowPlaying(),
              _Mixes(
                songs: songs,
                played: played.take(24).toList(),
                random: songs.length >= 4 ? _dailyPicks(songs, now) : const [],
                fresh: fresh.take(16).toList(),
              ),
              if (listens.isNotEmpty)
                _TrackRow(
                  title: 'Recent listens',
                  tracks: listens.take(18).map((entry) => entry.track).toList(),
                  subtitleFor: (track) {
                    final entry = listens.firstWhere((item) => item.track.id == track.id);
                    return _timeAgo(entry.playedMs, now);
                  },
                ),
              if (history.isNotEmpty) ...[
                const SectionLabel('Top recent listens'),
                _DayChips(
                  days: _days,
                  onPick: (days) => setState(() => _days = days),
                ),
                const SizedBox(height: 12),
                if (ranked.isEmpty)
                  const Text('Nothing in this stretch.')
                else
                  _TrackStrip(
                    height: 210,
                    count: ranked.length,
                    itemBuilder: (context, index) {
                      final item = ranked[index];
                      final tracks = ranked.map((rank) => rank.track).toList();
                      return _TrackCard(
                        track: item.track,
                        subtitle: item.count == 1 ? '1 play' : '${item.count} plays',
                        onTap: () => playTracks(context, ref, tracks, index),
                      );
                    },
                  ),
                const SizedBox(height: 8),
              ],
              if (selectedYear != null) ...[
                const SectionLabel('Around this time'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final year in years)
                      ChoiceChip(
                        label: Text('$year'),
                        selected: year == selectedYear,
                        onSelected: (_) => setState(() => _year = year),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (remembered.isEmpty)
                  Text('Nothing from this week in $selectedYear.')
                else
                  _TrackStrip(
                    height: 210,
                    count: min(remembered.length, 18),
                    itemBuilder: (context, index) {
                      final tracks = remembered.take(18).toList();
                      return _TrackCard(
                        track: tracks[index],
                        subtitle: tracks[index].artist,
                        onTap: () => playTracks(context, ref, tracks, index),
                      );
                    },
                  ),
                const SizedBox(height: 8),
              ],
              if (fresh.isNotEmpty)
                _TrackRow(
                  title: 'Recently added',
                  tracks: fresh.take(16).toList(),
                  subtitleFor: (track) => '${track.artist} · ${_timeAgo(track.addedMs, now)}',
                ),
              if (albums.isNotEmpty)
                _ShelfRow(
                  title: 'Recent albums',
                  count: min(albums.length, 12),
                  itemBuilder: (context, index) {
                    final album = albums[index];
                    final art = album.artworkPath ?? library.index.folderArtFor(album.tracks.first.folderPath);
                    return _ShelfCard(
                      title: album.name,
                      subtitle: album.artist,
                      path: art,
                      onTap: () => context.push('/library/album/${album.key}'),
                    );
                  },
                ),
              if (artists.isNotEmpty)
                _ShelfRow(
                  title: 'Recent artists',
                  count: min(artists.length, 12),
                  itemBuilder: (context, index) {
                    final artist = artists[index];
                    final cover = _coverTrack(artist.tracks);
                    return _ShelfCard(
                      title: artist.name,
                      subtitle: _songCount(artist.tracks.length),
                      path: cover?.artworkPath,
                      url: cover?.thumbnailUrl,
                      round: true,
                      onTap: () => context.push('/library/artist/${artist.key}'),
                    );
                  },
                ),
              if (library.playlists.isNotEmpty)
                _ShelfRow(
                  title: 'Playlists',
                  count: min(library.playlists.length, 16),
                  itemBuilder: (context, index) {
                    final playlist = library.playlists[index];
                    return _ShelfCard(
                      title: playlist.name,
                      subtitle: _songCount(playlist.trackCount),
                      path: playlist.artworkPath,
                      onPlay: () => _playPlaylist(playlist),
                      onTap: () => context.push('/library/playlist/${playlist.id}'),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _playPlaylist(Playlist playlist) async {
    try {
      final tracks = await ref.read(databaseProvider).playlistTracks(playlist.id);
      if (!mounted) return;
      if (tracks.isEmpty) {
        showForgeMessage(context, 'This playlist is empty.');
        return;
      }
      await playTracks(context, ref, tracks, 0);
    } catch (_) {
      if (!mounted) return;
      showForgeMessage(context, 'That playlist would not play.');
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.library});

  final LibraryIndex library;

  @override
  Widget build(BuildContext context) {
    final songs = library.songs.length;
    final albums = library.albums.length;
    final artists = library.artists.length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greetingFor(DateTime.now()), style: Theme.of(context).textTheme.bodySmall),
              Text('Forgemusic', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 4),
              Text(
                '${_count(songs, 'song')} · ${_count(albums, 'album')} · ${_count(artists, 'artist')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Search',
          onPressed: () => context.go('/search'),
          icon: const Icon(Icons.search),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.tune),
        ),
      ],
    );
  }
}

class _NowPlaying extends ConsumerWidget {
  const _NowPlaying();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(playbackProvider).valueOrNull ?? ref.read(playerProvider).snapshot;
    final track = snapshot.track;
    if (track == null) return const SizedBox.shrink();
    final equalizerOn = ref.watch(settingsProvider.select((settings) => settings.equalizer));
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: NowPlayingCard(
        track: track,
        playing: snapshot.playing,
        position: snapshot.position,
        duration: snapshot.duration ?? track.duration,
        equalizerOn: equalizerOn,
        onOpen: () => context.push('/player'),
        onEqualizer: () => showEqualizerSheet(context),
        onToggle: () {
          final player = ref.read(playerProvider);
          if (snapshot.playing) {
            player.pause();
          } else {
            player.play();
          }
        },
      ),
    );
  }
}

/// The song that is loaded, kept readable above the rest of home.
class NowPlayingCard extends StatelessWidget {
  const NowPlayingCard({
    super.key,
    required this.track,
    required this.playing,
    required this.position,
    required this.duration,
    required this.onOpen,
    required this.onToggle,
    this.onEqualizer,
    this.equalizerOn = false,
  });

  final Track track;
  final bool playing;
  final Duration position;
  final Duration duration;
  final VoidCallback onOpen;
  final VoidCallback onToggle;
  final VoidCallback? onEqualizer;
  final bool equalizerOn;

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
    final progress = (position.inMilliseconds / total).clamp(0, 1).toDouble();
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: ForgeColors.card(context),
      elevation: 2,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 12),
          child: Column(
            children: [
              Row(
                children: [
                  ArtworkView(path: track.artworkPath, url: track.thumbnailUrl, size: 84, radius: 18),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playing ? 'Now playing' : 'Paused',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: onSurface,
                            fontSize: 18,
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
                  Column(
                    children: [
                      PlayToggleButton(playing: playing, size: 56, onPressed: onToggle),
                      if (onEqualizer != null)
                        IconButton(
                          tooltip: 'Equalizer',
                          visualDensity: VisualDensity.compact,
                          onPressed: onEqualizer,
                          icon: Icon(
                            Icons.graphic_eq,
                            color: equalizerOn ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  color: Theme.of(context).colorScheme.primary,
                  backgroundColor: ForgeColors.mist.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatDuration(position), style: Theme.of(context).textTheme.bodySmall),
                  Text(formatRemaining(duration, position), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mixes extends ConsumerWidget {
  const _Mixes({
    required this.songs,
    required this.played,
    required this.random,
    required this.fresh,
  });

  final List<Track> songs;
  final List<Track> played;
  final List<Track> random;
  final List<Track> fresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(playbackProvider.select((async) => async.valueOrNull?.track)) ??
        ref.read(playerProvider).snapshot.track;
    final mixes = <_Mix>[];
    if (current != null) {
      final related = _withArtist(current, songs);
      if (related.length > 1) mixes.add(_Mix('With ${current.artist}', related));
    }
    if (played.isNotEmpty) mixes.add(_Mix('Most played', played));
    if (random.isNotEmpty) mixes.add(_Mix('Random picks', random));
    if (fresh.isNotEmpty) mixes.add(_Mix('New on this phone', fresh));
    if (mixes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Mixes'),
        SizedBox(
          height: 260,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: mixes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final mix = mixes[index];
              return _MixCard(
                title: mix.title,
                tracks: mix.tracks,
                onTap: () => playTracks(context, ref, mix.tracks, 0),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Mix {
  const _Mix(this.title, this.tracks);

  final String title;
  final List<Track> tracks;
}

class _MixCard extends StatelessWidget {
  const _MixCard({required this.title, required this.tracks, required this.onTap});

  final String title;
  final List<Track> tracks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 176,
              height: 176,
              child: Stack(
                children: [
                  Positioned.fill(child: _Collage(tracks: tracks)),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 22,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15),
            ),
            Text(_songCount(tracks.length), maxLines: 1, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Collage extends StatelessWidget {
  const _Collage({required this.tracks});

  final List<Track> tracks;

  @override
  Widget build(BuildContext context) {
    final arts = tracks.take(4).toList();
    if (arts.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: arts.length == 1
          ? _cell(arts.first)
          : Column(
              children: [
                Expanded(child: Row(children: _pair(arts.take(2).toList()))),
                if (arts.length > 2) ...[
                  const SizedBox(height: 3),
                  Expanded(child: Row(children: _pair(arts.sublist(2)))),
                ],
              ],
            ),
    );
  }

  List<Widget> _pair(List<Track> row) {
    return [
      for (var i = 0; i < row.length; i++) ...[
        if (i > 0) const SizedBox(width: 3),
        Expanded(child: _cell(row[i])),
      ],
    ];
  }

  Widget _cell(Track track) {
    return ArtworkView(path: track.artworkPath, url: track.thumbnailUrl, expand: true, radius: 0);
  }
}

class _DayChips extends StatelessWidget {
  const _DayChips({required this.days, required this.onPick});

  final int days;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final choice in _windowDays)
          ChoiceChip(
            label: Text(choice == 1 ? '1 day' : '$choice days'),
            selected: choice == days,
            onSelected: (_) => onPick(choice),
          ),
      ],
    );
  }
}

class _TrackRow extends ConsumerWidget {
  const _TrackRow({required this.title, required this.tracks, required this.subtitleFor});

  final String title;
  final List<Track> tracks;
  final String Function(Track track) subtitleFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(title),
        _TrackStrip(
          height: 210,
          count: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            return _TrackCard(
              track: track,
              subtitle: subtitleFor(track),
              onTap: () => playTracks(context, ref, tracks, index),
            );
          },
        ),
      ],
    );
  }
}

class _TrackStrip extends StatelessWidget {
  const _TrackStrip({required this.height, required this.count, required this.itemBuilder});

  final double height;
  final int count;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: itemBuilder,
      ),
    );
  }
}

class _TrackCard extends ConsumerWidget {
  const _TrackCard({required this.track, required this.subtitle, required this.onTap});

  final Track track;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveId = ref.watch(playbackProvider.select((async) => async.valueOrNull?.track?.id));
    final livePlaying = ref.watch(playbackProvider.select((async) => async.valueOrNull?.playing));
    final fallback = ref.read(playerProvider).snapshot;
    final current = (liveId ?? fallback.track?.id) == track.id;
    final playing = livePlaying ?? fallback.playing;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: 132,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ArtworkView(path: track.artworkPath, url: track.thumbnailUrl, size: 132, radius: 18),
                if (current)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: PlayToggleButton(
                      playing: playing,
                      size: 42,
                      onPressed: () {
                        final player = ref.read(playerProvider);
                        if (playing) {
                          player.pause();
                        } else {
                          player.play();
                        }
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 14,
                color: current ? Theme.of(context).colorScheme.primary : onSurface,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfRow extends StatelessWidget {
  const _ShelfRow({required this.title, required this.count, required this.itemBuilder});

  final String title;
  final int count;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(title),
        SizedBox(
          height: 224,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: count,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}

class _ShelfCard extends StatelessWidget {
  const _ShelfCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.path,
    this.url,
    this.round = false,
    this.onPlay,
  });

  final String title;
  final String subtitle;
  final String? path;
  final String? url;
  final bool round;
  final VoidCallback onTap;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ArtworkView(path: path, url: url, size: 148, radius: round ? 74 : 22),
                if (onPlay != null)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Material(
                      color: Theme.of(context).colorScheme.primary,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: IconButton(
                        tooltip: 'Play',
                        visualDensity: VisualDensity.compact,
                        onPressed: onPlay,
                        icon: Icon(Icons.play_arrow_rounded, color: Theme.of(context).colorScheme.onPrimary),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

int _latest(List<Track> tracks) {
  var latest = 0;
  for (final track in tracks) {
    final stamp = track.lastPlayedMs ?? track.addedMs;
    if (stamp > latest) latest = stamp;
  }
  return latest;
}

Track? _coverTrack(List<Track> tracks) {
  for (final track in tracks) {
    final art = track.artworkPath;
    final thumb = track.thumbnailUrl;
    if ((art != null && art.isNotEmpty) || (thumb != null && thumb.isNotEmpty)) return track;
  }
  return tracks.isEmpty ? null : tracks.first;
}

List<Track> _withArtist(Track current, List<Track> songs) {
  final name = current.artist.trim().toLowerCase();
  if (name.isEmpty) return const [];
  final same = songs.where((track) {
    return track.id != current.id && track.artist.trim().toLowerCase() == name;
  }).take(23);
  return [current, ...same];
}

/// Same order for the whole calendar day, so the row stays put while a song plays.
List<Track> _dailyPicks(List<Track> songs, DateTime now, {int count = 12}) {
  final copy = [...songs];
  copy.shuffle(Random(now.year * 10000 + now.month * 100 + now.day));
  return copy.take(count).toList();
}

List<HistoryEntry> _uniqueHistory(List<HistoryEntry> history) {
  final seen = <String>{};
  final unique = <HistoryEntry>[];
  for (final entry in history) {
    if (seen.add(entry.track.id)) unique.add(entry);
  }
  return unique;
}

class _Rank {
  _Rank(this.track);

  final Track track;
  int count = 0;
}

List<_Rank> _topInWindow(List<HistoryEntry> history, DateTime now, int days) {
  final cutoff = now.subtract(Duration(days: days)).millisecondsSinceEpoch;
  final ranks = <String, _Rank>{};
  for (final entry in history) {
    if (entry.playedMs < cutoff) continue;
    ranks.putIfAbsent(entry.track.id, () => _Rank(entry.track)).count++;
  }
  final ranked = ranks.values.toList()..sort((a, b) => b.count.compareTo(a.count));
  return ranked.take(16).toList();
}

List<int> _memoryYears(List<HistoryEntry> history, int currentYear) {
  final years = <int>{};
  for (final entry in history) {
    final year = DateTime.fromMillisecondsSinceEpoch(entry.playedMs).year;
    if (year < currentYear) years.add(year);
  }
  final list = years.toList()..sort((a, b) => b.compareTo(a));
  return list;
}

List<Track> _memories(List<HistoryEntry> history, int year, DateTime now) {
  final seen = <String>{};
  final tracks = <Track>[];
  for (final entry in history) {
    final when = DateTime.fromMillisecondsSinceEpoch(entry.playedMs);
    if (when.year != year || when.month != now.month) continue;
    if ((when.day - now.day).abs() > 5) continue;
    if (seen.add(entry.track.id)) tracks.add(entry.track);
  }
  return tracks;
}

String _songCount(int count) => count == 1 ? '1 song' : '$count songs';

String _count(int count, String noun) => count == 1 ? '1 $noun' : '$count ${noun}s';

String _timeAgo(int millis, DateTime now) {
  final delta = now.difference(DateTime.fromMillisecondsSinceEpoch(millis));
  if (delta.inMinutes < 1) return 'Just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
  if (delta.inHours < 24) return '${delta.inHours}h ago';
  if (delta.inDays < 7) return '${delta.inDays}d ago';
  if (delta.inDays < 30) return '${delta.inDays ~/ 7}w ago';
  if (delta.inDays < 365) return '${delta.inDays ~/ 30}mo ago';
  final years = delta.inDays ~/ 365;
  return years <= 1 ? '1y ago' : '${years}y ago';
}
