import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/app_failure.dart';
import '../../core/utils/cache_policy.dart';
import '../db/app_database.dart';
import '../models/app_settings.dart';
import '../models/media.dart';
import 'youtube_service.dart';

/// How far a save has gotten, from 0 to 1.
class TransferProgress {
  const TransferProgress({required this.label, required this.fraction});

  final String label;
  final double? fraction;
}

/// Saves YouTube audio and video for offline listening, and trims the cache.
class DownloadManager {
  DownloadManager(this._db, this._youtube);

  final AppDatabase _db;
  final YoutubeService _youtube;
  final _progress = StreamController<TransferProgress?>.broadcast();

  Stream<TransferProgress?> get progress => _progress.stream;

  Future<DownloadRecord> download(
    YoutubeHit hit, {
    required bool audioOnly,
    required AudioQuality audioQuality,
    required bool dataSaver,
  }) async {
    _progress.add(TransferProgress(label: 'Saving ${hit.title}', fraction: null));
    try {
      final chosen = audioOnly
          ? await _youtube.chooseAudio(hit.videoId, quality: audioQuality)
          : await _youtube.chooseVideo(hit.videoId, dataSaver: dataSaver);
      final dir = await _folder('downloads');
      final file = File(p.join(dir.path, '${hit.videoId}-${audioOnly ? 'audio' : 'video'}.${chosen.extension}'));
      final bytes = await _write(chosen, file, hit.title);
      final record = DownloadRecord(
        id: '${hit.videoId}-${audioOnly ? 'audio' : 'video'}',
        videoId: hit.videoId,
        title: hit.title,
        author: hit.author,
        audioOnly: audioOnly,
        filePath: file.path,
        bytes: bytes,
        createdMs: DateTime.now().millisecondsSinceEpoch,
        durationMs: hit.durationMs,
        thumbnailUrl: hit.thumbnailUrl,
      );
      await _db.upsertDownload(record);
      _progress.add(null);
      return record;
    } catch (error) {
      _progress.add(null);
      if (error is AppFailure) rethrow;
      throw AppFailure('That download stopped before it finished.');
    }
  }

  Future<void> cacheStream({
    required String videoId,
    required ChosenStream chosen,
    required String kind,
    required int limitBytes,
  }) async {
    final existing = await _db.cacheEntry(videoId, kind);
    if (existing?.filePath != null && await File(existing!.filePath!).exists()) {
      await _db.touchCache(videoId, kind);
      return;
    }
    await _evict(limitBytes: limitBytes, incoming: chosen.bytes, keepId: '$videoId|$kind');
    final dir = await _folder('yt-cache');
    final file = File(p.join(dir.path, '$videoId-$kind.${chosen.extension}'));
    try {
      final bytes = await _write(chosen, file, null);
      await _db.saveCache(
        CacheEntry(
          videoId: videoId,
          kind: kind,
          filePath: file.path,
          streamUrl: existing?.streamUrl,
          expiresMs: existing?.expiresMs,
          bytes: bytes,
          lastAccessMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (_) {
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> rememberUrl({
    required String videoId,
    required String kind,
    required String url,
    String? filePath,
    int bytes = 0,
  }) {
    return _db.saveCache(
      CacheEntry(
        videoId: videoId,
        kind: kind,
        filePath: filePath,
        streamUrl: url,
        expiresMs: DateTime.now().add(const Duration(hours: 4)).millisecondsSinceEpoch,
        bytes: bytes,
        lastAccessMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> clearCache() async {
    final entries = await _db.cacheEntries();
    for (final entry in entries) {
      final path = entry.filePath;
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    }
    await _db.clearCacheRows();
  }

  Future<void> deleteDownload(DownloadRecord record) async {
    final file = File(record.filePath);
    if (await file.exists()) await file.delete();
    await _db.deleteDownload(record.id);
  }

  Future<void> _evict({
    required int limitBytes,
    required int incoming,
    required String keepId,
  }) async {
    final entries = await _db.cacheEntries();
    final items = [
      for (final entry in entries)
        if (entry.filePath != null && entry.id != keepId)
          CacheItem(id: entry.id, bytes: entry.bytes, lastAccessMs: entry.lastAccessMs),
    ];
    final drop = CachePolicy.evict(items: items, incomingBytes: incoming, limitBytes: limitBytes);
    for (final id in drop) {
      final parts = id.split('|');
      if (parts.length != 2) continue;
      final entry = await _db.cacheEntry(parts[0], parts[1]);
      final path = entry?.filePath;
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
      if (entry != null) {
        await _db.saveCache(
          CacheEntry(
            videoId: entry.videoId,
            kind: entry.kind,
            streamUrl: entry.streamUrl,
            expiresMs: entry.expiresMs,
            bytes: 0,
            lastAccessMs: entry.lastAccessMs,
          ),
        );
      }
    }
  }

  Future<int> _write(ChosenStream chosen, File dest, String? label) async {
    final sink = dest.openWrite();
    var written = 0;
    try {
      await for (final chunk in _youtube.bytes(chosen.info)) {
        sink.add(chunk);
        written += chunk.length;
        if (label != null) {
          final total = chosen.bytes;
          _progress.add(
            TransferProgress(
              label: 'Saving $label',
              fraction: total <= 0 ? null : (written / total).clamp(0, 1),
            ),
          );
        }
      }
      await sink.flush();
      await sink.close();
      return written;
    } catch (_) {
      await sink.close();
      if (await dest.exists()) await dest.delete();
      rethrow;
    }
  }

  Future<Directory> _folder(String name) async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, name));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
