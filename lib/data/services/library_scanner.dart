import 'dart:async';
import 'dart:io';

import 'package:audiotags/audiotags.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../core/app_failure.dart';
import '../../core/utils/replay_gain_reader.dart';
import '../db/app_database.dart';
import '../library_bus.dart';
import '../models/app_settings.dart';
import '../models/track.dart';
import 'artwork_store.dart';
import 'library_merge.dart';
import 'track_mapper.dart';

/// Reads the phone's music library and folds duplicate copies together.
class LibraryScanner {
  LibraryScanner({
    required AppDatabase database,
    required LibraryBus bus,
    required ArtworkStore artwork,
    OnAudioQuery? query,
  }) : _db = database,
       _bus = bus,
       _artwork = artwork,
       _query = query ?? OnAudioQuery();

  final AppDatabase _db;
  final LibraryBus _bus;
  final ArtworkStore _artwork;
  final OnAudioQuery _query;

  Future<ScanResult> scan(AppSettings settings) async {
    final allowed = await _query.checkAndRequest(retryRequest: true);
    if (!allowed) {
      throw AppFailure(
        'Forgemusic needs access to your music before it can fill the shelves.',
      );
    }
    final songs = await _query.querySongs(uriType: UriType.EXTERNAL);
    final incoming = <Track>[];
    final minimumMs = settings.minDurationSec * 1000;
    for (final song in songs) {
      if (!settings.includeNonMusic && song.isMusic == false) continue;
      if ((song.duration ?? 0) < minimumMs) continue;
      if (song.data.trim().isEmpty) continue;
      incoming.add(trackFromSong(song));
    }
    final existing = await _db.localTracks();
    final result = LibraryMerge.merge(existing: existing, incoming: incoming);
    await _db.replaceLocalLibrary(result.tracks);
    _bus.ping();
    unawaited(_enrich(result.tracks));
    return result;
  }

  Future<void> _enrich(List<Track> tracks) async {
    var changed = false;
    final folders = await _db.folders();
    final seenFolders = <String>{};
    for (final track in tracks) {
      final path = track.filePath;
      if (path == null) continue;
      if (track.artworkPath == null) {
        final saved = await _artFromTags(track.id, path);
        if (saved != null) {
          await _db.updateArtwork(track.id, saved);
          changed = true;
        }
      }
      if (track.replayGainDb == null) {
        final gain = await ReplayGainReader.readFile(path);
        if (gain != null) {
          await _db.updateReplayGain(track.id, gain);
          changed = true;
        }
      }
      final folder = track.folderPath;
      if (folder != null && seenFolders.add(folder)) {
        if (folders[folder]?.artworkPath == null) {
          final discovered = await _artwork.discoverFolderArt(folder);
          if (discovered != null) {
            await _db.setFolder(path: folder, artworkPath: discovered);
            changed = true;
          }
        }
      }
    }
    if (changed) _bus.ping();
  }

  Future<String?> _artFromTags(String id, String path) async {
    if (!await File(path).exists()) return null;
    try {
      final tag = await AudioTags.read(path);
      final pictures = tag?.pictures ?? const [];
      if (pictures.isEmpty) return null;
      return _artwork.saveBytes(id, pictures.first.bytes);
    } catch (_) {
      return null;
    }
  }
}
