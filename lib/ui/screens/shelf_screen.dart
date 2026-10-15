import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/library.dart';
import '../../data/models/track.dart';
import '../../state/providers.dart';
import '../playback.dart';
import '../widgets/forge_widgets.dart';

enum ShelfKind { album, artist, genre, folder, playlist }

class ShelfScreen extends ConsumerWidget {
  const ShelfScreen({super.key, required this.kind, required this.id});

  final ShelfKind kind;
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    if (kind == ShelfKind.playlist) return _PlaylistShelf(id: id);
    final group = _group(library.index);
    final tracks = group?.tracks ?? const <Track>[];
    final title = group?.title ?? 'Shelf';
    final subtitle = group?.subtitle;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (kind == ShelfKind.folder && group?.folder != null)
            IconButton(
              tooltip: 'Folder art',
              onPressed: () => _pickArt(context, ref, group!.folder!),
              icon: const Icon(Icons.image_outlined),
            ),
          if (kind == ShelfKind.folder && group?.folder != null)
            IconButton(
              tooltip: group!.folder!.excluded ? 'Show folder' : 'Hide folder',
              onPressed: () => _toggleFolder(ref, group.folder!),
              icon: Icon(group.folder!.excluded ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            ),
        ],
      ),
      body: tracks.isEmpty
          ? const Center(child: Text('This shelf is empty.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (subtitle != null) Text(subtitle),
                Text('${tracks.length} songs · ${formatDuration(Duration(milliseconds: tracks.fold(0, (sum, track) => sum + track.durationMs)))}'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => playTracks(context, ref, tracks, 0),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play'),
                ),
                for (var i = 0; i < tracks.length; i++)
                  SongTile(
                    track: tracks[i],
                    artPath: library.index.folderArtFor(tracks[i].folderPath),
                    onTap: () => playTracks(context, ref, tracks, i),
                    onMore: () => showTrackMenu(context, ref, tracks[i]),
                  ),
              ],
            ),
    );
  }

  _Group? _group(LibraryIndex index) {
    return switch (kind) {
      ShelfKind.album => () {
        final album = index.albumByKey(id);
        if (album == null) return null;
        return _Group(album.name, album.artist, album.tracks);
      }(),
      ShelfKind.artist => () {
        final artist = index.artistByKey(id);
        if (artist == null) return null;
        return _Group(artist.name, '${artist.albums.length} albums', artist.tracks);
      }(),
      ShelfKind.genre => () {
        final genre = index.genreByKey(id);
        if (genre == null) return null;
        return _Group(genre.name, null, genre.tracks);
      }(),
      ShelfKind.folder => () {
        final folder = index.folderByKey(id);
        if (folder == null) return null;
        return _Group(folder.name, folder.excluded ? 'Hidden' : folder.path, folder.tracks, folder: folder);
      }(),
      ShelfKind.playlist => null,
    };
  }

  Future<void> _toggleFolder(WidgetRef ref, FolderGroup folder) async {
    await ref.read(databaseProvider).setFolder(path: folder.path, excluded: !folder.excluded);
    ref.read(libraryBusProvider).ping();
  }

  Future<void> _pickArt(BuildContext context, WidgetRef ref, FolderGroup folder) async {
    final picked = await FilePicker.pickFile(type: FileType.image);
    final source = picked?.path;
    if (source == null) return;
    final saved = await ref.read(artworkProvider).copyFile('folder-${folder.key}', source);
    if (saved == null) return;
    await ref.read(databaseProvider).setFolder(path: folder.path, artworkPath: saved);
    ref.read(libraryBusProvider).ping();
    if (context.mounted) showForgeMessage(context, 'Folder art updated.');
  }
}

class _Group {
  const _Group(this.title, this.subtitle, this.tracks, {this.folder});

  final String title;
  final String? subtitle;
  final List<Track> tracks;
  final FolderGroup? folder;
}

class _PlaylistShelf extends ConsumerStatefulWidget {
  const _PlaylistShelf({required this.id});

  final String id;

  @override
  ConsumerState<_PlaylistShelf> createState() => _PlaylistShelfState();
}

class _PlaylistShelfState extends ConsumerState<_PlaylistShelf> {
  List<Track> _tracks = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tracks = await ref.read(databaseProvider).playlistTracks(widget.id);
    if (!mounted) return;
    setState(() {
      _tracks = tracks;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final playlist = ref.watch(libraryProvider).playlists.where((item) => item.id == widget.id).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(playlist?.name ?? 'Playlist'),
        actions: [
          IconButton(onPressed: _rename, icon: const Icon(Icons.edit_outlined)),
          IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: FilledButton.icon(
                    onPressed: _tracks.isEmpty ? null : () => playTracks(context, ref, _tracks, 0),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play'),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: _tracks.length,
                    onReorder: (from, to) async {
                      var target = to;
                      if (target > from) target -= 1;
                      final next = [..._tracks];
                      final item = next.removeAt(from);
                      next.insert(target, item);
                      setState(() => _tracks = next);
                      await ref.read(databaseProvider).reorderPlaylist(widget.id, next.map((track) => track.id).toList());
                      ref.read(libraryBusProvider).ping();
                    },
                    itemBuilder: (context, index) {
                      final track = _tracks[index];
                      return ListTile(
                        key: ValueKey(track.id),
                        title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                        leading: ArtworkView(path: track.artworkPath, url: track.thumbnailUrl, radius: 12),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () async {
                            await ref.read(databaseProvider).removeFromPlaylist(widget.id, track.id);
                            ref.read(libraryBusProvider).ping();
                            await _load();
                          },
                        ),
                        onTap: () => playTracks(context, ref, _tracks, index),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _rename() async {
    final current = ref.read(libraryProvider).playlists.where((item) => item.id == widget.id).firstOrNull;
    final name = TextEditingController(text: current?.name ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Rename playlist'),
        content: TextField(controller: name, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Save')),
        ],
      ),
    );
    final trimmed = name.text.trim();
    name.dispose();
    if (ok != true || trimmed.isEmpty) return;
    await ref.read(databaseProvider).renamePlaylist(widget.id, trimmed);
    ref.read(libraryBusProvider).ping();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete this playlist?'),
        content: const Text('The songs stay in your library.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(databaseProvider).deletePlaylist(widget.id);
    ref.read(libraryBusProvider).ping();
    if (mounted) Navigator.of(context).pop();
  }
}
