import 'package:audiotags/audiotags.dart';

import '../../core/app_failure.dart';
import '../../core/utils/fingerprint.dart';
import '../db/app_database.dart';
import '../library_bus.dart';
import '../models/track.dart';

/// Writes tags back onto a local file and updates the shelf.
class TagEditor {
  TagEditor(this._db, this._bus);

  final AppDatabase _db;
  final LibraryBus _bus;

  Future<Track> save({
    required Track track,
    required String title,
    required String artist,
    required String album,
    required String albumArtist,
    required String genre,
    int? year,
    int? trackNumber,
    int? discNumber,
    String? lyrics,
  }) async {
    final path = track.filePath;
    if (track.source != TrackSource.local || path == null || path.isEmpty) {
      throw AppFailure('Only songs stored on this phone can be retagged.');
    }
    try {
      final existing = await AudioTags.read(path);
      await AudioTags.write(
        path,
        Tag(
          title: title.trim(),
          trackArtist: artist.trim(),
          album: album.trim(),
          albumArtist: albumArtist.trim(),
          genre: genre.trim(),
          year: year,
          trackNumber: trackNumber,
          discNumber: discNumber,
          lyrics: lyrics,
          pictures: existing?.pictures ?? const <Picture>[],
        ),
      );
    } catch (_) {
      throw AppFailure(
        'The file could not be changed. In settings, allow all-files access and try again.',
      );
    }
    final next = track.copyWith(
      title: title.trim(),
      artist: artist.trim(),
      album: album.trim(),
      albumArtist: albumArtist.trim(),
      genre: genre.trim(),
      year: year,
      trackNumber: trackNumber,
      discNumber: discNumber,
      lyrics: lyrics,
      clearLyrics: lyrics == null || lyrics.trim().isEmpty,
      fingerprint: trackFingerprint(
        title: title,
        artist: artist,
        durationMs: track.durationMs,
      ),
    );
    await _db.upsertTrack(next);
    _bus.ping();
    return next;
  }
}
