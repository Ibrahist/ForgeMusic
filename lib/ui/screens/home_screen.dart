import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/library.dart';
import '../../data/models/track.dart';
import '../../state/providers.dart';
import '../playback.dart';
import '../theme/forge_theme.dart';
import '../widgets/forge_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final snapshot = ref.watch(playbackProvider).valueOrNull;
    final songs = library.index.songs.where((track) => track.source == TrackSource.local).toList();
    final continueTrack = snapshot?.track ?? (library.history.isEmpty ? null : library.history.first.track);
    final albums = [...library.index.albums]..sort((a, b) => _recent(b).compareTo(_recent(a)));
    final played = [...songs.where((track) => track.playCount > 0)]
      ..sort((a, b) => b.playCount.compareTo(a.playCount));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(greetingFor(DateTime.now())),
                      Text('Forgemusic', style: Theme.of(context).textTheme.displaySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
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
            const SizedBox(height: 18),
            if (songs.isEmpty)
              EmptyShelves(
                onScan: () => ref.read(libraryProvider.notifier).scan(),
                onYouTube: () => context.go('/youtube'),
              )
            else ...[
              if (continueTrack != null) ...[
                const SectionLabel('Continue'),
                _ContinueCard(
                  track: continueTrack,
                  onTap: () => playTracks(context, ref, [continueTrack], 0),
                ),
                const SizedBox(height: 22),
              ],
              if (albums.isNotEmpty) ...[
                const SectionLabel('Albums'),
                SizedBox(
                  height: 214,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: math.min(albums.length, 12),
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final album = albums[index];
                      return _AlbumCard(
                        album: album,
                        art: library.index.folderArtFor(album.tracks.first.folderPath),
                        onTap: () => context.push('/library/album/${album.key}'),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (played.isNotEmpty) ...[
                const SectionLabel('Most played'),
                for (final track in played.take(8))
                  SongTile(
                    track: track,
                    artPath: library.index.folderArtFor(track.folderPath),
                    subtitle: '${track.artist} · ${track.playCount} plays',
                    onTap: () => playTracks(context, ref, played, played.indexOf(track)),
                    onMore: () => showTrackMenu(context, ref, track),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

int _recent(AlbumGroup album) {
  var latest = 0;
  for (final track in album.tracks) {
    final stamp = track.lastPlayedMs ?? track.addedMs;
    if (stamp > latest) latest = stamp;
  }
  return latest;
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.track, required this.onTap});

  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ForgeColors.card(context),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ArtworkView(path: track.artworkPath, url: track.thumbnailUrl, size: 72, radius: 18),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.play_arrow_rounded, size: 34),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album, required this.onTap, this.art});

  final AlbumGroup album;
  final String? art;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = album.artworkPath ?? art;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        width: 148,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ArtworkView(path: cover, size: 148, radius: 22),
            const SizedBox(height: 8),
            Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(album.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
