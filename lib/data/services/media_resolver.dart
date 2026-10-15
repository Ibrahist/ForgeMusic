import 'dart:io';

import 'package:just_audio/just_audio.dart';

import '../../core/app_failure.dart';
import '../../core/stream_agent.dart';
import '../db/app_database.dart';
import '../models/app_settings.dart';
import '../models/media.dart';
import '../models/track.dart';
import 'download_manager.dart';
import 'youtube_service.dart';

/// Something the player can open right now.
class ResolvedMedia {
  const ResolvedMedia({
    required this.uri,
    this.filePath,
    this.headers,
    this.cacheVideoId,
    this.cacheKind,
    this.cacheStream,
  });

  final Uri uri;
  final String? filePath;
  final Map<String, String>? headers;
  final String? cacheVideoId;
  final String? cacheKind;
  final ChosenStream? cacheStream;

  AudioSource get source {
    final path = filePath;
    if (path != null) return AudioSource.file(path);
    final stream = cacheStream;
    if (stream != null && stream.hls) {
      return HlsAudioSource(uri, headers: headers);
    }
    return ProgressiveAudioSource(uri, headers: headers);
  }
}

/// Picks a local file, a saved download, the cache, or a fresh stream.
class MediaResolver {
  MediaResolver(this._db, this._youtube, this._downloads);

  final AppDatabase _db;
  final YoutubeService _youtube;
  final DownloadManager _downloads;

  Future<ResolvedMedia> resolveAudio(Track track, AppSettings settings) async {
    if (track.source == TrackSource.local) {
      final location = track.path;
      if (location != null && location.startsWith('content:')) {
        return ResolvedMedia(uri: Uri.parse(location));
      }
      final file = track.filePath ?? location;
      if (file == null || file.isEmpty) {
        throw AppFailure('This song has no file to play.');
      }
      return ResolvedMedia(uri: Uri.file(file), filePath: file);
    }
    final videoId = track.youtubeId;
    if (videoId == null || videoId.isEmpty) {
      throw AppFailure('This YouTube song is missing its id.');
    }
    final download = await _db.downloadFor(videoId, audioOnly: true);
    if (download != null && await File(download.filePath).exists()) {
      return ResolvedMedia(uri: Uri.file(download.filePath), filePath: download.filePath);
    }
    final kind = settings.dataSaver ? 'audio-saver' : 'audio';
    final cached = await _db.cacheEntry(videoId, kind);
    final cachedFile = cached?.filePath;
    if (cachedFile != null && await File(cachedFile).exists()) {
      await _db.touchCache(videoId, kind);
      return ResolvedMedia(uri: Uri.file(cachedFile), filePath: cachedFile);
    }
    if (cached != null && cached.urlFresh && cached.streamUrl != null) {
      await _db.touchCache(videoId, kind);
      return ResolvedMedia(
        uri: Uri.parse(cached.streamUrl!),
        headers: streamHeaders,
        cacheVideoId: videoId,
        cacheKind: kind,
      );
    }
    final chosen = await _youtube.chooseAudio(videoId, dataSaver: settings.dataSaver);
    await _downloads.rememberUrl(
      videoId: videoId,
      kind: kind,
      url: chosen.url.toString(),
      filePath: cachedFile,
      bytes: cached?.bytes ?? 0,
    );
    return ResolvedMedia(
      uri: chosen.url,
      headers: streamHeaders,
      cacheVideoId: settings.cacheYoutube ? videoId : null,
      cacheKind: kind,
      cacheStream: settings.cacheYoutube ? chosen : null,
    );
  }

  Future<ResolvedMedia> resolveVideo({
    required String videoId,
    required bool dataSaver,
  }) async {
    final saved = await _db.downloadFor(videoId, audioOnly: false);
    if (saved != null && await File(saved.filePath).exists()) {
      return ResolvedMedia(uri: Uri.file(saved.filePath), filePath: saved.filePath);
    }
    final chosen = await _youtube.chooseVideo(videoId, dataSaver: dataSaver);
    return ResolvedMedia(
      uri: chosen.url,
      headers: streamHeaders,
      cacheStream: chosen,
    );
  }

  Future<void> invalidate(String videoId, String kind) async {
    final entry = await _db.cacheEntry(videoId, kind);
    if (entry == null) return;
    await _db.saveCache(
      CacheEntry(
        videoId: videoId,
        kind: kind,
        filePath: entry.filePath,
        expiresMs: 0,
        bytes: entry.bytes,
        lastAccessMs: entry.lastAccessMs,
      ),
    );
  }
}
