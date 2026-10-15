import '../../core/utils/fingerprint.dart';
import '../models/media.dart';
import '../models/track.dart';

/// A queue entry for a YouTube video.
Track trackFromHit(YoutubeHit hit, {bool downloaded = false, String? downloadPath}) {
  return Track(
    id: 'yt-${hit.videoId}',
    source: TrackSource.youtube,
    title: hit.title,
    artist: hit.author,
    album: 'YouTube',
    albumArtist: hit.author,
    genre: 'YouTube',
    durationMs: hit.durationMs,
    sizeBytes: 0,
    addedMs: DateTime.now().millisecondsSinceEpoch,
    fingerprint: trackFingerprint(
      title: hit.title,
      artist: hit.author,
      durationMs: hit.durationMs,
    ),
    youtubeId: hit.videoId,
    thumbnailUrl: hit.thumbnailUrl,
    downloaded: downloaded,
    downloadPath: downloadPath,
  );
}
