import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/library.dart';
import '../models/media.dart';
import '../models/playlist.dart';
import '../models/track.dart';

class AppDatabase {
  AppDatabase(this._db);

  final Database _db;

  static Future<AppDatabase> open() async {
    final dir = await getDatabasesPath();
    final database = await openDatabase(
      p.join(dir, 'forgemusic.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tracks (
            id TEXT PRIMARY KEY,
            source TEXT NOT NULL,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            album TEXT NOT NULL,
            album_artist TEXT NOT NULL,
            genre TEXT NOT NULL,
            year INTEGER,
            track_number INTEGER,
            disc_number INTEGER,
            duration_ms INTEGER NOT NULL,
            path TEXT,
            file_path TEXT,
            filename TEXT,
            folder_path TEXT,
            size_bytes INTEGER NOT NULL DEFAULT 0,
            bitrate INTEGER,
            youtube_id TEXT,
            thumbnail_url TEXT,
            artwork_path TEXT,
            lyrics TEXT,
            synced_lyrics TEXT,
            replay_gain REAL,
            play_count INTEGER NOT NULL DEFAULT 0,
            last_played_ms INTEGER,
            added_ms INTEGER NOT NULL,
            downloaded INTEGER NOT NULL DEFAULT 0,
            download_path TEXT,
            fingerprint TEXT,
            media_store_id INTEGER
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_tracks_fingerprint ON tracks(fingerprint)',
        );
        await db.execute(
          'CREATE INDEX idx_tracks_youtube ON tracks(youtube_id)',
        );
        await db.execute('''
          CREATE TABLE playlists (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_ms INTEGER NOT NULL,
            updated_ms INTEGER NOT NULL,
            artwork_path TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE playlist_tracks (
            playlist_id TEXT NOT NULL,
            track_id TEXT NOT NULL,
            position INTEGER NOT NULL,
            PRIMARY KEY (playlist_id, track_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            track_id TEXT NOT NULL,
            played_ms INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE folders (
            path TEXT PRIMARY KEY,
            artwork_path TEXT,
            excluded INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE queue_state (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            track_ids TEXT NOT NULL,
            current_index INTEGER NOT NULL,
            position_ms INTEGER NOT NULL,
            repeat_mode TEXT NOT NULL,
            shuffle INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE yt_cache (
            video_id TEXT NOT NULL,
            kind TEXT NOT NULL,
            file_path TEXT,
            stream_url TEXT,
            expires_ms INTEGER,
            bytes INTEGER NOT NULL DEFAULT 0,
            last_access_ms INTEGER NOT NULL,
            PRIMARY KEY (video_id, kind)
          )
        ''');
        await db.execute('''
          CREATE TABLE downloads (
            id TEXT PRIMARY KEY,
            video_id TEXT NOT NULL,
            title TEXT NOT NULL,
            author TEXT NOT NULL,
            audio_only INTEGER NOT NULL,
            file_path TEXT NOT NULL,
            bytes INTEGER NOT NULL,
            created_ms INTEGER NOT NULL,
            thumbnail_url TEXT,
            duration_ms INTEGER NOT NULL
          )
        ''');
      },
    );
    return AppDatabase(database);
  }

  Future<List<Track>> allTracks() async {
    final rows = await _db.query('tracks', orderBy: 'title COLLATE NOCASE');
    return rows.map(Track.fromMap).toList();
  }

  Future<List<Track>> localTracks() async {
    final rows = await _db.query(
      'tracks',
      where: 'source = ?',
      whereArgs: [TrackSource.local.name],
    );
    return rows.map(Track.fromMap).toList();
  }

  Future<Track?> trackById(String id) async {
    final rows = await _db.query('tracks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Track.fromMap(rows.first);
  }

  Future<Track?> trackByYoutubeId(String videoId) async {
    final rows = await _db.query(
      'tracks',
      where: 'youtube_id = ?',
      whereArgs: [videoId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Track.fromMap(rows.first);
  }

  Future<void> upsertTrack(Track track) {
    return _db.insert(
      'tracks',
      track.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> replaceLocalLibrary(List<Track> tracks) async {
    final batch = _db.batch();
    final keep = tracks.map((track) => track.id).toSet();
    for (final track in tracks) {
      batch.insert(
        'tracks',
        track.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    final existing = await localTracks();
    for (final track in existing) {
      if (!keep.contains(track.id)) {
        await _db.delete('tracks', where: 'id = ?', whereArgs: [track.id]);
        await _db.delete('playlist_tracks', where: 'track_id = ?', whereArgs: [track.id]);
      }
    }
  }

  Future<void> updateArtwork(String id, String path) {
    return _db.update('tracks', {'artwork_path': path}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateReplayGain(String id, double gain) {
    return _db.update('tracks', {'replay_gain': gain}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateLyrics(String id, {String? plain, String? synced}) {
    return _db.update(
      'tracks',
      {'lyrics': plain, 'synced_lyrics': synced},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> addHistory(String trackId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.rawUpdate(
      'UPDATE tracks SET play_count = play_count + 1, last_played_ms = ? WHERE id = ?',
      [now, trackId],
    );
    await _db.insert('history', {'track_id': trackId, 'played_ms': now});
  }

  Future<List<HistoryEntry>> recentHistory({int limit = 200}) async {
    final rows = await _db.rawQuery('''
      SELECT h.played_ms, t.*
      FROM history h
      JOIN tracks t ON t.id = h.track_id
      ORDER BY h.played_ms DESC
      LIMIT ?
    ''', [limit]);
    return rows.map((row) {
      return HistoryEntry(
        track: Track.fromMap(row),
        playedMs: (row['played_ms'] as num).toInt(),
      );
    }).toList();
  }

  Future<void> clearHistory() => _db.delete('history');

  Future<List<Playlist>> playlists() async {
    final rows = await _db.rawQuery('''
      SELECT p.*, COUNT(pt.track_id) AS track_count
      FROM playlists p
      LEFT JOIN playlist_tracks pt ON pt.playlist_id = p.id
      GROUP BY p.id
      ORDER BY p.updated_ms DESC
    ''');
    return rows.map(Playlist.fromMap).toList();
  }

  Future<Playlist> createPlaylist(String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final playlist = Playlist(
      id: 'pl-$now',
      name: name.trim(),
      createdMs: now,
      updatedMs: now,
    );
    await _db.insert('playlists', {
      'id': playlist.id,
      'name': playlist.name,
      'created_ms': playlist.createdMs,
      'updated_ms': playlist.updatedMs,
    });
    return playlist;
  }

  Future<void> renamePlaylist(String id, String name) {
    return _db.update(
      'playlists',
      {'name': name.trim(), 'updated_ms': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletePlaylist(String id) async {
    await _db.delete('playlist_tracks', where: 'playlist_id = ?', whereArgs: [id]);
    await _db.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Track>> playlistTracks(String id) async {
    final rows = await _db.rawQuery('''
      SELECT t.*
      FROM playlist_tracks pt
      JOIN tracks t ON t.id = pt.track_id
      WHERE pt.playlist_id = ?
      ORDER BY pt.position
    ''', [id]);
    return rows.map(Track.fromMap).toList();
  }

  Future<void> addToPlaylist(String playlistId, String trackId) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(MAX(position), -1) AS next FROM playlist_tracks WHERE playlist_id = ?',
      [playlistId],
    );
    final next = ((rows.first['next'] as num?)?.toInt() ?? -1) + 1;
    await _db.insert('playlist_tracks', {
      'playlist_id': playlistId,
      'track_id': trackId,
      'position': next,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await _touchPlaylist(playlistId);
  }

  Future<void> removeFromPlaylist(String playlistId, String trackId) async {
    await _db.delete(
      'playlist_tracks',
      where: 'playlist_id = ? AND track_id = ?',
      whereArgs: [playlistId, trackId],
    );
    await _touchPlaylist(playlistId);
  }

  Future<void> reorderPlaylist(String playlistId, List<String> trackIds) async {
    await _db.transaction((txn) async {
      await txn.delete('playlist_tracks', where: 'playlist_id = ?', whereArgs: [playlistId]);
      for (var i = 0; i < trackIds.length; i++) {
        await txn.insert('playlist_tracks', {
          'playlist_id': playlistId,
          'track_id': trackIds[i],
          'position': i,
        });
      }
    });
    await _touchPlaylist(playlistId);
  }

  Future<void> _touchPlaylist(String id) {
    return _db.update(
      'playlists',
      {'updated_ms': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, FolderMeta>> folders() async {
    final rows = await _db.query('folders');
    return {
      for (final row in rows)
        row['path']! as String: FolderMeta(
          path: row['path']! as String,
          artworkPath: row['artwork_path'] as String?,
          excluded: row['excluded'] == 1,
        ),
    };
  }

  Future<void> setFolder({
    required String path,
    String? artworkPath,
    bool? excluded,
    bool keepArtwork = true,
    bool keepExcluded = true,
  }) async {
    final current = await folders();
    final previous = current[path];
    await _db.insert('folders', {
      'path': path,
      'artwork_path': artworkPath ?? (keepArtwork ? previous?.artworkPath : null),
      'excluded': (excluded ?? (keepExcluded ? (previous?.excluded ?? false) : false)) ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveQueue(QueueSnapshot snapshot) {
    return _db.insert('queue_state', {
      'id': 1,
      'track_ids': jsonEncode(snapshot.ids),
      'current_index': snapshot.index,
      'position_ms': snapshot.positionMs,
      'repeat_mode': snapshot.repeat,
      'shuffle': snapshot.shuffle ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<QueueSnapshot?> loadQueue() async {
    final rows = await _db.query('queue_state', where: 'id = 1');
    if (rows.isEmpty) return null;
    final row = rows.first;
    final ids = (jsonDecode(row['track_ids']! as String) as List)
        .map((id) => '$id')
        .toList();
    return QueueSnapshot(
      ids: ids,
      index: (row['current_index'] as num).toInt(),
      positionMs: (row['position_ms'] as num).toInt(),
      repeat: row['repeat_mode']! as String,
      shuffle: row['shuffle'] == 1,
    );
  }

  Future<void> saveCache(CacheEntry entry) {
    return _db.insert(
      'yt_cache',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<CacheEntry?> cacheEntry(String videoId, String kind) async {
    final rows = await _db.query(
      'yt_cache',
      where: 'video_id = ? AND kind = ?',
      whereArgs: [videoId, kind],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CacheEntry.fromMap(rows.first);
  }

  Future<List<CacheEntry>> cacheEntries() async {
    final rows = await _db.query('yt_cache');
    return rows.map(CacheEntry.fromMap).toList();
  }

  Future<void> deleteCache(String videoId, String kind) {
    return _db.delete(
      'yt_cache',
      where: 'video_id = ? AND kind = ?',
      whereArgs: [videoId, kind],
    );
  }

  Future<void> clearCacheRows() => _db.delete('yt_cache');

  Future<void> touchCache(String videoId, String kind) {
    return _db.update(
      'yt_cache',
      {'last_access_ms': DateTime.now().millisecondsSinceEpoch},
      where: 'video_id = ? AND kind = ?',
      whereArgs: [videoId, kind],
    );
  }

  Future<void> upsertDownload(DownloadRecord record) {
    return _db.insert(
      'downloads',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DownloadRecord>> downloads() async {
    final rows = await _db.query('downloads', orderBy: 'created_ms DESC');
    return rows.map(DownloadRecord.fromMap).toList();
  }

  Future<DownloadRecord?> downloadFor(String videoId, {bool? audioOnly}) async {
    final rows = await _db.query(
      'downloads',
      where: audioOnly == null ? 'video_id = ?' : 'video_id = ? AND audio_only = ?',
      whereArgs: audioOnly == null ? [videoId] : [videoId, audioOnly ? 1 : 0],
      orderBy: 'created_ms DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DownloadRecord.fromMap(rows.first);
  }

  Future<void> deleteDownload(String id) {
    return _db.delete('downloads', where: 'id = ?', whereArgs: [id]);
  }
}
