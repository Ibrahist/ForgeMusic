import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_failure.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/library.dart';
import '../../data/models/media.dart';
import '../../data/models/playlist.dart';
import '../../data/models/track.dart';
import '../../state/providers.dart';
import '../playback.dart';
import '../widgets/forge_widgets.dart';

enum _Shelf { songs, albums, artists, genres, playlists, folders, videos, history }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  _Shelf _shelf = _Shelf.songs;
  List<LocalVideo> _videos = const [];
  String? _videoNote;
  bool _loadingVideos = false;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final index = library.index;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Library', style: Theme.of(context).textTheme.displaySmall)),
                  IconButton(
                    tooltip: 'Scan',
                    onPressed: library.scanning ? null : () => ref.read(libraryProvider.notifier).scan(),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            if (library.message != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(library.message!),
              ),
            if (library.scanning)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final shelf in _Shelf.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_label(shelf)),
                        selected: _shelf == shelf,
                        onSelected: (_) => _select(shelf),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _body(index, library)),
          ],
        ),
      ),
    );
  }

  String _label(_Shelf shelf) {
    return switch (shelf) {
      _Shelf.songs => 'Songs',
      _Shelf.albums => 'Albums',
      _Shelf.artists => 'Artists',
      _Shelf.genres => 'Genres',
      _Shelf.playlists => 'Playlists',
      _Shelf.folders => 'Folders',
      _Shelf.videos => 'Videos',
      _Shelf.history => 'History',
    };
  }

  Future<void> _select(_Shelf shelf) async {
    setState(() => _shelf = shelf);
    if (shelf == _Shelf.videos && _videos.isEmpty && !_loadingVideos) {
      await _loadVideos();
    }
  }

  Future<void> _loadVideos() async {
    setState(() {
      _loadingVideos = true;
      _videoNote = null;
    });
    final videos = await Permission.videos.request();
    if (!videos.isGranted) await Permission.storage.request();
    try {
      final found = await ref.read(deviceProvider).videos();
      if (!mounted) return;
      setState(() {
        _videos = found;
        _loadingVideos = false;
        _videoNote = found.isEmpty ? 'No videos showed up on this phone.' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingVideos = false;
        _videoNote = error is AppFailure ? error.message : 'Videos are not available yet.';
      });
    }
  }

  Widget _body(LibraryIndex index, LibraryState library) {
    final songs = index.songs.where((track) => track.source == TrackSource.local).toList();
    return switch (_shelf) {
      _Shelf.songs => _songs(songs),
      _Shelf.albums => _albums(index.albums),
      _Shelf.artists => _simple(
        index.artists,
        (item) => item.name,
        (item) => '${item.tracks.length} songs',
        (item) => context.push('/library/artist/${item.key}'),
      ),
      _Shelf.genres => _simple(
        index.genres,
        (item) => item.name,
        (item) => '${item.tracks.length} songs',
        (item) => context.push('/library/genre/${item.key}'),
      ),
      _Shelf.playlists => _playlists(library.playlists),
      _Shelf.folders => _folders(index.folders),
      _Shelf.videos => _videoList(),
      _Shelf.history => _history(library.history),
    };
  }

  Widget _songs(List<Track> songs) {
    if (songs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          EmptyShelves(
            onScan: () => ref.read(libraryProvider.notifier).scan(),
            onYouTube: () => context.go('/youtube'),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: songs.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.push('/queue'),
              icon: const Icon(Icons.queue_music),
              label: const Text('Open the queue'),
            ),
          );
        }
        final track = songs[index - 1];
        return SongTile(
          track: track,
          artPath: ref.read(libraryProvider).index.folderArtFor(track.folderPath),
          onTap: () => playTracks(context, ref, songs, index - 1),
          onMore: () => showTrackMenu(context, ref, track),
        );
      },
    );
  }

  Widget _albums(List<AlbumGroup> albums) {
    if (albums.isEmpty) return const _Quiet(text: 'Albums will gather here after a scan.');
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.78,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return InkWell(
          onTap: () => context.push('/library/album/${album.key}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: ArtworkView(path: album.artworkPath, expand: true, radius: 20)),
              const SizedBox(height: 8),
              Text(album.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(album.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    );
  }

  Widget _simple(List items, String Function(dynamic) title, String Function(dynamic) subtitle, void Function(dynamic) onTap) {
    if (items.isEmpty) return const _Quiet(text: 'Nothing in this shelf yet.');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          title: Text(title(item)),
          subtitle: Text(subtitle(item)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onTap(item),
        );
      },
    );
  }

  Widget _playlists(List<Playlist> playlists) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('New playlist'),
          onTap: _createPlaylist,
        ),
        for (final playlist in playlists)
          ListTile(
            leading: ArtworkView(path: playlist.artworkPath, radius: 14),
            title: Text(playlist.name),
            subtitle: Text('${playlist.trackCount} songs'),
            onTap: () => context.push('/library/playlist/${playlist.id}'),
          ),
      ],
    );
  }

  Future<void> _createPlaylist() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Name the playlist'),
        content: TextField(controller: name, autofocus: true, decoration: const InputDecoration(hintText: 'Late night')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Create')),
        ],
      ),
    );
    final trimmed = name.text.trim();
    name.dispose();
    if (ok != true || trimmed.isEmpty) return;
    await ref.read(databaseProvider).createPlaylist(trimmed);
    ref.read(libraryBusProvider).ping();
  }

  Widget _folders(List<FolderGroup> folders) {
    if (folders.isEmpty) return const _Quiet(text: 'Folders appear once songs have a home.');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        return ListTile(
          leading: ArtworkView(path: folder.artworkPath, radius: 14),
          title: Text(folder.name),
          subtitle: Text(folder.excluded ? 'Hidden from the shelves' : '${folder.tracks.length} songs'),
          onTap: () => context.push('/library/folder/${folder.key}'),
        );
      },
    );
  }

  Widget _videoList() {
    if (_loadingVideos) return const Center(child: CircularProgressIndicator());
    if (_videoNote != null) return _Quiet(text: _videoNote!);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        return ListTile(
          leading: const Icon(Icons.movie_outlined),
          title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${formatDuration(Duration(milliseconds: video.durationMs))} · ${formatBytes(video.sizeBytes)}'),
          onTap: () {
            ref.read(videoLaunchProvider.notifier).open(VideoLaunch.local(video));
            context.push('/video');
          },
        );
      },
    );
  }

  Widget _history(List<HistoryEntry> history) {
    if (history.isEmpty) return const _Quiet(text: 'Songs you spend time with will be remembered here.');
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () async {
              await ref.read(databaseProvider).clearHistory();
              ref.read(libraryBusProvider).ping();
            },
            child: const Text('Clear history'),
          ),
        ),
        for (final entry in history)
          SongTile(
            track: entry.track,
            subtitle: '${entry.track.artist} · ${formatDuration(entry.track.duration)}',
            onTap: () => playTracks(context, ref, [entry.track], 0),
            onMore: () => showTrackMenu(context, ref, entry.track),
          ),
      ],
    );
  }
}

class _Quiet extends StatelessWidget {
  const _Quiet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const DiscMark(size: 72),
        const SizedBox(height: 16),
        Text(text),
      ],
    );
  }
}
