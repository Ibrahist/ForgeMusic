import 'package:flutter_test/flutter_test.dart';
import 'package:forgemusic/data/models/track.dart';
import 'package:forgemusic/data/services/library_merge.dart';
import 'package:forgemusic/data/services/track_mapper.dart';
import 'package:on_audio_query/on_audio_query.dart';

void main() {
  test('a rescan keeps play counts and drops the extra copy', () {
    final stored = _song(
      id: 'local-1',
      title: 'Night Drive',
      playCount: 12,
      bitrate: 192,
      sizeBytes: 4,
    );
    final sameFile = _song(
      id: 'local-9',
      title: 'Night Drive',
      bitrate: 192,
      sizeBytes: 4,
    );
    final quieterCopy = _song(
      id: 'local-8',
      title: 'Night Drive',
      bitrate: 128,
      sizeBytes: 2,
    );

    final result = LibraryMerge.merge(
      existing: [stored],
      incoming: [sameFile, quieterCopy],
    );

    expect(result.tracks, hasLength(1));
    expect(result.tracks.single.id, 'local-1');
    expect(result.tracks.single.playCount, 12);
    expect(result.added, 0);
    expect(result.updated, 1);
    expect(result.skippedDuplicates, 1);
    expect(result.removed, 0);
  });

  test('a higher bitrate replaces the stored file and keeps the shelf id', () {
    final stored = _song(
      id: 'local-1',
      title: 'Night Drive',
      playCount: 4,
      bitrate: 128,
      sizeBytes: 2,
      artworkPath: '/art/cover.jpg',
    );
    final richer = _song(
      id: 'local-2',
      title: 'Night Drive',
      bitrate: 320,
      sizeBytes: 8,
      filePath: '/music/Night/rich.mp3',
    );

    final result = LibraryMerge.merge(
      existing: [stored],
      incoming: [stored, richer],
    );

    expect(result.tracks, hasLength(1));
    expect(result.skippedDuplicates, 1);
    expect(result.tracks.single.id, 'local-1');
    expect(result.tracks.single.playCount, 4);
    expect(result.tracks.single.bitrate, 320);
    expect(result.tracks.single.artworkPath, '/art/cover.jpg');
    expect(result.tracks.single.filePath, '/music/Night/rich.mp3');
  });

  test('media store rows become disc, track, and folder fields', () {
    final song = SongModel({
      '_id': 7,
      '_data': r'C:\Music\Night\glow.mp3',
      '_uri': 'content://media/external/audio/media/7',
      '_display_name': 'glow.mp3',
      '_display_name_wo_ext': 'glow',
      '_size': 800000,
      'album': 'Night',
      'artist': 'Ada',
      'album_artist': 'Ada Lane',
      'genre': 'Pop',
      'duration': 180000,
      'title': 'Glow',
      'track': 1002,
      'year': 2024,
    });

    final track = trackFromSong(song);

    expect(track.id, 'local-7');
    expect(track.discNumber, 1);
    expect(track.trackNumber, 2);
    expect(track.year, 2024);
    expect(track.albumArtist, 'Ada Lane');
    expect(track.path, 'content://media/external/audio/media/7');
    expect(track.folderPath, endsWith('Night'));
    expect(track.filename, 'glow.mp3');
  });
}

Track _song({
  required String id,
  required String title,
  int playCount = 0,
  int? bitrate,
  int sizeBytes = 1000,
  String? artworkPath,
  String? filePath,
}) {
  return Track(
    id: id,
    source: TrackSource.local,
    title: title,
    artist: 'Ada',
    album: 'Night',
    albumArtist: 'Ada',
    genre: 'Pop',
    durationMs: 180000,
    sizeBytes: sizeBytes,
    addedMs: 1,
    fingerprint: 'ada|nightdrive|90',
    playCount: playCount,
    bitrate: bitrate,
    artworkPath: artworkPath,
    filePath: filePath,
  );
}
