import '../db/app_database.dart';
import '../models/media.dart';
import '../models/track.dart';
import 'device_bridge.dart';
import 'youtube_service.dart';

/// Tells the listener when a followed artist has something new.
class ArtistAlerts {
  ArtistAlerts(this._db, this._youtube, this._device);

  final AppDatabase _db;
  final YoutubeService _youtube;
  final DeviceBridge _device;

  static const gap = Duration(hours: 6);

  Future<void> follow(String name) async {
    final found = await _youtube.newestUpload(name);
    await _db.upsertFollow(
      ArtistFollow(
        name: name,
        channelId: found.channelId,
        lastVideoId: found.videoId,
        lastCheckedMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> unfollow(String name) async {
    final rows = await _db.follows();
    for (final row in rows) {
      if (row.name.toLowerCase() == name.toLowerCase()) {
        await _db.deleteFollow(row.name);
      }
    }
  }

  Future<bool> isFollowing(String name) async {
    final rows = await _db.follows();
    return rows.any((row) => row.name.toLowerCase() == name.toLowerCase());
  }

  /// Looks for a new upload or a newly scanned local song. Quiet on failure.
  Future<void> check(List<Track> songs) async {
    final follows = await _db.follows();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final follow in follows) {
      final last = follow.lastCheckedMs ?? 0;
      if (now - last < gap.inMilliseconds) continue;
      String? body;
      var channelId = follow.channelId;
      var videoId = follow.lastVideoId;
      try {
        if (channelId == null || channelId.isEmpty) {
          final found = await _youtube.newestUpload(follow.name);
          channelId = found.channelId;
          videoId = found.videoId ?? videoId;
        } else {
          final newest = await _youtube.newestByChannel(channelId);
          if (newest.videoId != null &&
              follow.lastVideoId != null &&
              newest.videoId != follow.lastVideoId) {
            final title = newest.title;
            body = title == null || title.trim().isEmpty
                ? '${follow.name} posted something new.'
                : '${follow.name} posted $title';
          }
          videoId = newest.videoId ?? videoId;
        }
      } catch (_) {}
      if (body == null && follow.lastCheckedMs != null) {
        final fresh = songs.where((track) {
          return track.source == TrackSource.local &&
              track.artist.toLowerCase() == follow.name.toLowerCase() &&
              track.addedMs > follow.lastCheckedMs!;
        });
        final count = fresh.length;
        if (count > 0) {
          body = count == 1
              ? 'A new song from ${follow.name} is in your library.'
              : '$count new songs from ${follow.name} are in your library.';
        }
      }
      await _db.upsertFollow(
        ArtistFollow(
          name: follow.name,
          channelId: channelId,
          lastVideoId: videoId,
          lastCheckedMs: now,
        ),
      );
      if (body != null) {
        await _device.notify(title: follow.name, body: body);
      }
    }
  }
}
