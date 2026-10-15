import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_failure.dart';
import '../data/models/track.dart';
import '../state/providers.dart';
import 'widgets/forge_widgets.dart';

Future<void> playTracks(BuildContext context, WidgetRef ref, List<Track> tracks, int index) async {
  if (tracks.isEmpty) return;
  try {
    await ref.read(playerProvider).playTracks(tracks, index: index);
  } catch (error) {
    if (!context.mounted) return;
    showForgeMessage(context, error is AppFailure ? error.message : 'That song would not play.');
  }
}

Future<void> showTrackMenu(BuildContext context, WidgetRef ref, Track track) async {
  final library = ref.read(libraryProvider);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_play),
              title: const Text('Play next'),
              onTap: () async {
                Navigator.pop(sheet);
                await ref.read(playerProvider).playNext(track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: const Text('Add to queue'),
              onTap: () async {
                Navigator.pop(sheet);
                await ref.read(playerProvider).enqueue([track]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Add to playlist'),
              onTap: () async {
                Navigator.pop(sheet);
                if (!context.mounted) return;
                await _pickPlaylist(context, ref, track);
              },
            ),
            if (track.source == TrackSource.local)
              ListTile(
                leading: const Icon(Icons.sell_outlined),
                title: const Text('Edit tags'),
                onTap: () {
                  Navigator.pop(sheet);
                  context.push('/tags/${track.id}');
                },
              ),
            ListTile(
              leading: const Icon(Icons.lyrics_outlined),
              title: const Text('Fetch lyrics'),
              onTap: () async {
                Navigator.pop(sheet);
                await _fetchLyrics(context, ref, track);
              },
            ),
            if (library.playlists.isEmpty) const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

Future<void> _pickPlaylist(BuildContext context, WidgetRef ref, Track track) async {
  final name = TextEditingController();
  final playlists = ref.read(libraryProvider).playlists;
  final chosen = await showDialog<String>(
    context: context,
    builder: (dialog) {
      return AlertDialog(
        title: const Text('Add to a playlist'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final playlist in playlists)
                ListTile(
                  title: Text(playlist.name),
                  subtitle: Text('${playlist.trackCount} songs'),
                  onTap: () => Navigator.pop(dialog, playlist.id),
                ),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'New playlist'),
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Close')),
          FilledButton(
            onPressed: () async {
              final trimmed = name.text.trim();
              if (trimmed.isEmpty) return;
              final created = await ref.read(databaseProvider).createPlaylist(trimmed);
              ref.read(libraryBusProvider).ping();
              if (dialog.mounted) Navigator.pop(dialog, created.id);
            },
            child: const Text('Create'),
          ),
        ],
      );
    },
  );
  name.dispose();
  if (chosen == null) return;
  await ref.read(databaseProvider).addToPlaylist(chosen, track.id);
  ref.read(libraryBusProvider).ping();
  if (context.mounted) showForgeMessage(context, 'Saved to the playlist.');
}

Future<void> fetchLyrics(BuildContext context, WidgetRef ref, Track track) =>
    _fetchLyrics(context, ref, track);

Future<void> _fetchLyrics(BuildContext context, WidgetRef ref, Track track) async {
  try {
    final client = ref.read(lyricsProvider);
    var found = await client.fetch(
      title: track.title,
      artist: track.artist,
      album: track.album,
      durationMs: track.durationMs,
    );
    if ((found == null || !found.hasWords) && track.youtubeId != null) {
      found = await ref.read(youtubeProvider).captions(track.youtubeId!);
    }
    if (found == null || (!found.hasWords && !found.instrumental)) {
      throw AppFailure('No lyrics turned up for this one.');
    }
    final plain = found.instrumental ? 'Instrumental' : found.plain;
    await ref.read(databaseProvider).upsertTrack(track);
    await ref.read(databaseProvider).updateLyrics(track.id, plain: plain, synced: found.synced);
    ref.read(libraryBusProvider).ping();
    await ref.read(playerProvider).replaceTrack(
      track.copyWith(
        lyrics: plain,
        syncedLyrics: found.synced,
        clearLyrics: plain == null,
        clearSynced: found.synced == null,
      ),
    );
    if (context.mounted) {
      showForgeMessage(
        context,
        found.instrumental ? 'This one is instrumental.' : 'Lyrics are ready.',
      );
    }
  } catch (error) {
    if (!context.mounted) return;
    showForgeMessage(context, error is AppFailure ? error.message : 'Lyrics could not be fetched.');
  }
}
