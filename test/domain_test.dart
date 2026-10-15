import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:forgemusic/core/utils/cache_policy.dart';
import 'package:forgemusic/core/utils/crossfade.dart';
import 'package:forgemusic/core/utils/duplicates.dart';
import 'package:forgemusic/core/utils/fingerprint.dart';
import 'package:forgemusic/core/utils/formatters.dart';
import 'package:forgemusic/core/utils/lrc.dart';
import 'package:forgemusic/core/utils/replay_gain.dart';
import 'package:forgemusic/core/utils/replay_gain_reader.dart';
import 'package:forgemusic/core/utils/stream_choice.dart';
import 'package:forgemusic/data/models/library.dart';
import 'package:forgemusic/data/models/track.dart';

void main() {
  test('fingerprints ignore remaster tags and tiny duration gaps', () {
    final a = trackFingerprint(
      title: 'Midnight (Remastered)',
      artist: 'Ada feat. Nova',
      durationMs: 180000,
    );
    final b = trackFingerprint(
      title: 'Midnight',
      artist: 'Ada',
      durationMs: 180400,
    );
    expect(a, b);
    expect(normalizeName('Hello, World!'), 'helloworld');
    expect(cleanMeta('<unknown>', fallback: 'Unknown artist'), 'Unknown artist');
  });

  test('keeps the larger copy when bitrate is unknown', () {
    expect(
      DuplicateKeeper.preferCandidate(
        candidateSize: 9,
        existingSize: 4,
      ),
      isTrue,
    );
    expect(
      DuplicateKeeper.preferCandidate(
        candidateSize: 9,
        existingSize: 4,
        candidateBitrate: 128,
        existingBitrate: 320,
      ),
      isFalse,
    );
  });

  test('parses synced lyrics and follows the playhead', () {
    const lrc = '[00:01.20] First line\n[00:05] Second\n[01:02.005] Third';
    final lines = LrcParser.parse(lrc);
    expect(lines, hasLength(3));
    expect(lines[0].time, const Duration(seconds: 1, milliseconds: 200));
    expect(lines[2].text, 'Third');
    expect(LrcParser.indexAt(lines, Duration.zero), -1);
    expect(LrcParser.indexAt(lines, const Duration(seconds: 5)), 1);
    expect(LrcParser.indexAt(lines, const Duration(seconds: 70)), 2);
  });

  test('replay gain lowers loud tracks and boosts quiet ones', () {
    final loud = GainPlan.resolve(
      replayGainDb: -6,
      enabled: true,
      fallbackDb: 4,
    );
    expect(loud.volume, lessThan(1));
    expect(loud.enhancerDb, 0);

    final quiet = GainPlan.resolve(
      replayGainDb: 3,
      enabled: true,
      fallbackDb: 4,
    );
    expect(quiet.volume, 1);
    expect(quiet.enhancerDb, 3);

    final fallback = GainPlan.resolve(
      replayGainDb: null,
      enabled: true,
      fallbackDb: 4,
    );
    expect(fallback.enhancerDb, 4);

    final off = GainPlan.resolve(
      replayGainDb: -6,
      enabled: false,
      fallbackDb: 4,
    );
    expect(off.volume, 1);
  });

  test('reads replay gain from plain and utf-16 tag bytes', () {
    final plain = Uint8List.fromList(
      'REPLAYGAIN_TRACK_GAIN=-6.54 dB'.codeUnits,
    );
    expect(ReplayGainReader.decode(plain), -6.54);

    final encoded = _utf16('REPLAYGAIN_TRACK_GAIN=-3.25 dB');
    expect(ReplayGainReader.decode(encoded), -3.25);
  });

  test('equal-power crossfade keeps a steady level', () {
    expect(CrossfadeCurve.incoming(0), 0);
    expect(CrossfadeCurve.outgoing(0), closeTo(1, 0.001));
    expect(CrossfadeCurve.incoming(1), closeTo(1, 0.001));
    final energy = _square(CrossfadeCurve.incoming(0.35)) +
        _square(CrossfadeCurve.outgoing(0.35));
    expect(energy, closeTo(1, 0.001));
    expect(
      CrossfadeWindow.shouldStart(
        enabled: true,
        crossfadeMs: 5000,
        alreadyFading: false,
        repeatOne: false,
        position: const Duration(seconds: 56),
        duration: const Duration(seconds: 60),
        hasNext: true,
      ),
      isTrue,
    );
    expect(
      CrossfadeWindow.shouldStart(
        enabled: true,
        crossfadeMs: 5000,
        alreadyFading: false,
        repeatOne: true,
        position: const Duration(seconds: 56),
        duration: const Duration(seconds: 60),
        hasNext: true,
      ),
      isFalse,
    );
  });

  test('data saver prefers a smaller stream', () {
    final audio = [
      const RatedStream(value: 'low', bitsPerSecond: 48000),
      const RatedStream(value: 'mid', bitsPerSecond: 64000),
      const RatedStream(value: 'high', bitsPerSecond: 160000),
    ];
    expect(pickPreferred(audio, dataSaver: false), 'high');
    expect(pickPreferred(audio, dataSaver: true, maxBits: 64000), 'mid');

    final video = [
      const RatedStream(value: '144', bitsPerSecond: 100000, qualityRank: 1),
      const RatedStream(value: '720', bitsPerSecond: 2000000, qualityRank: 5),
    ];
    expect(pickPreferred(video, dataSaver: true), '144');
    expect(pickPreferred(video, dataSaver: false), '720');
  });

  test('cache eviction drops the oldest files first', () {
    final drop = CachePolicy.evict(
      items: const [
        CacheItem(id: 'old', bytes: 400, lastAccessMs: 1),
        CacheItem(id: 'new', bytes: 400, lastAccessMs: 9),
      ],
      incomingBytes: 300,
      limitBytes: 700,
    );
    expect(drop, ['old']);
  });

  test('library grouping skips duplicates of identity and sorts albums', () {
    final tracks = [
      _track(id: '1', title: 'B', artist: 'Ada', album: 'Night', number: 2),
      _track(id: '2', title: 'A', artist: 'Ada', album: 'Night', number: 1),
      _track(id: '3', title: 'C', artist: 'Bea', album: 'Day', genre: 'Jazz'),
    ];
    final index = LibraryIndex.fromTracks(tracks);
    expect(index.albums, hasLength(2));
    expect(
      index.albums.singleWhere((album) => album.name == 'Night').tracks.map((track) => track.title),
      ['A', 'B'],
    );
    expect(index.artists.map((artist) => artist.name), ['Ada', 'Bea']);
    expect(index.genres.map((genre) => genre.name), ['Jazz', 'Pop']);
    expect(matchesQuery(tracks.first, 'night'), isTrue);
    expect(matchesQuery(tracks.first, 'lyric line'), isTrue);
    expect(matchesQuery(tracks.first, ''), isFalse);
  });

  test('hidden folders stay out of songs but remain in the folder list', () {
    final tracks = [
      _track(id: '1', title: 'A', folder: r'C:\Music\Keep'),
      _track(id: '2', title: 'B', folder: r'C:\Music\Hide'),
    ];
    final index = LibraryIndex.fromTracks(
      tracks,
      folders: {
        r'C:\Music\Hide': const FolderMeta(path: r'C:\Music\Hide', excluded: true),
      },
    );
    expect(index.songs.map((track) => track.title), ['A']);
    expect(index.folders, hasLength(2));
    expect(index.folders.singleWhere((folder) => folder.name == 'Hide').excluded, isTrue);
  });

  test('clock and greeting stay friendly', () {
    expect(formatDuration(const Duration(minutes: 3, seconds: 5)), '3:05');
    expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    expect(formatRemaining(const Duration(seconds: 90), const Duration(seconds: 30)), '-1:00');
    expect(greetingFor(DateTime(2026, 1, 1, 9)), 'Good morning');
    expect(greetingFor(DateTime(2026, 1, 1, 23)), 'Late session');
  });
}

double _square(double value) => value * value;

Uint8List _utf16(String text) {
  final bytes = <int>[];
  for (final code in text.codeUnits) {
    bytes.add(code & 0xff);
    bytes.add((code >> 8) & 0xff);
  }
  return Uint8List.fromList(bytes);
}

Track _track({
  required String id,
  required String title,
  String artist = 'Ada',
  String album = 'Night',
  String genre = 'Pop',
  int number = 1,
  String? folder,
}) {
  return Track(
    id: id,
    source: TrackSource.local,
    title: title,
    artist: artist,
    album: album,
    albumArtist: artist,
    genre: genre,
    durationMs: 180000,
    sizeBytes: 1000,
    addedMs: 1,
    fingerprint: id,
    trackNumber: number,
    filename: '$title.mp3',
    folderPath: folder,
    lyrics: 'A lyric line lives here',
  );
}
