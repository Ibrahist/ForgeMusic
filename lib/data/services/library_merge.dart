import '../../core/utils/duplicates.dart';
import '../models/track.dart';

/// What a library scan did with the songs it saw.
class ScanResult {
  const ScanResult({
    required this.tracks,
    required this.added,
    required this.updated,
    required this.skippedDuplicates,
    required this.removed,
  });

  final List<Track> tracks;
  final int added;
  final int updated;
  final int skippedDuplicates;
  final int removed;

  int get total => tracks.length;

  String get summary {
    if (total == 0) {
      return 'No songs turned up. Try lowering the minimum length in settings.';
    }
    final bits = <String>['$total songs on the shelf'];
    if (added > 0) bits.add('$added new');
    if (skippedDuplicates > 0) {
      bits.add('$skippedDuplicates duplicates left out');
    }
    return '${bits.join(', ')}.';
  }
}

/// Collapses copies of the same song and keeps listening data on the survivor.
class LibraryMerge {
  static ScanResult merge({
    required List<Track> existing,
    required List<Track> incoming,
  }) {
    final storedByFingerprint = <String, Track>{};
    for (final track in existing) {
      storedByFingerprint.putIfAbsent(track.fingerprint, () => track);
    }
    final winners = <String, Track>{};
    var added = 0;
    var updated = 0;
    var skipped = 0;

    for (final candidate in incoming) {
      final current = winners[candidate.fingerprint];
      if (current == null) {
        final stored = storedByFingerprint[candidate.fingerprint];
        if (stored == null) {
          winners[candidate.fingerprint] = candidate;
          added++;
        } else {
          winners[candidate.fingerprint] = blend(stored, candidate);
          updated++;
        }
        continue;
      }
      skipped++;
      final better = DuplicateKeeper.preferCandidate(
        candidateSize: candidate.sizeBytes,
        existingSize: current.sizeBytes,
        candidateBitrate: candidate.bitrate,
        existingBitrate: current.bitrate,
      );
      if (!better) continue;
      final stored = storedByFingerprint[candidate.fingerprint];
      winners[candidate.fingerprint] = stored == null
          ? candidate
          : blend(stored, candidate);
    }

    final keep = winners.values.map((track) => track.id).toSet();
    final removed = existing.where((track) => !keep.contains(track.id)).length;
    return ScanResult(
      tracks: winners.values.toList(),
      added: added,
      updated: updated,
      skippedDuplicates: skipped,
      removed: removed,
    );
  }

  /// Keeps the shelf identity and the person's notes, and takes the new file.
  static Track blend(Track stored, Track incoming) {
    return Track(
      id: stored.id,
      source: TrackSource.local,
      title: incoming.title,
      artist: incoming.artist,
      album: incoming.album,
      albumArtist: incoming.albumArtist,
      genre: incoming.genre,
      year: incoming.year,
      trackNumber: incoming.trackNumber,
      discNumber: incoming.discNumber,
      durationMs: incoming.durationMs,
      sizeBytes: incoming.sizeBytes,
      addedMs: stored.addedMs,
      fingerprint: incoming.fingerprint,
      path: incoming.path,
      filePath: incoming.filePath,
      filename: incoming.filename,
      folderPath: incoming.folderPath,
      bitrate: incoming.bitrate,
      artworkPath: stored.artworkPath,
      lyrics: stored.lyrics,
      syncedLyrics: stored.syncedLyrics,
      replayGainDb: stored.replayGainDb,
      playCount: stored.playCount,
      lastPlayedMs: stored.lastPlayedMs,
      downloaded: stored.downloaded,
      downloadPath: stored.downloadPath,
      mediaStoreId: incoming.mediaStoreId,
    );
  }
}
