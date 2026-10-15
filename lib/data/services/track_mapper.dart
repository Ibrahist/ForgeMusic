import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/fingerprint.dart';
import '../models/track.dart';

/// Turns a media-store row into a shelf track.
Track trackFromSong(SongModel song) {
  final map = song.getMap;
  final filePath = song.data;
  final title = cleanMeta(
    song.title,
    fallback: cleanMeta(song.displayNameWOExt, fallback: 'Untitled'),
  );
  final artist = cleanMeta(song.artist, fallback: 'Unknown artist');
  final album = cleanMeta(song.album, fallback: 'Unknown album');
  final albumArtist = cleanMeta(
    map['album_artist']?.toString(),
    fallback: artist,
  );
  final genre = cleanMeta(song.genre, fallback: 'Unknown');
  final durationMs = song.duration ?? 0;
  final rawTrack = song.track ?? 0;
  final disc = rawTrack <= 0 ? null : rawTrack ~/ 1000;
  final number = rawTrack <= 0 ? null : rawTrack % 1000;
  final year = _year(map['year']);
  final size = song.size;
  return Track(
    id: 'local-${song.id}',
    source: TrackSource.local,
    title: title,
    artist: artist,
    album: album,
    albumArtist: albumArtist,
    genre: genre,
    year: year,
    trackNumber: number == 0 ? null : number,
    discNumber: disc == 0 ? null : disc,
    durationMs: durationMs,
    sizeBytes: size,
    addedMs: DateTime.now().millisecondsSinceEpoch,
    fingerprint: trackFingerprint(
      title: title,
      artist: artist,
      durationMs: durationMs,
    ),
    path: (song.uri != null && song.uri!.isNotEmpty) ? song.uri : filePath,
    filePath: filePath,
    filename: song.displayName,
    folderPath: p.dirname(filePath),
    bitrate: _bitrate(size, durationMs),
    mediaStoreId: song.id,
  );
}

int? _year(Object? value) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}

int? _bitrate(int sizeBytes, int durationMs) {
  if (sizeBytes <= 0 || durationMs <= 0) return null;
  return (sizeBytes * 8 / (durationMs / 1000)).round();
}
