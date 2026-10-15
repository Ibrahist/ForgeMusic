enum TrackSource { local, youtube }

enum RepeatMode { off, one, all }

/// A song Forgemusic can play, whether it lives on the phone or came from YouTube.
class Track {
  const Track({
    required this.id,
    required this.source,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArtist,
    required this.genre,
    required this.durationMs,
    required this.sizeBytes,
    required this.addedMs,
    required this.fingerprint,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.path,
    this.filePath,
    this.filename,
    this.folderPath,
    this.bitrate,
    this.youtubeId,
    this.thumbnailUrl,
    this.artworkPath,
    this.lyrics,
    this.syncedLyrics,
    this.replayGainDb,
    this.playCount = 0,
    this.lastPlayedMs,
    this.downloaded = false,
    this.downloadPath,
    this.mediaStoreId,
  });

  final String id;
  final TrackSource source;
  final String title;
  final String artist;
  final String album;
  final String albumArtist;
  final String genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final int durationMs;
  final String? path;
  final String? filePath;
  final String? filename;
  final String? folderPath;
  final int sizeBytes;
  final int? bitrate;
  final String? youtubeId;
  final String? thumbnailUrl;
  final String? artworkPath;
  final String? lyrics;
  final String? syncedLyrics;
  final double? replayGainDb;
  final int playCount;
  final int? lastPlayedMs;
  final int addedMs;
  final bool downloaded;
  final String? downloadPath;
  final int? mediaStoreId;
  final String fingerprint;

  Duration get duration => Duration(milliseconds: durationMs);

  bool get hasLyrics =>
      (syncedLyrics != null && syncedLyrics!.trim().isNotEmpty) ||
      (lyrics != null && lyrics!.trim().isNotEmpty);

  Track copyWith({
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? genre,
    int? year,
    int? trackNumber,
    int? discNumber,
    int? durationMs,
    String? path,
    String? filePath,
    String? filename,
    String? folderPath,
    int? sizeBytes,
    int? bitrate,
    String? thumbnailUrl,
    String? artworkPath,
    String? lyrics,
    String? syncedLyrics,
    double? replayGainDb,
    int? playCount,
    int? lastPlayedMs,
    bool? downloaded,
    String? downloadPath,
    String? fingerprint,
    bool clearLyrics = false,
    bool clearSynced = false,
    bool clearArtwork = false,
    bool clearDownload = false,
    bool clearReplayGain = false,
  }) {
    return Track(
      id: id,
      source: source,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      durationMs: durationMs ?? this.durationMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      addedMs: addedMs,
      fingerprint: fingerprint ?? this.fingerprint,
      path: path ?? this.path,
      filePath: filePath ?? this.filePath,
      filename: filename ?? this.filename,
      folderPath: folderPath ?? this.folderPath,
      bitrate: bitrate ?? this.bitrate,
      youtubeId: youtubeId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      artworkPath: clearArtwork ? null : (artworkPath ?? this.artworkPath),
      lyrics: clearLyrics ? null : (lyrics ?? this.lyrics),
      syncedLyrics: clearSynced ? null : (syncedLyrics ?? this.syncedLyrics),
      replayGainDb: clearReplayGain ? null : (replayGainDb ?? this.replayGainDb),
      playCount: playCount ?? this.playCount,
      lastPlayedMs: lastPlayedMs ?? this.lastPlayedMs,
      downloaded: downloaded ?? this.downloaded,
      downloadPath: clearDownload ? null : (downloadPath ?? this.downloadPath),
      mediaStoreId: mediaStoreId,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'source': source.name,
      'title': title,
      'artist': artist,
      'album': album,
      'album_artist': albumArtist,
      'genre': genre,
      'year': year,
      'track_number': trackNumber,
      'disc_number': discNumber,
      'duration_ms': durationMs,
      'path': path,
      'file_path': filePath,
      'filename': filename,
      'folder_path': folderPath,
      'size_bytes': sizeBytes,
      'bitrate': bitrate,
      'youtube_id': youtubeId,
      'thumbnail_url': thumbnailUrl,
      'artwork_path': artworkPath,
      'lyrics': lyrics,
      'synced_lyrics': syncedLyrics,
      'replay_gain': replayGainDb,
      'play_count': playCount,
      'last_played_ms': lastPlayedMs,
      'added_ms': addedMs,
      'downloaded': downloaded ? 1 : 0,
      'download_path': downloadPath,
      'fingerprint': fingerprint,
      'media_store_id': mediaStoreId,
    };
  }

  factory Track.fromMap(Map<String, Object?> map) {
    return Track(
      id: map['id']! as String,
      source: TrackSource.values.byName(map['source']! as String),
      title: map['title']! as String,
      artist: map['artist']! as String,
      album: map['album']! as String,
      albumArtist: map['album_artist']! as String,
      genre: map['genre']! as String,
      year: _asInt(map['year']),
      trackNumber: _asInt(map['track_number']),
      discNumber: _asInt(map['disc_number']),
      durationMs: _asInt(map['duration_ms']) ?? 0,
      sizeBytes: _asInt(map['size_bytes']) ?? 0,
      addedMs: _asInt(map['added_ms']) ?? 0,
      fingerprint: (map['fingerprint'] as String?) ?? '',
      path: map['path'] as String?,
      filePath: map['file_path'] as String?,
      filename: map['filename'] as String?,
      folderPath: map['folder_path'] as String?,
      bitrate: _asInt(map['bitrate']),
      youtubeId: map['youtube_id'] as String?,
      thumbnailUrl: map['thumbnail_url'] as String?,
      artworkPath: map['artwork_path'] as String?,
      lyrics: map['lyrics'] as String?,
      syncedLyrics: map['synced_lyrics'] as String?,
      replayGainDb: (map['replay_gain'] as num?)?.toDouble(),
      playCount: _asInt(map['play_count']) ?? 0,
      lastPlayedMs: _asInt(map['last_played_ms']),
      downloaded: map['downloaded'] == 1,
      downloadPath: map['download_path'] as String?,
      mediaStoreId: _asInt(map['media_store_id']),
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}
