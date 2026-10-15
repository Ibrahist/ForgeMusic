import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/app_failure.dart';

/// Words returned for a song, plain or timed.
class LyricsResult {
  const LyricsResult({
    this.plain,
    this.synced,
    this.instrumental = false,
  });

  final String? plain;
  final String? synced;
  final bool instrumental;

  bool get hasWords =>
      (synced != null && synced!.trim().isNotEmpty) ||
      (plain != null && plain!.trim().isNotEmpty && plain != 'Instrumental');
}

/// Asks LRCLIB for lyrics. The caller can fall back to captions.
class LyricsClient {
  LyricsClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _agent = 'Forgemusic/1.0';

  Future<LyricsResult?> fetch({
    required String title,
    required String artist,
    String? album,
    int? durationMs,
  }) async {
    final seconds = durationMs == null ? null : (durationMs / 1000).round();
    final withAlbum = await _get(
      title: title,
      artist: artist,
      album: album,
      durationSec: seconds,
    );
    if (withAlbum != null) return withAlbum;
    final plain = await _get(title: title, artist: artist, durationSec: seconds);
    if (plain != null) return plain;
    return _search(title: title, artist: artist, durationSec: seconds);
  }

  Future<LyricsResult?> _get({
    required String title,
    required String artist,
    String? album,
    int? durationSec,
  }) async {
    final query = <String, String>{
      'track_name': title,
      'artist_name': artist,
      if (album != null && album.trim().isNotEmpty) 'album_name': album.trim(),
      if (durationSec != null) 'duration': '$durationSec',
    };
    return _read(Uri.https('lrclib.net', '/api/get', query), allowMissing: true);
  }

  Future<LyricsResult?> _search({
    required String title,
    required String artist,
    int? durationSec,
  }) async {
    final uri = Uri.https('lrclib.net', '/api/search', {
      'q': '$artist $title',
    });
    final response = await _send(uri);
    if (response == null || response.statusCode == 404) return null;
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty) return null;
    Map<String, dynamic>? best;
    var bestGap = 1 << 30;
    for (final item in decoded) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      final duration = (map['duration'] as num?)?.toInt();
      final gap = durationSec == null || duration == null
          ? 8
          : (duration - durationSec).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = map;
      }
    }
    if (best == null) return null;
    return _fromMap(best);
  }

  Future<LyricsResult?> _read(Uri uri, {required bool allowMissing}) async {
    final response = await _send(uri);
    if (response == null) return null;
    if (response.statusCode == 404 && allowMissing) return null;
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    return _fromMap(decoded.cast<String, dynamic>());
  }

  Future<http.Response?> _send(Uri uri) async {
    try {
      return await _client
          .get(uri, headers: {'User-Agent': _agent})
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      return null;
    }
  }

  LyricsResult _fromMap(Map<String, dynamic> map) {
    if (map['instrumental'] == true) {
      return const LyricsResult(plain: 'Instrumental', instrumental: true);
    }
    final plain = (map['plainLyrics'] as String?)?.trim();
    final synced = (map['syncedLyrics'] as String?)?.trim();
    return LyricsResult(
      plain: plain == null || plain.isEmpty ? null : plain,
      synced: synced == null || synced.isEmpty ? null : synced,
    );
  }

  Future<LyricsResult> require({
    required String title,
    required String artist,
    String? album,
    int? durationMs,
  }) async {
    final found = await fetch(
      title: title,
      artist: artist,
      album: album,
      durationMs: durationMs,
    );
    if (found == null || (!found.hasWords && !found.instrumental)) {
      throw AppFailure('No lyrics turned up for this one.');
    }
    return found;
  }
}
