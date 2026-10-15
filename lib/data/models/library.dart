import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/utils/fingerprint.dart';
import 'track.dart';

/// A stable, URL-safe key for an album, artist, genre, or folder.
String libraryKey(String raw) =>
    sha1.convert(utf8.encode(raw)).toString().substring(0, 16);

class AlbumGroup {
  const AlbumGroup({
    required this.name,
    required this.artist,
    required this.key,
    required this.tracks,
  });

  final String name;
  final String artist;
  final String key;
  final List<Track> tracks;

  int get durationMs => tracks.fold(0, (sum, track) => sum + track.durationMs);

  String? get artworkPath =>
      tracks.cast<Track?>().firstWhere(
        (track) => track!.artworkPath != null,
        orElse: () => null,
      )?.artworkPath;
}

class ArtistGroup {
  const ArtistGroup({
    required this.name,
    required this.key,
    required this.tracks,
  });

  final String name;
  final String key;
  final List<Track> tracks;

  List<AlbumGroup> get albums => groupAlbums(tracks);
}

class GenreGroup {
  const GenreGroup({
    required this.name,
    required this.key,
    required this.tracks,
  });

  final String name;
  final String key;
  final List<Track> tracks;
}

class FolderGroup {
  const FolderGroup({
    required this.path,
    required this.name,
    required this.key,
    required this.tracks,
    this.artworkPath,
    this.excluded = false,
  });

  final String path;
  final String name;
  final String key;
  final List<Track> tracks;
  final String? artworkPath;
  final bool excluded;
}

class FolderMeta {
  const FolderMeta({
    required this.path,
    this.artworkPath,
    this.excluded = false,
  });

  final String path;
  final String? artworkPath;
  final bool excluded;
}

class LibraryIndex {
  const LibraryIndex({
    required this.songs,
    required this.albums,
    required this.artists,
    required this.genres,
    required this.folders,
  });

  final List<Track> songs;
  final List<AlbumGroup> albums;
  final List<ArtistGroup> artists;
  final List<GenreGroup> genres;
  final List<FolderGroup> folders;

  static const empty = LibraryIndex(
    songs: [],
    albums: [],
    artists: [],
    genres: [],
    folders: [],
  );

  factory LibraryIndex.fromTracks(
    List<Track> tracks, {
    Map<String, FolderMeta> folders = const {},
  }) {
    final visible = tracks.where((track) {
      final folder = track.folderPath;
      if (folder == null) return true;
      return folders[folder]?.excluded != true;
    }).toList();
    final songs = [...visible]..sort((a, b) => _label(a.title).compareTo(_label(b.title)));
    return LibraryIndex(
      songs: songs,
      albums: groupAlbums(visible),
      artists: _groupArtists(visible),
      genres: _groupGenres(visible),
      folders: _groupFolders(tracks, folders),
    );
  }

  AlbumGroup? albumByKey(String key) {
    for (final album in albums) {
      if (album.key == key) return album;
    }
    return null;
  }

  ArtistGroup? artistByKey(String key) {
    for (final artist in artists) {
      if (artist.key == key) return artist;
    }
    return null;
  }

  GenreGroup? genreByKey(String key) {
    for (final genre in genres) {
      if (genre.key == key) return genre;
    }
    return null;
  }

  FolderGroup? folderByKey(String key) {
    for (final folder in folders) {
      if (folder.key == key) return folder;
    }
    return null;
  }

  String? folderArtFor(String? path) {
    if (path == null) return null;
    for (final folder in folders) {
      if (folder.path == path) return folder.artworkPath;
    }
    return null;
  }
}

List<AlbumGroup> groupAlbums(List<Track> tracks) {
  final grouped = <String, List<Track>>{};
  for (final track in tracks.where((item) => item.source == TrackSource.local)) {
    final artist = track.albumArtist.trim().isEmpty ? track.artist : track.albumArtist;
    final raw = '$artist\u0001${track.album}';
    grouped.putIfAbsent(raw, () => []).add(track);
  }
  final albums = grouped.entries.map((entry) {
    final parts = entry.key.split('\u0001');
    final sorted = [...entry.value]..sort(_compareAlbumOrder);
    return AlbumGroup(
      name: parts[1],
      artist: parts[0],
      key: libraryKey(entry.key),
      tracks: sorted,
    );
  }).toList();
  albums.sort((a, b) => _label(a.name).compareTo(_label(b.name)));
  return albums;
}

List<ArtistGroup> _groupArtists(List<Track> tracks) {
  final grouped = <String, List<Track>>{};
  for (final track in tracks.where((item) => item.source == TrackSource.local)) {
    grouped.putIfAbsent(track.artist, () => []).add(track);
  }
  final artists = grouped.entries.map((entry) {
    return ArtistGroup(
      name: entry.key,
      key: libraryKey(entry.key),
      tracks: [...entry.value]..sort((a, b) => _label(a.title).compareTo(_label(b.title))),
    );
  }).toList();
  artists.sort((a, b) => _label(a.name).compareTo(_label(b.name)));
  return artists;
}

List<GenreGroup> _groupGenres(List<Track> tracks) {
  final grouped = <String, List<Track>>{};
  for (final track in tracks.where((item) => item.source == TrackSource.local)) {
    grouped.putIfAbsent(track.genre, () => []).add(track);
  }
  final genres = grouped.entries.map((entry) {
    return GenreGroup(
      name: entry.key,
      key: libraryKey(entry.key),
      tracks: entry.value,
    );
  }).toList();
  genres.sort((a, b) => _label(a.name).compareTo(_label(b.name)));
  return genres;
}

List<FolderGroup> _groupFolders(
  List<Track> tracks,
  Map<String, FolderMeta> meta,
) {
  final grouped = <String, List<Track>>{};
  for (final track in tracks.where((item) => item.source == TrackSource.local)) {
    final path = track.folderPath;
    if (path == null || path.isEmpty) continue;
    grouped.putIfAbsent(path, () => []).add(track);
  }
  final folders = grouped.entries.map((entry) {
    final info = meta[entry.key];
    final name = entry.key.split(RegExp(r'[\\/]')).where((part) => part.isNotEmpty).last;
    return FolderGroup(
      path: entry.key,
      name: name,
      key: libraryKey(entry.key),
      tracks: entry.value,
      artworkPath: info?.artworkPath,
      excluded: info?.excluded ?? false,
    );
  }).toList();
  folders.sort((a, b) => _label(a.name).compareTo(_label(b.name)));
  return folders;
}

int _compareAlbumOrder(Track a, Track b) {
  final disc = (a.discNumber ?? 0).compareTo(b.discNumber ?? 0);
  if (disc != 0) return disc;
  final track = (a.trackNumber ?? 9999).compareTo(b.trackNumber ?? 9999);
  if (track != 0) return track;
  return _label(a.title).compareTo(_label(b.title));
}

String _label(String value) => normalizeName(value).isEmpty ? value.toLowerCase() : normalizeName(value);

bool matchesQuery(Track track, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return false;
  bool has(String? value) => (value ?? '').toLowerCase().contains(needle);
  return has(track.title) ||
      has(track.artist) ||
      has(track.album) ||
      has(track.albumArtist) ||
      has(track.filename) ||
      has(track.lyrics) ||
      has(track.genre);
}
